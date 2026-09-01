# Count without enumerating

Use [`count_inequivalent`](@ref) when you want to know "how many structures *would* I get" without actually generating them. Instead of building every coloring and throwing away the duplicates, it works out how many distinct ones there must be directly from the supercell's symmetry group — the [Pólya count](../explanation/glossary.md#Pólya-count), an application of [Burnside's lemma](../explanation/glossary.md#Burnside's-lemma), unpacked in [Pólya counting](../explanation/polya-counting.md). The cost is `O(|G| · n)` per supercell: sub-second across the full reference corpus, even at sizes where the matching `enumerate(...)` call would take minutes.

That makes it the natural **pre-flight check**: run it first, look at the number, then decide whether to enumerate, narrow the volume range, or add a concentration constraint. The count is exact, not an estimate — it matches `length(enumerate(...))` for the same arguments.

## Setup

```jldoctest count_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## A single number

```jldoctest count_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(4:4))   # FCC binary, n=4
19

julia> count_inequivalent(p, sites; supercells = VolumeRange(12:12)) # the canonical n=12 reference
7140
```

The matching `length(enumerate(...))` calls would return the same numbers — but `enumerate` actually allocates the structures, while `count_inequivalent` is closed-form.

## A breakdown across volumes

Pass `breakdown = true` to get an [`InequivalentCount`](@ref) with per-volume and per-HNF breakdowns:

```jldoctest count_recipe
julia> ic = count_inequivalent(p, sites; supercells = VolumeRange(2:6), breakdown = true);

julia> ic.total
135

julia> ic.by_volume                                                  # sorted (n, count) tuples
5-element Vector{Tuple{Int64, BigInt}}:
 (2, 2)
 (3, 6)
 (4, 19)
 (5, 28)
 (6, 80)
```

`ic.by_hnf` carries one `(hnf, count)` entry per inequivalent HNF — useful for diagnosing which supercells dominate the structure count.

Reading `by_volume` before enumerating is the cheapest way to find where a volume sweep turns expensive: the per-volume count typically grows by a large factor per step, so the last volume in the range usually dominates the total.

## Heterogeneous `Sites`

When each sublattice carries its own species — zinc-blende, half/full Heusler, perovskite, or any site pinned to a single label — the count is computed with the *label-restricted* Pólya formulas, which intersect `allowed_labels` across each orbit rather than assuming every position is free over all `k` species. Nothing about the call changes; the dispatch is automatic.

Zinc-blende: an FCC parent with a binary cation sublattice at the origin and a binary anion sublattice at `(¼, ¼, ¼)`.

```jldoctest count_recipe
julia> zb = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                          [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]]);

julia> zb_sites = Sites([Site([0.0,  0.0,  0.0 ], [0, 1]),    # cations
                          Site([0.25, 0.25, 0.25], [2, 3])]); # anions
```

Heterogeneous sublattices require a `concentration` — Enumlib refuses *unrestricted* enumeration on them (see [Enumerate on a multilattice parent](enumerate-multilattice.md)). "No constraint" is spelled as a [`ConcentrationRange`](@ref) that leaves every species free:

```jldoctest count_recipe
julia> free4 = ConcentrationRange([(0//1, 1//1) for _ in 1:4]);

julia> [count_inequivalent(zb, zb_sites; supercells = VolumeRange(n:n),
                            concentration = free4) for n in 1:4]
4-element Vector{BigInt}:
   4
  11
  52
 290
```

Those are the numbers `enumerate` produces, not an upper bound on them:

```jldoctest count_recipe
julia> length(enumerate_structures(zb, zb_sites; supercells = VolumeRange(3:3), concentration = free4))
52
```

Sizing a run that spans several volumes is one call:

```jldoctest count_recipe
julia> count_inequivalent(zb, zb_sites; supercells = VolumeRange(1:4), concentration = free4)
357
```

!!! note "Per-site allowed labels change the count"
    Treating each position as free over all four labels would give 16, 204, 2960, and 64196 at these volumes instead of 4, 11, 52, and 290. [`estimate_cost`](@ref) prices a run with the same count, so the restriction is what keeps the resource check from refusing a request that is actually small. See [Pólya counting](../explanation/polya-counting.md) for the math.

## Unconstrained ranges and `by_concentration`

A `ConcentrationRange` covering `[0, 1]` for every species constrains nothing, so `count_inequivalent` collapses it to a single Burnside evaluation instead of walking every composition. The total is exact either way — every coloring has exactly one concentration — but the per-concentration breakdown is not materialized:

```jldoctest count_recipe
julia> free2 = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)]);

julia> ic_free = count_inequivalent(p, sites; supercells = VolumeRange(4:4),
                                     concentration = free2, breakdown = true);

julia> ic_free.total
19

julia> ic_free.by_concentration       # empty: the walk that would fill it is what we skipped
Tuple{Concentration, BigInt}[]
```

Pass a narrower range when you want that slice. Here the same 19 structures come back split three ways:

```jldoctest count_recipe
julia> ic_band = count_inequivalent(p, sites; supercells = VolumeRange(4:4),
                                     concentration = ConcentrationRange([(1//4, 3//4), (1//4, 3//4)]),
                                     breakdown = true);

julia> ic_band.by_concentration
3-element Vector{Tuple{Concentration, BigInt}}:
 (Concentration(1//4, 3//4), 7)
 (Concentration(1//2, 1//2), 5)
 (Concentration(3//4, 1//4), 7)
```

`total`, `by_volume`, and `by_hnf` are unaffected by the collapse. The shortcut is internal to `count_inequivalent`; [`enumerate`](@ref) still decomposes an unconstrained range into partitions, because it has to produce the structures — see [Sweep concentration ranges](sweep-concentration-ranges.md) for the partition gate that governs it.

## Super-periodic policy

By default, `count_inequivalent` reports the **primitive** (aperiodic) count — orbits whose stabilizer in the supercell's translation group is trivial. Pass `include_superperiodic = true` to get the raw Burnside count, which includes orbits that are actually derivatives of *smaller* supercells:

```jldoctest count_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(4:4))                          # primitive only
19

julia> count_inequivalent(p, sites; supercells = VolumeRange(4:4), include_superperiodic = true)  # all orbits
41
```

The 22 extra structures at n=4 are the super-periodic orbits — labelings whose true period divides 4. See [Handle super-periodicity](handle-super-periodicity.md) for when each branch is right.

## See also

- Reference: [`count_inequivalent`](@ref), [`InequivalentCount`](@ref), [`Enumlib.Polya.polya_count`](@ref), [`Enumlib.Polya.aperiodic_orbit_count`](@ref).
- How-to: [Estimate the cost of an enumeration](estimate-cost.md), [Handle super-periodicity](handle-super-periodicity.md), [Pick an algorithm](pick-an-algorithm.md).
- Explanation: [Pólya counting](../explanation/polya-counting.md), [Super-periodicity](../explanation/super-periodicity.md).
