# Enumerate on a multilattice parent (HCP, diamond, ...)

When the parent isn't a single-site Bravais lattice, it carries a **dset** — two or more basis sites per primitive cell. For example, HCP (2 atoms/cell), diamond (2 atoms), zincblende (2 atoms), perovskite ABO₃ (5 atoms), etc. Two cases:

- **Uniform sublattices** (every dset position carries the same allowed labels) — handled by the HF 2009 multilattice extension. Unrestricted enumeration via [`enumerate_structures(parent, sites; supercells)`] just works.
- **Heterogeneous sublattices** (different allowed labels per dset position — perovskite-style A-site cation mixing while B-site stays fixed, etc.) — handled by `:recursive_stabilizer` with a site-mask filter. Requires a [`Concentration`](@ref) or [`ConcentrationRange`](@ref) kwarg (unrestricted heterogeneous enumeration isn't supported — Regime C only makes sense at fixed concentration).

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
julia> e = enumerate_structures(p, sites; supercells = VolumeRange(1:4));

julia> length(e)
333
```

The per-volume breakdown matches the Fortran enumlib reference values (full mode, no label-exchange elimination, drops super-periodic colorings — Enumlib's default):

```jldoctest mlat_recipe
julia> [length(enumerate_structures(p, sites; supercells = VolumeRange(n:n))) for n in 1:6]
6-element Vector{Int64}:
    3
   10
   50
  270
  651
 4793
```

## Count without enumerating

[`count_inequivalent`](@ref) gives the same numbers via Pólya / Burnside; useful as a sanity check or for sizing a request before running it. Same shape as the `enumerate` calls above:

```jldoctest mlat_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(1:4))
333

julia> [count_inequivalent(p, sites; supercells = VolumeRange(n:n)) for n in 1:6]
6-element Vector{BigInt}:
    3
   10
   50
  270
  651
 4793
```

## Boron-doped diamond — FCC + 2-atom dset

A real-world Regime B example: B-doped diamond. Diamond is the FCC parent
with a 2-atom dset; in B-doped diamond, **both** sublattices can carry
either C or B (they're crystallographically equivalent and synthesis
puts B on either one), so the uniform-sublattice constructor applies.

```jldoctest mlat_recipe
julia> fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0];

julia> p_d = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]]);

julia> s_d = Sites(p_d, [0, 1]);   # label 0 = C, label 1 = B (uniform on both sublattices)

julia> [length(enumerate_structures(p_d, s_d; supercells = VolumeRange(n:n))) for n in 1:4]
4-element Vector{Int64}:
   3
   7
  33
 171
```

The `Sites` API uses integer labels (`0`, `1`, ...) — atomic symbols
like `"C"` and `"B"` are attached at POSCAR output time via
[`to_poscar`](@ref)'s `species_symbols=["C", "B"]` kwarg, not in the
`Sites` constructor. The integer label is what the enumerator
manipulates; the chemistry mapping is a presentation concern.

## Site-ordering convention (so labelings make sense)

The labeling vector (list of which atoms on which sites) on a multilattice supercell has length `n_D · n`, where `n_D = ndset(parent)` and `n = volume(hnf)`. Sites are ordered in **dset blocks**: positions `1..n` are the `n` Bravais sites at dset position 1; positions `n+1..2n` are the same Bravais sites at dset position 2; and so on. This matches the convention used by the supercell permutation group.

So for HCP at `n = 2` (4-site labeling), labeling `[0, 0, 1, 1]` means **every** atom on dset position 1 is species 0 and **every** atom on dset position 2 is species 1, regardless of which `n = 2` HNF the supercell uses. The geometric layering (along c, in-plane, etc.) depends on the specific HNF; the species assignment to sublattices doesn't.

## Write POSCARs for DFT

[`to_poscar`](@ref) and [`write_enumeration_archive`](@ref) emit the atomic positions in the same dset-blocks order as the labeling above — sublattice-1 atoms first, then sublattice-2, etc. The POSCAR's per-species count line (line 4+D) groups atoms by species across the whole supercell, so the file is valid VASP regardless of which sublattices each species lives on.

```jldoctest mlat_poscar
julia> using Enumlib

julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);

julia> sites = Sites(p, [0, 1]);

julia> e = enumerate_structures(p, sites; supercells = VolumeRange(1:4));

julia> mktempdir() do dir
           # one POSCAR
           open(joinpath(dir, "POSCAR_001"), "w") do io
               to_poscar(io, e[1], p, e.supercells[e[1].supercell_id].hnf;
                         super_periodic = false,
                         species_symbols = ["Ti", "V"],
                         enumlib_id = 1)
           end
           # or the whole batch as a tarball
           tar = write_enumeration_archive(dir, e;
                                           super_periodic = false,
                                           species_symbols = ["Ti", "V"],
                                           label = "HCP_TiV_n1-4")
           isfile(joinpath(dir, "POSCAR_001")) && endswith(tar, ".tar.gz")
       end
