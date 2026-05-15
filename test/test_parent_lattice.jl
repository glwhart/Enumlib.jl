using Test
using Enumlib
using LinearAlgebra

@testset "ParentLattice and SymmetryOp (chunk 1 + 1.1)" begin

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
        # Symmorphic — no non-zero translations
        @test n_nonzero_translations(pl) == 0
        # Identity is included
        @test any(op -> op.R == [1 0 0; 0 1 0; 0 0 1] && op.t == [0.0, 0.0, 0.0],
                  space_group(pl))
    end

    # ---- ParentLattice: FCC Bravais — both handednesses ----
    @testset "FCC Bravais — left- and right-handed bases both give 48 ops" begin
        # Left-handed primitive (det = -0.25) — the convention in the existing test corpus
        A_lefthand = [0.5 0.5 0.0;
                      0.5 0.0 0.5;
                      0.0 0.5 0.5]
        @test det(A_lefthand) < 0
        pl_l = ParentLattice(A_lefthand)
        @test length(space_group(pl_l)) == 48
        @test n_nonzero_translations(pl_l) == 0  # FCC is symmorphic Fm-3m

        # Right-handed primitive — swap two columns of the left-handed one
        A_righthand = [0.5 0.0 0.5;
                       0.5 0.5 0.0;
                       0.0 0.5 0.5]
        @test det(A_righthand) > 0
        pl_r = ParentLattice(A_righthand)
        @test length(space_group(pl_r)) == 48
        @test n_nonzero_translations(pl_r) == 0
    end

    # ---- ParentLattice: tetragonal Bravais (right-handed; |G| = 16 for P4/mmm) ----
    @testset "Tetragonal Bravais — 16 ops, right-handed" begin
        a, c = 1.0, 1.6
        A = [a 0.0 0.0;
             0.0 a 0.0;
             0.0 0.0 c]
        @test det(A) > 0
        pl = ParentLattice(A)
        @test ndset(pl) == 1
        @test length(space_group(pl)) == 16   # P4/mmm point group has 16 ops
        @test n_nonzero_translations(pl) == 0 # symmorphic
    end

    # ---- ParentLattice: HCP multilattice (P6_3/mmc, expects 12/24 non-zero t) ----
    @testset "HCP multilattice — 24 ops, 12 with screw-axis translations" begin
        a = 1.0
        c = sqrt(8/3)
        A = [a    -a/2     0.0;
             0.0   a*sqrt(3)/2  0.0;
             0.0   0.0     c]
        # Conventional HCP dset: second site at (1/3, 2/3, 1/2) in lattice coordinates.
        dset_hcp = [[0.0, 0.0, 0.0],
                    [1/3, 2/3, 1/2]]
        pl = ParentLattice(A, dset_hcp)
        @test ndset(pl) == 2
        @test length(space_group(pl)) == 24
        # P6_3/mmc has a 6_3 screw axis: 12 of the 24 ops carry a non-zero
        # fractional translation (compositions involving the (1/2)c screw).
        @test n_nonzero_translations(pl) == 12
    end

    # ---- ParentLattice: input validation ----
    @testset "ParentLattice input validation" begin
        # Singular basis (det = 0)
        A_singular = [1.0 0 0; 0 1.0 0; 1.0 1.0 0]
        @test_throws ArgumentError ParentLattice(A_singular)

        # Zero-norm column — caught before the Hadamard ratio computation
        A_zerocol = [1.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 1.0]
        @test_throws ArgumentError ParentLattice(A_zerocol)

        # Near-singular but technically non-zero (ratio = 1e-13) — should still throw
        A_nearsing = [1.0 0.0 1.0; 0.0 1.0 1.0; 0.0 0.0 1e-13]
        @test_throws ArgumentError ParentLattice(A_nearsing)

        # Non-square basis
        A_nonsquare = [1.0 0 0; 0 1.0 0]
        @test_throws Union{ArgumentError, DimensionMismatch} ParentLattice(A_nonsquare)

        # dset position with wrong length
        A = Matrix{Float64}(I, 3, 3)
        @test_throws ArgumentError ParentLattice(A, [[0.0, 0.0, 0.0], [0.5, 0.5]])

        # Empty dset
        @test_throws ArgumentError ParentLattice(A, Vector{Float64}[])
    end

    # ---- ParentLattice: silent canonicalization (chunk 1.1) ----
    @testset "Silent canonicalization of dset and Bravais anchor" begin
        A = Matrix{Float64}(I, 3, 3)

        # Wrap into [0,1) — input [1.5, -0.5, 0.5] should be folded to [0.5, 0.5, 0.5]
        # then (since this is Bravais) shifted to [0, 0, 0].
        pl_wrapped = ParentLattice(A, [[1.5, -0.5, 0.5]])
        @test pl_wrapped.dset[1] ≈ [0.0, 0.0, 0.0]   # Bravais shift to origin

        # Bravais anchor: an off-origin single-site dset is shifted to origin
        pl_off = ParentLattice(A, [[0.25, 0.25, 0.25]])
        @test pl_off.dset[1] ≈ [0.0, 0.0, 0.0]

        # Multilattice: anchor is preserved (no shift). Diamond example: dset at
        # (1/8, 1/8, 1/8) and (-1/8, -1/8, -1/8) — equivalent under the inversion
        # but the user chose this anchor for a physical reason.
        A_fcc = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
        dset_off = [[0.125, 0.125, 0.125], [0.875, 0.875, 0.875]]
        pl_dia = ParentLattice(A_fcc, dset_off)
        # Anchor preserved (after [0,1) wrap, no Bravais shift since length == 2)
        @test pl_dia.dset[1] ≈ [0.125, 0.125, 0.125]
        @test pl_dia.dset[2] ≈ [0.875, 0.875, 0.875]
    end

    # ---- ParentLattice: dset doesn't have to contain origin ----
    @testset "dset without one site at the origin (diamond-style anchoring)" begin
        # FCC primitive basis with diamond-style dset: 2 sites at (1/8, 1/8, 1/8) and
        # its inversion through the origin. This is the natural anchoring for a real-
        # Hamiltonian DFT calculation.
        A = [0.5 0.5 0.0;
             0.5 0.0 0.5;
             0.0 0.5 0.5]
        dset = [[0.125, 0.125, 0.125], [0.875, 0.875, 0.875]]
        pl = ParentLattice(A, dset)
        @test ndset(pl) == 2
        # Diamond's space group has 48 operations (in the FCC primitive setting).
        @test length(space_group(pl)) == 48
        # Diamond is non-symmorphic; specific count below in the symmorphism testset.
    end

    # ---- ParentLattice: fractional-translation breakdown across symmorphism types ----
    # Bundles items 6 and 8: HCP (non-symmorphic, 12/24), diamond (non-symmorphic,
    # 24/48), perovskite (symmorphic, 0/48). Catches a Spacey regression where
    # translations get computed but reported as zero — or vice versa.
    @testset "Symmorphism check: non-zero translation counts" begin
        # Symmorphic: perovskite ABO_3 in cubic Pm-3m. All ops should have t = 0.
        A_perov = Matrix{Float64}(I, 3, 3)
        dset_perov = [[0.0, 0.0, 0.0],
                      [0.5, 0.5, 0.5],
                      [0.5, 0.5, 0.0],
                      [0.5, 0.0, 0.5],
                      [0.0, 0.5, 0.5]]
        perov = ParentLattice(A_perov, dset_perov)
        @test length(space_group(perov)) == 48
        @test n_nonzero_translations(perov) == 0

        # Non-symmorphic: HCP (P6_3/mmc) — 6_3 screw axis gives 12/24 non-zero t.
        # (Already tested in the HCP testset above; included here for the symmorphism
        # comparison row.)
        A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
        dset_hcp = [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]
        hcp = ParentLattice(A_hcp, dset_hcp)
        @test n_nonzero_translations(hcp) == 12

        # Non-symmorphic: diamond (Fd-3m) — glide planes give 24/48 non-zero t.
        A_fcc = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
        dset_dia = [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]]
        dia = ParentLattice(A_fcc, dset_dia)
        @test length(space_group(dia)) == 48
        @test n_nonzero_translations(dia) == 24
    end

    # ---- R50.2a: dset-permutation precomputation ----
    # For every symmetry op (N, t) and every dset position d_i, we precompute:
    #   - π(i): the index of the d_j that N·d_i + t maps to (mod L).
    #   - v_i: the lattice shift (integer vector) such that N·d_i + t = d_{π(i)} + v_i.
    # Used by the multilattice getPermG path (R50.2b).
    @testset "dset-permutation precomputation (R50.2a)" begin

        # Single-lattice (FCC primitive): degenerate n_D = 1 case.
        @testset "single-lattice — π and v are trivial for every op" begin
            A = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
            p = ParentLattice(A)
            @test length(p.dset_perms) == length(p.space_group)
            @test length(p.dset_shifts) == length(p.space_group)
            # Every op sends the lone dset position to itself with zero lattice shift.
            @test all(π == [1] for π in p.dset_perms)
            @test all(v == [[0, 0, 0]] for v in p.dset_shifts)
        end

        # HCP (P6_3/mmc) multilattice: 24 ops, 6_3 screw swaps the two sublattices.
        @testset "HCP — 24 ops split 12/12 between preserve and swap" begin
            A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
            p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])

            @test length(p_hcp.space_group) == 24
            @test length(p_hcp.dset_perms) == 24
            # The identity is always first; it preserves the sublattices with no shift.
            @test p_hcp.dset_perms[1] == [1, 2]
            @test p_hcp.dset_shifts[1] == [[0, 0, 0], [0, 0, 0]]

            # Each π must be a permutation of {1, 2} (only two valid permutations for n_D = 2).
            for π in p_hcp.dset_perms
                @test sort(π) == [1, 2]
            end

            # Half preserve, half swap.
            preserve = count(==([1, 2]), p_hcp.dset_perms)
            swap     = count(==([2, 1]), p_hcp.dset_perms)
            @test preserve == 12
            @test swap == 12
            @test preserve + swap == 24
        end

        # Diamond (Fd-3m) multilattice: 48 ops, glide planes swap the sublattices.
        @testset "Diamond — 48 ops split 24/24" begin
            A_fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
            p_dia = ParentLattice(A_fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])

            @test length(p_dia.space_group) == 48
            @test p_dia.dset_perms[1] == [1, 2]
            preserve = count(==([1, 2]), p_dia.dset_perms)
            swap     = count(==([2, 1]), p_dia.dset_perms)
            @test preserve == 24
            @test swap == 24
        end

        # Math writeup worked example — verifies _dset_permutation directly against
        # the derivation in docs/notes/multilattice_dset_mapping_writeup.pdf.
        # Setup: 5·I primary lattice; D = {(0,0,0), (0,3,0), (2,3,0), (2,0,0)} in
        # Cartesian. Test op: N = 90°-rotation-around-z-then-invert-z, lattice-frame
        # t = (2, 0, 0). Expected π = (4, 1, 2, 3); expected v_i (Cartesian) =
        # {(0,0,0), (5,0,0), (5,-5,0), (0,-5,0)}.
        # Translated to lattice-frame coords (divide by 5): dset in (0,1)^3,
        # t = (0.4, 0, 0), v_i = {(0,0,0), (1,0,0), (1,-1,0), (0,-1,0)}.
        @testset "math writeup worked example" begin
            dset_cart = [[0.0, 0.0, 0.0], [0.0, 3.0, 0.0], [2.0, 3.0, 0.0], [2.0, 0.0, 0.0]]
            dset_frac = [d ./ 5 for d in dset_cart]
            N = [0 1 0; -1 0 0; 0 0 -1]
            t_frac = [2.0, 0.0, 0.0] ./ 5

            π, v = Enumlib._dset_permutation(dset_frac, N, t_frac, 1e-6, 0)
            @test π == [4, 1, 2, 3]
            @test v == [[0, 0, 0], [1, 0, 0], [1, -1, 0], [0, -1, 0]]
        end

        # _dset_permutation rejects a spurious op (one that doesn't preserve the dset).
        # 90° z-rotation applied to (0.3, 0.7, 0.5) sends it to (0.7, -0.3, 0.5),
        # which mod 1 is (0.7, 0.7, 0.5) — not in {(0,0,0), (0.3, 0.7, 0.5)}.
        @testset "_dset_permutation throws on spurious op" begin
            bad_dset = [[0.0, 0.0, 0.0], [0.3, 0.7, 0.5]]
            bad_R = [0 1 0; -1 0 0; 0 0 1]
            bad_t = [0.0, 0.0, 0.0]
            @test_throws ArgumentError Enumlib._dset_permutation(bad_dset, bad_R, bad_t, 1e-6, 0)
        end

        # eps_dset is configurable via the ParentLattice constructor.
        @testset "eps_dset kwarg propagates" begin
            A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
            dset_hcp = [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]
            # Default (1e-6) — works.
            @test_nowarn ParentLattice(A_hcp, dset_hcp)
            # Tighter (1e-12) — still works because float-precision noise on the
            # rotation arithmetic is well below 1e-12.
            @test_nowarn ParentLattice(A_hcp, dset_hcp; eps_dset = 1e-12)
            # Looser (1e-3) — works too; well above the natural separations.
            @test_nowarn ParentLattice(A_hcp, dset_hcp; eps_dset = 1e-3)
        end
    end

    # ---- R50.2b: cross-method consistency for getPermG on single-lattice ----
    # The new parent-aware getPermG (R50.2b) should agree with the legacy
    # LG-based getPermG on every single-lattice case (the L1 degenerate path).
    # Three parents × three volumes = 9 cross-checks.
    @testset "getPermG cross-method consistency (single-lattice, R50.2b)" begin
        sc_parent  = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        fcc_parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        bcc_parent = ParentLattice([-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5])

        for parent in (sc_parent, fcc_parent, bcc_parent)
            LG = Enumlib.lattice_rotations(parent)
            for n in (2, 4, 8)
                for h in getSymInequivHNFs(n, parent)
                    fixingOps = Enumlib.getFixingOps(h.matrix, LG)
                    perm_old = Enumlib.getPermG(h.matrix, fixingOps, LG)
                    perm_new = Enumlib.getPermG(h.matrix, fixingOps, parent)
                    @test length(perm_old) == length(perm_new)
                    @test Set(perm_old) == Set(perm_new)
                end
            end
        end
    end

end
