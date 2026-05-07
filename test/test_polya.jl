using Test
using Enumlib

@testset "Polya / count_inequivalent (chunk 7)" begin

    # ---- cycle_structure ----
    @testset "cycle_structure on small permutations" begin
        @test cycle_structure([1, 2, 3, 4, 5]) == [1, 1, 1, 1, 1]
        @test cycle_structure([2, 1, 4, 3, 5]) == [2, 2, 1]
        @test cycle_structure([2, 3, 1]) == [3]
        @test cycle_structure([2, 3, 4, 1]) == [4]
    end

    # ---- polya_count: raw Burnside on tiny groups ----
    @testset "polya_count(group, k) on hand-verified small cases" begin
        # Identity-only on n=3, k=2: every coloring is its own orbit.
        @test polya_count([[1, 2, 3]], 2) == 8

        # Cyclic C_3 on n=3, k=2: Burnside (8 + 2 + 2) / 3 = 4.
        c3 = [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
        @test polya_count(c3, 2) == 4

        # Symmetric S_3 on n=3, k=2: 4 orbits.
        s3 = [[1,2,3], [2,1,3], [3,2,1], [1,3,2], [2,3,1], [3,1,2]]
        @test polya_count(s3, 2) == 4

        # Cyclic C_4 on n=4, k=2: Burnside (16 + 2 + 4 + 2) / 4 = 6.
        c4 = [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]
        @test polya_count(c4, 2) == 6
    end

    @testset "polya_count(group, multiplicities) on hand-verified small cases" begin
        # Cyclic C_3 with multiplicities [1, 2]: 1 orbit (the single binary necklace).
        c3 = [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
        @test polya_count(c3, [1, 2]) == 1

        # Symmetric S_4 on n=4 — full symmetric group has 24 elements.
        # At [2,2]: 1 orbit (any 2-2 coloring is reachable from any other).
        # At [1,3]: 1 orbit. At [4,0]: 1 orbit.
        s4 = collect(values(Dict(p => collect(p) for p in
                ([(p[i] for i in 1:4)...] for p in
                  Iterators.product(1:4, 1:4, 1:4, 1:4)
                  if length(unique(p)) == 4))))
        @test length(s4) == 24
        @test polya_count(s4, [2, 2]) == 1
        @test polya_count(s4, [1, 3]) == 1
        @test polya_count(s4, [4, 0]) == 1
    end

    # ---- Identity test at the Polya layer (sum-over-multiplicities recovers unrestricted) ----
    @testset "sum over multiplicities matches unrestricted (Polya identity)" begin
        c4 = [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]
        s = sum(polya_count(c4, [a, 4 - a]) for a in 0:4)
        @test s == polya_count(c4, 2)
    end

    # ---- aperiodic_orbit_count vs hand-verified Möbius result ----
    @testset "aperiodic_orbit_count on cyclic C_4 binary" begin
        # Möbius: (1/4)(2^4 - 2^2) = 3. Matches chunk 6.2 hand-verified.
        c4 = [[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]
        @test aperiodic_orbit_count(c4, (1, 1, 4), 2) == 3
    end

    # ---- count_inequivalent against locked enumerate(...) reference values ----
    # The strongest cross-validation: every count_inequivalent must match
    # length(enumerate(...)) at the chunk-5/6/6.2 locked references, on both
    # kwarg branches.

    @testset "count_inequivalent on FCC binary unrestricted matches enumerate" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # include_superperiodic = false (chunk 5 reference)
        @test count_inequivalent(parent, sites; supercells = VolumeRange(4:4)) == 19
        @test count_inequivalent(parent, sites; supercells = VolumeRange(8:8)) == 390
        @test count_inequivalent(parent, sites; supercells = VolumeRange(12:12)) == 7140

        # include_superperiodic = true (chunk 6.2 reference)
        @test count_inequivalent(parent, sites; supercells = VolumeRange(4:4),
                                                include_superperiodic = true) == 41
        @test count_inequivalent(parent, sites; supercells = VolumeRange(8:8),
                                                include_superperiodic = true) == 544
        @test count_inequivalent(parent, sites; supercells = VolumeRange(12:12),
                                                include_superperiodic = true) == 7885
    end

    @testset "count_inequivalent on FCC ternary unrestricted at n=4 matches enumerate" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1, 2])])
        @test count_inequivalent(parent, sites; supercells = VolumeRange(4:4)) == 96
    end

    @testset "count_inequivalent at fixed concentration matches enumerate" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # include_superperiodic = false (chunk 6 reference)
        for (n, a, b, ref) in [(4, 2, 2, 5), (8, 4, 4, 94),
                               (8, 3, 5, 86), (12, 6, 6, 1552)]
            c = Concentration_count([a, b]; n_total = n)
            @test count_inequivalent(parent, sites; supercells = VolumeRange(n:n),
                                                    concentration = c) == ref
        end

        # include_superperiodic = true (chunk 6.2 reference)
        for (n, a, b, ref) in [(4, 2, 2, 13), (8, 4, 4, 146),
                               (8, 3, 5, 86), (12, 6, 6, 1739)]
            c = Concentration_count([a, b]; n_total = n)
            @test count_inequivalent(parent, sites; supercells = VolumeRange(n:n),
                                                    concentration = c,
                                                    include_superperiodic = true) == ref
        end
    end

    # ---- Asymmetric-concentration trip-wire (research.md §5.2.1) ----
    # At 15:17 — and any other asymmetric concentration where the
    # multiplicity vector doesn't divide cleanly by any non-trivial
    # divisor of n — super-periodic structures are number-theoretically
    # empty. The two kwarg branches MUST give the same count.
    @testset "asymmetric concentration trip-wire (count side)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        c = Concentration_count([3, 5]; n_total = 8)
        cnt_aper = count_inequivalent(parent, sites; supercells = VolumeRange(8:8), concentration = c)
        cnt_full = count_inequivalent(parent, sites; supercells = VolumeRange(8:8), concentration = c,
                                                     include_superperiodic = true)
        @test cnt_aper == cnt_full == 86

        # Stronger: also at higher n where 15:17 etc. are equally-clean asymmetric.
        # 5:7 in n=12: 5 & 7 share no common factor with 12 except via d=12. Trip-wire.
        c2 = Concentration_count([5, 7]; n_total = 12)
        a2 = count_inequivalent(parent, sites; supercells = VolumeRange(12:12), concentration = c2)
        f2 = count_inequivalent(parent, sites; supercells = VolumeRange(12:12), concentration = c2,
                                               include_superperiodic = true)
        @test a2 == f2
    end

    # ---- include_superperiodic default matches missing kwarg ----
    @testset "default kwarg matches missing kwarg" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        c1 = count_inequivalent(parent, sites; supercells = VolumeRange(4:4))
        c2 = count_inequivalent(parent, sites; supercells = VolumeRange(4:4),
                                               include_superperiodic = false)
        @test c1 == c2
    end

    # ---- InequivalentCount breakdown ----
    @testset "InequivalentCount breakdown sums correctly" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # Single volume, no concentration range.
        ic = count_inequivalent(parent, sites; supercells = VolumeRange(4:4),
                                               breakdown = true)
        @test ic isa InequivalentCount{3}
        @test ic.total == 19
        @test sum(c for (_, c) in ic.by_volume) == ic.total
        @test sum(c for (_, c) in ic.by_hnf) == ic.total
        @test isempty(ic.by_concentration)   # no ConcentrationRange

        # Volume sweep.
        ic_sweep = count_inequivalent(parent, sites; supercells = VolumeRange(2:4),
                                                     breakdown = true)
        @test sum(c for (_, c) in ic_sweep.by_volume) == ic_sweep.total
        @test sum(c for (_, c) in ic_sweep.by_hnf) == ic_sweep.total

        # ConcentrationRange should populate by_concentration.
        cr = ConcentrationRange([(1//4, 3//4), (1//4, 3//4)])  # excludes monochromatic at n=4
        ic_cr = count_inequivalent(parent, sites; supercells = VolumeRange(4:4),
                                                  concentration = cr,
                                                  breakdown = true)
        @test sum(c for (_, c) in ic_cr.by_concentration) == ic_cr.total
    end

    # ---- Polya identity matching enumerate's identity test ----
    # sum over multiplicities should equal unrestricted, on both kwarg branches,
    # at the same FCC sizes that chunk-6 used. This is the count-level analog of
    # chunk 6's enumerate-level identity test.
    @testset "Polya identity: sum over concentrations equals unrestricted (count side)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        for n in [4, 8, 12]
            unrestricted = count_inequivalent(parent, sites; supercells = VolumeRange(n:n))
            total = BigInt(0)
            for a in 1:n-1   # exclude monochromatic (super-periodic at any volume)
                c = Concentration_count([a, n - a]; n_total = n)
                total += count_inequivalent(parent, sites; supercells = VolumeRange(n:n),
                                                            concentration = c)
            end
            @test total == unrestricted
        end
    end

end
