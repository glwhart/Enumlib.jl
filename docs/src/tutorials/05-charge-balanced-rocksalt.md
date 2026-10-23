# Charge-balanced rocksalt superstructures

Ionic superstructures obey two charge conditions. The structure as a whole is neutral, and, by Pauling's electrostatic valence rule, the cation charges around each anion balance that anion's charge. D. N. Bublikov's combinatorial model of NaCl-type superstructures (*Crystallography Reports* **56**, 89–100 (2011); code at [dmitry-bublikov/NaCl-superstructure-simulator](https://github.com/dmitry-bublikov/NaCl-superstructure-simulator)) enumerates cation orderings that satisfy both. This tutorial reproduces his NaFeO₂ example: the global condition is built into Enumlib, and the local one is a few lines of filtering on the result.

## What you'll build

- A rocksalt parent with Na⁺ and Fe³⁺ on the cation sublattice and O²⁻ fixed on the anion sublattice.
- A [`ConcentrationRange`](@ref) carrying charges, so only neutral compositions are enumerated.
- A Pauling-rule filter applied to the symmetry-distinct structures, which picks out the layered α-NaFeO₂ ordering.
- Bublikov's fixed 32-cation cube, and a comparison with his counts.

## Setup

Rocksalt is fcc with two sites per primitive cell, the cation at the origin and the anion half a body diagonal away:

```jldoctest rocksalt
julia> using Enumlib, LinearAlgebra

julia> A = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0];    # fcc primitive vectors (columns), a = 1

julia> parent = ParentLattice(A, [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5]]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [:Na, :Fe]),     # cation sublattice
                      Site([0.5, 0.5, 0.5], [:O])]);          # anion sublattice, fixed

julia> species_symbols(sites)
3-element Vector{Symbol}:
 :Na
 :Fe
 :O
```

`species_symbols` gives the label order: Na is label 0, Fe label 1, O label 2. Each structure's `labeling` uses these labels.

## Step 1 — only neutral compositions

`ConcentrationRange(sites; charges)` is the full composition range over the species of `sites`, restricted to neutral ones, with a charge for each element. NaFeO₂ needs `n(Na) + 3 n(Fe) = 2 n(O)`:

```jldoctest rocksalt
julia> cr = ConcentrationRange(sites; charges = Dict(:Na => 1, :Fe => 3, :O => -2));

julia> [count_inequivalent(parent, sites; supercells = VolumeRange(n:n), concentration = cr) for n in 1:8]
8-element Vector{BigInt}:
  0
  2
  0
  5
  0
 20
  0
 94
```

With oxygen filling every anion site, neutrality forces Na:Fe = 1:1, which is impossible in a cell with an odd number of cations. The even-cell counts are the familiar fcc 1:1 binary counts — 94 at eight cations is the Hart–Forcade value — because the anion sublattice is fixed and the cation sublattice is fcc. Without `charges` the same cells hold every composition, 631 structures in all; the filter removes them before any coloring is built. For integer labels, give the charges as a vector in label order instead: `ConcentrationRange(3; charges = [1, 3, -2])` is the same range.

```jldoctest rocksalt
julia> e = enumerate_structures(parent, sites; supercells = VolumeRange(1:8), concentration = cr);

julia> length(e)
121
```

## Step 2 — Pauling's rule as a filter

Each O²⁻ has six cation neighbors at distance `a/2`, and the rule asks that their charges sum to +12. The rule depends on positions, so it is a property of each structure rather than of its composition. It is also unchanged by every symmetry operation of the parent, so a representative passes exactly when every structure equivalent to it does: filtering the enumerated representatives loses nothing.

The filter builds each supercell's Cartesian site positions and counts every periodic image within reach, so that a small cell, where one cation can be several of an anion's neighbors, is handled correctly:

