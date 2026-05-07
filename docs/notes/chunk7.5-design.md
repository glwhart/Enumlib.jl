# Chunk 7.5 — `EnumerationCostEstimate` + `estimate_cost` + memory-budget gate (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §6.9 (`EnumerationCostEstimate` type), §7.2 (cost estimator), §7.3 (memory-budget gate), §7.4 (BigInt handling); `docs/notes/v0.2-plan.md` chunk 7.5 entry; `docs/notes/chunk7-design.md` (Polya machinery this builds on).

**Goal:** make the chunk-7 `count_inequivalent` machinery the load-bearing layer behind a real *pre-flight gate* on `enumerate(...)`. The Phase 7 promise was "ask first, run second" — chunk 7 made counting work; chunk 7.5 wires it into the actual `enumerate(...)` flow so the user can't accidentally launch a 100 GiB enumeration on a 16 GiB laptop.

After chunk 7.5: `enumerate(...)` calls `estimate_cost` internally; if `peak_memory_bytes > memory_budget`, throws `EnumerationTooLargeError` with a structured payload telling the user what would have been allocated and what to try instead.

---

## What lives in chunk 7.5

### 1. `EnumerationCostEstimate` type — `src/types/cost_estimate.jl`

Per Phase 6.9 + §7.2 (with `estimated_walltime_seconds` deferred per §7.9 Q2):

```julia
"""
    EnumerationCostEstimate

Pre-flight prediction returned by `estimate_cost(...)`. The pre-flight gate inside `enumerate(...)` consults this struct.

Fields:
- `total_count::BigInt` — predicted number of inequivalent structures, honoring the same `include_superperiodic` kwarg the user passed to `enumerate(...)` / `estimate_cost(...)`.
- `peak_memory_bytes::Int` — worst-case peak memory for the chosen algorithm. For `:exhaustive`: max over HNFs of `bitmap + output_so_far`. For `:multinomial`: max over (HNF, concentration) of `bitmap + output_so_far`. Output is `sizeof(EnumeratedStructure{D, Vector{Int8}}) × total_count` plus per-supercell metadata.
- `chosen_algorithm::Symbol` — what `:auto` resolved to (or the explicit algorithm passed). One of `:exhaustive`, `:multinomial`.
- `selection_kind::Symbol` — `:volume_range`, `:radius_bound`, or `:explicit_hnfs`. Used so error messages can suggest an appropriately-shaped mitigation ("try a tighter radius" vs "smaller volume range").
- `partition_count::Int` — number of distinct multiplicity vectors when a `ConcentrationRange` was supplied; `1` otherwise.
- `notes::Vector{String}` — advisory messages: which algorithm was auto-picked and why, gate near-misses, etc.

Phase 7 §7.9 Q2 deferred `estimated_walltime_seconds` to v0.3 — hardware variance too high without a calibration pass. Not in v0.2.
"""
struct EnumerationCostEstimate
    total_count::BigInt
    peak_memory_bytes::Int
    chosen_algorithm::Symbol
    selection_kind::Symbol
    partition_count::Int
    notes::Vector{String}
end
```

Plus equality, pretty-print (`Base.show(io, ::MIME"text/plain", c)` showing each field with `format_bytes` for memory).

### 2. `EnumerationTooLargeError` — extend `src/types/errors.jl`

```julia
"""
    EnumerationTooLargeError

Thrown by `enumerate(...)` when the pre-flight cost estimate exceeds the configured `memory_budget`. The error carries the full `EnumerationCostEstimate` so the user can see exactly what would have been allocated.
"""
struct EnumerationTooLargeError <: Exception
    estimate::EnumerationCostEstimate
    budget_bytes::Int
end

function Base.showerror(io::IO, e::EnumerationTooLargeError)
    pred = format_bytes(e.estimate.peak_memory_bytes)
    bdgt = format_bytes(e.budget_bytes)
    print(io, """EnumerationTooLargeError: predicted peak memory $pred exceeds memory_budget $bdgt.
                 Predicted structure count: $(e.estimate.total_count)
                 Chosen algorithm: $(e.estimate.chosen_algorithm)
                 Selection: $(e.estimate.selection_kind)
                 Mitigations:
                   • Narrow the supercells (smaller VolumeRange / tighter RadiusBound)
                   • Add a concentration to switch from :exhaustive to :multinomial
                   • Pass on_overflow = :warn or :ignore to bypass the gate
                   • Pass memory_budget = <bigger> if you have the RAM""")
end
```

`format_bytes(n::Integer) -> String` lives alongside (formats as KiB / MiB / GiB / TiB to 2 decimals).

### 3. `estimate_cost(...)` — extends `src/enumerate.jl`

