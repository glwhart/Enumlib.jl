using Test
using Enumlib

@testset "Concentration + multinomial enumeration (chunk 6)" begin

    # ---- Concentration construction & validation ----
    @testset "Concentration validation" begin
        # Canonical form
        c = Concentration([1//2, 1//2])
        @test c.fractions == [1//2, 1//2]
        @test n_species(c) == 2

        # Single-species rejected
        @test_throws ArgumentError Concentration([1//1])

        # Negative fraction
        @test_throws ArgumentError Concentration([-1//2, 3//2])

        # Doesn't sum to 1
        @test_throws ArgumentError Concentration([1//4, 1//4])

        # 1//3 + 1//3 + 1//3 sums exactly to 1//1 in Rational arithmetic — no float
        # rounding issues. Should construct cleanly.
        c3 = Concentration([1//3, 1//3, 1//3])
        @test sum(c3.fractions) == 1//1
    end

    @testset "Concentration_ratio" begin
        c = Concentration_ratio([15, 17])
        @test c.fractions == [15//32, 17//32]

        c2 = Concentration_ratio([1, 1, 2])
        @test c2.fractions == [1//4, 1//4, 1//2]

        # Negative ratio rejected
        @test_throws ArgumentError Concentration_ratio([-1, 2])
        # All-zero rejected
        @test_throws ArgumentError Concentration_ratio([0, 0])
    end

    @testset "Concentration_count" begin
        c = Concentration_count([15, 17]; n_total = 32)
        @test c.fractions == [15//32, 17//32]

        # Mismatched n_total
        @test_throws ArgumentError Concentration_count([15, 17]; n_total = 30)

        # Non-positive n_total
        @test_throws ArgumentError Concentration_count([1, 1]; n_total = 0)
    end

    @testset "multiplicities resolves cleanly or throws" begin
        c = Concentration_ratio([15, 17])
        @test multiplicities(c, 32) == [15, 17]
        @test multiplicities(c, 64) == [30, 34]

        # Doesn't divide cleanly
        c_third = Concentration([1//3, 2//3])
        @test_throws EmptyEnumerationError multiplicities(c_third, 4)
    end

    # ---- ConcentrationRange ----
    @testset "ConcentrationRange validation" begin
        # Valid
        cr = ConcentrationRange([(0//1, 1//2), (1//2, 1//1)])
        @test n_species(cr) == 2

        # min > max
        @test_throws ArgumentError ConcentrationRange([(1//2, 1//4), (0//1, 1//1)])

        # No feasible — sum-of-lows > 1
        @test_throws ArgumentError ConcentrationRange([(3//4, 1//1), (3//4, 1//1)])
    end

    @testset "concentrations_in_range counts" begin
        # Binary at n=4 with full range: a=0..4, so 5 multiplicity vectors.
        cr = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])
        crs = concentrations_in_range(cr, 4)
        @test length(crs) == 5

        # Binary at n=10 with bounds (0, 1) per species: 11 multiplicity vectors.
        @test length(concentrations_in_range(cr, 10)) == 11

        # Ternary at n=20 wide bounds: 231 (per chunk-6 review table).
        cr_tern = ConcentrationRange([(0//1, 1//1), (0//1, 1//1), (0//1, 1//1)])
        @test length(concentrations_in_range(cr_tern, 20)) == 231
    end

    # ---- multinomial_count, hash, unhash ----
    @testset "multinomial_count returns BigInt with correct values" begin
        @test multinomial_count([2, 2]) == 6
        @test multinomial_count([15, 17]) == BigInt(565722720)
        # Overflow case — Int64 would die at this size, BigInt handles it.
        n = 70
        c_big = multinomial_count([35, 35])
        @test c_big > BigInt(typemax(Int))
    end

    @testset "multinomial_hash bijection round-trip" begin
        # multinomial(4; 2, 2) = 6
        for idx in 0:5
            c = Enumlib.multinomial_unhash(idx, [2, 2])
            @test Enumlib.multinomial_hash(c, [2, 2]) == idx
        end

        # Larger: multinomial(6; 3, 2, 1) = 60
        for idx in 0:59
            c = Enumlib.multinomial_unhash(idx, [3, 2, 1])
            @test Enumlib.multinomial_hash(c, [3, 2, 1]) == idx
        end
    end

    @testset "multinomial_hash range and consistency" begin
        # All hash values should fall in [0, C-1] and be distinct.
        mults = [3, 3]
        C = Int(multinomial_count(mults))
        seen = Set{Int}()
        for idx in 0:C-1
            c = Enumlib.multinomial_unhash(idx, mults)
            h = Enumlib.multinomial_hash(c, mults)
            @test 0 <= h < C
            push!(seen, h)
        end
        @test length(seen) == C
    end

    # ---- enumerate(...) at fixed concentration: locked reference counts ----
    @testset "FCC binary at fixed concentration — locked counts" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # n=4 50% (2:2): 5 structures
        e = enumerate(parent, sites; supercells = VolumeRange(4:4),
                                       concentration = Concentration_count([2, 2]; n_total = 4))
        @test length(e) == 5

        # n=8 50% (4:4): 94
        e = enumerate(parent, sites; supercells = VolumeRange(8:8),
                                       concentration = Concentration_count([4, 4]; n_total = 8))
        @test length(e) == 94

        # n=8 3:5: 86
        e = enumerate(parent, sites; supercells = VolumeRange(8:8),
                                       concentration = Concentration_count([3, 5]; n_total = 8))
        @test length(e) == 86

        # n=12 50% (6:6): 1552
        e = enumerate(parent, sites; supercells = VolumeRange(12:12),
                                       concentration = Concentration_count([6, 6]; n_total = 12))
        @test length(e) == 1552
    end

    # ---- The identity test: sum of per-concentration enumerations == unrestricted ----
    # This is the load-bearing correctness check — proves the multinomial port
    # over the entire chunk-5 FCC corpus without needing to run the slow
    # Ag-Pt 32-cell test (5.7×10⁸ candidates).
    @testset "FCC binary identity: sum per concentration == unrestricted" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        for n in [4, 8, 12]
            unrestricted = length(enumerate(parent, sites; supercells = VolumeRange(n:n)))
            total_per_c = 0
            for a in 1:n-1   # exclude monochromatic (super-periodic for n ≥ 2)
                c = Concentration_count([a, n-a]; n_total = n)
                ce = enumerate(parent, sites; supercells = VolumeRange(n:n), concentration = c)
                total_per_c += length(ce)
            end
            @test total_per_c == unrestricted
        end
    end

    @testset "FCC ternary identity at n=4 (locked: 96)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1, 2])])
        unrestricted = length(enumerate(parent, sites; supercells = VolumeRange(4:4)))
        @test unrestricted == 96
        total = 0
        for a in 0:4, b in 0:4-a
            c = 4 - a - b
            (a == 4 || b == 4 || c == 4) && continue
            conc = Concentration_count([a, b, c]; n_total = 4)
            ce = enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = conc)
            total += length(ce)
        end
        @test total == 96
    end

    # ---- Dispatcher integration ----
    @testset ":auto picks :exhaustive without concentration, :multinomial with" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # No concentration → :auto routes to :exhaustive
        e_auto = enumerate(parent, sites; supercells = VolumeRange(4:4))
        e_exhaustive = enumerate(parent, sites; supercells = VolumeRange(4:4), algorithm = :exhaustive)
        @test length(e_auto) == length(e_exhaustive)

        # With concentration → :auto routes to :multinomial
        c = Concentration_count([2, 2]; n_total = 4)
        e_auto_c = enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = c)
        e_mult = enumerate(parent, sites; supercells = VolumeRange(4:4),
                                            concentration = c, algorithm = :multinomial)
        @test length(e_auto_c) == length(e_mult)
    end

    @testset ":multinomial without concentration errors" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws ArgumentError enumerate(parent, sites; supercells = VolumeRange(4:4),
                                              algorithm = :multinomial)
    end

    # ---- ConcentrationRange dispatch ----
    @testset "ConcentrationRange loops over partitions" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # Range covering all binary multiplicities at n=4: should equal unrestricted minus monochromatic.
        cr = ConcentrationRange([(1//4, 3//4), (1//4, 3//4)])  # excludes a=0 and a=4
        e = enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = cr)
        # Per-concentration: a=1 (1:3), a=2 (2:2), a=3 (3:1) = three Concentrations.
        # Each gives some count; sum should match the unrestricted minus monochromatic.
        unrestricted = length(enumerate(parent, sites; supercells = VolumeRange(4:4)))
        @test length(e) == unrestricted   # all 19, since monochromatic dropped already
    end

    # ---- Partition-explosion gate ----
    @testset "Partition gate errors when partition_threshold exceeded" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        cr = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])
        # At n=4, this decomposes into 5 partitions — well below default 100.
        @test_nowarn enumerate(parent, sites; supercells = VolumeRange(4:4), concentration = cr)

        # With a tight threshold, it errors.
        @test_throws PartitionExplosionError enumerate(parent, sites;
            supercells = VolumeRange(4:4), concentration = cr, partition_threshold = 4)
    end

    @testset "Partition gate :ignore allows pass-through" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        cr = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])
        # 5 partitions at n=4, threshold 2, but :ignore lets it through.
        @test_nowarn enumerate(parent, sites; supercells = VolumeRange(4:4),
                                                concentration = cr,
                                                partition_threshold = 2,
                                                on_partition_overflow = :ignore)
    end

    # ---- include_superperiodic at fixed concentration (chunk 6.2) ----
    # At asymmetric concentrations (3:5 in n=8), super-periodic structures are
    # number-theoretically empty: no period d|n with d<n admits a 3:5 split
    # (3 and 5 share no nontrivial factor with 8). So the kwarg is a no-op —
    # `=true` and `=false` must give the same count. Trip-wire for §5.2.1.
    @testset "include_superperiodic at asymmetric concentration is a no-op (trip-wire)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        c = Concentration_count([3, 5]; n_total = 8)
        e_aper = enumerate(parent, sites; supercells = VolumeRange(8:8), concentration = c)
        e_full = enumerate(parent, sites; supercells = VolumeRange(8:8), concentration = c,
                                          include_superperiodic = true)
        @test length(e_aper) == length(e_full) == 86
    end

    # At symmetric concentrations (2:2 in n=4, 4:4 in n=8, 6:6 in n=12),
    # super-periodic structures exist: e.g., a period-4 4:4 cell tiled into
    # n=8 produces a 4:4 super-periodic structure at n=8. `=true` > `=false`.
    @testset "include_superperiodic at symmetric concentration (locked counts)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # Aperiodic (chunk-6 locked): 5, 94, 1552.
        # Full Burnside captured at chunk-6.2 implementation: 13, 146, 1739.
        for (n, a, b, aper_ref, full_ref) in [(4, 2, 2, 5, 13),
                                              (8, 4, 4, 94, 146),
                                              (12, 6, 6, 1552, 1739)]
            c = Concentration_count([a, b]; n_total = n)
            @test length(enumerate(parent, sites; supercells = VolumeRange(n:n),
                                                  concentration = c)) == aper_ref
            @test length(enumerate(parent, sites; supercells = VolumeRange(n:n),
                                                  concentration = c,
                                                  include_superperiodic = true)) == full_ref
        end
    end

end
