# The multinomial-hash algorithm — Hart-Nelson-Forcade 2012.
#
# Hashes labelings of a fixed-multiplicity multiset into ranks in [0, C-1] where
# C = multinomial(n; a_1, ..., a_k). The crossing-out algorithm uses this hash
# to enumerate symmetry-inequivalent structures at fixed concentration in O(C)
# memory instead of O(k^n) — a 20-100× saving for typical use cases (Ag-Pt
# 15:17 in 32-cell: 5.7E8 candidates instead of 4.3E9 for unrestricted binary).
#
# The encoding is mixed-radix: for each color i = 1..k-1 (in order), compute
# the colex rank x_i of color i's positions among the still-unfilled slots,
# then combine via:
#     y = x_1 + C_1 * (x_2 + C_2 * (x_3 + ... + C_{k-2} * x_{k-1}))
# where C_i = binomial(n_remaining_i, a_i). Color k is determined by the rest.
#
# See research.md §4.3 for the paper's algorithm description.

"""
    multinomial_count(multiplicities::AbstractVector{<:Integer}) :: BigInt

Compute the multinomial coefficient `multinomial(n; a_1, ..., a_k)` exactly using the iterative-binomial identity:

    multinomial(a_1, ..., a_k) = ∏_{i=1..k} binomial(a_1 + ... + a_i, a_i)

Mathematically equivalent to `n! / ∏ a_i!`, but evaluates one binomial at a time so factors cancel as we go — no wasteful `n!` intermediate. Returns `BigInt` so the result is exact for arbitrary input (binary at n=70 already overflows `Int64`); the BigInt cost is ~µs per call, negligible since `multinomial_count` runs once per (supercell, concentration) pair during pre-flight, never in an inner loop.

See `docs/notes/chunk6-review.md` for the full tradeoff analysis (why not `Combinatorics.multinomial` + try/catch, why not the factorial form, inner-loop overflow safety proof).
"""
function multinomial_count(multiplicities::AbstractVector{<:Integer})::BigInt
    s = BigInt(0)
    result = BigInt(1)
    for k in multiplicities
        s += k
        result *= binomial(s, BigInt(k))
    end
    return result
end

"""
    multinomial_hash(coloring::AbstractVector{<:Integer},
                     multiplicities::AbstractVector{<:Integer}) :: Int

Hash a coloring — a length-`n` vector with values in `0:k-1` and per-color counts matching `multiplicities` — to its rank in `[0, C-1]` where `C = multinomial(n; multiplicities)`. Implements the mixed-radix scheme from HF 2012 §3.1.

For each color `i = 1..k-1` (processed in order), this:
1. Identifies the positions where color `i-1` sits *among the still-unfilled slots*.
2. Computes the colex rank `x_i` of those positions within the unfilled slots.
3. Accumulates `y += x_i * P` where `P` is the running product of `C_j` for `j < i`.

Color `k-1` (the last) is determined by what's left, so we don't include it in the hash.

Assumes the coloring satisfies the multiplicity constraint. Behavior is undefined otherwise (caller's responsibility — `getUniqueColorings_multinomial` only generates valid colorings).
"""
function multinomial_hash(coloring::AbstractVector{<:Integer},
                          multiplicities::AbstractVector{<:Integer})
    n = length(coloring)
    k = length(multiplicities)
    sum(multiplicities) == n ||
        throw(DimensionMismatch("sum(multiplicities) = $(sum(multiplicities)) ≠ length(coloring) = $n"))

    y = 0
    P = 1                               # running product of C_j for j < i
    n_remaining = n
    filled = falses(n)                  # positions already assigned to colors 0..i-2

    # Process colors 0, 1, ..., k-2. Color k-1 is determined by what's left.
    for i in 0:k-2
        a_i = multiplicities[i+1]       # 1-indexed multiplicities; 0-indexed colors
        if a_i == 0
            # No positions for this color; x_i = 0, C_i = 1 (degenerate). Skip.
            continue
        end

        # Compute x_i = colex rank of color i's positions among the unfilled slots.
        # Walk through the unfilled slots in order, numbering them 0, 1, 2, ...;
        # when we see a position whose color is i, accumulate its contribution to
        # the colex rank.
        x_i = 0
        slot_idx = 0      # 0-indexed position among unfilled slots
        m_i = 0           # number of color-i positions seen so far (1-indexed for colex)
        for pos in 1:n
            filled[pos] && continue
            if coloring[pos] == i
                m_i += 1
                x_i += binomial(slot_idx, m_i)
                filled[pos] = true
            end
            slot_idx += 1
        end

        C_i = binomial(n_remaining, a_i)
        y += x_i * P
        P *= C_i
        n_remaining -= a_i
    end
    return y
end

