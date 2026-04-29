# Enumlib.jl — pre-refactor research

Living document. Built up phase by phase. Each phase ships a self-contained section; the **Status** column in the plan below is the source of truth for progress. Open questions accumulate at the bottom of each phase; the final phase rolls them up.

---

## Phase 0 — Plan

### Sources to digest

**Local code:**
- Fortran `enumlib` at `~/Drive/Work/codes/enumlib/` — ~8.5K LOC across `src/` plus an `aux_src/` of auxiliary tools/Python wrappers, `wrap/` for Python bindings, `support/` with internal-doc PDFs (interior_points, multiperms, multilattice_dset_mapping, cRangeAdjustment), `tests/`.
- Julia `Enumlib.jl` at `~/Drive/Work/codes/Enumlib.jl/` — post-split, contains the enumeration half of the former JuCE.jl plus the migrated group/coloring utilities.

**Papers (locally available):**
- Hart & Forcade, *PRB* **77**, 224115 (2008) — original derivative-structure algorithm.
- Hart & Forcade, *PRB* **80**, 014120 (2009) — multilattices / HCP.
- Hart, Nelson & Forcade, *Comp. Mat. Sci.* **59**, 101 (2012) — fixed concentration.

**Papers to fetch:**
- Morgan, Hart & Forcade, *Comp. Mat. Sci.* **136**, 144 (2017) — recursive-stabilizer enumeration. URL: http://msg.byu.edu/docs/papers/recStabEnumeration.pdf.
- Atsuto Seko, "fast deduplication for enumerated lists" — exact citation TBD; user described the topic but not the title. The local Mendeley copy of *Seko, Koyama, Tanaka 2009* is on cluster expansion, not enumeration deduplication, so almost certainly a different paper. Will hunt in Phase 8.

**Out of scope (per user):**
- Arrow enumeration. Niche, unused; no Julia reimplementation.

### Phasing

| # | Phase | Status | Notes |
|---|---|---|---|
| 1 | Inventory + plan (this section) | in progress | Sign-off requested before Phase 2. |
| 2 | Fortran enumlib codebase digest | not started | Use Explore subagent for breadth; I synthesize. |
| 3 | Current Julia Enumlib state + Fortran→Julia delta | not started | Mostly a writeup of what we already have. |
| 4 | Paper digests (Hart-Forcade 2008, 2009, 2012; Morgan-Hart-Forcade 2017) | not started | One paper per pass. Read PDFs locally; fetch 2017 from URL. |
| 5 | Algorithmic dispatch strategy | not started | How the public API decides which algorithm to invoke. |
| 6 | Data-structure design proposals | not started | Replacing `enumStr`; staging structs across the workflow. |
| 7 | Misuse / scale-safety mechanisms | not started | Pre-flight estimators, `BigInt`, bit-hash dedup, soft caps. |
| 8 | External literature survey | not started | The "big ask." Heuristic pass. Includes the Seko paper hunt. |
| 9 | Pymatgen integration analysis | not started | What's needed to drop in as a replacement. |
| 10 | Performance + regression testing in CI | not started | Persisted benchmarks, PR-time regression catches. |
| 11 | DFT / IAP output formats | not started | POSCAR is partial; survey the rest. |
| 12 | Open questions + final synthesis | not started | Roll-up; what to build first. |

I'll mark each row as it advances and link to the corresponding section heading. Each completed phase gets its own commit so the document grows in reviewable chunks.

### Pacing

- Each phase ends with a check-in. I won't blow through twelve phases without surfacing.
- Phases 2 and 8 are the biggest. I'll likely split each across multiple turns.
- Phases 5–7, 9–11 are design-leaning rather than excavation; they should be quicker per phase but produce the highest-value sections of the document.

### Things I want to confirm before deep work

1. **Reordering.** I'd default to the order above (excavate sources, then synthesize). Push back if you want, e.g., the data-structure proposal first because it's blocking other decisions.
2. **The Seko paper.** When you have a moment, point me at the citation if you find it — I can do a citation-graph search but a direct pointer saves real time.
3. **Pymatgen scope.** Phase 9 has two natural depths: (a) document the surface area of pymatgen's wrapper and what a drop-in would need to match; (b) actually prototype the swap. I'd plan for (a) only in this research phase; (b) becomes its own work item after the refactor lands.
4. **Skipped pieces.** Beyond arrow enumeration, anything else from the Fortran code I should explicitly mark as "not bringing forward"? Examples that may or may not deserve cuts: the Polya driver (`driver_polya.f90`), `make2Dplot.f90` and other aux tools in `aux_src/`, the `wrap/` Python bindings (Julia gets new bindings via PyJulia/JuliaCall, not these), the `compare_two_enum_files.f90` aux (probably worth porting as a test utility, but later).

