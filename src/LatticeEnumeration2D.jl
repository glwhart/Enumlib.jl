module LatticeEnumeration2D

using LinearAlgebra
using Plots
using MinkowskiReduction
using SmithNormalForm
using StaticArrays

export genHNFs, isequivbases, gencolorings, getinequivHNFs, plotSuperTile, SuperTile, convertGtoOrd, convertCarttoG, gettransgroup, getrotationgroup, getpermgroup, genallcolorings, reducecolorings, removesuperperiodic

"""
    SuperTile(HNF::Matrix{Int})

Create a SuperTile struct from a Hermite Normal Form.
"""
struct SuperTile
    n::Int
    HNF::SMatrix{2,2,Int}
    SNF::SVector{2,Int}
    L::SMatrix{2,2,Int}
    gPts::Vector{SVector{2,Int}}
    function SuperTile(HNF::Matrix{Int})
        n = abs(det(HNF))
        SNF = smith(HNF).SNF
        L = smith(HNF).Sinv
        gPts = [SA[i,j] for i in 0:SNF[1]-1 for j in 0:SNF[2]-1]
        new(n,HNF,SNF,L,gPts)
    end
end


"""
    genHNFs(n::Int)

Generate all 2D Hermite Normal Forms with determinant n.
"""
function genHNFs(n::Int)
    hnfs = Vector{Matrix{Int}}()
    for a in 1:n
        for c in 1:n
            if a*c == n
                for b in 0:c-1
                    push!(hnfs, [a 0; b c])
                end
                break
            end
        end
    end
    return hnfs
end


"""
    isequivbases(B1, B2, LG)

Check if two bases are equivalent under any rotation in the point group, LG.
"""
function isequivbases(B1, B2, LG)
    if abs(det(B1)) != abs(det(B2))
        return false
    end

    invB2 = inv(B2)
    for g in LG
        T = invB2*g*B1
        if norm(T - round.(Int,T)) < 1e-6
            return true
        end 
    end  
    return false
end


"""
    hasequivbasis(Blist, B1, LG)

Check if a list of basis contains an equivalent basis under the action of a point group, LG.
"""
function hasequivbasis(Blist, B1, LG)
    for b in Blist
        if isequivbases(b,B1,LG)
            return true
        end
    end
    return false
end


"""
    getinequivHNFs(n::Int, LG, Greduce=true)

Return the symmetrically inequivalent superlattice bases, of size n, under the action of a point group, LG.

If Greduced is true, then all bases will be returned in Guass-reduced form.
"""
function getinequivHNFs(n, LG, Greduce=true)
    allHNFs = genHNFs(n)
    out = Vector{Matrix{Int}}()
    for h in allHNFs
        if !hasequivbasis(out,h,LG)
            push!(out, h)
        end
    end

    if Greduce
        for i in eachindex(out)
            U,V = GaussReduce(out[i][:,1],out[i][:,2])
            out[i] = round.(Int, [U V])
        end
    end

    return out
end


"""
    getSuperTiles(HNFlist)

Convert HNF bases into SuperTile structs.
"""
function getSuperTiles(HNFlist::Vector{Matrix{Int}})
    return [SuperTile(h) for h in HNFlist]
end


"""
    shiftGpt(gPt, ST::SuperTile)

Translate a G-space point onto its corresponding site in the SuperTile.
Rounds to nearest site.
"""
function shiftGpt(gPt, ST::SuperTile)
    a,b = ST.SNF
    return mod.(round.(Int,gPt),[a;b])
end


"""
    convertGtoOrd(gPt, ST::SuperTile)

Convert a G-space point into its ordinal index in a SuperTile.
"""
function convertGtoOrd(gPt, ST::SuperTile)
    return 1 + dot(shiftGpt(gPt,ST), [ST.SNF[2],1])
end

"""
    convertCarttoG(gPt, ST::SuperTile, pLat)

Convert a cartesian lattice point into its corresponding G-space point.
"""
function convertCarttoG(cPt, ST::SuperTile, pLat)
    a,b = ST.SNF
    return mod.(round.(Int, ST.L*inv(pLat)*cPt),[a;b])
end

"""
    convertGtoOrd(gPt,ST::SuperTile)

Convert a cartesian lattice point into its ordinal index in a SuperTile.
"""
function convertCarttoOrd(cPt, ST::SuperTile, pLat)
    return convertGtoOrd(convertCarttoG(cPt, ST, pLat), ST)
end

"""
    gettransgroup(ST::SuperTile)

Compute the automorphic translations of a SuperTile.
"""
function gettransgroup(ST::SuperTile)
    return sort([[convertGtoOrd(g+h,ST) for h in ST.gPts] for g in ST.gPts])
