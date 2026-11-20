# Sampling profile, printed as a call tree, of one FCC enumeration.
# Run: julia --project=. bench/tree-profile/profile_tree.jl 2 18   (k species, volume n)
# Read the tree view, not per-function totals: the sampler also records idle threads.

using Enumlib, Profile
const P = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
run(k, n) = enumerate_structures(P, Sites(P, collect(0:k-1)); supercells = VolumeRange(n:n),
    concentration = ConcentrationRange([(0//1, 1//1) for _ in 1:k]),
    algorithm = :recursive_stabilizer, partition_threshold = 10^9, skip_resource_check = true)
k, n = parse.(Int, ARGS)
run(k, 4)
Profile.init(n = 10^8, delay = 0.001)
@time @profile run(k, n)
Profile.print(format = :tree, C = false, mincount = 40, maxdepth = 30, noisefloor = 2)
