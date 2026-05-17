# Custom exception types for Enumlib's user-protection layer.
#
# Per Phase 7 design (research.md §7.5, §7.6), these errors fire from the
# enumeration resource check inside `enumerate(...)` to catch user-misuse cases
# before the enumeration starts allocating memory or burning CPU.

"""
    EmptyEnumerationError(reason::Symbol, diagnostic::String)

Thrown when the user's request cannot produce any valid structures. `reason` codes:

- `:concentration_unrealizable` — fractions don't divide cleanly into `n_total`
  (e.g., `Concentration([1//5, 4//5])` at `VolumeRange(2:4)` — no `n` in 2..4 is
  divisible by 5).
- `:no_active_sites` — the user's `Sites` has only inactive sites (single allowed
  label per site), so the labeling space is empty.
- `:site_restriction_conflict` — site restrictions over-constrain the requested
  concentration (chunk 6+).

Per chunk 2 review item 5, we throw rather than silently returning an empty
result — the caller is more often confused than not when no structures appear.
"""
struct EmptyEnumerationError <: Exception
    reason::Symbol
    diagnostic::String
end

function Base.showerror(io::IO, e::EmptyEnumerationError)
    print(io, "EmptyEnumerationError ($(e.reason)): ", e.diagnostic)
end

"""
    PartitionExplosionError(partition_count::Int, threshold::Int, diagnostic::String = "")

Thrown when a `ConcentrationRange` decomposes into too many distinct multiplicity vectors at the requested cell size. Default threshold (chunk 6): 100. Above that, the naïve caller almost certainly wanted a narrower range.

Per Phase 7 §7.6, the gate is paternalistic by default; expert users can pass `on_partition_overflow = :ignore` (or set `partition_threshold` higher) for literature-validation runs that genuinely want every partition.
"""
struct PartitionExplosionError <: Exception
    partition_count::Int
    threshold::Int
    diagnostic::String
end

PartitionExplosionError(partition_count::Int, threshold::Int) =
    PartitionExplosionError(partition_count, threshold, "")

function Base.showerror(io::IO, e::PartitionExplosionError)
    print(io, "PartitionExplosionError: ConcentrationRange decomposes into ",
              e.partition_count, " distinct multiplicity vectors ",
              "(threshold = $(e.threshold)). The cost estimate is the *sum* across ",
              "all of them, which usually means a much larger total enumeration ",
              "than intended.")
    if !isempty(e.diagnostic)
        print(io, "\n  ", e.diagnostic)
    end
    print(io,
          "\n\nMitigations to consider:",
          "\n  • Narrow the ConcentrationRange (e.g., tighter per-species (min, max) bounds).",
          "\n  • Reduce k by merging species that don't need to vary independently.",
          "\n  • Override the gate: pass `on_partition_overflow = :ignore` (you accept the risk).",
          "\n  • Raise the threshold: pass `partition_threshold = $(2 * e.threshold)`.")
end

"""
    EnumerationTooLargeError(estimate::EnumerationCostEstimate, budget_bytes::Int)

Thrown by `enumerate(...)` when the predicted `EnumerationCostEstimate`'s `peak_memory_bytes` exceeds the configured `memory_budget`. Carries the full estimate so the user can see exactly what would have been allocated, plus the budget that was tripped.

Per Phase 7 §7.3, the gate is `on_overflow = :error` by default; expert users can pass `:warn` (warns but proceeds) or `:ignore` (silent pass-through), or set `skip_resource_check = true` to bypass the estimator entirely.
"""
struct EnumerationTooLargeError <: Exception
    estimate::EnumerationCostEstimate
    budget_bytes::Int
end

function Base.showerror(io::IO, e::EnumerationTooLargeError)
    pred = format_bytes(e.estimate.peak_memory_bytes)
    bdgt = format_bytes(e.budget_bytes)
    print(io, "EnumerationTooLargeError: predicted peak memory ", pred,
              " exceeds memory_budget ", bdgt, ".",
          "\n  Predicted structure count : ", e.estimate.total_count,
          "\n  Chosen algorithm          : :", e.estimate.chosen_algorithm,
          "\n  Selection                 : :", e.estimate.selection_kind,
          "\n\nMitigations to consider:",
          "\n  • Narrow the supercells (smaller VolumeRange / tighter RadiusBound).",
          "\n  • Add a `concentration` to switch from :exhaustive to :multinomial.",
          "\n  • Pass `on_overflow = :warn` or `:ignore` to bypass the gate.",
          "\n  • Pass `memory_budget = <bigger>` if you have the RAM.",
          "\n  • Pass `skip_resource_check = true` to skip estimation entirely.")
end