end


"""
    getfixedgroup(ST::SuperTile,LG)

Return a mask of the for the operations in LG which are symmetrically invariant on a basis.
"""
function getfixedgroup(ST::SuperTile,LG)
    mask = falses(length(LG))
    B = ST.HNF
    invB = inv(B)
    for i in eachindex(LG)
        T = invB*LG[i]*B
        mask[i] = norm(T - round.(Int, T)) < 1e-8
    end
    return mask
end


"""
    getrotationgroup(ST::SuperTile,LG)

Get the invariant rotations of a supertile. 
"""
function getrotationgroup(ST::SuperTile,LG)
    fixedG = getfixedgroup(ST,LG)
    L = ST.L
    Linv = inv(L)
    RG = unique([[convertGtoOrd(L*g*Linv*c,ST) for c in ST.gPts] for g in LG[fixedG]])
    return RG
end


"""
    getpermgroup(ST::SuperTile,LG)

Generate the permutation group of a SuperTile with point group, LG.
"""
function getpermgroup(ST::SuperTile,LG)
    RG = getrotationgroup(ST,LG)
    TG = gettransgroup(ST)
    return [r[t] for r in RG for t in TG]
end


"""
    genallcolorings(n, elements)

Generate all colorings of length n with k elements. 
"""
function genallcolorings(n, k)
    elements = 1:k

    perms = []
    function perm_helper(curr)
        if length(curr) == n
            push!(perms, copy(curr))
            return
        end

        for e in elements
            push!(curr, e)
            perm_helper(curr)
            pop!(curr)
        end
    end

    perm_helper([])
    return perms
end


"""
    removesuperperiodic(colorings, ST:SuperTile)

Removes the superperiodic colorings in a list of the colorings of a SuperTile.
"""
function removesuperperiodic(colorings, ST::SuperTile)
    TG = gettransgroup(ST)
    mask = trues(length(colorings))
    for (i, c) in pairs(colorings)
        for t in TG[2:end]
            if c[t] == c
                mask[i] = false
                break
            end
        end
    end

    return colorings[mask]
end


"""
    reducecolorings(colorings, ST::SuperTile, LG)

Removes from a list the symmetrically equivalent and superperiodic colorings of a SuperTile. 
"""
function reducecolorings(colorings, ST::SuperTile, LG)
    colorings = removesuperperiodic(colorings, ST)
    PG = getpermgroup(ST, LG)
    mask = falses(length(colorings))
    checked = []
    for (i, c) in pairs(colorings)
        if !(c in checked)
            mask[i] = true
            for g in PG
                push!(checked, c[g])
            end
        end
    end
    return colorings[mask]
end


"""
    genlatticepoints(pLat, size_x, size_y)

Generates the points of a lattice within a box of given size
"""
function genlatticepoints(pLat, box_size) 
    a = pLat[:,1]
    b = pLat[:,2]

    max_i = maximum(inv(pLat)*[box_size,0])+1
    max_j = maximum(inv(pLat)*[0,box_size])+1

    points = []
    for i in -max_i:max_i
        for j in -max_j:max_j
            point = i * a + j * b
            if point[1] >= 0 && point[1] <= box_size && point[2] >= 0 && point[2] <= box_size
                push!(points, point)
            end
        end
    end
    return points
end


"""
    plotcoloring(coloring, ST::SuperTile, pLat, size=16, ms=12, colorscheme=[:salmon, :skyblue, :forestgreen, :orchid, :gold3, :royalblue4])

Creates a plot of a given coloring of a SuperTile of a lattice.
"""
function plotcoloring(coloring, ST::SuperTile, pLat, size=16, ms=12, colorscheme=[:salmon, :skyblue, :forestgreen, :orchid, :gold3, :royalblue4])
    recolor = [colorscheme[c] for c in coloring]

    cPts = genlatticepoints(pLat, size)

    colors = [recolor[convertCarttoOrd(p, ST, pLat)] for p in cPts]

    plt = scatter([p[1] for p in cPts],[p[2] for p in cPts], color=colors,
            xlims=(-.5,size+.5), ylims=(-.5,size+.5), bg=:black, markerstrokewidth=0,
            axis=false, legend=false, size=(size*25,size*25), ms=ms, grid=false)
    return plt
end


