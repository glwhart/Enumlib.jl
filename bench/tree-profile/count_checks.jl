# Counts canonical checks in the recursive-stabilizer tree (FCC, all concentrations).
# Run: julia --project=. bench/tree-profile/count_checks.jl "13 16 18 20" "9 10 12"
#      (first list: binary volumes, second: ternary volumes)

using Enumlib, Printf
const P = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
run(k, n) = enumerate_structures(P, Sites(P, collect(0:k-1)); supercells = VolumeRange(n:n),
    concentration = ConcentrationRange([(0//1, 1//1) for _ in 1:k]),
    algorithm = :recursive_stabilizer, partition_threshold = 10^9, skip_resource_check = true)
const C = zeros(Int, 6)  # checks, accepted, elements compared, checks at depth1, accepted depth1, full-group elems at depth1
@eval Enumlib function _is_canonical(partial::AbstractVector, parent_stab, depth::Int)
    Main.C[1] += 1; depth == 1 && (Main.C[4] += 1)
    for g in parent_stab
        Main.C[3] += 1; depth == 1 && (Main.C[6] += 1)
        _permuted_colex_less(partial, g, depth) && return false
    end
    Main.C[2] += 1; depth == 1 && (Main.C[5] += 1)
    return true
end
for (k, ns) in ((2, parse.(Int, split(ARGS[1]))), (3, parse.(Int, split(ARGS[2]))))
    run(k, 4)
    for n in ns
        fill!(C, 0)
        t = @elapsed s = run(k, n)
        @printf("k=%d n=%2d %7.2fs %8d structs | checks %10d kept %5.1f%% | group elems/check %6.1f | depth-1 checks %5.1f%% of all, kept %5.2f%%, elems/check %6.1f\n",
            k, n, t, length(s), C[1], 100C[2]/C[1], C[3]/C[1], 100C[4]/C[1], 100C[5]/C[4], C[6]/C[4])
        flush(stdout)
    end
end
