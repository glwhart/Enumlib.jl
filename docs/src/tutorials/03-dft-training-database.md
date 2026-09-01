# Generating a DFT/MLIP training database

The DFT/MLIP roundtrip workflow, end to end: enumerate symmetry-inequivalent configurations[^terms] → ship them to a DFT or MLIP collaborator → receive POSCARs back with energies filled in → pair the energies with the original enumeration, ready for cluster-expansion fitting.

[^terms]: Same terminology as Tutorials 01 and 02 — a **configuration** is a supercell-plus-coloring pair (an [`EnumeratedStructure`](@ref)); a **coloring** is the per-site species vector. The [glossary](../explanation/glossary.md) has the full list.

## What you'll build

On the same FCC binary parent as the earlier tutorials, treated as Ag–Pt at 50/50 composition:

- A single `.tar.gz` archive (5 POSCARs + a TOML manifest) ready to share with a calculator.
- A one-paragraph workflow your collaborator follows to fill in energies.
- A `Vector{Tuple{EnumeratedStructure, Float64}}` paired and ready to hand to a cluster-expansion (CE) or MLIP fitter[^1].

[^1]: JuCE.jl is the canonical downstream consumer. The "tuple-list" shape — a vector of `(configuration, energy)` pairs — is the *interchange format* both sides agree on: a stable, minimal contract that doesn't require either side to know the other's internal types. Anything that accepts that shape works.

Most code blocks below are **prose snippets**, not jldoctests — the pipeline touches the filesystem (timestamped archive names, temp dirs, TOML manifests), which doesn't doctest cleanly.

## Setup

Same parent and sites as Tutorial 02; we add a [`Concentration`](@ref) — exactly 2 of each species in a 4-atom cell — to keep the demo batch small:

```jldoctest dft_tutorial
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites(parent, [0, 1]);

julia> c = concentration_count([2, 2]; n_total = 4);
```

## Step 1 — count first

Before enumerating, ask how many configurations the call is about to produce. [`count_inequivalent`](@ref) gives you the answer in milliseconds, with no allocation, via the Pólya counter — so you can size the batch before committing to it[^2]:

```jldoctest dft_tutorial
julia> count_inequivalent(parent, sites; supercells = VolumeRange(4:4), concentration = c)
5
```

[^2]: `enumerate(...)` also runs this check internally and refuses to start when the predicted memory exceeds `memory_budget`. See [Dispatch and the resource check](../explanation/dispatch-and-cost-gate.md).

