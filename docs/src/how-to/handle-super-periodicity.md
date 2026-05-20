# Handle super-periodicity

A *super-periodic* structure is a labeling whose true repeat unit is *smaller* than the supercell. Said another way, the unit cell has a translation symmetry that is smaller than the periodicity of the supercell itself. For example, for a one dimensional lattice, the labeling `[0, 1, 0, 1]` at supercell volume 4 is actually a volume-2 structure repeated twice.

Enumlib treats super-periodicity as a **policy kwarg**: `include_superperiodic`. The default is `false`; pass `true` when you want the alternative. Both settings are duplicate-free *under the definition that fits your problem*. Two scenarios make this concrete:

- **Sweeping a volume range** (the common case — `VolumeRange(1:N)`). With `include_superperiodic = false` (default), each *physical* structure appears exactly once across the entire sweep, in the smallest supercell volume that can host it. The `[0, 1, 0, 1]` example above is enumerated at volume 2 (as `[0, 1]`) and not re-emitted at volume 4. From the sweep's perspective, the volume-4 copy *is* the duplicate, and the default drops it.
- **A single fixed volume** (`VolumeRange(4:4)`, say). With `include_superperiodic = true`, you get every orbit that lives on a volume-4 supercell, including `[0, 1, 0, 1]`. Nothing is duplicated *within that volume*; the count is just larger than the aperiodic-only count because the "smaller true period" labelings are now allowed. This is the right answer when you're asking "how many distinct decorations of this specific cell exist?" or when you're cross-checking against a paper that quotes the complete Burnside orbit count.

So the choice is about which question you're asking — the sweep question (default, `false`) or the fixed-cell question (`true`) — not about counting structures more or less than once.

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

The extra 22 are labelings whose true period is 1 or 2 — they would already be enumerated at volumes 1 and 2 of a sweep. It is useful to include the extra labelings when:

- You're asking a single-volume question ("how many configurations live on a 2×2×2 supercell?") and want the complete answer (including, for example, the pure A and pure B configurations)
- You're cross-checking against a paper that quotes the complete count.


The same kwarg works on `enumerate(...)` directly — pass `include_superperiodic = true` to get back the larger `Enumeration`.

## Asymmetric-concentration trip-wire

At an asymmetric concentration like 5:7 in n=12, no super-periodic structures can exist. 5 doesn't divide 12 evenly; no way to make the labeling periodic. So, for a fixed 5:7 concentration, `include_superperiodic = true` and `false` give **the same count** — the kwarg has no effect asymmetric concentrations. This is a useful sanity check: if you flip the kwarg and the count doesn't change, super-periodicity isn't a concern for your case.

## See also

- Reference: [`Base.enumerate`](@ref), [`count_inequivalent`](@ref), [`Enumlib.Polya.aperiodic_orbit_count`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Count without enumerating](count-without-enumerating.md).
- Explanation: [Super-periodicity](../explanation/super-periodicity.md), [Pólya counting](../explanation/polya-counting.md).
