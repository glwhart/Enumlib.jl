# Concentration and multiplicity

A concentration is *a vector of fractions*; a multiplicity is *a vector of counts*. The two live one `n_total = n_D · n` factor apart. This page covers how Enumlib's `Concentration` and `ConcentrationRange` types convert between them, the divisibility constraint that drops some supercell volumes silently, and how orbit sizes (`orbit_size`) relate to concentration counts.

## Fractions vs counts

A [`Concentration`](@ref) value carries `Rational{Int}` fractions that sum to 1. To enumerate at that concentration on a supercell with `n_total` sites, Enumlib resolves the fractions to integer counts via [`multiplicities`](@ref):

```
mults = multiplicities(concentration, n_total)   # ::Vector{Int}, sum(mults) == n_total
```

Four constructors land on the same `Concentration`:

| Constructor | Input | Use case |
|---|---|---|
| `Concentration([f₁, f₂, ...])` | Fractions summing to 1 | You already have the composition as fractions. |
| `concentration_ratio([a₁, a₂, ...])` | Raw ratios | You have integers like `[1, 3]` meaning 1 of A per 3 of B; divides by the sum. |
| `concentration_count([n₁, n₂, ...]; n_total = N)` | Anchored counts | You have a specific supercell in mind; validates `sum == n_total`. |
| `Concentration(sites, [[r₁₁, r₁₂, ...], [r₂₁, ...], ...])` | Per-sublattice ratios | Regime C (heterogeneous sublattices). Stating "1:1 on A, 1:1 on B, fixed on O" directly is much less error-prone than computing the global flat-vector by hand. |

They're interchangeable downstream: `enumerate_structures(...; concentration = c)` takes any of them.

## The divisibility constraint

A `Concentration` is *resolvable at a supercell of size `n_total`* iff each fraction times `n_total` is an integer. Equivalently: every fraction's denominator divides `n_total`.

```
Concentration([1//4, 3//4])         # denominators are 4 — needs n_total divisible by 4
Concentration([1//3, 2//3])         # denominators are 3 — needs n_total divisible by 3
Concentration([15//32, 17//32])     # needs n_total divisible by 32
```

When [`enumerate_structures`](@ref) or [`count_inequivalent`](@ref) encounter a `(concentration, n)` pair where the concentration doesn't resolve cleanly, they **skip that volume silently**. So `enumerate_structures(parent, sites; supercells = VolumeRange(3:6), concentration = c_third)` with `c_third = Concentration([1//3, 2//3])` only enumerates on volumes 3 and 6 (multiples of 3); volumes 4 and 5 emit nothing.

This isn't an error — it's the natural semantics ("at this volume, this composition is impossible") and follows from `multiplicities` throwing [`EmptyEnumerationError`](@ref) on non-divisible inputs.

## Multilattice — multiplicity over `n_D · n`

For a multilattice parent with `n_D` dset positions, every supercell carries `n_total = n_D · n` substitutable atoms. Multiplicities are resolved against `n_total`, not `n`:

```
# HCP binary at supercell volume 2: n_total = 2 · 2 = 4 atoms.
multiplicities(Concentration([1//2, 1//2]), 4)   # → [2, 2]
multiplicities(Concentration([1//4, 3//4]), 4)   # → [1, 3]
```

Internally `count_inequivalent`, `estimate_cost`, and the per-concentration enumeration path all resolve against `n_total = n_D · n`, not `n`. The single-lattice case is the degenerate `n_D = 1` case.

## Concentration ranges

[`ConcentrationRange`](@ref) holds per-species `(lower, upper)` bounds. [`concentrations_in_range`](@ref) materializes every [`Concentration`](@ref) inside the range whose fractions resolve cleanly at a given `n_total`:

```jldoctest
julia> using Enumlib

julia> concentrations_in_range(ConcentrationRange([(0//1, 1//1), (0//1, 1//1)]), 4)
5-element Vector{Concentration}:
 Concentration(0//1, 1//1)
 Concentration(1//4, 3//4)
 Concentration(1//2, 1//2)
 Concentration(3//4, 1//4)
 Concentration(1//1, 0//1)
```

For binary 0:1, 1:3, 2:2, 3:1, 1:0 at `n = 4`. Note Enumlib does **not** auto-collapse label-exchange image pairs (the `[1:3]` and `[3:1]` pair, for example) — that's a deliberate design choice (different chemical species so the same composition swapped is a different material). Bound the range tighter — e.g., `(0//1, 1//2)` and `(1//2, 1//1)` — if you want only one half.

The range can decompose into a lot of concentrations at high `n_total`. The [partition-explosion gate](multinomial-2012.md#partition-explosion) caps it via `partition_threshold` (default 100).

## Charge neutrality is a property of the multiplicities

For an ionic parent, give each label a formal charge `qᵢ` (a vacancy is `0`). A labeling is neutral when `Σ aᵢ qᵢ = 0` over its multiplicities `aᵢ`. The condition involves only the counts, never the positions, so every labeling with a given multiplicity vector is neutral or none is. That is why neutrality is a filter on compositions rather than a property of each coloring: `ConcentrationRange(bounds; charges)` drops the non-neutral vectors inside [`concentrations_in_range`](@ref), and everything downstream — enumeration, [`count_inequivalent`](@ref), [`estimate_cost`](@ref), the partition gate — iterates the shorter list. The coloring algorithms never see a charge.

```jldoctest
julia> using Enumlib

julia> concentrations_in_range(ConcentrationRange(2; charges = [1, -1]), 4)
1-element Vector{Concentration}:
 Concentration(1//2, 1//2)
```

The filter knows nothing about sublattices. A neutral multiplicity vector that cannot be placed on the sites — say, more cations than there are cation sites — is kept, and simply yields no colorings, exactly as an ill-fitting vector does without charges.

Global neutrality is the only charge condition Enumlib applies. Local rules, such as Pauling's electrostatic valence rule (the cation charges around each anion sum to that anion's charge times its coordination), depend on positions and so are properties of each coloring. They can be applied to the enumerated representatives afterwards: any such rule is unchanged by the parent's symmetry, so a representative passes exactly when every member of its orbit does. [Tutorial 05](../tutorials/05-charge-balanced-rocksalt.md) does this for rocksalt.

## Orbit size ≠ multiplicity vector

Two unrelated meanings of "multiplicity" live in Enumlib; don't confuse them:

| Quantity | What it measures | Where |
|---|---|---|
| **Multiplicities** | Counts of each species in one labeling, summing to `n_total` | `multiplicities(c, n_total)::Vector{Int}` |
| **Orbit size** (a.k.a. *degeneracy*, *figure degeneracy*) | Number of labelings equivalent to a given one under the supercell's permutation group | `EnumeratedStructure.orbit_size::Int` |

Multiplicity vectors are about *composition* (the macroscopic concentration). Orbit sizes are about *symmetry* (how many physical configurations correspond to one symmetry-inequivalent representative). Both have units of "count," which is why the name collision can confuse — but they answer different questions.

## See also

- [`Concentration`](@ref), [`ConcentrationRange`](@ref), [`multiplicities`](@ref), [`concentrations_in_range`](@ref), [`EmptyEnumerationError`](@ref).
- [Enumerate at fixed concentration](../how-to/enumerate-at-fixed-concentration.md), [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md) — recipes.
- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — the algorithm a fixed concentration unlocks.
- [Tutorial 02 — Enumerating at a fixed concentration](../tutorials/02-fixed-concentration.md).
