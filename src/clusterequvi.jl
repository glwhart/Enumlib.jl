using Spacey

function shiftToOrigin(clusterPoints)
    m = minimum(eachcol(clusterPoints))
    return clusterPoints .- m
end



shiftToOrigin(c1)



# A = [1 0 0; 0 1 0; 0 0 1]


function isEquivClusters(c1, c2, LG)
    if size(c1) != size(c2)
        return false
    end

    c1t = shiftToOrigin(c1)
    c1t = c1t[:,sortperm(eachcol(c1t))]
    c2t = shiftToOrigin(c2)
    c2t = c2t[:,sortperm(eachcol(c2t))]

    if c1t == c2t
        return true
    end

    for g in LG
        c2g = shiftToOrigin(g * c2t)
        c2g = c2g[:,sortperm(eachcol(c2g))]

        if c1t == c2g
            # println(g)
            return true
        end
    end

    return false
end


c1 = hcat([[1,0,1],[1,1,1],[1,0,0],[2,2,1]]...)

c2 = LG[10]*c1

shiftToOrigin(c1)
shiftToOrigin(LG[24]*shiftToOrigin(c2))

isEquivClusters(c1, c2, LG)




ctest1 = vcat(rand(1:3, 2, 3),[0 0 0])
ctest2 = vcat(rand(1:3, 2, 3),[0 0 0])

println(isEquivClusters(ctest1, ctest2, A))

scatter(ctest1[1,:], ctest1[2,:], label="c1",ms=10)
scatter!(ctest2[1,:], ctest2[2,:], label="c2")


#gen cluster up to volume 10 and radius 1.38
#compare clusters between 10 and 1.38
#compute energies for 1.38 - get Js from 10, set unknowns to 0
#then do aliasing
#same thing for 8
#testing.jl

rmred, rli, rmwide = load("data/rmred_N20_k2_fcc_renum.jld2", "rmred", "rli", "rm")
rmred = real.(rmred)
mwide = load("data/design_matrix_N10_k2_wide.jld2","m").value
li = load("data/li_N10_k2_reducedm.jld2", "li")
mred = mwide[:,li]
syndata = load("data/syntheticEnergies.jld2", "enthSyn")
J_n10 = load("data/syntheticEnergies.jld2", "J")

rlp_li = rlp[rli[2:end] .- 1]
clp_li = clp[li[2:end] .- 1]

cluster_correlation = zeros(Int, length(rlp_li))

for (i,c) in enumerate(rlp_li)
    for (j,c2) in enumerate(clp_li)
        if isEquivClusters(c, c2, LG)
            println("c1: ", i, " c2: ", j)
            if cluster_correlation[i] != 0
                println("Warning: ", i, " already matched with ", cluster_correlation[i])
            end
            cluster_correlation[i] = j
        end
    end
end

J_r = zeros(length(rlp_li)+1)
J_r[1] = J_n10[1]
for (i,j) in enumerate(cluster_correlation)
    if cluster_correlation[i] != 0
        J_r[i+1] = J_n10[cluster_correlation[i]+1]
    else
        J_r[i+1] = 0
    end
end

syndata_r = rmred * J_r



using Test

@testset "isEquivClusters" begin
    A = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5] # FCC lattice
    LG,G = pointGroup(A)

    @testset "Identical Vertices" begin
        c1 = hcat([[1,0,1],[1,1,1],[1,0,0],[2,2,1]]...)
        c2 = copy(c1)
        @test isEquivClusters(c1, c2, LG)

        c3 = [0 0 0]
        @test isEquivClusters(c3, c3, LG)

        c4 = [0 0 0; -1 2 3; 1 0 0]
        @test isEquivClusters(c4, c4, LG)
    end

    @testset "Different Number of Vertices" begin
        c1 = hcat([[2,0,1],[4,1,1],[1,-1,0],[-1,2,1]]...)
        c2 = hcat([[1,0,0],[1,0,1]]...)
        @test !isEquivClusters(c1, c2, LG)

        c3 = []
        @test !isEquivClusters(c1, c3, LG)

        c4 = hcat([[2,0,1],[4,1,1],[1,-1,0],[-1,2,1], [2,0,1]]...)
        @test !isEquivClusters(c1, c4, LG)
    end

    @testset "Translations" begin
        c1 = hcat([[-1,0,1],[1,2,1],[1,4,0],[3,2,1]]...)
        c2 = c1 .+ [1, -2, -1]
        @test isEquivClusters(c1, c2, LG)

        c3 = c1 .+ [0, 0, 0]
        @test isEquivClusters(c1, c3, LG)

        c4 = c1 .+ [-2, 2, 2]
        @test isEquivClusters(c1, c4, LG)
    end

    @testset "Rotations" begin
        c1 = hcat([[1,-1,1],[-3,1,2],[1,1,2],[2,2,1]]...)
        for g in LG
            c2 = g * c1
            @test isEquivClusters(c1, c2, LG)
        end

        c3 = [-1 1 4; 1 2 1; 2 1 3] * c1
        @test !isEquivClusters(c1, c3, LG)

        c4 = [0 0 0; 0 0 0; 0 0 0] * c1
        @test !isEquivClusters(c1, c4, LG)
    end

    @testset "Permutations" begin
        c1 = hcat([[2,0,1],[1,-1,1],[-2,-2,-2],[2,3,1],[-1,2,3]]...)
        c2 = c1[:, [3, 1, 2, 4, 5]]
        @test isEquivClusters(c1, c2, LG)
        c3 = c1[:, [5, 4, 3, 2, 1]]
        @test isEquivClusters(c1, c3, LG)
        c4 = c1[:, [1, 2, 3, 4]]
        @test !isEquivClusters(c1, c4, LG)
    end

    @testset "Combination Test" begin
        c1 = hcat([[2,0,1],[1,-1,1],[2,3,1],[-1,2,3]]...)
        for g in LG
            c2 = (g * c1[:, [3, 1, 2, 4]]) .+ [-1, 2, -1]
            @test isEquivClusters(c1, c2, LG)

            c3 = g * (c1[:, [1, 4, 3, 2]] .+ [1, -1, 3])
            @test isEquivClusters(c1, c3, LG)
        end
    end
end