using Test
using Enumlib
using Enumlib: getSymInequivHNFs    # un-exported in chunk 13b.1
using LinearAlgebra: norm

@testset "SupercellSelection (chunk 4)" begin

    # ---- avg_cell_radius (chunk 2 review item 2; switched from max to avg) ----
    @testset "avg_cell_radius" begin
        # Unit cube — all 8 corners equidistant from center; avg = max = sqrt(3)/2.
        @test avg_cell_radius([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]) ≈ sqrt(3)/2

        # Axis-aligned 1×1×4 box — also has equidistant corners (all at distance
        # sqrt(0.5² + 0.5² + 2²) = sqrt(4.5)). The avg = max = sqrt(4.5) here.
        @test avg_cell_radius([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 4.0]) ≈ sqrt(4.5)

        # Skew (non-axis-aligned) basis — corners at unequal distances.
        # Captured numerically; avg is meaningfully below max in this case
        # (avg ≈ 0.914, max ≈ 1.173). This is where the chunk 2 review's
        # tie-breaking rationale actually shows up.
        skew = [1.0 0.5 0.0; 0.0 1.0 0.5; 0.0 0.0 1.0]
        @test avg_cell_radius(skew) ≈ 0.9139512672596557
    end

    # ---- VolumeRange ----
    @testset "VolumeRange validation" begin
        @test_throws ArgumentError VolumeRange(2:1)              # empty range
        @test_throws ArgumentError VolumeRange(0:5)              # zero / negative volumes
        @test_throws ArgumentError VolumeRange(-1:-1)            # negative
        # Valid construction
        v = VolumeRange(2:8)
        @test v.range == 2:8
    end

    @testset "VolumeRange — enumerate_hnfs matches getSymInequivHNFs per volume" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        result = enumerate_hnfs(VolumeRange(2:6), parent)
        # Per-volume reference (from chunk 3's locked corpus on FCC):
        # n=2 → 2; n=3 → ?; n=4 → 7; n=5 → ?; n=6 → 10
        per_volume = [length(getSymInequivHNFs(n, parent)) for n in 2:6]
        @test length(result) == sum(per_volume)
        # All volumes should be in 2:6
        @test all(n -> 2 <= volume(n) <= 6, result)
    end

    # ---- RadiusBound ----
    @testset "RadiusBound validation" begin
        @test_throws ArgumentError RadiusBound(max_radius_ratio = 0)
        @test_throws ArgumentError RadiusBound(max_radius_ratio = -1)
        @test_throws ArgumentError RadiusBound(max_radius_ratio = 1.0, max_volume = 0)
        @test_throws ArgumentError RadiusBound(max_radius_ratio = 1.0, max_volume = -5)
        # Valid construction with default max_volume
        b = RadiusBound(max_radius_ratio = 2.5)
        @test b.max_radius_ratio == 2.5
        @test b.max_volume == typemax(Int)
    end

    @testset "RadiusBound — empty result for tight bound" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        # A radius bound smaller than 1× the parent radius rejects all supercells
        # (they're all at least as big as the parent).
        result = enumerate_hnfs(RadiusBound(max_radius_ratio = 0.5, max_volume = 5), parent)
        @test isempty(result)
    end

    @testset "RadiusBound — max_radius_ratio = 1 returns just the parent" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        result = enumerate_hnfs(RadiusBound(max_radius_ratio = 1.0, max_volume = 5), parent)
        @test length(result) == 1
        @test result[1].matrix == [1 0 0; 0 1 0; 0 0 1]
        @test volume(result[1]) == 1
    end

    @testset "RadiusBound — captured reference on FCC" begin
        # Captured from chunk 4 development as the regression target. FCC
        # primitive parent, max_radius_ratio = 2.0, max_volume = 20.
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        result = enumerate_hnfs(RadiusBound(max_radius_ratio = 2.0, max_volume = 20), parent)
        @test length(result) == 32
        # All survivors have volume ≤ 9 (an empirical observation worth pinning).
        @test maximum(volume(h) for h in result) <= 9
        # All survivors are within the radius cutoff.
        parent_r = avg_cell_radius(parent.A)
        for h in result
            @test avg_cell_radius(parent.A * h.matrix) <= 2.0 * parent_r + 1e-9
        end
    end

    # ---- ExplicitHNFs ----
    @testset "ExplicitHNFs validation" begin
        @test_throws ArgumentError ExplicitHNFs(HNF{3}[])
        # Valid
        h1 = HNF([1 0 0; 0 1 0; 0 0 2])
        h2 = HNF([1 0 0; 0 2 0; 0 0 1])
        e = ExplicitHNFs([h1, h2])
        @test length(e.hnfs) == 2
    end

    @testset "ExplicitHNFs — enumerate_hnfs is a no-op pass-through" begin
        parent = ParentLattice([1.0 0 0; 0 1.0 0; 0 0 1.0])
        h1 = HNF([1 0 0; 0 1 0; 0 0 2])
        h2 = HNF([1 0 0; 0 2 0; 0 0 1])
        h3 = HNF([2 0 0; 0 1 0; 0 0 1])
        result = enumerate_hnfs(ExplicitHNFs([h1, h2, h3]), parent)
        @test length(result) == 3
        @test result[1] == h1
        @test result[2] == h2
        @test result[3] == h3
    end

    # (The "Bug-fix: getFixingLatticeOps stale refs cleared" testset was
    # retired in v0.3-prep along with `radiusEnumeration.jl`, which it was
    # exercising via the now-removed `getHNFColorings` entry point.)

end
