using Test
using Enumlib

@testset "EnumerationCostEstimate + estimate_cost + memory-budget gate (chunk 7.5)" begin

    # ---- format_bytes ----
    @testset "format_bytes spot checks" begin
        @test format_bytes(0) == "0 B"
        @test format_bytes(1023) == "1023 B"
        @test format_bytes(1024) == "1.00 KiB"
        @test format_bytes(1024^2) == "1.00 MiB"
        @test format_bytes(1024^3) == "1.00 GiB"
        @test format_bytes(1024^4) == "1.00 TiB"
        @test format_bytes(1536) == "1.50 KiB"
        @test_throws ArgumentError format_bytes(-1)
    end

    # ---- EnumerationCostEstimate construction + equality ----
    @testset "EnumerationCostEstimate equality" begin
        a = EnumerationCostEstimate(BigInt(19), 1294, :exhaustive, :volume_range, 1,
                                    String["Auto-dispatch chose :exhaustive"])
        b = EnumerationCostEstimate(BigInt(19), 1294, :exhaustive, :volume_range, 1,
                                    String["Auto-dispatch chose :exhaustive"])
        c = EnumerationCostEstimate(BigInt(20), 1294, :exhaustive, :volume_range, 1,
                                    String["Auto-dispatch chose :exhaustive"])
        @test a == b
        @test a != c
    end

    # ---- estimate_cost: total_count matches count_inequivalent ----
    @testset "estimate_cost.total_count matches count_inequivalent" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # Unrestricted, both branches.
        for n in [4, 8, 12]
            for sp in (false, true)
                est = estimate_cost(parent, sites; supercells = VolumeRange(n:n),
                                                   include_superperiodic = sp)
                cnt = count_inequivalent(parent, sites; supercells = VolumeRange(n:n),
                                                        include_superperiodic = sp)
                @test est.total_count == cnt
            end
        end

        # Fixed concentration, both branches.
        c = concentration_count([4, 4]; n_total = 8)
        for sp in (false, true)
            est = estimate_cost(parent, sites; supercells = VolumeRange(8:8),
                                               concentration = c,
                                               include_superperiodic = sp)
            cnt = count_inequivalent(parent, sites; supercells = VolumeRange(8:8),
                                                    concentration = c,
                                                    include_superperiodic = sp)
            @test est.total_count == cnt
        end
    end

    # ---- estimate_cost: chosen_algorithm follows :auto dispatch ----
    @testset "chosen_algorithm follows :auto dispatch" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # No concentration → :recursive_stabilizer (v0.3: synthesizes a full
        # ConcentrationRange internally; bench Section 5 shows ~2-3× speedup
        # and ~½ memory vs :exhaustive's k^n bitmap).
        e1 = estimate_cost(parent, sites; supercells = VolumeRange(4:4))
        @test e1.chosen_algorithm == :recursive_stabilizer
        @test any(occursin("recursive_stabilizer", n) for n in e1.notes)

        # With concentration → :multinomial.
        c = concentration_count([2, 2]; n_total = 4)
        e2 = estimate_cost(parent, sites; supercells = VolumeRange(4:4), concentration = c)
        @test e2.chosen_algorithm == :multinomial

        # Explicit algorithm passes through; notes is empty.
        e3 = estimate_cost(parent, sites; supercells = VolumeRange(4:4),
                                          algorithm = :exhaustive)
        @test e3.chosen_algorithm == :exhaustive
        @test isempty(e3.notes)
    end

    # ---- estimate_cost: selection_kind ----
    @testset "selection_kind matches the SupercellSelection subtype" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        e_vr = estimate_cost(parent, sites; supercells = VolumeRange(4:4))
        @test e_vr.selection_kind == :volume_range

        e_rb = estimate_cost(parent, sites; supercells = RadiusBound(max_radius_ratio = 2.0, max_volume = 8))
        @test e_rb.selection_kind == :radius_bound

        # Explicit HNFs — pick one HNF from the standard list.
        hnf = enumerate_hnfs(VolumeRange(4:4), parent)[1]
        e_eh = estimate_cost(parent, sites; supercells = ExplicitHNFs([hnf]))
        @test e_eh.selection_kind == :explicit_hnfs
    end

    # ---- estimate_cost: partition_count ----
    @testset "partition_count matches the request shape" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        # No concentration → 1. :auto synthesizes a full-range
        # ConcentrationRange internally to route to the tree (v0.3), but
        # the partition decomposition is an implementation detail — the
        # user didn't ask for a concentration constraint, so partition_count
        # surfaces as 1 (consistent with the user's intent).
        e_none = estimate_cost(parent, sites; supercells = VolumeRange(4:4))
        @test e_none.partition_count == 1

        # Single Concentration → 1.
        c = concentration_count([2, 2]; n_total = 4)
        e_c = estimate_cost(parent, sites; supercells = VolumeRange(4:4), concentration = c)
        @test e_c.partition_count == 1

        # ConcentrationRange → number of multiplicity vectors at each volume,
        # summed across HNFs at that volume. At n=4 with full bounds: 5 partitions
        # × 7 HNFs at n=4 = 35.
        cr = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])
        e_cr = estimate_cost(parent, sites; supercells = VolumeRange(4:4), concentration = cr)
        @test e_cr.partition_count == 5 * 7
    end

    # ---- Memory prediction sanity ----
    @testset "peak_memory_bytes is positive and increases with size" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        e4  = estimate_cost(parent, sites; supercells = VolumeRange(4:4))
        e8  = estimate_cost(parent, sites; supercells = VolumeRange(8:8))
        e12 = estimate_cost(parent, sites; supercells = VolumeRange(12:12))

        @test e4.peak_memory_bytes > 0
        @test e8.peak_memory_bytes > e4.peak_memory_bytes
        @test e12.peak_memory_bytes > e8.peak_memory_bytes
    end

    @testset "multinomial bitmap < exhaustive bitmap at same n" begin
        # At asymmetric concentrations, the multinomial-bitmap term
        # binomial(n, a) is much smaller than the exhaustive 2^n term.
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

        e_exh = estimate_cost(parent, sites; supercells = VolumeRange(12:12))
        c = concentration_count([5, 7]; n_total = 12)
        e_mul = estimate_cost(parent, sites; supercells = VolumeRange(12:12),
                                              concentration = c)
        @test e_mul.peak_memory_bytes < e_exh.peak_memory_bytes
    end

    # ---- Memory-budget gate (the headline feature) ----

    @testset "default budget passes for chunk-5/6 reference cases" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # Default memory_budget is several GiB; FCC at n ≤ 12 is far smaller.
        @test_nowarn enumerate(parent, sites; supercells = VolumeRange(12:12))
    end

    @testset "memory_budget = 1 fires EnumerationTooLargeError" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws EnumerationTooLargeError enumerate(parent, sites;
                                                         supercells = VolumeRange(4:4),
                                                         memory_budget = 1)
    end

    # ---- Real-world gate firing: the default budget protects against a
    # case that would otherwise allocate hundreds of GiB.
    # v0.2-polish item from `docs/notes/v0.2-plan.md` line 444. The previous
    # gate-firing tests force the issue with `memory_budget = 1`; this one
    # confirms the gate also fires for a realistic input without budget
    # manipulation. FCC binary unrestricted at n=30 with `:exhaustive`
    # predicts a 2^30-bit bitmap (~130 MiB) but the conservative output-buffer
    # bound from `_predict_peak_memory` adds the per-structure cost across
    # 2.6 × 10^9 predicted structures, well over 200 GiB. Default 8 GiB budget
    # refuses the request.
    @testset "default budget fires for FCC binary :exhaustive n=30" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws EnumerationTooLargeError enumerate(parent, sites;
            supercells = VolumeRange(30:30), algorithm = :exhaustive)
        # Same case via estimate_cost — predicted peak far exceeds the
        # default 25%-of-RAM-or-2-GiB budget for any reasonable machine.
        est = estimate_cost(parent, sites; supercells = VolumeRange(30:30),
                             algorithm = :exhaustive)
        @test est.chosen_algorithm == :exhaustive
        @test est.total_count > 10^9
        @test est.peak_memory_bytes > Enumlib.default_memory_budget()
    end

    # The negative counterpart: a moderately large enumeration that the gate
    # *passes*. Confirms the conservatism dial is set so the gate doesn't
    # refuse cases that would actually run. FCC binary unrestricted at n=18
    # predicts ~32 MiB of memory and ~4 × 10^5 structures — fits in the
    # default budget comfortably.
    @testset "default budget passes for FCC binary auto n=18" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        est = estimate_cost(parent, sites; supercells = VolumeRange(18:18))
        @test est.chosen_algorithm == :recursive_stabilizer  # v0.3 default
        @test est.peak_memory_bytes < Enumlib.default_memory_budget()
        # Sanity: total_count nontrivial.
        @test est.total_count > 10^5
    end

    @testset "on_overflow = :warn warns but proceeds" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e = @test_logs (:warn, r"exceeds memory_budget") match_mode = :any begin
            enumerate(parent, sites; supercells = VolumeRange(4:4),
                                     memory_budget = 1, on_overflow = :warn)
        end
        @test length(e) == 19   # ran to completion despite the warn
    end

    @testset "on_overflow = :ignore proceeds silently" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        e = enumerate(parent, sites; supercells = VolumeRange(4:4),
                                     memory_budget = 1, on_overflow = :ignore)
        @test length(e) == 19
    end

    @testset "skip_resource_check = true bypasses the gate entirely" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # Even with absurd budget = 1, skip_resource_check = true runs without
        # error because the gate is never consulted.
        e = enumerate(parent, sites; supercells = VolumeRange(4:4),
                                     memory_budget = 1, skip_resource_check = true)
        @test length(e) == 19
    end

    # ---- EnumerationTooLargeError payload ----
    @testset "EnumerationTooLargeError carries the populated estimate" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        try
            enumerate(parent, sites; supercells = VolumeRange(4:4), memory_budget = 1)
            @test false   # should have thrown
        catch err
            @test err isa EnumerationTooLargeError
            @test err.estimate isa EnumerationCostEstimate
            @test err.estimate.total_count == 19
            # v0.3: :auto routes unrestricted through the tree.
            @test err.estimate.chosen_algorithm == :recursive_stabilizer
            @test err.budget_bytes == 1
            # showerror should run without error and contain "memory_budget".
            io = IOBuffer()
            showerror(io, err)
            @test occursin("memory_budget", String(take!(io)))
        end
    end

end
