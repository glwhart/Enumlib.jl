# Tutorial — Generate a DFT training database from an Enumlib enumeration

This tutorial walks through the v0.2 first-application workflow: enumerate symmetry-inequivalent derivative structures, ship them to a collaborator running DFT (or an MLIP), receive back energies, and pair the energies with the original enumeration ready for cluster-expansion fitting.

By the end you'll have:
- a `.tar.gz` archive of POSCAR files ready to share with a calculator,
- a small Julia script the calculator (or anyone) can use to populate the `energy_eV=` slots,
- a `Vector{Tuple{EnumeratedStructure, Float64}}` ready to feed into JuCE.jl's CE fitter.

This file lives in `docs/notes/` for the v0.2 pre-release. When Phase 13d ships, it migrates to `docs/src/tutorials/03-dft-training-database.md` with minor reformatting for the Documenter site.

## Scope and assumptions

- **Materials problem.** Binary alloy on a FCC lattice. We pretend we're studying Ag–Pt (any binary works the same way; the `species_symbols` kwarg lets you pick).
- **Enumeration target.** All symmetry-inequivalent structures at fixed concentration `2:2` in the n=4 primitive supercell. (Chunk 6 locked this count at 5 structures.)
- **DFT side.** We simulate the calculator with a Julia loop that scribbles synthetic energies into the `energy_eV=` slots. In production, your collaborator runs VASP or an MLIP and fills in real numbers — the format is the same either way.
- **Output.** A flat list of `(structure, energy)` tuples. Hand this to JuCE.jl (or any CE/MLIP fitter that accepts the same shape).

## Step 0 — install Enumlib

```julia
using Pkg
Pkg.develop(path = "https://github.com/glwhart/Enumlib.jl")  # while unregistered
# After v0.2.0 General-registry release: Pkg.add("Enumlib")
using Enumlib
```

## Step 1 — define the parent lattice and the substitution sites

The parent lattice is what the supercells are built on. The `Sites` object describes which positions in the primitive cell can be decorated and which species (`allowed_labels`) can sit at each position.

```julia
parent = ParentLattice([0.5 0.5 0.0;
                        0.5 0.0 0.5;
                        0.0 0.5 0.5])             # FCC primitive
sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])    # one site, two species (0 and 1)
```

`allowed_labels = [0, 1]` says color 0 and color 1 are both allowed; we'll later interpret color 0 as Ag and color 1 as Pt via the `species_symbols` kwarg in `to_poscar` / `write_enumeration_archive`.

## Step 2 — count first (preflight) before enumerating

For real workflows that touch larger supercells, count the orbit space first. It's cheap and tells you whether your `enumerate(...)` call is going to produce 5 structures or 5 million.

```julia
c = Concentration_count([2, 2]; n_total = 4)        # exactly 2 of each species in n=4
n_orbits = count_inequivalent(parent, sites;
                              supercells = VolumeRange(4:4),
                              concentration = c)    # ::BigInt
@show n_orbits   # 5
```

For binary FCC at n=4 with 2:2 concentration, Pólya tells us 5. (Locked in chunk 6 tests.)

## Step 3 — enumerate

```julia
enum = enumerate(parent, sites;
                 supercells = VolumeRange(4:4),
                 concentration = c)
length(enum)   # 5
```

Each entry of `enum.structures` is an `EnumeratedStructure` carrying the labeling and the supercell ID; `enum.supercells` carries the HNFs.

## Step 4 — write the archive for the collaborator

```julia
out = write_enumeration_archive("./batch1/", enum;
                                 super_periodic = false,
                                 species_symbols = ["Ag", "Pt"],
                                 label = "FCC_AgPt_n4_2-2")
@show out   # "./batch1/enumlib_FCC_AgPt_n4_2-2_2026-05-09T<time>.tar.gz"
```

What's inside the tarball: 5 POSCARs (`POSCAR.01` through `POSCAR.05`) plus an `enumeration.toml` manifest. Each POSCAR's first line looks like:

```
# enumlib_id=1 hnf=1 concentration=2:2 super_periodic=false energy_eV=
```

The `energy_eV=` slot is empty by design; the calculator fills it in.

