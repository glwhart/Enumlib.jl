# Pick an algorithm

In practice, `enumerate` will automatically pick the best algorithm for your request.
`enumerate` ships with three concentration-aware algorithms plus the "original" exhaustive (HF 2008) algorithm that sweeps over all concentrations. In most cases, **leave `algorithm = :auto`** — it makes the right call and you save reading the rest of this page.

## Setup

```jldoctest alg_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## What `:auto` decides

| Inputs | `:auto` picks | Why |
|---|---|---|
| No `concentration` kwarg | `:exhaustive` (HF 2008) | Visit every k^n labeling; mark symmetry orbits as you go. The choice to make when there's no concentration constraint. |
| `concentration` supplied **and** the multinomial bitmap fits in `memory_budget × 0.8` | `:multinomial` (HF 2012) | Memory-bounded but fast. Mixed-radix hash into a `[0, C-1]` bitmap; cross out orbits. |
| `concentration` supplied **but** the multinomial bitmap won't fit | `:recursive_stabilizer` (Morgan 2017) |  Memory-cheap (no bitmap). Good for very long enumerations. Tree search with shrinking stabilizers; generates configurations "lazily". |
| Heterogeneous `Sites` (Regime C) **plus** `concentration` | `:recursive_stabilizer` | Today the only algorithm that filters per-site allowed labels (chunk 6.5b). The fast bitmap variant (`:multinomial_restricted`) is reserved for chunk 6.5a. |
#gh we use "Regime C", "Regime A" etc, assuming the user has held the definition in their head. We need links to definitions, or be more explicit at each use.
 
You can see what `:auto` chose by calling [`estimate_cost`](@ref) — its `chosen_algorithm` field is the dispatch result:

```jldoctest alg_recipe
julia> c = concentration_count([4, 4]; n_total = 8);

julia> est = estimate_cost(p, sites; supercells = VolumeRange(8:8), concentration = c);

julia> est.chosen_algorithm                          # small case: bitmap easily fits
:multinomial
```

## What each algorithm does (one paragraph each)

You shouldn't need this to call `enumerate`. It's here so you can read the dispatcher's choice and know what it means.

- **`:exhaustive`** (HF 2008) — iterate every `k^n` coloring of the supercell, check each against the symmetry group, keep one representative per orbit. Right when `k^n` is small.
- **`:multinomial`** (HF 2012) — only iterate colorings at the target `concentration`. Uses a bitmap of remaining candidates; memory grows with the multinomial coefficient. Fast per-config, but the bitmap can get big.
- **`:recursive_stabilizer`** (Morgan-Hart 2017) — tree search with shrinking stabilizers. Streams configurations instead of materializing a bitmap. Slower per configuration but scales to inputs where `:multinomial` would blow the memory budget. Also the only algorithm that handles per-site allowed labels (Regime C, chunk 6.5b).

For the math behind each, see [exhaustive-2008](../explanation/exhaustive-2008.md), [multinomial-2012](../explanation/multinomial-2012.md), [recursive-stabilizer-2017](../explanation/recursive-stabilizer-2017.md), and the [algorithm overview](../explanation/algorithm-overview.md).

## When `:auto` refuses (the resource check)

If Enumlib predicts the request will exceed your `memory_budget` (default 1 GB), it throws an `EnumerationTooLargeError` before any work starts. The error names the algorithm `:auto` was about to use, the predicted memory, and your budget. Three responses:

1. **Raise the budget.** `enumerate(...; memory_budget = 16_000_000_000)` for 16 GB.
2. **Force `:recursive_stabilizer`.** It streams, so it has no bitmap memory dependence. Slower per config but finishes:
   ```julia
   enumerate(parent, sites; supercells, concentration, algorithm = :recursive_stabilizer)
   ```
3. **Subset the request.** Shrink the supercell volume range or pin a stricter `concentration`; the resource check refused for a reason.

The [estimate-cost how-to](estimate-cost.md) covers the budget kwargs and what each prediction means.

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

## Algorithms reserved for the future

These names parse but throw `ArgumentError` today:

- **`:multinomial_restricted`** (chunk 6.5a) — `:multinomial` extended to per-site allowed labels. Will eventually become `:auto`'s pick for Regime C when the input fits in memory. Until then, `:recursive_stabilizer` handles Regime C.
- **`:bdd`** (Shinohara 2020 ZDD) — reserved for v0.3+.

## See also

- Reference: [`Base.enumerate`](@ref), [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`Enumlib.Polya.polya_count`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Estimate the cost of an enumeration](estimate-cost.md), [Sweep concentration ranges](sweep-concentration-ranges.md).
- Explanation: [Dispatch and the resource check](../explanation/dispatch-and-cost-gate.md), [Algorithm overview](../explanation/algorithm-overview.md).
