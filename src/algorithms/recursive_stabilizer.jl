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
                                             include_superperiodic = false)
        :: Vector{Vector{Int8}}

Symmetry-inequivalent colorings at fixed concentration via the Morgan 2017 tree-search-with-shrinking-stabilizers algorithm. Public driver — analog of `getUniqueColorings_multinomial` from chunk 6.

For high configurational freedom (large n, k ≥ 3), the tree is asymptotically faster than chunk-6's bitmap algorithm — the paper's Fig. 5 shows ~100× speedup at FCC ternary n=20. For small n, chunk-6's bitmap may still be faster (no per-level overhead); `:auto` dispatch picks based on the chunk-7.5 cost estimate.

By default (`include_superperiodic = false`), drops super-periodic colorings — those fixed by some non-identity pure translation. See `research.md` §5.2.1.
"""
function getUniqueColorings_recursive_stabilizer(perm_group,
                                                  multiplicities::AbstractVector{<:Integer};
                                                  include_superperiodic::Bool = false)
    n = sum(multiplicities)
    k = length(multiplicities)
    n == length(perm_group[1]) ||
        throw(DimensionMismatch(
            "sum(multiplicities) = $n ≠ length(perm_group[1]) = $(length(perm_group[1]))"))

    output = Vector{Vector{Int8}}()
    # Initial state: empty partial, full perm_group as the stabilizer, empty loc.
    partial = fill(Int8(-1), n)        # -1 means "unfilled"
    current_loc = Int[]
    _descend!(output, partial, perm_group, current_loc,
              multiplicities, 0, n, k, perm_group, include_superperiodic)
    return output
end

# Recursive descent. At depth `ℓ` we've placed colors `0..ℓ-1`. Place color ℓ
# now (taking `multiplicities[ℓ+1]` positions from the unfilled set).
function _descend!(output, partial, parent_stab, current_loc,
                   multiplicities, depth, n, k, full_group, include_superperiodic)
    if depth == k - 1
        # Last color is determined by what's left. Materialize the leaf and
        # apply the super-periodicity check.
        full_partial = copy(partial)
        for pos in 1:n
            if full_partial[pos] == -1
                full_partial[pos] = Int8(k - 1)
            end
        end

        # Super-periodicity: drop if any non-identity translation fixes it.
        # The first n elements of full_group are the translation subgroup
        # (per getPermG: identity rotation × n translations). Non-identity
        # translations are full_group[2:n].
        if !include_superperiodic
            for ig in 2:min(n, length(full_group))
                if full_partial[full_group[ig]] == full_partial
                    return  # super-periodic; drop
                end
            end
        end

        push!(output, full_partial)
        return
    end

    # Place color `depth` (0-indexed) next. We need a_{depth+1} positions
    # from the currently unfilled set.
    a_here = multiplicities[depth + 1]
    unfilled_positions = [i for i in 1:n if partial[i] == -1]
    n_unfilled = length(unfilled_positions)

    if a_here == 0
        # No positions for this color — descend without placing.
        push!(current_loc, 0)
        _descend!(output, partial, parent_stab, current_loc,
                  multiplicities, depth + 1, n, k, full_group, include_superperiodic)
        pop!(current_loc)
        return
    end

    branching = binomial(n_unfilled, a_here)
    branching <= typemax(Int) ||
        throw(ArgumentError(
            "branching factor $(branching) exceeds typemax(Int) at depth $depth"))

    for x in 0:branching-1
        # Decode x to a subset of unfilled-slot indices (0-indexed).
        chosen_slot_idxs = _inverse_colex_rank(x, a_here, n_unfilled)
        # Translate to absolute positions.
        chosen_positions = [unfilled_positions[i + 1] for i in chosen_slot_idxs]
        # Place the color.
        for pos in chosen_positions
            partial[pos] = Int8(depth)
        end
        push!(current_loc, x)

        # Canonicality check: walk parent stabilizer; if any g maps loc to
        # a lex-smaller loc, this is a duplicate.
        if _is_canonical(partial, parent_stab, multiplicities, depth + 1, current_loc)
            # Compute the new stabilizer — filter parent_stab to perms that
            # fix the new partial.
            new_stab = _stabilize_partial(parent_stab, partial)
            _descend!(output, partial, new_stab, current_loc,
                      multiplicities, depth + 1, n, k, full_group, include_superperiodic)
        end

        # Backtrack: un-place the color, pop loc.
        for pos in chosen_positions
            partial[pos] = Int8(-1)
        end
        pop!(current_loc)
    end
end

# Inverse colex rank: given rank `x` (0-indexed), find which `a` of `n` slots
# (0-indexed) it corresponds to. Returns sorted ascending. Mirrors the body
# of chunk 6's `multinomial_unhash` for a single color.
function _inverse_colex_rank(x::Int, a::Int, n::Int)
    a == 0 && return Int[]
    positions = Int[]
    x_remaining = x
    for j in a:-1:1
        c = j - 1
        while binomial(c + 1, j) <= x_remaining
            c += 1
        end
        push!(positions, c)
        x_remaining -= binomial(c, j)
    end
    sort!(positions)
    return positions
end

# Compute the location vector of `partial` at the given `depth` (number of
# colors placed). Returns Vector{Int} of length `depth`.
#
# This is the same per-color rank computation as chunk 6's `multinomial_hash`,
# but stops at depth ℓ rather than going to k.
function _location_vector(partial::AbstractVector, multiplicities, depth::Int)
    n = length(partial)
    loc = Int[]
    consumed = falses(n)
    n_remaining = n

    for color in 0:depth-1
        a_color = multiplicities[color + 1]
        if a_color == 0
            push!(loc, 0)
            continue
        end

        # x_color = colex rank of color's positions among the still-unconsumed slots.
        x_color = 0
        slot_idx = 0
        m = 0
        for pos in 1:n
            consumed[pos] && continue
            if partial[pos] == Int8(color)
                m += 1
                x_color += binomial(slot_idx, m)
                consumed[pos] = true
            end
            slot_idx += 1
        end
        push!(loc, x_color)
        n_remaining -= a_color
    end
    return loc
end

# Canonicality check. Walks `parent_stab`; for each `g`, computes the
# location vector of `partial[g]` (the permuted partial) at this depth.
# Returns false if any `permuted_loc` is lex-smaller than `current_loc`,
# true otherwise.
function _is_canonical(partial::AbstractVector, parent_stab,
                       multiplicities, depth::Int, current_loc)
    permuted = similar(partial)
    for g in parent_stab
        # permuted = partial[g]
        for i in eachindex(partial)
            permuted[i] = partial[g[i]]
        end
        # If permuted == partial, identity-like effect — skip (loc unchanged).
        permuted == partial && continue
        permuted_loc = _location_vector(permuted, multiplicities, depth)
        # Lex-compare.
        if permuted_loc < current_loc
            return false
        end
    end
    return true
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
