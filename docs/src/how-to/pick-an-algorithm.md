# Pick an algorithm

`enumerate` ships with three concentration-aware algorithms plus an `:auto` dispatcher that picks for you. In most cases, **leave `algorithm = :auto`** — it makes the right call and you save reading the rest of this page.

## Setup

```jldoctest alg_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## What `:auto` decides

| Inputs | `:auto` picks | Why |
|---|---|---|
| No `concentration` kwarg | `:exhaustive` (HF 2008) | Visit every k^n labeling; mark symmetry orbits as you go. Right when there's no concentration constraint. |
| `concentration` supplied **and** the multinomial bitmap fits in `memory_budget × 0.8` | `:multinomial` (HF 2012) | Mixed-radix hash into a `[0, C-1]` bitmap; cross out orbits. Memory-bounded but fast. |
| `concentration` supplied **but** the multinomial bitmap won't fit | `:recursive_stabilizer` (Morgan 2017) | Tree search with shrinking stabilizers; streams structures (no bitmap). Memory-cheap. |

You can see what `:auto` chose by calling [`estimate_cost`](@ref) — its `chosen_algorithm` field is the dispatch result:

```jldoctest alg_recipe
julia> c = concentration_count([4, 4]; n_total = 8);

julia> est = estimate_cost(p, sites; supercells = VolumeRange(8:8), concentration = c);

julia> est.chosen_algorithm                          # small case: bitmap easily fits
:multinomial
```

## When to override

The override (`algorithm = :exhaustive | :multinomial | :recursive_stabilizer`) is for cases where `:auto`'s rule misses a special concern of yours. Three motivations:

1. **You want the bitmap explicitly** for reproducibility against earlier runs:
   ```
   algorithm = :multinomial
   ```
2. **You want the tree** for systems with high configurational freedom even when the bitmap would fit — the tree's per-structure cost is sometimes lower at large n × k:
   ```
   algorithm = :recursive_stabilizer
   ```
3. **You want the unrestricted enumeration even though you supplied a `concentration`** — `:exhaustive` ignores the `concentration` kwarg, which is occasionally useful for cross-checks.

For both `:multinomial` and `:recursive_stabilizer`, the `concentration` kwarg is **required** (the algorithms are concentration-restricted by design):

```jldoctest alg_recipe
julia> est = estimate_cost(p, sites; supercells = VolumeRange(8:8),
                           concentration = c, algorithm = :recursive_stabilizer);

julia> est.chosen_algorithm                          # explicit override sticks
:recursive_stabilizer
```

## See also

- Reference: [`Base.enumerate`](@ref), [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`Enumlib.Polya.polya_count`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Estimate the cost of an enumeration](estimate-cost.md), [Sweep concentration ranges](sweep-concentration-ranges.md).
- Explanation: [Dispatch and the cost gate](../explanation/dispatch-and-cost-gate.md), [Algorithm overview](../explanation/algorithm-overview.md).
