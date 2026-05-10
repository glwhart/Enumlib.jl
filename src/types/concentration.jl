# Concentration and ConcentrationRange — chunk 6.
#
# Two related types that describe the user's stoichiometry constraint:
#
#   - `Concentration` — a single fixed concentration. Per-species fractions
#     summing to 1, stored as `Rational{Int}` so the math is exact.
#   - `ConcentrationRange` — per-species (min, max) bounds. Decomposes at each
#     supercell size into a list of integer-multiplicity vectors that satisfy
#     the bounds.
#
# Plus the three named constructors for `Concentration` per chunk-2-review item 5
# (`concentration_ratio`, `concentration_count`).

"""
    Concentration(fractions::AbstractVector{<:Rational})

A single concentration: per-species fractions summing to 1, stored as `Rational{Int}` for exact arithmetic.

Three named constructors per chunk-2-review item 5:
- `Concentration([15//32, 17//32])` — canonical: explicit fractions.
- `concentration_ratio([15, 17])` — integer ratio convenience: 15:17 → [15//32, 17//32].
- `concentration_count([15, 17]; n_total = 32)` — literal counts: "15 of A and 17 of B in a 32-cell." Validates that `sum(counts) == n_total`.

The verbose names are deliberate (chunk-2-review item 5: clarity over brevity for one-time problem-setup code).
"""
struct Concentration
    fractions::Vector{Rational{Int}}

    function Concentration(fractions::AbstractVector{<:Rational})
        length(fractions) >= 2 ||
            throw(ArgumentError("Concentration needs ≥ 2 species; got $(length(fractions))"))
        all(0 <= f <= 1 for f in fractions) ||
            throw(ArgumentError("each fraction must be in [0, 1]; got $fractions"))
        sum(fractions) == 1//1 ||
            throw(ArgumentError("fractions must sum to 1//1; got sum = $(sum(fractions))"))
        new(collect(Rational{Int}, fractions))
    end
end

