# Tests for Enumlib: HNF enumeration, colorings, symmetry reduction.

using Test
using Enumlib
using Enumlib: getColorings, reduceColorings, getSymEqvColorings_slow,
    generateGroup    # un-exported utility helpers used by the legacy testset below
using Combinatorics
using LinearAlgebra
using Spacey

# v0.2 chunk-by-chunk test files. Each one is a standalone @testset; running
# Pkg.test() exercises everything (chunk 1 → 6 plus the legacy corpus below).
include("test_parent_lattice.jl")
include("test_sites.jl")
include("test_atomic_labels.jl")
include("test_hnf.jl")
include("test_supercell_selection.jl")
include("test_enumerate.jl")
include("test_concentration.jl")
include("test_polya.jl")
include("test_cost_estimate.jl")
include("test_recursive_stabilizer.jl")
include("test_auto_dispatch.jl")
include("test_poscar.jl")
include("test_legacy_import.jl")

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

    # (The HNF + lattice-coord getPermG legacy-API regression suite — formerly
    # FCC binary/ternary at n=4/8/12 — was retired in v0.3-prep when the legacy
    # `getPermG(h, fixingOps, LG::Vector{Matrix{Int}})` method was removed. The
    # same canonical counts (3/3/3/3/3/2/2 ternary at n=4, sum=390 binary at
    # n=8, sum=7140 binary at n=12) are now locked via the public
    # `enumerate(...)` API in test_enumerate.jl.)
end
