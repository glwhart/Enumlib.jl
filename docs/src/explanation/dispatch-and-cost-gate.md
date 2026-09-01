# Dispatch and the resource check

How `enumerate(...)`'s `algorithm = :auto` dispatch picks one of the four enumeration algorithms, how the enumeration resource check uses Pólya / [`estimate_cost`](@ref) to refuse oversized requests, and how to override each step.

## `algorithm = :auto` (the default)

When you call `enumerate_structures(parent, sites; supercells, concentration, algorithm = :auto)` (the default), Enumlib decides among:

- `:exhaustive` — [HF 2008](exhaustive-2008.md). Iterates `k^(n_D·n)` labelings.
- `:multinomial` — [HF 2012](multinomial-2012.md). Iterates the multinomial coefficient labelings at the target concentration.
- `:multinomial_restricted` — [HF 2012 §A.1](multinomial-2012.md). Bitmap + per-site mask for Regime C; reserved for explicit selection (linear iteration is slower than the tree on the Regime-C corpus).
- `:recursive_stabilizer` — [Morgan-Hart 2017](recursive-stabilizer-2017.md). Tree walk; no bitmap.

The decision tree:

1. **No concentration?** → `:recursive_stabilizer`, with a synthesized full-range `ConcentrationRange` built internally. Bench Section 5 shows the tree beats `:exhaustive` by ~2-3× and uses ~½ the memory across FCC binary/ternary and HCP. The single exception is Regime-C unrestricted, which the validator rejects regardless of algorithm.
2. **Concentration present + Regime C (heterogeneous sublattices)?** → `:recursive_stabilizer`. The tree scales by the valid-colorings subspace; `:multinomial_restricted` iterates the full multinomial coefficient and runs ~9-60× slower on the Heusler / wurtzite / perovskite corpus (bench Section 4).
3. **Concentration present + multinomial bitmap fits in 80% of `memory_budget`?** → `:multinomial`. The bitmap algorithm has tighter constants when the bitmap fits, and ties or narrowly trails the tree on FCC binary fixed-concentration (bench Section 2).
4. **Concentration present + multinomial bitmap too big?** → `:recursive_stabilizer`. The tree algorithm doesn't materialize the bitmap.

The "80% of `memory_budget`" threshold leaves headroom for the output `Vector{EnumeratedStructure}` and Julia's allocator overhead.

## Manual algorithm selection

Pass an explicit `algorithm = :exhaustive` / `:multinomial` / `:multinomial_restricted` / `:recursive_stabilizer` symbol to override. Use cases:

- **Benchmarking** — comparing wall-clock between algorithms on the same problem (this is how Section 5's "tree beats `:exhaustive`" finding was settled).
- **Forcing the recursive-stabilizer tree** even when the bitmap would fit, e.g., to avoid heavy single allocations on a shared-memory cluster (`:auto` already does this for unrestricted enumeration).
- **Forcing `:exhaustive`** on a concentration-restricted problem if you want the unrestricted count for comparison (uncommon), or to cross-check the tree against the original HF 2008 bitmap.

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

There's also a `skip_resource_check::Bool = false` kwarg that disables the check entirely.

## `memory_budget`

Defaults to `max(2 GiB, 25% of Sys.total_memory())`. Pass an explicit byte count to override:

- **HPC / Slurm** — `Sys.total_memory()` reports the *host's* RAM, not the cgroup / Slurm allocation. Set `memory_budget = parse(Int, ENV["SLURM_MEM_PER_NODE"]) * 2^20` or similar.
- **Smaller-than-default** — when you want the resource check to refuse earlier (e.g., on a laptop where 25% would still be too much).

[`estimate_cost`](@ref) takes the same `memory_budget` kwarg and reports the would-be peak; you can call it explicitly to size before running.

## Resource check ↔ Pólya ↔ algorithm alignment

The resource check's count is the *aperiodic Pólya count* (see [polya-counting](polya-counting.md)), which matches what `enumerate(...)` will produce *with the same `include_superperiodic` policy*. So the predicted structure count is exact (up to BigInt arithmetic), and the predicted memory is an upper bound on what `enumerate` actually allocates.

That exactness extends to heterogeneous sublattices: the count is taken with the label-restricted Pólya formulas, which honor each position's `allowed_labels` instead of assuming every position is free over all `k` species. Without that, the gate would price a zinc-blende or perovskite run orders of magnitude above its true size and could refuse a request that comfortably fits.

Enumlib's testsuite asserts this alignment on the entire reference corpus: for every locked-count case, `count_inequivalent` and `length(enumerate(...))` agree, and `estimate_cost(...).peak_memory_bytes` ≥ the algorithm's actual peak.

## See also

- [Pick an algorithm](../how-to/pick-an-algorithm.md) — recipe.
- [Estimate the cost](../how-to/estimate-cost.md) — recipe.
- [Algorithm overview](algorithm-overview.md) — bird's-eye view.
- [`enumerate_structures`](@ref), [`estimate_cost`](@ref), [`EnumerationCostEstimate`](@ref), [`EnumerationTooLargeError`](@ref).
