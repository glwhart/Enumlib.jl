using Revise
using clusterExpansion
using Spacey
using LinearAlgebra
using MinkowskiReduction
using Plots

# This list has  already been mink reduced.
BravaisLatticeList=Dict([
    "Simple monoclinic 1"          => ([0.1 1.0 0.0; 0.0 0.0 1.1; 0.7 0.0 0.0], 4)
    "Body-centered orthorhombic 1" => ([1.1 0.55 0.55; 0.0 0.95 0.95; 0.0 0.7 -0.7], 8)
    "Simple orthorhombic"          => ([1.1 0.0 0.0; 0.0 1.2 0.0; 0.0 0.0 1.3], 8)
    "Base-Centered orthorhombic 2" => ([0.0 1.1 1.9; 0.0 -1.1 1.9; 1.3 0.0 0.0], 8)
    "Face-centered orthorhombic 1" => ([0.55 0.55 0.0; 0.0 0.0 0.95; 0.35 -0.35 -0.35], 8)
    "Triclinic 1"                  => ([0.2 0.8 0.1; 0.0 0.2 1.1; 0.7 -0.4 0.0], 2)
    "FCC"                          => ([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0], 48)
    "hexagonal 1"                  => ([0.5 0.5 0.0; sqrt(3)/2 -sqrt(3)/2 0.0; 0.0 0.0 1.6], 24)
    "BCTet"                        => ([0.5 0.5 0.5; 0.5 -0.5 0.0; 0.0 0.0 0.54], 16)
    "Rhombohedral 1"               => ([0.0 -0.5 0.5; -0.5 0.0 1.0; 0.5 0.5 1.0], 12)
    "Centered monoclinic 1"        => ([0.5 0.5 0.5; 0.0 1.1 -1.1; 0.7 -0.7 -0.7], 4)
    "Base-centered orthorhombic 1" => ([0.5 0.5 0.0; 0.0 0.0 1.1; 0.7 -0.7 0.0], 8)
    "Simple tetragonal"            => ([1.1 0.0 0.0; 0.0 1.1 0.0; 0.0 0.0 1.3], 16)
    #"FCC unreduced 1"              => ([0.0 0.5 1.0; 0.5 0.0 1.0; 0.5 0.5 1.0], 48)
    "Simple cubic"                 => ([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0], 48)
    "BCC"                          => ([-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0], 48)
])


lat = BravaisLatticeList["FCC"][1]
LG,_=pointGroup(lat)
@time pairs=getPairClustersInSphere(lat,LG,9);
cartPairs = [lat*p for p in pairs]
radii = norm.(cartPairs)