Same kwarg surface as `enumerate(...)`; returns `EnumerationCostEstimate` without running the algorithm:

```julia
"""
    estimate_cost(parent::ParentLattice{D}, sites::Sites{D};
                  supercells::SupercellSelection,
                  concentration = nothing,
                  algorithm::Symbol = :auto,
                  include_superperiodic::Bool = false) -> EnumerationCostEstimate

Predict the cost of `enumerate(...)` *before* running it. Useful for users who want to size their request explicitly, and for `enumerate(...)`'s pre-flight gate (which calls this internally).

Cost: same as `count_inequivalent(...)` — milliseconds even for hundreds of supercells. The Pólya count is the dominant term; per-algorithm memory estimation is closed-form.
"""
function estimate_cost(parent, sites; supercells, concentration = nothing,
                       algorithm::Symbol = :auto,
                       include_superperiodic::Bool = false)
    k = _validate_enumerate_inputs(parent, sites, concentration)

    # Resolve algorithm (same logic as enumerate's :auto dispatch).
    chosen = algorithm == :auto ? (concentration === nothing ? :exhaustive : :multinomial) : algorithm

    notes = String[]
    if algorithm == :auto
        push!(notes, "Auto-dispatch chose :$chosen (concentration $(concentration === nothing ? "nothing" : "supplied"))")
    end

    # Total count via the chunk-7 machinery.
    total_count = count_inequivalent(parent, sites; supercells, concentration,
                                     include_superperiodic)

    # Memory prediction.
    peak_memory = _predict_peak_memory(parent, sites, supercells, concentration, chosen, total_count)

    # Selection kind.
    selection_kind = supercells isa VolumeRange ? :volume_range :
                     supercells isa RadiusBound ? :radius_bound : :explicit_hnfs

    # Partition count.
    partition_count = if concentration isa ConcentrationRange
        # Sum across volumes — number of distinct multiplicity vectors total.
        sum(length(concentrations_in_range(concentration, n))
            for n in _volumes_for(supercells, parent))
    else
        1
    end

    return EnumerationCostEstimate(total_count, peak_memory, chosen,
                                   selection_kind, partition_count, notes)
end
```

### 4. `_predict_peak_memory(...)` — internal helper

Per §7.2:

- **`:exhaustive`** (chunk 5): peak = max over HNFs of `bitmap_bytes(k^n) + output_running_total`.
  - `bitmap_bytes(C) = ceil(C / 8)` (BitVector cost).
  - `output_running_total` accumulates as we walk HNFs.
- **`:multinomial`** (chunk 6): peak = max over (HNF, concentration) of `bitmap_bytes(C_multinomial) + output_running_total`.

For chunk 7.5 we approximate "output running total" by `total_count × sizeof(EnumeratedStructure{D, Vector{Int8}})`. The actual peak depends on enumeration order, but this is a safe upper bound (at end-of-run, output holds all structures).

The `bitmap_bytes(C)` term is exact — it's the worst-case allocation per HNF.

### 5. Wire `enumerate(...)`'s pre-flight gate

Replace the chunk-6 partial stub. Currently `memory_budget`, `on_overflow`, `skip_preflight` are accepted but ignored for the memory side (only the partition gate is real). Chunk 7.5 makes them all real:

```julia
function Base.enumerate(parent, sites; ..., skip_preflight::Bool = false, ...)
    # ... existing algorithm validation ...
    k = _validate_enumerate_inputs(parent, sites, concentration)

    # Pre-flight gate (skipped if user opts out).
    if !skip_preflight
        estimate = estimate_cost(parent, sites; supercells, concentration,
                                 algorithm, include_superperiodic)
        if estimate.peak_memory_bytes > memory_budget
            if on_overflow === :error
                throw(EnumerationTooLargeError(estimate, memory_budget))
            elseif on_overflow === :warn
                @warn "Predicted peak memory exceeds budget" estimate memory_budget
            end
            # :ignore falls through.
        end
    end

    # ... existing HNF enumeration + algorithm body ...
end
```

The partition gate stays where it is (inside `_enumerate_multinomial`, computing per-volume).

### 6. Module wiring

- `src/Enumlib.jl`: include `types/cost_estimate.jl`; export `EnumerationCostEstimate`, `EnumerationTooLargeError`, `estimate_cost`, `format_bytes`.
- `src/types/errors.jl`: append `EnumerationTooLargeError` struct + showerror.

---

## What's deliberately NOT in chunk 7.5

