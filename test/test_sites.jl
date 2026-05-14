using Test
using Enumlib

@testset "Site and Sites (chunk 2)" begin

    # ---- Site validation ----
    @testset "Site validation" begin
        # Wrong position length
        @test_throws ArgumentError Site{3}([0.0, 0.0], BitSet([0, 1]))
        # Empty allowed_labels
        @test_throws ArgumentError Site{3}([0.0, 0.0, 0.0], BitSet())
        # BitSet form constructs cleanly
        s = Site([0.0, 0.0, 0.0], BitSet([0, 1]))
        @test s.position == [0.0, 0.0, 0.0]
        @test s.allowed_labels == BitSet([0, 1])
        # Vector convenience form converts to BitSet
        s2 = Site([0.5, 0.5, 0.5], [0, 1])
        @test s2.allowed_labels == BitSet([0, 1])
        # Range form (e.g., 0:2) also accepted via the Vector overload
        s3 = Site([0.0, 0.0, 0.0], 0:2)
        @test s3.allowed_labels == BitSet([0, 1, 2])
    end

    # ---- is_active / is_inactive ----
    @testset "is_active and is_inactive" begin
        active = Site([0.0, 0.0, 0.0], BitSet([0, 1]))
        @test is_active(active)
        @test !is_inactive(active)
        inactive = Site([0.5, 0.5, 0.5], BitSet([2]))
        @test is_inactive(inactive)
        @test !is_active(inactive)
    end

    # ---- Site equality and hashing (pairing rule) ----
    @testset "Site equality and hashing" begin
        a = Site([0.0, 0.0, 0.0], BitSet([0, 1]))
        b = Site([0.0, 0.0, 0.0], BitSet([0, 1]))
        c = Site([0.5, 0.5, 0.5], BitSet([0, 1]))
        @test a == b
        @test a != c
        @test hash(a) == hash(b)
        # Can be used in a Set (depends on the pairing rule)
        @test length(Set([a, b, c])) == 2
    end

    # ---- Sites incremental construction ----
    @testset "Sites incremental construction" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0], [0, 1]),
            Site([0.5, 0.5, 0.5], [0, 1]),
            Site([0.5, 0.5, 0.0], [2]),  # inactive
        ])
        @test length(sites.list) == 3
        @test n_active(sites) == 2
        @test n_canonical(sites) == 3   # no equivalencies declared yet
        @test n_effective(sites) == 2   # 2 active, all canonical
    end

    # ---- Sites upfront-partition construction ----
    @testset "Sites upfront-partition construction" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0], [0, 1]),
            Site([0.5, 0.0, 0.0], [0, 1]),
            Site([0.0, 0.5, 0.0], [0, 1]),
            Site([0.0, 0.0, 0.5], [0, 1]),
        ], [[1, 2], [3, 4]])
        @test n_active(sites) == 4
        @test n_canonical(sites) == 2
        @test n_effective(sites) == 2
        # Sites within a class share their canonical root
        @test canonical(sites, 1) == canonical(sites, 2)
        @test canonical(sites, 3) == canonical(sites, 4)
        # Sites across classes have different roots
        @test canonical(sites, 1) != canonical(sites, 3)
    end

    # ---- Sites upfront-partition validation ----
    @testset "Sites upfront-partition validation" begin
        site_list = [Site([0.0, 0.0, 0.0], [0, 1]),
                     Site([0.5, 0.5, 0.5], [0, 1]),
                     Site([0.5, 0.0, 0.0], [0, 1])]
        # Overlapping classes (site 2 in both)
        @test_throws ArgumentError Sites(site_list, [[1, 2], [2, 3]])
        # Out-of-range index
        @test_throws ArgumentError Sites(site_list, [[1, 4]])
        # Empty class
        @test_throws ArgumentError Sites(site_list, [Int[]])
    end

    # ---- equate! idempotence and transitivity ----
    @testset "equate! idempotence and transitivity" begin
        sites = Sites([Site([k/4, 0.0, 0.0], [0, 1]) for k in 0:3])
        equate!(sites, 1, 2)
        equate!(sites, 2, 3)
        # Transitivity: 1 and 3 share a class even though we never explicitly equated them.
        @test canonical(sites, 1) == canonical(sites, 3)
        # Site 4 is still on its own.
        @test canonical(sites, 1) != canonical(sites, 4)
        # Idempotence: equating already-equated sites is a no-op.
        equate!(sites, 1, 2)
        @test n_canonical(sites) == 2
        # Self-equate (i == j) is a no-op.
        equate!(sites, 1, 1)
        @test n_canonical(sites) == 2
    end

    # ---- equate! return value (chainability) ----
    @testset "equate! return value is sites itself" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.5, 0.5, 0.5], [0, 1])])
        result = equate!(sites, 1, 2)
        @test result === sites   # identity, not just structural equality
    end

    # ---- equate! out-of-range ----
    @testset "equate! out-of-range" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([0.5, 0.5, 0.5], [0, 1])])
        @test_throws ArgumentError equate!(sites, 0, 1)
        @test_throws ArgumentError equate!(sites, 1, 3)
    end

    # ---- Pattern A: perovskite ABO_3 (inactive sites) ----
    @testset "Perovskite ABO_3 — A and B substitutional, oxygens inactive" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0], [0, 1]),  # A: substitutional
            Site([0.5, 0.5, 0.5], [0, 1]),  # B: substitutional
            Site([0.5, 0.5, 0.0], [2]),     # O: inactive
            Site([0.5, 0.0, 0.5], [2]),     # O: inactive
            Site([0.0, 0.5, 0.5], [2]),     # O: inactive
        ])
        @test n_active(sites) == 2
        @test n_canonical(sites) == 5   # no equivalencies declared
        @test n_effective(sites) == 2   # only A and B contribute to the labeling space
        active = active_canonical_sites(sites)
        @test length(active) == 2
        @test [i for (i, _) in active] == [1, 2]
    end

    # ---- Pattern B: slab with mirror equivalencies ----
    @testset "Slab geometry — mirror-image layer equivalencies" begin
        N = 4
        layer_positions = [[0.0, 0.0, k/N] for k in 0:N-1]
        sites = Sites([Site(p, [0, 1]) for p in layer_positions])
        # Pair mirror-image layers: (1,4) and (2,3).
        for i in 1:N÷2
            equate!(sites, i, N - i + 1)
        end
        @test n_active(sites) == 4
        @test n_canonical(sites) == 2
        @test n_effective(sites) == 2
    end

    # ---- Mixed construction (upfront + incremental) ----
    @testset "Mixed construction: upfront then equate! later" begin
        sites = Sites([Site([k/4, 0.0, 0.0], [0, 1]) for k in 0:3], [[1, 2]])
        # Upfront: only 1 ↔ 2.
        @test n_canonical(sites) == 3
        # Add 3 ↔ 4 incrementally.
        equate!(sites, 3, 4)
        @test n_canonical(sites) == 2
        @test canonical(sites, 1) == canonical(sites, 2)
        @test canonical(sites, 3) == canonical(sites, 4)
    end

    # ---- Single-site Sites: size-1 boundary invariants ----
    # Pins down "did you accidentally write code that assumes ≥ 2 sites?" — a real
    # failure mode that wouldn't show up in the perovskite/slab tests.
    @testset "Single-site Sites — size-1 boundary" begin
        # Active single site
        sites_active = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test n_active(sites_active) == 1
        @test n_canonical(sites_active) == 1
        @test n_effective(sites_active) == 1
        @test length(active_canonical_sites(sites_active)) == 1
        # Inactive single site
        sites_inactive = Sites([Site([0.0, 0.0, 0.0], [0])])
        @test n_active(sites_inactive) == 0
        @test n_canonical(sites_inactive) == 1
        @test n_effective(sites_inactive) == 0
        @test isempty(active_canonical_sites(sites_inactive))
        # equate!(s, 1, 1) is a no-op even on a singleton
        equate!(sites_active, 1, 1)
        @test n_canonical(sites_active) == 1
        # Show doesn't crash on the size-1 case
        @test sprint(show, sites_active) isa String
        @test sprint(show, sites_inactive) isa String
    end

    # ---- All-equivalent Sites: limit case for slab uniformity ----
    @testset "All-equivalent Sites — uniform substitution limit" begin
        sites = Sites([Site([0.0, 0.0, k/4], [0, 1]) for k in 0:3])
        # Equate everyone into one class.
        for i in 2:4
            equate!(sites, 1, i)
        end
        @test n_active(sites) == 4
        @test n_canonical(sites) == 1
        @test n_effective(sites) == 1
        active = active_canonical_sites(sites)
        @test length(active) == 1
    end

    # ---- Empty list rejected ----
    @testset "Sites empty list rejected" begin
        @test_throws ArgumentError Sites(Site{3}[])
    end

    # ---- Sites does not validate against a parent (chunk 2 design item 1, locked: A) ----
    # Anything that looks like a fractional coordinate is accepted; cross-validation
    # against a specific ParentLattice happens at the enumerate(...) boundary.
    @testset "Sites does not validate positions against a parent" begin
        # A position that's geometrically nonsense for a unit-cube lattice (e.g.,
        # 17.0) is accepted at construction. The job of catching this lives upstream.
        @test_nowarn Sites([Site([17.0, -3.0, 99.5], [0, 1])])
    end

    # ---- R51 convenience constructors from a ParentLattice ----
    @testset "Sites(parent, ...) convenience constructors (R51)" begin
        p_sc  = ParentLattice([1.0 0 0; 0 1 0; 0 0 1])                        # single-site Bravais
        A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
        p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])      # two-site multilattice

        # --- Uniform forms: integer vector, BitSet, range ---
        @testset "uniform — integer vector / BitSet / range agree" begin
            s_v   = Sites(p_sc, [0, 1])
            s_bs  = Sites(p_sc, BitSet([0, 1]))
            s_rng = Sites(p_sc, 0:1)
            for s in (s_v, s_bs, s_rng)
                @test s isa Sites{3}
                @test length(s.list) == 1
                @test s.list[1].allowed_labels == BitSet([0, 1])
                @test is_active(s.list[1])
                @test n_active(s) == 1
                @test n_canonical(s) == 1
                @test n_effective(s) == 1
            end
        end

        # --- k-species kwarg shorthand ---
        @testset "Sites(parent; k=N) shorthand" begin
            s2 = Sites(p_sc; k = 2)
            @test s2.list[1].allowed_labels == BitSet([0, 1])

            s3 = Sites(p_sc; k = 3)
            @test s3.list[1].allowed_labels == BitSet([0, 1, 2])
            @test is_active(s3.list[1])

            # Invalid k: empty allowed_labels rejected at the Site layer.
            @test_throws ArgumentError Sites(p_sc; k = 0)
            @test_throws ArgumentError Sites(p_sc; k = -1)
        end

        # --- Multi-site parent: uniform applies to every dset position ---
        @testset "uniform on HCP multilattice" begin
            sites = Sites(p_hcp, [0, 1])
            @test length(sites.list) == 2
            @test all(s -> s.allowed_labels == BitSet([0, 1]), sites.list)
            @test all(is_active, sites.list)
            @test n_active(sites) == 2
            @test n_canonical(sites) == 2   # each dset position in its own class
            @test n_effective(sites) == 2

            # Kwarg form agrees with the explicit uniform call (compare via .list —
            # Sites itself has no Base.:(==) since the Union-Find state would need
            # equivalence-class-aware comparison).
            @test sites.list == Sites(p_hcp; k = 2).list
        end

        # --- Per-position form: Vector{Vector{Int}} and Vector{BitSet} both work ---
        @testset "per-position on HCP multilattice" begin
            sites = Sites(p_hcp, [[0, 1, 2], [0]])
            @test length(sites.list) == 2
            @test sites.list[1].allowed_labels == BitSet([0, 1, 2])
            @test sites.list[2].allowed_labels == BitSet([0])
            @test is_active(sites.list[1])
            @test is_inactive(sites.list[2])
            @test n_active(sites) == 1
            @test n_canonical(sites) == 2

            # BitSet entries land in the same per-position dispatch path.
            sites_bs = Sites(p_hcp, [BitSet([0, 1, 2]), BitSet([0])])
            @test sites.list == sites_bs.list
        end

        # --- Per-position length must match ndset(parent) ---
        @testset "per-position length-mismatch ArgumentError" begin
            @test_throws ArgumentError Sites(p_hcp, [[0, 1]])           # 1 vs 2
            @test_throws ArgumentError Sites(p_hcp, [[0, 1], [0], [1]]) # 3 vs 2
        end

        # --- Single-site parent: per-position with one entry is fine ---
        @testset "per-position on single-site parent" begin
            sites = Sites(p_sc, [[0, 1]])      # length matches ndset(p_sc) = 1
            @test length(sites.list) == 1
            @test sites.list[1].allowed_labels == BitSet([0, 1])
            # Semantically the same as the uniform form on a single-site parent.
            @test sites.list == Sites(p_sc, [0, 1]).list
        end
    end

end
