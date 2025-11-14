using Revise
using clusterExpansion
using Spacey
using LinearAlgebra
using MinkowskiReduction
using Plots

BravaisLatticeList=Dict([
("Centered monoclinic 1",     ([1.0  1.0 0.5; 1.1 -1.1 0.0; 0.0 0.0 0.7],4)),
("Simple monoclinic 1",      ( [1.0  0.0 0.1; 0.0  1.1 0.0; 0.0 0.0 0.7],4)),
("Base-centered orthorhombic 1",([1.0  0.0 0.5; 0.0  1.1 0.0; 0.0 0.0 0.7] ,8)),
("Triclinic 1",([1.0  0.1 0.2; 0.2  1.1 0.0; 0.3 0.0 0.7] ,2)),
("FCC unreduced 1",([0.0 0.5 1.0; 0.5 0.0 1.0; 0.5 0.5 1.0],48)),
("Rhombohedral 1",([1.0  1.0 .5; 1.0  .5 1.0; .5 1.0 1.0],12)),
("hexagonal 1",([1.0 0.5 0.0; 0.0  √(.75) 0.0; 0.0 0.0 1.6],24)),
("Base-Centered orthorhombic 2",([1.1 1.9 0.0; -1.1 1.9 0.0; 0.0 0.0 1.3],8)),
("Body-centered orthorhombic 1",([1.1 0.0 0.55; 0.0 1.9 0.95; 0.0 0.0 0.7],8)),
("Face-centered orthorhombic 1",([0.55 0.0 0.55; 0.95 0.95 0.0; 0.0 0.35 0.35],8)),
("BCTet",([0.0 0.5 0.5; 0.5 0.0 0.5; 0.54 0.54 0.0],16)),
("FCC",([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],48)),
("BCC",([-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0],48)),
("Simple cubic",([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],48)),
("Simple orthorhombic",([1.1 0.0 0.0; 0.0 1.2 0.0; 0.0 0.0 1.3],8)),
("Simple tetragonal",([1.1 0.0 0.0; 0.0 1.1 0.0; 0.0 0.0 1.3],16))
])


function radiusEnumeration(A;maxVol=15)
    LG,G=pointGroup(A)
    hnfs = Vector{Matrix{Int64}}()
    for i ∈ 1:maxVol
        append!(hnfs, getAllHNFs(i))
        #append!(hnfs, getSymInequivHNFs(i,LG))
    end
    hnfs = [round.(Int,inv(A)*minkReduce(A*h)) for h in hnfs]
    radii = [cellRadius(A*h) for h in hnfs]
    volumes = [abs.(round(Int,det(h))) for h in hnfs]
    idx = sortperm(radii)
    return hnfs[idx], radii[idx], volumes[idx]
end
 

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

A = BravaisLatticeList["FCC"][1]
LG,G=pointGroup(A)

@time hnfs, radii, volumes = getSymInequivHNFsByCellRadius(BravaisLatticeList["FCC"][1],1.8)
volumes
# What I need to do is enumerate now that I have all the HNFs.

#hnfs=vcat([getSymInequivHNFs(i,LG) for i ∈ 1:4]...)
colorings = coloringsOfHNFList(hnfs,2,LG)
vcat(colorings...)
plot(volumes,xlabel="HNF index (sorted by volume)",ylabel="Volume/Number of colorings",title="Number of colorings vs volume",msw=0,ms=2,yscale=:log10)
scatter!(length.(colorings),msw=0,ms=2,color=:red,yscale=:log10)
scatter(volumes,radii,msw=0,ms=4,xlabel="Volume",ylabel="Radius",title="Radius vs Volume",legend=false,color=:green)
hColorings = length.(colorings)

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

