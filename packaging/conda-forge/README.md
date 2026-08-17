# conda-forge packaging plan

Goal: make `conda install enumlib` deliver the Julia `enum.x` / `polya.x`, so users
(and pymatgen's CI) get Enumlib.jl transparently and the Fortran `enumlib` can be
retired.

**Submitted:** https://github.com/conda-forge/staged-recipes/pull/34550 (phase 1,
the `enumlib-jl` staged recipe). The files here mirror what was submitted; keep them
in sync if the review asks for changes.

Note the recipe is in the **v1 `recipe.yaml`** format — staged-recipes deprecated the
v0 `meta.yaml` for new recipes, and the old draft here has been replaced.

## Recommended approach: ship the prebuilt binary

Download the per-platform tarball this repo's `release.yml` attaches to a GitHub
Release (`url` + `sha256`) and relocate it into `$PREFIX`, rather than building
inside the feedstock. Building in the feedstock is impractical: `create_app` pulls
the whole Julia General registry depot plus artifacts at build time, which fights
conda-forge's reproducible / no-arbitrary-download norms and is heavy for bounded
CI.

The tradeoff is real and worth stating plainly: **binary repackaging is an explicit
exception that conda-forge/core has to approve.** That approval is the gating risk
for this whole approach, not the packaging mechanics.

## Two-phase migration

1. **New `enumlib-jl` staged-recipe.** Submitted as staged-recipes#34550. Gets
   conda-forge/core to rule on the repackaging exception and proves the runtime works
   on their CI, without disturbing the live Fortran package.
2. **Fold into the `enumlib` name** once validated (a major version bump), so
   `conda install enumlib` yields the Julia engine.

## What the existing feedstock does (verified 2026-08-14)

`conda-forge/enumlib-feedstock` `recipe/meta.yaml` + `build.sh`, at `enumlib 2.0.6`:

- Builds from source: `msg-byu/enumlib` + `msg-byu/symlib`, with patches, `make`,
  and `{{ compiler('fortran') }}`.
- `skip: true  # [win]` — Linux and macOS only. Our `release.yml` also builds
  Windows, which is extra rather than required here.
- Installs **three** executables: `enum.x`, `polya.x`, `makestr.x` — all three of
  which Enumlib.jl now provides.
- Tests with `enum.x struct_enum.in.fcc` — the input filename as a positional
  argument.
- `recipe-maintainers: [jan-janssen]`.

Two consequences that shaped this repo:

- **The positional filename is load-bearing.** A drop-in that only reads
  `./struct_enum.in` fails the feedstock's own test. Handled — see
  `Enumlib._cli_input_file` and the "CLI positional input file" testset.
- **`makestr.x` is now covered** by `Enumlib.makestr_main` (`bin/makestr.jl`).

## Open blockers

1. **conda-forge/core must grant the binary-repackaging exception.** Gates
   everything above.
2. **Taking over the `enumlib` name needs the current maintainer's sign-off.**
   Shyue Ping Ong started the original feedstock but has lost track of who owns it
   now; the recipe lists `jan-janssen`. His advice was to skip identifying the
   maintainer and simply open a PR against the feedstock — CI runs, maintainer
   merges.
3. ~~`makestr.x` coverage gap.~~ **Closed.** `makestr.x` is now implemented
   (`Enumlib.makestr_main`): it reads `struct_enum.out`, rebuilds each structure,
   and writes `vasp.<n>` POSCARs via `to_poscar`. Verified byte-identical to what
   the enumeration itself produces, and verified parseable by
   `pymatgen.io.vasp.inputs.Poscar.from_str` with `index_species`, which is
   exactly how `EnumlibAdaptor` consumes it. Enumlib.jl therefore now supplies all
   three executables the feedstock ships, so an `enumlib`-name takeover no longer
   regresses anyone.
4. ~~Size is estimated, not measured.~~ **Measured** (first real build, 2026-08-14):
   **417 MB** compressed for linux-x86_64, **289 MB** for macos-aarch64, **436 MB**
   for windows-x86_64. The earlier 180–280 MB scoping figure was too low. The hard
   limit is 1 GB/file (conda-forge's own `julia` package is ~168 MB compressed), so
   there is headroom — but this is large, and reviewers will notice.

## Filling in the recipe

`recipe/meta.yaml` carries `sha256: PLACEHOLDER_*` values. After a release build:

```bash
gh release download v0.3.3 --repo glwhart/Enumlib.jl --pattern '*.sha256'
cat *.sha256          # paste each into the matching selector line
```
