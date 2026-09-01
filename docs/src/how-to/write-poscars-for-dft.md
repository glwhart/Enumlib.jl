# Write POSCARs for DFT

The DFT/MLIP **roundtrip workflow**: enumerate structures → write VASP-format POSCAR files for downstream DFT or MLIP runs → ship the directory to a collaborator → receive POSCARs back with energies filled in → attach the energies to your `Enumeration` for cluster-expansion fitting.

Most of the examples below are executed as doctests, writing into a temporary directory so they stay self-contained. The two that read energies back are prose: they need a collaborator (or a calculator) to have filled the `energy_eV=` slots first, and faking that inline would obscure the point. That round-trip is covered by the test suite instead.

## Setup

```jldoctest poscar_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);   # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary

julia> c = concentration_count([4, 4]; n_total = 8);                 # 50/50

julia> e = enumerate_structures(p, sites; supercells = VolumeRange(8:8),
                                concentration = c);

julia> length(e)
94
```

That 94 is the canonical HF 2012 reference count for FCC binary 4:4 at n=8.

## One POSCAR for one structure

[`to_poscar`](@ref) writes a single structure to an IO stream. The header line carries the enumeration metadata plus an empty `energy_eV=` slot for the calculator to fill in:

```jldoctest poscar_recipe
julia> poscar = sprint(io -> to_poscar(io, e[1], p,
                                       e.supercells[e[1].supercell_id].hnf;
                                       super_periodic = false));

julia> print(join(first(split(poscar, "\n"), 8), "\n"))
# radius=2.3714 enumlib_id=0 hnf=1 super_periodic=false energy_eV=
1.0
        0.000000000000        0.500000000000        0.500000000000
        0.500000000000        0.000000000000        0.500000000000
        3.000000000000        2.500000000000       -2.500000000000
A B
4 4
Direct
```

Rows 3–5 are the *supercell* basis, not the parent's. `enumlib_id` is 0 here
because a one-off `to_poscar` call has no batch to number against; pass
`enumlib_id =` yourself, or use the archive writer below, which numbers them.
To write it to disk, hand `to_poscar` a real stream:

```jldoctest poscar_recipe
julia> mktempdir() do dir
           open(joinpath(dir, "POSCAR_1"), "w") do io
               to_poscar(io, e[1], p, e.supercells[e[1].supercell_id].hnf;
                         super_periodic = false)
           end
           filesize(joinpath(dir, "POSCAR_1")) > 0
       end
true
```

VASP-5+ format (the species-symbols line was added at v4→v5; that format is unchanged through VASP 6).

## A whole enumeration as a tarball

[`write_enumeration_archive`](@ref) writes every structure into a single `.tar.gz` containing all the POSCARs plus a TOML manifest mapping `structure_id ↔ poscar_filename`:

```jldoctest poscar_recipe
julia> mktempdir() do dir
           path = write_enumeration_archive(dir, e; super_periodic = false,
                                            label = "ag-pt-4-4-n8")
           startswith(basename(path), "enumlib_ag-pt-4-4-n8_") &&
               endswith(path, ".tar.gz")
       end
true
```

Passing a **directory** auto-names the tarball
`enumlib_<label>_<yyyy-mm-ddTHH-MM-SS>.tar.gz`, so repeated runs cannot collide.
Pass a path ending in `.tar.gz` instead and it is written exactly there.

### Species symbols

If your `Sites` was constructed with atomic-symbol labels (`Sites(p, [:Ag, :Pt])`, see [Describe substitution sites](describe-substitution-sites.md#atomic-symbol-labels)), `write_enumeration_archive` picks up the mapping automatically — POSCAR line 6 reads `Ag Pt` without any extra kwarg. For integer-labeled Sites, pass `species_symbols = ["Ag", "Pt"]` explicitly. An explicit kwarg always wins over the Sites-derived default.

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

`tagged` is ready to hand off to [JuCE.jl](https://github.com/byu-panda-edu/JuCE.jl) or any other cluster-expansion / MLIP fitter that consumes `(structure, energy)` pairs.

## Right-handedness and other gotchas

- `to_poscar` automatically detects basis matrices with `det(B) < 0` and swaps columns 1↔2 plus the corresponding fractional positions, so the output is always right-handed (VASP requires this).
- The `energy_eV=` slot is the only schema-controlled field the calculator should edit. Future versions may add `forces_eV_per_A=` and `stress_eV_per_A3=` slots; the parser is forward-compatible (unknown header keys are ignored).
- Collaborators who aren't Julia users can fill in `energy_eV=` with any text editor or a short Python/shell script — the header format is intentionally simple.

## See also

- Reference: [`to_poscar`](@ref), [`write_enumeration_archive`](@ref), [`read_results`](@ref), [`attach_results`](@ref), [`EnumeratedStructure`](@ref), [`Enumeration`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md) — usually done first.
- Tutorial: [DFT/MLIP training database](../tutorials/03-dft-training-database.md).
- Explanation: [Algorithm overview](../explanation/algorithm-overview.md).
