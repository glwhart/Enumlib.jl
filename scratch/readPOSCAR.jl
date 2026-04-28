using clusterExpansion
using NormalForms
using LinearAlgebra

function readPOSCARs(folder::String, A=nothing)
    files = sort(filter(f -> !isdir(joinpath(folder,f)), readdir(folder)))

    # Read first POSCAR to get parent lattice and k if not provided
    first_lines = readlines(joinpath(folder, files[1]))
    if A === nothing
        A = hcat([parse.(Float64, split(first_lines[i])) for i ∈ 3:5]...)
    end
    print("Parent lattice A:\n", A, "\n")
    k = length(split(first_lines[6]))

    hnfs = Matrix{Int64}[]
    colorings = Vector{Vector{Int64}}[]

    for (iStr, f) in enumerate(files)
        lines = readlines(joinpath(folder, f))

        # scaled lattice vectors - assume 1
        scale = 1.0 #parse(Float64, lines[2])

        # lattice vectors in Cartesian coordinates
        sv = scale .* hcat([parse.(Float64, split(lines[i])) for i ∈ 3:5]...)
        sl = round.(Int, inv(A) * sv)  # lattice coordinates

        # concentration vector
        iconc = parse.(Int, split(lines[7])[1:k])
        n = sum(iconc)

        # direct coordinates of atoms
        dcPts = hcat([parse.(Float64, split(lines[8+i])[1:3]) for i ∈ 1:n]...)

        # Smith normal form
        snf_obj = snf(sl)
        L = snf_obj.U
        SNF = diag(snf_obj.S)

        # Get ordinals from gCoords from direct coordinates
        gCoords = mod.(round.(L * sl * dcPts, digits=8), SNF)
        idx = gCoordsToOrdinals(gCoords, SNF)

        lab = sortperm(vcat([fill(j-1, iconc[j]) for j ∈ 1:k]...))
        lab = lab[idx]

        found = false
        for i in eachindex(hnfs)
            if hnfs[i] == sl
                push!(colorings[i], lab)
                found = true
                break
            end
        end
        if !found
            push!(hnfs, sl)
            push!(colorings, [lab])
        end
    end
    return hnfs, colorings, A
end

h,c = readPOSCARFolder("poscars/test")

h
c
hnfs
rcolorings

h == hnfs
c == rcolorings

setdiff(h, hnfs)

for (i,z) in enumerate(c)
    println(i, " ", z==rcolorings[i])
    if z!=rcolorings[i]
        # println(setdiff(z, rcolorings[i]))
    end
end

c[13]
rcolorings[13]
setdiff(c[13], rcolorings[13])
setdiff(rcolorings[13], c[13])

unique(c[13])
unique(rcolorings[13])



strs = clusterExpansion.readStrIn("poscars/structures-1772471704981.in")

h2,c2 = [], []
for s in strs
    push!(h2, s.HNF)
    push!(c2, s.coloring)
end

h2_red = []
c22 = []
for (ic,co) in enumerate(c2)
    found = false
    for i in eachindex(h2_red)
        if h2_red[i] == h2[ic]
            push!(c22[i], co)
            found = true
            break
        end
    end
    if !found
        push!(h2_red, h2[findfirst(c2 .== co)])
        push!(c22, [co])
    end
end

for cs in c22
    if length(cs) == length(unique(cs))
        println("All unique")
    else
        println("Duplicates found")
    end
end

c22[3]
unique(c22[3])