# Enumlib benchmark suite

Wall-clock and allocation benchmarks for the three enumeration algorithms
(`:exhaustive`, `:multinomial`, `:recursive_stabilizer`) plus the Pólya
counter. Two purposes:

1. **Lock per-algorithm timings** as regression checkpoints. Cross-grep
   committed results files to spot when a refactor slows things down.
2. **Cross-compare the algorithms** on the cases where they're directly
   comparable (fixed-concentration single-lattice), to settle whether one
   dominates the others in practice.

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
| 2 | FCC binary, fixed concentration, n=4/8/12 | all three | works — direct cross-comparison |
| 3 | HCP / Diamond, unrestricted, various n | `:exhaustive` | works (R50.2b) |
| 4 | Per-site restricted (Regime C, perovskite-style) | none yet | gate fires (`ArgumentError`); awaits chunk 6.5 |

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
- **Cross-Fortran for site-restricted.** When chunk 6.5 lands (or when
  `:recursive_stabilizer` is extended to handle per-site allowed labels),
  rerun Fortran enumlib's bitmap (`enum_method = 1`) and tree
  (`enum_method = 2`) on the same perovskite-style problem to settle
  which Julia algorithm to invest in further.
