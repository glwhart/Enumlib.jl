# conda-forge packaging plan

Goal: make `conda install enumlib` deliver the Julia `enum.x` / `polya.x`, so users
(and pymatgen's CI) get Enumlib.jl transparently and the Fortran `enumlib` can be
retired.

Everything here is a **draft**. Nothing has been submitted to conda-forge.

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

1. **New `enumlib-jl` staged-recipe.** Gets conda-forge/core to rule on the
   repackaging exception and proves the runtime works on their CI, without
   disturbing the live Fortran package.
2. **Fold into the `enumlib` name** once validated (a major version bump), so
   `conda install enumlib` yields the Julia engine.

## What the existing feedstock does (verified 2026-08-14)

`conda-forge/enumlib-feedstock` `recipe/meta.yaml` + `build.sh`, at `enumlib 2.0.6`:

- Builds from source: `msg-byu/enumlib` + `msg-byu/symlib`, with patches, `make`,
  and `{{ compiler('fortran') }}`.
- `skip: true  # [win]` — Linux and macOS only. Our `release.yml` also builds
  Windows, which is extra rather than required here.
- Installs **three** executables: `enum.x`, `polya.x`, **`makestr.x`**.
- Tests with `enum.x struct_enum.in.fcc` — the input filename as a positional
  argument.
- `recipe-maintainers: [jan-janssen]`.

Two consequences that shaped this repo:

- **The positional filename is load-bearing.** A drop-in that only reads
  `./struct_enum.in` fails the feedstock's own test. Handled — see
  `Enumlib._cli_input_file` and the "CLI positional input file" testset.
- **`makestr.x` has no Julia counterpart.** See the blockers below.

## Open blockers

1. **conda-forge/core must grant the binary-repackaging exception.** Gates
   everything above.
2. **Taking over the `enumlib` name needs the current maintainer's sign-off.**
   Shyue Ping Ong started the original feedstock but has lost track of who owns it
   now; the recipe lists `jan-janssen`. His advice was to skip identifying the
   maintainer and simply open a PR against the feedstock — CI runs, maintainer
   merges.
3. **`makestr.x` is a genuine coverage gap.** The feedstock installs it and
   pymatgen's `EnumlibAdaptor` requires it on `PATH`
   (`which("makestr.x") or which("makeStr.x") or which("makeStr.py")`), but
   Enumlib.jl ships no equivalent — there is no `makestr`/`makeStr` anywhere in
   this repo. So Enumlib.jl currently replaces `enum.x` and `polya.x` but **not**
   the whole feedstock: structure generation from `struct_enum.out` still comes
   from the Fortran side. Fully retiring the Fortran means porting `makestr` or
   confirming nobody depends on it. Until then, an `enumlib`-name takeover would
   regress users who call `makestr.x`.
4. **Size is estimated, not measured.** The ~655 MB raw / ~180–280 MB compressed
   figures came from scoping, not from a build. `release.yml` prints `du -h` on the
   tarball; use that number. For reference conda-forge's own `julia` package is
   ~168 MB compressed and the hard limit is 1 GB/file, so there is headroom, but
   confirm rather than assume.

## Filling in the recipe

`recipe/meta.yaml` carries `sha256: PLACEHOLDER_*` values. After a release build:

```bash
gh release download v0.3.3 --repo glwhart/Enumlib.jl --pattern '*.sha256'
cat *.sha256          # paste each into the matching selector line
```
