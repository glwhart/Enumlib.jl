using Test
using Enumlib

@testset "Recursive-stabilizer tree (Morgan 2017) — chunk 8a" begin

    # ---- :recursive_stabilizer is now a real choice ----
    @testset ":recursive_stabilizer no longer rejected" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        c = Concentration_count([2, 2]; n_total = 4)
        # Should NOT throw the chunk-8-reserved ArgumentError.
        @test_nowarn enumerate(parent, sites; supercells = VolumeRange(4:4),
                                              concentration = c,
                                              algorithm = :recursive_stabilizer)
    end

    @testset ":recursive_stabilizer requires a concentration" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws ArgumentError enumerate(parent, sites;
                                              supercells = VolumeRange(4:4),
                                              algorithm = :recursive_stabilizer)
    end

    # ---- Cross-validation: :recursive_stabilizer == :multinomial at every chunk-6 reference ----
    # The strongest correctness check — the tree should produce identical
    # counts to chunk-6's bitmap algorithm at every locked reference value,
    # on both kwarg branches.

    @testset "FCC binary at fixed concentration matches :multinomial (=false)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        for (n, a, b, ref) in [(4, 2, 2, 5), (8, 4, 4, 94),
                               (8, 3, 5, 86), (12, 6, 6, 1552)]
            c = Concentration_count([a, b]; n_total = n)
            e_rs = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                            concentration = c,
                                            algorithm = :recursive_stabilizer)
            @test length(e_rs) == ref
        end
    end

    @testset "FCC binary at fixed concentration matches :multinomial (=true)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        # chunk-6.2 locked values for include_superperiodic = true
        for (n, a, b, ref) in [(4, 2, 2, 13), (8, 4, 4, 146),
                               (8, 3, 5, 86), (12, 6, 6, 1739)]
            c = Concentration_count([a, b]; n_total = n)
            e_rs = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                            concentration = c,
                                            algorithm = :recursive_stabilizer,
                                            include_superperiodic = true)
            @test length(e_rs) == ref
        end
    end

    @testset "tree count matches multinomial count exactly (FCC binary)" begin
        # Stronger version of the above: at every (HNF, concentration) pair,
        # the *count* of structures returned by the two algorithms must be
        # identical. (Coloring-by-coloring agreement is harder because the
        # canonical-orbit-rep convention may differ; counts must match.)
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        for n in [4, 8], a in 1:n-1
            c = Concentration_count([a, n - a]; n_total = n)
            for sp in (false, true)
                e_rs = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                                concentration = c,
                                                algorithm = :recursive_stabilizer,
                                                include_superperiodic = sp)
                e_m = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                                concentration = c,
                                                algorithm = :multinomial,
                                                include_superperiodic = sp)
                @test length(e_rs) == length(e_m)
            end
        end
    end

    # ---- Synthetic small group cross-validation ----
    @testset "tree matches multinomial on a synthetic 9-atom 2D group" begin
        # 3x3 torus with translations + rotations — Morgan §3 worked example
        # used a 9-atom 2D system with 36 group elements. Our reproduction
        # uses square symmetry which matches the count to multinomial but
        # may not exactly reproduce the paper's |G| / orbit count.
        function pos(i, j)
            return 1 + (mod(i, 3)) * 3 + mod(j, 3)
        end
        trans = [[pos(i + di, j + dj) for i in 0:2 for j in 0:2]
                 for di in 0:2 for dj in 0:2]
        rot90 = [pos(j, 2 - i) for i in 0:2 for j in 0:2]
        rot180 = [rot90[rot90[k]] for k in 1:9]
        rot270 = [rot90[rot180[k]] for k in 1:9]
        rots = [collect(1:9), rot90, rot180, rot270]
        pg = Vector{Vector{Int}}()
        for r in rots, t in trans
            push!(pg, r[t])
        end
        unique!(pg)

        for mults in [[2, 3, 4], [4, 3, 2], [3, 3, 3]]
            for sp in (false, true)
                cnt_rs = length(Enumlib.getUniqueColorings_recursive_stabilizer(
                            pg, mults; include_superperiodic = sp))
                cnt_m = length(Enumlib.getUniqueColorings_multinomial(
                            pg, mults; include_superperiodic = sp))
                @test cnt_rs == cnt_m
            end
        end
    end

    # ---- estimate_cost accepts :recursive_stabilizer ----
    @testset "estimate_cost handles :recursive_stabilizer" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        c = Concentration_count([4, 4]; n_total = 8)
        est = estimate_cost(parent, sites; supercells = VolumeRange(8:8),
                                            concentration = c,
                                            algorithm = :recursive_stabilizer)
        @test est isa EnumerationCostEstimate
        @test est.chosen_algorithm == :recursive_stabilizer
        @test est.total_count == 94   # chunk-6 reference
    end

    @testset "estimate_cost rejects :recursive_stabilizer without concentration" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test_throws ArgumentError estimate_cost(parent, sites;
                                                  supercells = VolumeRange(4:4),
                                                  algorithm = :recursive_stabilizer)
    end

    # ---- Tree's Polya identity (count side) ----
    @testset "sum-over-concentrations matches unrestricted (recursive_stabilizer)" begin
        parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        for n in [4, 8]
            unrestricted = length(enumerate(parent, sites; supercells = VolumeRange(n:n)))
            tree_total = 0
            for a in 1:n-1
                c = Concentration_count([a, n - a]; n_total = n)
                e = enumerate(parent, sites; supercells = VolumeRange(n:n),
                                              concentration = c,
                                              algorithm = :recursive_stabilizer)
                tree_total += length(e)
            end
            @test tree_total == unrestricted
        end
    end

end
