# TEMPORARY, IN-MEMORY ONLY. Replaces Enumlib._is_super_periodic for the current Julia
# session with a version that compares the coloring with its translated image entry by
# entry, stopping at the first difference, instead of building the translated coloring
# as a new array for every translation. src/ is not touched.
#
#   include("bench/tree-profile/superperiodic_patch.jl")   # after `using Enumlib`

using Enumlib

@eval Enumlib function _is_super_periodic(coloring::AbstractVector, perm_group::AbstractVector,
                                         n_cells::Int)
    for ig in 2:min(n_cells, length(perm_group))
        g = perm_group[ig]
        fixed = true
        @inbounds for i in eachindex(coloring)
            if coloring[g[i]] != coloring[i]
                fixed = false
                break
            end
        end
        fixed && return true
    end
    return false
end
