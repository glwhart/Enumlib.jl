# Enumerate on a multilattice parent (HCP, diamond, ...)

When the parent isn't a single-site Bravais lattice, it carries a **dset** — two or more basis sites per primitive cell. HCP (2 atoms), diamond (2 atoms), zincblende (2 atoms), perovskite ABO₃ (5 atoms), etc. Two cases:

- **Uniform sublattices** (every dset position carries the same allowed labels). Shipped in R50.2 (v0.2-era) via the HF 2009 multilattice extension. Unrestricted enumeration via [`enumerate(parent, sites; supercells)`] just works.
- **Heterogeneous sublattices** (different allowed labels per dset position — perovskite-style A-site cation mixing while B-site stays fixed, etc.). Shipped in chunk 6.5b via the `:recursive_stabilizer` algorithm with a site-mask filter. Requires a [`Concentration`](@ref) or [`ConcentrationRange`](@ref) kwarg (unrestricted heterogeneous enumeration isn't supported — Regime C only makes sense at fixed concentration).

## Setup — HCP binary

```jldoctest mlat_recipe
julia> using Enumlib

julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);  # 2-site dset

julia> sites = Sites(p, [0, 1]);   # binary, applied uniformly to both dset positions

julia> ndset(p)
2
```

## Enumerate

Same call shape as the single-site case — the dispatcher detects the multilattice regime and routes through HF 2009:

```jldoctest mlat_recipe
julia> e = enumerate(p, sites; supercells = VolumeRange(1:4));

julia> length(e)
333
```

The per-volume breakdown matches the Fortran enumlib reference values (full mode, no label-exchange elimination, drops super-periodic colorings — Enumlib's default):

```jldoctest mlat_recipe
julia> [length(enumerate(p, sites; supercells = VolumeRange(n:n))) for n in 1:6]
6-element Vector{Int64}:
    3
   10
   50
  270
  651
 4793
```

## Count without enumerating

[`count_inequivalent`](@ref) gives the same numbers via Pólya / Burnside; useful as a sanity check or for sizing a request before running it:

```jldoctest mlat_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(1:4))
333
```

## Diamond — FCC + 2-atom dset

Same recipe; only the parent changes:

```jldoctest mlat_recipe
julia> fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0];

julia> p_d = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]]);

julia> s_d = Sites(p_d, [0, 1]);

julia> [length(enumerate(p_d, s_d; supercells = VolumeRange(n:n))) for n in 1:4]
4-element Vector{Int64}:
   3
   7
  33
 171
```

## Site-ordering convention (so labelings make sense)

The labeling vector on a multilattice supercell has length `n_D · n`, where `n_D = ndset(parent)` and `n = volume(hnf)`. Sites are ordered in **dset blocks**: positions `1..n` are the `n` Bravais sites at dset position 1; positions `n+1..2n` are the same Bravais sites at dset position 2; and so on. This matches the convention used by the supercell permutation group.

So for HCP at `n = 2` (4-site labeling), labeling `[0, 0, 1, 1]` means "dset position 1 is pure species 0, dset position 2 is pure species 1" — an A-B layered structure.

## Write POSCARs for DFT

[`to_poscar`](@ref) and [`write_enumeration_archive`](@ref) both work without modification — the writer follows the same dset-blocks ordering above when emitting the `Direct` coordinates block.

```julia
using Enumlib

A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
sites = Sites(p, [0, 1])
e = enumerate(p, sites; supercells = VolumeRange(1:4))

# One POSCAR
open("POSCAR_001", "w") do io
    to_poscar(io, e[1], p, e.supercells[e[1].supercell_id].hnf;
              super_periodic = false,
              species_symbols = ["Ti", "V"],
              enumlib_id = 1)
end

# Or the whole batch as a tarball
write_enumeration_archive("hcp-ti-v", e;
                          super_periodic = false,
                          species_symbols = ["Ti", "V"],
                          label = "HCP_TiV_n1-4")
```

A representative HCP `n = 2` POSCAR looks like:

```
# enumlib_id=1 hnf=1 concentration=3:1 super_periodic=false energy_eV=
1.0
        1.000000000000        0.000000000000        0.000000000000
       -0.500000000000        0.866025403784        0.000000000000
        0.000000000000        0.000000000000        3.265986323711
Ti V
3 1
Direct
        0.000000000000        0.000000000000        0.000000000000
        0.000000000000        0.000000000000        0.500000000000
        0.333333333333        0.666666666667        0.250000000000
        0.333333333333        0.666666666667        0.750000000000
```

Four atoms: dset block 1 positions (the two Bravais sites at origin) then dset block 2 positions (the two Bravais sites offset by the dset's second entry).

## Heterogeneous sublattices (Regime C)

When the dset positions carry **different** allowed labels — perovskite A-site mixing, single-sublattice substitution in a multilattice host, etc. — supply a `concentration` kwarg. The dispatcher routes through `:recursive_stabilizer` with a site-mask filter (chunk 6.5b).

```jldoctest mlat_recipe_c
julia> using Enumlib

julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);

julia> sites_het = Sites([
           Site([0.0, 0.0, 0.0],         [0, 1]),   # sublattice 1: binary
           Site([1/3, 2/3, 1/2],         [0]),      # sublattice 2: fixed
       ]);

julia> # 4-site supercell at n=2; concentration is per-color counts over the
       # full labeling (sublattice-2 fixed positions count toward species 0):
       c = concentration_count([3, 1]; n_total = 4);

julia> length(enumerate(p, sites_het; supercells = VolumeRange(2:2), concentration = c))
3
```

Without `concentration`, Regime C throws an `ArgumentError`: "Multilattice with per-site `allowed_labels` (Regime C — heterogeneous sublattices) requires a `concentration` kwarg." That's the gate working as designed — unrestricted enumeration on heterogeneous sublattices isn't a defined problem; you need a fixed composition to enumerate around.

## When the gate rejects your inputs

Two regime-discrimination errors you may hit:

- **`Sites` length ≠ `ndset(parent)`.** With `ndset(p) = 2` you need a 2-entry `Sites`. The shorthand `Sites(p, [0, 1])` constructs one per dset position automatically (uniform case only).
- **Heterogeneous `allowed_labels` without `concentration`.** As above — supply a `Concentration` or `ConcentrationRange`.
- **`algorithm = :multinomial_restricted`.** Reserved for chunk 6.5a; throws until that ships. Use `:recursive_stabilizer` (or `:auto`, which picks it automatically for Regime C).

## See also

- Reference: [`ParentLattice`](@ref), [`Sites`](@ref), [`enumerate`](@ref), [`count_inequivalent`](@ref), [`to_poscar`](@ref), [`write_enumeration_archive`](@ref).
- How-to: [Construct a parent lattice](construct-a-parent-lattice.md), [Describe substitution sites](describe-substitution-sites.md), [Write POSCARs for DFT](write-poscars-for-dft.md).
- Explanation: [Algorithm overview](../explanation/algorithm-overview.md#multilattice-extension) — the HF 2009 multilattice extension at a conceptual level.
