using Test
using Enumlib
using LinearAlgebra: det

@testset "HNF and Supercell (chunk 3)" begin

    # ---- HNF{D} validation ----
    @testset "HNF validation" begin
        # Valid lower-triangular HNF
        m = [1 0 0; 0 1 0; 2 3 4]
        h = HNF(m)
        @test h.matrix == m
        @test volume(h) == 4
        @test det(h) == 4         # LinearAlgebra.det overload
        @test typeof(det(h)) == Int

        # Wrong size
        @test_throws ArgumentError HNF{3}([1 0; 0 1])

        # Non-square
        @test_throws Union{ArgumentError, DimensionMismatch} HNF([1 2; 3 4; 5 6])

        # Zero diagonal entry
        @test_throws ArgumentError HNF([0 0 0; 0 1 0; 0 0 1])

        # Negative diagonal entry
        @test_throws ArgumentError HNF([-1 0 0; 0 1 0; 0 0 1])

        # Non-zero super-diagonal (not lower-triangular)
        @test_throws ArgumentError HNF([1 1 0; 0 1 0; 0 0 1])

        # Sub-diagonal out of range (must be in [0, diag))
        @test_throws ArgumentError HNF([2 0 0; 5 1 0; 0 0 1])      # 5 ≥ 1 (diag of row 2)
        @test_throws ArgumentError HNF([2 0 0; -1 1 0; 0 0 1])     # negative
    end

    # ---- HNF equality and hashing (pairing rule) ----
    @testset "HNF equality and hashing" begin
        a = HNF([1 0 0; 0 1 0; 2 3 4])
        b = HNF([1 0 0; 0 1 0; 2 3 4])
        c = HNF([2 0 0; 1 2 0; 0 0 2])
        @test a == b
        @test a != c
        @test hash(a) == hash(b)
        @test length(Set([a, b, c])) == 2
    end

    # ---- HNF show ----
    @testset "HNF pretty printing" begin
        h = HNF([1 0 0; 0 1 0; 2 3 4])
        s = sprint(show, h)
        @test occursin("HNF{3}", s)
        @test occursin("volume 4", s)
        @test occursin("2 3 4", s)        # the third row, where the interesting digits are
    end

    # ---- Supercell construction: simple cubic n=2 ----
    # Single-site Bravais cube; 48 ops in the parent space group; for any HNF of
    # volume 2, the stabilizer subgroup will be smaller (reflecting the
    # superlattice's reduced symmetry).
    @testset "Supercell — simple cubic n=2" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        hnfs = getSymInequivHNFs(2, parent)
        @test length(hnfs) == 3   # captured from the experiment above

        # Build a Supercell from each HNF; verify SNF diagonal product equals volume
        for h in hnfs
            sc = Supercell(h, parent)
            @test prod(sc.snf) == volume(h)
            @test sc.n_stabilizer_ops > 0
            @test sc.n_stabilizer_ops <= 48                     # ≤ |parent space group|
            # Perm group size is (#unique rotation-actions on supercell sites) ×
            # (#translations). Translations contribute n; rotation-actions are at
            # most `n_stabilizer_ops` but can be fewer (different rotations can
            # induce the same permutation on the supercell). So the perm group
            # size is a multiple of n, bounded above by n_stabilizer_ops × n.
            @test length(sc.permutation_group) % volume(h) == 0
            @test length(sc.permutation_group) <= sc.n_stabilizer_ops * volume(h)
            @test length(sc.permutation_group) >= volume(h)      # at least the translations
        end
    end

    # ---- Supercell construction: HCP multilattice ----
    @testset "Supercell — HCP multilattice n=2" begin
        a = 1.0; c = sqrt(8/3)
        A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
        dset_hcp = [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]
        parent = ParentLattice(A_hcp, dset_hcp)
        hnfs = getSymInequivHNFs(2, parent)
        @test length(hnfs) == 3                                  # captured from the experiment

        for h in hnfs
            sc = Supercell(h, parent)
            @test prod(sc.snf) == volume(h)
            @test sc.n_stabilizer_ops > 0
            @test sc.n_stabilizer_ops <= 24                     # ≤ |HCP space group| = 24
        end
    end

    # ---- getSymInequivHNFs counts across a corpus of lattices and sizes ----
    # Captured by running getSymInequivHNFs once during chunk 3 development
    # (per chunk 3 design item 5) and locked here as the regression target.
    @testset "Inequivalent-HNF counts across lattice corpus" begin
        # Each entry: (lattice name, parent, expected counts at n = 2, 4, 6, 8, 12)
        sc_parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        fcc_parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        bcc_parent = ParentLattice([-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5])
        tet_parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.6])
        a = 1.0; c = sqrt(8/3)
        hcp_parent = ParentLattice([a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c],
                                   [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])

        cases = [
            ("Simple cubic",    sc_parent,  [3,  9, 13, 24,  49]),
            ("FCC",             fcc_parent, [2,  7, 10, 20,  41]),
            ("BCC",             bcc_parent, [2,  7, 10, 20,  41]),
            ("Tetragonal",      tet_parent, [5, 17, 29, 51, 115]),
            ("HCP multilatt",   hcp_parent, [3, 11, 19, 34,  77]),
        ]
        sizes = [2, 4, 6, 8, 12]

        for (name, parent, expected) in cases
            counts = [length(getSymInequivHNFs(n, parent)) for n in sizes]
            @test counts == expected
        end
    end

    # ---- Bridge between new and legacy ----
    @testset "Bridge: new getSymInequivHNFs matches legacy lattice-coord version" begin
        using Spacey: pointGroup
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        LG = pointGroup(parent.A)

        for n in [2, 4, 8]
            new_hnfs = getSymInequivHNFs(n, parent)
            legacy_hnfs = getSymInequivHNFs(n, LG)         # legacy lattice-coord API
            @test length(new_hnfs) == length(legacy_hnfs)
            # Order may differ; compare as sets of underlying matrices
            new_matrices = Set(h.matrix for h in new_hnfs)
            legacy_matrices = Set(legacy_hnfs)
            @test new_matrices == legacy_matrices
        end
    end

    # ---- Supercell equality and hashing ----
    @testset "Supercell equality and hashing" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        hnfs = getSymInequivHNFs(2, parent)
        s1 = Supercell(hnfs[1], parent)
        s2 = Supercell(hnfs[1], parent)              # same HNF, same parent
        s3 = Supercell(hnfs[2], parent)              # different HNF
        @test s1 == s2
        @test hash(s1) == hash(s2)
        @test s1 != s3
        @test length(Set([s1, s2, s3])) == 2
    end

    # ---- Supercell show ----
    @testset "Supercell pretty printing" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        hnfs = getSymInequivHNFs(2, parent)
        sc = Supercell(hnfs[1], parent)
        s = sprint(show, sc)
        @test occursin("Supercell{3}", s)
        @test occursin("|stabilizer|", s)
        @test occursin("HNF:", s)
        @test occursin("SNF diag:", s)
    end

end
