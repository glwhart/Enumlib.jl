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
# Section 4 — per-site restricted labels (Regime C — perovskite-style).
# Currently NOT supported by any Julia algorithm — :multinomial_restricted is
# queued for chunk 6.5 and :recursive_stabilizer doesn't yet branch on per-site
# allowed sets (queued).
#
# This section just confirms the gate fires and records the error — when one
# of those algorithms lands, we'll switch this to a real timing comparison.
# ============================================================================

println()
println("Section 4 — per-site restricted (Regime C; currently gated)")
println("-"^78)

let
    # Diamond-style multilattice where one sublattice is fixed (inactive).
    fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
    p = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
    sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),       # binary
                   Site([0.25, 0.25, 0.25], [0])])       # fixed
    print("  Diamond w/ inactive 2nd sublattice: ")
    try
        enumerate(p, sites; supercells = VolumeRange(2:2))
        println("UNEXPECTEDLY SUCCEEDED — gate may be wider than expected")
    catch e
        # Trim to just the first sentence — full ArgumentError includes
        # a long suggestion list.
        msg = sprint(showerror, e)
        first_line = first(split(msg, '.'))
        println("ArgumentError (expected): ", first_line, ".")
    end
end

println()
println("="^78)
println("Done.")
