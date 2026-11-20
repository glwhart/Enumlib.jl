# Upper bound on what a fixed-density necklace generator could save in the tree,
# FCC binary. For each supercell whose translations are cyclic shifts of the site
# order, compare (A) the tree as it is with (B) a loop that is handed, for free,
# only the first-species sets that are already smallest under translation and runs
# the full-group canonical check on each. (B) ignores the generator's own cost, so
# it is the best case. Outputs of (A) and (B) are checked to be identical.
#   julia --project=. bench/tree-profile/necklace_bound.jl 13 17 18 19 20
using Enumlib, Printf, Combinatorics
const FCC = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])

is_cyclic_shift_group(T, n) = Set(T) == Set([[mod(i - 1 + s, n) + 1 for i in 1:n] for s in 0:n-1])

# colex comparison of two equal-size sorted position sets: smaller largest-difference wins
function colex_less(x, y)
    for i in length(x):-1:1
        x[i] != y[i] && return x[i] < y[i]
    end
    return false
end
function translation_canonical_sets(T, n, a)
    out = Vector{Vector{Int}}()
    for S in combinations(1:n, a)                 # lexicographic; re-sorted to colex below
        ok = true
        for t in T
            img = sort!([t[i] for i in S])
            if colex_less(img, S); ok = false; break; end
        end
        ok && push!(out, S)
    end
    sort!(out, lt = colex_less)
end

function emulate(pg, sets, n)
    output = Vector{Vector{Int8}}()
    partial = fill(Int8(1), n)
    for S in sets
        for i in S; partial[i] = Int8(0); end
        Enumlib._is_canonical(partial, pg, 1) && push!(output, copy(partial))
        for i in S; partial[i] = Int8(1); end
    end
    output
end

for n in parse.(Int, ARGS)
    t_whole = minimum(@elapsed(enumerate_structures(FCC, Sites(FCC, [0, 1]); supercells = VolumeRange(n:n),
        concentration = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)]), algorithm = :recursive_stabilizer,
        partition_threshold = 10^9, skip_resource_check = true)) for _ in 1:2)
    tA = tB = tA_noncyc = 0.0; ncyc = nall = 0; tried = kept_cands = 0
    for hnf in enumerate_hnfs(VolumeRange(n:n), FCC)
        pg = Supercell(hnf, FCC).permutation_group
        T = pg[1:n]; nall += 1
        cyc = is_cyclic_shift_group(T, n)
        cyc && (ncyc += 1)
        for a in 1:n-1
            mults = [a, n - a]
            Enumlib.getUniqueColorings_recursive_stabilizer(pg, mults)
            ta = minimum(@elapsed(Enumlib.getUniqueColorings_recursive_stabilizer(pg, mults)) for _ in 1:3)
            if !cyc
                tA_noncyc += ta; continue
            end
            sets = translation_canonical_sets(T, n, a)
            A = Enumlib.getUniqueColorings_recursive_stabilizer(pg, mults)
            B = emulate(pg, sets, n)
            A == B || error("emulation output differs at n=$n hnf=$(hnf.matrix) a=$a")
            tb = minimum(@elapsed(emulate(pg, sets, n)) for _ in 1:3)
            tA += ta; tB += tb; tried += binomial(n, a); kept_cands += length(sets)
        end
    end
    @printf("n=%2d  supercells %2d (cyclic %2d) | whole run %.2f s | tree on cyclic: %.3f s -> best case %.3f s (%.1fx), sets tried %d -> %d | tree on non-cyclic %.3f s\n",
            n, nall, ncyc, t_whole, tA, tB, tA / max(tB, 1e-9), tried, kept_cands, tA_noncyc)
    flush(stdout)
end
