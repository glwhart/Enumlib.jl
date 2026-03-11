#module LatticeColoringEnumeration
#using LinearAlgebra
#export getAllHNFs, tripletList, basesAreEquiv, equivHNFs
# Might be convenient to have fixing ops and/or group in one of these structs
export checkCartesianPt, getFixingLatticeOps

""" Define a type for a supercell of a parent lattice, its HNF, SNF, gpoints, etc. 

(not yet used)
"""
struct SuperTile # A supercell of a parent lattice and some of its group properties
    n::Int64 # size of tile; number of parent lattice tiles in supertile
    HNF::Matrix{Int64} # HNF of the supercell
    L::Array{Int64,2} # Left transformation for SNF, maps lattice coordinates to gspace coordinates
    SNF::Vector{Int64} # Smith normal form of the supercell
    gPts::Array{Int64,2} # columns are supercell sites in group coordinates
    function SuperTile(n,HNF)
        L = snf(HNF).U # inverse because 'smith' package defines the transformation differently than enumlib
        SNF = daig((HNF).S)
        gPts = hcat([[i,j,k] for i ∈ 0:SNF[1]-1 for j ∈ 0:SNF[2]-1 for k ∈ 0:SNF[3]-1]...)
        new(n,HNF,L,SNF,gPts)
    end
end

""" Supertile + colorings, an enumeration restricted to one tile (not yet used) """
struct ColoredTile
    t::SuperTile # The supercell
    c::Vector{Vector{Int64}} # The list of colorings for this tile
end

""" Define a parent lattice, its symmetries, etc. """
struct ParentLattice
    A::Matrix{Float64} # The parent lattice
    Ainv::Matrix{Float64} # The inverse of the parent lattice
    G::Array{Int64,2} # The group of the parent lattice in lattice coordinates

    function ParentLattice(A)
        Ainv = inv(A)
        G = pointGroup(A)[1]
        new(A,Ainv,G)
    end
end

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

""" Check if two bases are equivalent under the action a group 

    Two equivalent superlattices are related by a unimodular transformation. 
    This function checks, for every allowed g ∈ G, if two bases are 
    equivalent by checking if the transformation matrix is unimodular. 

        *** Finite precision issues could be avoided by doing this all in integers using HNFer ***
"""
function basesAreEquiv(HNF1,HNF2,pLat,G::Vector{Matrix{Float64}})
    # This routine assumes det(HNF1) == det(HNF2)
    invB2 = inv(pLat*HNF2)
    for g ∈ G
        T = invB2*g*(pLat*HNF1)
        # The epsilon should be smaller than 1/det(B1) for numerical stability.
        if norm(T - round.(Int,T)) < 1e-6 # Check if T is an integer matrix
            return true
        end 
    end  
    return false
end

""" Check if two bases are equivalent under the action a group 

    Two equivalent superlattices are related by a unimodular transformation. 
    This function checks, for every allowed g ∈ LG, if two bases are 
    equivalent by checking if the transformation matrix is unimodular. 
"""
function basesAreEquiv(HNF1,HNF2,LG::Vector{Matrix{Int}})
    # This routine assumes det(HNF1) == det(HNF2)
    invB2 = inv(HNF2)
    for g ∈ LG
        T = invB2*g*HNF1
        if norm(T - round.(Int,T)) < 1e-6 # Check if T is an integer matrix
            return true
        end 
    end  
    return false
end


""" Get symmetry-inequivalent HNFs under the parent lattice group 

getSymInequivHNFs(n,pLat,G) returns the symmetry-inequivalent HNFs, of size d, under the action of the group G, the symmetries of the parent lattice.
"""
function getSymInequivHNFs(d,pLat,G::Vector{Matrix{Float64}})
HNFList = getAllHNFs(d)
n = length(HNFList)
mask = trues(n)
    for i ∈ 1:n-1
        if !mask[i] continue end
        for j ∈ i+1:n
            if !mask[j] continue end
            if basesAreEquiv(HNFList[i],HNFList[j],pLat,G)
                mask[j] = false
            end
        end
    end
    return [HNFList[i] for i ∈ findall(mask.==1)] # Return only the symmetry-inequivalent HNFs
end

""" Get symmetry-inequivalent HNFs under the parent lattice group 

getSymInequivHNFs(n,LG) returns the symmetry-inequivalent HNFs, of size n, under the action of the group LG, the symmetries of the parent lattice in lattice coordinates.
"""
function getSymInequivHNFs(d,LG::Vector{Matrix{Int}})
    HNFList = getAllHNFs(d)
    n = length(HNFList)
    mask = trues(n)
    for i ∈ 1:n-1
        for j ∈ i+1:n
            if !mask[j] continue end
            if basesAreEquiv(HNFList[i],HNFList[j],LG)
                mask[j] = false
            end
        end
    end
    return [HNFList[i] for i ∈ findall(mask.==1)] # Return only the symmetry-inequivalent HNFs
end

""" getFixingOps(hnf,pLat,G::Vector{Matrix{Float64}})

Return a mask marking the symmetries in G that fix the superlattice of given HNF

    getFixingOps(hnf,pLat,G): Given an HNF, a parent lattice, and the symmetries of the parent lattice, return a mask of the symmetries under which the superlattice is invariant. In other words, it returns the stabilizer subgroup of G.
"""
function getFixingOps(hnf,pLat,G::Vector{Matrix{Float64}})
    mask = falses(length(G))
    B = pLat*hnf
    for (i,g) ∈ enumerate(G)
        T = inv(B)*g*B 
        # For n≤24, an epsilon of 1e-2 would have been small enough
        norm(T - round.(Int,T)) < 1e-8 ? mask[i] = true : nothing 
    end
    return mask
end  

"""
    getFixingLatticeOps(hnf,LG)

    Return a mask identifying the elements of the symmetry group (expressed in lattice coordinates) that fix the superlattice defined by the HNF. (Compare to getFixingOps, which uses Cartesian coords.)
"""    
function getFixingLatticeOps(hnf,LG)
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

function coloringsOfHNFList(hnfs,k,LG::Vector{Matrix{Int}})
   colorings = Vector{Vector{Vector{Int64}}}()
   for iH ∈ eachindex(hnfs) # few milliseconds
        fixingOps = getFixingLatticeOps(hnfs[iH],LG)
        permG = getPermG(hnfs[iH],fixingOps,LG)
        push!(colorings,getUniqueColorings(k,permG))
    end
    return colorings
end