"""
    multinomial_unhash(idx::Integer, multiplicities::AbstractVector{<:Integer}) :: Vector{Int8}

Inverse of [`multinomial_hash`](@ref): given an index `idx ∈ [0, C-1]`, recover the unique coloring with the given multiplicities.

For each color `i = 0..k-2` in order, extracts `x_i = (idx_remaining ÷ P_so_far) mod C_i`, then maps `x_i` back to a set of `a_i` positions (within the still-unfilled slots) via inverse-colex. Color `k-1` fills whatever's left.
"""
function multinomial_unhash(idx::Integer, multiplicities::AbstractVector{<:Integer})
    n = sum(multiplicities)
    k = length(multiplicities)
    coloring = fill(Int8(k - 1), n)         # default-fill with last color
    filled = falses(n)
    n_remaining = n
    idx_remaining = Int(idx)

    for i in 0:k-2
        a_i = multiplicities[i+1]
        if a_i == 0
            continue
        end

        C_i = binomial(n_remaining, a_i)
        # x_i is the rank of color-i's position-set within the unfilled slots.
        # Mixed-radix decode: x_i is the "innermost" remaining digit for this layer.
        x_i = idx_remaining % C_i
        idx_remaining = div(idx_remaining, C_i)

        # Inverse colex: given rank x_i and target count a_i (in n_remaining slots),
        # find the corresponding subset of unfilled slot indices. Greedy:
        # for j = a_i, a_i-1, ..., 1, find the largest c with binomial(c, j) <= x_i,
        # set c as the j-th position, subtract binomial(c, j).
        positions_in_unfilled = Int[]
        x_remaining = x_i
        for j in a_i:-1:1
            c = j - 1
            while binomial(c + 1, j) <= x_remaining
                c += 1
            end
            push!(positions_in_unfilled, c)
            x_remaining -= binomial(c, j)
        end

        # Translate slot-indices to absolute positions and mark as filled with color i.
        # `positions_in_unfilled` was built in reverse order (j: a_i down to 1); each
        # entry is a 0-indexed slot in the unfilled-slot enumeration. Walk the unfilled
        # positions in order and pick the matching ones.
        target_slots = sort(positions_in_unfilled)  # ascending 0-indexed slot indices
        slot_idx = 0
        next_target = 1
        for pos in 1:n
            filled[pos] && continue
            if next_target <= length(target_slots) && slot_idx == target_slots[next_target]
                coloring[pos] = Int8(i)
                filled[pos] = true
                next_target += 1
            end
            slot_idx += 1
        end

        n_remaining -= a_i
    end
    return coloring
end

"""
    getUniqueColorings_multinomial(perm_group::AbstractVector,
                                   multiplicities::AbstractVector{<:Integer};
                                   include_superperiodic = false) :: Vector{Vector{Int8}}

Symmetry-inequivalent colorings at fixed concentration. Crossing-out algorithm over the multinomial-hash space — the chunk-6 analog of `getUniqueColorings(k, perm_group)` from chunk 5.

Iterates over all `C = multinomial(n; multiplicities)` valid colorings (each at its hash index), maintains a `BitVector(C)` "visited" mask, and when a coloring is the lex-smallest representative of its orbit under `perm_group`, keeps it and crosses out its orbit-mates.

By default (`include_superperiodic = false`), drops super-periodic colorings — those fixed by some non-identity pure translation. Pass `true` to keep them and return the full Burnside orbit space (research.md §5.2.1). Note: at asymmetric concentrations (e.g., 15:17 in n=32), super-periodic structures are number-theoretically empty, so the kwarg is a no-op there.

For chunk-6 sizes (Ag-Pt at 15:17 in n=32 → C ≈ 5.7E8 → 71 MB bitmap), this fits in memory comfortably. For larger cases the bitmap won't fit in `typemax(Int)` and `enumerate(...)` redirects to the recursive-stabilizer tree (chunk 8). The pre-flight cost gate (chunk 7) catches the overflow before allocation.
"""
function getUniqueColorings_multinomial(perm_group, multiplicities::AbstractVector{<:Integer};
                                        include_superperiodic::Bool = false)
    C = multinomial_count(multiplicities)
    C <= typemax(Int) ||
        throw(ArgumentError(
            "multinomial coefficient $(C) exceeds typemax(Int) — this enumeration " *
            "needs the recursive-stabilizer (Morgan 2017) algorithm, planned for chunk 8."))
    C_int = Int(C)
    n = sum(multiplicities)

    # `perm_group` is structured as (rotation × translation), with the first
    # element the identity and the next n-1 elements the non-identity translations
    # (per `getPermG`'s construction in src/Enumlib.jl). A coloring fixed by any
    # non-identity translation is super-periodic — its true period is shorter than
    # the supercell, so it's already enumerated as a smaller-supercell derivative
    # structure and we must drop it (Hart-Forcade 2008 step 5d). Skipped when
    # include_superperiodic = true.
    visited = trues(C_int)
    survivors = Vector{Int8}[]
    for idx in 0:C_int-1
        visited[idx + 1] || continue
        coloring = multinomial_unhash(idx, multiplicities)

        if !include_superperiodic
            # Super-periodicity check: if any non-identity translation fixes this
            # coloring, drop it. The non-identity translations are perm_group[2:n].
            is_super_periodic = false
            for ig in 2:n
                ig <= length(perm_group) || break
                permuted = coloring[perm_group[ig]]
                if permuted == coloring
                    is_super_periodic = true
                    break
                end
            end

            if is_super_periodic
                visited[idx + 1] = false
                continue
            end
        end

        push!(survivors, coloring)

        # Cross out symmetry-equivalent labelings (including the labeling itself).
        for g in perm_group
            permuted = coloring[g]
            j = multinomial_hash(permuted, multiplicities)
            visited[j + 1] = false
        end
    end
    return survivors
end