---

## Phase 1 — Inventory: detailed

### Fortran enumlib source layout

`src/` files and approximate line counts (already gathered):

| File | LOC | Role (provisional) |
|---|---|---|
| `derivative_structure_generator.f90` | 1607 | Top-level orchestrator. Module containing `gen_multilattice_derivatives` driver and many helpers. |
| `labeling_related.f90` | 1773 | Coloring/labeling enumeration logic. |
| `enumeration_utilities.f90` | 1325 | Utilities used across the pipeline. |
| `tree_class.f90` | 864 | Recursive-stabilizer tree (Morgan 2017 algorithm). |
| `io_utils.f90` | 610 | Read/write of `struct_enum.out`, input files, etc. |
| `sorting.f90` | 280 | Sort utilities. |
| `enumeration_routines.f90` | 175 | Helpers split out from the orchestrator (per HISTORY.md, ongoing cleanup). |
| `arrow_related.f90` | 133 | Arrow enumeration. **Not porting.** |
| `enumeration_types.f90` | 64 | Type/struct definitions. |
| `enumeration_routines.xml`, `*.xml` | — | Code-gen / API spec metadata (FORD?). |
| `driver.f90` | 41 | Default CLI driver. |
| `driver_polya.f90` | 41 | Pólya-counting driver — counts enumerations without generating them. |
| `spacegroup.f90` | 27 | Wrapper around `symlib`. |

Plus:
- `aux_src/` — Python wrappers (`Enumerate.py`, `makeStr.py`), Fortran utilities (`compare_two_enum_files.f90`, `find_structure_in_list.f90`, `HNF_counter.f90`, `HNF_profiler.f90`, `make2Dplot.f90`, `makePerovStr.f90`, `makeStr.f90`, `makeStr2d.f90`, `random_lattice_driver.f90`).
- `support/` — internal-doc PDFs (algorithmic notes).
- `wrap/` — Python bindings (cwrapper.f90).
- `symlib/` — symmetry library dependency (Fortran).
- `tests/` — unit tests.
- `HISTORY.md` — version history with embedded design notes; the 2.0.0 entry in particular describes the "inactive sites" overhaul, which is a substantial undertaking the Julia code does *not* carry forward yet.

### Julia Enumlib source layout (current)

(Gathered earlier in this session.)

| File | LOC | Role |
|---|---|---|
| `src/Enumlib.jl` | ~317 | Module file. Defines `cellRadius`, group/coloring/cluster utilities, includes the rest. |
| `src/LatticeColoringEnumeration.jl` | 287 | HNF + coloring enumeration core. |
| `src/LatticeEnumeration2D.jl` | 481 | 2D variant; standalone submodule, NOT included by `Enumlib.jl` by default (own deps: Plots, SmithNormalForm, StaticArrays). |
| `src/CEdataSupport.jl` | 120 | `enumStr` struct + `readStructenumout` / `readStrIn` / `readEnergies`. |
| `src/clusterequvi.jl` | 34 | `shiftToOrigin`, `isEquivClusters`. |
| `src/radiusEnumeration.jl` | 123 | Radius-bounded HNF enumeration (5 functions). |
| `scratch/readPOSCAR.jl` | 127 | VASP POSCAR reader — has top-level scratch; not loaded. |
| `scratch/makePOSCAR.jl` | 115 | VASP POSCAR writer — has top-level scratch + uses captured global `A`; not loaded. |
| `test/runtests.jl` | — | Coloring + HNF tests. 9/9 pass. |
| `test/runtests2D.jl` | 139 | 2D-side tests; runs separately. |

Total Julia LOC: well under 2K, vs. 8.5K Fortran. The gap is mostly missing functionality, not just terseness — features the Julia version doesn't have at all (concentration restrictions, site restrictions, multilattice handling, recursive-stabilizer tree, displacement directions, much I/O).

### Internal-doc PDFs in `enumlib/support/`

These are gold for understanding the math; will dig into them in Phase 2.

- `interior_points.pdf` — finding interior points of a supercell.
- `interior_points_reciprocal_space.pdf` — same in reciprocal space (k-point grids).
- `multiperms.pdf` — Forcade's "multipermutations" (combinatorial counting underlying the labeling enumeration).
- `multilattice_dset_mapping_writeup.pdf` — the dset mapping in the multilattice algorithm.
- `notes_cRangeAdjustment.pdf` — notes on the concentration-range adjustment in the fixed-concentration algorithm.

---

*(Sections for Phases 2–12 will be appended below as they're produced.)*
