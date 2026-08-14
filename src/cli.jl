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

Usage: enum.x [options]

Reads struct_enum.in from the current directory, enumerates, and writes
struct_enum.out to the current directory, printing the progress table to
stdout. Drop-in replacement for the Fortran enum.x.

Options:
  -h, --help     show this message and exit
  -V, --version  print version and exit
"""

const POLYA_USAGE = """
polya.x (Enumlib.jl) — count inequivalent derivative superstructures

Usage: polya.x [options]

Reads struct_enum.in from the current directory and prints the count per
supercell volume plus the total. Writes nothing; generates no structures.

Options:
  --include-superperiodic  also count super-periodic labelings (default: skip
                           them, matching what enum.x writes to struct_enum.out)
  -h, --help               show this message and exit
  -V, --version            print version and exit
"""

# Version string for the `--version` line. `pkgversion` works in a source
# checkout and in a compiled app; the Project.toml fallback covers the case
# where neither is available (then "unknown" rather than an error).
function _cli_version()
    try
        return string(pkgversion(@__MODULE__))
    catch
        try
            dir = pkgdir(@__MODULE__)
            dir === nothing && return "unknown"
            m = match(r"(?m)^version\s*=\s*\"([^\"]+)\"",
                      read(joinpath(dir, "Project.toml"), String))
            return m === nothing ? "unknown" : m.captures[1]
        catch
            return "unknown"
        end
    end
end

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
        inp = read_struct_enum_in("struct_enum.in")
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

    known = ("--include-superperiodic",)
    unknown = filter(a -> !(a in known), args)
    if !isempty(unknown)
        println(stderr, "polya.x: unrecognized argument(s): ", join(unknown, " "))
        print(stderr, POLYA_USAGE)
        return Cint(1)
    end
    include_superperiodic = "--include-superperiodic" in args

    try
        inp = read_struct_enum_in("struct_enum.in")
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
