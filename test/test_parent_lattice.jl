using Test
using Enumlib
using LinearAlgebra

@testset "ParentLattice and SymmetryOp (chunk 1)" begin

    # ---- SymmetryOp: construction validation ----
    @testset "SymmetryOp validation" begin
        # Wrong rotation size
        @test_throws ArgumentError SymmetryOp{3}(zeros(Int, 2, 2), zeros(3))
        # Wrong translation length
        @test_throws ArgumentError SymmetryOp{3}([1 0 0; 0 1 0; 0 0 1], zeros(2))
        # Identity op constructs cleanly
        op = SymmetryOp{3}([1 0 0; 0 1 0; 0 0 1], [0.0, 0.0, 0.0])
        @test op.R == [1 0 0; 0 1 0; 0 0 1]
        @test op.t == [0.0, 0.0, 0.0]
    end

    # ---- ParentLattice: simple cubic Bravais (Pm-3m, |G| = 48) ----
    @testset "Simple cubic Bravais — 48 ops" begin
        A = Matrix{Float64}(I, 3, 3)
        pl = ParentLattice(A)
        @test ndset(pl) == 1
        @test length(space_group(pl)) == 48
        # Identity is included
        @test any(op -> op.R == [1 0 0; 0 1 0; 0 0 1] && op.t == [0.0, 0.0, 0.0],
                  space_group(pl))
    end

    # ---- ParentLattice: FCC Bravais (Fm-3m, |G| = 48 in primitive basis) ----
    @testset "FCC Bravais — 48 ops" begin
        # Primitive FCC basis (the conventional Phase 6 example)
        A = [0.5 0.5 0.0;
             0.5 0.0 0.5;
             0.0 0.5 0.5]
        pl = ParentLattice(A)
        @test ndset(pl) == 1
        @test length(space_group(pl)) == 48
    end

    # ---- ParentLattice: HCP multilattice (P6_3/mmc, expects fractional translations) ----
    @testset "HCP multilattice — fractional translations expected" begin
        # Hexagonal a, c with c/a = √(8/3) (ideal HCP)
        a = 1.0
        c = sqrt(8/3)
        A = [a    -a/2     0.0;
             0.0   a*sqrt(3)/2  0.0;
             0.0   0.0     c]
        # Conventional HCP dset: 2 sites, the second offset by (1/3, 2/3, 1/2) in
        # crystallographic coordinates (not (1/3, 1/3, 1/2) — the latter gives a
        # different multilattice).
        dset_hcp = [[0.0, 0.0, 0.0],
                    [1/3, 2/3, 1/2]]
        pl = ParentLattice(A, dset_hcp)
        @test ndset(pl) == 2
        # HCP space group P6_3/mmc has 24 operations. Some may carry a fractional
        # translation (½, ½ along c due to the screw axis 6_3).
        @test length(space_group(pl)) == 24
        # At least one op should carry a non-zero fractional translation
        @test any(op -> any(t -> t > 1e-9, op.t), space_group(pl))
    end

    # ---- ParentLattice: input validation ----
    @testset "ParentLattice input validation" begin
        # Singular basis (det = 0)
        A_singular = [1.0 0 0; 0 1.0 0; 1.0 1.0 0]
        @test_throws ArgumentError ParentLattice(A_singular)

        # Non-square basis
        A_nonsquare = [1.0 0 0; 0 1.0 0]
        @test_throws Union{ArgumentError, DimensionMismatch} ParentLattice(A_nonsquare)

        # dset position outside [0,1)
        A = Matrix{Float64}(I, 3, 3)
        @test_throws ArgumentError ParentLattice(A, [[0.0, 0.0, 0.0], [1.5, 0.0, 0.0]])

        # dset position with wrong length
        @test_throws ArgumentError ParentLattice(A, [[0.0, 0.0, 0.0], [0.5, 0.5]])

        # Left-handed basis is allowed (Hart-Forcade is handedness-agnostic; existing
        # test corpus uses a left-handed FCC primitive basis).
        A_lefthand = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]   # FCC primitive, det = -0.25
        pl = ParentLattice(A_lefthand)
        @test length(space_group(pl)) == 48
    end

    # ---- ParentLattice: dset doesn't have to contain origin ----
    @testset "dset without origin (diamond-style anchoring)" begin
        # FCC basis, dset shifted away from origin (legal — doesn't have to contain origin
        # per Phase 6 design discussion).
        A = [0.5 0.5 0.0;
             0.5 0.0 0.5;
             0.0 0.5 0.5]
        dset = [[0.25, 0.25, 0.25], [0.75, 0.75, 0.75]]
        pl = ParentLattice(A, dset)
        @test ndset(pl) == 2
        # Should still get a valid space group; exact count depends on the geometry
        # (this is diamond-like, expecting 48 ops for the Fd-3m structure)
        @test length(space_group(pl)) >= 48
    end

end
