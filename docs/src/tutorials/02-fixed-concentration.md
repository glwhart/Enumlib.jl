# Enumerating at a fixed concentration

[Tutorial 01](01-first-enumeration.md) produced *every* labeling on the chosen supercells. Real materials problems usually want a slice of that space: "exactly 50% A and 50% B," or "between 25% and 50% A." This tutorial covers the [`Concentration`](@ref) and [`ConcentrationRange`](@ref) types and the `concentration` kwarg on [`enumerate`](@ref).

## Setup

Same FCC binary parent as Tutorial 01:

```jldoctest concentration_tutorial
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites(parent, [0, 1]);
```

## A single concentration

Three constructors land on the same `Concentration` value — pick whichever matches how the data arrives at you:

| Constructor | When to use |
|---|---|
| `Concentration([f1, f2, ...])` | You have fractions: `[1//2, 1//2]`. Must sum to 1; use `Rational{Int}` for exactness. |
| `concentration_ratio([a, b, ...])` | You have raw ratios: `[1, 3]` → `[1//4, 3//4]`. Divides through by the sum. |
| `concentration_count([n1, n2, ...]; n_total = N)` | You have anchored counts: "3 A and 9 B atoms in a 12-cell" → `[1//4, 3//4]`. Validates `sum == n_total`. |

```jldoctest concentration_tutorial
julia> Concentration([1//4, 3//4])
Concentration(1//4, 3//4)

julia> concentration_ratio([1, 3])
Concentration(1//4, 3//4)

julia> concentration_count([3, 9]; n_total = 12)
Concentration(1//4, 3//4)
```

All three are equivalent. The `concentration_count` form is the most common in practice because it documents *the supercell size you committed to* alongside the composition.

## Enumerating at a single concentration

Pass the `Concentration` as the `concentration` kwarg. The chunk-6 reference value: FCC binary 1:3 at supercell volume 4 yields 7 structures.

```jldoctest concentration_tutorial
julia> c = concentration_count([1, 3]; n_total = 4);

julia> e = enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = c)
Enumeration{3, Vector{Int8}} (7 structures, 7 supercells, 1 site)
  parent: 48-op space group, 1-element dset
```

Every emitted structure has exactly 1 atom of species 0 and 3 atoms of species 1:

```jldoctest concentration_tutorial
julia> all(count(==(0), to_labeling(s)) == 1 for s in e)
true

julia> all(count(==(1), to_labeling(s)) == 3 for s in e)
true
```

The canonical chunk-6 reference for the harder 4:4 case (binary at n=8) is 94 structures:

```jldoctest concentration_tutorial
julia> c44 = concentration_count([4, 4]; n_total = 8);

julia> length(enumerate(parent, sites; supercells = VolumeRange(8:8), concentration = c44))
94
```

## Divisibility — when a concentration doesn't fit

A fixed `Concentration` requires *integer counts at every supercell size you enumerate over*. For example, `[1//3, 2//3]` on a volume-4 supercell would need 4/3 of species 0 — impossible.

```jldoctest concentration_tutorial
julia> c_third = Concentration([1//3, 2//3]);

julia> multiplicities(c_third, 6)    # n_total = 6 → 2 of A, 4 of B → ok
2-element Vector{Int64}:
 2
 4

julia> try
           multiplicities(c_third, 4)    # n_total = 4 → would need 4/3 of A
       catch err
           err isa EmptyEnumerationError ? "EmptyEnumerationError (concentration doesn't divide)" : rethrow()
       end
"EmptyEnumerationError (concentration doesn't divide)"
```

[`enumerate`](@ref) skips supercell volumes where the concentration doesn't fit cleanly. So `VolumeRange(3:6)` with `[1//3, 2//3]` only enumerates on volumes 3 and 6 (multiples of 3); volumes 4 and 5 produce nothing.

## A range of concentrations

[`ConcentrationRange`](@ref) accepts a lower/upper bound for each species' fraction. The enumerator sweeps every concentration *inside* the range that produces integer counts at each supercell volume. To suppress the binary-symmetric label-exchange image (Enumlib does **not** auto-collapse it), bound the range tighter — here we restrict to the `[0, 1/2]` × `[1/2, 1]` corner:

```jldoctest concentration_tutorial
julia> cr = ConcentrationRange([(0//1, 1//2), (1//2, 1//1)])
ConcentrationRange((0//1, 1//2), (1//2, 1//1))

julia> concentrations_in_range(cr, 4)
3-element Vector{Concentration}:
 Concentration(0//1, 1//1)
 Concentration(1//4, 3//4)
 Concentration(1//2, 1//2)
```

Then [`enumerate`](@ref) returns the union of structures across all in-range concentrations:

```jldoctest concentration_tutorial
julia> length(enumerate(parent, sites;
                         supercells = VolumeRange(4:4),
                         concentration = cr))
12
```

## Breakdown by volume / concentration / HNF

[`count_inequivalent`](@ref) with `breakdown = true` returns an [`InequivalentCount`](@ref) carrying per-volume, per-concentration, and per-HNF totals — useful for sizing the request before running it:

```jldoctest concentration_tutorial
julia> ic = count_inequivalent(parent, sites;
                                supercells = VolumeRange(4:4),
                                concentration = cr,
                                breakdown = true);

julia> ic.total
12

julia> ic.by_concentration
3-element Vector{Tuple{Concentration, BigInt}}:
 (Concentration(0//1, 1//1), 0)
 (Concentration(1//4, 3//4), 7)
 (Concentration(1//2, 1//2), 5)
```

`12 = 0 + 7 + 5`. The 0 at concentration `0//1, 1//1` (pure species 1) reflects the default super-periodicity policy: the all-B labeling on the volume-4 supercell is a periodic replica of the all-B labeling on volume 1, so it's dropped. Pass `include_superperiodic = true` to keep it.

## Where to go next

- **Ship the structures to a DFT calculator**: [Tutorial 03 — Generating a DFT/MLIP training database](03-dft-training-database.md).
- **Multi-element parents** (HCP, diamond, ...): [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).
- **Decide what concentration to even use**: [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md) — recipe-level guidance.
- **Estimate before running**: [Count without enumerating](../how-to/count-without-enumerating.md), [Estimate the cost](../how-to/estimate-cost.md).
