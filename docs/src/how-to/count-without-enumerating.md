# Count without enumerating

Use [`count_inequivalent`](@ref) when you want to know "how many structures *would* I get" without paying to materialize them. Internally this is Pólya / Burnside math — orbit counting via cycle structures — so the cost is `O(|G| · n)` per supercell. Sub-second across the chunk-6 / chunk-7 corpus, even at sizes where the matching `enumerate(...)` call would take minutes.

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
