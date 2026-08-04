#!/usr/bin/env julia
# Drop-in `enum.x` (Phase 9). Reads `struct_enum.in` from the current directory,
# enumerates, writes `struct_enum.out` to the current directory, and prints the
# Fortran-style progress table (the `…RunTot` table) to stdout. Behaves like the
# Fortran `enum.x` so pymatgen's `EnumlibAdaptor` uses it unchanged.
#
# Run:  julia --project=<Enumlib.jl> bin/enum.jl
# (PackageCompiled into a standalone `enum.x` in a later chunk.)
using Enumlib

inp = Enumlib.read_struct_enum_in("struct_enum.in")
e = enumerate(inp.parent, inp.sites; supercells = inp.selection,
              concentration = inp.concentration)
open("struct_enum.out", "w") do io
    Enumlib.write_struct_enum_out(io, e; input = inp, stdout_io = stdout)
end
