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

Three named constructors — pick the one that matches what you're holding in your head:
- `Concentration([1//4, 3//4])` — canonical: explicit fractions, fully specified.
- `concentration_ratio([1, 3])` — *scale-free* integer ratio: 1:3 → `[1//4, 3//4]`. Non-coprime inputs work too — `[2, 6]` or `[3, 9]` all produce the same `Concentration(1//4, 3//4)` after normalization. Use when you care about the proportion, not the cell size.
- `concentration_count([3, 9]; n_total = 12)` — *anchored* literal counts: 3 of A and 9 of B *in a 12-cell* → `[1//4, 3//4]`. Validates `sum(counts) == n_total`. Use when you've committed to a specific supercell size.

A fourth constructor — `Concentration(sites, per_sublattice)` — is documented separately below; it's the natural form for Regime C (heterogeneous sublattices).
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
    concentration_ratio(integers::AbstractVector{<:Integer}) -> Concentration

Convenience constructor: treats the integer vector as a ratio. Each `Concentration` fraction is `integers[i] // sum(integers)`.

# Examples
```jldoctest
julia> concentration_ratio([2, 4])   # 2:4 reduces to 1:2 → fractions in lowest terms
Concentration(1//3, 2//3)

julia> concentration_ratio([1, 1, 2])  # ternary 1:1:2
Concentration(1//4, 1//4, 1//2)
```
"""
function concentration_ratio(integers::AbstractVector{<:Integer})
    all(n -> n >= 0, integers) ||
        throw(ArgumentError("ratio integers must be non-negative; got $integers"))
    s = sum(integers)
    s > 0 || throw(ArgumentError("ratio integers must not all be zero"))
    return Concentration([n // s for n in integers])
end

"""
    concentration_count(counts::AbstractVector{<:Integer}; n_total::Integer) -> Concentration

Literal-counts constructor: interprets the integer vector as exact counts in a cell of size `n_total`. Validates that `sum(counts) == n_total`; mismatched `n_total` throws.

# Examples
```jldoctest
julia> concentration_count([3, 9]; n_total = 12)   # 3 A + 9 B atoms in a 12-cell
Concentration(1//4, 3//4)

julia> concentration_count([15, 17]; n_total = 32)
Concentration(15//32, 17//32)
```
"""
function concentration_count(counts::AbstractVector{<:Integer}; n_total::Integer)
    n_total > 0 ||
        throw(ArgumentError("n_total must be positive; got $n_total"))
    sum(counts) == n_total ||
        throw(ArgumentError("sum(counts) = $(sum(counts)) does not match n_total = $n_total"))
    return Concentration([c // n_total for c in counts])
end

"""
    Concentration(sites::Sites, per_sublattice::Vector{<:AbstractVector{<:Real}}) -> Concentration

Per-sublattice constructor for Regime C / multilattice cases. Each
`per_sublattice[i]` gives the *ratio* (or fraction) of each label allowed at
dset position `i`, in the sorted order of `sites.list[i].allowed_labels`. The
constructor normalizes each sublattice row to a per-site fraction, sums across
dset positions, and divides by the number of dset positions to produce the
global flat-vector `Concentration`.

Use when the flat-vector representation is awkward — e.g., perovskite ABO₃
with 1:1 mixing on A and B and O fixed, which globally translates to
`Concentration([1//10, 1//10, 1//10, 1//10, 6//10])` at n=2. The per-sublattice
form lets you say "1:1 on A, 1:1 on B, fixed on O" directly and have the
constructor do the bookkeeping.

# Examples

Perovskite ABO₃ (A site = {0,1}, B site = {2,3}, three O sites all = {4}):

```jldoctest sublat_conc
julia> using Enumlib

julia> p = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],
                          [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5],
                           [0.5, 0.5, 0.0], [0.5, 0.0, 0.5], [0.0, 0.5, 0.5]]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.5, 0.5, 0.5], [2, 3]),
                       Site([0.5, 0.5, 0.0], [4]),
                       Site([0.5, 0.0, 0.5], [4]),
                       Site([0.0, 0.5, 0.5], [4])]);

julia> Concentration(sites, [[1, 1], [1, 1], [1], [1], [1]])
Concentration(1//10, 1//10, 1//10, 1//10, 3//5)
```

Half-Heusler with distinct sublattice species (X = {0,1}, Y = {2}, Z = {3}):

