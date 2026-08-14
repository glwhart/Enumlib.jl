#!/usr/bin/env julia
# Drop-in `enum.x` (Phase 9). Reads `struct_enum.in` from the current directory,
# enumerates, writes `struct_enum.out` to the current directory, and prints the
# Fortran-style progress table (the `…RunTot` table) to stdout. Behaves like the
# Fortran `enum.x` so pymatgen's `EnumlibAdaptor` uses it unchanged.
#
# Run:  julia --project=<Enumlib.jl> bin/enum.jl
#
# Thin wrapper only: the implementation is `Enumlib.enum_main()` in src/cli.jl, so
# PackageCompiler's create_app compiles the identical code path into a standalone
# `enum.x` (see build/build_app.jl).
using Enumlib

exit(Enumlib.enum_main())
