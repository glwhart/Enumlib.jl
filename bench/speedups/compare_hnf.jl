# Old vs new supercell reduction: identical canonical lists and class sizes, and timing.
#   julia --project=. bench/speedups/compare_hnf.jl
using Enumlib, Printf
lat = [("FCC", [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0], nothing),
       ("BCC", [-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5], nothing),
       ("SC",  [1.0 0 0; 0 1.0 0; 0 0 1.0], nothing),
       ("tetragonal", [1.0 0 0; 0 1.0 0; 0 0 1.3], nothing),
       ("orthorhombic", [1.0 0 0; 0 1.2 0; 0 0 1.45], nothing),
       ("HCP", [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)], [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])]
parents = [(nm, ds === nothing ? ParentLattice(A) : ParentLattice(A, ds)) for (nm, A, ds) in lat]
LGs = [(nm, [Matrix{Int}(round.(Int, op.R)) for op in space_group(p)]) for (nm, p) in parents]
LGs = [(nm, unique(LG)) for (nm, LG) in LGs]
NMAX = parse(Int, get(ENV, "NMAX", "16"))
old = Dict{Tuple{String,Int},Any}(); told = Dict{String,Float64}()
for (nm, LG) in LGs
    told[nm] = @elapsed for d in 1:NMAX; old[(nm, d)] = Enumlib._getSymInequivHNFs_with_degens(d, LG); end
end
include(joinpath(@__DIR__, "hnf_orbit_patch.jl"))
for (nm, LG) in LGs
    Enumlib._getSymInequivHNFs_with_degens(2, LG)
    same = true
    tnew = @elapsed for d in 1:NMAX
        r = Enumlib._getSymInequivHNFs_with_degens(d, LG)
        r == old[(nm, d)] || (same = false; println("DIFFERS: $nm d=$d"))
    end
    @printf("%-13s |LG| = %2d  volumes 1-%d: %d classes; identical %s;  old %.2f s, new %.3f s\n",
            nm, length(LG), NMAX, sum(length(old[(nm, d)][1]) for d in 1:NMAX), same, told[nm], tnew)
end