The timestamped filename is automatic (per chunk-11b design): if you run a second batch a minute later you get a different name, so two tarballs in the same directory can't collide.

## Step 5 — ship the tarball

Email/Slack/upload `out` to your collaborator. Include a one-paragraph instruction:

> *"Each POSCAR's first line ends with `energy_eV=`. After your DFT or MLIP run, append the computed total energy in eV (per cell, not per atom) to that slot — manual edit, `sed`, or a 5-line Python script all work. Repack the directory back into a `.tar.gz` and send it back. Don't change the rest of the POSCAR."*

A one-line `sed` fill from a results CSV is plenty:

```bash
# fill_energies.sh — calculator's side
while IFS=, read -r id energy; do
    sed -i.bak "s|energy_eV=$|energy_eV=$energy|" "POSCAR.$(printf %02d $id)"
done < energies.csv
tar -czf batch1_filled.tar.gz POSCAR.* enumeration.toml
```

Or in Python (using whatever they normally use for VASP outputs):

```python
import re, pathlib
energies = {1: -45.32, 2: -45.41, 3: -45.28, 4: -45.39, 5: -45.35}  # from VASP
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

## Step 6 — receive back, read the energies

```julia
results = read_results("./batch1_filled.tar.gz")   # ::Dict{Int, Float64}
@show length(results)     # 5
@show results[1]          # -45.32 (or whatever the calculator computed)
```

`read_results` auto-detects the input form:
- `.tar.gz` / `.tgz` / `.tar` file → extracted to a temp dir, read, cleaned up.
- A directory of POSCARs → read directly.

If the calculator hasn't filled in some POSCARs yet (mid-batch), `read_results` skips those and emits an `@info` listing the missing IDs. Re-run later when more results land.

## Step 7 — pair with the original enumeration

```julia
pairs = attach_results(enum, results)
# pairs::Vector{Tuple{EnumeratedStructure{3,Vector{Int8}}, Float64}}
@show length(pairs)            # 5
@show pairs[1][2]              # -45.32 — the energy of structure 1
@show pairs[1][1].labeling     # the labeling vector of structure 1
```

`attach_results` also `@info`s if the enumeration has structures whose IDs aren't in `results` — useful for telling "calculator finished 3 of 5 so far."

## Step 8 — hand off to JuCE.jl for CE fitting

```julia
using JuCE   # the cluster-expansion library
ce_fit = JuCE.fit_cluster_expansion(pairs)
```

(Replace with whatever JuCE's actual entry point is when this tutorial migrates to the docs proper. For v0.2 pre-release, check `JuCE.jl/cePlan.md` for the current API.)

## Troubleshooting

**"VASP says my POSCAR is left-handed."**
Shouldn't happen — `to_poscar` detects left-handed bases at write time and swaps two columns to fix the sign of the determinant (chunk 11b.1). If you see this with a v0.2 Enumlib build, please file an issue with the parent lattice and HNF.

**"`read_results` skipped some POSCARs."**
Either the `energy_eV=` slot is still empty (calculator didn't fill it), or line 1 was modified and no longer matches the expected format. Open one of the skipped POSCARs and check line 1 looks like:

```
# enumlib_id=42 hnf=14 concentration=15:17 super_periodic=false energy_eV=-45.32
```

The slot must be exactly `energy_eV=<float>` (sign optional; scientific notation OK).

**"My collaborator wants forces and stresses too (MLIP fits)."**
v0.2 schema is energy-only (locked at chunk 11 design Q4-A). Forces/stresses extension lands in v0.2.x: collaborator adds e.g. `forces_eV_per_A=...` to line 1; `read_results` is updated to capture and return them. Open an issue when you need this.

**"My collaborator only ran some of the structures."**
That's the expected partial-fill flow. `read_results` returns just the filled-in results; `attach_results` warns about the missing IDs. Pair what you have with the original enumeration; refit the CE later when the rest land.

## What's next

After v0.2.0 ships, this tutorial moves to `docs/src/tutorials/03-dft-training-database.md` (Phase 13d). The rest of Phase 13 (reference, how-to, explanation) builds out the user-facing documentation around this workflow.