true
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

A common real-world case: only **one** sublattice is being substituted, the others are fixed by chemistry. Two-sublattice examples — zincblende Alₓ Ga₁₋ₓ As, NbS₂ doped with Fe on the Nb sublattice, half-Heuslers. Three-sublattice (perovskite ABO₃) — A-site or B-site mixing while the other cation + the three oxygens stay put.

Supply a `concentration` kwarg and Enumlib enumerates only the colorings consistent with the per-site allowed labels. (Internally it uses the `:recursive_stabilizer` algorithm, filtering colorings as it walks the tree to drop any that put a forbidden species on a restricted sublattice.)

The example below is zincblende AlₓGa₁₋ₓAs: FCC parent with a 2-atom
dset (cation + anion at the diamond-structure positions). With atomic-
symbol labels the chemistry is right there in the code — the cation
sublattice carries `{:Al, :Ga}` and the anion sublattice is fixed to
`{:As}`. The `Sites` constructor builds the integer mapping
(`:Al → 0, :Ga → 1, :As → 2`) in first-seen order for you:

```jldoctest mlat_recipe_c
julia> using Enumlib

julia> fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0];

julia> p = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]]);

julia> sites_het = Sites([
           Site([0.0,  0.0,  0.0 ], [:Al, :Ga]),   # cation sublattice
           Site([0.25, 0.25, 0.25], [:As]),        # anion sublattice — fixed
       ]);

julia> species_symbols(sites_het)
3-element Vector{Symbol}:
 :Al
 :Ga
 :As

julia> # n = 2 supercell has 4 sites = 2 cations + 2 anions. For
       # Al₁Ga₁As₂ at n=2, ask for 1 Al, 1 Ga, 2 As across the
       # 4-atom labeling (concentration is per-label-index, so the
       # mapping above determines the order):
       c = concentration_count([1, 1, 2]; n_total = 4);

julia> length(enumerate_structures(p, sites_het; supercells = VolumeRange(2:2), concentration = c))
2
```

The two inequivalent configurations are the two distinct ways to place
one Al + one Ga on the two cation positions of this `n = 2` supercell
(the anions are always As). [`to_atom_labeling(struc, sites_het)`](@ref)
gives the labelings back as `Vector{Symbol}` after enumeration. When you
write POSCARs via [`write_enumeration_archive`](@ref), the symbol mapping
flows through automatically — no need to repeat `species_symbols=` at
the POSCAR call site. The integer-label form `[0, 1]` / `[2]` is still
accepted if you prefer it; see [Describe substitution sites](describe-substitution-sites.md#atomic-symbol-labels).

## Per-sublattice `Concentration` for Regime C

For Regime C, stating the concentration globally as a flat-vector
`Concentration([f₁, ..., f_k])` requires translating per-sublattice composition
into global fractions, which gets fiddly fast (perovskite ABO₃ at 1:1 A,
1:1 B, fixed O resolves to `Concentration([1//10, 1//10, 1//10, 1//10, 6//10])`
at n=2). The per-sublattice constructor `Concentration(sites, per_sublattice)`
lets you state composition per dset position directly — see the
[Specify concentration per sublattice](specify-per-sublattice-concentration.md)
how-to for the recipe and [Tutorial 04](../tutorials/04-multilattice-per-sublattice.md)
for a walkthrough.

Without `concentration`, Regime C throws an `ArgumentError`: "Multilattice with per-site `allowed_labels` (Regime C — heterogeneous sublattices) requires a `concentration` kwarg." That's the input validation working as designed — unrestricted enumeration on heterogeneous sublattices isn't a defined problem; you need a fixed composition to enumerate around.

## When input validation rejects your inputs

Two regime-discrimination errors you may hit:

- **`Sites` length ≠ `ndset(parent)`.** With `ndset(p) = 2` you need a 2-entry `Sites`. The shorthand `Sites(p, [0, 1])` constructs one per dset position automatically (uniform case only).
- **Heterogeneous `allowed_labels` without `concentration`.** As above — supply a `Concentration` or `ConcentrationRange`.
- **`algorithm = :multinomial_restricted` for Regime A or B.** This algorithm only applies to heterogeneous sublattices (Regime C); for Regime A/B use `:multinomial` or `:recursive_stabilizer` (or `:auto`).

## See also

- Reference: [`ParentLattice`](@ref), [`Sites`](@ref), [`enumerate_structures`](@ref), [`count_inequivalent`](@ref), [`to_poscar`](@ref), [`write_enumeration_archive`](@ref).
- How-to: [Construct a parent lattice](construct-a-parent-lattice.md), [Describe substitution sites](describe-substitution-sites.md), [Write POSCARs for DFT](write-poscars-for-dft.md).
- Explanation: [Algorithm overview](../explanation/algorithm-overview.md#multilattice-extension) — the HF 2009 multilattice extension at a conceptual level.
