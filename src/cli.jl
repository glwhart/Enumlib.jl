# CLI entry points for the drop-in `enum.x` and `polya.x` executables.
#
# The implementations live here, in the package, rather than only in `bin/*.jl`
# because PackageCompiler's `create_app` compiles *functions*, not scripts:
#
#     create_app(pkg, dest; executables = ["enum" => "enum_main",
#                                          "polya" => "polya_main"])
#
# `bin/enum.jl` and `bin/polya.jl` remain as thin wrappers, so
# `julia --project=. bin/enum.jl` keeps working in a source checkout and the
# script and compiled paths cannot drift apart.
#
# Both entry points take their arguments from `Base.ARGS` (populated the same way
# for a script run and for a create_app executable) and return a `Cint` exit code.

const ENUM_USAGE = """
enum.x (Enumlib.jl) — enumerate derivative superstructures

Usage: enum.x [input_file] [options]

Reads the input file (default struct_enum.in) from the current directory,
enumerates, and writes struct_enum.out to the current directory, printing the
progress table to stdout. Drop-in replacement for the Fortran enum.x.

Options:
  -h, --help     show this message and exit
  -V, --version  print version and exit
"""

const MAKESTR_USAGE = """
makestr.x (Enumlib.jl) — write VASP POSCARs for enumerated structures

Usage: makestr.x [struct_enum.out] [first] [last] [options]
       makestr.x -input struct_enum.out first last

Reads struct_enum.out (default `struct_enum.out`) and writes one POSCAR per
selected structure as `vasp.<n>` in the current directory, matching the Fortran
makestr.x / makeStr.py output naming that pymatgen's EnumlibAdaptor globs for.

Structure selection:
  no numbers        every structure in the file
  one number N      structure N alone
  two numbers L H   structures L through H inclusive

Numbering is 1-based, as in the file's own `start` column. A range beginning at 0
is read as the 0-based convention the Fortran makestr.x accepts and shifted by
one, so `makestr.x struct_enum.out 0 9` and `-input struct_enum.out 1 10` select
the same ten structures.

Options:
  -input FILE              read FILE instead of ./struct_enum.out
  --species A,B[,C...]     species symbols per label, in label order
                           (default A, B, C, …; pymatgen supplies its own)
  --include-superperiodic  record super_periodic=true in the POSCAR header
  -h, --help               show this message and exit
  -V, --version            print version and exit
"""

const POLYA_USAGE = """
polya.x (Enumlib.jl) — count inequivalent derivative superstructures

Usage: polya.x [input_file] [options]

Reads the input file (default struct_enum.in) from the current directory and
prints the count per supercell volume plus the total. Writes nothing; generates
no structures.

Options:
  --include-superperiodic  also count super-periodic labelings (default: skip
                           them, matching what enum.x writes to struct_enum.out)
  -h, --help               show this message and exit
  -V, --version            print version and exit
"""

# The Fortran drivers (driver.f90 / driver_polya.f90) both take positional
# arguments: arg 1 is an optional input filename defaulting to "struct_enum.in",
# and arg 2 an optional Fortran logical selecting the legacy cross-out algorithm.
# The filename is load-bearing, not cosmetic: conda-forge's enumlib feedstock
# tests the package with `enum.x struct_enum.in.fcc`, so a drop-in that only ever
# reads ./struct_enum.in fails that test.
#
# Arg 2 is accepted and ignored. It chose between two implementations of the same
# enumeration in the Fortran; Enumlib.jl selects its algorithm automatically and
# the resulting structures are unaffected, so ignoring it changes no answer.
function _cli_input_file(exe::AbstractString, args)
    positional = filter(a -> !startswith(a, "-"), args)
    if length(positional) >= 2
        @warn "$exe: ignoring legacy second argument $(repr(positional[2])) " *
              "(the Fortran origCrossOutAlgorithm switch). Enumlib.jl chooses its " *
              "algorithm automatically; the enumeration result is unaffected."
    end
    return isempty(positional) ? "struct_enum.in" : positional[1]
end

