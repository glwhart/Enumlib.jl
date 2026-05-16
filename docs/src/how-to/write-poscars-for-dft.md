# Write POSCARs for DFT

This is the v0.2.0 **first-application workflow**: enumerate structures → write VASP-format POSCAR files for downstream DFT or MLIP runs → ship the directory to a collaborator → receive POSCARs back with energies filled in → attach the energies to your `Enumeration` for cluster-expansion fitting.

The code examples below are **prose snippets**, not jldoctests — they touch the filesystem (timestamped archive names, temporary directories), which doesn't doctest cleanly. Treat them as a template; the file-format details are locked by the reference docstrings.

## Setup

```julia
using Enumlib

p     = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])   # FCC primitive
sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])                  # binary
c     = concentration_count([4, 4]; n_total = 8)                # 50/50

e = enumerate(p, sites; supercells = VolumeRange(8:8), concentration = c)
```

`e` carries 94 `EnumeratedStructure`s — the chunk-6 reference for FCC binary 4:4 at n=8.

## One POSCAR for one structure

[`to_poscar`](@ref) writes a single structure to an IO stream. The header line carries the enumeration metadata plus an empty `energy_eV=` slot for the calculator to fill in:

```julia
open("POSCAR_1", "w") do io
    to_poscar(io, e[1], p, e.supercells[e[1].supercell_id].hnf)
end
```

The header looks like:

```
# enumlib_id=1 hnf=1 concentration=4:4 super_periodic=false energy_eV=
1.0
   0.0   0.5   0.5
   0.5   0.0   0.5
   0.5   0.5   0.0
A B
   4   4
Direct
   ...
```

VASP-5+ format (the species-symbols line was added at v4→v5; that format is unchanged through VASP 6).

## A whole enumeration as a tarball

[`write_enumeration_archive`](@ref) writes every structure into a single `.tar.gz` containing all the POSCARs plus a TOML manifest mapping `structure_id ↔ poscar_filename`:

```julia
archive_path = write_enumeration_archive("ag-pt-4-4-n8", e)
# → "ag-pt-4-4-n8_2026-05-14_103045.tar.gz" (timestamp auto-appended)
```

Ship the tarball to your collaborator. They unpack it, run their DFT/MLIP jobs, fill in the `energy_eV=` slot on each POSCAR's header line, and re-tar (or send back the directory).

## Reading energies back

[`read_results`](@ref) auto-detects whether you have a tarball or a directory, walks every POSCAR, and parses the `energy_eV=` slot:

```julia
results = read_results("ag-pt-4-4-n8_filled_2026-05-14.tar.gz")
# → Dict{Int, Float64} keyed by structure_id
```

[`attach_results`](@ref) pairs the energies with the structures:

```julia
tagged = attach_results(e, results)
# → Vector{Tuple{EnumeratedStructure, Float64}}
```

`tagged` is ready to hand off to [JuCE.jl](https://github.com/glwhart/JuCE.jl) or any other cluster-expansion / MLIP fitter that consumes `(structure, energy)` pairs.

## Right-handedness and other gotchas

- `to_poscar` automatically detects basis matrices with `det(B) < 0` and swaps columns 1↔2 plus the corresponding fractional positions, so the output is always right-handed (VASP requires this).
- The `energy_eV=` slot is the only schema-controlled field the calculator should edit. Future versions may add `forces_eV_per_A=` and `stress_eV_per_A3=` slots; the parser is forward-compatible (unknown header keys are ignored).
- Collaborators who aren't Julia users can fill in `energy_eV=` with any text editor or a short Python/shell script — the header format is intentionally simple.

## See also

- Reference: [`to_poscar`](@ref), [`write_enumeration_archive`](@ref), [`read_results`](@ref), [`attach_results`](@ref), [`EnumeratedStructure`](@ref), [`Enumeration`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md) — usually done first.
- Tutorial: [DFT/MLIP training database](../tutorials/03-dft-training-database.md).
- Explanation: [Algorithm overview](../explanation/algorithm-overview.md).
