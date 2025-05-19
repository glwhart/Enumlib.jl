using Spacey

function shiftToOrigin(clusterPoints)
    m = minimum(clusterPoints, dims=2)
    return clusterPoints .- m
end


c1 = hcat([[1,0,1],[1,1,1],[1,0,0],[2,2,1]]...)
shiftToOrigin(c1)



A = [1 0 0; 0 1 0; 0 0 1]


function isEquivClusters(c1, c2, A)
    c1 = sort(shiftToOrigin(c1), dims=2)
    c2 = shiftToOrigin(c2)

    LG = pointGroup(A)[1]

    for g in LG
        c2g = sort(shiftToOrigin(g * c2), dims=2)

        if c1 == c2g
            return true
        end
    end

    return false
end


c2 = (pointGroup(A)[1][8]*hcat([[1,0,1],[1,0,0],[2,2,1],[1,1,1]]...) .+ [1; 2; -1])

isEquivClusters(c1, c2, A)



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