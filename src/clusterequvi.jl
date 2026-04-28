using Spacey

function shiftToOrigin(clusterPoints)
    m = minimum(eachcol(clusterPoints))
    return clusterPoints .- m
end


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
