using Test
using Enumlib
using Enumlib: getSymInequivHNFs    # un-exported in chunk 13b.1; tests still need it

@testset "Enumeration + enumerate (chunk 5)" begin

    # ---- EnumeratedStructure construction + validation ----
    @testset "EnumeratedStructure validation" begin
        # Valid construction with explicit fields
        s = EnumeratedStructure{3, Vector{Int8}}(1, Int8[0, 1, 0, 1], 1, 1)
        @test s.supercell_id == 1
        @test s.labeling == Int8[0, 1, 0, 1]
        @test s.hnf_degeneracy == 1
        @test s.labeling_degeneracy == 1

        # Defaults for the two degeneracy fields.
        s2 = EnumeratedStructure{3, Vector{Int8}}(2, Int8[0, 0])
        @test s2.hnf_degeneracy == 1
        @test s2.labeling_degeneracy == 1

        # Validation
        @test_throws ArgumentError EnumeratedStructure{3, Vector{Int8}}(0, Int8[0])      # supercell_id < 1
        @test_throws ArgumentError EnumeratedStructure{3, Vector{Int8}}(1, Int8[0], 0)   # hnf_degeneracy < 1
        @test_throws ArgumentError EnumeratedStructure{3, Vector{Int8}}(1, Int8[0], 1, 0)  # labeling_degeneracy < 1
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

    # ---- Multilattice — graceful error ----
    @testset "enumerate — multilattice errors with v0.3 message" begin
        # HCP — 2-element dset.
        a = 1.0; c = sqrt(8/3)
        A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
        parent = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                       Site([1/3, 2/3, 1/2], [0, 1])])
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(2:2))
    end

    # ---- Sites validation — multi-site Sites errors with chunk-6 message ----
    @testset "enumerate — multi-site Sites errors" begin
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
