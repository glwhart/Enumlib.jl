# Dispatch and the cost gate

How `enumerate(...)`'s `algorithm = :auto` dispatch picks one of the three enumeration algorithms, how the enumeration resource check uses Pólya / [`estimate_cost`](@ref) to refuse oversized requests, and how to override each step.

## `algorithm = :auto` (the default)

When you call `enumerate(parent, sites; supercells, concentration, algorithm = :auto)` (the default), Enumlib decides among:

- `:exhaustive` — [HF 2008](exhaustive-2008.md). Iterates `k^(n_D·n)` labelings.
- `:multinomial` — [HF 2012](multinomial-2012.md). Iterates the multinomial coefficient labelings at the target concentration.
- `:recursive_stabilizer` — [Morgan-Hart 2017](recursive-stabilizer-2017.md). Tree walk; no bitmap.

The decision tree:

1. **No concentration?** → `:exhaustive`. The other algorithms either need a concentration (multinomial; recursive-stabilizer in v0.2) or wouldn't help.
2. **Concentration present + multinomial bitmap fits in 80% of `memory_budget`?** → `:multinomial`. The bitmap algorithm has tighter constants when the bitmap fits.
3. **Concentration present + multinomial bitmap too big?** → `:recursive_stabilizer`. The tree algorithm doesn't materialize the bitmap.

The "80% of `memory_budget`" threshold leaves headroom for the output `Vector{EnumeratedStructure}` and Julia's allocator overhead.

## Manual algorithm selection

Pass an explicit `algorithm = :exhaustive` / `:multinomial` / `:recursive_stabilizer` symbol to override. Use cases:

- **Benchmarking** — comparing wall-clock between algorithms on the same problem.
- **Forcing the recursive-stabilizer tree** even when the bitmap would fit, e.g., to avoid heavy single allocations on a shared-memory cluster.
- **Forcing exhaustive** on a concentration-restricted problem if you want the unrestricted count for comparison (uncommon).

Invalid combinations error at validation time — e.g., `algorithm = :multinomial` without `concentration` throws `ArgumentError`.

## The enumeration resource check

`enumerate(...)` consults [`estimate_cost`](@ref) before allocating anything substantial:

1. **Pólya estimates the structure count** (`count_inequivalent` internally — milliseconds).
2. **`_predict_peak_memory` estimates peak memory** for the chosen algorithm: `BitVector` size for `:exhaustive` / `:multinomial`, or `output_count × n × overhead` for `:recursive_stabilizer`.
3. **The total is compared to `memory_budget`** (default: `max(2 GiB, 25% of system RAM)`).

What happens next depends on `on_resource_overflow` (default `:error`):

- `:error` — throw [`EnumerationTooLargeError`](@ref) carrying the estimate, before any allocation.
- `:warn` — `@warn` the estimate and proceed.
- `:ignore` — silently proceed.

There's also a `skip_preflight::Bool = false` kwarg that disables the check entirely. (Note: the kwarg name is staged for renaming to match the new "enumeration resource check" terminology in v0.3+; see the v0.2 plan's "Pending rename of `skip_preflight` kwarg" entry.)

## `memory_budget`

Defaults to `max(2 GiB, 25% of Sys.total_memory())`. Pass an explicit byte count to override:

- **HPC / Slurm** — `Sys.total_memory()` reports the *host's* RAM, not the cgroup / Slurm allocation. Set `memory_budget = parse(Int, ENV["SLURM_MEM_PER_NODE"]) * 2^20` or similar.
- **Smaller-than-default** — when you want the gate to fire earlier (e.g., on a laptop where 25% would still be too much).

[`estimate_cost`](@ref) takes the same `memory_budget` kwarg and reports the would-be peak; you can call it explicitly to size before running.

## Cost-gate ↔ Pólya ↔ algorithm alignment

The cost-gate's count is the *aperiodic Pólya count* (see [polya-counting](polya-counting.md)), which matches what `enumerate(...)` will produce *with the same `include_superperiodic` policy*. So the predicted structure count is exact (up to BigInt arithmetic), and the predicted memory is an upper bound on what `enumerate` actually allocates.

The chunk-7 / chunk-7.5 testsuites assert this alignment on the entire reference corpus: for every locked-count case, `count_inequivalent` and `length(enumerate(...))` agree, and `estimate_cost(...).peak_memory_bytes` ≥ the algorithm's actual peak.

## See also

- [Pick an algorithm](../how-to/pick-an-algorithm.md) — recipe.
- [Estimate the cost](../how-to/estimate-cost.md) — recipe.
- [Algorithm overview](algorithm-overview.md) — bird's-eye view.
- [`enumerate`](@ref), [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`EnumerationTooLargeError`](@ref).