```jldoctest rocksalt
julia> charge = [1, 3, -2];                 # by label: Na, Fe, O

julia> function pauling_balanced(s, e)
           h = e.supercells[s.supercell_id].hnf
           L = A * h.matrix                                     # supercell vectors
           frac = site_positions(h, parent)
           n = length(frac) ÷ 2                                  # cations first, then anions
           cart = [L * collect(f) for f in frac]
           images = [L * [i, j, k] for i in -2:2 for j in -2:2 for k in -2:2]
           all(1:n) do a
               sum(charge[s.labeling[c] + 1] for c in 1:n for t in images
                   if isapprox(norm(cart[c] + t - cart[n + a]), 0.5; atol = 1e-6)) == 12
           end
       end;

julia> good = filter(s -> pauling_balanced(s, e), e.structures);

julia> [volume(e.supercells[s.supercell_id].hnf) for s in good]
7-element Vector{Int64}:
 2
 4
 6
 6
 8
 8
 8
```

Seven of the 121 neutral structures are locally balanced. The smallest, at two cations, is the ordering in alternating (111) layers: α-NaFeO₂, the parent of the layered LiCoO₂-type cathodes. Every O²⁻ sits between a Na layer and an Fe layer and sees three of each, 3 + 9 = 12. The other two-cation ordering, alternating (001) layers, is neutral but fails: an O²⁻ in a Na layer sees four Na⁺ in its own layer and two Fe³⁺ above and below, a total of 10.

## Step 3 — Bublikov's 32-cation cube

Bublikov works on one fixed cell, the 2a × 2a × 2a cube with 32 cation and 32 anion sites. In Enumlib that cell is a single HNF of index 32:

```jldoctest rocksalt
julia> cube = HNF{3}([2 0 0; 2 4 0; 2 0 4]);

julia> A * cube.matrix                 # columns span 2x̂, 2ŷ, 2ẑ: the cube
3×3 Matrix{Float64}:
 2.0  2.0  2.0
 2.0  0.0  2.0
 2.0  2.0  0.0
```

The columns differ by 2x̂, 2ŷ and 2ẑ, and the determinant is 8 = (2a)³. Select the cell with [`ExplicitHNFs`](@ref). Bublikov's orderings include ones that also fit a smaller cell, so pass `include_superperiodic = true`. The count below is exact but takes about 40 s, so it is shown rather than run:

```julia
count_inequivalent(parent, sites; supercells = ExplicitHNFs([cube]),
                   concentration = concentration_count([16, 16, 32]; n_total = 64),
                   include_superperiodic = true)
# 404582
```

There are 404,582 symmetry-distinct Na₁₆Fe₁₆ orderings of the cube, and Pauling's rule keeps 5 of them. Bublikov's programs give the same 5, and the same 140 for the total number of locally balanced orderings counted without symmetry. His Li/Mg/Fe oxides on the same cube agree as well: for Li₄Mg₂₄Fe₄O₃₂, Li₆Mg₂₀Fe₆O₃₂, Li₈Mg₁₆Fe₈O₃₂, Li₁₀Mg₁₂Fe₁₀O₃₂ and Li₁₂Mg₈Fe₁₂O₃₂, both programs find 3, 3, 9, 7 and 9 distinct structures (120, 480, 1620, 2112 and 1200 orderings). Enumerating 404,582 structures to keep 5 is slow; for cells this size the comparison test in `test/test_bublikov_cf32.jl` searches with the local rule applied site by site and then uses Enumlib's symmetry operations of the cube to merge equivalent orderings.

Our counts treat mirror images as the same structure, since the rocksalt point group contains improper operations. Bublikov's programs detect mirror pairs separately and keep one of each, which gives the same totals.

## What you've learned

1. **Global neutrality** is a filter on compositions: `ConcentrationRange(k; charges)` passes only neutral multiplicity vectors, and enumeration, counting and the cost estimate all see the shorter list.
2. **Local rules** such as Pauling's depend on positions, so they are applied to the enumerated structures. Because they are unchanged by the parent's symmetry, filtering representatives is exact.
3. **A fixed cell** is `ExplicitHNFs([h])` with `include_superperiodic = true`.

## Where to go next

- [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md) explains why neutrality depends only on the composition.
- [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md) covers `ConcentrationRange` bounds and the partition-count limit.
- [Tutorial 03](03-dft-training-database.md) turns the seven balanced structures into POSCARs for DFT.