```jldoctest sublat_conc_hh
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                          [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25], [0.75, 0.75, 0.75]]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.25, 0.25, 0.25], [2]),
                       Site([0.75, 0.75, 0.75], [3])]);

julia> Concentration(sites, [[1, 1], [1], [1]])
Concentration(1//6, 1//6, 1//3, 1//3)
```
"""
function Concentration(sites::Sites,
                       per_sublattice::AbstractVector{<:AbstractVector{<:Real}})
    length(per_sublattice) == length(sites.list) ||
        throw(ArgumentError(
            "per_sublattice has $(length(per_sublattice)) entries but Sites " *
            "has $(length(sites.list)) dset positions."))

    # Global species set across all dset positions; require zero-indexed dense
    # labels (same gate the enumerate validation applies to Regime C inputs).
    union_labels = reduce(union, (s.allowed_labels for s in sites.list))
    k_global = length(union_labels)
    sorted_global = sort(collect(union_labels))
    sorted_global == collect(0:k_global-1) ||
        throw(ArgumentError(
            "zero-indexed dense labels required across all positions; got " *
            "$(sort(collect(union_labels)))"))

    # Per-cell label counts: each dset position contributes 1 atom per cell,
    # split among its allowed labels according to per_sublattice[i].
    counts_per_cell = zeros(Rational{Int}, k_global)
    for (i, s) in enumerate(sites.list)
        row = per_sublattice[i]
        length(row) == length(s.allowed_labels) ||
            throw(ArgumentError(
                "per_sublattice[$i] has $(length(row)) entries but " *
                "sites.list[$i].allowed_labels has $(length(s.allowed_labels)) labels."))
        all(>=(0), row) ||
            throw(ArgumentError(
                "per_sublattice[$i] entries must be non-negative; got $row"))
        row_total = sum(row)
        row_total > 0 ||
            throw(ArgumentError(
                "per_sublattice[$i] entries sum to zero; need at least one " *
                "positive entry per dset position"))

        # `allowed_labels` is a BitSet so iteration is sorted ascending; the
        # k-th entry of `row` corresponds to the k-th smallest allowed label.
        for (k_idx, label) in enumerate(sort(collect(s.allowed_labels)))
            counts_per_cell[label + 1] += Rational{Int}(row[k_idx]) // row_total
        end
    end

    # Normalize to global fractions (per-cell counts sum to ndset).
    total = sum(counts_per_cell)
    return Concentration(counts_per_cell ./ total)
end

"""
    n_species(c::Concentration)

Number of species in the concentration vector.
"""
n_species(c::Concentration) = length(c.fractions)

"""
    multiplicities(c::Concentration, n_total::Integer) -> Vector{Int}

Resolve a concentration to integer per-species counts at a specific cell size. Throws `EmptyEnumerationError` if the fractions don't divide cleanly into `n_total` (e.g., `Concentration([1//3, 2//3])` at `n_total = 4`).

# Examples
```jldoctest
julia> c = concentration_count([4, 4]; n_total = 8);

julia> multiplicities(c, 16)
2-element Vector{Int64}:
 8
 8
```
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

# Examples

"All binary structures with composition in the 40–60% range" — each species in `[2//5, 3//5]`. At a 10-site cell that's 3 partitions:
```jldoctest
julia> cr = ConcentrationRange([(2//5, 3//5), (2//5, 3//5)]);

julia> concentrations_in_range(cr, 10)
3-element Vector{Concentration}:
 Concentration(2//5, 3//5)
 Concentration(1//2, 1//2)
 Concentration(3//5, 2//5)
```

"Every ternary stoichiometry where C is at most 1/3" — first two species unconstrained, third species in `[0, 1//3]`. At a 6-site cell that's 18 partitions:
```jldoctest
julia> cr = ConcentrationRange([(0//1, 1//1), (0//1, 1//1), (0//1, 1//3)]);

julia> length(concentrations_in_range(cr, 6))
18
```
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

"""
    n_species(cr::ConcentrationRange) -> Int

Number of species (length of the per-species `(min, max)` bounds vector).
"""
n_species(cr::ConcentrationRange) = length(cr.bounds)

"""
    concentrations_in_range(cr::ConcentrationRange, n_total::Integer) -> Vector{Concentration}

Enumerate every integer-multiplicity vector `(a_1, ..., a_k)` with `sum(a_i) = n_total` and `lo_i ≤ a_i / n_total ≤ hi_i`, returning the corresponding `Concentration`s. Used by `enumerate(...)` to walk a concentration range.

The default `partition_threshold = 100` checks the result of this function; if the count exceeds the threshold and `on_partition_overflow = :error`, `enumerate(...)` throws a `PartitionExplosionError` with a "narrow your range" message.

# Examples
Asymmetric binary range — A in `[25%, 50%]`, B in `[50%, 75%]` — at a supercell size of 8 yields 3 partitions:
```jldoctest
julia> cr = ConcentrationRange([(1//4, 1//2), (1//2, 3//4)]);

julia> concentrations_in_range(cr, 8)
3-element Vector{Concentration}:
 Concentration(1//4, 3//4)
 Concentration(3//8, 5//8)
 Concentration(1//2, 1//2)
```
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
