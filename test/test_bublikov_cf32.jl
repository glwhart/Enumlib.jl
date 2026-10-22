# Cross-check against an independent code: D. N. Bublikov's NaCl-type
# superstructure simulator (Crystallography Reports 56, 89–100 (2011);
# github.com/dmitry-bublikov/NaCl-superstructure-simulator, commit 5e59fea).
#
# His CF32 cell is the 2a × 2a × 2a rocksalt cube: 32 cation and 32 anion sites.
# For each stoichiometry he lists every cation charge assignment on the cube in
# which the six cation neighbors of every O²⁻ sum to +12 (Pauling's rule), then
# removes symmetry duplicates and keeps one of each mirror pair. From his
# example_files:
#   raw      = lines of 2_Structure_generator's structuries_*.txt
#   distinct = phase_*.cif files left after 6_Mirror_structure_comparison
#              (the 7_Reduce_cell_for_DFT inputs)
#
# Enumerating every ordering of the cube and filtering is exact but slow (404,582
# distinct Na₁₆Fe₁₆ orderings alone), so this test searches site by site with the
# rule as a bound and merges equivalent solutions with the cube's own symmetry
# permutations from Enumlib's `Supercell`. Agreement checks Enumlib's rocksalt
# space group and supercell permutation group against his independent symmetry
# filters, on cells where both are complete.

using Test
using Enumlib
using LinearAlgebra

@testset "Bublikov CF32 local-balance counts" begin
    A = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
    P = ParentLattice(A, [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5]])
    cube = HNF{3}([2 0 0; 2 4 0; 2 0 4])
    @test A * cube.matrix ≈ [2 2 2; 2 0 2; 2 2 0]          # spans 2x̂, 2ŷ, 2ẑ

    # Six cation neighbors of each anion (indices 1:32 are cations, 33:64 anions).
    frac = Enumlib.supercell_fractional_positions(cube, P)
    cart = [(A * cube.matrix) * collect(f) for f in frac]
    mi(d) = d .- 2 .* round.(d ./ 2)                        # minimum image, period 2a
    nb = [[c for c in 1:32 if isapprox(norm(mi(cart[c] - cart[32 + a])), 0.5; atol = 1e-6)]
          for a in 1:32]
    @test all(==(6) ∘ length, nb)
    G = Supercell(cube, P).permutation_group

    function bublikov_counts(counts, charges; target = 12)
        # Visit sites so anion neighborhoods close early: next is the unvisited
        # site whose anions have the fewest unvisited neighbors left.
        order = Int[]; todo = Set(1:32)
        while !isempty(todo)
            score(c) = minimum(count(in(todo), nb[a]) for a in 1:32 if c in nb[a])
            c = argmin(c -> (score(c), c), collect(todo))
            push!(order, c); delete!(todo, c)
        end
        pos = invperm(order)
        nbs = [[pos[c] for c in nb[a]] for a in 1:32]
        anions_of = [Int[] for _ in 1:32]
        for a in 1:32, c in nbs[a]; push!(anions_of[c], a); end

        lab = zeros(Int, 32); left = copy(counts)
        psum = zeros(Int, 32); free = fill(6, 32)
        sols = Vector{Vector{Int}}()
        function reachable(a)
            qs = [charges[i] for i in eachindex(left) if left[i] > 0]
            isempty(qs) && return psum[a] == target
            psum[a] + minimum(qs) * free[a] <= target <= psum[a] + maximum(qs) * free[a]
        end
        function dfs(c)
            c > 32 && (push!(sols, lab[pos]); return)            # back to site order
            for i in eachindex(counts)
                left[i] == 0 && continue
                left[i] -= 1; lab[c] = i - 1
                for a in anions_of[c]; psum[a] += charges[i]; free[a] -= 1; end
                if all(a -> free[a] > 0 ? reachable(a) : psum[a] == target, anions_of[c])
                    dfs(c + 1)
                end
                for a in anions_of[c]; psum[a] -= charges[i]; free[a] += 1; end
                left[i] += 1
            end
        end
        dfs(1)
        k = length(counts)                                     # anion label
        canon(l) = minimum(Tuple([l; fill(k, 32)][g]) for g in G)
        return (raw = length(sols), distinct = length(unique(canon.(sols))))
    end

    # (cation counts, cation charges) => (raw, distinct) from his example_files.
    cases = [
        ([16, 16],     [1, 3])    => (140, 5),     # NaFeO₂ / LiFeO₂ (his 21_12_0)
        ([4, 24, 4],   [1, 2, 3]) => (120, 3),     # Li/Mg/Fe oxides (his 31_12_0)
        ([6, 20, 6],   [1, 2, 3]) => (480, 3),
        ([8, 16, 8],   [1, 2, 3]) => (1620, 9),
        ([10, 12, 10], [1, 2, 3]) => (2112, 7),
        ([12, 8, 12],  [1, 2, 3]) => (1200, 9),
    ]
    for ((counts, q), (raw, distinct)) in cases
        r = bublikov_counts(counts, q)
        @test r.raw == raw
        @test r.distinct == distinct
    end
end
