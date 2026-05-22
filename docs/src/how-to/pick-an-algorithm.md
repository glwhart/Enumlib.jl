# Pick an algorithm

In practice, `enumerate` will automatically pick the best algorithm for your request.
`enumerate` ships with three concentration-aware algorithms plus the "original" exhaustive (HF 2008) algorithm that sweeps over all concentrations. In most cases, **leave `algorithm = :auto`** — it makes the right call and you save reading the rest of this page.

!!! tip "The tree wins almost everywhere"
    Cross-algorithm benchmarks (`bench/runbench.jl` Sections 2, 4, 5) show that the recursive-stabilizer tree (Morgan-Hart 2017) is faster than the bitmap algorithms in nearly every case measured — ~2-3× over `:exhaustive` for unrestricted enumeration (and ~½ the memory), and ~9-60× over `:multinomial_restricted` for Regime C. As of v0.3, `:auto` defaults to the tree for unrestricted enumeration too (synthesizing a full-range `ConcentrationRange` internally). The bitmap algorithms remain available for explicit cross-checks and edge cases.

## Setup

```jldoctest alg_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## What `:auto` decides

| Inputs | `:auto` picks | Why |
|---|---|---|
| No `concentration` kwarg | `:recursive_stabilizer` (Morgan-Hart 2017) | The tree streams over all concentrations via a synthesized full-range `ConcentrationRange`; bench Section 5 measures ~2-3× speedup and ~½ memory vs `:exhaustive`. |
| `concentration` supplied **and** the multinomial bitmap fits in `memory_budget × 0.8` | `:multinomial` (HF 2012) | Memory-bounded but fast. Mixed-radix hash into a `[0, C-1]` bitmap; cross out orbits. |
| `concentration` supplied **but** the multinomial bitmap won't fit | `:recursive_stabilizer` (Morgan-Hart 2017) | Memory-cheap (no bitmap). Good for very long enumerations. Tree search with shrinking stabilizers; generates configurations "lazily". |
| Heterogeneous `Sites` — different allowed labels per dset position (e.g. perovskite A-site mixing, the As-fixed-on-anion AlGaAs example) — **plus** `concentration` | `:recursive_stabilizer` | The tree scales by the valid-colorings subspace; the bitmap variant `:multinomial_restricted` (shipped in v0.2.1) iterates the *full* multinomial coefficient and ends up slower for sparse Regime-C masks. |

The "Regime" labels you may see in error messages and design docs come from a three-way split of multilattice problems: **A** = single-site parent (just a Bravais lattice), **B** = multilattice with every dset position carrying the same allowed labels ("uniform sublattices" — HCP binary, diamond binary), **C** = multilattice with allowed labels that differ per dset position ("heterogeneous sublattices" — perovskite-style). Regime A and B run on `:multinomial` when concentration is given *and the bitmap fits the memory budget*; everything else (including Regime C and unrestricted enumeration) runs on the tree.

You can see what `:auto` chose by calling [`estimate_cost`](@ref) — its `chosen_algorithm` field is the dispatch result:

```jldoctest alg_recipe
julia> c = concentration_count([4, 4]; n_total = 8);

julia> est = estimate_cost(p, sites; supercells = VolumeRange(8:8), concentration = c);

julia> est.chosen_algorithm                          # small case: bitmap easily fits
:multinomial
```

## What each algorithm does (one paragraph each)

You shouldn't need this to call `enumerate`. It's here so you can read the dispatcher's choice and know what it means.

A note on "bitmap": throughout the multinomial path, this is a literal packed bit array (Julia's `BitVector`) with one bit per labeling at the target concentration. The multinomial hash maps each labeling deterministically to an index in the array, and the algorithm flips bits as orbit-equivalents are eliminated. It's not a hash *table* (no separate chains, no open addressing) — just `multinomial coefficient` bits, indexed by hash. That's why the memory cost grows linearly with the multinomial coefficient and the dispatcher tracks it for the resource check.

- **`:exhaustive`** (HF 2008) — iterate every `k^n` coloring of the supercell, check each against the symmetry group, keep one representative per orbit. The original algorithm; correct and simple but no longer the default — bench Section 5 shows the tree beats it by ~2-3× on FCC binary/ternary and HCP with ~½ the memory. Still useful for explicit cross-checks of the bitmap memory profile.
- **`:multinomial`** (HF 2012) — only iterate colorings at the target `concentration`. Uses the bitmap of remaining candidates described above; memory grows with the multinomial coefficient. Fast per-config, but the bitmap can get big. Roughly ties the tree at FCC binary fixed-concentration (bench Section 2); the tree wins as the bitmap grows.
- **`:multinomial_restricted`** (HF 2012 §A.1) — bitmap variant with a per-site `allowed_labels` mask for Regime C. Iterates the *full* multinomial coefficient and skips invalid slots lazily; slow when most slots are invalid (bench Section 4 shows it's ~9-60× slower than the tree on the Regime-C corpus). Reserved for dense-mask cases where the linear sweep is cheap; tree-walk pruning queued for a later release.
- **`:recursive_stabilizer`** (Morgan-Hart 2017) — tree search with shrinking stabilizers. Streams configurations instead of materializing a bitmap. The current `:auto` default for almost everything (including unrestricted enumeration, via a synthesized full-range `ConcentrationRange`); wins on speed and memory across the bench suite.

For the math behind each, see [exhaustive-2008](../explanation/exhaustive-2008.md), [multinomial-2012](../explanation/multinomial-2012.md), [recursive-stabilizer-2017](../explanation/recursive-stabilizer-2017.md), and the [algorithm overview](../explanation/algorithm-overview.md).

## When `:auto` refuses (the resource check)

If Enumlib predicts the request will exceed your `memory_budget` (default `max(2 GiB, 25% of system RAM)`), it throws an `EnumerationTooLargeError` before any work starts. The error names the algorithm `:auto` was about to use, the predicted memory, and your budget. Three responses:

1. **Raise the budget.** `enumerate(...; memory_budget = 16_000_000_000)` for 16 GB.
2. **Force `:recursive_stabilizer`.** It streams, so it has no bitmap memory dependence. Slower per config but finishes:
   ```julia
   enumerate(parent, sites; supercells, concentration, algorithm = :recursive_stabilizer)
   ```
3. **Subset the request.** Shrink the supercell volume range or pin a stricter `concentration`; the resource check refused for a reason. You might need to make your problem smaller for it to fit in memory.

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

- **`:bdd`** (Shinohara 2020 ZDD) — reserved for v0.3+.

## See also

- Reference: [`Base.enumerate`](@ref), [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`Enumlib.Polya.polya_count`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Estimate the cost of an enumeration](estimate-cost.md), [Sweep concentration ranges](sweep-concentration-ranges.md).
- Explanation: [Dispatch and the resource check](../explanation/dispatch-and-cost-gate.md), [Algorithm overview](../explanation/algorithm-overview.md).
