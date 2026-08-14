#!/usr/bin/env julia
# Drop-in `makestr.x`. Reads `struct_enum.out` and writes one POSCAR per selected
# structure as `vasp.<n>` in the current directory — the naming the Fortran
# `makestr.x` / `makeStr.py` used and that pymatgen's `EnumlibAdaptor` globs for.
#
# Run:  julia --project=<Enumlib.jl> bin/makestr.jl [struct_enum.out] [first] [last]
#
# Thin wrapper only: the implementation is `Enumlib.makestr_main()` in src/cli.jl, so
# PackageCompiler's create_app compiles the identical code path into a standalone
# `makestr.x` (see build/build_app.jl).
using Enumlib

exit(Enumlib.makestr_main())
