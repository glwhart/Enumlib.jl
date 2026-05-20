# Estimate the cost of an enumeration

[`estimate_cost`](@ref) predicts how big a planned `enumerate(...)` call will be — total structure count, peak memory, chosen algorithm — *without* actually allocating or running it. Two use cases:

1. **You** call it to size a request before launching a multi-day job.
2. **`enumerate(...)` itself** calls it internally as the *enumeration resource check* — and refuses to proceed if the prediction exceeds `memory_budget`.

## Setup

```jldoctest cost_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## Preview a planned run

```jldoctest cost_recipe
julia> est = estimate_cost(p, sites; supercells = VolumeRange(8:8));

julia> est.total_count                          # how many structures we'd get
390

julia> est.chosen_algorithm                     # what :auto resolved to
:exhaustive
```

Inspect any field of the returned [`EnumerationCostEstimate`](@ref) (`total_count`, `peak_memory_bytes`, `chosen_algorithm`, `selection_kind`, `partition_count`, `notes`) to drive your sizing decisions.

## When the resource check refuses

The same `estimate_cost` call is made internally by `enumerate(...)`. If the prediction exceeds `memory_budget`, the default policy throws [`EnumerationTooLargeError`](@ref) — *before* any allocation happens. Below, demonstrate the error by forcing it with an artificially tiny `memory_budget = 1` byte:

```jldoctest cost_recipe; filter = r"\d+\.\d+ MiB"
julia> try
           enumerate(p, sites; supercells = VolumeRange(20:20), memory_budget = 1)
       catch e
           e isa EnumerationTooLargeError || rethrow()
           format_bytes(e.estimate.peak_memory_bytes)
       end
"137.56 MiB"
```

## Override policies

When you genuinely *want* the run to proceed despite a failed resource check, pass one of:

- `on_overflow = :warn` — log a warning and proceed.
- `on_overflow = :ignore` — proceed silently.
- `memory_budget = <bigger>` — raise the budget. Default is `default_memory_budget()` (25% of system RAM, with a 2 GiB floor).
- `skip_resource_check = true` — bypass the estimator entirely. Use sparingly: this also skips the cost-and-algorithm-info notes you'd normally see.

## See also

- Reference: [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`EnumerationTooLargeError`](@ref), [`format_bytes`](@ref), [`default_memory_budget`](@ref).
- How-to: [Pick an algorithm](pick-an-algorithm.md), [Count without enumerating](count-without-enumerating.md), [Sweep concentration ranges](sweep-concentration-ranges.md).
- Explanation: [Dispatch and the resource check](../explanation/dispatch-and-cost-gate.md).