# Handle super-periodicity

A *super-periodic* structure is a labeling whose true repeat unit is *smaller* than the supercell — for example, the labeling `[0, 1, 0, 1]` at supercell volume 4 is actually a volume-2 structure repeated twice. Enumlib treats super-periodicity as a **policy kwarg**: `include_superperiodic` defaults to `false` (drop them — the canonical "no duplicates across volumes" view), with `true` available when you want every orbit including the smaller-period ones.

## Setup

```jldoctest sp_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## The default — primitive structures only

```jldoctest sp_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(4:4))   # default policy
19
```

19 truly primitive (aperiodic) labelings at n=4. This is the right answer when you're sweeping a volume range and want each structure to appear *once*, in the smallest supercell that fits it.

## Including super-periodic orbits

```jldoctest sp_recipe
julia> count_inequivalent(p, sites; supercells = VolumeRange(4:4),
                          include_superperiodic = true)
41
```

The extra 22 are labelings whose true period is 1 or 2 — they would already be enumerated at volumes 1 and 2 of a sweep. Useful when:

- You're asking a single-volume question ("how many orbits live on a 2×2×2 supercell?") and want the Burnside-complete answer.
- You're cross-checking against a paper that quotes the raw orbit count.
- You're building training data where having the same structure expressed at multiple supercell sizes is a *feature* (data augmentation, scale-invariance training).

The same kwarg works on `enumerate(...)` directly — pass `include_superperiodic = true` to get back the larger `Enumeration`.

## Asymmetric-concentration trip-wire

At an asymmetric concentration like 1:11 in n=12, no super-periodic structures can exist (1 doesn't divide 12 in any way that makes the labeling periodic). So `include_superperiodic = true` and `false` give **the same count** — the kwarg is a no-op at asymmetric concentrations. This is a useful sanity check: if you flip the kwarg and the count doesn't change, super-periodicity isn't a concern for your case.

## See also

- Reference: [`Base.enumerate`](@ref), [`count_inequivalent`](@ref), [`Enumlib.Polya.aperiodic_orbit_count`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Count without enumerating](count-without-enumerating.md).
- Explanation: [Super-periodicity](../explanation/super-periodicity.md), [Pólya counting](../explanation/polya-counting.md).
