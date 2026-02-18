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


A = BravaisLatticeList["FCC"][1]
primR = cellRadius(A) # Get some scale for the lattice so we can pick a pair cutoff
LG,_=pointGroup(A) # Need the pointgroup for the pair enumeration
# need to limit the number and size of HNFs by doing an enumeration and then cutting of a the radius, and then the size when the break between radii jumps too suddenly.
nmax = 16
println("Calculating HNFs up to size ",nmax)
begin
hnfs = Vector{Matrix{Int64}}()
hnfLengths = Vector{Int64}()
for i ∈ 1:nmax
    hnfList = getSymInequivHNFs(i,LG)
    r = sortperm(cellRadius.(hnfList))
        append!(hnfs, hnfList[r])
        append!(hnfLengths,length(hnfList))
end
end
println("hnfs lengths: ",hnfLengths)
# Mink reduce the unit cells
hnfs=[round.(Int,inv(A)*minkReduce(A*h)) for h ∈ hnfs]
radii = [cellRadius(A*h) for h in hnfs]
szColors =[fill([:red,:blue,:green,:orange,:purple,:tan,:pink,:black,:red,:blue,:green,:orange,:purple,:tan,:pink,:black][i],hnfLengths[i]) for i in eachindex(hnfLengths)]
szColors=vcat(szColors...)
plot(radii,legend=:none,ylabel="radius",st=:scatter,color=szColors,ylim=(0.7,1.5))
println("cell radii: ",[cellRadius(A*h) for h in hnfs])
uqr=unique(sort(radii))
plot(uqr[2:end]-uqr[1:end-1],yscale=:log10)
# sort the hnfs by radius. Then enumerate colorings for each HNF in turn. Quit if we are over budget. Each coloring costs ln(Natoms)*Natoms^2/size(PG). But we only check the budget at the end of each HNF.

# in this scheme we are ordering the HNFs first by radius, then by volume. Imagine concentric ellipses with a very large horizontal aspect ratio. We slowly increase the radius of the ellipses, including the next ellipses that come in. If we slightly decrease the aspect ratio, we will pick up smaller volume, larger radius cells before some large volume small radius cells. Picking that aspect ratio is a hyperparameter, I guess.
spHNF = sortperm([cellRadius(A*h) for h in hnfs])
plot(radii[spHNF],color=szColors[spHNF],st=:scatter,ylim=(0.7,1.5))

# Ellipses centered at origin, same eccentricity e (drawn first so scatter points appear on top)
# For (x/a)² + (y/b)² = 1 with a ≥ b: e = √(1 - (b/a)²)  =>  b = a√(1 - e²)
θ = range(0, 2π; length=100)
e = .999   # eccentricity (0 = circle, 1 = degenerate)
# .9 does almost straight volume
# .99 weights volume and radius about the same
# .999 Decides almost solely on radius

## But you could also just do straight lines with different slopes. Basically just an l1 ball with different aspect ratios.
## that would simplify things and no reason to think it wouldn't be better, or at least as good.


p = plot(xlabel="Volume", ylabel="Radius", legend=false)
for a in range(1, 40, step=0.5)   # semi-major axis (volume direction)
    b = a * sqrt(1 - e^2)               # semi-minor axis (radius direction)
    plot!(p, a*cos.(θ), b*sin.(θ); linewidth=1, color=:gray)
end
scatter!(p, abs.(det.(hnfs[spHNF])), radii[spHNF], color=szColors[spHNF],xlims=(0,16),ylims=(0.0,1.5))

cond(m2[:,1:end-2])

m2qr = qr(m2,ColumnNorm())
qrCol = fill(:cyan,length(diam2))
qrCol[m2qr.p[1:405]] .= :blue
plot(diam2,st=:scatter,msw=0,ms=1,color=qrCol)
# Wow, the qr didn't take the big ones, it just took a fairly uniform sampling. Not sure these are worse from a physical intuition perspective


# eliminate hnfs bigger than Rmax
hnfs = hnfs[findall([cellRadius(A*h) < Rmax for h in hnfs])]
println("Number of hnfs: ",length(hnfs))
println("Volume of selected hnfs: ",[round(Int,abs(det(h))) for h in hnfs])
# Get the interior points for each HNF, accumulate them in a list
# Tried using just the shortest cell vector from each HNF for sizes N=8,9,10 and it all worked. Condition numbers were good too.

# In this call, the second argument has been made irrelevant. I need to change the buildClusters function to not require that argument. It's not really needed---it can be determined from the hnf list.
clusterPool,diameters,vertOrders = buildClusters_orig(A,1,hnfs,LG,cellVecVerts)

println("Unique clusters: ",length(clusterPool))
colorings = Vector{Vector{Vector{Int64}}}()
for iH ∈ axes(hnfs,1) # few milliseconds
    fixingOps = getFixingOps(hnfs[iH],A,G)
    permG = getPermG(hnfs[iH],fixingOps,A,G)
    push!(colorings,getUniqueColorings(k,permG))
