# Radius-based HNF enumeration. Included from clusterExpansion.jl after the
# module's own cellRadius is defined and after LatticeColoringEnumeration.jl
# has provided getSymInequivHNFs / getAllHNFs / basesAreEquiv / getFixingLatticeOps
# / getPermG / getUniqueColorings.
#
# These functions are pure enumeration: they don't reference any CE-specific
# machinery (correlation matrices, design matrices, basis functions). After the
# split into Enumlib.jl, this file moves to the enum package.

"""
    radiusEnumHNFs(A; maxVol=15)

Enumerate every symmetry-inequivalent superlattice of the parent lattice
`A` up to volume `maxVol`, then sort the results by Minkowski-reduced cell
radius. Returns `(hnfs, radii, volumes)` indexed in the same order; the HNFs
are integer matrices in the lattice coordinates of `A`.
"""
function radiusEnumHNFs(A; maxVol=15)
    LG, _ = pointGroup(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:maxVol
        append!(hnfs, getSymInequivHNFs(i, LG))
    end
    hnfs = [round.(Int, inv(A) * minkReduce(A * h)) for h in hnfs]
    radii = [cellRadius(A * h) for h in hnfs]
    volumes = [abs.(round(Int, det(h))) for h in hnfs]
    idx = sortperm(radii)
    return hnfs[idx], radii[idx], volumes[idx]
end

"""
    getHNFColorings(h, k, LG)

For a single HNF `h`, enumerate all symmetry-inequivalent `k`-ary colorings
of its interior points under the lattice point group `LG`. Returns a vector
of colorings, where each coloring is a vector of integers in `0:k-1`.
"""
function getHNFColorings(h, k, LG::Vector{Matrix{Int64}})
    fixingOps = getFixingLatticeOps(h, LG)
    permG = getPermG(h, fixingOps, LG)
    return getUniqueColorings(k, permG)
end

"""
    radEnumByXcellRadius(A, x)

Return HNFs of `A` grouped by radius, keeping only those whose
Minkowski-reduced cell radius is at most `x` times the parent cell's
radius. Each entry of the returned vector is itself a vector of HNFs that
share the same radius.

This variant enumerates every HNF up to volume 80 without symmetry
reduction; use [`getSymInequivHNFsByCellRadius`](@ref) for the
symmetry-reduced version.
"""
function radEnumByXcellRadius(A, x)
    rCell = cellRadius(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:80
        append!(hnfs, getAllHNFs(i))
    end
    hnfs = [round.(Int, inv(A) * minkReduce(A * h)) for h in hnfs]
    radii = [cellRadius(A * h) for h in hnfs]
    rhnfs = Vector{Matrix{Int64}}()
    for r in radii
        if r ≤ x * rCell
            push!(rhnfs, hnfs[findall(radii .== r)])
        end
    end
    return rhnfs
end

"""
    getSymInequivHNFsByCellRadius(A, x; maxVol=20)

Enumerate symmetry-inequivalent HNFs of `A` whose Minkowski-reduced cell
radius is at most `x` times the parent cell's radius, drawing from all HNFs
up to volume `maxVol`. Returns `(hnfs, radii, volumes)` for the survivors.

Strategy: enumerate every HNF up to `maxVol`, drop those above the radius
cutoff, then remove symmetry duplicates within the survivors. Slower than
radius-first enumeration but bulletproof — guaranteed not to miss any
symmetry-inequivalent cell within the radius bound.
"""
function getSymInequivHNFsByCellRadius(A, x; maxVol=20)
    rCell = cellRadius(A)
    LG, _ = pointGroup(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:maxVol
        append!(hnfs, getAllHNFs(i))
    end
    hnfs = [round.(Int, inv(A) * minkReduce(A * h)) for h in hnfs]
    radii = round.([cellRadius(A * h) for h in hnfs], digits=10) # collapse FP-only differences
    volumes = abs.(round.(Int, det.(hnfs)))
    idx = findall(radii .≤ x * rCell)
    radii = radii[idx]
    hnfs = hnfs[idx]
    volumes = volumes[idx]
    mask = trues(length(hnfs))
    for i ∈ eachindex(hnfs)
        if !mask[i] continue end
        for j ∈ i+1:length(hnfs)
            if !mask[j] continue end
            if volumes[i] < volumes[j] break end
            if basesAreEquiv(hnfs[i], hnfs[j], LG)
                mask[j] = false
            end
        end
    end
    return hnfs[mask], radii[mask], abs.(round.(Int, det.(hnfs[mask])))
end

"""
    estimatedTime(h)

Heuristic estimate of the time needed to enumerate colorings of an HNF of
size `n = abs(det(h))`: returns `n^2 * log(n)`. Does not yet account for
k-point folding factors.
"""
function estimatedTime(h)
    s = abs(det(h))
    return s^2 * log(s)
end