# Version string for the `--version` line, resolved once at precompile time.
#
# This must be a `const`, not a runtime lookup. Inside a PackageCompiler app there
# is no package Project.toml on disk, so `pkgversion` returns `nothing` — and it
# *returns* it rather than throwing, so a try/catch does not help: `string(nothing)`
# is the literal "nothing", which is exactly what v0.3.4's released binaries
# printed. Precompilation does have the Project.toml, so resolving here freezes the
# real number into the app image.
const CLI_VERSION::String = let
    v = try
        pv = pkgversion(@__MODULE__)
        pv === nothing ? nothing : string(pv)
    catch
        nothing
    end
    if v === nothing || v == "nothing"
        proj = normpath(joinpath(@__DIR__, "..", "Project.toml"))
        m = isfile(proj) ?
            match(r"(?m)^version\s*=\s*\"([^\"]+)\"", read(proj, String)) : nothing
        m === nothing ? "unknown" : String(m.captures[1])
    else
        v
    end
end

_cli_version() = CLI_VERSION

_asks_version(args) = any(a -> a == "--version" || a == "-V", args)
_asks_help(args)    = any(a -> a == "--help" || a == "-h", args)

"""
    enum_main() -> Cint

Entry point for the drop-in `enum.x`. Reads `struct_enum.in` from the working
directory, enumerates, writes `struct_enum.out`, and prints the Fortran-style
progress table to stdout. `--version`/`-V` and `--help`/`-h` return before
`struct_enum.in` is touched.

Unrecognized arguments are deliberately *ignored* rather than rejected: the
Fortran `enum.x` this stands in for is permissive, and callers such as
pymatgen's `EnumlibAdaptor` must keep working unchanged.
"""
function enum_main()::Cint
    args = Base.ARGS
    if _asks_version(args)
        println("enum.x (Enumlib.jl) $(_cli_version())")
        return Cint(0)
    end
    if _asks_help(args)
        print(ENUM_USAGE)
        return Cint(0)
    end
    try
        inp = read_struct_enum_in(_cli_input_file("enum.x", args))
        e = enumerate(inp.parent, inp.sites; supercells = inp.selection,
                      concentration = inp.concentration)
        open("struct_enum.out", "w") do io
            write_struct_enum_out(io, e; input = inp, stdout_io = stdout)
        end
    catch err
        println(stderr, "enum.x: ", sprint(showerror, err))
        return Cint(1)
    end
    return Cint(0)
end

"""
    polya_main() -> Cint

Entry point for `polya.x`. Reads `struct_enum.in` from the working directory and
reports how many symmetrically inequivalent derivative superstructures it
describes — the job the Fortran `polya.x` (`driver_polya.f90`) did. Generates no
structures and writes no files.

The output layout is deliberately not a copy of the Fortran's; only the
functionality is carried forward. Unlike [`enum_main`](@ref) this is a new
interface with no compatibility burden, so unknown arguments are rejected.
"""
function polya_main()::Cint
    args = Base.ARGS
    if _asks_version(args)
        println("polya.x (Enumlib.jl) $(_cli_version())")
        return Cint(0)
    end
    if _asks_help(args)
        print(POLYA_USAGE)
        return Cint(0)
    end

    # Reject unknown *flags* only; bare words are the positional input filename,
    # matching the Fortran polya.x.
    known = ("--include-superperiodic",)
    unknown = filter(a -> startswith(a, "-") && !(a in known), args)
    if !isempty(unknown)
        println(stderr, "polya.x: unrecognized argument(s): ", join(unknown, " "))
        print(stderr, POLYA_USAGE)
        return Cint(1)
    end
    include_superperiodic = "--include-superperiodic" in args

    try
        inp = read_struct_enum_in(_cli_input_file("polya.x", args))
        counts = count_inequivalent(inp.parent, inp.sites;
                                   supercells = inp.selection,
                                   concentration = inp.concentration,
                                   include_superperiodic = include_superperiodic,
                                   breakdown = true)

        println("polya.x (Enumlib.jl) $(_cli_version())")
        println(include_superperiodic ?
                "Counting all labelings, super-periodic included." :
                "Counting aperiodic labelings only (what enum.x reports).")
        inp.concentration === nothing ||
            println("Concentration restriction from struct_enum.in applied.")
        println()
        println("    volume            count")
        for (n, cnt) in counts.by_volume
            println(lpad(n, 10), lpad(string(cnt), 17))
        end
        println()
        println(lpad("total", 10), lpad(string(counts.total), 17))
    catch err
        println(stderr, "polya.x: ", sprint(showerror, err))
        return Cint(1)
    end
    return Cint(0)
end

