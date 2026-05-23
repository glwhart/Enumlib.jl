# Enumlib benchmark suite

Wall-clock and allocation benchmarks for the four enumeration algorithms
(`:exhaustive`, `:multinomial`, `:recursive_stabilizer`,
`:multinomial_restricted`) plus the Pólya counter. Two purposes:

1. **Lock per-algorithm timings** as regression checkpoints. Cross-grep
   committed results files to spot when a refactor slows things down.
2. **Cross-compare the algorithms** on the cases where they're directly
   comparable (fixed-concentration single-lattice; Regime-C multilattice),
   to settle whether one dominates the others in practice.

## Running

From the repo root:

```bash
julia --project=bench bench/runbench.jl
```

To capture results to a file for git-tracking:

```bash
julia --project=bench bench/runbench.jl > bench/results-$(date +%Y%m%d).txt
```

The bench `Project.toml` declares `Enumlib` and `BenchmarkTools` only.
First run will instantiate; subsequent runs use the cached `Manifest.toml`.

## What's covered

| Section | Case | Algorithms | Status |
|---|---|---|---|
| 1 | FCC binary, unrestricted, n=4/8/12 | `:exhaustive` | works |
| 2 | FCC binary, fixed concentration, n=4/8/12 | `:exhaustive`, `:multinomial`, `:recursive_stabilizer` | works — direct cross-comparison |
| 3 | HCP / Diamond, unrestricted, various n | `:exhaustive` | works (R50.2b) |
| 4 | Regime C: zinc-blende (dense mask) + half-Heusler Y=Z={2} (sparse mask), n=2/3 | `:multinomial_restricted` vs `:recursive_stabilizer` | works — chunks 6.5a/6.5b/6.5c head-to-head |
| 5 | Full-sweep (all concentrations): FCC binary/ternary, HCP binary | `:exhaustive` vs `:recursive_stabilizer` (via full `ConcentrationRange`) | works |
| 6 | Fixed-concentration at scale: FCC binary n=14/16/18 at 50% | `:multinomial` vs `:recursive_stabilizer` | works — validates the 80% threshold |

The Section 4 numbers settle why `:auto` picks `:recursive_stabilizer` for
Regime C: on the dense zinc-blende case `:recursive_stabilizer` is ~9× faster
than `:multinomial_restricted` at n=3 (433 μs vs 3.8 ms); on the sparse
half-Heusler case the gap widens to ~60× (380 μs vs 22.8 ms) because the
bitmap iterates the full multinomial space while most slots fail the
site_mask check. A tree-walk pruning variant of `:multinomial_restricted`
is queued for v0.3.

Section 5 (added 2026-05-22) is the surprise: `:recursive_stabilizer` over
a full `ConcentrationRange` beats `:exhaustive` at every case measured —
~2× faster and ~half the memory at FCC binary n=12 (280 ms / 429 MiB vs
497 ms / 1.05 GiB). The tree visits the same coloring space split into
per-concentration partitions, but per-branch pruning means it never
materializes the full k^n bitmap. Acted on in v0.3.0: `:auto` now picks
the tree for unrestricted enumeration too.

Section 6 (added 2026-05-23) is the *counter*-surprise: for a *single*
fixed `Concentration`, `:multinomial` beats `:recursive_stabilizer` —
and the gap widens with n. At FCC binary 50%:
n=14 7:7 the bitmap is 2.2× faster; n=18 9:9 it's 5.2× faster and uses
0.3× the memory. The bitmap's O(1) random-access advantage compounds.
Confirms the v0.3.0 `_multinomial_bitmap_fits` 80%-of-budget threshold is
well-calibrated: keep the bitmap as long as it fits, then switch to the
tree. No tuning needed.

## When to extend

- **New algorithm landed** → add a row to Section 2 / 3 comparing it against
  the existing ones on the same cases.
- **Hotspot work** → after a change targeting a specific allocation pattern
  or inner loop, re-run and grep the results files for the affected case.
- **Cross-lattice generality** → add a Section showing BCC / simple-cubic /
  tetragonal / non-cubic cases when we want to confirm the per-algorithm
  timings track the lattice's point-group size.

## Notes on methodology

- `samples = 5, evals = 1` — we want minimum-time-over-a-handful-of-runs,
  not statistical confidence. These cases run long enough (ms+) that
  GC noise dominates run-to-run variance; 5 samples is plenty.
- Warmup: the script touches every algorithm before timing so JIT
  specializations happen up-front.
- **Fortran cross-comparison** is *not* in this script — see the
  "Performance baseline" section of `docs/notes/v0.2-plan.md` for the
  Julia-vs-Fortran exhaustive table (2026-05-09).

## Followups

- **Flame graphs.** No profile-instrumented run is committed yet; this
  script captures wall-clock and allocation summaries only. For hotspot
  hunting, the typical flow is `using Profile; @profile run_case(); ...`
  with `ProfileView.@profview` or PProf.jl as the viewer.
- **Allocation profiling.** Use `Profile.Allocs.@profile` + a viewer like
  PProf or just `Profile.Allocs.fetch()` to see which lines allocate.
- **Cross-Fortran for site-restricted.** Section 4 of the Julia suite is
  now self-contained (chunks 6.5a/6.5b/6.5c). A Fortran cross-check on the
  same perovskite/zinc-blende/half-Heusler corpus would be a useful sanity
  point — Fortran enumlib's bitmap (`enum_method = 1`) vs tree
  (`enum_method = 2`) on the same inputs.
