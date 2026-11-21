# Warm timings, minimum of 5, for the resource check alone and the whole default run.
# Run with --project=<checkout>; prints one line per case.
using Enumlib, Printf

function tmin(f)
    f()                                    # warm-up (compilation)
    best = Inf
    for _ in 1:5
        GC.gc()
        best = min(best, @elapsed f())
    end
    return 1000best
end

A_fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
A_bcc = [-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5]
A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
p_fcc = ParentLattice(A_fcc); p_bcc = ParentLattice(A_bcc)
p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])

cases = [("fcc binary 1-16", p_fcc, Sites(p_fcc, [0, 1]), 1:16, (;)),
         ("fcc ternary 1-10", p_fcc, Sites(p_fcc, [0, 1, 2]), 1:10, (;)),
         ("bcc binary 1-14", p_bcc, Sites(p_bcc, [0, 1]), 1:14, (;)),
         ("hcp ternary 1-6", p_hcp, Sites(p_hcp, [0, 1, 2]), 1:6, (;)),
         ("fcc binary 1-12 x in 1/4..3/4", p_fcc, Sites(p_fcc, [0, 1]), 1:12,
             (; concentration = ConcentrationRange([(1//4, 3//4), (1//4, 3//4)])))]

@printf("%-32s %14s %16s %16s\n", "case", "estimate_cost", "default run", "skip check")
for (lab, p, s, v, kw) in cases
    sc = VolumeRange(v)
    te = tmin(() -> estimate_cost(p, s; supercells = sc, kw...))
    tr = tmin(() -> enumerate_structures(p, s; supercells = sc, kw...))
    ts = tmin(() -> enumerate_structures(p, s; supercells = sc, skip_resource_check = true, kw...))
    @printf("%-32s %11.1f ms %13.1f ms %13.1f ms\n", lab, te, tr, ts)
end
