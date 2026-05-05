# Tests for Enumlib: HNF enumeration, colorings, symmetry reduction.

using Test
using Enumlib
using Combinatorics
using LinearAlgebra
using Spacey

# v0.2 chunk-by-chunk test files. Each one is a standalone @testset; running
# Pkg.test() exercises everything (chunk 1 → 6 plus the legacy corpus below).
include("test_parent_lattice.jl")
include("test_sites.jl")
include("test_hnf.jl")

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

    # Symmetry-inequivalent colorings via HNF + permutation group, 4-site fcc.
    # Uses the lattice-coordinate API throughout (Cartesian variants dropped in
    # chunk 3 — see docs/notes/chunk3-design.md).
    pLat = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
    LG = pointGroup(pLat)
    hnf = getSymInequivHNFs(4, LG)
    fixingOps = [getFixingOps(hnf[i], LG) for i in axes(hnf,1)]
    @test map(1:7) do i
        pG = getPermG(hnf[i], fixingOps[i], LG)
        return getUniqueColorings(3, pG) |> length
    end == [15, 15, 15, 15, 15, 12, 9]
    @test map(1:7) do i
        pG = getPermG(hnf[i], fixingOps[i], LG)
        return getUniqueColorings(2, pG) |> length
    end == [3, 3, 3, 3, 3, 2, 2]

    # 8-site fcc supercell — same count enumlib reports
    hnf = getSymInequivHNFs(8, LG)
    fixingOps = [getFixingOps(hnf[i], LG) for i in axes(hnf,1)]
    @test map(1:length(hnf)) do i
        pG = getPermG(hnf[i], fixingOps[i], LG)
        return getUniqueColorings(2, pG) |> length
    end |> sum == 390

    # 12-site fcc supercell — same count enumlib reports
    hnf = getSymInequivHNFs(12, LG)
    fixingOps = [getFixingOps(hnf[i], LG) for i in axes(hnf,1)]
    @test map(1:length(hnf)) do i
        pG = getPermG(hnf[i], fixingOps[i], LG)
        return getUniqueColorings(2, pG) |> length
    end |> sum == 7140
end
