# Morgan-Hart-Forcade 2017 recursive-stabilizer tree algorithm.
#
# Builds a tree where each level places one color. At each node, the partial
# coloring's location vector (chunk-6 multinomial hash applied per-level)
# identifies the partial; if a permutation in the parent's stabilizer maps
# the partial to a lex-smaller location vector, the entire subtree is a
# duplicate and gets pruned.
#
# Two key ideas:
#   1. Partial colorings — pruning at depth ℓ kills all 2^(k-ℓ)+ descendants.
#   2. Shrinking stabilizers — comparison cost decreases with depth.
#
# See research.md §4.4 (Morgan 2017 digest) and chunk8-design.md for the
# design discussion. Built ON TOP OF chunk 6's multinomial-hash machinery.

"""
    getUniqueColorings_recursive_stabilizer(perm_group, multiplicities;
                                             site_mask = nothing) -> Vector{Vector{Int8}}

Symmetry-inequivalent colorings at fixed concentration via the Morgan-Hart 2017 tree-search-with-shrinking-stabilizers algorithm. Internal driver — users reach this algorithm via `enumerate(parent, sites; algorithm = :recursive_stabilizer, ...)`. `Enumlib.getUniqueColorings_multinomial` and this function are the two parallel concentration-restricted enumerators.

For high configurational freedom (large n, k ≥ 3), the tree is asymptotically faster than the bitmap algorithm — Morgan-Hart 2017 Fig. 5 shows ~100× speedup at FCC ternary n=20. For small n the bitmap may still be faster (no per-level overhead); `:auto` dispatch in `enumerate(...)` picks based on the enumeration resource check (`estimate_cost`).

Returns every canonical labeling (one per orbit under `perm_group`). Super-periodic filtering is the caller's job (see `Enumlib._enumerate_per_concentration`) — the algorithm itself has no notion of "pure translation"; that's a property of the supercell's translation subgroup, which lives in the caller's scope where `n_cells = volume(hnf)` is in scope.

The optional `site_mask` kwarg (`BitMatrix(n, k)`) enables per-site restricted allowed labels (Regime C). When `nothing` (default), every position can carry every color. When supplied, the tree branching at each depth filters `unfilled_positions` to those where `site_mask[pos, depth+1]` is true; if too few allowed positions remain to satisfy the multiplicity for the current color, the branch is pruned.
"""
function getUniqueColorings_recursive_stabilizer(perm_group,
                                                  multiplicities::AbstractVector{<:Integer};
                                                  site_mask::Union{Nothing, BitMatrix} = nothing)
    n = sum(multiplicities)
    k = length(multiplicities)
    n == length(perm_group[1]) ||
        throw(DimensionMismatch(
            "sum(multiplicities) = $n ≠ length(perm_group[1]) = $(length(perm_group[1]))"))

    if site_mask !== nothing
        size(site_mask) == (n, k) ||
            throw(DimensionMismatch(
                "site_mask must be ($n, $k), got $(size(site_mask))"))
    end

    output = Vector{Vector{Int8}}()
    # Initial state: empty partial, full perm_group as the stabilizer.
    partial = fill(Int8(-1), n)        # -1 means "unfilled"
    binom = _binomial_table(n)
    _descend!(output, partial, perm_group, multiplicities, 0, n, k, site_mask, binom)
    return output
end

# binom[m+1, j+1] == binomial(m, j) for 0 ≤ j ≤ m ≤ n, saturating at typemax(Int)
# instead of overflowing. Built once per call: the branch decoder looks these up
# in its innermost loop, where computing them afresh dominated the run time.
# Saturation is safe there — every lookup is compared against a rank smaller
# than the (checked, unsaturated) branching factor, so a saturated entry
# compares correctly, and the entries it subtracts are never saturated.
function _binomial_table(n::Int)
    binom = zeros(Int, n + 1, n + 1)
    for m in 0:n
        binom[m + 1, 1] = 1
        for j in 1:m
            a, b = binom[m, j], binom[m, j + 1]          # C(m-1, j-1), C(m-1, j)
            s = a + b
            binom[m + 1, j + 1] = (s < a || s < b) ? typemax(Int) : s
        end
    end
    return binom
end
_binom(binom, m, j) = (0 <= j <= m) ? binom[m + 1, j + 1] : 0