""" radiusEnumeration(A;maxVol=15)

Enumerate all symmetry-inequivalent superlattices up to volume maxVol, and return a radius-sorted list of the HNFs, radii, and volumes.
"""
function radiusEnumHNFs(A;maxVol=15)
    LG,_=pointGroup(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:maxVol
        #append!(hnfs, getAllHNFs(i))
        append!(hnfs, getSymInequivHNFs(i,LG))
    end
    hnfs = [round.(Int,inv(A)*minkReduce(A*h)) for h in hnfs]
    radii = [cellRadius(A*h) for h in hnfs]
    volumes = [abs.(round(Int,det(h))) for h in hnfs]
    idx = sortperm(radii)
    return hnfs[idx], radii[idx], volumes[idx]
end
 
res=[radiusEnumHNFs(BravaisLatticeList[i][1];maxVol=14) for i ∈ keys(BravaisLatticeList)]
@show length.([i[1] for i in res])
# The number of enumerated HNFs depends on the lattice type (because of symmetry)
# Check out how the number correlates with maxVol and pointgroupsize
pgs = [length(pointGroup(BravaisLatticeList[i][1])[1]) for i ∈ keys(BravaisLatticeList)]


@show [(i,isMinkReduced(BravaisLatticeList[i][1])) for i ∈ keys(BravaisLatticeList)]

[(i,minkReduce(BravaisLatticeList[i][1])) for i ∈ keys(BravaisLatticeList)]
# Plot all 16 series of radii (distances)




lattice_names = collect(keys(BravaisLatticeList))
p = plot(xlabel="HNF Index", ylabel="Radius (Distance)", title="Radius vs Index for All 16 Lattice Types (up to size 20)", legend=:bottomright, size=(1000, 600),msw=0,ms=2,yscale=:log10)
vol = [abs(det(BravaisLatticeList[i][1])) for i in keys(BravaisLatticeList) ]

for (idx, name) in enumerate(lattice_names)
    radii = res[idx][2] 
    v = abs(det(BravaisLatticeList[name][1])) # Get the matrix (first element of tuple) and compute its determinant
    plot!(p, 1:length(radii), radii/v, label=name, linewidth=1.5, markersize=2, msw=0, marker=:circle, alpha=0.7)
end

display(p)
plot!(p, yscale=:log10)
savefig(p, "figures/radiusEnumerationAllLattices.png")

""" getHNFColorings(h,k,LG)

For a given HNF, enumerate all the colorings, 
"""
function getHNFColorings(h,k,LG::Vector{Matrix{Int64}}) 
    fixingOps = getFixingLatticeOps(h,LG)
    permG = getPermG(h,fixingOps,LG)
    return getUniqueColorings(k,permG)
end

tLG, _ = pointGroup(BravaisLatticeList["Centered monoclinic 1"][1])
res[1]
[getHNFColorings(i,2,LG) for i in res[1][1]]

[minkReduce(BravaisLatticeList[i][1]) for i ∈ keys(BravaisLatticeList)]


radiusEnumeration(minkReduce(BravaisLatticeList["Simple cubic"][1]))[3]|>length


function radEnumByXcellRadius(A,x)
    rCell = cellRadius(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:80
        append!(hnfs, getAllHNFs(i))
        #append!(hnfs, getSymInequivHNFs(i,LG))
    end
    hnfs = [round.(Int,inv(A)*minkReduce(A*h)) for h in hnfs]
    radii = [cellRadius(A*h) for h in hnfs]
    rhnfs = Vector{Matrix{Int64}}()
    for r in radii
        if r ≤ x*rCell
            push!(rhnfs, hnfs[findall(radii.==r)])
        end
    end
    return rhnfs
end

# Enumerate a BUNCH of HNFs so that there is no chance of missing any. Eliminate any that are bigger than x*rCell. Take the ones that remain and remove those that are symmetrically equivalent.
function getSymInequivHNFsByCellRadius(A,x;maxVol=20)
    rCell = cellRadius(A)
    LG,_=pointGroup(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:maxVol
        append!(hnfs, getAllHNFs(i))
    end
    hnfs = [round.(Int,inv(A)*minkReduce(A*h)) for h in hnfs]
  #  println("First hnf: ", hnfs[1])
    radii = [cellRadius(A*h) for h in hnfs]
  #  println("First radii: ", round.(radii,digits=10)[1:min(10,length(radii))])
    radii = round.(radii,digits=10) # Don't distinguish between radii that are different only because of floating point precision.
    volumes = abs.(round.(Int,det.(hnfs)))
    idx = findall(radii.≤x*rCell)
    # Drop cells that are too big
    radii = radii[idx]
    hnfs = hnfs[idx]
    volumes = volumes[idx]
    mask = trues(length(hnfs))
 #   println("First volumes: ", volumes[1:min(10,length(volumes))])
    for i ∈ eachindex(hnfs)
        if !mask[i] continue end
   #     println(i,", ", mask[i])
        for j ∈ i+1:length(hnfs)
            if !mask[j] continue end
            if volumes[i] < volumes[j] break end
            #println("Checking if ", i, " and ", j, " are rot-trans equiv")
            # Don't use isRotTransEquiv because in assumes G, not LG. Can we replace one of these?
            if basesAreEquiv(hnfs[i],hnfs[j],LG)
             #   println("Removing ", j)
                mask[j] = false
            end
        end
    end
#    println("Mask: ", mask[1:min(10,length(mask))])
    return hnfs[mask], radii[mask], abs.(round.(Int,det.(hnfs[mask])))
end

rcut = 2.0
A = BravaisLatticeList["BCC"][1]
LG,G=pointGroup(A)

@time hnfs, radii, volumes = getSymInequivHNFsByCellRadius(A,rcut)
println("Number of HNFs: ", length(hnfs))
scatter(unique(sort(radii)),ylabel="Radius",msw=0,ms=2,legend=false,yticks=0:.1:rcut+.1,ylims=(0,rcut+.1))

# Bulletproof this function
m, dia, vo =getRenumDesignMatrix(BravaisLatticeList["Simple cubic"][1],1.5,2)

# What I need to do is enumerate now that I have all the HNFs.



#hnfs=vcat([getSymInequivHNFs(i,LG) for i ∈ 1:4]...)
colorings = coloringsOfHNFList(hnfs,3,LG)
println("Number of colorings: ", length(vcat(colorings...)))
plot(volumes,xlabel="HNF index (sorted by volume)",ylabel="Volume/Number of colorings",title="Number of colorings vs volume",msw=0,ms=2,yscale=:log10)
scatter!(length.(colorings),msw=0,ms=2,color=:red,yscale=:log10)
scatter(volumes,radii,msw=0,ms=4,xlabel="Volume",ylabel="Radius",title="Radius vs Volume",legend=false,color=:green)
hColorings = length.(colorings)


# Generate the poscars for David
dirpath = "data"
using NormalForms
genPOSCARs(dirpath, hnfs, colorings, ["a", "b", "c"])


using CairoMakie
fig = Figure(resolution=(900, 700))
ax = Axis3(fig[1, 1], xlabel="Volume", ylabel="Radius", zlabel="hColorings", azimuth=pi / 6, elevation=pi / 6)

CairoMakie.barplot!(ax, volumes, radii, hColorings; direction=:z, color=hColorings, colormap=colormap)



coloringsOfHNFList([hnfs[11]],2,LG)


radEnumByXcellRadius(BravaisLatticeList["FCC"][1],2.6)
unique(ans)
@time hnfs, radii, volumes = radiusEnumeration(BravaisLatticeList["FCC"][1];maxVol=48);
println("Number of HNFs: ", length(hnfs))
scatter(volumes,radii,xlabel="Volume",ylabel="Radius",title="Radius vs Volume",msw=0,ms=2)
scatter(radii,msw=0,ms=2,color=:red)
uqr = unique(radii)
plot!([count(radii.≤uq) for uq in uqr],xlabel="Radius index",ylabel="Number of HNFs",title="Number of HNFs vs Radius",msw=0,ms=2,yscale=:log10,xscale=:log10)

tConfigs = 0
for r ∈ uqr
    #println(r,", ", count(radii.≤r))
    idx = findall(radii.≤r)
    sC = sum(length.(colorings[idx]))
    tConfigs += sC
    println("# of configs: ", tConfigs)
end

function estimatedTime(h) # add kpoint folding factor later (needs group of parent)
    s = abs(det(h))
    t = s^2*log(s)
    return t
end
estimatedTime.(hnfs)




# Estimate the time to calculate the colorings in the generated list.



colorings = Vector{Vector{Vector{Int64}}}()
for iH ∈ eachindex(hnfs) # few milliseconds
ops =getFixingLatticeOps(hnfs[iH],LG)
permG = getPermG(hnfs[iH],ops,A,G)
#permG = getPermG(hnfs[iH],ops,LG)
println(permG)
push!(colorings,getUniqueColorings(2,permG))
end
vcat(colorings...)

