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
#
# Thin wrapper only: the implementation is `Enumlib.polya_main()` in src/cli.jl, so
# PackageCompiler's create_app compiles the identical code path into a standalone
# `polya.x` (see build/build_app.jl).
using Enumlib

exit(Enumlib.polya_main())
