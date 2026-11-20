# TEMPORARY, IN-MEMORY ONLY. Replaces Enumlib._getSymInequivHNFs_with_degens for the current Julia session.
# src/ is not touched.
#
# Old: every pair (i, j) of volume-d HNFs is tested with basesAreEquiv, which loops over the rotations and builds a
# float inverse, a product and a rounded copy for each one: cost ~ N_HNF^2 x |LG| with three allocations per test.
# New: for each HNF not yet classified (in list order), apply every rotation g, bring g*H to the same lower-triangular
# Hermite form getAllHNFs uses, and look it up in a Dict of the list: cost ~ N_HNF x |LG|. The classes are the same
# (two superlattices are equivalent exactly when some g maps one onto the other), each class keeps its smallest index
# as the canonical one, and class sizes are counted the same way, so the output is identical.
#
#   include("bench/speedups/hnf_orbit_patch.jl")   # after `using Enumlib`
using Enumlib

@eval Enumlib begin
# Column-style Hermite normal form of an integer 3x3 matrix with nonzero determinant: L = M*U, U unimodular, L lower
# triangular with positive diagonal and 0 <= L[i,j] < L[i,i] for j < i -- the form getAllHNFs lists.
function _colhnf3(M::AbstractMatrix{<:Integer})
    A = Matrix{Int}(M)
    for r in 1:3
        # zero A[r, c] for c > r by gcd column operations among columns r..3
        for c in r+1:3
            while A[r, c] != 0
                q = div(A[r, r], A[r, c])
                for k in 1:3
                    A[k, r] -= q * A[k, c]
                end
                for k in 1:3                       # swap columns r and c
                    A[k, r], A[k, c] = A[k, c], A[k, r]
                end
            end
        end
        if A[r, r] < 0
            for k in 1:3; A[k, r] = -A[k, r]; end
        end
    end
    # reduce below-diagonal entries into [0, diagonal) with column operations from the right
    for r in 2:3, c in 1:r-1
        q = fld(A[r, c], A[r, r])
        if q != 0
            for k in 1:3; A[k, c] -= q * A[k, r]; end
        end
    end
    return A
end

_hnfkey(H) = (H[1,1], H[2,1], H[2,2], H[3,1], H[3,2], H[3,3])

function _getSymInequivHNFs_with_degens(d, LG::Vector{Matrix{Int}})
    HNFList = getAllHNFs(d)
    n = length(HNFList)
    index = Dict{NTuple{6,Int},Int}(_hnfkey(HNFList[i]) => i for i in 1:n)
    class_id = zeros(Int, n)
    for i in 1:n
        class_id[i] == 0 || continue
        class_id[i] = i
        for g in LG
            j = index[_hnfkey(_colhnf3(g * HNFList[i]))]
            class_id[j] == 0 && (class_id[j] = i)
        end
    end
    canonical_indices = findall(i -> class_id[i] == i, 1:n)
    canonical = [HNFList[i] for i in canonical_indices]
    class_sizes = [count(==(i), class_id) for i in canonical_indices]
    return canonical, class_sizes
end
end # @eval