# Recursive descent. At depth `ℓ` we've placed colors `0..ℓ-1`. Place color ℓ
# now (taking `multiplicities[ℓ+1]` positions from the unfilled set).
#
# `site_mask` (or `nothing`) restricts which positions can carry each color.
# When supplied, position `pos` can carry color `c` only if `site_mask[pos, c+1]`
# is true. The branching at each depth filters unfilled positions accordingly.
function _descend!(output, partial, parent_stab,
                   multiplicities, depth, n, k,
                   site_mask::Union{Nothing, BitMatrix}, binom)
    if depth == k - 1
        # Last color is determined by what's left. Materialize the leaf.
        # Super-periodicity is the caller's responsibility (it needs
        # n_cells, which we don't have here).
        full_partial = copy(partial)
        for pos in 1:n
            if full_partial[pos] == -1
                # Site-restriction check (chunk 6.5): the last-color slot must
                # permit color k-1. If any position can't host it, the entire
                # branch is unsatisfiable — abandon.
                if site_mask !== nothing && !site_mask[pos, k]
                    return
                end
                full_partial[pos] = Int8(k - 1)
            end
        end
        push!(output, full_partial)
        return
    end

    # Place color `depth` (0-indexed) next. We need a_{depth+1} positions
    # from the currently unfilled set (filtered by site_mask, if supplied).
    a_here = multiplicities[depth + 1]
    unfilled_positions = if site_mask === nothing
        [i for i in 1:n if partial[i] == -1]
    else
        # Site-restriction-aware: only positions where this color is allowed.
        [i for i in 1:n if partial[i] == -1 && site_mask[i, depth + 1]]
    end
    n_unfilled = length(unfilled_positions)

    if a_here == 0
        # No positions for this color — descend without placing.
        _descend!(output, partial, parent_stab, multiplicities, depth + 1, n, k,
                  site_mask, binom)
        return
    end

    # Branch pruning: if fewer allowed positions than required atoms of this
    # color, the branch is unsatisfiable (only matters when site_mask is in
    # play; without it n_unfilled is always ≥ a_here by construction).
    if n_unfilled < a_here
        return
    end

    branching = binomial(n_unfilled, a_here)
    branching <= typemax(Int) ||
        throw(ArgumentError(
            "branching factor $(branching) exceeds typemax(Int) at depth $depth"))

    chosen_slot_idxs = Vector{Int}(undef, a_here)
    for x in 0:branching-1
        # Decode x to a subset of unfilled-slot indices (0-indexed). Branches run
        # in colex order of the subset, which fixes the order of the output.
        _inverse_colex_rank!(chosen_slot_idxs, x, a_here, binom)
        # Place the color.
        for i in chosen_slot_idxs
            partial[unfilled_positions[i + 1]] = Int8(depth)
        end

        # Canonicality check: if any g in the parent stabilizer maps the partial
        # to a smaller one, this is a duplicate.
        if _is_canonical(partial, parent_stab, depth + 1)
            # Compute the new stabilizer — filter parent_stab to perms that
            # fix the new partial.
            new_stab = _stabilize_partial(parent_stab, partial)
            _descend!(output, partial, new_stab, multiplicities, depth + 1, n, k,
                      site_mask, binom)
        end

        # Backtrack: un-place the color.
        for i in chosen_slot_idxs
            partial[unfilled_positions[i + 1]] = Int8(-1)
        end
    end
end

# Inverse colex rank: given rank `x` (0-indexed), write into `positions` which
# `a` slots (0-indexed, ascending) it corresponds to. Mirrors the body of
# chunk 6's `multinomial_unhash` for a single color; binomials come from the
# table built in `getUniqueColorings_recursive_stabilizer`.
function _inverse_colex_rank!(positions::Vector{Int}, x::Int, a::Int, binom)
    x_remaining = x
    for j in a:-1:1
        c = j - 1
        while _binom(binom, c + 1, j) <= x_remaining
            c += 1
        end
        positions[j] = c                 # largest first, so filling j = a…1 sorts it
        x_remaining -= _binom(binom, c, j)
    end
    return positions
end

# Canonicality check. A partial is canonical when no g in `parent_stab` maps it
# to a lex-smaller location vector — the vector of per-color colex ranks
# (chunk 6's `multinomial_hash`, stopped at `depth`) of each color's positions
# among the slots left for it.
#
# The ranks never need computing. Compare color by color: while earlier colors
# occupy the same positions in both partials, both have the same slots left for
# the next color, numbered the same way, so comparing that color's colex ranks
# is comparing its two position sets in colex order — decided by the largest
# position where they differ. Scanning positions from the top, the first one
# where exactly one partial has this color settles it: if it is the current
# partial's, the permuted one is smaller. The first color that differs decides
# the whole comparison.
#
# The site mask needs no special handling, because `parent_stab` maps allowed
# positions to allowed positions (the caller filters the group by the mask), so
# every color sits only on slots it may use in both partials. This replaced a
# version that built each location vector with binomial sums and fresh arrays
# for every g, which was most of the run time on large groups. The permuted
# partial is read through `g` rather than copied, since the comparison usually
# settles within the first few positions from the top.
function _is_canonical(partial::AbstractVector, parent_stab, depth::Int)
    for g in parent_stab
        _permuted_colex_less(partial, g, depth) && return false
    end
    return true
end

# True when `partial[g]` precedes `partial` in the order described above.
function _permuted_colex_less(partial::AbstractVector, g::AbstractVector, depth::Int)
    n = length(partial)
    length(g) == n || throw(DimensionMismatch("permutation length ≠ partial length"))
    for color in 0:depth-1
        c = Int8(color)
        for pos in n:-1:1
            @inbounds in_perm = partial[g[pos]] == c
            @inbounds in_self = partial[pos] == c
            in_perm == in_self && continue
            return in_self               # partial holds the larger position: partial[g] is smaller
        end
    end
    return false                         # equal through `depth`
end

# Stabilizer of the partial coloring under parent_stab — the subgroup of
# elements that fix the partial (every position keeps its color).
function _stabilize_partial(parent_stab, partial::AbstractVector)
    new_stab = Vector{Vector{Int}}()
    for g in parent_stab
        fixes = true
        for i in eachindex(partial)
            if partial[g[i]] != partial[i]
                fixes = false
                break
            end
        end
        fixes && push!(new_stab, g)
    end
    return new_stab
end
