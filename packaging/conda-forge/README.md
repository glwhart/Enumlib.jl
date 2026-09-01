# conda-forge packaging plan

Goal: make `conda install` deliver the Julia `enum.x` / `polya.x` / `makestr.x`, so
users (and pymatgen's CI) get Enumlib.jl transparently and the Fortran `enumlib`
can be retired.

**Submitted:** https://github.com/conda-forge/staged-recipes/pull/34550. The files
here mirror what was submitted; keep them in sync if the review asks for changes.
The recipe is in the **v1 `recipe.yaml`** format — staged-recipes deprecated v0
`meta.yaml` for new recipes.

## Approach: build the application in the recipe

The recipe compiles the app with `PackageCompiler.create_app` against
conda-forge's own `julia`, driving this repo's `build/build_app.jl` — the same
entry point `release.yml` uses, so the conda and release builds cannot diverge.

This replaced an earlier design that repackaged the prebuilt release tarballs.
conda-forge declined that (@mkitti, 2026-08-21: *"The binary repackaging might be
an issue here. The intention is for you to build the binaries in the recipe"*), and
confirmed on 2026-08-25 that dependencies need not be declared as sources and that
**network access at build time is acceptable** — which is what makes building here
practical at all, since `create_app` resolves the General registry and downloads
artifacts.

### What that changes about the package

Building against conda-forge's `julia` does **not** produce a self-contained bundle
like the GitHub release tarballs. julia-feedstock's `build.sh` deliberately strips
Julia's vendored libraries:

```
rm $PREFIX/lib/julia/{libcholmod.so,libcurl.so,libssh2.so,libgit2.so,libssl.so}
```

so Julia links against conda-forge's `openblas-ilp64`, `gmp`, `mpfr`, `libgit2`,
`curl` and friends as separate packages. The application inherits those as runtime
dependencies. Two consequences, both reflected in the recipe:

- **`binary_relocation: false` is gone.** The copied runtime carries `$PREFIX`
  references that conda-build must rewrite. (It was correct for the repackaging
  design, where the bundle resolved everything by RPATH relative to the executable.)
- **`requirements/host` mirrors julia-feedstock's host list**, so the run
  requirements come from those entries' `run_exports`. That list is deliberately
  generous for a first build; conda-build's overlinking check will report what the
  app actually links, and it should then be trimmed.

`julia` is a **host** dependency rather than a build one, so its runtime libraries
land in `$PREFIX` where conda-build relocates them. `build.sh` therefore invokes
`$PREFIX/bin/julia` by explicit path instead of trusting `PATH`.

## Platforms

| subdir | status |
| --- | --- |
| `linux-64` | built from source in the recipe |
| `osx-64` | built from source in the recipe |
| `osx-arm64` | **blocked** — see below |
| `win-64` | skipped (the Fortran enumlib feedstock also skips Windows) |

**osx-arm64 is blocked structurally, not for want of effort.** conda-forge
cross-compiles osx-arm64 on osx-64 runners and has no native Apple Silicon CI, and
staged-recipes builds only x64 in any case. But `create_app` must *execute*
target-architecture code to precompile its system image, and a Julia system image
cannot be cross-compiled. So "build it in the recipe" and "ship Apple Silicon" are
mutually exclusive on the available infrastructure — no arm64 `julia` package would
fix it, and conda-forge's `julia` has none anyway (julia-feedstock#283, open since
July 2024).

Asked on the PR whether a repackage **scoped to osx-arm64 only** would be
acceptable. Until that is answered, Apple Silicon users are served by the native
arm64 binaries on this project's GitHub releases. Note `osx-64` does not cover
them: conda and pixi resolve `osx-arm64` by default on Apple Silicon, so an
`osx-64` package is never a solver candidate outside a deliberate Rosetta
environment.

## Open questions with the reviewer

1. **osx-arm64** — scoped repackaging exception, or ship without it?
2. **CPU optimization** — conda-forge's convention is separate packages per
   `x86_64-microarch-level` (levels 1/3/4, gated on the virtual package of that
   name). Julia's own `JULIA_CPU_TARGET` multi-versioning does the same thing
   inside one system image. Variants mean three ~150 MB packages; multi-versioning
   inflates one. The system image already dominates this package, so the decision
   probably comes down to measuring both. `build.sh` currently sets Julia's
   multi-target string, marked provisional.

## What the existing Fortran feedstock does (verified 2026-08-14)

`conda-forge/enumlib-feedstock` at `enumlib 2.0.6`:

- Builds from source: `msg-byu/enumlib` + `msg-byu/symlib`, with patches, `make`,
  and `{{ compiler('fortran') }}`.
- `skip: true  # [win]` — Linux and macOS only.
- Installs **three** executables: `enum.x`, `polya.x`, `makestr.x` — all three of
  which Enumlib.jl now provides.
- Tests with `enum.x struct_enum.in.fcc` — the input filename as a positional
  argument.
- `recipe-maintainers: [jan-janssen]`.

Two consequences that shaped this repo:

- **The positional filename is load-bearing.** A drop-in that only reads
  `./struct_enum.in` fails the feedstock's own test. Handled — see
  `Enumlib._cli_input_file` and the "CLI positional input file" testset.
- **`makestr.x` is covered** by `Enumlib.makestr_main` (`bin/makestr.jl`): it reads
  `struct_enum.out`, rebuilds each structure, and writes `vasp.<n>` POSCARs via
  `to_poscar`. Verified byte-identical to what the enumeration itself produces, and
  parseable by `pymatgen.io.vasp.inputs.Poscar.from_str` with `index_species` —
  exactly how `EnumlibAdaptor` consumes it.

## Two-phase migration

1. **New `enumlib.jl` staged-recipe** (this PR) — proves the build works on
   conda-forge's CI without disturbing the live Fortran package.
2. **Fold into the `enumlib` name** once validated (a major version bump), so
   `conda install enumlib` yields the Julia engine. Taking over that name needs the
   current maintainer's sign-off; Shyue Ping Ong started the original feedstock but
   has lost track of who owns it now, and the recipe lists `jan-janssen`. His advice
   was to skip identifying the maintainer and simply open a PR against the
   feedstock — CI runs, maintainer merges.

## Updating the version

`recipe.yaml` pins the source tarball and its `sha256`:

```bash
curl -fsSL -o src.tar.gz \
  https://github.com/glwhart/Enumlib.jl/archive/refs/tags/vX.Y.Z.tar.gz
shasum -a 256 src.tar.gz
```

Unlike the old repackaging recipe, this is a single source with one checksum, which
the autotick bot can maintain.
