module Enumlib

using Combinatorics
using LinearAlgebra
using NormalForms
using Spacey, MinkowskiReduction

# --- v0.2 type catalog (chunk 1: foundation) ---
include("types/symmetry_op.jl")
include("types/parent_lattice.jl")

export
    # v0.2 type catalog (chunk 1)
    SymmetryOp, ParentLattice,
    basis, dset, space_group, ndset,

    # HNF enumeration (legacy; ports to new types in chunks 3+)
    getAllHNFs, tripletList, basesAreEquiv, getSymInequivHNFs,
    getFixingOps, getFixingLatticeOps, checkCartesianPt,
    # Permutation groups
    getPermG, getTransGroup,
    # Coordinates and supercell structures
    SuperTile, ColoredTile,
    gCoordsToOrdinals, ordinalToGcoords,
    getCartesianPts, getOrdinalsFromCartesian, get_nonzero_index,
    coloringsOfHNFList,
    # Group theory
    isaGroup, generateGroup,
    # Colorings
    getColorings, getSymEqvColorings_slow, reduceColorings, getUniqueColorings,
    # Cluster utilities
    isRotTransEquiv, isTransEquiv, canonClustOrder!, deleteTransDuplicates!,
    shiftToOrigin, isEquivClusters,
    # Cell utilities
    cellRadius,
    # Structure I/O
    enumStr, readStructenumout, readEnergies, readStrIn,
    # Radius-based enumeration
    radiusEnumHNFs, getHNFColorings, radEnumByXcellRadius,
    getSymInequivHNFsByCellRadius, estimatedTime

"""
    cellRadius(B)

Get the radius of the unit cell `B`. Radius is the max distance from the
center of the cell to any corner.
"""
function cellRadius(B)
    A = minkReduce(B)
    center = (A[:,1] + A[:,2] + A[:,3]) ./ 2
    corners = [[0., 0., 0.], A[:,1], A[:,2], A[:,3], A[:,1]+A[:,2], A[:,1]+A[:,3], A[:,2]+A[:,3], A[:,1]+A[:,2]+A[:,3]]
    return max(norm.([center - i for i in corners])...)
end

# --- cluster equivalence (no enum-file deps) ---

"""
    canonClustOrder!(clust)

Apply canonical ordering of cluster vertices for robust comparison.
"""
function canonClustOrder!(clust)
    clust .= hcat(sort(eachslice(clust, dims=2))...)
end

"""
    isTransEquiv(c1, c2)

Returns true if `c1` and `c2` are translates of each other.
"""
function isTransEquiv(c1, c2)
    return any([all([(c1.-c2)[:,1]] .≈ eachslice(c1.-c2, dims=2)[2:end])])
end

"""
    isRotTransEquiv(t1, t2, G)

Returns true if `t1` and any `g*t2` for `g ∈ G` are just translates of each
other. The point group `G` should be in the same coordinates as the points.
"""
function isRotTransEquiv(t1, t2, G)
    t1 = canonClustOrder!(t1)
    for g ∈ G
        t2g = hcat(sort(eachslice(g * t2, dims=2))...)
        if isTransEquiv(t1, t2g)
            return true
        end
    end
    return false
end

"""
    deleteTransDuplicates!(clusterList)

Remove clusters from `clusterList` that are translational duplicates of
another cluster.
"""
function deleteTransDuplicates!(clusterList)
    mask = falses(length(clusterList))
    for jr in eachindex(clusterList)
        if mask[jr] continue end
        for kr in jr+1:length(clusterList)
            t1 = hcat(sort(eachslice(clusterList[jr], dims=2))...)
            t2 = hcat(sort(eachslice(clusterList[kr], dims=2))...)
            if isTransEquiv(t1, t2)
                mask[kr] = true
            end
        end
    end
    deleteat!(clusterList, mask)
end

# --- group theory utilities ---

"""
    isaGroup(G)

Check whether the rows of `G` are closed under composition (i.e., form a
permutation group).
"""
function isaGroup(G)
    isagroup = true
    for iG in eachrow(G)
        for jG in eachrow(G)
            if iG[jG] ∉ eachrow(G)
                isagroup = false
            end
        end
    end
    return isagroup
end

