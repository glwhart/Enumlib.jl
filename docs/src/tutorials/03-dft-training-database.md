# Generating a DFT/MLIP training database

End-to-end workflow: enumerate symmetry-inequivalent structures → ship them to a DFT or MLIP collaborator → receive POSCARs back with energies filled in → pair the energies with the enumeration for cluster-expansion fitting.

By the end of this tutorial you'll have:

- a `.tar.gz` archive of POSCARs ready to share with a calculator,
- a one-paragraph workflow your collaborator follows to fill in energies,
- a `Vector{Tuple{EnumeratedStructure, Float64}}` ready to hand to a CE/MLIP fitter (JuCE.jl is the v0.2.0 first-application target).

The code blocks below are mostly **prose snippets**, not jldoctests — the pipeline touches the filesystem (timestamped archive names, temp dirs, JSON manifests) which doesn't doctest cleanly.

## Setup — FCC binary at fixed concentration

Same parent lattice and sites as the earlier tutorials; this time we add a [`Concentration`](@ref) constraint to keep the enumeration target small and well-defined:

```jldoctest dft_tutorial
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);   # FCC primitive

julia> sites = Sites(parent, [0, 1]);   # binary: species 0 (Ag) and species 1 (Pt)

julia> c = concentration_count([2, 2]; n_total = 4);   # exactly 2 Ag + 2 Pt in a 4-atom cell
```

Count first, enumerate second. The chunk-6 reference for FCC binary 2:2 at supercell volume 4 is 5 structures:

```jldoctest dft_tutorial
julia> count_inequivalent(parent, sites; supercells = VolumeRange(4:4), concentration = c)
5
```

5 structures is small enough to fit in one batch comfortably; for production sweeps you'd vary volume and concentration too. See [Tutorial 02](02-fixed-concentration.md) for fixed concentrations and [the count-without-enumerating how-to](../how-to/count-without-enumerating.md) for sizing larger requests.

## Step 1 — enumerate

```julia
e = enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = c)
length(e)   # 5
```

`e` is an [`Enumeration`](@ref) carrying the 5 [`EnumeratedStructure`](@ref)s. Each one knows its supercell (`e.supercells[s.supercell_id]`) and its labeling (`to_labeling(s)`).

## Step 2 — write the archive

[`write_enumeration_archive`](@ref) bundles every structure as one POSCAR per file plus a TOML manifest, all wrapped in a `.tar.gz`:

```julia
out = write_enumeration_archive("./batch1/", e;
                                 super_periodic = false,
                                 species_symbols = ["Ag", "Pt"],
                                 label = "FCC_AgPt_n4_2-2")
# out: "./batch1/enumlib_FCC_AgPt_n4_2-2_2026-05-16T14-30-00.tar.gz"
```

The timestamp is automatic so two batches in the same directory can't collide. Inside the tarball:

- `POSCAR.01` through `POSCAR.05` — one VASP-format POSCAR per structure. Line 1 of each carries the enumeration metadata plus an empty `energy_eV=` slot the calculator will fill in:
  ```
  # enumlib_id=1 hnf=1 concentration=2:2 super_periodic=false energy_eV=
  ```
- `enumeration.toml` — manifest mapping each filename to its structure metadata, plus a top-level `[enumeration]` section recording the parent, species symbols, super-periodicity policy, etc.

`super_periodic = false` is a required kwarg — it records the policy this enumeration was produced under so the round-trip stays consistent.

## Step 3 — ship it

Email / Slack / upload the tarball to your collaborator. Include a one-paragraph instruction:

> *Each POSCAR's first line ends with `energy_eV=`. After your DFT (VASP, Quantum ESPRESSO, ...) or MLIP (MACE, ALIGNN, ...) run, append the computed total energy in eV (per cell, not per atom) to that slot — a manual edit, a `sed` one-liner, or a 5-line Python script all work. Then repack the directory back into a `.tar.gz` and send it back. Don't change anything else in the POSCAR.*

A `sed` fill from a results CSV is enough:

```bash
# fill_energies.sh — calculator's side
while IFS=, read -r id energy; do
    sed -i.bak "s|energy_eV=$|energy_eV=$energy|" "POSCAR.$(printf %02d $id)"
done < energies.csv
tar -czf batch1_filled.tar.gz POSCAR.* enumeration.toml
```

Or Python:

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

## Step 4 — read the energies back

[`read_results`](@ref) auto-detects whether you have a tarball or a directory:

```julia
results = read_results("./batch1_filled.tar.gz")   # ::Dict{Int, Float64}
# Dict(1 => -45.32, 2 => -45.41, 3 => -45.28, 4 => -45.39, 5 => -45.35)
```

If the calculator hasn't filled in some POSCARs yet (mid-batch), `read_results` skips those and emits an `@info` listing the missing IDs — you can re-run later when more results land.

## Step 5 — pair with the original enumeration

[`attach_results`](@ref) zips the `Dict{Int, Float64}` into the existing [`Enumeration`](@ref):

```julia
pairs = attach_results(e, results)
# pairs :: Vector{Tuple{EnumeratedStructure{3, Vector{Int8}}, Float64}}
length(pairs)             # 5
pairs[1][2]               # -45.32 — energy of structure 1
pairs[1][1] |> to_labeling  # Int8 labeling of structure 1
```

`attach_results` also `@info`s if the enumeration has structures whose IDs aren't in `results` — useful for tracking calculator progress on a partial batch.

## Step 6 — hand off to a CE/MLIP fitter

The `Vector{Tuple{EnumeratedStructure, Float64}}` shape is the v0.2.0 interchange format with JuCE.jl. From there it's CE territory — fitting cluster-expansion coefficients, computing convex hulls, and so on. See JuCE's own documentation for the next steps.

## Troubleshooting

**"VASP says my POSCAR is left-handed."**
Shouldn't happen — `to_poscar` detects left-handed parent bases at write time and swaps two columns to fix the sign of the determinant while preserving the Cartesian geometry. If you see this with a v0.2 build, please file an issue with the parent lattice and HNF.

**"`read_results` skipped some POSCARs."**
Either the `energy_eV=` slot is still empty (calculator didn't fill it), or line 1 was modified and no longer matches the expected format. Open one of the skipped POSCARs and check line 1 looks like:

```
# enumlib_id=42 hnf=14 concentration=15:17 super_periodic=false energy_eV=-45.32
```

The slot must be exactly `energy_eV=<float>` (sign optional; scientific notation OK).

**"My collaborator wants forces and stresses too (MLIP fits)."**
v0.2.0's schema is energy-only. Forces/stresses extension is queued for v0.2.x: the calculator adds e.g. `forces_eV_per_A=...` to line 1; `read_results` learns to capture them. Open an issue when you need this.

**"My collaborator only ran some of the structures."**
That's the expected partial-fill flow. `read_results` returns just the filled-in results; `attach_results` warns about the missing IDs. Pair what you have with the original enumeration; refit the CE later when the rest land.

## See also

- Reference: [`write_enumeration_archive`](@ref), [`read_results`](@ref), [`attach_results`](@ref), [`to_poscar`](@ref).
- How-to: [Write POSCARs for DFT](../how-to/write-poscars-for-dft.md) — the same machinery, recipe-oriented.
- How-to: [Estimate the cost](../how-to/estimate-cost.md) — sizing big sweeps before running them.
- Multi-element parents: [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md) — HCP, diamond, etc. The POSCAR pipeline above works without modification.
