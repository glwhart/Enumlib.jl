# The drop-in executables (pymatgen interop)

Enumlib.jl ships three command-line executables — `enum.x`, `polya.x`, and `makestr.x` —
as pre-compiled per-platform binaries on each [release](https://github.com/glwhart/Enumlib.jl/releases).
They exist for one reason: so that tools built around the Fortran
[`enumlib`](https://github.com/msg-byu/enumlib) can use this package without changing a
line. In particular, pymatgen's `EnumlibAdaptor` shells out to `enum.x` and `makestr.x`
found on `PATH`, and works against these unmodified.

!!! note "These are an integration surface, not a user API"
    If you are writing Julia, do not shell out to them. [`enumerate_structures`](@ref)
    and [`count_inequivalent`](@ref) do the same work in-process, faster, and hand back
    typed values instead of files you have to parse. The executables exist to satisfy
    callers that already speak the Fortran's file protocol. This page documents the bridge
    so its behaviour is on the record; it is not a recommendation to use it.

## What each one does

| executable | reads | writes | who calls it |
| --- | --- | --- | --- |
| `enum.x` | `struct_enum.in` | `struct_enum.out` + progress table on stdout | pymatgen's `EnumlibAdaptor` |
| `makestr.x` | `struct_enum.out` | one `vasp.<n>` POSCAR per structure | pymatgen's `EnumlibAdaptor` |
| `polya.x` | `struct_enum.in` | counts to stdout; writes nothing | nothing, currently |

`polya.x` has no caller. It exists so that the conda-forge `enumlib` package — which ships
`polya.x` alongside the other two — can eventually be served by this implementation without
regressing anyone who used it. If you want that count from Julia, use
[`count_inequivalent`](@ref); see [Count without enumerating](../how-to/count-without-enumerating.md).

## Engine detection

`--version` prints one line carrying the token `Enumlib.jl`:

```
$ enum.x --version
enum.x (Enumlib.jl) 0.3.8
```

The Fortran `enum.x` has no `--version` flag, so its absence is what distinguishes the two.
pymatgen uses exactly this check and emits a non-breaking `UserWarning` recommending
Enumlib.jl when it finds the legacy engine. Anything downstream that wants to tell the
implementations apart should probe the same way rather than inspecting file sizes or paths.
`--version` and `--help` return before any input file is touched, so they work from any
directory.

## Fortran compatibility, and one deliberate difference

The `struct_enum.in` / `struct_enum.out` formats are unchanged, which is what makes the
swap invisible to callers. Two details of the Fortran command line are also carried
forward: argument 1 is an optional input filename (defaulting to `struct_enum.in`), and the
Fortran's second positional argument — the legacy `origCrossOutAlgorithm` switch — is
accepted, warned about, and ignored, since Enumlib.jl chooses its algorithm automatically
and the resulting structures are unaffected.

Results are not always identical, and the difference is intentional. For symmetry-equivalent
sublattices with overlapping label sets, Enumlib.jl keeps symmetry operations that the
Fortran drops, so counts can differ; the worked case is in `docs/notes/chunk6.5-design.md`
§11.4. Two features of the Fortran are also absent: displacement-direction ("arrow")
enumeration, and two-dimensional / `surf`-mode enumeration, which the reader rejects with a
clear error rather than guessing.

## Installation

The per-platform tarballs bundle the Julia runtime, so no Julia installation is required —
untar and put `bin/` on `PATH`. See the
[README](https://github.com/glwhart/Enumlib.jl#standalone-binaries-no-julia-required) for
the download command, checksums, and the macOS Gatekeeper note.

The implementations live in `src/cli.jl` as `Enumlib.enum_main`, `Enumlib.polya_main`, and
`Enumlib.makestr_main`; `bin/*.jl` are thin wrappers so the script and compiled paths cannot
drift apart.
