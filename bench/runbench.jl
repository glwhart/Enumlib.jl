# Benchmark suite for Enumlib's three algorithms.
#
# Two purposes:
#   1. Lock per-algorithm wall-clock numbers so regressions are visible.
#   2. Cross-compare the three algorithms (:exhaustive, :multinomial,
#      :recursive_stabilizer) on the cases where they're directly comparable,
#      to settle whether one dominates the others in practice.
#
# Run:
#   $ julia --project=bench bench/runbench.jl
#
# To capture results to a file for git-tracking:
#   $ julia --project=bench bench/runbench.jl > bench/results-$(date +%Y%m%d).txt
#
# The script is intentionally a flat-script (no module). Each `@btime`
# block produces a min/median time + allocation count; cross-grep results
# files for regressions.

using Enumlib
using BenchmarkTools
using Dates

# Warmup — touch every algorithm so JIT specializations happen before we time.
let
    p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s = Sites(p, [0, 1])
    c = concentration_count([2, 2]; n_total = 4)
    enumerate(p, s; supercells = VolumeRange(2:2))
    enumerate(p, s; supercells = VolumeRange(4:4), concentration = c, algorithm = :multinomial)
    enumerate(p, s; supercells = VolumeRange(4:4), concentration = c, algorithm = :recursive_stabilizer)
    count_inequivalent(p, s; supercells = VolumeRange(4:4))

    # Regime C warmup — touches :multinomial_restricted and the Regime-C
    # branch of :recursive_stabilizer for Section 4.
    pC = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                       [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
    sC = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                Site([0.25, 0.25, 0.25], [2, 3])])
    crC = ConcentrationRange([(0//1, 1//1) for _ in 1:4])
    enumerate(pC, sC; supercells = VolumeRange(1:1), concentration = crC,
              algorithm = :multinomial_restricted,
              partition_threshold = 1_000_000, skip_resource_check = true)
    enumerate(pC, sC; supercells = VolumeRange(1:1), concentration = crC,
              algorithm = :recursive_stabilizer,
              partition_threshold = 1_000_000, skip_resource_check = true)
end

println("="^78)
println("Enumlib benchmark suite — ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
println("Julia ", VERSION, "  |  Enumlib ", pkgversion(Enumlib))
println("="^78)

# ============================================================================
# Section 1 — single-lattice (FCC binary), unrestricted concentration.
#
# Only :exhaustive applies (the other two need a concentration). Cross-checks
# against the Fortran-vs-Julia table in docs/notes/v0.2-plan.md (2026-05-09
# Performance baseline). Volumes chosen to span the curve: small (per-call
# overhead dominates), medium (work-dominated), large (allocation patterns).
# ============================================================================

println()
println("Section 1 — FCC binary unrestricted (:exhaustive only)")
println("-"^78)

let
    p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s = Sites(p, [0, 1])
    for n in (4, 8, 12)
        print("  FCC binary, VolumeRange($n:$n): ")
        b = @benchmark enumerate($p, $s; supercells = VolumeRange($n:$n)) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
    end
end

# ============================================================================
# Section 2 — single-lattice, fixed concentration. All three algorithms apply
# (the user can pick via `algorithm = :exhaustive` / `:multinomial` /
# `:recursive_stabilizer`). Direct cross-algorithm comparison.
# ============================================================================

println()
println("Section 2 — FCC binary fixed concentration (cross-algorithm)")
println("-"^78)

let
    p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s = Sites(p, [0, 1])

    # 2:2 at n=4 (5 configs — small, per-call overhead dominates).
    # 4:4 at n=8 (94 configs — chunk-6 reference; medium work).
    # 6:6 at n=12 (1552 configs — chunk-6 reference; large).
    cases = [
        ("4 (2:2)",  concentration_count([2, 2]; n_total = 4),  4),
        ("8 (4:4)",  concentration_count([4, 4]; n_total = 8),  8),
        ("12 (6:6)", concentration_count([6, 6]; n_total = 12), 12),
    ]
    for (label, c, n) in cases
        println("  n=$label")
        for alg in (:exhaustive, :multinomial, :recursive_stabilizer)
            print("    $(rpad(":$alg", 24))")
            kw = alg == :exhaustive ? (;) : (; concentration = c)
            b = @benchmark enumerate($p, $s; supercells = VolumeRange($n:$n), algorithm = $alg, $kw...) samples=5 evals=1
            println(BenchmarkTools.prettytime(minimum(b).time),
                    "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                    ", ", minimum(b).allocs, " allocs)")
        end
    end
end

# ============================================================================
# Section 3 — multilattice unrestricted (HCP, Diamond — uniform sublattices).
# Regime B from R50.2b. Only :exhaustive applies (no concentration).
# ============================================================================

println()
println("Section 3 — multilattice unrestricted (:exhaustive only)")
println("-"^78)

let
    a = 1.0; c = sqrt(8/3)
    A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
    p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
    s_hcp = Sites(p_hcp, [0, 1])

    A_dia = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
    p_dia = ParentLattice(A_dia, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
    s_dia = Sites(p_dia, [0, 1])

    for (name, parent, sites, vols) in (
        ("HCP    n=1..4 (333)",  p_hcp, s_hcp, 1:4),
        ("HCP    n=5   (651)",   p_hcp, s_hcp, 5:5),
        ("HCP    n=6   (4793)",  p_hcp, s_hcp, 6:6),
        ("Diamond n=1..4 (214)", p_dia, s_dia, 1:4),
    )
        print("  $(rpad(name, 24))")
        b = @benchmark enumerate($parent, $sites; supercells = VolumeRange($vols)) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
    end
end

# ============================================================================
# Section 4 — per-site restricted labels (Regime C) — cross-algorithm.
#
# Both Regime C algorithms — :multinomial_restricted (chunk 6.5a, HF 2012
# §A.1 bitmap + site_mask) and :recursive_stabilizer (chunk 8, Morgan-Hart
# 2017 tree) — are now wired through. Section 4 measures them head-to-head
# on two contrasting mask shapes:
#
#   - "dense": zinc-blende. Both sublattices active, disjoint binary labels
#     ({0,1} on sublattice 1, {2,3} on sublattice 2). Every position is
#     active; the mask only forbids cross-sublattice labels.
#   - "sparse": half-Heusler Y=Z={2}. One binary sublattice ({0,1}) plus two
#     fixed sublattices (label 2 only). Most positions are inactive.
#
# :auto picks :recursive_stabilizer in both cases (chunk 6.5a's design
# note): :multinomial_restricted's linear bitmap scales by the full
# multinomial coefficient, so for sparse masks where most slots are
# invalid it wastes effort. A tree-walk pruning variant is queued for v0.3.
# ============================================================================

println()
println("Section 4 — Regime C cross-algorithm (chunk 6.5a vs chunk 8)")
println("-"^78)

let
    # ---- dense mask: zinc-blende ({0,1} ⊕ {2,3}) ----
    p_zb = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                         [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
    s_zb = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                  Site([0.25, 0.25, 0.25], [2, 3])])
    cr_zb = ConcentrationRange([(0//1, 1//1) for _ in 1:4])

    for n in (2, 3)
        println("  zinc-blende n=$n  (dense mask: every position active)")
        for alg in (:multinomial_restricted, :recursive_stabilizer)
            print("    $(rpad(":$alg", 26))")
            b = @benchmark enumerate($p_zb, $s_zb;
                                     supercells = VolumeRange($n:$n),
                                     concentration = $cr_zb,
                                     algorithm = $alg,
                                     partition_threshold = 1_000_000,
                                     skip_resource_check = true) samples=5 evals=1
            println(BenchmarkTools.prettytime(minimum(b).time),
                    "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                    ", ", minimum(b).allocs, " allocs)")
        end
    end

    # ---- sparse mask: half-Heusler Y=Z={2} ----
    p_hh = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                         [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25], [0.75, 0.75, 0.75]])
    s_hh = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                  Site([0.25, 0.25, 0.25], [2]),
                  Site([0.75, 0.75, 0.75], [2])])
    cr_hh = ConcentrationRange([(0//1, 1//1) for _ in 1:3])

    for n in (2, 3)
        println("  half-Heusler Y=Z={2} n=$n  (sparse mask: 2/3 of positions fixed)")
        for alg in (:multinomial_restricted, :recursive_stabilizer)
            print("    $(rpad(":$alg", 26))")
            b = @benchmark enumerate($p_hh, $s_hh;
                                     supercells = VolumeRange($n:$n),
                                     concentration = $cr_hh,
                                     algorithm = $alg,
                                     partition_threshold = 1_000_000,
                                     skip_resource_check = true) samples=5 evals=1
            println(BenchmarkTools.prettytime(minimum(b).time),
                    "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                    ", ", minimum(b).allocs, " allocs)")
        end
    end
end

# ============================================================================
# Section 5 — full-sweep cross-algorithm (:exhaustive vs :recursive_stabilizer).
#
# When the user wants every symmetry-inequivalent configuration regardless
# of concentration, two paths exist:
#
#   - `:exhaustive` (no concentration kwarg) — one bitmap pass over k^n.
#   - `:recursive_stabilizer` with `ConcentrationRange([(0,1), ...])` — runs
#     the tree once per integer composition of n_active into k parts and
#     concatenates. The number of partitions is `C(n+k-1, k-1)`, all small
#     for the cases here.
#
# Same FCC/HCP/Diamond cases as Sections 1–3, just probing whether the tree
# beats the bitmap when *every* concentration is enumerated. Multinomial
# ternary (FCC k=3) added because the partition fan-out is larger and the
# bitmap covers a wider domain (3^n vs 2^n).
# ============================================================================

println()
println("Section 5 — full-sweep (:exhaustive vs :recursive_stabilizer)")
println("-"^78)

let
    # ---- FCC binary, full sweep ----
    p_b = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s_b = Sites(p_b, [0, 1])
    cr_b = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])

    for n in (4, 8, 12)
        println("  FCC binary n=$n  (2^$n = $(2^n) bitmap slots)")
        print("    $(rpad(":exhaustive", 26))")
        b = @benchmark enumerate($p_b, $s_b;
                                 supercells = VolumeRange($n:$n)) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
        print("    $(rpad(":recursive_stabilizer", 26))")
        b = @benchmark enumerate($p_b, $s_b;
                                 supercells = VolumeRange($n:$n),
                                 concentration = $cr_b,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
    end

    # ---- FCC ternary, full sweep ----
    p_t = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s_t = Sites(p_t, [0, 1, 2])
    cr_t = ConcentrationRange([(0//1, 1//1), (0//1, 1//1), (0//1, 1//1)])

    for n in (4, 6)
        println("  FCC ternary n=$n  (3^$n = $(3^n) bitmap slots)")
        print("    $(rpad(":exhaustive", 26))")
        b = @benchmark enumerate($p_t, $s_t;
                                 supercells = VolumeRange($n:$n)) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
        print("    $(rpad(":recursive_stabilizer", 26))")
        b = @benchmark enumerate($p_t, $s_t;
                                 supercells = VolumeRange($n:$n),
                                 concentration = $cr_t,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
    end

    # ---- HCP binary, full sweep ----
    a = 1.0; c = sqrt(8/3)
    A_hcp = [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c]
    p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
    s_hcp = Sites(p_hcp, [0, 1])
    cr_hcp = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)])

    for n in (3, 5)
        println("  HCP binary n=$n  (2^$(2n) = $(2^(2n)) bitmap slots — 2 dset sites)")
        print("    $(rpad(":exhaustive", 26))")
        b = @benchmark enumerate($p_hcp, $s_hcp;
                                 supercells = VolumeRange($n:$n)) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
        print("    $(rpad(":recursive_stabilizer", 26))")
        b = @benchmark enumerate($p_hcp, $s_hcp;
                                 supercells = VolumeRange($n:$n),
                                 concentration = $cr_hcp,
                                 algorithm = :recursive_stabilizer,
                                 partition_threshold = 1_000_000,
                                 skip_resource_check = true) samples=5 evals=1
        println(BenchmarkTools.prettytime(minimum(b).time),
                "  (", BenchmarkTools.prettymemory(minimum(b).memory),
                ", ", minimum(b).allocs, " allocs)")
    end
end

# ============================================================================
# Section 6 — fixed-concentration at scale (:multinomial vs :recursive_stabilizer).
#
# Section 2 measured the two at FCC binary n=4/8/12 — roughly tied (the
# bitmap edges out the tree by ~10% at n=12). Section 6 extends the curve
# to n=14/16/18/20 where the multinomial bitmap is bigger but still fits
# in `default_memory_budget` (`:auto` keeps picking `:multinomial`). The
# question this answers: does the v0.3 "tree wins" finding from Section 5
# (full sweep) carry over to single fixed concentrations at large bitmap
# sizes, or do the bitmap's constants compound?
#
# Result (2026-05-23): the bitmap's O(1) random-access advantage compounds
# as the multinomial coefficient grows. At fixed 50% concentration:
#   n=14 7:7    bitmap 2.2× faster, 0.7× memory
#   n=16 8:8    bitmap 3.5× faster, 0.5× memory
#   n=18 9:9    bitmap 5.2× faster, 0.3× memory
#   n=20 10:10  bitmap 6.2× faster, 0.2× memory
# Confirms `:auto`'s 80%-of-budget pivot (`_multinomial_bitmap_fits`) — keep
# bitmap as long as it fits, then switch to tree.
# ============================================================================

println()
println("Section 6 — fixed-concentration at scale (:multinomial vs :recursive_stabilizer)")
println("-"^78)

let
    p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    s = Sites(p, [0, 1])
    # n=20 10:10 takes ~10 s for multinomial and ~55 s for tree on Apple M1;
    # keep the case list reasonable for a manual bench run.
    for (n, a, b) in ((14, 7, 7), (16, 8, 8), (18, 9, 9))
        c = concentration_count([a, b]; n_total = n)
        println("  FCC binary n=$n $(a):$(b)  (multinomial C = $(Enumlib.multinomial_count([a, b])))")
        for alg in (:multinomial, :recursive_stabilizer)
            print("    $(rpad(":$alg", 26))")
            bm = @benchmark enumerate($p, $s; supercells = VolumeRange($n:$n),
                                       concentration = $c, algorithm = $alg,
                                       skip_resource_check = true) samples=3 evals=1
            println(BenchmarkTools.prettytime(minimum(bm).time),
                    "  (", BenchmarkTools.prettymemory(minimum(bm).memory),
                    ", ", minimum(bm).allocs, " allocs)")
        end
    end
end

println()
println("="^78)
println("Done.")