- **`estimated_walltime_seconds`** — Phase 7 §7.9 Q2 deferred to v0.3.
- **Smart-default super-periodicity inspection** — research.md §5.2.1 logged three v0.3 candidates (silently no-op moot kwarg, warn on multi-volume sweeps with `=true`). Chunk 7.5 just passes `include_superperiodic` through; no extra inspection.
- **Per-HNF memory granularity for `RadiusBound`** — for `RadiusBound`, the HNF list comes back from `enumerate_hnfs` already. We compute peak across that resolved list. No probabilistic / streaming RadiusBound memory model.
- **Recursive-stabilizer (`:recursive_stabilizer`) memory model** — chunk 8 will add it. Until then, `estimate_cost` rejects this algorithm at the same gate as `enumerate(...)` does today.
- **Multilattice / site-restricted memory models** — these are gated by chunks 6.5 / v0.3.

---

## Tests planned (extend `test/test_enumerate.jl`; new `test/test_cost_estimate.jl`)

### `EnumerationCostEstimate` type
1. **Construction + equality.** Identical-field instances are `==`; differing fields are not.
2. **Pretty-print** shows readable bytes (KiB/MiB/GiB).

### `format_bytes`
3. **Spot checks.** `format_bytes(1023) == "1023 B"`; `1024 → "1.00 KiB"`; `1024^2 → "1.00 MiB"`; `1024^3 → "1.00 GiB"`.

### `estimate_cost(...)` correctness
4. **Total count matches `count_inequivalent`.** For each chunk-5/6/6.2 reference, `estimate_cost(...).total_count == count_inequivalent(...)`. Both kwarg branches.
5. **`chosen_algorithm` matches `:auto` dispatch.** No-concentration → `:exhaustive`; with concentration → `:multinomial`. Explicit algorithm passes through.
6. **`selection_kind` is correct** for `VolumeRange`, `RadiusBound`, `ExplicitHNFs`.
7. **`partition_count` matches the per-volume sum** for `ConcentrationRange`; equals 1 for `Concentration` and no-concentration.
8. **`notes` is populated when `:auto` resolves.** Otherwise empty.

### Memory prediction sanity
9. **`peak_memory_bytes > 0`** for any non-empty enumeration.
10. **Bitmap term scales with `k^n`** (exhaustive). For FCC binary at n=4 vs n=8 vs n=12, predicted peak rises with `2^n`.
11. **Multinomial bitmap is much smaller than exhaustive** for asymmetric concentrations (e.g., 15:17 in n=32: `binomial(32, 17)` vs `2^32`).

### Memory-budget gate
12. **Default budget passes for chunk-5/6/6.2 reference cases** (none are >2 GiB).
13. **Error fires when budget is below predicted peak.** Set `memory_budget = 1` and confirm `EnumerationTooLargeError` is thrown.
14. **`on_overflow = :warn` warns but proceeds.** `@test_warn` + result still produced.
15. **`on_overflow = :ignore` proceeds silently.**
16. **`skip_preflight = true` bypasses the gate entirely.** No estimator call; no error even with `memory_budget = 1`.
17. **`EnumerationTooLargeError` payload** has the populated `estimate` and `budget_bytes`. `showerror` prints the formatted bytes.

### Backwards-compat
18. **Chunks 1–7 tests still pass.** Default `memory_budget = default_memory_budget()` is high enough that no existing test trips the gate.

Total: 18 testsets, ~30 individual tests.

---

## Open questions for you

### Q1 — Unify `estimate_cost`'s `count` field with `count_inequivalent`?

`estimate_cost(...).total_count` and `count_inequivalent(...; ...)` return the same `BigInt` for the same input. The estimator just adds memory + algorithm metadata.

**A.** Have `estimate_cost` call `count_inequivalent` internally. Cleanest separation. One extra function-call layer (negligible).

**B.** Inline the Pólya math in `estimate_cost`, duplicate code. Faster by ~µs but harder to maintain.

**My lean: A.** No-brainer; A is what the design references already assume.

> A

### Q2 — Output-buffer size estimate: exact, conservative, or a separate field?

The output of `enumerate(...)` is `Vector{EnumeratedStructure{D, Vector{Int8}}}` of length `total_count`. Each `EnumeratedStructure` carries a `Vector{Int8}` labeling of length `n` (varies by HNF) plus a few Ints.

**A.** Single `peak_memory_bytes` includes both bitmap and output. Conservative — the user sees one number and acts on it.

**B.** Split into `bitmap_bytes` + `output_bytes` fields. More information; user can reason about the components.

**My lean: A** for v0.2, with the option to split in v0.3 if users want it. Phase 7 §7.2 already specifies a single `peak_memory_bytes`. Keep the surface minimal.

> A

### Q3 — `include_superperiodic` kwarg threading through `estimate_cost` — match `enumerate` or fix to `false`?