"""
    makestr_main() -> Cint

Entry point for `makestr.x`. Reads `struct_enum.out` and writes one POSCAR per
selected structure as `vasp.<n>`, the naming the Fortran `makestr.x` / `makeStr.py`
used and that pymatgen's `EnumlibAdaptor` globs for.

Rebuilds each structure from the file as an `EnumeratedStructure` + `HNF` +
`ParentLattice` and writes it with [`to_poscar`](@ref), so the POSCARs are
identical to what the enumeration itself would have produced — no separate
geometry path to drift.
"""
function makestr_main()::Cint
    args = Base.ARGS
    if _asks_version(args)
        println("makestr.x (Enumlib.jl) $(_cli_version())")
        return Cint(0)
    end
    if _asks_help(args)
        print(MAKESTR_USAGE)
        return Cint(0)
    end

    # `-input FILE` (makeStr.py style) and `--species A,B` take a value; peel those
    # off first so the remaining bare words are the file and the range numbers.
    infile = nothing
    species = String[]
    super_periodic = false
    rest = String[]
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "-input" || a == "--input"
            i + 1 <= length(args) ||
                (println(stderr, "makestr.x: $a needs a filename"); return Cint(1))
            infile = args[i + 1]; i += 2
        elseif a == "--species"
            i + 1 <= length(args) ||
                (println(stderr, "makestr.x: --species needs a comma-separated list");
                 return Cint(1))
            species = String.(split(args[i + 1], ',')); i += 2
        elseif startswith(a, "--species=")
            species = String.(split(split(a, '=', limit = 2)[2], ',')); i += 1
        elseif a == "--include-superperiodic"
            super_periodic = true; i += 1
        elseif startswith(a, "-")
            println(stderr, "makestr.x: unrecognized argument $(repr(a))")
            print(stderr, MAKESTR_USAGE)
            return Cint(1)
        else
            push!(rest, a); i += 1
        end
    end

    # Bare words: an optional filename followed by up to two range numbers.
    nums = Int[]
    for a in rest
        n = tryparse(Int, a)
        if n === nothing
            infile === nothing ? (infile = a) :
                (println(stderr, "makestr.x: unexpected extra argument $(repr(a))");
                 return Cint(1))
        else
            push!(nums, n)
        end
    end
    infile === nothing && (infile = "struct_enum.out")

    try
        out = read_struct_enum_out(infile)
        isempty(out.structures) &&
            (println(stderr, "makestr.x: $infile lists no structures"); return Cint(1))

        available = [s.strN for s in out.structures]
        selected = if isempty(nums)
            available
        elseif length(nums) == 1
            [nums[1]]
        elseif length(nums) == 2
            lo, hi = nums
            # A range starting at 0 is the Fortran makestr.x 0-based convention
            # (pymatgen calls it as `struct_enum.out 0 N-1`); shift to 1-based.
            lo == 0 && ((lo, hi) = (lo + 1, hi + 1))
            lo:hi
        else
            println(stderr, "makestr.x: expected at most two range numbers, got ",
                    length(nums))
            print(stderr, MAKESTR_USAGE)
            return Cint(1)
        end

        by_strN = Dict(s.strN => s for s in out.structures)
        symbols = isempty(species) ?
            [string(Char('A' + (c - 1))) for c in 1:out.k] : species
        length(symbols) >= out.k ||
            (println(stderr, "makestr.x: --species lists $(length(symbols)) symbols " *
                             "but the file is a $(out.k)-nary case"); return Cint(1))

        written = 0
        for strN in selected
            s = get(by_strN, strN, nothing)
            if s === nothing
                println(stderr, "makestr.x: no structure $strN in $infile " *
                                "(file has $(minimum(available))–$(maximum(available)))")
                return Cint(1)
            end
            structure = EnumeratedStructure{3}(s.hnf_id, s.labeling, s.orbit_size)
            open("vasp.$(strN)", "w") do io
                to_poscar(io, structure, out.parent, s.hnf;
                          super_periodic = super_periodic,
                          species_symbols = symbols,
                          enumlib_id = strN)
            end
            written += 1
        end
        println("makestr.x (Enumlib.jl) $(_cli_version()): wrote $written POSCAR file(s)")
    catch err
        println(stderr, "makestr.x: ", sprint(showerror, err))
        return Cint(1)
    end
    return Cint(0)
end
