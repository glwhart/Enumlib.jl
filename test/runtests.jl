# Tests for the enumeration half of the package: HNF enumeration, colorings,
# symmetry reduction, structure I/O. Pre-split this file is included from
# runtests.jl. After the split into Enumlib.jl, this file is renamed to
# runtests.jl in the new repo.

using Test
using clusterExpansion  # becomes `using Enumlib` post-split
using Combinatorics
using LinearAlgebra
using Spacey

@testset "Colorings and HNF enumeration" begin
    # Plain enumeration of colorings
    k = 3; n = 3
    @test getColorings(3,3) == [collect(reverse(Tuple(c))) for c in CartesianIndices(ntuple(i->0:k-1,n))][:]
    @test [collect(reverse(Tuple(c))) for c in CartesianIndices((0:2,0:2,0:2,0:2,0:2))][:] == getColorings(3,5)

    # Reduced colorings: square lattice, 3 colors
    @test reduce(vcat, reduceColorings(getColorings(3,4), 3, generateGroup([2 3 4 1; 4 3 2 1]))') == [0 0 0 0; 0 0 0 1; 0 0 0 2; 0 0 1 1; 0 0 1 2; 0 0 2 2; 0 1 0 1;
        0 1 0 2; 0 1 1 1; 0 1 1 2; 0 1 2 1; 0 1 2 2; 0 2 0 2; 0 2 1 2;
        0 2 2 2; 1 1 1 1; 1 1 1 2; 1 1 2 2; 1 2 1 2; 1 2 2 2; 2 2 2 2]

    # Reduced colorings: square lattice, 3 colors, oblique tile
    S3 = transpose(hcat(permutations([1,2,3])...))
    @test reduce(vcat, getSymEqvColorings_slow(3,3,S3)') == [0 0 0; 0 0 1; 0 0 2; 0 1 1; 0 1 2; 0 2 2; 1 1 1; 1 1 2; 1 2 2; 2 2 2]

    # 5-site 3-coloring on square supertile
    G5 = generateGroup([2 3 5 1 4; 1 5 2 3 4])
    @test getSymEqvColorings_slow(3,5,G5) == [[0, 0, 0, 0, 0], [0, 0, 0, 0, 1], [0, 0, 0, 0, 2], [0, 0, 0, 1, 1], [0, 0, 0, 1, 2], [0, 0, 0, 2, 2], [0, 0, 1, 1, 1], [0, 0, 1, 1, 2], [0, 0, 1, 2, 1], [0, 0, 1, 2, 2], [0, 0, 2, 2, 1], [0, 0, 2, 2, 2], [0, 1, 1, 1, 1], [0, 1, 1, 1, 2], [0, 1, 1, 2, 2], [0, 1, 2, 1, 2], [0, 1, 2, 2, 2], [0, 2, 2, 2, 2], [1, 1, 1, 1, 1], [1, 1, 1, 1, 2], [1, 1, 1, 2, 2], [1, 1, 2, 2, 2], [1, 2, 2, 2, 2], [2, 2, 2, 2, 2]]

    # Symmetry-inequivalent colorings via HNF + permutation group, 4-site fcc
    pLat = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
    _, G = pointGroup(pLat)
    hnf = getSymInequivHNFs(4, pLat, G)
    fixingOps = [getFixingOps(hnf[i], pLat, G) for i in axes(hnf,1)]
    @test map(1:7) do i
        pG = getPermG(hnf[i], fixingOps[i], pLat, G)
        return getUniqueColorings(3, pG) |> length
    end == [15, 15, 15, 15, 15, 12, 9]
    @test map(1:7) do i
        pG = getPermG(hnf[i], fixingOps[i], pLat, G)
        return getUniqueColorings(2, pG) |> length
    end == [3, 3, 3, 3, 3, 2, 2]

    # 8-site fcc supercell — same count enumlib reports
    hnf = getSymInequivHNFs(8, pLat, G)
    fixingOps = [getFixingOps(hnf[i], pLat, G) for i in axes(hnf,1)]
    @test map(1:length(hnf)) do i
        pG = getPermG(hnf[i], fixingOps[i], pLat, G)
        return getUniqueColorings(2, pG) |> length
    end |> sum == 390

    # 12-site fcc supercell — same count enumlib reports
    hnf = getSymInequivHNFs(12, pLat, G)
    fixingOps = [getFixingOps(hnf[i], pLat, G) for i in axes(hnf,1)]
    @test map(1:length(hnf)) do i
        pG = getPermG(hnf[i], fixingOps[i], pLat, G)
        return getUniqueColorings(2, pG) |> length
    end |> sum == 7140
end
