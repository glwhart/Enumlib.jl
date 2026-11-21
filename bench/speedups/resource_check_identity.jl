# Identity check for the resource-check speedup (branch perf/resource-check).
# Run with --project=<checkout> and an output file name, once on a copy of main
# (`git archive main | tar -x -C DIR`, plus a Manifest.toml) and once on the
# branch, then `diff` the two files. Each line holds the first 16 hex digits of
# the SHA-256 of one printed result. About an hour per checkout, most of it
# printing and hashing the ~10^6 structures.
using Enumlib, SHA, Printf

out = open(ARGS[1], "w")
digest(x) = bytes2hex(sha256(repr(x)))[1:16]
put(case, what, x) = (println(out, rpad(case, 34), rpad(what, 34), digest(x)); flush(out))

A_fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
A_bcc = [-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5]
A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
p_fcc = ParentLattice(A_fcc)
p_bcc = ParentLattice(A_bcc)
p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
p_hh = ParentLattice(A_fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25], [0.75, 0.75, 0.75]])
# Half-Heusler with distinct inactive labels: Regime C, filtered parent (48 -> 24 ops).
s_hh = Sites([Site([0.0, 0.0, 0.0], [0, 1]), Site([0.25, 0.25, 0.25], [2]),
              Site([0.75, 0.75, 0.75], [3])])

# (label, parent, sites, volumes, keyword arguments)
cases = [
    ("fcc binary 1:16",            p_fcc, Sites(p_fcc, [0, 1]),    1:16, (;)),
    ("fcc ternary 1:10",           p_fcc, Sites(p_fcc, [0, 1, 2]), 1:10, (;)),
    ("bcc binary 1:14",            p_bcc, Sites(p_bcc, [0, 1]),    1:14, (;)),
    ("hcp ternary 1:6",            p_hcp, Sites(p_hcp, [0, 1, 2]), 1:6,  (;)),
    ("fcc binary 1:12 x in 1/4..3/4", p_fcc, Sites(p_fcc, [0, 1]), 1:12,
        (; concentration = ConcentrationRange([(1//4, 3//4), (1//4, 3//4)]))),
    ("fcc binary 1:12 x = 1/2",    p_fcc, Sites(p_fcc, [0, 1]),    1:12,
        (; concentration = Concentration([1//2, 1//2]))),
    ("fcc binary 1:10 superperiodic", p_fcc, Sites(p_fcc, [0, 1]), 1:10,
        (; include_superperiodic = true)),
    ("fcc binary 1:10 exhaustive", p_fcc, Sites(p_fcc, [0, 1]),    1:10,
        (; algorithm = :exhaustive)),
    ("hcp binary 1:6 multinomial", p_hcp, Sites(p_hcp, [0, 1]),    1:6,
        (; concentration = ConcentrationRange(2), algorithm = :multinomial)),
    ("half-Heusler C full range 1:4", p_hh, s_hh, 1:4,
        (; concentration = ConcentrationRange(4), partition_threshold = 10^6)),
    ("half-Heusler C partial 1:4", p_hh, s_hh, 1:4,
        (; concentration = ConcentrationRange([(0//1, 1//3), (0//1, 1//3), (1//3, 1//3), (1//3, 1//3)]),
           partition_threshold = 10^6)),
]

for (lab, p, s, v, kw) in cases
    sc = VolumeRange(v)
    ckw = (; (k => kw[k] for k in keys(kw) if k in (:concentration, :include_superperiodic))...)
    ekw = (; (k => kw[k] for k in keys(kw) if k in (:concentration, :include_superperiodic, :algorithm))...)
    put(lab, "count_inequivalent breakdown", count_inequivalent(p, s; supercells = sc, breakdown = true, ckw...))
    put(lab, "count_inequivalent superperiodic", count_inequivalent(p, s; supercells = sc, include_superperiodic = true, breakdown = true,
                                                                   (; (k => kw[k] for k in keys(kw) if k == :concentration)...)...))
    put(lab, "estimate_cost", estimate_cost(p, s; supercells = sc, ekw...))
    e = enumerate_structures(p, s; supercells = sc, kw...)
    put(lab, "enumerate supercells", [(c.hnf.matrix, c.snf, c.n_stabilizer_ops, c.permutation_group, c.hnf_degeneracy) for c in e.supercells])
    put(lab, "enumerate structures", [(t.supercell_id, t.labeling, t.orbit_size) for t in e.structures])
    put(lab, "number of structures = $(length(e.structures))", length(e.structures))
    e2 = enumerate_structures(p, s; supercells = sc, skip_resource_check = true, kw...)
    put(lab, "same, skip_resource_check", [(t.supercell_id, t.labeling, t.orbit_size) for t in e2.structures])
end
# Resource-check error path: the estimate must still fire before any enumeration.
try
    enumerate_structures(p_fcc, Sites(p_fcc, [0, 1]); supercells = VolumeRange(20:20), memory_budget = 1)
    put("fcc binary 20 budget=1", "error", "no error")
catch err
    put("fcc binary 20 budget=1", "error", (typeof(err), err.estimate))
end
close(out)
