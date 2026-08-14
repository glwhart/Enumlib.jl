#!/usr/bin/env julia
# Counting-only companion to `bin/enum.jl` (the drop-in `enum.x`). Reads
# `struct_enum.in` from the current directory and reports how many symmetrically
# inequivalent derivative superstructures it describes — the job the Fortran
# `polya.x` (`driver_polya.f90`) did, via the Pólya/Burnside route instead of by
# generating anything. Nothing is written to disk and no structures are built.
#
# The output format is deliberately *not* a copy of the Fortran `polya.x`
# layout; only the functionality is carried forward.
#
# Run:  julia --project=<Enumlib.jl> bin/polya.jl [--include-superperiodic]
# (PackageCompiled into a standalone `polya.x` alongside `enum.x`.)
using Enumlib

const USAGE = """
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

function _version()
    try
        return string(pkgversion(Enumlib))
    catch
        m = match(r"(?m)^version\s*=\s*\"([^\"]+)\"",
                  read(joinpath(pkgdir(Enumlib), "Project.toml"), String))
        return m === nothing ? "unknown" : m.captures[1]
    end
end

# `--version`/`-V` and `--help`/`-h` exit before `struct_enum.in` is touched, so
# they work anywhere (this is what pymatgen's engine detection probes).
if any(a -> a == "--version" || a == "-V", ARGS)
    println("polya.x (Enumlib.jl) $(_version())")
    exit(0)
end
if any(a -> a == "--help" || a == "-h", ARGS)
    print(USAGE)
    exit(0)
end

const KNOWN_FLAGS = ("--include-superperiodic",)
let unknown = filter(a -> !(a in KNOWN_FLAGS), ARGS)
    if !isempty(unknown)
        println(stderr, "polya.x: unrecognized argument(s): ", join(unknown, " "))
        print(stderr, USAGE)
        exit(1)
    end
end
include_superperiodic = "--include-superperiodic" in ARGS

inp = Enumlib.read_struct_enum_in("struct_enum.in")
counts = count_inequivalent(inp.parent, inp.sites;
                            supercells = inp.selection,
                            concentration = inp.concentration,
                            include_superperiodic = include_superperiodic,
                            breakdown = true)

println("polya.x (Enumlib.jl) $(_version())")
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
