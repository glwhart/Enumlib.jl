# TEMPORARY, IN-MEMORY ONLY. Replaces Enumlib._descend! for the current Julia session
# with a version that steps from one set of sites to the next in colex order,
# instead of decoding every index through the binomial table. src/ is not touched.
#
#   include("bench/tree-profile/successor_patch.jl")   # after `using Enumlib`

using Enumlib

@eval Enumlib begin
# Advance `idx` (0-based, ascending, length a) to the next a-subset of 0:m-1 in colex
# order. Returns false when `idx` was the last one.
function _next_colex!(idx::Vector{Int}, m::Int)
    a = length(idx)
    j = 1
    while j < a && idx[j] + 1 == idx[j + 1]
        j += 1
    end
    if j == a && idx[a] + 1 >= m
        return false
    end
    idx[j] += 1
    for i in 1:j-1
        idx[i] = i - 1
    end
    return true
end

function _descend!(output, partial, parent_stab,
                   multiplicities, depth, n, k,
                   site_mask::Union{Nothing, BitMatrix}, binom)
    if depth == k - 1
        full_partial = copy(partial)
        for pos in 1:n
            if full_partial[pos] == -1
                if site_mask !== nothing && !site_mask[pos, k]
                    return
                end
                full_partial[pos] = Int8(k - 1)
            end
        end
        push!(output, full_partial)
        return
    end
    a_here = multiplicities[depth + 1]
    unfilled_positions = if site_mask === nothing
        [i for i in 1:n if partial[i] == -1]
    else
        [i for i in 1:n if partial[i] == -1 && site_mask[i, depth + 1]]
    end
    n_unfilled = length(unfilled_positions)
    if a_here == 0
        _descend!(output, partial, parent_stab, multiplicities, depth + 1, n, k,
                  site_mask, binom)
        return
    end
    n_unfilled < a_here && return
    branching = binomial(n_unfilled, a_here)
    branching <= typemax(Int) ||
        throw(ArgumentError(
            "branching factor $(branching) exceeds typemax(Int) at depth $depth"))

    # --- the only change: step through the subsets instead of decoding each rank ---
    chosen_slot_idxs = collect(0:a_here-1)          # first subset in colex order
    while true
        for i in chosen_slot_idxs
            partial[unfilled_positions[i + 1]] = Int8(depth)
        end
        if _is_canonical(partial, parent_stab, depth + 1)
            new_stab = _stabilize_partial(parent_stab, partial)
            _descend!(output, partial, new_stab, multiplicities, depth + 1, n, k,
                      site_mask, binom)
        end
        for i in chosen_slot_idxs
            partial[unfilled_positions[i + 1]] = Int8(-1)
        end
        _next_colex!(chosen_slot_idxs, n_unfilled) || break
    end
end
end # @eval

# Check the stepping order against the existing decoder for every (m, a) up to m = 14.
let binom = Enumlib._binomial_table(14), buf = Int[]
    for m in 1:14, a in 1:m
        idx = collect(0:a-1); resize!(buf, a)
        for x in 0:binomial(m, a)-1
            Enumlib._inverse_colex_rank!(buf, x, a, binom)
            buf == idx || error("order differs at m=$m a=$a rank=$x")
            more = Enumlib._next_colex!(idx, m)
            more == (x < binomial(m, a) - 1) || error("wrong end at m=$m a=$a")
        end
    end
    println("successor_patch: stepping order matches the existing decoder for all m ≤ 14")
end