"""
    generateGroup(generators)

Given a matrix whose rows are permutation generators, generate the full
group. Returns the rows sorted (identity first).
"""
function generateGroup(generators)
    while true
        closed = true
        for iG ∈ eachrow(generators)
            for jG ∈ eachrow(generators)
                if iG[jG] ∉ eachrow(generators)
                    generators = [generators; iG[jG]']
                    closed = false
                end
            end
        end
        if closed break end
    end
    return sortslices(generators, dims=1)
end

"""
    hash(mul, c)

Hash a coloring `c` of a tile into its base-10 integer using the place
values in `mul`.
"""
function hash(mul, c)
    return sum(mul .* c)
end

"""
    hash2coloring(hash, k, n)

Inverse of [`hash`](@ref): convert a base-10 hash back into a coloring of
length `n` with `k` colors.
"""
function hash2coloring(hash, k, n)
    coloring = zeros(Int64, n)
    r = hash - 1
    for i in n-1:-1:0
        d, r = divrem(r, k^i)
        coloring[n-i] = d
    end
    return coloring
end

# --- colorings ---

"""
    getColorings(k, n)

Generate the full list of `k`-ary colorings on `n` sites. Each coloring is
a vector of integers in `0:k-1`.
"""
function getColorings(k, n)
    return [collect(reverse(Tuple(c))) for c in CartesianIndices(ntuple(i->0:k-1, n))][:]
end

"""
    reduceColorings(colorings, k, G)

Reduce a list of colorings to the symmetrically inequivalent ones under the
group `G` (rows are permutations of the sites).
"""
function reduceColorings(colorings, k, G)
    n = length(colorings[1])
    mul = [k^(i-1) for i ∈ reverse(1:n)]
    hashTbl = trues(length(colorings))
    for (i, ic) in enumerate(colorings)
        if !hashTbl[i] continue end
        for g ∈ eachrow(G)
            test = hash(mul, ic[g]) + 1
            if test > i
                hashTbl[test] = false
            end
        end
    end
    return colorings[hashTbl]
end

"""
    getSymEqvColorings_slow(k, n, G)

Generate all colorings and reduce to symmetrically inequivalent ones under
`G`. Slower than [`getUniqueColorings`](@ref) (which uses a permutation
group from an HNF) but useful when only a permutation matrix is in hand.
"""
function getSymEqvColorings_slow(k, n, G)
    colorings = getColorings(k, n)
    return reduceColorings(colorings, k, G)
end

# --- enumeration sources (must come after the utilities they don't use,
#     before the functions that depend on getTransGroup, etc.) ---

include("LatticeColoringEnumeration.jl")
include("CEdataSupport.jl")
include("clusterequvi.jl")
# readPOSCAR.jl and makePOSCAR.jl live in scratch/ for now; they're
# standalone scripts with top-level scratch code that needs cleanup before
# they can be part of the module proper.

# --- permutation groups (depend on getTransGroup from LatticeColoringEnumeration) ---

"""
    getPermG(h, fixingOps, pLat, G::Vector{Matrix{Float64}})

Permutation group for the supercell `h` of parent lattice `pLat`, given the
ordinal vector `fixingOps` selecting the stabilizer subgroup of the
Cartesian point group `G`. Eq. 3 of the original enumlib paper, in
Cartesian coordinates.
"""
function getPermG(h, fixingOps, pLat, G::Vector{Matrix{Float64}})
    S, L, R = snf(h)
    LAinv = L * inv(pLat)
    invLAinv = inv(LAinv)
    z1, z2, z3 = diag(S)
    GspcSites = [[i,j,k] for i ∈ 0:z1-1 for j ∈ 0:z2-1 for k ∈ 0:z3-1]
    GSitesRot = [[mod.(round.(Int, LAinv * iR * invLAinv * i), [z1; z2; z3]) for i ∈ GspcSites] for iR ∈ G[fixingOps]]
    factor = [z2*z3, z3, 1]
    rotGrp = [[sum(i .* factor) + 1 for i in j] for j in GSitesRot] |> unique
    sort!(rotGrp)
    tGrp = getTransGroup([z1, z2, z3])
    perm = Vector{Vector{Int}}()
    for iR ∈ rotGrp
        for iT ∈ tGrp
            push!(perm, iR[iT])
        end
    end
    return perm
end

"""
    getPermG(h, fixingOps, LG::Vector{Matrix{Int}})

Lattice-coordinate variant of [`getPermG`](@ref): same construction but
with the lattice-coordinate point group `LG` directly.
"""
function getPermG(h, fixingOps, LG::Vector{Matrix{Int}})
    S, L, _ = snf(h)
    Linv = round.(Int, inv(L))
    z1, z2, z3 = diag(S)
    GspcSites = [[i,j,k] for i ∈ 0:z1-1 for j ∈ 0:z2-1 for k ∈ 0:z3-1]
    GSitesRot = [[mod.(L * iLG * Linv * i, [z1; z2; z3]) for i ∈ GspcSites] for iLG ∈ LG[fixingOps]]
    factor = [z2*z3, z3, 1]
    rotGrp = [[sum(i .* factor) + 1 for i in j] for j in GSitesRot] |> unique
    sort!(rotGrp)
    tGrp = getTransGroup([z1, z2, z3])
    perm = Vector{Vector{Int}}()
    for iR ∈ rotGrp
        for iT ∈ tGrp
            push!(perm, iR[iT])
        end
    end
    return perm
end

# --- colorings via permutation group (depends on hash/hash2coloring above) ---

"""
    getUniqueColorings(k, pG)

Given the permutation group `pG` of a supercell (from
[`getPermG`](@ref)), return the symmetrically inequivalent `k`-ary
colorings. Eliminates superperiodic colorings.
"""
function getUniqueColorings(k, pG)
    n = length(pG[1])
    idx = ntuple(i->0:k-1, n)
    mul = [k^(i-1) for i ∈ reverse(1:n)]
    hashTbl = trues(k^n)
    for (i, ic) in enumerate(CartesianIndices(idx))
        c = reverse(Tuple(ic))
        if !hashTbl[i] continue end
        for (ig, g) ∈ enumerate(pG[2:end])
            test = Enumlib.hash(mul, c[g]) + 1
            if test > i || test == i && ig < n
                hashTbl[test] = false
            end
        end
    end
    return [hash2coloring(i, k, n) for i ∈ findall(hashTbl)]
end

# --- radius-based HNF enumeration (uses cellRadius, getSymInequivHNFs,
#     getFixingLatticeOps, getPermG, getAllHNFs, basesAreEquiv) ---

include("radiusEnumeration.jl")

end # module Enumlib