"""
    gencolorings(n, k, LG)

Returns a dictionary of SuperTiles with point group LG up to size n and its symmetrically inequivalent colorings.
"""
function gencolorings(n, k, LG)
    STcolors = Dict{SuperTile,Array{Array{Int}}}()
    for subn in 1:n
        STs = getSuperTiles(getinequivHNFs(subn, LG))
        allcolorings = genallcolorings(subn, k)
    
        for ST in STs
            STcolors[ST] = reducecolorings(allcolorings, ST, LG)
        end
    end
    return STcolors
end


"""
    multiplotcolorings(STcolors, pLat)

Plots dictionary of SuperTiles and coloring on a given lattice. 
"""
function multiplotcolorings(STcolors, pLat) 
    plts = vcat([[plotcoloring(i, st, pLat, 16, 11) for i in STcolors[st]] for st in sort(collect(keys(STcolors)), lt=lessthanST)]...)
    N2 = ceil(√length(plts)) * 420
    return plot(plts..., size=(N2,N2), margins=-1*Plots.mm)
end


"""
   lessthanST(ST1::SuperTile, ST2::SuperTile) 
   
Checks if the first SuperTile is smaller than the second SuperTile.
"""
function lessthanST(ST1::SuperTile, ST2::SuperTile) 
    if abs(ST1.n) < abs(ST2.n)
        return true
    elseif abs(ST1.n) == abs(ST2.n)
        d1 = abs(norm(ST1.HNF[:,1]) - norm(ST1.HNF[:,2]))
        d2 = abs(norm(ST2.HNF[:,1]) - norm(ST2.HNF[:,2]))
        if d1 > d2
            return true
        elseif d1 == d2
            print("DoTT")
            return abs(dot(ST1.HNF[:,1], ST1.HNF[:,2])) > abs(dot(ST2.HNF[:,1], ST2.HNF[:,2]))
        end
    end
    return false
end


"""
    concentrationplot(STcolors, pLat, k)

Plots colorings of a SuperTiles in order based on concentration of elements.
"""
function concentrationplot(STcolors, pLat, k)
    colors = vcat([[(st,c) for c in STcolors[st]] for st in sort(collect(keys(STcolors)), lt=lessthanST)]...)
    conc = [concentrations(c[2], k) for c in colors]
    order = sortperm(conc, rev=true)
    plts = [plotcoloring(i[2], i[1], pLat, 16, 11) for i in colors[order]]
    N2 = ceil(√length(plts)) * 420
    return plot(plts..., size=(N2,N2), margins=-1*Plots.mm)
end


"""
    concentrations(c, k)
Returns the concentrations of k colors in a coloring.
"""
function concentrations(c, k)
    [count(==(i), c) for i in 1:k] / length(c)
end


"""
    radialgenHNFs(r)

Gets all HNFs that fit within radius r.
"""
function radialgenHNFs(r)
    n = floor(Int, 2*(r)^2)
    hnfs = vcat([genHNFs(i) for i in 1:n]...)
    mask = trues(length(hnfs))
    for (i, h) in pairs(hnfs)
        u = h[:,1]
        v = h[:,2]
        s = maximum(norm, [u+v, u-v])
        if s > 2*r
            mask[i] = false
        end
    end
    return hnfs[mask]
end

"""
    radialinequivHNFs(r, LG, Greduce=true)

Gets inequivalent HNFs that fit within a radius r.
"""
function radialinequivHNFs(r, LG, Greduce=true)
    allHNFs = radialgenHNFs(r)
    out = Vector{Matrix{Int}}()
    for h in allHNFs
        if !hasequivbasis(out,h,LG)
            push!(out, h)
        end
    end

    if Greduce
        for i in eachindex(out)
            U,V = GaussReduce(out[i][:,1],out[i][:,2])
            out[i] = round.(Int, [U V])
        end
    end

    return out
end

"""
    radialgencolorings(r, k, LG)

Gets the colorings of SuperTiles whhich fit within a radius r with k elements.
"""
function radialgencolorings(r, k, LG)
    STcolors = Dict{SuperTile,Array{Array{Int}}}()
    STs = getSuperTiles(radialinequivHNFs(r, LG))

    for ST in STs
        allcolorings = genallcolorings(ST.n, k)
        STcolors[ST] = reducecolorings(allcolorings, ST, LG)
    end
    return STcolors
end


"""
    plotSuperTile(ST::SuperTile, pLat)

Draws the outline of a SuperTile.
"""
function plotSuperTile(ST::SuperTile, pLat)
    h = pLat*ST.HNF
    return plot([0, h[1], h[1]+h[2] , h[2], 0],[0, h[3], h[3]+h[4], h[4], 0],
        legend=false, color=:red, width=5, aspect_ratio=:equal)
end

end # module LatticeEnumeration2D