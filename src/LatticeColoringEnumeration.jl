# Internal helpers — un-exported in chunk 13b.1. Call via `Enumlib.foo(...)`
# if you need them.

# Chunk 5 deletions (closes chunk-3-review item 3):
# - struct SuperTile (3D variant; flagged "not yet used" in original) — removed.
# - struct ColoredTile (depended on SuperTile) — removed.
# - function coloringsOfHNFList(hnfs, k, LG) — supplanted by `enumerate(parent,
#   sites; supercells=ExplicitHNFs(hnfs))` against the new public API.
# The 2D analog SuperTile (in LatticeEnumeration2D.jl) is a separate orphaned
# subsystem and is not affected by this cleanup.


# Old ParentLattice struct removed — replaced by the parametric ParentLattice{D} in
# src/types/parent_lattice.jl (chunk 1 of v0.2 plan). Confirmed zero in-repo callers
# constructed the old struct; the `pLat` parameter in functions like
# getSymInequivHNFs(d, pLat, G) is just a raw 3x3 basis matrix, not the struct.

""" Generate all of the HNF matrices of with determinant n """
function getAllHNFs(n)
# Even for n≈65 (>10,000 HNFs), this takes less than a second. No need for anything fancier because HNFs of such size are way beyond current requirements.
    diags = tripletList(n) # All possible diagonal entries of HNF matrices with determinant n
    nHNF = sum([iD[2]*iD[3]^2 for iD ∈ diags]) # Number of HNF matrices to generate
    #HNFs = zeros(Int,3,3,nHNF) # Preallocate array to store all HNFs
    HNFs = Vector{Matrix{Int}}(undef, nHNF) 
    iH = 1 # Counter for HNFs
    for iD ∈ diags # Loop over all possible diagonal entries
        for d1 ∈ 0:iD[2]-1 # Loop over row two off-diagonal entries
            for d2 ∈ 0:iD[3]-1 # Loop over row-three, column-1 entries
                for d3 ∈ 0:iD[3]-1 # Loop over row-three, column-2 entries
                    HNFs[iH] = [iD[1] 0 0; d1 iD[2] 0; d2 d3 iD[3]]

                    iH += 1 # Increment HNF counter
                end
            end
        end
    end
    return HNFs
end

""" Generate all integer triplets a*b*c = n """
function tripletList(n)
    # Even for cases n ≈ 100, this takes only a couple of μs. No need for anything fancier.
    triples = Vector{Vector{Int64}}()
    # Loop over all triplets that a*b*c = n
    for i ∈ 1:n
        for j ∈ 1:n
            if i*j > n break end # Just for efficiency
            for k ∈ 1:n
                if i*j*k > n break end # Just for efficiency
                if i*j*k == n
                   push!(triples,[i,j,k])
                end
            end
        end
    end
    return triples
end

"""
    basesAreEquiv(HNF1,HNF2,LG::Vector{Matrix{Int64}})

Check if two bases are equivalent under the action a group 

    Two equivalent superlattices are related by a unimodular transformation. 
    This function checks, for every allowed g ∈ LG, if two bases are 
    equivalent by checking if the transformation matrix is unimodular. 
"""
function basesAreEquiv(HNF1,HNF2,LG::Vector{Matrix{Int64}})
    # This routine assumes det(HNF1) == det(HNF2)
    invB2 = inv(HNF2)
    for g ∈ LG
        T = invB2*g*HNF1
        # The epsilon should be smaller than 1/det(B1) for numerical stability.
        if norm(T - round.(Int,T)) < 1e-6 # Check if T is an integer matrix
            return true
        end 
    end  
    return false
end


""" Get symmetry-inequivalent HNFs under the parent lattice group

getSymInequivHNFs(n,LG) returns the symmetry-inequivalent HNFs, of size n, under the action of the group LG, the symmetries of the parent lattice in lattice coordinates.
"""
function getSymInequivHNFs(d,LG::Vector{Matrix{Int}})
    canonical, _ = _getSymInequivHNFs_with_degens(d, LG)
    return canonical
end

"""
    _getSymInequivHNFs_with_degens(d, LG::Vector{Matrix{Int}})

Return `(canonical_hnfs, class_sizes)` where `class_sizes[i]` is the number of volume-`d` HNFs in the parent-point-group orbit of `canonical_hnfs[i]` — i.e., the size of its symmetry class. Sum of class sizes equals the total number of volume-`d` HNFs from `getAllHNFs(d)`.

The canonical HNFs and their ordering match what `getSymInequivHNFs(d, LG)` returns. Used to populate `Supercell.hnf_degeneracy` (mirroring Fortran enumlib's `hnf_degen`).
"""
function _getSymInequivHNFs_with_degens(d, LG::Vector{Matrix{Int}})
    HNFList = getAllHNFs(d)
    n = length(HNFList)
    # class_id[j] = canonical (smallest) index in HNFList equivalent to j.
    class_id = collect(1:n)
    for i ∈ 1:n-1
        class_id[i] == i || continue       # i already in earlier class — skip
        for j ∈ i+1:n
            class_id[j] == j || continue   # j already classified — skip
            if basesAreEquiv(HNFList[i], HNFList[j], LG)
                class_id[j] = i
            end
        end
    end
    canonical_indices = findall(i -> class_id[i] == i, 1:n)
    canonical = [HNFList[i] for i in canonical_indices]
    class_sizes = [count(==(i), class_id) for i in canonical_indices]
    return canonical, class_sizes
