"""
    EnumerationCostEstimate

Pre-flight prediction returned by [`estimate_cost`](@ref). The pre-flight gate inside `enumerate(...)` consults this struct to decide whether to proceed or throw `EnumerationTooLargeError`.

Fields:

- `total_count::BigInt` — predicted number of inequivalent structures, honoring the same `include_superperiodic` kwarg the user passed. Computed via the chunk-7 Pólya machinery.
- `peak_memory_bytes::Int` — worst-case peak memory for the chosen algorithm. For `:exhaustive`: max over HNFs of `bitmap_bytes(k^n) + output_so_far`. For `:multinomial`: max over (HNF, concentration) of `bitmap_bytes(C_multinomial) + output_so_far`. Output-buffer term is approximated by `total_count × sizeof(EnumeratedStructure{D, Vector{Int8}})` — a safe upper bound at end-of-run.
- `chosen_algorithm::Symbol` — what `:auto` resolved to (or the explicit algorithm passed). One of `:exhaustive`, `:multinomial`.
- `selection_kind::Symbol` — `:volume_range`, `:radius_bound`, or `:explicit_hnfs`. Lets error messages suggest an appropriately-shaped mitigation.
- `partition_count::Int` — number of distinct multiplicity vectors when a `ConcentrationRange` was supplied; `1` otherwise.
- `notes::Vector{String}` — advisory messages: which algorithm `:auto` picked, etc.

Phase 7 §7.9 Q2 deferred `estimated_walltime_seconds` to v0.3 — hardware variance too high without a calibration pass.
"""
struct EnumerationCostEstimate
    total_count::BigInt
    peak_memory_bytes::Int
    chosen_algorithm::Symbol
    selection_kind::Symbol
    partition_count::Int
    notes::Vector{String}
end

Base.:(==)(a::EnumerationCostEstimate, b::EnumerationCostEstimate) =
    a.total_count == b.total_count &&
    a.peak_memory_bytes == b.peak_memory_bytes &&
    a.chosen_algorithm == b.chosen_algorithm &&
    a.selection_kind == b.selection_kind &&
    a.partition_count == b.partition_count &&
    a.notes == b.notes

function Base.show(io::IO, ::MIME"text/plain", c::EnumerationCostEstimate)
    println(io, "EnumerationCostEstimate:")
    println(io, "  total_count       = ", c.total_count)
    println(io, "  peak_memory_bytes = ", format_bytes(c.peak_memory_bytes),
                "  ($(c.peak_memory_bytes) bytes)")
    println(io, "  chosen_algorithm  = :", c.chosen_algorithm)
    println(io, "  selection_kind    = :", c.selection_kind)
    println(io, "  partition_count   = ", c.partition_count)
    if !isempty(c.notes)
        println(io, "  notes:")
        for n in c.notes
            println(io, "    • ", n)
        end
    end
end

"""
    format_bytes(n::Integer) -> String

Format a byte count as a human-readable string with the largest unit ≥ 1.

Examples:

    format_bytes(0)         == "0 B"
    format_bytes(1023)      == "1023 B"
    format_bytes(1024)      == "1.00 KiB"
    format_bytes(1024^2)    == "1.00 MiB"
    format_bytes(1024^3)    == "1.00 GiB"
    format_bytes(1024^4)    == "1.00 TiB"

Uses binary (1024-based) units to match how memory budgets are typically
reported. Two-decimal precision; rounds toward zero for the unit selection.
"""
function format_bytes(n::Integer)::String
    n < 0 && throw(ArgumentError("format_bytes: byte count must be ≥ 0; got $n"))
    units = ("B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB")
    n < 1024 && return "$n B"
    val = Float64(n)
    unit_idx = 1
    while val >= 1024 && unit_idx < length(units)
        val /= 1024
        unit_idx += 1
    end
    return Printf.@sprintf("%.2f %s", val, units[unit_idx])
end