Five configurations — small enough to ship in a single batch. (For production sweeps you'd vary volume and concentration too; see [Count without enumerating](../how-to/count-without-enumerating.md) for the recipe-oriented version of this pattern.)

## Step 2 — enumerate

```julia
e = enumerate_structures(parent, sites; supercells = VolumeRange(4:4), concentration = c)
length(e)   # 5
```

`e` is an [`Enumeration`](@ref) carrying the 5 [`EnumeratedStructure`](@ref) values — same shape as Tutorial 01, just smaller and concentration-restricted.

## Step 3 — write the archive

[`write_enumeration_archive`](@ref) bundles every configuration as one POSCAR per file, plus a TOML manifest, wrapped in a `.tar.gz`. The auto-generated filename carries a timestamp so two batches in the same directory can't collide[^3]:

[^3]: Pass `label = "..."` to add a descriptive component to the auto-name; pass an explicit `.tar.gz` path to skip auto-naming. See [`write_enumeration_archive`](@ref).

```julia
out = write_enumeration_archive("./batch1/", e;
                                 super_periodic = false,
                                 species_symbols = ["Ag", "Pt"],
                                 label = "FCC_AgPt_n4_2-2")
# out: "./batch1/enumlib_FCC_AgPt_n4_2-2_2026-05-16T14-30-00.tar.gz"
```

Inside the tarball:

- `POSCAR.01` through `POSCAR.05` — one VASP-format POSCAR per configuration. Line 1 carries the enumeration metadata plus an empty `energy_eV=` slot the calculator will fill in:
  ```
  # enumlib_id=1 hnf=1 concentration=2:2 super_periodic=false energy_eV=
  ```
- `enumeration.toml` — manifest mapping each filename to its configuration metadata, plus a top-level `[enumeration]` section recording the parent, species symbols, super-periodicity policy, etc.

`super_periodic = false` is required — it records the policy this enumeration was produced under so the round-trip stays consistent on the read side.

## Step 4 — ship it

Email / Slack / upload the tarball to your collaborator with a one-paragraph instruction:

> *Each POSCAR's first line ends with `energy_eV=`. After your DFT or MLIP run, append the computed total energy in eV (per cell, not per atom; include the sign — DFT total energies are negative) to that slot — a manual edit, a `sed` one-liner, or a few-line script all work. Then repack the directory into a `.tar.gz` and send it back. Don't change anything else in the POSCAR.*

A short Python script is the most portable fill recipe:

```python
import re, pathlib
energies = {1: -45.32, 2: -45.41, 3: -45.28, 4: -45.39, 5: -45.35}
for path in pathlib.Path(".").glob("POSCAR.*"):
    m = re.match(r"POSCAR\.(\d+)$", path.name)
    if not m: continue
    eid = int(m.group(1))
    if eid not in energies: continue
    text = path.read_text()
    new = re.sub(r"energy_eV=\s*$", f"energy_eV={energies[eid]}",
                 text, count=1, flags=re.MULTILINE)
    path.write_text(new)
```

(A `sed` one-liner over a CSV of `(id, energy)` pairs works too, if your collaborator prefers shell.)

## Step 5 — read the energies back

[`read_results`](@ref) auto-detects whether you have a tarball or an unpacked directory:

```julia
results = read_results("./batch1_filled.tar.gz")   # ::Dict{Int, Float64}
# Dict(1 => -45.32, 2 => -45.41, 3 => -45.28, 4 => -45.39, 5 => -45.35)
```

Partial batches are fine — if the calculator hasn't filled some POSCARs yet, `read_results` skips them and emits an `@info` listing the missing IDs. You re-run later when more results land.

## Step 6 — pair with the original enumeration and hand off

[`attach_results`](@ref) zips the `Dict{Int, Float64}` into the existing [`Enumeration`](@ref), producing the `Vector{Tuple{EnumeratedStructure, Float64}}` interchange format:

```julia
pairs = attach_results(e, results)
# pairs :: Vector{Tuple{EnumeratedStructure{3, Vector{Int8}}, Float64}}
pairs[1][2]                # -45.32 — energy of configuration 1
pairs[1][1] |> to_labeling # Int8 coloring of configuration 1
```

`attach_results` also `@info`s if the enumeration has configurations whose IDs aren't in `results` — useful for tracking calculator progress on a partial batch.

From here it's CE / MLIP territory: hand `pairs` to JuCE.jl (or any fitter that accepts the tuple-list shape) and fit cluster-expansion coefficients, compute convex hulls, etc. See JuCE's own documentation for the next steps.

## What just happened

You walked an enumeration through the full DFT-training loop, end to end:

1. **Count** to confirm the batch size is sane.
2. **Enumerate** to materialize the configurations.
3. **Archive** to ship one tarball instead of N loose POSCARs.
4. **Ship** with one paragraph of instructions.
5. **Read** the calculator's filled-in energies back.
6. **Pair** them with the original enumeration and hand off for fitting.

Every step is one function call. The collaborator's side is a few-line script, intentionally — the interchange format (POSCAR + the `energy_eV=` slot) is *the* contract between Enumlib and the calculator, kept deliberately minimal so nothing breaks when collaborators use different tools.

## Troubleshooting

**"VASP says my POSCAR is left-handed."** Shouldn't happen — `to_poscar` detects left-handed parent bases at write time and swaps two columns to fix the sign of the determinant while preserving the Cartesian geometry. If you see this, please file an issue, including the parent lattice and HNF.

**"`read_results` skipped some POSCARs."** Either the `energy_eV=` slot is still empty (calculator didn't fill it), or line 1 was modified and no longer matches the expected format. The slot must be exactly `energy_eV=<float>`, and the float should **always carry its sign** — DFT total energies are negative, and while the parser will accept an unsigned value it can't catch a missing minus. Scientific notation is fine:

```
# enumlib_id=42 hnf=14 concentration=15:17 super_periodic=false energy_eV=-45.32
```

**"My collaborator wants forces and stresses too (MLIP fits)."** The current schema is energy-only. Open an issue if you need forces/stresses.

**"My collaborator only ran some of the configurations."** That's the expected partial-fill flow. `read_results` returns just the filled-in results; `attach_results` warns about the missing IDs. Pair what you have, refit the CE later when the rest land.

## See also

- Reference: [`write_enumeration_archive`](@ref), [`read_results`](@ref), [`attach_results`](@ref), [`to_poscar`](@ref).
- How-to: [Write POSCARs for DFT](../how-to/write-poscars-for-dft.md) — the same machinery, recipe-oriented.
- Multi-element parents: [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md) — HCP, diamond, etc. The POSCAR pipeline above works without modification.
- Big sweeps: [Estimate the cost](../how-to/estimate-cost.md).