end
println("colorings: ", sum(length.(colorings)))



@time pairs=getPairClustersInSphere(lat,LG,3); # ~30 secs for fcc and Rmax=9
cartPairs = [lat*p for p in pairs] # Convert the pairs to Cartesian coordinates
radii = norm.(cartPairs)
plot(radii,msw=0,ms=2,legend=false,color=:red)
[count(vertOrd3[li3].==i) for i in 0:8]'


m, diam, vertOrd = getRenumDesignMatrix(lat,1.3,2,1);
rank(m)
mred, li = leftmostIndependentColumns(m,100)
col = fill(:blue,size(m,2))
col[li] .= :red
sz =repeat([2],length(diam))
sz[li] .= 3
scatter(diam,msw=0,color=col,ms=sz,legend=:none,
dpi=300,
xlabel="Cluster index",ylabel="Radius",title="Binary fcc, rcut=1.5, cellVecVerts=1 (red lin. ind.)")
# cellVecVerts = 1 gave rank = 391
savefig("figures/fccBinaryRadiusEnumerationAug1.png")
cond(mred)

m2, diam2, vertOrd2 = getRenumDesignMatrix(lat,1.31,2,2);
rank(m2)
mred2, li2 = leftmostIndependentColumns(m2,100)
cond(m2)
col2 = fill(:blue,size(m2,2))
col2[li2] .= :red
scatter(diam2,msw=0,color=col2,ms=2,legend=:none,
dpi=300,
xlabel="Cluster index",ylabel="Radius",title="Binary fcc, rcut=1.5, Aug=2 (red lin. ind.)")
# cellVecVerts = 2 gave rank = 391 (same as 1)
savefig("figures/fccBinaryRadiusEnumerationAug2.png")


coldiff=[[:red,:red,:blue,:green,:orange,:purple,:tan,:pink,:black][vertOrd[li][i]+1] for i in 1:391]

plot(diam[li]- diam2[li2],st=:scatter,msw=0,ms=2,color=coldiff,legend=false)
# The l.i. clusters seem to be the same for pairs and about 1/2 the 3 bodies. Then the second case seems to pick up 

diffs = abs.(diam[li]-diam2[li2])
diffs[39]
cond(mred)
cond(mred2)

m3, diam3, vertOrd3 = getRenumDesignMatrix(lat,1.5,2,3);
rank(m3)
cond(m3)
mred3, li3 = leftmostIndependentColumns(m3,60)
col3 = fill(:blue,size(m3,2))
col3[li3] .= :red
scatter(diam3,msw=0,color=col3,ms=2,legend=:none,
dpi=300,
xlabel="Cluster index",ylabel="Radius",title="Binary fcc, rcut=1.5, Aug=3 (red lin. ind.)")
savefig("figures/fccBinaryRadiusEnumerationAug3.png")
# cellVecVerts = 3 gave rank = 415 (full rank)
# Wow, the condition number is 1000x better than the incomplete cases
# The questions though is what clusters were added that helped? Was it pairs? triplets? quadruplets?

# To figure this out, will have to find the li columns of the matrix and see what clusters they correspond to.

plot()
for i in [diam[li],diam2[li2],diam3[li3]]
plot!(i,xlabel="Cluster index",ylabel="Radius",title="Radii of independent clusters",color=:darkgreen,ms=2)
end
# Find the matching columns in m2. assums the same order but extra columns here and there in m2.
marker = 1; maplist = Vector{Int64}(); abort = false;
for (j,i) ∈ enumerate(eachcol(m))
    while norm(i-m2[:,marker]) > 1e-4
        marker += 1
        println("$j diff: ", round(norm(i-m2[:,marker]),digits=10))
        if marker > size(m,2) abort = true; break end
    end
    if abort break end
    push!(maplist,marker)
end
maplist
plot(maplist,st=:scatter,msw=0,ms=2) 

[norm(m[:,128]-m2[:,i]) for i in 141:size(m2,2)]|> plot
[norm(m[:,i] - m2[:,i]) for i in 1:40]|> plot

# Find the matching columns in m2 for each column in m. Makes no assumption about the order of the columns in m2.
matchList = Vector{Vector{Int64}}()
for i in 1:size(m,2)
    for j in 1:size(m2,2)
       if norm(m[:,i]-m2[:,j]) < 1e-4
        push!(matchList,[i,j])
        break
       end
    end
end
hcat(matchList...)'
scatter(hcat(matchList...)',msw=0,ms=2)

""" findCommonColumns(m1,m2)

Returns the indices (list of integers) of columns in m2 that match m1. """ 
function findCommonColumns(m1,m2)   
    return findall(in(eachcol(m1)),eachcol(m2))
end

"""radiusEnumeration(A;maxVol=15)

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