end

"""
    getFixingOps(hnf, LG::Vector{Matrix{Int}})

Return a mask identifying the elements of the symmetry group (expressed in lattice
coordinates) that fix the superlattice defined by the HNF — i.e., the stabilizer
subgroup of `LG`. Pure integer arithmetic in the lattice-coords basis.
"""
function getFixingOps(hnf, LG::Vector{Matrix{Int}})
    mask = falses(length(LG))
    B = hnfc(hnf).H
    for (i,g) ∈ enumerate(LG)
        hnfc(g*B).H == B ? mask[i] = true : nothing
    end
    return mask
end

""" Make the composite cyclic group that represents the translation group of the superlattice
   
    makeTransGroup(z): Given the diagonal entries of the SNF (integer vector, z), compute the automorphisms of the lattice sites that represent the translation group of the superlattice.
"""
function getTransGroup(z)
    # Define "gspace" points, 3D points that represent the lattice sites in the group notation
    GspcSites = [[i,j,k] for i ∈ 0:z[1]-1 for j ∈ 0:z[2]-1 for k ∈ 0:z[3]-1]
    # Compute the automorphism group of the lattice by adding each group element to the entire group (and then modding components by the SNF entries)
    GspcG = [[mod.(j.+i,z) for i ∈ GspcSites] for j ∈ GspcSites] 
    # Convert translations expressed as gspace point orbits to permutation group elements. The 3d gspace points are three digits, mixed-radix numbers. "Hash" them to base 10.
    placeVals = [z[2]*z[3],z[3],1] # Place values for each digit of the mixed-radix number representing group elements
    tGrp =[[sum(i.*placeVals)+1 for i in j] for j in GspcG] # Convert to base-10
    sort!(tGrp) # Put identity first  
    return tGrp
end

""" Convert a list of points in g-space coordinates to ordinal indices in the supercell 

    gCoordsToOrdinals(gPts,SNF): gPts is 3xN mixed-radix numbers, output is N-vector"""
function gCoordsToOrdinals(gPts,SNF)
    placeVals = [SNF[2]*SNF[3],SNF[3],1]
    siteOrdinals = [sum(i.*placeVals)+1 for i in eachcol(gPts)] # Convert to base-10, 1-indexed
    return convert(Vector{Int},siteOrdinals)
end

""" Convert an ordinal index (site # in the supercell) to g-space coordinates 

    ordinalToGCoords(o,z): o is an integer (site #, 1..n), z is an integer 3-vector (SNF), output is 3-vector (g-space coordinates)"""
function ordinalToGcoords(o,z)
    placeVals = [z[2]*z[3],z[3],1]
    gCoords = mod.((o-1) .÷ placeVals,z)
    return gCoords
end

""" getOrdinalsFromCartesian(cPts,A,L,SNF)

cPts is a 3xN vector Cartesian coordinates, A is the parent lattice, L is the left SNF transform, SNF is Smith Normal Form for this cell.
output is N-vector of ordinals"""
# Map Cartesian coordinates to lattice coordinates, map into first tile, then convert to g-space coordinates, then to ordinal indices.
function getOrdinalsFromCartesian(cPts,A,L,SNF)
    T = L*inv(A) # Transformation from lattice to g-space coordinates
    gPts = mod.(round.(Int,T*cPts),SNF)
    return gCoordsToOrdinals(gPts,SNF)
end


""" Genererate all interior points of a unit cell, in Cartesian coordinates

    getCartesianPts(A,H;mink=true): A is the parent lattice, H defines the supercell. Output is a list of all interior points, in Cartesian coordinates. """
function getCartesianPts(A,H;mink=true)
    sdiag=diag(snf(H).S)
    L = snf(H).U # Get the left SNF transform
    n = prod(sdiag)
    # Convert gspace vector to lattice coordinates of supercell, mod into first tile, then convert to Cartesian coordinates (right to left)
    if !mink
        cPts = [A*H*mod.(inv(H)*inv(L)*ordinalToGcoords(i,sdiag),1) for i in 1:n] 
    # If we are going to mink reduce, then H needs to be the "mink reduced" HNF
    else
        H = inv(A)*minkReduce(A*H)
        cPts = [minkReduce(A*H)*mod.(inv(H)*inv(L)*ordinalToGcoords(i,sdiag),1) for i in 1:n]    
    end
    return cPts
end

""" Check that a Cartesian point is a lattice point 

    checkCartesianPts(A,cPts): A is the parent lattice, cPts is a 3 vector. Returns true if the point is a lattice point."""
function checkCartesianPt(A,c)
    Ai = inv(A)
    if norm(Ai*c - round.(Ai*c)) < 1e-10 # eps was chosen to be large enough to pass all unit tests
        return true
    else
        return false
    end 
end
""" get_nonzero_index(m,reps=1e-13) """
function get_nonzero_index(m; reps=1e-13)
    mask = findall(abs.(diag(m)).>reps)
    return mask
end

# `coloringsOfHNFList(hnfs, k, LG)` was deleted in chunk 5. Use the new public
# entry `enumerate(parent, sites; supercells=ExplicitHNFs(hnfs))` instead — it
# returns an Enumeration{D, Vector{Int8}} which carries the same labelings (and
# more: per-structure metadata, supercell back-references).