**A.** Match: `estimate_cost(...; include_superperiodic = false)` → predicts what `enumerate(...; include_superperiodic = false)` would do. Both default `false`.

**B.** Always estimate at `include_superperiodic = false` since that's the default. Saves the user from passing it.

**My lean: A.** The cost depends on whether super-periodic structures are included (the count term). Mismatch between estimate and enumeration would be a footgun. Same kwarg name + default + semantics on every public function — matches research.md §5.2.1.

> A

### Q4 — `EnumerationCostEstimate` mutability + caching?

Phase 6.9 spec'd it as an immutable struct. Some workflows might want to compute the estimate once, mutate the budget, and re-check.

**A.** Immutable struct (Phase 6.9 design). For the rare re-check use case, re-call `estimate_cost`.

**B.** Mutable struct. Saves a Pólya re-run (sub-second savings).

**My lean: A.** Immutable matches every other v0.2 type; the Pólya re-run is cheap. Caching is a v0.3 polish if anyone asks.

> A

### Q5 — Should `estimate_cost(...)` error on the same multilattice / site-restricted gates as `enumerate(...)`, or just predict?

**A.** Errors. Same input-validation block via `_validate_enumerate_inputs` (already shared with `count_inequivalent`). User can't ask for a cost estimate for an unsupported configuration.

**B.** Returns an estimate with `notes = ["multilattice not yet supported, prediction is for the single-lattice approximation"]` or similar.

**My lean: A.** Honesty over false predictions. If a configuration would error in `enumerate(...)`, it should error in `estimate_cost(...)` too. Same gate, same message.

> A

### Q6 — Test for memory-budget gate: synthetic small example, or rely on the absurd-budget setup?

The natural way to trigger the gate without slowing tests: pass `memory_budget = 1` (1 byte). Any non-trivial case will exceed.

**A.** Just `memory_budget = 1` for gate-triggering tests. Simple, fast.

**B.** Construct a scenario where the actual memory prediction is genuinely large (e.g., FCC binary at n=20). Slower; more "realistic"; tests the prediction math too.

**My lean: A for the gate-firing tests; B-style sanity already covered by tests 9–11.** Mixing both gives full coverage without slowness.

> A, but let's add something like the proposal B later. Nothing like a real test...
 
### Q7 — Should `EnumerationCostEstimate` be exported, or only `estimate_cost`?

**A.** Export `EnumerationCostEstimate` (so users can dispatch on it / construct mock instances). Phase 6.9 implicitly assumes this.

**B.** Internal only — return value is the only contact surface.

**My lean: A.** Standard practice; users who want to build wrappers around `estimate_cost` need the type.

> A

### Q8 — `format_bytes` exported or internal?

**A.** Export. Useful utility.

**B.** Internal helper.

**My lean: A.** It's a tiny helper but useful to users who handle byte counts elsewhere; matches `default_memory_budget` (already exported).

> A

---

## Implementation plan

1. Write `src/types/cost_estimate.jl` — `EnumerationCostEstimate` struct + equality + pretty-print + `format_bytes`.
2. Append to `src/types/errors.jl` — `EnumerationTooLargeError` struct + `Base.showerror`.
3. Update `src/enumerate.jl`:
   - Add `_predict_peak_memory(parent, sites, supercells, concentration, algorithm, total_count)` internal helper.
   - Add `_volumes_for(supercells, parent)` internal helper (returns the set of supercell volumes that will be visited; needed for partition_count).
   - Add public `estimate_cost(...)` top-level.
   - Wire the pre-flight memory-budget gate into `enumerate(...)`. The partition gate stays where it is (inside `_enumerate_multinomial`).
4. Update `src/Enumlib.jl` — `include("types/cost_estimate.jl")`; exports for `EnumerationCostEstimate`, `EnumerationTooLargeError`, `estimate_cost`, `format_bytes`.
5. Write `test/test_cost_estimate.jl` — the 18 testsets above. Capture predicted-bytes reference values during a one-shot implementation run.
6. Update `test/runtests.jl` — one new `include`.
7. Update `docs/notes/v0.2-plan.md` — chunk 7.5 → done; "stub" caveat removed from chunk-7 entry; v0.2-polish list intact.
8. Run all tests. Expect 470 + ~30 = ~500 passing.

**Estimated:** one focused session. The math is small; the tests are the bulk.

---

## After your sign-off

- Implementation lands as `Chunk 7.5: estimate_cost + memory-budget gate`.
- `docs/notes/chunk7.5-review.md` opened for the review pass.
- Land chunk 7.5.1 with revisions if needed.
- Then chunk 8 (recursive-stabilizer, Morgan 2017) toward v0.2.0.

**Sign off below or annotate Q1–Q8 inline:**

Your response: Proceed
