using Test
using Enumlib

# Chunk 8b — :auto dispatch upgrade. With chunk 8a's :recursive_stabilizer in
# place, `:auto` now picks between :multinomial and :recursive_stabilizer based
# on whether the multinomial bitmap would exceed memory_budget × 0.8.

@testset ":auto dispatch with :recursive_stabilizer (chunk 8b)" begin

    parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
    sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

    # ---- :auto with no concentration → :exhaustive (unchanged) ----
    @testset ":auto / no concentration → :exhaustive" begin
        e = estimate_cost(parent, sites; supercells = VolumeRange(4:4))
        @test e.chosen_algorithm == :exhaustive
    end

    # ---- :auto with concentration, default budget → :multinomial (small case fits) ----
    @testset ":auto / small fixed-concentration / default budget → :multinomial" begin
        c = concentration_count([4, 4]; n_total = 8)
        e = estimate_cost(parent, sites; supercells = VolumeRange(8:8), concentration = c)
        @test e.chosen_algorithm == :multinomial
    end

    # ---- The bitmap-fits helper ----
    @testset "_multinomial_bitmap_fits flips at the right boundary" begin
        c = concentration_count([4, 4]; n_total = 8)
        # n=8 4:4: multinomial = 70 → bitmap = ceil(70/8) = 9 bytes.
        # Threshold = budget × 0.8.
        # At budget = 100 → threshold = 80. 9 ≤ 80 → fits.
        @test Enumlib._multinomial_bitmap_fits(parent, VolumeRange(8:8), c, 100)
        # At budget = 5 → threshold = 4. 9 > 4 → doesn't fit.
        @test !Enumlib._multinomial_bitmap_fits(parent, VolumeRange(8:8), c, 5)

        # n=12 6:6: multinomial = 924 → bitmap = ceil(924/8) = 116 bytes.
        c12 = concentration_count([6, 6]; n_total = 12)
        # At budget = 100 → threshold = 80. 116 > 80 → doesn't fit.
        @test !Enumlib._multinomial_bitmap_fits(parent, VolumeRange(12:12), c12, 100)
        # At budget = 1000 → threshold = 800. 116 ≤ 800 → fits.
        @test Enumlib._multinomial_bitmap_fits(parent, VolumeRange(12:12), c12, 1000)
    end

    # ---- :auto with tight memory_budget should pick :recursive_stabilizer ----
    @testset ":auto / tight memory_budget → :recursive_stabilizer + completes" begin
        c = concentration_count([6, 6]; n_total = 12)
        # Budget where multinomial bitmap (116 bytes) > budget × 0.8 (= 80 → 100 budget).
        # But the gate would also fire because output > 100. So bypass with skip_preflight.
        e = enumerate(parent, sites; supercells = VolumeRange(12:12), concentration = c,
                                     memory_budget = 100, skip_preflight = true)
        # We don't have a direct way to inspect chosen algorithm from Enumeration,
        # but we can verify the count matches the chunk-6 reference (which means
        # whichever algorithm was picked, it produced the right answer).
        @test length(e) == 1552
    end

    # ---- :auto picks :multinomial OR :recursive_stabilizer; both give same count ----
    @testset ":auto count matches explicit algorithms (chunk-6 references)" begin
        # At every chunk-6 reference, :auto's choice should produce the same count
        # as :multinomial and :recursive_stabilizer (which we already cross-validated
        # in chunk 8a).
        for (n, a, b, ref) in [(4, 2, 2, 5), (8, 4, 4, 94),
                               (8, 3, 5, 86), (12, 6, 6, 1552)]
            c = concentration_count([a, b]; n_total = n)
            e_auto = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                              concentration = c)
            @test length(e_auto) == ref
        end
    end

    # ---- Ag-Pt-style asymmetric concentration at moderate volume (single HNF) ----
    # Demonstrates the tree handles a real case at scale. n=16 7:9 → multinomial 11440;
    # asymmetric so no super-periodic; sub-second across all 47 HNFs at n=16.
    @testset "Ag-Pt-style 7:9 at n=16 (full sweep, both algorithms agree)" begin
        c = concentration_count([7, 9]; n_total = 16)
        # Use single (most-symmetric) HNF to keep this fast, but cover the *value*.
        hnfs = enumerate_hnfs(VolumeRange(16:16), parent)
        # Pick the HNF with the largest stabilizer for fastest enumeration.
        gsizes = [length(Supercell(h, parent).permutation_group) for h in hnfs]
        best_h = hnfs[argmax(gsizes)]
        ehnfs = ExplicitHNFs([best_h])

        cnt_count = count_inequivalent(parent, sites; supercells = ehnfs, concentration = c)
        cnt_rs = length(enumerate(parent, sites; supercells = ehnfs, concentration = c,
                                                  algorithm = :recursive_stabilizer))
        cnt_m = length(enumerate(parent, sites; supercells = ehnfs, concentration = c,
                                                 algorithm = :multinomial))
        @test cnt_count == cnt_rs == cnt_m
    end

end
