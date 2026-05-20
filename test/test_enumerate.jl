using Test
using Enumlib
using Enumlib: getSymInequivHNFs    # un-exported in chunk 13b.1; tests still need it

@testset "Enumeration + enumerate (chunk 5)" begin

    # ---- EnumeratedStructure construction + validation ----
    @testset "EnumeratedStructure validation" begin
        # v0.3-prep: labeling_degeneracy + hnf_degeneracy fields dropped from
        # EnumeratedStructure (the former was a duplicate of orbit_size; the
        # latter moved to Supercell where it semantically belongs).
        s = EnumeratedStructure{3, Vector{Int8}}(1, Int8[0, 1, 0, 1], 3)
        @test s.supercell_id == 1
        @test s.labeling == Int8[0, 1, 0, 1]
        @test s.orbit_size == 3

        # Default for orbit_size.
        s2 = EnumeratedStructure{3, Vector{Int8}}(2, Int8[0, 0])
        @test s2.orbit_size == 1

        # Validation
        @test_throws ArgumentError EnumeratedStructure{3, Vector{Int8}}(0, Int8[0])      # supercell_id < 1
        @test_throws ArgumentError EnumeratedStructure{3, Vector{Int8}}(1, Int8[0], 0)   # orbit_size < 1
    end

    # ---- to_labeling accessor ----
    @testset "to_labeling returns Vector{Int8}" begin
        s = EnumeratedStructure{3, Vector{Int8}}(1, Int8[0, 1, 0])
        v = to_labeling(s)
        @test v isa Vector{Int8}
        @test v == Int8[0, 1, 0]
    end

    # ---- Enumeration iteration + indexing ----
    @testset "Enumeration iterator protocol" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # Build an empty Enumeration and exercise iteration / indexing on a real
        # one via enumerate(...) below. Here, just hand-construct.
        sc = Supercell(HNF([1 0 0; 0 1 0; 0 0 1]), parent)
        s1 = EnumeratedStructure{3, Vector{Int8}}(1, Int8[0])
        s2 = EnumeratedStructure{3, Vector{Int8}}(1, Int8[1])
        e = Enumeration{3, Vector{Int8}}(parent, sites, [sc], [s1, s2])
        @test length(e) == 2
        @test e[1] == s1
        @test e[end] == s2
        # Iteration yields all structures in order.
        out = collect(e)
        @test out == [s1, s2]
    end

    # ---- enumerate(...) — load-bearing FCC reference counts ----
    # These are THE chunk-5 regression tests — they prove the chunk 1→5 stack
    # works end-to-end. Numbers come from the legacy Fortran enumlib's published
    # results and from chunk 3's locked HNF-count corpus.
    @testset "enumerate — FCC binary at n=4 (locked: per-HNF [3,3,3,3,3,2,2])" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        @test length(e) == 19
        @test length(e.supercells) == 7
        per_sc = [count(s -> s.supercell_id == i, e.structures) for i in 1:7]
        @test per_sc == [3, 3, 3, 3, 3, 2, 2]
    end

    @testset "enumerate — FCC ternary at n=4 (locked: per-HNF [15,15,15,15,15,12,9])" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1, 2])])
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        @test length(e) == 96
        @test length(e.supercells) == 7
        per_sc = [count(s -> s.supercell_id == i, e.structures) for i in 1:7]
        @test per_sc == [15, 15, 15, 15, 15, 12, 9]
    end

    @testset "enumerate — FCC binary at n=8 (locked: 390 total)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e = enumerate(parent, sites; supercells = VolumeRange(8:8))
        @test length(e) == 390
    end

    @testset "enumerate — FCC binary at n=12 (locked: 7140 total)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e = enumerate(parent, sites; supercells = VolumeRange(12:12))
        @test length(e) == 7140
    end

    # ---- Volume-range vs single-volume parity ----
    @testset "enumerate — VolumeRange(2:4) sums per-volume counts" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e_range = enumerate(parent, sites; supercells = VolumeRange(2:4))
        per_n = [length(enumerate(parent, sites; supercells = VolumeRange(n:n)))
                 for n in 2:4]
        @test length(e_range) == sum(per_n)
    end

    # ---- ExplicitHNFs path ----
    @testset "enumerate — ExplicitHNFs gives same result as VolumeRange" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # Take the symmetry-inequivalent HNFs at n=4 and pass them as ExplicitHNFs.
        hnfs_n4 = getSymInequivHNFs(4, parent)
        e_explicit = enumerate(parent, sites; supercells = ExplicitHNFs(hnfs_n4))
        e_volume = enumerate(parent, sites; supercells = VolumeRange(4:4))
        @test length(e_explicit) == length(e_volume)
    end

    # ---- algorithm validation ----
    @testset "enumerate — algorithm kwarg validation" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        sel = VolumeRange(2:2)
        # :exhaustive is the default and works
        @test_nowarn enumerate(parent, sites; supercells = sel, algorithm = :exhaustive)
        # :auto resolves to :exhaustive in chunk 5
        @test_nowarn enumerate(parent, sites; supercells = sel, algorithm = :auto)
        # :multinomial requires a concentration kwarg (chunk 6+).
        @test_throws ArgumentError enumerate(parent, sites; supercells = sel, algorithm = :multinomial)
        # :recursive_stabilizer defers to chunk 8
        @test_throws ArgumentError enumerate(parent, sites; supercells = sel, algorithm = :recursive_stabilizer)
        # Unknown algorithms error
        @test_throws ArgumentError enumerate(parent, sites; supercells = sel, algorithm = :foo)
    end

    # ---- Multilattice — regime B (uniform sublattices, HF 2009) ----
    # R50.2b (2026-05-15) flipped this from a throw-test to a Fortran-corpus
    # anchor test. HCP binary counts at n = 1..6 match the Fortran enumlib
    # reference (full mode, no label-exchange elimination): [3, 10, 50, 270,
    # 651, 4793].
    @testset "enumerate — regime B HCP Fortran corpus" begin
        a = 1.0; c = sqrt(8/3)
        A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
        parent = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([1/3, 2/3, 1/2], [0, 1])])
        fortran_hcp = [3, 10, 50, 270, 651, 4793]
        for n in 1:6
            @test length(enumerate(parent, sites; supercells = VolumeRange(n:n))) == fortran_hcp[n]
            @test count_inequivalent(parent, sites; supercells = VolumeRange(n:n)) == fortran_hcp[n]
        end
    end

    # ---- Multilattice — regime B Diamond (FCC + 2-atom dset) ----
    @testset "enumerate — regime B Diamond Fortran corpus" begin
        fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
        parent = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.25, 0.25, 0.25], [0, 1])])
        fortran_diamond = [3, 7, 33, 171]
        for n in 1:4
            @test length(enumerate(parent, sites; supercells = VolumeRange(n:n))) == fortran_diamond[n]
            @test count_inequivalent(parent, sites; supercells = VolumeRange(n:n)) == fortran_diamond[n]
        end
    end

    # ---- Multilattice — regime C (heterogeneous sublattices, chunk 6.5b) ----
    # Chunk 6.5b (2026-05-19) flipped Regime C from "errors with planning message"
    # to "errors only without concentration; works with one". The :recursive_stabilizer
    # algorithm now handles the site-mask filter; :multinomial still errors (queued
    # for chunk 6.5a as :multinomial_restricted).
    @testset "enumerate — regime C gating" begin
        a = 1.0; c = sqrt(8/3)
        A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
        parent = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        # First sublattice binary, second sublattice fixed — different allowed_labels.
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([1/3, 2/3, 1/2], [0])])
        # No concentration → ArgumentError (Regime C requires concentration).
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
        # k = species union = {0, 1} (d₂'s {0} is a subset of d₁'s {0, 1}). At n=2,
        # n_total = 2·2 = 4 sites; d₂'s pair contributes 2 atoms of label 0 forced,
        # leaving d₁'s 2 sites for the binary choice. Pick 2 each species.
        cc = concentration_count([3, 1]; n_total = 4)
        # :multinomial on Regime C → ArgumentError (queued for chunk 6.5a).
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2),
                                              concentration = cc, algorithm = :multinomial)
        # With concentration and :auto → succeeds via :recursive_stabilizer.
        e = enumerate(parent, sites; supercells = VolumeRange(2:2), concentration = cc)
        @test length(e) >= 0          # smoke: doesn't throw
    end

    # ---- Multilattice — Regime C Fortran corpus (chunk 6.5b, 2026-05-19) ----
    # Cross-validation against the locked Fortran corpus at
    # test/data/chunk6.5_fortran_corpus.csv. Covers the cases where Julia and
    # Fortran's Regime-C semantics agree:
    #   • perovskite (all inactive O sublattices share label {4})
    #   • zinc-blende (no inactive sublattices; both active with disjoint labels)
    #   • half-Heusler and full-Heusler with inactive Y and Z relabeled to the
    #     same label {2} (i.e., the "physically equivalent" interpretation that
    #     Fortran's k=2 convention encodes for inactive markers)
    #
    # The distinct-Y={2}, Z={3} cases diverge from Fortran (Julia treats them as
    # distinct active species; Fortran conflates them as inactive markers). See
    # chunk6.5-design.md §11 for the open decision on how to resolve. Skipped in
    # this testset to keep it gating-clean.
    @testset "enumerate — regime C Fortran corpus" begin
        # half-Heusler with Y=Z={2}, binary X-substitution at d₁.
        @testset "half-Heusler (Y=Z={2})" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0, 0.0, 0.0],
                               [0.25, 0.25, 0.25],
                               [0.75, 0.75, 0.75]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([0.25, 0.25, 0.25], [2]),
                           Site([0.75, 0.75, 0.75], [2])])
            expected = [2, 2, 6, 19, 28, 80, 104]   # n = 1..7
            for n in 1:7
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:3])
                e = enumerate(p, sites; supercells = VolumeRange(n:n),
                              concentration = cr, partition_threshold = 1_000_000,
                              skip_resource_check = true)
                @test length(e) == expected[n]
            end
        end

        # full-Heusler with Y=Z={2}, X at d₂ and d₄ (standard 8c Wyckoff).
        @testset "full-Heusler (Y=Z={2})" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0, 0.0, 0.0],
                               [0.25, 0.25, 0.25],
                               [0.5, 0.5, 0.5],
                               [0.75, 0.75, 0.75]])
            sites = Sites([Site([0.0, 0.0, 0.0], [2]),
                           Site([0.25, 0.25, 0.25], [0, 1]),
                           Site([0.5, 0.5, 0.5], [2]),
                           Site([0.75, 0.75, 0.75], [0, 1])])
            expected = [3, 7, 30, 156, 342]   # n = 1..5
            for n in 1:5
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:3])
                e = enumerate(p, sites; supercells = VolumeRange(n:n),
                              concentration = cr, partition_threshold = 1_000_000,
                              skip_resource_check = true)
                @test length(e) == expected[n]
            end
        end

        # Perovskite ABO₃ — A binary, B binary, three O fixed (same label).
        @testset "perovskite ABO₃" begin
            p = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],
                              [[0.0, 0.0, 0.0],
                               [0.5, 0.5, 0.5],
                               [0.5, 0.5, 0.0],
                               [0.5, 0.0, 0.5],
                               [0.0, 0.5, 0.5]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([0.5, 0.5, 0.5], [2, 3]),
                           Site([0.5, 0.5, 0.0], [4]),
                           Site([0.5, 0.0, 0.5], [4]),
                           Site([0.0, 0.5, 0.5], [4])])
            expected = [4, 15, 48, 301]   # n = 1..4
            for n in 1:4
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:5])
                e = enumerate(p, sites; supercells = VolumeRange(n:n),
                              concentration = cr, partition_threshold = 1_000_000,
                              skip_resource_check = true)
                @test length(e) == expected[n]
            end
        end

        # Zinc-blende — every sublattice active with disjoint labels.
        @testset "zinc-blende" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0, 0.0, 0.0],
                               [0.25, 0.25, 0.25]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([0.25, 0.25, 0.25], [2, 3])])
            expected = [4, 11, 52, 290]   # n = 1..4
            for n in 1:4
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:4])
                e = enumerate(p, sites; supercells = VolumeRange(n:n),
                              concentration = cr, partition_threshold = 1_000_000,
                              skip_resource_check = true)
                @test length(e) == expected[n]
            end
        end
    end

    # ---- Chunk 6.5c — label-equivalence-aware effective parent ----
    # The Regime-C symmetry input is filtered at `enumerate(...)` entry by
    # sub-setting `parent.space_group` to ops whose dset_perm respects the
    # per-position `allowed_labels` equivalence classes. Regime A and Regime B
    # short-circuit to the original `parent` (object identity); Regime C
    # builds a fresh ParentLattice with the filtered space group.
    @testset "_effective_parent (chunk 6.5c)" begin
        # ---- Regime A fast path: single-lattice → no work, returns parent ----
        @testset "Regime A (single dset) — identity short-circuit" begin
            parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
            @test Enumlib._effective_parent(parent, sites) === parent
        end

        # ---- Regime B fast path: uniform allowed_labels → still identity ----
        @testset "Regime B (uniform sublattices) — identity short-circuit" begin
            a = 1.0; c = sqrt(8/3)
            A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
            parent = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([1/3, 2/3, 1/2], [0, 1])])
            @test Enumlib._effective_parent(parent, sites) === parent
        end

        # ---- Regime C: parent.space_group is filtered when ops swap classes ----
        # Half-Heusler with distinct Y={2}, Z={3}: FCC's 48 ops include ops
        # that swap Y↔Z (e.g., inversion through the unit-cell center). After
        # filtering by the {X, Y, Z} equivalence classes, exactly half survive.
        @testset "Regime C halfHeusler (distinct labels) — 48 → 24" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0, 0.0, 0.0],
                               [0.25, 0.25, 0.25],
                               [0.75, 0.75, 0.75]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([0.25, 0.25, 0.25], [2]),
                           Site([0.75, 0.75, 0.75], [3])])
            @test length(p.space_group) == 48          # user's parent untouched
            peff = Enumlib._effective_parent(p, sites)
            @test peff !== p                            # not the same object
            @test length(peff.space_group) == 24
            @test length(p.space_group) == 48          # still untouched after the call
        end

        # ---- Wurtzite: uniform-types Spacey gives 24, label-aware filter gives 12 (P6₃mc) ----
        @testset "Regime C wurtzite — 24 → 12" begin
            A = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
            ds = [[0.0, 0.0, 0.0], [1.0/3, 2.0/3, 0.5],
                  [0.0, 0.0, 0.375], [1.0/3, 2.0/3, 0.875]]
            p = ParentLattice(A, ds)
            sites = Sites([Site(ds[1], [0, 1]),
                           Site(ds[2], [0, 1]),
                           Site(ds[3], [2]),
                           Site(ds[4], [2])])
            @test length(p.space_group) == 24
            peff = Enumlib._effective_parent(p, sites)
            @test length(peff.space_group) == 12       # P6₃mc
        end

        # ---- Regime C with all ops already class-preserving: identity short-circuit ----
        # Half-Heusler with Y=Z={2}: X={0,1} is its own equivalence class;
        # Y/Z share the {2} class. The FCC 48-op group has no ops that swap
        # X ↔ Y/Z (X is at the origin, Y/Z at 1/4-positions — different Wyckoff
        # orbits), and the Y↔Z swaps are class-preserving (same {2}). So no
        # ops get filtered — _effective_parent short-circuits and returns the
        # original parent. This is the case our existing chunk 6.5b corpus
        # testset relies on.
        @testset "Regime C halfHeusler (Y=Z={2}) — no-op short-circuit" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0, 0.0, 0.0],
                               [0.25, 0.25, 0.25],
                               [0.75, 0.75, 0.75]])
            sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                           Site([0.25, 0.25, 0.25], [2]),
                           Site([0.75, 0.75, 0.75], [2])])
            @test Enumlib._effective_parent(p, sites) === p
        end
    end

    # ---- Chunk 6.5a — :multinomial_restricted cross-validates :recursive_stabilizer ----
    # The bitmap + site-mask algorithm (HF 2012 §A.1) must produce the same
    # set of canonical labelings as the tree (Morgan 2017) for every Regime-C
    # case. The corpus testset above runs the tree; this set runs the bitmap
    # at the same per-volume / per-concentration breakpoints (where the
    # bitmap fits in memory) and asserts count equality.
    #
    # Note: `:auto` dispatch defaults to :recursive_stabilizer for Regime C
    # because the linear-iteration bitmap algorithm scales by total
    # multinomial space (most slots invalid for sparse masks) rather than by
    # the valid subspace. Users opt into :multinomial_restricted explicitly
    # for dense-mask cases or by passing `algorithm = :multinomial_restricted`.
    # See `src/algorithms/multinomial_restricted.jl` for the design tradeoff.
    @testset ":multinomial_restricted (chunk 6.5a) cross-validates :recursive_stabilizer" begin
        # ---- zinc-blende (dense mask: every sublattice active) ----
        @testset "zinc-blende n=1..3" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0,0.0,0.0], [0.25,0.25,0.25]])
            sites = Sites([Site([0.0,0.0,0.0], [0,1]),
                           Site([0.25,0.25,0.25], [2,3])])
            for n in 1:3
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:4])
                e_mr = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :multinomial_restricted,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                e_rs = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                @test length(e_mr) == length(e_rs)
            end
        end

        # ---- half-Heusler (Y=Z={2}; sparse mask, but bitmap small enough at n≤3) ----
        @testset "half-Heusler (Y=Z={2}) n=1..3" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0,0.0,0.0], [0.25,0.25,0.25], [0.75,0.75,0.75]])
            sites = Sites([Site([0.0,0.0,0.0], [0,1]),
                           Site([0.25,0.25,0.25], [2]),
                           Site([0.75,0.75,0.75], [2])])
            for n in 1:3
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:3])
                e_mr = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :multinomial_restricted,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                e_rs = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                @test length(e_mr) == length(e_rs)
            end
        end

        # ---- perovskite n=1..2 (both A and B active, three inactive O sites) ----
        @testset "perovskite n=1..2" begin
            p = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],
                              [[0.0,0.0,0.0], [0.5,0.5,0.5],
                               [0.5,0.5,0.0], [0.5,0.0,0.5], [0.0,0.5,0.5]])
            sites = Sites([Site([0.0,0.0,0.0], [0,1]),
                           Site([0.5,0.5,0.5], [2,3]),
                           Site([0.5,0.5,0.0], [4]),
                           Site([0.5,0.0,0.5], [4]),
                           Site([0.0,0.5,0.5], [4])])
            for n in 1:2
                cr = ConcentrationRange([(0//1, 1//1) for _ in 1:5])
                e_mr = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :multinomial_restricted,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                e_rs = enumerate(p, sites; supercells = VolumeRange(n:n),
                                 concentration = cr,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true)
                @test length(e_mr) == length(e_rs)
            end
        end

        # ---- :multinomial_restricted rejected on Regime A and Regime B ----
        @testset "rejected on Regime A / Regime B" begin
            # Regime A (single dset, FCC binary).
            p_A = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
            sites_A = Sites([Site([0.0,0.0,0.0], [0,1])])
            c_A = concentration_count([2, 2]; n_total = 4)
            @test_throws ArgumentError enumerate(p_A, sites_A;
                supercells = VolumeRange(4:4), concentration = c_A,
                algorithm = :multinomial_restricted)

            # Regime B (HCP binary with uniform allowed_labels).
            a = 1.0; c = sqrt(8/3)
            A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
            p_B = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
            sites_B = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                             Site([1/3, 2/3, 1/2], [0, 1])])
            c_B = concentration_count([2, 2]; n_total = 4)
            @test_throws ArgumentError enumerate(p_B, sites_B;
                supercells = VolumeRange(2:2), concentration = c_B,
                algorithm = :multinomial_restricted)
        end

        # ---- :multinomial_restricted still requires a concentration ----
        @testset "requires concentration" begin
            p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                              [[0.0,0.0,0.0], [0.25,0.25,0.25]])
            sites = Sites([Site([0.0,0.0,0.0], [0,1]),
                           Site([0.25,0.25,0.25], [2,3])])
            @test_throws ArgumentError enumerate(p, sites;
                supercells = VolumeRange(2:2),
                algorithm = :multinomial_restricted)
        end
    end

    # ---- Multilattice — dset/Sites length mismatch ----
    @testset "enumerate — multilattice with Sites length ≠ ndset errors" begin
        a = 1.0; c = sqrt(8/3)
        A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
        parent = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        # ndset = 2 but Sites has only 1 entry.
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
    end

    # ---- Single-site parent + multi-site Sites: regime A confused ----
    @testset "enumerate — multi-site Sites on single-site parent errors" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.5, 0.5, 0.5], [0, 1])])
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
    end

    # ---- Sites validation — non-zero-indexed labels error with chunk-6 message ----
    @testset "enumerate — sparse allowed_labels errors" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        # Allowed labels {3, 5} — sparse / non-zero-indexed.
        sites = Sites([Site([0.0, 0.0, 0.0], BitSet([3, 5]))])
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
    end

    # ---- Inactive single site errors with informative message ----
    @testset "enumerate — inactive single site errors" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        sites = Sites([Site([0.0, 0.0, 0.0], [0])])  # only one allowed label → inactive
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
    end

    # ---- Empty enumeration on RadiusBound returning no HNFs ----
    @testset "enumerate — empty result when supercells resolve to nothing" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # RadiusBound below the parent's own radius — yields no HNFs.
        e = enumerate(parent, sites; supercells = RadiusBound(max_radius_ratio = 0.5,
                                                              max_volume = 5))
        @test length(e) == 0
        @test isempty(e.supercells)
    end

    # ---- Cleanup verification — deleted types are unreachable ----
    @testset "Cleanup — SuperTile / ColoredTile / coloringsOfHNFList unreachable" begin
        @test !isdefined(Enumlib, :SuperTile)
        @test !isdefined(Enumlib, :ColoredTile)
        @test !isdefined(Enumlib, :coloringsOfHNFList)
    end

    # ---- default_memory_budget ----
    @testset "default_memory_budget returns sensible value" begin
        b = default_memory_budget()
        @test b isa Int
        @test b >= 2 * 2^30   # 2 GiB floor
        # Should not exceed system memory — sanity bound.
        @test b <= Int(Sys.total_memory())
    end

    # ---- include_superperiodic kwarg (chunk 6.2) ----
    # Default `false` (existing behavior throughout chunks 5–6) returns
    # primitive (aperiodic) structures — the across-volume-sweep contract.
    # `true` returns the full Burnside orbit space. See research.md §5.2.1.
    @testset "include_superperiodic on synthetic cyclic n=4 binary" begin
        # 4-element cyclic group — pG[1] is identity; pG[2..4] are the three
        # non-identity translations. Hand-verifiable via Möbius / Burnside:
        # aperiodic = (1/4)(2^4 − 2^2) = 3; full Burnside = (1/4)(2^4+2^2+2^1+2^2) = 6.
        pg = [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]
        @test length(Enumlib.getUniqueColorings(2, pg)) == 3
        @test length(Enumlib.getUniqueColorings(2, pg; include_superperiodic = false)) == 3
        @test length(Enumlib.getUniqueColorings(2, pg; include_superperiodic = true)) == 6
    end

    @testset "include_superperiodic on FCC binary unrestricted (locked counts)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # Default and explicit `=false` agree with the chunk-5 reference.
        @test length(enumerate(parent, sites; supercells = VolumeRange(4:4))) == 19
        @test length(enumerate(parent, sites; supercells = VolumeRange(4:4),
                                              include_superperiodic = false)) == 19

        # Locked `=true` reference values, captured at chunk-6.2 implementation.
        @test length(enumerate(parent, sites; supercells = VolumeRange(4:4),
                                              include_superperiodic = true)) == 41
        @test length(enumerate(parent, sites; supercells = VolumeRange(8:8),
                                              include_superperiodic = true)) == 544
        @test length(enumerate(parent, sites; supercells = VolumeRange(12:12),
                                              include_superperiodic = true)) == 7885

        # `=true` ≥ `=false` (full orbit count includes super-periodic).
        for n in [4, 8, 12]
            aper = length(enumerate(parent, sites; supercells = VolumeRange(n:n)))
            full = length(enumerate(parent, sites; supercells = VolumeRange(n:n),
                                                   include_superperiodic = true))
            @test full >= aper
        end
    end

    @testset "include_superperiodic default matches missing kwarg" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e_default = enumerate(parent, sites; supercells = VolumeRange(4:4))
        e_explicit = enumerate(parent, sites; supercells = VolumeRange(4:4),
                                              include_superperiodic = false)
        @test length(e_default) == length(e_explicit)
        # Same coloring multiset (identical Enumeration content).
        @test sort(to_labeling.(e_default)) == sort(to_labeling.(e_explicit))
    end

    # ---- R33: orbit_size field ----
    # The orbit_size on each EnumeratedStructure is the symmetry-orbit size of the
    # labeling under the supercell's permutation group: |orbit(c)| = |G| / |Stab(c)|.
    # Aggregate identity (when include_superperiodic = true): the orbit sizes
    # within a single supercell sum to k^n (unrestricted) or multinomial(n; mults)
    # (fixed concentration) — every labeling lives in exactly one orbit.
    @testset "orbit_size field (R33)" begin
        A_fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
        parent_fcc = ParentLattice(A_fcc)
        sites_fcc = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        A_bcc = 0.5 * [-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0]
        parent_bcc = ParentLattice(A_bcc)
        sites_bcc = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # Helper: group structures by supercell_id, sum orbit_sizes per supercell.
        function _orbit_sum_per_supercell(e)
            sums = Dict{Int, Int}()
            for s in e
                sums[s.supercell_id] = get(sums, s.supercell_id, 0) + s.orbit_size
            end
            return sums
        end

        # 1. Smallest sanity: FCC binary n=2 unrestricted → 2^2 = 4 per HNF.
        @testset "FCC binary n=2 unrestricted: sum per HNF = 2^n = 4" begin
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(2:2),
                          include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test !isempty(sums)
            for (_, total) in sums
                @test total == 4
            end
        end

        # 2. Default-policy canonical: FCC binary n=4 → 2^4 = 16 per HNF.
        @testset "FCC binary n=4 unrestricted: sum per HNF = 2^n = 16" begin
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(4:4),
                          include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test length(sums) == 7   # 7 inequivalent HNFs at FCC n=4
            for (_, total) in sums
                @test total == 16
            end
        end

        # 3. Larger volume: FCC binary n=8 unrestricted → 2^8 = 256 per HNF.
        @testset "FCC binary n=8 unrestricted: sum per HNF = 2^n = 256" begin
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(8:8),
                          include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test !isempty(sums)
            for (_, total) in sums
                @test total == 256
            end
        end

        # 4. Different parent lattice: BCC binary n=4 → 16 per HNF.
        @testset "BCC binary n=4 unrestricted: sum per HNF = 2^n = 16" begin
            e = enumerate(parent_bcc, sites_bcc; supercells = VolumeRange(4:4),
                          include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test !isempty(sums)
            for (_, total) in sums
                @test total == 16
            end
        end

        # 5. Fixed-concentration small: FCC binary 2:2 at n=4 → multinomial = 6 per HNF.
        @testset "FCC binary 2:2 at n=4: sum per HNF = multinomial = 6" begin
            c = concentration_count([2, 2]; n_total = 4)
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(4:4),
                          concentration = c, include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test !isempty(sums)
            for (_, total) in sums
                @test total == 6   # multinomial_count([2,2]) = 6
            end
        end

        # 6. Fixed-concentration medium: FCC binary 4:4 at n=8 → multinomial = 70 per HNF.
        @testset "FCC binary 4:4 at n=8: sum per HNF = multinomial = 70" begin
            c = concentration_count([4, 4]; n_total = 8)
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(8:8),
                          concentration = c, include_superperiodic = true)
            sums = _orbit_sum_per_supercell(e)
            @test !isempty(sums)
            for (_, total) in sums
                @test total == 70   # multinomial_count([4,4]) = 70
            end
        end

        # 7. Per-structure divisibility: every orbit_size divides |perm_group|
        #    (orbit-stabilizer theorem corollary).
        @testset "per-structure divisibility |orbit| | |G|" begin
            e = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(4:4),
                          include_superperiodic = true)
            for s in e
                sc = e.supercells[s.supercell_id]
                G_size = length(sc.permutation_group)
                @test s.orbit_size >= 1
                @test G_size % s.orbit_size == 0
            end
        end

        # 8. Cross-algorithm consistency: :multinomial and :recursive_stabilizer
        #    produce the same orbit-size multiset for the same (parent, sites, conc).
        @testset "cross-algorithm orbit-size consistency (FCC 4:4 n=8)" begin
            c = concentration_count([4, 4]; n_total = 8)
            e_mult = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(8:8),
                               concentration = c, algorithm = :multinomial)
            e_tree = enumerate(parent_fcc, sites_fcc; supercells = VolumeRange(8:8),
                               concentration = c, algorithm = :recursive_stabilizer)
            @test length(e_mult) == length(e_tree)
            @test sort([s.orbit_size for s in e_mult]) ==
                  sort([s.orbit_size for s in e_tree])
        end
    end

end
