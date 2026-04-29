# Enumlib.jl — pre-refactor research

Living document. Built up phase by phase. Each phase ships a self-contained section; the **Status** column in the plan below is the source of truth for progress. Open questions accumulate at the bottom of each phase; the final phase rolls them up.

---

## Phase 0 — Plan

### Design principles (added in response to your comments at lines 103, 124)

Two strong notes you gave on the structure question, promoted to first-class principles for the rest of this work:

1. **The Fortran file divisions are advisory at best.** Some have real conceptual justification (e.g., separating labeling combinatorics from supercell geometry); others are quick-and-convenient. When I describe the Fortran layout in Phase 2, I'll flag which divisions look load-bearing and which look incidental. Phase 6 (data structures) will design from first principles, using Fortran's organization as evidence of *what concepts exist*, not as a template.

2. **The current Julia layout is not a baseline either.** The existing files (`LatticeColoringEnumeration.jl`, `clusterequvi.jl`, `CEdataSupport.jl`, etc.) accreted during a "testing/experimenting" period. Treat them as content (the algorithms inside are correct and load-bearing) but not as structure (the divisions don't reflect deliberate design). Phase 3's gap analysis will compare *capabilities*, not file shapes.

The practical consequence: the data-structure design (Phase 6) and the public API design (Phase 5 dispatch) get to be opinionated, even if they cut across both prior layouts.

### Sources to digest

**Local code:**
- Fortran `enumlib` at `~/Drive/Work/codes/enumlib/` — ~8.5K LOC across `src/` plus an `aux_src/` of auxiliary tools/Python wrappers, `wrap/` for Python bindings, `support/` with internal-doc PDFs (interior_points, multiperms, multilattice_dset_mapping, cRangeAdjustment), `tests/`.

> **Claude:** Agreed. Plan for the algorithm-related PDFs (everything in `support/` except possibly `interior_points_reciprocal_space.pdf`, which is k-point-grid material that's more peripheral — but I'd lean toward keeping it too):
> - **Mechanical migration** (Phase 1.5): copy the PDFs into a new `docs/notes/` directory in this repo and commit, so they're version-controlled with the code that implements the algorithms they describe.
> - **LaTeX-ification** (rolling, alongside Phase 2 reading): for each PDF, transcribe to LaTeX with the figures extracted as separate files. I'll annotate as I go — typically each note is dense and worth expanding inline (worked examples, references to specific Fortran subroutines or Julia functions, edge-case discussion). Build to PDF via `latexmk`. This becomes the living algorithmic documentation.
> - **Format choice:** LaTeX over markdown because these are math-heavy with cross-references, theorems, multi-line equations. Pandoc markdown's math is good enough for short notes but breaks down for the multipermutations material in particular.
> - **Rough budget:** the five PDFs are 5–15 pages each, mostly equations with prose. Transcribing each is half a day's work; I'd do them lazily as I encounter the underlying algorithms in Phase 2 rather than as a batch.
That all sounds great.

- Julia `Enumlib.jl` at `~/Drive/Work/codes/Enumlib.jl/` — post-split, contains the enumeration half of the former JuCE.jl plus the migrated group/coloring utilities.

**Papers (locally available):**
- Hart & Forcade, *PRB* **77**, 224115 (2008) — original derivative-structure algorithm.
- Hart & Forcade, *PRB* **80**, 014120 (2009) — multilattices / HCP.
- Hart, Nelson & Forcade, *Comp. Mat. Sci.* **59**, 101 (2012) — fixed concentration.

**Papers to fetch:**
- Morgan, Hart & Forcade, *Comp. Mat. Sci.* **136**, 144 (2017) — recursive-stabilizer enumeration. URL: http://msg.byu.edu/docs/papers/recStabEnumeration.pdf.

> **Claude:** Will fetch via WebFetch in Phase 1.5 and store at `papers/MorganHartForcade2017_recStabEnumeration.pdf`. Confirmed will be available before Phase 4.

- Shinohara, **Seko**, Horiyama, Ishihata, Honda, Tanaka, *J. Chem. Phys.* **153**, 104109 (2020) — "Enumeration of nonequivalent substitutional structures using advanced data structure of binary decision diagram." Note: the paper you described as "the Seko paper" has Atsuto Seko as the *second* author; Shinohara is first. The algorithmic contribution is a Binary Decision Diagram (BDD) data structure for enumeration.

> **Claude:** Found at `papers/ShinoharaEtAl_2020_BinaryDecisionDiagram.pdf` in this repo. So it's actually 2020, not pre-2020 as you thought; that aligns with this being a refinement of the original enumeration line of work rather than a foundational predecessor. Will read carefully in Phase 4 with three explicit goals:
> 1. **The algorithm itself** — what the new dedup approach does and how it would slot into Enumlib.
> 2. **Backward citation harvest** — the references in this paper are the most efficient way to discover other algorithmic improvements. I'll list each cited paper that looks relevant (anything on permutation groups, supercell enumeration, lattice deduplication, group-theoretic combinatorics) with a one-line note on why. You can pick the ones to chase.
> 3. **Terminology calibration** — I'll build a small glossary subsection (Phase 4 output) of the formal vocabulary used across all four papers. Terms like "stabilizer," "labeling," "dset," "super-periodic," "g-space coordinates" mean specific things in this literature and I want to use them precisely in the design docs.

**Out of scope (per user):**
- Arrow enumeration. Niche, unused; no Julia reimplementation.

### Phasing

| # | Phase | Status | Notes |
|---|---|---|---|
| 1 | Inventory + plan (this section) | done | Plan section committed. |
| 1.5 | Pre-flight setup | done | PDFs migrated, all five papers in `papers/`, Seko verified, glossary stub created. |
| 2 | Fortran enumlib codebase digest | not started | Use Explore subagent for breadth; I synthesize. Will flag load-bearing divisions vs incidental ones (per Design Principle 1). |
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

> **Claude:** Acknowledged — will reorder mid-stream if a phase surfaces a decision that blocks earlier work.

2. **The Seko paper.** When you have a moment, point me at the citation if you find it — I can do a citation-graph search but a direct pointer saves real time.

> **Claude:** Resolved above — `papers/ShinoharaEtAl_2020_BinaryDecisionDiagram.pdf`. Will read in Phase 4.

3. **Pymatgen scope.** Phase 9 has two natural depths: (a) document the surface area of pymatgen's wrapper and what a drop-in would need to match; (b) actually prototype the swap. I'd plan for (a) only in this research phase; (b) becomes its own work item after the refactor lands.

> **Claude:** No pushback noted, sticking with (a)-only for the research phase.

4. **Skipped pieces.** Beyond arrow enumeration, anything else from the Fortran code I should explicitly mark as "not bringing forward"? Examples that may or may not deserve cuts: the Polya driver (`driver_polya.f90`), `make2Dplot.f90` and other aux tools in `aux_src/`, the `wrap/` Python bindings (Julia gets new bindings via PyJulia/JuliaCall, not these), the `compare_two_enum_files.f90` aux (probably worth porting as a test utility, but later).

You said:
> `make2Dplot` needs to be completely replaced. We'll start from scratch later on.

Confirmed: dropping. Adding to the deferred-but-not-skipped list — we'll redesign visualization output as part of Phase 11 / a follow-on after the refactor.

> What does the polya driver do?

**Claude:** I read `driver_polya.f90` (it's tiny — 41 lines) and now understand. It's not its own algorithm; it's a thin CLI wrapper that calls the same `gen_multilattice_derivatives` routine as the regular driver, but with `polya=.true.` passed in. Inside the orchestrator that flag short-circuits the *generation* of structures and instead returns just the **count** of inequivalent enumerations — computed via the Pólya enumeration theorem (a closed-form group-theoretic counting formula for the number of inequivalent colorings under a permutation group action).
>
> Two implications worth flagging:
>
> 1. **It's exactly the pre-flight estimator we need for Phase 7 (misuse mitigation).** The user-misuse case — "I asked for an enumeration that's 10¹² structures and now my disk is full" — is *precisely* what Pólya counting prevents: you call it first, it tells you the size, and then you decide whether to actually run. Bringing this forward as a first-class API on the Julia side is high-value: e.g., `count_inequivalent(parent_lattice, k, n_max)` returning a `BigInt` count, with the option to also return a per-HNF breakdown.
> 2. **There's a hidden second algorithm in the same driver.** Line 26 reads `read(arg2, '(L1)') origCrossOutAlgorithm`, and that flag is passed through into `gen_multilattice_derivatives`. So the Fortran code has *two* enumeration algorithms with a runtime toggle: the original "crossing-out" algorithm and (presumably) the recursive-stabilizer tree from Morgan 2017. This affects Phase 5 (dispatch strategy) — we have at least two known algorithms to dispatch between, and the right Julia API surface should make the choice explicit (or automatic based on input characteristics) rather than a boolean flag.

You also said:
> The comparison code is really important for comparing enumerations that were done at different versions of the code, or with different inputs that might be practically equivalent. We will need to have this functionality. We can rethink the design though, if this version is not up to scratch.

Confirmed: porting `compare_two_enum_files.f90` is on the bring-forward list. From the HISTORY.md context (the SNF-change saga in 2.0.3), this routine had to handle automorphisms induced by SNF non-uniqueness, label permutations, and complementary cases — the kind of subtleties that take "literally months" to get right. So the existing logic is hard-won; I'll digest it in Phase 2 and recommend in Phase 6 / Phase 11 whether to port it as-is or redesign around a cleaner data representation. The functionality stays either way.

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


The file structure and divisions in the original code may have good justification, but some also may have just been quick and convenient. Let's think deeply about conceptual groupings and divisions in the new code, learning from the good things in the original code but not letting it keep us from better choices where appropriate.

> **Claude:** Promoted to **Design Principle 1** at the top of this doc. Concretely it'll show up in Phase 2 as flags on each Fortran file ("conceptually load-bearing" vs "incidental grouping"), and in Phase 6 as a green-field structural design rather than a port.

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

The layout for the Julia code should not be considered as well decided or well thought out. This could was developed mostly in "testing" and "experimenting" mindset. There was no deep design thinking in its development. Let's take time here and do it right, keeping all the research in mind as we go, especially the full functionality of the old code and algorithmic improvements turned up by reading papers.

> **Claude:** Promoted to **Design Principle 2** at the top of this doc. Phase 3's gap analysis will be capability-vs-capability (what the Fortran does that the Julia doesn't), not file-vs-file. Phase 6 won't take the existing module/struct names as given.


### Internal-doc PDFs in `enumlib/support/`

These are gold for understanding the math; will dig into them in Phase 2.

- `interior_points.pdf` — finding interior points of a supercell.
- `interior_points_reciprocal_space.pdf` — same in reciprocal space (k-point grids).
- `multiperms.pdf` — Forcade's "multipermutations" (combinatorial counting underlying the labeling enumeration).
- `multilattice_dset_mapping_writeup.pdf` — the dset mapping in the multilattice algorithm.
- `notes_cRangeAdjustment.pdf` — notes on the concentration-range adjustment in the fixed-concentration algorithm.

We should not only preserve these but convert them to latex files so we can annotate and expand them. They can be somewhat terse and we should make them more digestible.

> **Claude:** Plan committed at the top under the PDF migration response. To recap the concrete shape: PDFs go to `docs/notes/` first (Phase 1.5, mechanical, fast); LaTeX transcription happens lazily as I encounter each algorithm in Phase 2. Each transcribed note ends up at e.g. `docs/notes/multiperms.tex` with the figures extracted as separate files, builds via `latexmk` to a refreshable PDF in the same directory. As I add commentary, expansions, worked examples, and cross-references to the implementing code, those become commits with diffs you can review — much better signal than "I rewrote the whole PDF."

---

## Phase 1.5 — Pre-flight setup

Mechanical work that should be done before Phase 2 deep-reading begins, so we have all the source material and references in one place. Each item is small.

| Task | Status | Notes |
|---|---|---|
| Migrate algorithm PDFs from `~/Drive/Work/codes/enumlib/support/` → `docs/notes/` | done | 5 files copied: interior_points, interior_points_reciprocal_space, multiperms, multilattice_dset_mapping_writeup, notes_cRangeAdjustment. |
| Fetch Morgan, Hart & Forcade 2017 (recStabEnumeration) → `papers/` | done | Was blocked by stale URL — `msg.byu.edu` is the old domain; `bsg.byu.edu` is the current one. Fetched from `https://bsg.byu.edu/docs/papers/recStabEnumeration.pdf`. PDF v1.7, 11 pages. |
| Confirm Seko 2020 PDF readable | done | `papers/ShinoharaEtAl_2020_BinaryDecisionDiagram.pdf`, valid PDF v1.4, 10 pages, 2.84 MB. |
| Quick scan of `papers/` for anything else relevant | done | Only Seko 2020 there at the moment. Empty otherwise. |
| Stub `docs/notes/glossary.tex` | done | Skeleton with stub entries grouped by topic. Populated during Phase 4. |

Phase 1.5 is done modulo the Morgan 2017 blocker, which is on the user's plate.

---

*(Sections for Phases 2–12 will be appended below as they're produced.)*
