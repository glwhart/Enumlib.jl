# Times the tree and hashes its output, with or without the in-memory patch.
#   julia --project=. bench/tree-profile/compare_successor.jl original
#   julia --project=. bench/tree-profile/compare_successor.jl patched
using Enumlib, Printf
ARGS[1] == "patched" && include(joinpath(@__DIR__, "successor_patch.jl"))
const P = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
run(k, n) = enumerate_structures(P, Sites(P, collect(0:k-1)); supercells = VolumeRange(n:n),
    concentration = ConcentrationRange([(0//1, 1//1) for _ in 1:k]),
    algorithm = :recursive_stabilizer, partition_threshold = 10^9, skip_resource_check = true)
run(2, 4); run(3, 4)
for (k, n) in ((2, 16), (2, 18), (2, 20), (3, 10), (3, 12))
    s = run(k, n); t = minimum(@elapsed(run(k, n)) for _ in 1:3)
    @printf("%-8s k=%d n=%2d  %7.2f s  %8d structures  output hash %016x\n",
            ARGS[1], k, n, t, length(s), hash(repr(s)))
    flush(stdout)
end