"""
    concentration_ratio(integers::AbstractVector{<:Integer})

Convenience constructor: treats the integer vector as a ratio. `concentration_ratio([15, 17])` → `[15//32, 17//32]`.
"""
function concentration_ratio(integers::AbstractVector{<:Integer})
    all(n -> n >= 0, integers) ||
        throw(ArgumentError("ratio integers must be non-negative; got $integers"))
    s = sum(integers)
    s > 0 || throw(ArgumentError("ratio integers must not all be zero"))
    return Concentration([n // s for n in integers])
end

"""
    concentration_count(counts::AbstractVector{<:Integer}; n_total::Integer)

Literal-counts constructor: interprets the integer vector as exact counts in a cell of size `n_total`. `concentration_count([15, 17]; n_total = 32)` validates that `sum(counts) == 32` then produces `[15//32, 17//32]`. Mismatched `n_total` throws.
"""
function concentration_count(counts::AbstractVector{<:Integer}; n_total::Integer)
    n_total > 0 ||
        throw(ArgumentError("n_total must be positive; got $n_total"))
    sum(counts) == n_total ||
        throw(ArgumentError("sum(counts) = $(sum(counts)) does not match n_total = $n_total"))
    return Concentration([c // n_total for c in counts])
end

"""
    n_species(c::Concentration)

Number of species in the concentration vector.
"""
n_species(c::Concentration) = length(c.fractions)

"""
    multiplicities(c::Concentration, n_total::Integer) :: Vector{Int}

Resolve a concentration to integer per-species counts at a specific cell size. Throws `EmptyEnumerationError` (Phase 7 §7.5) if the fractions don't divide cleanly into `n_total` (e.g., `Concentration([1//3, 2//3])` at `n_total = 4`).
"""
function multiplicities(c::Concentration, n_total::Integer)
    n_total >= 1 ||
        throw(ArgumentError("n_total must be ≥ 1; got $n_total"))
    counts = Int[]
    for f in c.fractions
        # f * n_total must be an exact integer.
        v = f * n_total
        denominator(v) == 1 ||
            throw(EmptyEnumerationError(:concentration_unrealizable,
                "concentration $(c.fractions) does not produce integer counts at " *
                "n_total = $n_total (would need $(numerator(v))/$(denominator(v)) " *
                "of species $(length(counts)+1))"))
        push!(counts, numerator(v))
    end
    return counts
end

# Equality and hashing — value semantics on the fractions vector.
Base.:(==)(a::Concentration, b::Concentration) = a.fractions == b.fractions
Base.hash(c::Concentration, h::UInt) = hash(c.fractions, h)

# Pretty printing.
function Base.show(io::IO, c::Concentration)
    parts = ["$(numerator(f))//$(denominator(f))" for f in c.fractions]
    print(io, "Concentration(", join(parts, ", "), ")")
end


# ------------------------------------------------------------------------------

"""
    ConcentrationRange(bounds::AbstractVector{Tuple{Rational, Rational}})

Per-species `(min, max)` bounds. Decomposes at each cell size into a list of `Concentration`s within the bounds via `concentrations_in_range`.

Used for "I want all binary structures with composition in 40–60% range" or "I want every ternary stoichiometry where C is at most 1/3."
"""
struct ConcentrationRange
    bounds::Vector{Tuple{Rational{Int}, Rational{Int}}}

    function ConcentrationRange(bounds::AbstractVector)
        length(bounds) >= 2 ||
            throw(ArgumentError("ConcentrationRange needs ≥ 2 species"))
        for (i, (lo, hi)) in enumerate(bounds)
            (0 <= lo <= hi <= 1) ||
                throw(ArgumentError(
                    "species $i bounds (lo=$lo, hi=$hi) must satisfy 0 ≤ lo ≤ hi ≤ 1"))
        end
        # Sum of mins must be ≤ 1 ≤ sum of maxes — otherwise no concentration in
        # the box can satisfy both the species bounds AND the unit-sum constraint.
        sum(lo for (lo, _) in bounds) <= 1//1 <= sum(hi for (_, hi) in bounds) ||
            throw(ArgumentError(
                "ConcentrationRange has no feasible concentration: sum-of-lows " *
                "= $(sum(lo for (lo, _) in bounds)), sum-of-highs = $(sum(hi for (_, hi) in bounds)). Need sum-of-lows ≤ 1 ≤ sum-of-highs."))
        new([(Rational{Int}(lo), Rational{Int}(hi)) for (lo, hi) in bounds])
    end
end

n_species(cr::ConcentrationRange) = length(cr.bounds)

"""
    concentrations_in_range(cr::ConcentrationRange, n_total::Integer) :: Vector{Concentration}

Enumerate every integer-multiplicity vector `(a_1, ..., a_k)` with `sum(a_i) = n_total` and `lo_i ≤ a_i / n_total ≤ hi_i`, returning the corresponding `Concentration`s. Used by chunk-6's `enumerate(...)` to walk a concentration range.

Per Phase 7 §7.6, the chunk-6 default `partition_threshold = 100` checks the result of this function; if the count exceeds the threshold and `on_partition_overflow = :error`, `enumerate(...)` throws a `PartitionExplosionError` with a "narrow your range" message.
"""
function concentrations_in_range(cr::ConcentrationRange, n_total::Integer)
    n_total >= 1 ||
        throw(ArgumentError("n_total must be ≥ 1; got $n_total"))
    k = n_species(cr)
    # For each species i, the count a_i must lie in [lo_i * n_total, hi_i * n_total],
    # rounded to the nearest integer (clamped to non-negative).
    per_species_min = [max(0, ceil(Int, lo * n_total)) for (lo, _) in cr.bounds]
    per_species_max = [min(n_total, floor(Int, hi * n_total)) for (_, hi) in cr.bounds]

    results = Concentration[]
    # Recursive enumeration: walk species 1..k-1, fixing each count within bounds,
    # and let species k take what's left (if it satisfies its own bounds).
    counts = zeros(Int, k)

    function recurse(i::Int, remaining::Int)
        if i == k
            # Species k takes whatever's left.
            if per_species_min[k] <= remaining <= per_species_max[k]
                counts[k] = remaining
                push!(results, Concentration([c // n_total for c in counts]))
            end
            return
        end
        for a in per_species_min[i]:per_species_max[i]
            counts[i] = a
            recurse(i + 1, remaining - a)
        end
    end
    recurse(1, n_total)

    return results
end

Base.:(==)(a::ConcentrationRange, b::ConcentrationRange) = a.bounds == b.bounds
Base.hash(cr::ConcentrationRange, h::UInt) = hash(cr.bounds, h)

function Base.show(io::IO, cr::ConcentrationRange)
    parts = ["($(numerator(lo))//$(denominator(lo)), $(numerator(hi))//$(denominator(hi)))"
             for (lo, hi) in cr.bounds]
    print(io, "ConcentrationRange(", join(parts, ", "), ")")
end
