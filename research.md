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
| 2 | Fortran enumlib codebase digest | done | Architecture + per-file digest + data types + two-algorithm toggle + inactive-sites overhaul + cross-cutting concerns + I/O formats. See Phase 2 section below. |
| 3 | Current Julia Enumlib state + Fortran→Julia delta | done | Capability inventory + gap analysis. See Phase 3 section below. |
| 4 | Paper digests (Hart-Forcade 2008, 2009, 2012; Morgan-Hart-Forcade 2017; Shinohara et al. 2020) | done | All five papers digested. |
| 5 | Algorithmic dispatch strategy | done | Public API surface + auto-dispatch decision tree + 5-mode algorithm catalogue + pre-flight gate + Fortran-comparison table. See Phase 5 section below. |
| 6 | Data-structure design proposals | done | 12-type catalog + invariants + construction APIs + Fortran↔Julia comparison + 7 open questions. See Phase 6 section below. |
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


## Phase 2 — Fortran enumlib codebase digest

Source: `~/Drive/Work/codes/enumlib/src/` (~8.5K LOC) plus `aux_src/`. Digest produced via Explore subagent + my synthesis. Path/line citations throughout; spot-check anything that looks surprising.

### 2.1 Top-level architecture

Two thin CLI drivers (`driver.f90`, `driver_polya.f90`, 41 lines each) feed everything into one monolithic kernel: **`gen_multilattice_derivatives`** at `derivative_structure_generator.f90:1215-1512`. The drivers differ only in passing `polya=.true./false.` and whether they thread the `origCrossOutAlgorithm` flag. Polya counting reuses the same kernel, just short-circuiting before generation.

The kernel runs five phases per invocation:

1. **Inactive-site removal** — `make_inactive_table` (`enumeration_routines.f90:93-150`) extracts the active subset of sites (>1 allowed label, no equivalence). Inactive sites are stashed and re-inserted post-enumeration.
2. **Input validation + output file open** (`derivative_structure_generator.f90:1271-1357`) — write the `struct_enum.out` header.
3. **Symmetry analysis loop over volumes** (`derivative_structure_generator.f90:1365+`) — for each volume `ivol ∈ [nMin, nMax]`: generate all HNFs → remove symmetry duplicates → SNF → build rotation-permutation lists.
4. **Concentration enumeration loop** (per volume, per concentration) — algorithm dispatch (see §2.4) → write enumerated structures.
5. **Output finalization** — close the file.

The whole flow is in one ~300-line function with `[TODO]` comments admitting it should be split into helpers (line 1275). This is the single biggest target for restructuring in the Julia rewrite.

### 2.2 Per-file digest with load-bearing classification

Per **Design Principle 1**, files are flagged as either *load-bearing* (the file represents a coherent concept and should likely survive as a unit), *incidental* (the file is just where some functions ended up — recombine freely), or *conditional* (only load-bearing if the feature is brought forward).

| File | LOC | Role | Classification | Notes |
|---|---|---|---|---|
| `derivative_structure_generator.f90` | 2000 | HNF enumeration, symmetry reduction, kernel orchestration | **Load-bearing for HNF/symmetry, incidental for orchestration** | The HNF/SNF/perm-list functions are tightly coupled and belong together. The orchestrating `gen_multilattice_derivatives` should be split into a sequence of helpers. |
| `labeling_related.f90` | 1800 | Labeling enumeration (both algorithms) + output writer | **Load-bearing, but split** | Two algorithms (enum3 crossing-out, enum4 tree) share this file; they should be separate Julia modules with a thin dispatcher. `write_labelings` is intertwined with enum3 — extract. |
| `tree_class.f90` | 900 | OO `tree` type for Morgan 2017 algorithm | **Load-bearing** | Cleanest file in the codebase. The OO design carries over well to a Julia struct + methods. |
| `enumeration_utilities.f90` | 1400 | `map_enumStr_to_real_space`, comparison, POSCAR I/O, finding structures | **Load-bearing for mapping; incidental for the rest** | The (HNF, labeling) → real-space mapping is core. Comparison and structure-search are separate concepts that wandered in. |
| `enumeration_types.f90` | 65 | Derived type definitions | **Load-bearing** | Small, focused. The active types (`RotPermList`, `opList`, `derivStruct`, `tree`-related) carry the data model. Some (`cryst`, `derivCryst`) are vestigial scaffolding. |
| `io_utils.f90` | 610 | `struct_enum.in/out` parsing/writing | **Load-bearing if the file format is preserved** | Format is described in §2.7. Quirks: backspace-and-rewind passes, fragile `:`/`/` label parsing. |
| `enumeration_routines.f90` | 175 | Inactive-site helpers (`make_inactive_table`, `adjust_crange_for_inactive_sites`, `getSpaceGroup_activeSitesOnly`) | **Load-bearing** (post-2.0.0 feature) | Per HISTORY.md the 2.0.0 overhaul made this central. Currently small but conceptually distinct. |
| `sorting.f90` | 280 | Heapsort, sort_concs | **Incidental** | Generic; Julia has stdlib equivalents. |
| `spacegroup.f90` | 27 | Standalone CLI demo | **Skip** | Demo-only. |
| `arrow_related.f90` | 133 | Arrow enumeration | **Skip per user** | Out of scope. |
| `driver.f90`, `driver_polya.f90` | 41 each | CLI entry points | **Replace** | Drivers become Julia functions with kwargs. |
| `aux_src/compare_two_enum_files.f90` | 450 | Compare two outputs under SNF automorphisms + label perms | **Load-bearing for testing/regression** | Hard-won logic per HISTORY.md 2.0.3 ("literally took months"). Bring forward semantics, redesign API. |
| `aux_src/HNF_counter.f90` | 94 | Count + characterize HNFs | **Incidental** | Could become a small public counting API. |
| `aux_src/HNF_profiler.f90` | 200 | HNF analysis | **Incidental** | Same. |
| `aux_src/makeStr.f90` | 300 | POSCAR writer with spectator-atom support | **Conditional** | POSCAR output is needed; the file is a starting point but `scratch/makePOSCAR.jl` is closer to the Julia we want. Cherry-pick the spectator-atom logic. |
| `aux_src/find_structure_in_list.f90` | 33 | Test driver | **Incidental** | Reproduce as a Julia test helper. |
| `aux_src/random_lattice_driver.f90` | 30 | Test/demo | **Incidental** | Reproduce in Julia tests if needed. |
| `aux_src/makeStr2d.f90`, `makePerovStr.f90` | ~200 ea | Specialized POSCAR writers | **Skip** | 2D plotting / perovskite demos; redesign output later. |
| `aux_src/make2Dplot.f90` | — | 2D plotting | **Skip per user** | Will be replaced from scratch. |
| `aux_src/convert_structures_to_enumformat.f90` | 2000 | POSCAR → struct_enum.out | **Conditional** | Inverse of `makeStr`. Needed if we keep the file format. |

### 2.3 Data types catalog

All in `enumeration_types.f90` unless noted. The starred ones are central; the rest are containers or dead.

| Type | Fields | Purpose | Status |
|---|---|---|---|
| **`RotPermList`*** | `perm(:,:)`, `RotIndx(:)`, `nL`, `v(:,:,:)` | Per-HNF: rotations that fix the supercell, the d-vector permutation each induces, and the lattice shifts to bring rotated d-vectors back into the first cell | Threaded through almost everything. The single most important data structure. |
| **`opList`*** | `rot(3,3,nOp)`, `shift(3,nOp)` | Space-group rotations and translations | Essential. |
| **`derivStruct`*** | `diag(3)`, `pLat`, `dVec`, `nD`, `HNF`, `L`, `n`, `labeling`, `conc` | A single enumerated structure (output unit) | Active; output uses this. |
| **`tree`*** | `colors(:)`, `k`, `n`, `G`, `A`, `Gsize(:)`, `loc(:)`, `branches(:)`, `base(:)`, `unique`, `done`, `nArrows`, `color_map` | Recursive-stabilizer enumeration tree (Morgan 2017) | In `tree_class.f90`. Carries enum4 state. |
| `GroupList` | `layer(:)` of `permList` | Stabilizer group per tree layer | Used inside `tree`. |
| `permList` | `perms(:,:)` ptr | A list of permutations | Container. |
| `LabelRotationList` | `lr(:)` | Index list for label rotations | Rarely used. |
| `cryst` | `LV(3,3)`, `bas(:,:)`, `aTyp(:)` | Real-space crystal | **Dead** — comment says "Not used yet. Not clear that it is useful." |
| `derivCryst` | `diag(3)`, `pLat`, `HNF`, `L`, `labeling` | Group-space enumeration unit | **Dead** — same comment. |

For Phase 6 (data structure design), the live set is `{RotPermList, opList, derivStruct, tree}` plus the array families `{HNF, SNF, L}`. `cryst`/`derivCryst` are scaffolding for an unfinished refactor; ignore.

### 2.4 The two algorithms — when each fires

The `origCrossOutAlgorithm` flag flows from the driver into `gen_multilattice_derivatives` and is checked at `derivative_structure_generator.f90:1475-1488`. The dispatch logic (paraphrased):

```fortran
if origCrossOutAlgorithm
   .or. (any(site_res == 0) .and. multinomial(...) < max_binomial .and. .not. arrows)
then
   call generate_permutation_labelings(...)   ! enum3, "crossing-out"
   call write_labelings(...)
else
   call recursively_stabilized_enum(...)      ! enum4, Morgan 2017 tree
end if
```

Two algorithms, with three knobs deciding which: explicit override, presence of site restrictions, and a hardwired `max_binomial = 1E10` threshold (line 1268).

| | enum3 — `generate_permutation_labelings` | enum4 — `recursively_stabilized_enum` |
|---|---|---|
| Strategy | Mixed-radix odometer over labelings; bitstring-marker heuristic for degeneracy | Recursive enumeration tree; stabilizer group at each layer prunes equivalents |
| File:lines | `labeling_related.f90:310-512` + `write_labelings 587-811` | `labeling_related.f90:58-270` (driver) + `tree_class.f90` (state) |
| Strength | Site-restricted enumerations with small multinomial; few active sites | Large multinomials, complex symmetries, arrow handling |
| Inactive sites | Handled (post-hoc by `write_labelings`) | **NOT YET IMPLEMENTED** in the tree; postprocessing only — see HISTORY.md 2.0.0 |
| Arrows | Not supported (excluded by the conditional) | Supported via arrow_group |
| Output | `write_labelings` writes to file | Writes inline as the tree is traversed |
| Degeneracy | Bitstring marker `lab` (fast, opaque) | Implicit in stabilizer-tree traversal (exact) |

The hardwired `max_binomial = 1E10` is a code smell. Per HISTORY.md 1.0.6 the previous value (2.63E14) caused overflow. The new value is conservative but still arbitrary. Phase 7 (misuse mitigation) should treat this as a pre-flight estimator decision rather than a hidden constant.

### 2.5 Inactive sites overhaul (HISTORY.md 2.0.0) — and what's still incomplete

The 2.0.0 entry overhauled the code to handle "spectator" or "inactive" sites — sites in the parent cell with only one allowed species and therefore no configurational freedom. Before 2.0.0 these were enumerated like any other site, causing combinatorial explosion. Now they're stripped out, the active set is enumerated, and the inactive labels are re-inserted before output.

**Concrete shape:**
- Two parallel d-set arrays: `dFull(:, nDFull)` and `d(:, nD)` where `nD ≤ nDFull`.
- Two parallel label arrays: `labelFull/digitFull` and `label/digit`.
- An `equivalencies(:)` array — for each site, points to its canonical site index (or to itself if non-equivalent). Tobias's earlier modification.
- An `inactives(:,:)` table — rows are `(site_index, forced_label)` pairs. Built by `make_inactive_table`.
- `adjust_crange_for_inactive_sites` (`enumeration_routines.f90:19-75`) recomputes concentration ranges to account for atoms locked into inactive sites. The arithmetic is non-trivial — see `docs/notes/notes_cRangeAdjustment.pdf`.
- `getSpaceGroup_activeSitesOnly` (`enumeration_routines.f90:152-172`) computes the space group considering only active sites by tagging inactive sites with a distinct atom type so they can't map to active sites under symmetry.

**What's incomplete:**
- enum4 (`recursively_stabilized_enum`) does NOT natively support inactive sites. Per HISTORY.md 2.0.0: *"the code has not yet been updated for the 'new' algorithm. Because this algorithm uses its own routine to write out the derivative structures, it will require modification too."* Postprocessing handles the labels, but the symmetry treatment in the tree algorithm doesn't yet reflect that some sites are locked.
- Tests for `find_site_equivalencies` are disabled — used only in UNCLE per HISTORY.md.

**Implication for the rewrite:** the inactive/equivalent site machinery is genuinely load-bearing (it's the difference between tractable and intractable enumerations for many real materials), but it's also the messiest part of the Fortran code. Phase 6 should design a clean abstraction — probably a single `Site` type that carries (position, allowed_labels, equivalent_to, inactive_label) — rather than the parallel-arrays approach.
Yes, this need a fresh look and redesign

> **Claude:** Logged as a Phase 6 priority. Tentative shape (subject to refinement when we get there): a `Site` struct carrying `(position::SVector{3}, allowed_labels::BitSet, equivalent_to::Int, inactive_label::Union{Nothing,Int})`, with `equivalent_to` enforced via Union-Find at construction so transitivity can't silently break (addresses your gotcha #5 below). The parent lattice + dset becomes a `Vector{Site}` plus the basis matrix, replacing the parallel arrays `dFull/d`, `labelFull/label`, `equivalencies`, `inactives`.

### 2.6 Concentration- and site-restricted enumeration

**Concentration ranges (`cRange`):**
- Format: `cRange(iSpecies, :)` = `[min_numerator, max_numerator, denominator]` — fraction `[min/denom, max/denom]`.
- Read from `struct_enum.in` if `concCheck=.true.`.
- Adjusted for inactive sites in `adjust_crange_for_inactive_sites` before enumeration begins.
- Per cell volume, `get_concentration_list` (`derivative_structure_generator.f90:82-160`) enumerates valid concentration partitions; per-concentration loop generates labelings.

**Site restrictions (`site_res`):**
- Built by `get_site_restrictions(label, digit, nD, site_res)` (called at `derivative_structure_generator.f90:1461`).
- `site_res(i) == 0` means site i has restricted labels (fewer than k available).
- Presence of site restrictions is one of the three knobs that selects enum3 over enum4.

The 2012 paper (HNF 2012, in `papers/`) is the reference for the fixed-concentration algorithm. Phase 4 will dig in.

### 2.7 Multilattices — the dset and interior points

A multilattice has more than one basis site per parent unit cell (HCP = 2, perovskites = 5+). The code calls this set the *dset*. Each enumerated supercell contains `n × nD` atoms.

**Three places multilattices add complexity:**

1. **Symmetry permutes the dset.** `get_dvector_permutations` (`derivative_structure_generator.f90`) computes how each rotation permutes the d-vectors. The permutation is stored in `RotPermList.perm` along with lattice shifts `RotPermList.v` to map rotated d-vectors back into the first cell.

2. **Interior points.** Mapping (HNF, labeling) → atomic positions requires enumerating "interior points" of the supercell. The math is in `docs/notes/interior_points.pdf` and the implementation is in `map_enumStr_to_real_space` (`enumeration_utilities.f90:49-123`). For an HNF with diagonal `(a, b, c)` and off-diagonal entries:
   ```
   for each d-vector iD:
       for z1 ∈ [0, a-1]:
           for z2 ∈ [⌊b·z1/a⌋, c + ⌊b·z1/a⌋ - 1]:
               for z3 ∈ ...:
                   pos = pLV·[z1,z2,z3] + d(:,iD)
   ```
   Off-by-one errors in these bounds silently miss or duplicate atoms.
   But has that ever happened? Is it a problem?

> **Claude:** Honest answer — I don't have direct evidence it has been a fielded bug. I overcalled the risk; the Fortran code's interior-points loop is well-tested at this point. The phrase was speculative ("silently miss or duplicate atoms" is the *kind* of error those bounds could produce, not one we know happened). Concrete derisking for the rewrite: write a property-based test that, for a curated set of (lattice, HNF, dset) cases, verifies (a) the right number of atoms come out (`n × n_D`) and (b) all atoms are distinct after lattice-reduction. If we get those two right, off-by-one in the loop is caught immediately. So: not a hot risk, but cheap to lock down — Phase 10 task.

3. **HNF deduplication respects the dset.** Two HNFs are equivalent only if related by a symmetry that permutes the dset *consistently* with the permutation already on each cell. See `docs/notes/multilattice_dset_mapping_writeup.pdf`.

The 2009 paper formalizes all of this. Phase 4 reads it.

### 2.8 I/O formats

#### `struct_enum.in`

```
[1]      Title (≤80 chars)
[2]      'B' (bulk/3D) or 'S' (surface/2D)
[3-5]    Parent lattice vectors (rows = vectors)
[6]      nD
[7..6+nD]  d-vectors and per-site allowed labels:
           d_x d_y d_z : 0/1     ← labels separated by '/'
[7+nD]   k (number of species)
[8+nD]   nMin nMax
[9+nD]   eps
[10+nD]  fullLab (T/F)
[11+nD]  concCheck (T/F)
  if concCheck:
    [12+nD..11+nD+k]  cRange rows: min_num max_num denom
[next]   equivalencies: nD integers (canonical site or self)
```

Fragile bits: `:`/`/` parsing, the backspace-and-rewind passes (`io_utils.f90:91-143`), labels `> k-1` indicating inactive sites.

We could rethink this format. Is it closely aligned to the real data structure of the problem? Is it the best way to pose an enumeration problem?

> **Claude:** Worth doing. The Fortran format is *operational* (it's what the CLI driver eats) rather than *semantic* (it doesn't model the enumeration problem cleanly). Specifically: it conflates parent lattice description, multilattice dset, label-allowance, equivalencies, concentration constraints, and enumeration parameters all into one freeform text file with positional sensitivity. A cleaner Julia-native posing would separate:
> 1. **Crystal structure**: `ParentLattice` (basis vectors + dset). Just geometry.
> 2. **Allowed substitutions**: `Vector{Site}` with per-site `allowed_labels` (covers active/inactive/restricted).
> 3. **Constraints**: a `Constraints` struct with `concentration_range`, `fixed_cells`, etc. — optional.
> 4. **Enumeration parameters**: `volume_range`, `algorithm`, etc. — kwargs on the entry function.
>
> The Julia call site becomes `enumerate(parent, sites, constraints; volume_range=2:10)` rather than reading a magic file. *Per the no-Fortran-compat directive in §2.10 #5:* a one-way `Enumlib.LegacyImport.read_struct_enum_in(path)` reader exists in a separate submodule for migrating existing Fortran setups, but it's not the primary API and not load-bearing.
>
> Phase 6 (data structures) and Phase 9 (pymatgen) jointly own this decision.

#### `struct_enum.out`

Echoes the input header, then a structure list:

```
# <fortpy version="3" revision="247"></fortpy>     ← version=4 if arrows
[full echoed input header]
start #tot HNF Hdegn labdegn Totdegn #size idx pg SNF HNF "Left transform" labeling [arrows]
0 1 1 1 1 1 2 1 4 1 1 1 1 1 2 3 1 1 0 0 0 1 1 0 0 0 2 00
...
```

Each row encodes index, total found, HNF index, degeneracies, volume, point-group order, SNF diagonal, HNF (9 entries), Left transform (9 entries), labeling string of length n×nD. SNF non-uniqueness means equivalent enumerations can produce different output rows — this is what `compare_two_enum_files` exists to handle.
Would it be better to store these "rows" in some sort of struct? There is lots of repeated information here. Many structures have the same SNF, or HNF, or left transform...

> **Claude:** Strong yes. The flat row format is denormalized — every structure copies its parent's HNF, SNF, and left transform. For an enumeration of $10^6$ structures sharing a few hundred HNFs, that's gigabytes of redundancy.
>
> The natural normalization for in-memory use:
>
> ```julia
> struct EnumeratedStructure
>     supercell_id::Int          # index into a separate Vector{Supercell}
>     labeling::Vector{Int8}     # length n × nD, the only per-structure data
>     hnf_degeneracy::Int        # bookkeeping
>     labeling_degeneracy::Int
> end
>
> struct Supercell                # shared across all structures with the same HNF
>     hnf::SMatrix{3,3,Int}
>     snf::SVector{3,Int}
>     left_transform::SMatrix{3,3,Int}
>     point_group_order::Int
>     translation_perms::Vector{Vector{Int}}    # cached for downstream use
>     rotation_perms::Vector{Vector{Int}}
> end
>
> struct Enumeration
>     parent::ParentLattice
>     sites::Vector{Site}
>     supercells::Vector{Supercell}             # ~hundreds typically
>     structures::Vector{EnumeratedStructure}   # ~thousands to millions
> end
> ```
>
> Memory drops by the per-supercell-multiplicity factor. Indexing a structure becomes `enum.structures[i]` and accessing its HNF is `enum.supercells[enum.structures[i].supercell_id].hnf`. Serialization uses the normalized form directly via JLD2 (or optionally HDF5) — no flattening, no custom format. *Per the no-Fortran-compat directive in §2.10 #5: pymatgen integration is via PythonCall, not a re-flattened legacy format.*
>
> This connects to your "iterator vs writer" point in §3.2.4 below — once the in-memory form is normalized, lazy generation becomes the natural API.
I like all of this. One thought to flag and reconsider later: the labeling element in EnumeratedStructure could be replaced a single Int (Big Int?) that could be regenerated into the labeling. Not sure that is efficient, but might save space. Let's flag it and rethink later.

> **Claude:** Good instinct — and it's actually exactly the perfect-hash idea (§4.1) applied to storage. Quick sketch of the trade-offs to flag for Phase 6:
>
> **What "labeling-as-Int" looks like.** A length-$n$ labeling with $k$ colors is a number in $[0, k^n - 1]$ via the base-$k$ digit hash. For fixed-concentration cases the better hash is the 2012 multinomial hash giving $[0, C-1]$ where $C = \binom{n}{a_1, \ldots, a_k}$ — much smaller. So `EnumeratedStructure.labeling` becomes a single `Int64` (or `BigInt` if it overflows) and the explicit `Vector{Int8}` is regenerated on demand.
>
> **Storage savings.** For a typical fcc binary $n=20$ structure: `Vector{Int8}` = 20 bytes per structure; one `Int64` = 8 bytes. ~2.5× reduction. For larger $n$ the gap grows: at $n=50$ binary it's 50 bytes vs 8 = 6×. For ternary the comparison is similar; the labeling is `Vector{Int8}` of length $n$ so 1 byte per site, vs an `Int64`.
>
> **When `Int64` isn't enough.** $k^n$ overflows `Int64` (which holds up to $2^{63} - 1 \approx 9.2 \times 10^{18}$) at:
> - Binary ($k=2$): $n = 63$.
> - Ternary ($k=3$): $n = 39$.
> - Quaternary ($k=4$): $n = 31$.
> - Quinary ($k=5$): $n = 27$.
>
> Past those, we need `Int128`, `BigInt`, or a packed-bits representation. For the *fixed-concentration* multinomial hash $C$, the limits are roughly 2× higher per $k$ (since $C \ll k^n$). So Int64 works for *most* practical cases; BigInt fallback for the very-large enumerations the 2020 Shinohara paper unlocks.
>
> **Cost of regenerating the labeling on demand.** Decoding an integer to a `Vector{Int8}` is $O(n)$ — fast (~50 ns for $n=20$). For most workloads (write to POSCAR, compute correlation, ...) the user will materialize the vector once anyway, so storage-as-Int + decode-on-access doesn't add real overhead.
>
> **Where it bites.** If a downstream caller iterates the same labeling many times (e.g., looping over symmetry images of the same structure), repeated decode is wasteful. Easy fix: a `materialize(s::EnumeratedStructure)` accessor that caches into a `Vector{Int8}` if needed.
>
> **Phase 6 design hooks** to keep this option open:
> - Define `Labeling = Union{Int64, BigInt}` or a small wrapper struct so we can swap representations without changing call sites.
> - Or define `EnumeratedStructure` parameterized: `EnumeratedStructure{L}` where `L` is `Vector{Int8}`, `Int64`, or `BigInt`. The dispatch at construction picks based on size.
>
> Logged as a Phase 6 design point. The current `Vector{Int8}` proposal in my normalized-output sketch above is the *conservative* default; the integer representation is a memory optimization we can opt into when the enumeration is large enough to make it worth the dispatch.

### 2.9 Tests

`~/Drive/Work/codes/enumlib/tests/` is structured as XML-driven test definitions colocated with the source files. `tests/derivative_structure_generator/` alone has 5820 directories of test cases; `enumeration_utilities/` has 10224. The format is mostly: input file → expected output file → comparison tool checks them. The unit-test runner is in `tests/unittests/test_driver.f90` (menu-driven).

Per HISTORY.md, after the 2.0.x changes many tests were re-enabled and outputs updated. The disabled `find_site_equivalencies` tests are UNCLE-only.

For the Julia rewrite: don't try to port the whole test corpus. Pick representative cases that cover (a) HNF generation correctness vs Table IV of the 2008 paper, (b) coloring counts on small FCC/BCC/HCP cases, (c) round-trip via `map_enumStr_to_real_space`, (d) concentration-restricted spot checks, (e) inactive-site spot checks, (f) compare-two-enums regression. Phase 10 (CI + perf regression) will lay this out properly.
Agree with this paragraph. Good plan.

### 2.10 Open questions and gotchas (raised by the digest, to track)

1. **Hardwired `max_binomial = 1E10`** (`derivative_structure_generator.f90:1268`) — algorithm-dispatch threshold with a magic constant.
This needs to be rethough, redesigned...

2. **enum4 inactive-site support is incomplete** — confirm via testing before relying on it for non-trivial cases.

Might sort itself out to some degree if we come up with a better representation, better data structure for inactive site handling.

3. **Bitstring labeling markers (`lab`, `lm`)** in `generate_permutation_labelings` — opaque, undocumented degeneracy heuristic. Risk surface for the rewrite.
Tell me more what you mean by this.

> **Claude:** I called them "opaque" before reading the 2012 paper. Now that I have, they're not opaque — they're just not commented in the Fortran source. Here's what they do:
>
> The 2012 paper's algorithm uses the multinomial mixed-radix hash to map each fixed-concentration configuration to an integer in `[0, C-1]` where `C = multinomial(n; a_1, ..., a_k)`. To eliminate symmetry duplicates, the code allocates a `BitVector` of length `C` (this is `lab` in the Fortran, the "labeling" markers). Initially all bits are false ("not yet visited / not in any orbit").
>
> Then it iterates `i = 0, 1, ..., C-1`:
> 1. If `lab[i]` is already true → skip; this configuration is in an orbit we've already enumerated.
> 2. Otherwise, materialize the configuration from index `i` (using the inverse hash from §3.2 of the 2012 paper). It's a unique representative of a new orbit.
> 3. For each symmetry operation `g ∈ G`, compute the index `j = hash(g · config_i)` and set `lab[j] = true`. This marks all members of the orbit as "visited."
> 4. Save configuration `i` as one unique structure; advance.
>
> So `lab` is a *visited-set* bitmap; `lm` (which I haven't traced precisely but appears similar) is presumably the same scheme for site-restricted variants where the hash isn't perfect. The "opacity" was just lack of documentation in the Fortran — the algorithm itself is clean. In Julia this becomes:
>
> ```julia
> visited = falses(C)
> for i in 0:C-1
>     visited[i] && continue
>     config = unhash(i, multinomial_descriptors)
>     push!(unique_configs, config)
>     for g in symmetry_group
>         visited[hash(g * config, multinomial_descriptors)] = true
>     end
> end
> ```
>
> Three lines once the hash + inverse are in hand. The "risk surface" I flagged is gone now that the 2012 paper has demystified the markers — it's just a vanilla orbit-marking pass.
Good catch. We'll make sure that the same opaqueness doesn't happen in the julia code. It will be well documented and commented in the code.


4. **SNF non-uniqueness** — left transform is not uniquely determined; `compare_two_enum_files` handles the resulting automorphisms. Julia rewrite needs to either nail down a canonical SNF (NormalForms.jl?) or replicate the automorphism handling. 
SNF is canonical by definition. It's the left transform that isn't unique. Not sure what effort would be necessary to enforce that. Probably easier not to rely on it and compute equivalencies. In any case, we need to think about this more.

> **Claude:** You're right — I was sloppy with the language. The SNF matrix $S$ itself (the diagonal entries $s_1 \mid s_2 \mid s_3$) is canonical given $H$. It's the left and right unimodular transforms $L, R$ in $L H R = S$ that are not unique — many $L, R$ pairs yield the same $S$. And per HISTORY.md 2.0.3, when symlib's SNF routine was updated, the produced $L$ changed even though $S$ didn't, which cascaded into different output rows for "equivalent" enumerations.
>
> The correct phrasing is "left-transform non-uniqueness," not "SNF non-uniqueness." I'll fix the wording in the Phase 2 main text and the synthesis bullet on a follow-up pass.
>
> Your second point — "probably easier not to rely on it and compute equivalencies" — is the right framing. Rather than fight to canonicalize $L$, we accept that two correct enumerations may disagree on row content and rely on `compare_two_enum_files`-style equivalence checking. That's what the Fortran code already does post-2.0.3. Phase 6 should make this an explicit design decision: **don't expose $L$ in the public output API; keep it internal to the (HNF, labeling) → real-space mapping**, and provide a structure-equivalence comparator for users who need to compare enumerations across versions.
Yes

5. **Equivalencies transitivity is unchecked** — if the user passes a non-transitive `equivalencies` array, the code silently produces wrong answers.
We need to make the new code bullet proof to that failure mode

> **Claude:** Two ways to make this bulletproof, in order of preference:
>
> 1. **Use a representation that enforces transitivity by construction.** A Union-Find / Disjoint-Set structure stores equivalence classes directly: there's no array of pointers that could disagree, just "what class is site `i` in?" — answered in nearly $O(1)$. Julia stdlib doesn't ship one, but `DataStructures.jl`'s `IntDisjointSets` works, or we write a tiny one in ~30 lines. Construction API: the user calls `add_equivalent!(sites, i, j)` and the structure handles the rest. Reading `canonical_site(sites, i)` always returns the canonical representative; it's transitively-correct for free.
> 2. **Validate at construction.** If we keep the array form for compat with the Fortran format, validate at construction time: walk the array, for each `i`, follow `equivalencies[i]` to fixed point and check that the same canonical site comes back from any starting point in the cycle. Throw a `DomainError` with a descriptive message if not.
>
> Lean: option (1). Equivalences are conceptually a partition; using a partition data structure expresses that intent and prevents the failure mode at the type level. Phase 6 design point.
I don't anticipate that we'll even want "compat with the Fortran format". Design right, go forward with confidence. Learn from the past, keep the good. Redesign the rest.

> **Claude:** This is load-bearing strategic guidance. Lifting it to a top-level **Design Principle 3** in a follow-up cleanup commit, alongside Principles 1 (Fortran file divisions are advisory) and 2 (current Julia layout isn't a baseline). Cascading consequences I want to make explicit so they don't quietly resurface later in the doc:
>
> **(a) Equivalencies (the comment you replied to).** Drop option (2) "validate at construction" — that was framed as "if we keep the array form for compat with the Fortran format." We're not. Use Union-Find natively. The user-facing API takes pairs `(i, j)` and adds them to a partition; there's no array format anywhere.
>
> **(b) The struct_enum.in / struct_enum.out file formats.** No more "compat shim" framing. The Fortran formats are reference for *understanding what existed*, not constraints on what we ship. Specifically:
> - **Reading legacy files:** a one-way migration utility. "Import a Fortran setup into Julia" is a use case for someone who has existing struct_enum.in files; it's not a long-term API. Lives in a separate submodule like `Enumlib.LegacyImport` or `Enumlib.Fortran`.
> - **Writing legacy files:** mostly not needed. Possibly useful for *generating* test cases against Fortran enumlib for the regression-comparison tooling, but that's an internal-test-only use, not a user-facing feature.
> - **The "primary" Julia format** (for serialization / persistence) is whatever's natural for our types — JLD2 by default, optional HDF5 export.
>
> **(c) Pymatgen integration.** Phase 9 simplifies. Today pymatgen's `enumlib_caller` shells out to the Fortran CLI and parses `struct_enum.out`. To *replace* that path with our Julia code, the cleanest route is:
> - Provide a Python-callable Julia API via PythonCall.jl / JuliaCall (whichever pymatgen prefers).
> - Pymatgen calls `Enumlib.enumerate(...)` directly, gets a stream of structures or an `Enumeration` object, converts to its `Structure` type.
> - No `struct_enum.out` file involved.
> - For backward-compat with users still on the file workflow, the `LegacyImport` migration utility can also generate `struct_enum.out` from our internal types — but that's a one-day tactical adapter, not a design constraint.
>
> **(d) The compare-enumerations regression utility.** Still important per your earlier note (the Fortran is "extremely strong, heavily battle tested"), but reframed: it compares our *Julia* enumeration against a Fortran-generated reference *internally* during testing. It doesn't need to be exposed to end users; it's a CI tool. Reads our internal types on one side and the Fortran `struct_enum.out` (via `LegacyImport`) on the other.
>
> **(e) Priority order from §3.4.** Updating: drop "(8) struct_enum.out writer + pymatgen-compatibility shim" — replaced by "(8) `Enumlib.LegacyImport` reader for Fortran files (one-way migration + test-corpus loader)". The struct_enum.out *writer* is downgraded to optional and only built if someone asks.
>
> Net effect: the rewrite is meaningfully simpler. We don't have to worry about preserving every quirk of the legacy formats; we design what's right and provide migration paths.
>
> Will retro-edit the affected earlier responses (the iterator-first response in §3.2 and the priority list in §3.4) to remove their "compat shim" framing in a follow-up pass before we strip markers.


6. **Concentration partition enumeration uses GCDs** (`enumeration_routines.f90:70`) — for large k, performance unclear.
We can brainstorm how big k might be, insert some failsafe triggers, or rethink this completely. I don't remember why the GCD was convenient.

> **Claude:** I haven't traced the exact `enumeration_routines.f90:70` site, but the typical role of GCDs in this kind of code is *fraction reduction* — reducing concentration ranges $[\text{min\_num}, \text{max\_num}, \text{denom}]$ to lowest terms across multiple species, so cell volumes that don't admit the requested concentration are skipped without enumeration. E.g., for $\text{cRange}_A = [1, 1, 4]$ ($A$ is exactly 25%), only cell volumes that are multiples of 4 can produce that concentration; for cell volume 6 the GCD machinery rejects it before the labeling pass starts.
>
> Practical scope: $k$ in materials enumeration is almost always 2 or 3; rarely 4; "high-entropy alloys" cases (HEAs) push to 5–6. So the worst case the algorithm needs to handle gracefully is $k = 5$ or $6$. GCD computations on small integers are ns-fast; the cost isn't in the GCDs themselves, it's in the *number* of partitions to consider, which scales as roughly $\binom{n+k-1}{k-1}$. For $n = 50, k = 6$ that's around 3 million partitions — still tractable.
>
> Concrete plan: implement the partition-enumeration with GCD-based pruning per Fortran, but *also* expose a `partition_count(n, k, ranges)` pre-flight that warns if the number of partitions × estimated configurations-per-partition exceeds a threshold. That way users with weird high-$k$ requests get a clear "this will produce $10^{15}$ structures, abort?" prompt rather than silent thrashing. Phase 7 (misuse mitigation) home.
That sounds like a good plan

7. **Direct-write to unit 14 inside the enumeration loop** — incomplete output if interrupted.
8. **`derivCryst` and `cryst` types are dead** — leftover from an unfinished earlier refactor.

### 2.11 What this means for the Julia design (synthesis)

Pulling the threads from the digest into design implications for later phases:

- **Phase 5 (algorithm dispatch).** At least three known dispatch dimensions: explicit override, site-restricted vs not, multinomial size. Replace the single `origCrossOutAlgorithm` boolean with named algorithm choices and an automatic predictor. The `polya=true` short-circuit becomes a separate top-level entry: `count_inequivalent`.
yes
- **Phase 6 (data structures).** Live types are `RotPermList`, `opList`, `derivStruct`, `tree`. Dead types (`cryst`, `derivCryst`) should not be carried forward. Replace parallel-array site representation (`dFull/d`, `labelFull/label`, `equivalencies`, `inactives`) with a single `Site` struct. SNF non-uniqueness needs a deliberate decision (canonicalize or carry automorphisms). 
We can even reconsider whether the live types are the best choice or if there is something better.

- **Phase 7 (scale safety).** Pre-flight Pólya count is the obvious entry point. The `max_binomial = 1E10` threshold is a placeholder for a real cost model. BigInt comes in for the count itself; the labeling representation can stay machine-int once n×nD is bounded.
- **Phase 9 (pymatgen).** Pymatgen wraps the CLI driver, which means it parses `struct_enum.out`. Either preserve that file format byte-for-byte or write a thin Julia→Pymatgen shim.
Not sure what to say about this yet. 
- **Phase 10 (CI + perf).** Regression test = run our enumeration vs Fortran's `compare_two_enum_files`-style equivalence, on a curated test corpus. Performance regression = walltime on a fixed set of hard cases.
Good
- **Phase 11 (DFT outputs).** `makeStr.f90` (with spectator-atom support) is the reference; `scratch/makePOSCAR.jl` is the starting point but doesn't yet have spectator atoms.

### 2.12 What's still missing from this digest

To not over-claim: I've not yet read the `support/` PDFs (`interior_points.pdf`, `multiperms.pdf`, `multilattice_dset_mapping_writeup.pdf`, `notes_cRangeAdjustment.pdf`). They'll be read during Phase 4 when the relevant algorithms come up — that's where LaTeX-ification will happen too.

I've also not exhaustively traced control flow inside the larger files (e.g., every branch of `gen_multilattice_derivatives`). The top-level shape is captured; if Phase 6 surfaces a question that needs deep tracing, I'll spawn a focused agent.


---


## Phase 3 — Current Julia Enumlib state + Fortran→Julia delta

Per **Design Principle 2**, this is a *capability* gap analysis, not a file-shape comparison. The current Julia layout reflects an experimenting phase and shouldn't constrain what the rewrite preserves vs reorganizes.

### 3.1 What Enumlib.jl currently does (post-split, v0.1.0)

The package is 1361 LOC across 6 files in `src/`:

| File | LOC | What it provides |
|---|---|---|
| `Enumlib.jl` | 316 | Module entry. Defines `cellRadius`. Re-defines (in this module's namespace) the cluster-equivalence + group-theory + coloring utilities migrated from JuCE during the split (deleteTransDuplicates!, isaGroup, generateGroup, hash, hash2coloring, getColorings, reduceColorings, getSymEqvColorings_slow, getUniqueColorings, getPermG ×2, isRotTransEquiv, canonClustOrder!, isTransEquiv). Includes the next four files. |
| `LatticeColoringEnumeration.jl` | 287 | HNF/SNF/labeling primitives — `getAllHNFs`, `tripletList`, `basesAreEquiv`, `getSymInequivHNFs`, `getFixingOps`, `getFixingLatticeOps`, `getTransGroup`, `gCoordsToOrdinals`, `ordinalToGcoords`, `getCartesianPts`, `checkCartesianPt`, `get_nonzero_index`, `getOrdinalsFromCartesian`, `coloringsOfHNFList`, plus structs `SuperTile`, `ColoredTile`, `ParentLattice`. **The three structs are dead** — see Claude's verification below the table. |
| `CEdataSupport.jl` | 120 | The `enumStr` struct + `readStructenumout`, `readEnergies`, `readStrIn` (UNCLE structures.in reader, gzip-aware). |
| `clusterequvi.jl` | 34 | `shiftToOrigin`, `isEquivClusters` (Cartesian-coordinate cluster equivalence). |
| `radiusEnumeration.jl` | 123 | `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius`, `estimatedTime` — radius-bounded enumeration variants. |
| `LatticeEnumeration2D.jl` | 481 | Standalone 2D submodule (own module declaration, own deps `Plots`, `SmithNormalForm`, `StaticArrays`). NOT loaded by `Enumlib.jl` by default; users `include` it manually. Defines its **own** `SuperTile` struct (different from the 3D one). |

> **Claude:** Confirmed your suspicion via grep. In the 3D `Enumlib` module:
> - `SuperTile` is **defined** at `LatticeColoringEnumeration.jl:11` and **exported** at `Enumlib.jl:15`. It is **never constructed** anywhere in the 3D code. Worse, its inner constructor at line 17 has a typo (`daig((HNF).S)` instead of `diag(...)`) — calling it would throw `UndefVarError`. So the struct is both unused *and* broken.
> - `ColoredTile` is defined to wrap a `SuperTile` plus a colorings vector. Same story — defined and exported, never constructed. Inherits the brokenness via dependency on `SuperTile`'s constructor.
> - `ParentLattice` is defined at line 32 and exported. Never constructed in the 3D module.
>
> The `SuperTile` references in `test/runtests2D.jl` are to a *different* `SuperTile` defined in `LatticeEnumeration2D` — that one has its own type, used only inside the 2D submodule.
>
> So three exported-but-dead types in the 3D Enumlib API. Strongest possible signal that Phase 6 should design data structures from first principles. Yes! The fact that exporting these types didn't break anything is itself evidence that the right shape for `Site` / `Supercell` / `Enumeration` hasn't been settled.
>
> **Action item I'll take during Phase 6:** delete these three dead structs from the export list and from `LatticeColoringEnumeration.jl`, replace with the new design.

Tests: `test/runtests.jl` covers HNF generation + coloring counts (9/9 pass against reference values from the 2008 paper's Table IV — FCC 8-site sum = 390, 12-site sum = 7140, etc.). `test/runtests2D.jl` exercises `LatticeEnumeration2D` separately.

POSCAR I/O lives in `scratch/{readPOSCAR,makePOSCAR}.jl` — has top-level scratch code, not module-loadable as-is.

### 3.2 Capability gap vs Fortran enumlib

The single biggest takeaway from reading both: **Julia Enumlib has the geometric/symmetry foundations but is missing most of the configurational machinery.** Concretely:

#### 3.2.1 Present in Julia, parity with Fortran

| Capability | Julia function(s) | Fortran equivalent | Notes |
|---|---|---|---|
| HNF enumeration (all HNFs of a volume) | `getAllHNFs(n)` | `get_all_HNFs` (`derivative_structure_generator.f90`) | Verified against Hart-Forcade 2008 Table IV. |
| HNF symmetry-deduplication | `getSymInequivHNFs`, `basesAreEquiv` | `remove_duplicate_lattices` | Same algorithm. |
| Stabilizer subgroup of a supercell | `getFixingOps`, `getFixingLatticeOps` | `get_fixing_operations` | Same. |
| Permutation group on supercell sites | `getPermG` (Float and Int versions) | `get_rotation_perms_lists` | Same. Eq. 3 from the 2008 paper. |
| Symmetry-inequivalent colorings of one HNF | `getUniqueColorings(k, pG)` | inside `generate_unique_labelings` / tree algorithm | k-ary, eliminates super-periodics. |
| All colorings (no symmetry) | `getColorings(k, n)` | helper inside Fortran enum3 | Trivial. |
| Coloring reduction by a permutation group | `reduceColorings`, `getSymEqvColorings_slow` | helper | "_slow" name acknowledges this is the brute-force path. |
| Smith Normal Form | via `NormalForms.jl` (`snf`) | `get_SNF` (calls symlib) | Different library; SNF non-uniqueness still a concern. |
| Minkowski reduction | via `MinkowskiReduction.jl` | inline in Fortran | Cleaner separation in Julia. |
| Point-group / lattice symmetry | via `Spacey.jl` (`pointGroup`) | symlib | Modern Julia package. |
| Radius-bounded HNF enumeration | `radiusEnumHNFs`, `getSymInequivHNFsByCellRadius` | aux_src `HNF_counter.f90` (analysis only) | Julia has it as a real API; Fortran only as a counting tool. **Improvement.** |
| 2D enumeration | `LatticeEnumeration2D` submodule | `get_all_2D_HNFs` | Julia has it as a separate, opt-in submodule. |
| `enumStr` data type | `enumStr` struct | `derivStruct` derived type | Roughly aligned. Both will likely be replaced (per Phase 6). |
| Read `struct_enum.out` | `readStructenumout` | `read_struct_enum_out` (in `enumeration_utilities.f90`) | Fortran is more thoroughly tested. |
| Read UNCLE `structures.in` (incl. .gz) | `readStrIn` | not in Fortran enumlib | **Julia-only feature.** Probably came over from UNCLE-adjacent work. |

#### 3.2.2 Missing in Julia (the real gap)

| Capability | Fortran routine(s) | Effort to port | Priority |
|---|---|---|---|
| **Concentration-restricted enumeration** | `generate_permutation_labelings` + `get_concentration_list` + `cRange` plumbing | High — touches input format, dispatch logic, labeling | **High.** This is the 2012 paper's contribution; major user feature. |
| **Site restrictions** | `get_site_restrictions` + `site_res` plumbing | Medium — mostly a constraint check during labeling | **High.** |
| **Inactive / spectator / equivalent sites** | `make_inactive_table`, `adjust_crange_for_inactive_sites`, `getSpaceGroup_activeSitesOnly`, `equivalencies` | High — pervasive in current Fortran | **High.** Tractable-vs-intractable for many real materials. Needs clean abstraction (Phase 6). |
| **Multilattice handling** | `get_dvector_permutations`, dset propagation in `RotPermList`, multilattice-aware HNF dedup | Medium-High — adds nD dimension everywhere | **High.** HCP, perovskites, etc. The 2009 paper. |
| **Recursive-stabilizer tree (Morgan 2017, enum4)** | `recursively_stabilized_enum`, `tree_class.f90` | Medium — clean OO design carries over well | **Medium** — only needed when crossing-out won't scale. |
| **Crossing-out algorithm (enum3)** | `generate_permutation_labelings` + bitstring markers | Medium — but the bitstring marker logic is opaque/undocumented | **Medium** — currently the default for site-restricted cases in Fortran. |
| **Pólya counting (pre-flight estimator)** | enum3/enum4 with `polya=true` short-circuit | Low — closed-form group-theoretic | **High** for misuse mitigation (Phase 7). |
| **`map_enumStr_to_real_space`** (mapping (HNF, labeling) → atomic positions) | `enumeration_utilities.f90:49-123` | Low-Medium — uses interior-points formulas | **High.** Without this we can't produce VASP/QE/LAMMPS input. |
| **`compare_two_enum_files`** (regression / equivalence under SNF automorphisms + label perms) | `aux_src/compare_two_enum_files.f90` | Medium-High — hard-won logic per HISTORY.md 2.0.3 | **High** for trustworthy testing. |
| **Find a structure in an enumeration** | `find_match_in_structenumout` | Medium | Medium. |
| **POSCAR writer with spectator atoms** | `aux_src/makeStr.f90` | Low — `scratch/makePOSCAR.jl` is a starting point | **High** for DFT users. |
| **POSCAR → struct_enum format conversion** | `aux_src/convert_structures_to_enumformat.f90` | Medium | Medium. |
| **`fixed_cells.in` support** (constrained HNF list) | `read_in_cells_from_file`, `check_for_fixed_cells` | Low | Low — niche. |
| **Arrow enumeration** | `arrow_related.f90`, integrated with tree | — | **Skipped per user.** |

#### 3.2.3 Where Julia is better than Fortran (today)

A small list, but real:

- **`radiusEnumeration.jl`** is a first-class API. In Fortran it's only an analysis tool (`HNF_counter.f90`).
- **Modular dependencies.** `MinkowskiReduction.jl`, `NormalForms.jl`, `Spacey.jl` are separate registered Julia packages. The Fortran code rolls all of this into `symlib` and inline routines.
- **Type system.** Even the rudimentary current `enumStr` struct is more discoverable than Fortran's `derivStruct`. Once Phase 6 redesigns the data model, this advantage compounds.
- **Test discoverability.** `Pkg.test()` runs the suite; Fortran requires a custom XML-driven test driver.
- **Less dead code.** The Fortran code has explicit dead types (`cryst`, `derivCryst`), commented-out routines (`generate_disjoint_permutation_labelings`), and stale CLI helpers. Julia is leaner because it never accumulated this.
- **`readStrIn` for UNCLE structures.in** (with gzip) is not in Fortran enumlib — useful interop on the input side.

#### 3.2.4 Where Julia is *worse* than Fortran (today)

Honest accounting:

- **No core enumeration features beyond HNFs and basic colorings.** The whole concentration/site-restriction/multilattice/inactive-site/recursive-stabilizer machinery is missing. This is the bulk of the gap.
- **No `struct_enum.out` writer.** We can read but not write the canonical output format. Phase 9 (pymatgen) is impossible until this is fixed.
Other than pymatgen, do we really need a writer? Couldn't we make a iterable that stored the necessary information to lazily spit them out as they were requested?

> **Claude:** That's the better framing. Julia idiom is iterators / lazy generators, and an enumeration is naturally one. Pseudocode for the user-facing API:
>
> ```julia
> # Lazy: doesn't materialize all structures
> for s in enumerate(parent, sites; volume_range=2:10, concentration=[0.5, 0.5])
>     process(s)            # one structure at a time
>     write_poscar("POSCAR.$(s.id)", s)
> end
>
> # Eager when you need the whole list
> all_structures = collect(enumerate(parent, sites; ...))
>
> # Counting without enumerating (Pólya)
> n_structures = count_inequivalent(parent, sites; ...)
> ```
>
> This is far better than the Fortran "enumerate to disk, then have downstream tools read the file" workflow. The user doesn't need to manage an intermediate file; the structures stream directly into whatever pipeline they want. Disk persistence is just `JLD2.save("enum.jld2", enum)` — Julia-native, no custom format needed.
>
> So: **default API is lazy iteration**. The 2017 recursive-stabilizer tree is naturally streaming-friendly; the 2008/2012 crossing-out can also be made to yield as it goes (or, if we want, materialize the visited bitmap eagerly and yield the unique ones — we can decide which when we get there).
>
> *Earlier this response framed the `struct_enum.out` writer as a "compat-shim utility." That framing is now retired per your no-Fortran-compat directive in §2.10 #5. We don't ship a struct_enum.out writer at all in the user-facing API; if it's needed for cross-validation against Fortran enumlib output, it lives in an internal-test-only `LegacyExport` module.*

- **No POSCAR pipeline.** `scratch/{read,make}POSCAR.jl` need cleanup before they can be loaded as module code, and `genPOSCARs` even has a captured-global-`A` bug.
- **No regression-comparison tooling.** Without something like `compare_two_enum_files`, we can't validate the rewrite against the Fortran gold standard.
We really need this. The Fortran is extremely strong, heavily battle tested. 

> **Claude:** Promoting in the work plan. Currently item (7) in §3.4's order-of-feature-delivery; should move up. Two reasons:
> 1. Without it we have no objective measure that any new feature is correct against the Fortran reference.
> 2. It's the *gating* tool for porting concentration restrictions, multilattices, and inactive sites — for each, we run Fortran enumlib on a representative case, run the new Julia code on the same case, compare, iterate.
>
> Revised priority order: (1) `map_to_real_space` + POSCAR writer (already partial), (2) **compare-enumerations regression utility** (was 7), (3) Pólya pre-flight count, (4) concentration restrictions, (5) inactive sites + equivalencies, (6) multilattice support, (7) recursive-stabilizer algorithm, (8) `Enumlib.LegacyImport` — read-only Fortran-format reader for migration + test-corpus loading.
>
> *Earlier draft of (8) read "struct_enum.out writer + pymatgen-compatibility shim." Updated per your no-Fortran-compat directive in §2.10 #5: we don't preserve the file format as a long-term API. Pymatgen integration becomes a Python-callable Julia API via PythonCall (Phase 9), not a file-format shim.*
>
> Phase 12 will lock this in; flagging now while the reasoning is fresh.
Great

- **Limited test coverage.** 9 tests (all passing). Fortran has tens of thousands of test directories. We don't need to match that volume, but coverage of concentration/site-restriction edge cases will need to grow with the features.
- **Some carryover scaffolding** from JuCE — `clusterequvi.jl` is small and arguably belongs in Enumlib, but the function names (`shiftToOrigin`, `isEquivClusters`) are CE-flavored. Phase 6 should reconsider where these belong.

### 3.3 Algorithmic-correctness check

Worth being explicit: the *current* Julia enumeration is verified correct on the cases the test suite exercises. The 8-site and 12-site FCC binary coloring counts (390 and 7140 respectively) match the Hart-Forcade 2008 paper Table IV. HNF counts at small volumes match the Fortran output. The geometric/symmetry primitives reproduce expected behavior on FCC, BCC, simple cubic, hcp.

What we *don't* have evidence for is correctness on:
- Multilattice cases beyond HCP-style (only superficially handled by current code; nD>1 logic in `getCartesianPts` etc. exists but isn't load-tested).
- Concentration-restricted cases — there's no implementation to test.
- Inactive-site cases — same.
- Edge cases the Fortran 2.0.3 saga revealed (SNF automorphism handling).

So when Phase 5+ designs the new code, Julia parity for the missing features can't simply be "match the test suite" — we'll need to construct a test corpus from Fortran outputs for concentration / site-restriction / multilattice scenarios.
Yes.

### 3.4 Implications for the rewrite plan

- **Build the missing 90%, don't rewrite the 10%.** Most of what's there (HNF/SNF/symmetry primitives, getUniqueColorings) is correct and well-isolated. The rewrite should preserve these as a foundation and *add* the missing capabilities on top, with an opportunity to redesign the data model (Phase 6) at the layer boundary.
- **Phase 6 priority list** for data structures: (a) replace `enumStr`; (b) design a `Site` abstraction unifying `dFull/d`, `labelFull/label`, `equivalencies`, `inactives`; (c) design `Configuration` (the labeling state) so concentration/site restrictions can hook in cleanly; (d) decide on canonical SNF or carry automorphisms.
- **Phase 5 dispatch** should expose `enumerate(parent, …)` with kwargs for concentration_range, site_restrictions, fixed_cells, algorithm=:auto. The :auto path uses Pólya counting + multinomial size to choose enum3 vs enum4.
This sounds good.
- **Order of feature delivery (rough guess; Phase 12 will refine; revised inline in the response above and again in §2.10 #5):** (1) `map_enumStr_to_real_space` + POSCAR writer, (2) compare-enumerations regression utility (Fortran reference vs Julia), (3) Pólya pre-flight count, (4) concentration restrictions, (5) inactive sites + equivalencies, (6) full multilattice support, (7) recursive-stabilizer algorithm, (8) `Enumlib.LegacyImport` (read-only Fortran-format reader for migration + test-corpus loading).

### 3.5 The 2D submodule

`LatticeEnumeration2D.jl` is currently standalone — not loaded by `Enumlib.jl`. It has its own `module LatticeEnumeration2D` declaration and deps (`Plots`, `SmithNormalForm`, `StaticArrays`). User said it's "niche" and "easy to visualize" but no immediate plans to work on it.

For the rewrite I'd recommend keeping it as an explicit submodule (`Enumlib.LatticeEnumeration2D`) loaded on demand via `using Enumlib.LatticeEnumeration2D`, so the Plots dependency stays optional. The 2D code shares concepts with 3D (HNFs, colorings, supertiles) but uses its own types — worth a Phase 6 look at whether we can collapse some of that duplication.


---


## Phase 4 — Paper digests

One section per paper. Each digest covers: problem statement, algorithmic contribution, what's new vs prior work, key concepts (which feed the glossary), complexity, mapping to Fortran routines, what carries into the Julia rewrite. Glossary at `docs/notes/glossary.tex` is populated as I go.

### 4.1 Hart & Forcade 2008 — *Algorithm for generating derivative structures*

**Citation.** Gus L. W. Hart, Rodney W. Forcade, *Phys. Rev. B* **77**, 224115 (2008). DOI: 10.1103/PhysRevB.77.224115. PDF: `papers/HartForcade_2008_AlgorithmForGeneratingDerivativeStructures.pdf` (9 pages).

#### Problem

Given a parent lattice $L$ and $k$ atom types, enumerate *every distinct* derivative superstructure — every supercell of $L$ together with every periodic decoration of its atomic sites — up to physical equivalence (rotations, translations, label-exchange). Generality target: any parent lattice, any $k$, in 2D or 3D.

#### Why this paper exists

Prior algorithms (Ferreira-Wei-Zunger, FWZ) were both incomplete and slow for the general case:
- Restricted in practice to fcc/bcc binary cases.
- Used a geometric "smallest first" enumeration plus correlation-comparison deduplication, which is $O(N^2)$ in the number of structures and which can miss structures that have matching short-range correlations but differ further out (the *completeness gap* in the original FWZ).
- For $n=20$ fcc binary: minutes here vs **>1 month** for FWZ.
- For $n=24$: <2 hours here vs >1 month for FWZ.

The new algorithm is **formally complete** (no missed structures) and **scales linearly with $N$** (the number of unique structures found) — best possible asymptotic for an enumeration problem.

#### The key idea

Replace geometric duplicate-checking with **group theory in the quotient group $G = L/S$** where $S$ is the superlattice (a subgroup of $L$). $G$ is finite of order $n$ (the *index* or volume ratio); via the Smith Normal Form it decomposes as a direct sum of cyclic groups $\mathbb{Z}_{s_1} \oplus \cdots \oplus \mathbb{Z}_{s_k}$.

A *labeling* (coloring) of the parent lattice that's periodic under $S$ is the same thing as a labeling of the elements of $G$. So duplicate-checking happens *inside the finite group*, never against the infinite lattice. This is what unlocks the linear scaling: the $k^n$ candidate labelings of $G$ are stored in a perfect hash, and each duplicate-elimination step is one pass through that hash.

#### The algorithm (six steps, mapped to Fortran)

1. **Generate all HNF matrices of size $n$** (Sec. II.A). HNF is the lower-triangular form with $0 \le b < c$, $0 \le d, e < f$, and $a \cdot c \cdot f = n$. Closed-form count formula (Eq. 2):
   $$\sum_{d \mid n} d\sigma(d) = \prod_{i=1}^{k} \frac{(p_i^{e_i+2}-1)(p_i^{e_i+1}-1)}{(p_i-1)^2(p_i+1)}$$
   for $n = p_1^{e_1}\cdots p_k^{e_k}$. Sloane's A001001. Used to sanity-check generation. **Fortran:** `get_all_HNFs` (`derivative_structure_generator.f90`). **Julia:** `getAllHNFs(n)`.

2. **Reduce HNFs by parent-lattice symmetry** (Sec. II.B). Two HNFs $H_i, H_j$ define equivalent superlattices iff $B_j^{-1} R B_i$ is a unimodular integer matrix for some rotation $R$ in the parent point group. Asymptotically: factor of $\frac{1}{2} |\text{rot group}|$ reduction (e.g., $\sim 1/24$ for fcc/bcc). **Fortran:** `remove_duplicate_lattices`. **Julia:** `getSymInequivHNFs`, `basesAreEquiv`.

3. **For each remaining HNF, compute SNF and the quotient group structure** (Sec. II.C). $LHR = S$, $S$ diagonal. The quotient $L/S = \mathbb{Z}_{s_1} \oplus \mathbb{Z}_{s_2} \oplus \mathbb{Z}_{s_3}$. **Fortran:** `get_SNF`. **Julia:** via `NormalForms.jl`'s `snf`.

4. **Generate all $k^n$ labelings of $G$**. Stored as $n$-digit base-$k$ integers; a perfect hash. **Fortran:** inside `generate_unique_labelings` / `generate_permutation_labelings`. **Julia:** `getColorings(k, n)`.

5. **Eliminate four kinds of duplicate via group-theoretic operations on $G$:**

   - **(5a) Incomplete labelings.** Discard any labeling where some label $\in \{0, \ldots, k-1\}$ does not appear. Optional (drives binary→ternary→quaternary partitioning).
   - **(5b) Translation duplicates.** Adding any element $t \in G$ to every position permutes labels by a fixed permutation. The $n$ such permutations partition the labelings into orbits of size $n$. Keep one per orbit. *Reduces by a factor of $\sim n$.*
   - **(5c) Label-exchange duplicates.** Renaming $a \leftrightarrow b$. Reduces binary by 2x; for $k$-ary, reduces by $\le k!$.
   - **(5d) Super-periodic labelings.** Labelings whose actual period is shorter than the supercell — i.e., they correspond to a smaller-index superstructure already enumerated. Detected: a non-identity translation $t$ that leaves the labeling invariant.

   All four are implementable as $O(N)$ scans through the hash with $O(n)$ work per labeling.

6. **Remove label-rotation duplicates per HNF** (Sec. II.C.6). Some parent-lattice rotations $R$ leave a *specific* superlattice fixed (so step 2 didn't catch them) but still permute its interior points. Eq. 3 expresses the induced permutation entirely inside $G$:
   $$G' = L A^{-1} R (L A^{-1})^{-1} G$$
   No reference to superlattice geometry. **Fortran:** `get_rotation_perms_lists`, `getPermG` in the labeling layer. **Julia:** `getPermG` (already present, both Float and Int methods).

#### Complexity

The total run time is dominated by step 5 + 6, both of which are linear in the number of labelings examined. The number of labelings examined per SNF is at most $k^n$, but the SNFs are *vastly* fewer than HNFs — Table III shows e.g. only 4 distinct SNFs at $n=16$ for 651 HNFs — so labelings are enumerated once per SNF and broadcast across all HNFs sharing that SNF, which is the critical efficiency win. **Asymptotically $O(N)$ in the number of unique structures found.**

#### Validation (paper's tables)

- **Table III**: HNF and SNF counts for $n=2$ to 16. SNF counts are tiny — 1 for prime $n$, 2–4 for highly composite $n$. This is the saving.
- **Table IV**: Symmetrically inequivalent superlattices for fcc/bcc, sc, hex, tetragonal, $n=2$ to 10. *This is the test reference our Julia tests at `test/runtests.jl` already validate against.*
- **Table V**: Cumulative fcc derivative structures up to $n=23$: 8,172,820. (Paper's Fig. 9 shows the fraction of HNFs that survive symmetry reduction asymptotes to $2/N \approx 5\%$ for fcc.)
- **Table VII**: ternary fcc has 13,287 cumulative at $n=10$; quaternary has 40,280.

#### Terminology introduced (seeded into glossary.tex)

| Term | Meaning in this paper |
|---|---|
| Derivative superstructure | A supercell of a parent lattice + periodic atomic decoration. |
| Parent lattice $L$ | The reference Bravais lattice (treated as group under addition). |
| Superlattice $S$ | A sublattice of $L$ of finite index $n$. |
| Index $n$ | $|L/S|$ — the volume ratio (number of parent cells per supercell). |
| Quotient group $G = L/S$ | Finite group of order $n$, structure determined by SNF. |
| Labeling / coloring | A function from the $n$ elements of $G$ to $\{0,\ldots,k-1\}$. |
| HNF | Hermite Normal Form representation of the superlattice basis transform. |
| SNF | Smith Normal Form; gives $G$'s direct-sum decomposition. |
| Translation duplicate | Two labelings related by adding $t \in G$ to each position. |
| Label-exchange duplicate | Two labelings related by relabeling $a \leftrightarrow b$. |
| Super-periodic labeling | A labeling fixed by some non-identity translation in $G$. |
| Label-rotation duplicate | Two labelings related by a parent-lattice rotation that fixes the superlattice. |

#### What this means for the rewrite

- **The Julia code already implements steps 1, 2, 3, and 6 correctly** and matches Table IV at the tested cases ($n \le 12$ FCC). What's missing relative to this paper is the *full* labeling pipeline (steps 4–5), which the paper's "remove translations / label-exchange / superperiodics" cascade describes. The current `getUniqueColorings(k, pG)` does combine these into a single pass via permutation-group hashing — that's a defensible implementation choice, but should be sanity-checked against the paper's step-by-step counts on small cases (Table I in the paper, $n=4$, $k=2$: 16 → 14 → 4 → 3 surviving labelings).
- **The "perfect hash" framing** (Sec. II.C.2) suggests a clean Julia data model: at the SNF level, labelings are just `Vector{Int8}` of length $n$ that index into a `BitVector` of length $k^n$. Phase 6 should consider this representation for the dedup pass; current `getUniqueColorings` uses a `BitVector` of length `k^n` already, which is consistent.
I like this idea a lot. Can you explain it a bit more verbosely.

> **Claude:** Glad it lands. Here's the verbose version. The Hart-Forcade 2008 algorithm has a beautifully simple data model that the current Julia code is *almost* already using; making it explicit clarifies the design.
>
> **Setup.** A labeling of a supercell with $n$ sites and $k$ atom types is a function $\sigma: \{1, \ldots, n\} \to \{0, 1, \ldots, k-1\}$. Equivalently, a length-$n$ vector with entries in $\{0, \ldots, k-1\}$. There are exactly $k^n$ such labelings.
>
> **The hash.** Read each labeling as the digits of a base-$k$ integer:
> $$\text{idx}(\sigma) = \sigma_1 + k \sigma_2 + k^2 \sigma_3 + \cdots + k^{n-1} \sigma_n \;\in\; [0, k^n - 1]$$
> This is bijective onto $[0, k^n - 1]$ — every integer in that range corresponds to exactly one labeling, and vice versa. That's what makes it a "perfect" hash: no collisions, no gaps. The hash table that uses it is just an array indexed by the integer.
>
> **The visited bitmap.** Allocate `visited::BitVector` of length $k^n$. Bit $i$ answers "is the labeling with index $i$ in an orbit we've already enumerated?" Initially all false.
>
> **The dedup loop.** Walk $i = 0, 1, \ldots, k^n - 1$:
> 1. If `visited[i]` → skip; this labeling is already accounted for.
> 2. Materialize the labeling $\sigma_i$ from index $i$ (split base-$k$ digits — a one-liner).
> 3. Add $\sigma_i$ to the unique list.
> 4. For each symmetry operation $g \in G$ (translations + rotations of the supercell), compute $\text{idx}(g \cdot \sigma_i)$ and set `visited[idx]` to true. This marks the entire orbit of $\sigma_i$ as visited.
>
> **Why this is good.** Each labeling is visited exactly $|G|$ times in the inner loop (once when it's the representative, $|G|-1$ times when it's a symmetry-image of one). The total work is $O(k^n |G|)$. Memory is $O(k^n)$ bits, which for $k=2, n=20$ is 1 MB — trivially fits in cache. For $k=2, n=30$ it's 1 GB and starts to hurt; that's where the 2012 fixed-concentration hash and the 2017 tree algorithm take over.
>
> **The Julia code in 5 lines:**
>
> ```julia
> function unique_orbits(k::Int, n::Int, perm_group::Vector{Vector{Int}})
>     visited = falses(k^n)
>     reps = Vector{Vector{Int8}}()
>     digits = zeros(Int8, n)
>     for i in 0:(k^n - 1)
>         visited[i+1] && continue
>         x = i; for j in 1:n; digits[j] = x % k; x ÷= k; end
>         push!(reps, copy(digits))
>         for g in perm_group
>             permuted = digits[g]
>             idx = 0; for j in n:-1:1; idx = idx * k + permuted[j]; end
>             visited[idx+1] = true
>         end
>     end
>     return reps
> end
> ```
>
> The current `getUniqueColorings(k, pG)` is already structured around this idea — it uses a `BitVector` of length `k^n` and walks `CartesianIndices`. The cleanup for Phase 6 is mostly wording: state explicitly that the labeling space *is* $[0, k^n - 1]$, that the bitmap *is* the dedup state, and document the bijection cleanly. The current implementation hides this behind a `CartesianIndices` iteration which obscures the underlying perfect-hash structure.
>
> Once this representation is made explicit, the 2012 paper's multinomial hash and the 2017 paper's location vectors slot in as natural specializations: same dedup loop, different (more compact) hash + inverse.
Good

- **Incompleteness of FWZ-style correlation deduplication** is the historical reason the geometry-free approach was developed. The Julia rewrite must not regress on this — any future "fast deduplication" optimization (Phase 8 / Shinohara 2020) needs to be checked for completeness in the same way.

#### Open question

The paper says (Sec. II.A): "the implementation of the HNF-generating algorithm can be rigorously checked" using the closed-form count from Eq. 2. Worth wiring this as a CI test in Phase 10: `count(getAllHNFs(n)) == closed_form_HNF_count(n)` for $n$ up to, say, 30. Yes, we should do this

---

### 4.2 Hart & Forcade 2009 — *Generating derivative structures from multilattices: Algorithm and application to hcp alloys*

**Citation.** Gus L. W. Hart, Rodney W. Forcade, *Phys. Rev. B* **80**, 014120 (2009). DOI: 10.1103/PhysRevB.80.014120. PDF: `papers/HartForcade_2009_DerivativeStructuresFromMultilattices.pdf` (8 pages).

#### Problem

The 2008 paper handles parent lattices that are simple Bravais lattices (one site per primitive cell). Many real materials are not — HCP has 2 sites per primitive cell, perovskites have 5+, diamond has 2, tetragonal Heuslers have 4. The 2009 paper extends the algorithm to **multilattices**.

#### Definition (the dset and the multilattice)

A **multilattice** $M$ is a union of translates of a Bravais lattice $L$:
$$M = L + D = \{x + d : x \in L, \; d \in D\}$$
where $D = \{d_1, \ldots, d_{n_D}\}$ is the **dset** — a set of fractional translations within one parent cell. By convention $0 \in D$ (the multilattice contains the origin); the other $d_i$ are interior basis sites.

Examples:
- **HCP**: hexagonal $L$, $D = \{(0,0,0), (1/2, \sqrt{3}/6, \frac{1}{2}\sqrt{8/3})\}$, so $|D|=2$.
- **Diamond / zincblende**: fcc $L$, $|D|=2$.
- **Perovskite ABO$_3$**: simple-cubic $L$, $|D|=5$.

A supercell of $M$ contains $n \cdot n_D$ atoms, where $n = \det H$ is the supercell index.

#### The key extension

Instead of labeling elements of $G = L/L'$ (where $L'$ is the superlattice), label elements of the **Cartesian product $D \times G$** — one label per (basis-site, coset) pair. There are $|D| \cdot n$ elements; the labeling-space size is $k^{|D| \cdot n}$.

The geometric → combinatorial bridge is the map (Sec. IV.2.c):
$$\gamma : M \to D \times G, \qquad \gamma(d + x) = (d, \, h(x))$$
where $h : L \to G$ is the homomorphism $h(x) = [U A^{-1} x]_S$ from the SNF (mod each $S_{ii}$). Two multilattice elements have the same $\gamma$-image iff they differ by a superlattice element — i.e., iff they're forced to receive the same label. So labeling $D \times G$ periodically is equivalent to labeling $M$ with the superlattice's periodicity. This makes the duplicate-elimination machinery from the 2008 paper apply *unchanged*; only the index set changes.

#### How symmetries act on $D \times G$ (the new content)

A symmetry of $M$ has the form $f_N(x) = N x + t$ with $N$ an orthonormal matrix (rotation/reflection) in the parent point group and $t$ a fractional translation. The 2009 paper proves (Appendix) that $t$ can always be chosen as an element of $D$.

For each candidate $N$ in the parent's point group, find the $d_N \in D$ such that $f_N$ is actually a symmetry of $M$ (it might not be, even if $N$ is a symmetry of $L$). When it is, $f_N$ induces the permutation on $D \times G$:
$$\pi_N(d, g) = \bigl(\, d_{N, d}, \; (U A^{-1} N A U^{-1})_S \, g + (U A^{-1})_S \, t_{N, d} \,\bigr)$$
Here $d_{N,d}$ is the d-vector that $d$ maps to under $N$, and $t_{N,d} \in L$ is the lattice shift bringing the rotated $d$ back into the first cell. Translational symmetries are simpler:
$$\pi_t(d, g) = (d, \; g + g_0)$$

The full symmetry group on $D \times G$ is generated by composing these. Step (4) of the algorithm is then identical to the 2008 paper's Step 5–6: enumerate $k^{|D \times G|}$ labelings, eliminate translation / label-exchange / super-periodic / label-rotation duplicates via the permutation action.

#### Mapping to Fortran code

This is exactly what `RotPermList` carries:
- `RotPermList.perm(:,:)` — the permutation on $D \times G$ for each rotation in the stabilizer of the supercell.
- `RotPermList.v(:,:,:)` — the lattice shifts $t_{N,d}$ to bring rotated d-vectors back into the first cell.
- `RotPermList.RotIndx(:)` — which rotations of the full point group fix this superlattice.

The routine `get_dvector_permutations` in `derivative_structure_generator.f90` computes the $d_{N,d}$ map for each parent-lattice rotation. The routine `get_rotation_perms_lists` builds the full permutation list for a given HNF. Internal note: `multilattice_dset_mapping_writeup.pdf` (in `docs/notes/`) is the mathematical reference for these computations.

#### Validation (paper's tables)

- **Table I**: HNF counts for hex / fcc/bcc / sc / tetragonal at $n = 2$ to 10. Hex has more HNFs than cubic at same $n$ (lower symmetry: 24 ops vs 48). For HCP applications, the hex column applies.
- **Table II**: number of inequivalent hcp- and fcc-derivative labelings, indexed two ways: by index $n$ and by *number of sites per cell*. Important reframing: hcp index $n$ = $2n$ sites, so to compare hcp's "richness" to fcc's at fixed atom count, look at hcp index $n/2$ vs fcc index $n$. fcc has more derivatives by site count.
- **Section VI / Fig. 6**: at $n \le 4$ for hcp the algorithm finds **201** derivative structures, of which only **7 are experimentally known** ($B_h$, $B19$, $\mathrm{Ag_3Sb}$, $\mathrm{LiIr_3}$, $\mathrm{Au_5Sn}$, $D0_{19} = \mathrm{Ni_3Sn}$, $D0_a = \beta\mathrm{Cu_3Ti}$). The other 194 are candidates for new compounds.
- **Likelihood measure** (Fig. 7): structures ranked by deviation from random pair-correlations. Several enumerated-but-unobserved hcp structures score *higher* than known ones — predictions for new compounds.

#### Terminology added to the glossary

| Term | Meaning |
|---|---|
| Multilattice $M$ | Union of translates of a Bravais lattice by a dset. (Already in glossary.) |
| dset $D$ | Set of fractional translations defining the multilattice; $|D| = n_D$. (Already in glossary.) |
| $D \times G$ structure | The combinatorial set on which labelings of a multilattice live; $|D \times G| = n_D \cdot n$. |
| Translate (of a superlattice) | One coset $L' + g$; geometrically, one shifted copy of the supercell. All sites in a translate receive the same label across the basis sites. |
| Likelihood measure | Concentration-dependent ranking of derivative structures by deviation from random pair-correlations; a heuristic for predicting "interesting" new structures. |
| d-vector permutation $d_{N,d}$ | For rotation $N$ acting on multilattice site $d$, the unique $d_{N,d} \in D$ such that $N d \equiv d_{N,d}$ modulo $L$. |

#### What carries into the rewrite

- **The current Julia code's `nD` parameter** is on the right shape for multilattices but the symmetry-on-$D \times G$ machinery is incomplete. Specifically: the existing `getPermG` operates on supercell sites (one label per site), not on the $D \times G$ Cartesian product. Need to either generalize `getPermG` or layer a multilattice-aware wrapper. The former is better, don't you think?

> **Claude:** Yes, generalize. Wrappers introduce an extra abstraction layer (you have to remember which version you're calling, what its semantics are, when to convert), and they tend to leak — eventually some caller wants to skip the wrapper for performance and you have two parallel APIs. Generalizing keeps one canonical function with one canonical signature; the singleton-dset case ($n_D = 1$) is just a degenerate input that the same code handles cleanly.
>
> Concrete shape (Phase 6): `getPermG(supercell::Supercell, parent::ParentLattice) :: Vector{Vector{Int}}` returning permutations on `n × n_D` sites. When `parent.dset == [zero_vector]`, the result reduces to the current single-site permutation list and existing call sites work unchanged.

- **A `Multilattice` (or `ParentLattice`) struct** in the redesign should carry $\{A, D\}$ together. Phase 6 design point: should single-lattice cases be a special case (`D = [zero_vector]`) of the multilattice path, or should there be two code paths? My lean: one code path (always $D \times G$); the singleton case has $|D|=1$ and degenerates cleanly. One code path is also my lean as well.
- **The `multilattice_dset_mapping_writeup.pdf` is the canonical reference.** It will be the next LaTeX-ification target alongside Phase 6 work, since the equations in Sec. IV.2.b–d and the Appendix are exactly what the implementation needs.
- **`get_dvector_permutations` is the linchpin.** Implementing it correctly (computing $d_{N,d}$ + $t_{N,d}$ for each parent-lattice rotation) is the gating capability for full multilattice support. Test it against Table I (HNF counts for hex) and the $n \le 4$ hcp count of 201.
- **The 2009 paper has an Appendix** with detailed formulas for $\pi_t$, $\pi_N$, and the homomorphism $h$. Phase 6 should reference these explicitly when designing the permutation-group computation.

#### Cumulative complexity assessment after 2008+2009

After both papers, the algorithm is:
1. HNF generation (Eq. 2 closed form).
2. HNF symmetry reduction (parent-lattice rotation group acting on HNF list).
3. SNF / quotient group construction.
4. $D \times G$ structure construction (multilattice extension).
5. Symmetry-action permutations $\pi_t$, $\pi_N$ on $D \times G$.
6. Label all $k^{|D \times G|}$ configurations.
7. Eliminate translation / label-exchange / super-periodic / label-rotation duplicates.

Step 4 is where the 2009 paper's contribution lives. Steps 5–7 reuse the 2008 framework on the larger index set.

---

### 4.3 Hart, Nelson & Forcade 2012 — *Generating derivative structures at a fixed concentration*

**Citation.** Gus L. W. Hart, Lance J. Nelson, Rodney W. Forcade, *Comp. Mat. Sci.* **59**, 101–107 (2012). DOI: 10.1016/j.commatsci.2012.02.015. PDF: `papers/HartNelsonForcade_2012_DerivativeStructuresAtFixedConcentration.pdf` (7 pages).

#### Problem

The 2008/2009 algorithm enumerates *all* configurations regardless of concentration. The labeling space has $k^n$ elements, which becomes a memory wall for moderate cell sizes:

- Binary, $n=50$: $2^{50} \approx 10^{15}$ candidates → ~1 PB hash.
- Ternary, $n=16$: roughly the practical ceiling.

But many real applications fix the concentration:
- Charge-neutrality constraints (ZrO$_2$ doped with Y$^{3+}$ creates O-vacancies at fixed stoichiometry).
- Surface adsorbate problems (binary alloy + adsorbate species → effectively quaternary, but coverages are small).
- Targeted phase searches (e.g., Ag–Pt at 15:17 stoichiometry, 32-atom cell).

For the Ag–Pt case the full enumeration would need $2^{32} \approx 10^{10}$ entries; the fixed-concentration enumeration needs $\binom{32}{17} \approx 5 \times 10^8$ — **20× less memory**. For the binary $n=50$ at 20:80, $\binom{50}{10} \approx 10^{10}$ — **10 GB instead of 1 PB**, or ~$10^5$× less.

The 2012 paper's contribution is a **new perfect hash function** that maps *permutations of a multiset* (instead of all $k^n$ labelings) to consecutive integers. This unlocks fixed-concentration enumeration for cell sizes that were intractable in the 2008 algorithm.

#### The multinomial mixed-radix hash (Sec. 3.1)

For colors $c_1, \ldots, c_k$ with multiplicities $a_1, \ldots, a_k$ (so $n = \sum a_i$), the number of distinct configurations is the multinomial:
$$C = \binom{n}{a_1, \ldots, a_k} = \prod_{i=1}^k C_i, \qquad C_i = \binom{n - a_1 - \cdots - a_{i-1}}{a_i}$$

Hash a configuration by enumerating the placements of each color in turn:
1. **For each color $i$** (in order), look at where color $i$ sits among the still-unfilled slots. This is a binary string of length $n - a_1 - \cdots - a_{i-1}$ with $a_i$ ones. Compute its rank $x_i \in [0, C_i - 1]$.
2. **The rank computation** for a single-color binary string: for each `0` with $p$ ones to its right out of $q$ total ones, add $\binom{p}{q-1}$. Sum to get $x_i$. (Sec. 3.1.)
3. **Combine into a global index** via mixed-radix:
   $$y = f(x_1, \ldots, x_k) = x_1 + C_1 \bigl(x_2 + C_2 (x_3 + \cdots + C_{k-2} x_{k-1}) \bigr)$$
   (Eq. 3 in the paper.)

The result $y \in [0, C-1]$ — a perfect hash, no gaps, no duplicates. The configuration → integer map is bijective on the set of multiset permutations at the target concentration. This makes the duplicate-elimination passes from 2008 (translation, label-exchange-of-equal-multiplicities, super-periodic, label-rotation) work *unchanged*, just over a much smaller table.

#### The inverse map (Sec. 3.2)

From an integer $y \in [0, C-1]$, recover the configuration:
1. Per-color ranks: $x_i = y \mod C_i$, then $y \leftarrow y / C_i$. Repeat for each color.
2. Per-color binary string: greedy reconstruction — for each position, compare $\binom{\ell-1}{t-1}$ to the remaining rank to decide whether the position is `1` or `0`, then update the rank. Algorithm in Sec. 3.2 (also visualized in Fig. 5).

This is the workhorse of the crossing-out enumeration: iterate $y = 0, 1, \ldots, C-1$, materialize the configuration, check duplicate-flags, advance.

#### Site restrictions: the backtracking tree (Appendix A.1)

When some sites are restricted (e.g., "site 4 cannot be red"), the multinomial hash becomes non-perfect — the table covers all multiplicities $\{a_i\}$, but some entries violate restrictions and must be skipped. Naïvely indexing then post-filtering wastes memory.

The fix: switch from indexing to a **backtracking tree search**. Each tree level fixes the color at one site; branches that violate a site restriction OR exceed a per-color count are pruned. Surviving leaves are the legal colorings. Fig. 7 shows the tree for 4 sites, 3 colors, with combined site + concentration restrictions: 9 of 81 colorings survive.

The Fortran code merges this with the multinomial hash via the bitstring markers (`lab`, `lm`) flagged in Phase 2 as "opaque." The 2012 paper is the documentation of what they're doing — they're encoding the concentration-restricted multiset hash + the site-restriction tree pruning into a compact representation. Knowing this, the bitstring logic becomes legible.

#### Pure counting at fixed concentration (Appendix A.2)

For *just counting* the number of inequivalent configurations at fixed concentration — without generating them — use a Pólya-style extension. For a permutation $\rho$ with cycle lengths $c_1 < c_2 < \cdots < c_t$ (with multiplicities $m_1, \ldots, m_t$, so $\sum m_i c_i = n$), the count of colorings fixed by $\rho$ with target multiplicities $a_1, \ldots, a_k$ is:
$$\sum_{M \in \omega(\rho)} \prod_{i=1}^t \binom{c_i}{M_{i,1}, \ldots, M_{i,k}}$$
where $M$ is a $t \times k$ matrix of non-negative integers satisfying:
$$\sum_{j=1}^k M_{i,j} = m_i \quad \forall i, \qquad \sum_{i=1}^t c_i M_{i,j} = a_j \quad \forall j$$

Average over the symmetry group (Burnside-style) to get the inequivalent count. The paper validated against Maple for an $n=48$ fcc case (a 19-digit decimal answer in 5 minutes; enumeration would be infeasible).

This is the calculation behind the Fortran `polya=.true.` short-circuit. It's a different counting formula from the simple Pólya-cycle-index that would give the all-concentrations count — that one's in `count_full_colorings` in `labeling_related.f90`.

#### Application: Ag–Pt at 15:17 in a 32-atom supercell (Sec. 4)

A 1996 Durussel-Feschotte paper claimed an ordered phase in Ag-Pt at ~53 at% Pt, stoichiometry 15:17, in a $2 \times 2 \times 2$ multiple of conventional fcc (32 atoms). The lattice parameter was about twice the fcc value.

Workflow:
1. Enumerate all 15:17 configurations in the 32-cell: $\binom{32}{17} \approx 5 \times 10^8$.
2. Symmetry reduction: 1536 = 48 (point group) × 32 (translations) → ~400,000 distinct.
3. Cluster expansion (50 first-principles calculations) → energy estimate per configuration.
4. Find the lowest-energy configuration. Result (Fig. 6): a structure resembling L1$_1$ with Pt substitutional defects.
5. Phonon-DOS check: L1$_1$ is vibrationally stable; the 15:17 candidate is not.

Conclusion: the 1996 claim is wrong. **L1$_1$ is the actual ground state, not 15:17.** Demonstrates the practical use of the algorithm: it can refute a published phase-diagram claim.

#### Mapping to Fortran code

| Concept | Fortran |
|---|---|
| Multinomial hash + inverse | `generate_permutation_labelings` (`labeling_related.f90:310-512`); inner loops compute the $x_i$ ranks and the global index |
| Backtracking tree with site restrictions | Same routine; `site_res` array drives the pruning |
| Concentration range partitioning | `get_concentration_list` (`derivative_structure_generator.f90:82-160`), `get_list_at_this_size` |
| Concentration range adjustment for inactive sites | `adjust_crange_for_inactive_sites` (`enumeration_routines.f90:19-75`) |
| Pólya counting at fixed concentration | `polya=.true.` flag → short-circuit in `gen_multilattice_derivatives`; the cycle-counting formula |
| Bitstring markers `lab`, `lm` | The crossing-out flags on the hash table; Phase 2 noted these as opaque, but they're just "this slot has been visited / assigned to an orbit" markers |

#### Mapping to Julia (current state and what's needed)

**None of this is implemented in Enumlib.jl currently.** Phase 6 will need to design:
1. A `Concentration` type carrying multiplicities $\{a_i\}$ and (optionally) a `ConcentrationRange` carrying min/max/denom triples.
2. The mixed-radix hash + inverse — a `MultisetHash` struct or set of free functions. This is a clean, well-bounded chunk to implement and test (Eq. 3 + Sec. 3.2 algorithm). High-confidence Julia rewrite target.
3. Site restrictions as either a per-site `Vector{Set{Int}}` of allowed colors, or a `BitMatrix(n_sites, k_colors)` mask. The latter is what the Fortran "masking matrices" effectively are (Fig. 7).
4. The backtracking tree search — straightforward recursive enumeration in Julia.
5. The Pólya counting routine — a standalone `count_inequivalent(parent, n, k; concentration=nothing, site_restrictions=nothing)` API. Single-purpose, highly testable.

Order of build: counting first (low-risk, gives the pre-flight estimator from Phase 7), then the hash + inverse, then the backtracking, then concentration-range partitioning, then full integration into the dispatch.

#### Terminology added to the glossary

| Term | Meaning |
|---|---|
| Concentration / multiplicity vector | $(a_1, \ldots, a_k)$ with $\sum a_i = n$, specifying how many sites of each species. |
| Concentration range | Per-species `[min_num, max_num, denom]` triple specifying allowed fractions. |
| Multinomial coefficient $C$ | $\binom{n}{a_1, \ldots, a_k} = n! / \prod a_i!$. Number of multiset permutations. |
| Multiset / mixed-radix hash | The 2012 paper's perfect hash from configurations to $[0, C-1]$ via Eq. 3. |
| Site restriction | A per-site constraint excluding certain species. Combined with concentration constraints in the backtracking tree. |
| Pólya counting at fixed concentration | The Burnside-averaged count of inequivalent configurations at given multiplicities, using the cycle-decomposition formula in Appendix A.2. |
| Lattice decoration problem | Synonym for the derivative-structure-enumeration problem. (Used in the 2012 introduction.) |

#### What carries into the rewrite (synthesis with 2008+2009 so far)

The cumulative algorithm after 2008+2009+2012 is the same six steps as before plus a new dispatch on the labeling step:

> **Step 4 (revised).** If concentration is unrestricted, use the $k^n$ base-$k$ hash from 2008. If concentration is fixed (or in a small range), use the multinomial mixed-radix hash from 2012. If site restrictions are present, switch from indexed enumeration to backtracking tree search. If pure counting is requested, use the Pólya extension and short-circuit.

Phase 5 (algorithm dispatch) needs to capture this decision tree explicitly. Phase 6 needs to design the data types so the three modes (unrestricted / fixed-conc / fixed-conc + site-restricted) share infrastructure cleanly. Phase 7 (misuse mitigation) gets the Pólya counting as its first deliverable.

---

### 4.4 Morgan, Hart & Forcade 2017 — *Generating derivative superstructures for systems with high configurational freedom*

**Citation.** Wiley S. Morgan, Gus L. W. Hart, Rodney W. Forcade, *Comp. Mat. Sci.* **136**, 144–149 (2017). DOI: 10.1016/j.commatsci.2017.04.015. PDF: `papers/MorganHartForcade2017_recStabEnumeration.pdf` (6 pages).

#### Problem

The 2008 (full-space crossing-out) and 2012 (fixed-concentration crossing-out) algorithms generate the *whole* labeling table and prune duplicates pass-by-pass. The memory and time scale with the table size — i.e., with $k^n$ or $C(n; a_1, \ldots, a_k)$ — even when the final count of unique structures is small. The 2017 paper observes that for high configurational freedom (large $n$, $k \ge 3$, displacement degrees of freedom), the table grows much faster than the unique-structure count, and the wasted work dominates.

The contribution: **a tree-search algorithm with partial colorings and stabilizer subgroups** that prunes entire subtrees of equivalents in one comparison, instead of generating-then-pruning leaf-by-leaf. Empirically two orders of magnitude faster than 2012 for ternary fcc cells around $n = 20$, and unlocks cell sizes that were previously inaccessible.

This is the "enum4" / `recursively_stabilized_enum` algorithm in the Fortran code, with the supporting `tree_class.f90` machinery.

#### The two key ideas

**(1) Partial colorings.** An intermediate node in the tree where only the first few colors have been placed (e.g., the reds, but not yet the yellows or the purples). All children of that node share the partial placement. If a partial coloring at depth $\ell$ is symmetry-equivalent to one already visited, *every* full coloring beneath it is also a duplicate of one already enumerated → skip the whole subtree.

The example in Fig. 1: 9-atom 2D cell with 2 reds, 3 yellows, 4 purples. After placing only the reds (the first level of the tree), 36 distinct red placements exist. Many are equivalent under symmetry; the equivalent ones (e.g., the rightmost (35, •, •) is equivalent to (0, •, •)) get pruned, taking their entire subtrees with them.

**(2) Stabilizer subgroups.** At each tree node, the *stabilizer* of the partial coloring is the subgroup of the parent's symmetry group that leaves the placed colors invariant. The stabilizer shrinks monotonically with depth — by the time you've placed two colors, the symmetries that fix both are a subgroup of those that fix just one. When checking whether a child node is a duplicate, you only need to apply the parent's stabilizer (not the full point group), because non-stabilizer symmetries have already eliminated equivalents at higher levels.

This shrinking-stabilizer property is what gives the algorithm its asymptotic edge: comparison cost decreases with depth even as the total number of partial colorings grows.

#### The algorithm (Section 3)

For a fixed cell size $n$ and concentration $(a_1, \ldots, a_k)$:

1. **Sort colors by concentration**, smallest first. This minimizes branching at the top of the tree.
2. **Build the tree level by level**, color by color:
   - At depth $\ell$, the node has placed colors $1, \ldots, \ell$. The state is a *location vector* $(x_1, \ldots, x_\ell)$ where each $x_i$ is the per-color rank from the 2012 multinomial hash (which counts placements among the still-empty sites at that level).
   - The number of children of a depth-$\ell$ node is $C_{\ell+1} = \binom{n - a_1 - \cdots - a_\ell}{a_{\ell+1}}$.
3. **For each new partial coloring**, compute its location vector and apply the parent's stabilizer subgroup. If any group element maps the location vector to a *smaller* location vector (lexicographically), this configuration is a duplicate of one already found in the parent's subtree — prune.
4. **Otherwise** the partial coloring is a new representative. Compute its stabilizer (a subgroup of the parent's stabilizer) for use in the next level. Save and descend.
5. **At depth $k$** (all colors placed), record the full coloring.
6. **Backtrack** to the next unexplored sibling.

Concrete example (Section 3, the 9-atom case): brute-force 1260 distinct configurations, Pólya counts 24 unique. The tree search explores only **106 of 1296 candidate nodes** (vs comparing all 1260 pairwise). Confirms the 24 unique configs.

The location-vector mechanism is exactly the 2012 multinomial mixed-radix hash, applied per-level. So the 2017 algorithm is built *on top of* the 2012 hash, not as a replacement.

#### Why the tree wins (memory and time)

- **Memory**: only the path from root to current node + the unique partial colorings already saved at each level. No global table of $C$ entries.
- **Time**: comparisons at depth $\ell$ are against the (much smaller) set of already-saved partial colorings at that level, using the (shrinking) stabilizer subgroup. The expensive comparisons higher up the tree are amortized across many descendants.

Fig. 5 shows the empirical scaling: for fcc ternary at equal concentration, the 2017 algorithm catches up with the 2012 algorithm around $n = 5$ and then pulls ahead, reaching 100× faster at $n = 20$. For quaternary, the gap is similar.

#### Extension to displacement degrees of freedom (Section 3.3)

Each atomic site can also have a displacement direction (e.g., one of 6 cardinal directions in 3D). The trick:
1. Treat displaced atoms as a *different species* — so a binary alloy with displacement becomes effectively quaternary (each original species times two: undisplaced + displaced).
2. Run the color enumeration. After a full configuration is found, restore the arrows (displacement directions) and use the *full configuration's* stabilizer subgroup to check arrow-arrangement uniqueness.
3. Arrow-vector hash (Eq. 3): $x = \sum_{i=0}^k a_i d^i$ — mixed-radix in base $d$.

Adding 2 arrows to the 9-atom example: configurations grow $1260 \to 45360$, but unique structures only $24 \to 663$. The arrow extension is roughly an outer loop on top of the color tree.

**Per user's instruction, we are not porting arrow enumeration to Julia.** The arrow extension is documented here for completeness; the underlying tree algorithm without arrows is what we want.

#### Implementation map (Fortran)

| Concept | Fortran |
|---|---|
| The `tree` OO type | `tree_class.f90` (864 LOC). Methods `init`, `coloring`, `depth`, `increment_location`, `check`, `get_loc`, `add_arrows`. |
| Driver routine | `recursively_stabilized_enum` (`labeling_related.f90:58-270`). |
| Location vector | `tree.loc(:)` field. |
| Branching factor per level | `tree.branches(:)` field. |
| Stabilizer subgroups per layer | `tree.G(:)` (a `GroupList` with one `permList` per layer). |
| Arrow group | `tree.A(:)` — same shape as `G`. **Not bringing this forward.** |
| Per-layer base case (memoization) | `tree.base(:)`. |
| Color count and coloring map | `tree.color_map(:,:)`. |

The Fortran implementation is the cleanest file in the codebase per Phase 2's classification — the OO design carries over to Julia naturally. The arrow code is bolted on and interleaves through; stripping it cleans up substantial complexity.

#### Implementation map (Julia)

Not implemented. Phase 6 design notes:

- **A `Tree` struct** mirroring the Fortran one but without arrow fields. Concrete fields: `colors::Vector{Int}` (the multiplicities $a_1, \ldots, a_k$), `n::Int`, `loc::Vector{Int}` (location vector), `branches::Vector{Int}` (branching factor per level), `stabilizers::Vector{PermutationGroup}` (one per layer), `unique::Vector{Vector{Int}}` (saved unique partial colorings per layer).
- **The methods** are obvious one-to-one translations: `next!`, `check`, `coloring`, etc.
- **Critical reuse**: the location-vector hash is the same machinery as the 2012 multinomial hash. Implement that once in a `MultisetHash` module and use it from both the 2012 crossing-out path and the 2017 tree path.
- **The stabilizer-subgroup computation** needs efficient group operations on permutation lists. Spacey.jl provides point-group operations; the per-layer stabilizer is a filter on a parent group.

#### Open questions raised by this paper

1. **The Pólya pre-flight reference.** Section 3.1 says "a recently developed numerical algorithm for the Pólya enumeration theorem" (refs 16-18) — that's *Pólya, Read 2012*; *Pólya 1937*; **and Rosenbrock, Morgan, Hart, Curtarolo, Forcade *J. Exp. Algorithmics* 21, 1 (2016)**. This last reference is potentially in scope for Phase 8 — it's the numerical Pólya algorithm that powers the pre-flight estimator. Worth grabbing. I put it in the papers folder.

> **Claude:** Renamed your `papers_polya.pdf` → `papers/RosenbrockEtAl_2016_NumericalPolyaEnumerationTheorem.pdf` per our naming convention. Confirmed first page: Rosenbrock, Morgan, Hart, Curtarolo, Forcade, *ACM J. Exp. Algorithmics* **21**, 1.11 (Aug 2016). DOI: 10.1145/2955094. This is the numerical Pólya implementation that the Morgan 2017 tree algorithm references for its pre-flight count. I'll digest it as **§4.6** in a follow-up Phase 4 commit (small addition; one paper). It directly enables Phase 7 (misuse mitigation) since the pre-flight count is the user-protection feature.

2. **The "smallest first" sort order**. Section 3 notes that placing colors smallest-first minimizes top-level branching. This is a heuristic, not proved optimal. Worth checking whether the Julia implementation should preserve this default and whether other orderings ever win. How would we test that?

> **Claude:** Concrete test design (Phase 10 work, but the sketch):
>
> Pick a small panel of cases that span the algorithmic regime — say 8 cases:
> - FCC ternary $n \in \{8, 12, 16, 20\}$ at equal concentration (worst case for branching).
> - HCP ternary $n \in \{4, 6\}$ (multilattice).
> - FCC quaternary $n \in \{8, 12\}$ (high $k$).
>
> For each case, run the recursive-stabilizer enumeration four times with different color sort orders:
> 1. **Smallest first** (Fortran default; minimizes top-level branching factor).
> 2. **Largest first** (opposite extreme).
> 3. **Original order** (whatever order the user supplied).
> 4. **Random** (3 random shuffles per case, take the median).
>
> Measure two things per run: (a) total tree nodes explored, (b) wall-clock time. Tabulate. Smallest-first should win on most cases — if it doesn't on any, that's evidence to change the default. If a *particular* type of case favors a different ordering (e.g., HCP at high $k$ benefits from largest-first), we can document and let users override via a kwarg.
>
> Pre-flight prediction: smallest-first wins on average (the heuristic argument is sound — fewer top-level branches = less stabilizer-group work amortized lower in the tree). Largest-first will likely lose substantially. The interesting question is whether *any* alternative ever beats smallest-first, which would tell us when to expose the kwarg.
>
> One-page benchmark in `bench/sort_order.jl`, run once during Phase 6 implementation, results documented in the design notes.

3. **Arrows vs. our scope**. The arrow material is non-trivially intertwined with the coloring tree in Fortran; the Julia rewrite should design the `Tree` API so that an arrow extension *could* slot in cleanly later without forcing the rest of the code to anticipate it. Phase 6 design responsibility. We don't need the arrows, ever. Even if we did, the design was faulty. We need to start from scratch if we ever do arrows again.

> **Claude:** Updating the directive: arrows are fully out of scope, full stop. Removing the "design Tree API for arrow extensibility" point — that was overcaution and would only complicate the Tree code without payoff. The Julia `Tree` struct will not anticipate arrows in any way. If a future researcher wants arrow enumeration, they design from scratch with a different starting point.
>
> Will also remove the Tree's `arrow_group::GroupList` field hint and the related extension discussion from the rewrite-implications synthesis. One less degree of freedom is one less source of bugs.


#### Terminology added to the glossary

| Term | Meaning |
|---|---|
| Partial coloring | A node in the enumeration tree where only the first $\ell$ colors of $k$ have been placed. All descendants share the placement. |
| Enumeration tree (recursive-stabilizer) | The tree structure built by Morgan-Hart-Forcade 2017. Root = empty lattice; depth $\ell$ = $\ell$ colors placed. |
| Location vector | The per-level rank tuple $(x_1, \ldots, x_\ell)$ identifying a tree node, with each $x_i$ the 2012-style multinomial-hash rank of color $i$'s placement. |
| Stabilizer subgroup of a partial coloring | The subgroup of the (parent) symmetry group that leaves the partial coloring invariant. Shrinks monotonically with tree depth. |
| Pruning a subtree | Skipping all descendants of a node by virtue of the node itself being symmetry-equivalent to one already visited. The single-comparison saving per pruned subtree is the source of the algorithmic speedup. |

#### What carries into the rewrite (synthesis update through 2017)

After 2008+2009+2012+2017, the dispatch landscape is:

| Mode | Path | Memory | Time | When to use |
|---|---|---|---|---|
| Pure counting | Pólya cycle-index | $O(|H|)$ | fast (closed-form) | Pre-flight, scale safety |
| All concentrations | 2008 base-$k$ hash + crossing-out | $O(k^n)$ | $O(k^n)$ | Small $n$, $k=2$ or 3 |
| Fixed concentration, no site restrictions | 2012 multinomial hash + crossing-out | $O(C)$ | $O(C)$ | Narrow $C$ |
| Fixed concentration + site restrictions | 2012 backtracking tree | varies | varies | Narrow $C$ + restrictions |
| High configurational freedom | 2017 recursive-stabilizer tree | $O(\text{tree size})$ | sub-linear in $C$ | Large $n$, $k \ge 3$, big enumerations |

Phase 5 dispatch needs to choose between these based on inputs. Phase 7 misuse mitigation gets pure counting as a free pre-flight estimator. Phase 6 needs the data types to support the union: the location-vector hash and the stabilizer subgroup are both reusable across modes.

---

### 4.5 Shinohara, Seko, Horiyama, Ishihata, Honda & Tanaka 2020 — *Enumeration of nonequivalent substitutional structures using advanced data structure of binary decision diagram*

**Citation.** Kohei Shinohara, Atsuto Seko, Takashi Horiyama, Masakazu Ishihata, Junya Honda, Isao Tanaka, *J. Chem. Phys.* **153**, 104109 (2020). DOI: 10.1063/5.0021663. PDF: `papers/ShinoharaEtAl_2020_BinaryDecisionDiagram.pdf` (15 pages including references).

**Note on attribution:** The paper user described as "the Seko paper" has Shinohara as first author and Seko as second. Both are at Kyoto University; Seko is the corresponding senior author, but Shinohara did the work.

#### Problem

After 2008+2009+2012+2017, the bottleneck for enumeration of large systems is **memory**, not time. Even Morgan-Hart-Forcade 2017 — the streaming tree algorithm — needs $O(\text{tree size})$ memory which grows with the number of unique structures. For
- FCC binary at index 29: enumlib peak memory ~3.0 GB
- FCC ternary at index 19: same order
- HCP at any non-trivial index (because $|D|=2$ doubles the index effectively)

…the workstation's RAM becomes the limit, not patience.

The 2020 paper proposes representing the *set* of nonequivalent labelings as a **Zero-Suppressed Binary Decision Diagram (ZDD)** — a compact graph-based data structure. The result: ~120× less memory at the same scale, pushing accessible cell sizes from index 29 → 48 (binary fcc), 19 → 31 (ternary fcc), 15 → 26 (quaternary fcc).

#### What a ZDD is

A **Binary Decision Diagram (BDD)** is a rooted directed acyclic graph representing a Boolean function. Each non-terminal node corresponds to a variable; each node has a 1-edge and a 0-edge to its children; paths from the root to the 1-terminal correspond to satisfying assignments. Originally introduced by Bryant (1986, 1992) for circuit verification.

A **Zero-Suppressed Binary Decision Diagram (ZDD)** (Minato 1993) is a variant designed for *sparse* set families — situations where most variables in any given member are 0. The reduction rules differ slightly from regular BDDs:

1. **Node elimination:** any node whose 1-edge points directly to the 0-terminal is eliminated (the variable is forced to 0 in any satisfying solution including this node).
2. **Node sharing:** any two nodes with the same variable, the same 0-child, and the same 1-child are merged.

Result: a ZDD canonically represents a family of subsets, and is exponentially more compact than the explicit list when the family has structure.

#### How they apply ZDD to derivative-structure enumeration (Section IV)

**Binary case (Sec. IV.C.1):**

Given a sublattice $L_M$ with permutation group $\Sigma_M$, the set of nonequivalent labelings $\mathcal{C}_{M,2}$ is defined as the lex-maximum labeling in each orbit (Eq. 9). For each $\sigma \in \Sigma_M$, build a ZDD $\tilde{\mathcal{C}}_{M,2}^{(\sigma)}$ representing labelings $c$ with $c \ge \sigma(c)$ in lex order (Eq. 15). Then intersect across all $\sigma \in \Sigma_M$ (Eq. 16):
$$\mathcal{C}_{M,2} = \bigcap_{\sigma \in \Sigma_M} \tilde{\mathcal{C}}_{M,2}^{(\sigma)}$$
Each path from root to 1-terminal in the resulting **isomorphism-eliminated ZDD** corresponds to one unique labeling.

**Multicomponent case (Sec. IV.C.2):**

For $k \ge 3$, encode the labeling $\mathbf{c} \in \{0, \ldots, k-1\}^{|D_M|}$ as a **one-hot binary encoding** $\tilde{\mathbf{c}} \in \{0, 1\}^{k \cdot |D_M|}$ where $\tilde{c}_{i,p} = 1$ iff $c_i = p$ (Eq. 17–18). Add the constraint that exactly one species per site is hot:
$$\sum_{p=0}^{k-1} \tilde{c}_{i,p} = 1 \quad \forall i$$
Build a ZDD enforcing the one-of-$k$ constraint (call it $\tilde{\mathcal{C}}_{\text{one-of-}k}$) and intersect with the isomorphism-eliminated ZDDs:
$$\tilde{\mathcal{C}}_{M,k} = \tilde{\mathcal{C}}_{\text{one-of-}k} \cap \Bigl(\bigcap_{\sigma \in \Sigma_M} \tilde{\mathcal{C}}_{M,k}^{(\sigma)}\Bigr)$$

**Construction technique (Appendix B):** the **frontier-based method** (Iwashita-Nakazawa-Kawahara-Uno-Minato 2013, ref 23). It's a dynamic-programming construction that tracks only the "frontier" — the set of variables already decided that need to be remembered for future merges. Without frontier-based construction, building the binary decision tree first and reducing it to a ZDD loses ZDD's main advantage. The paper used the open-source library **TdZdd** (https://github.com/kunisura/TdZdd) for the actual ZDD operations.

**Optional constraints (Section VI):** ZDDs for *eliminating superperiodic structures* (Eq. 33), *eliminating incomplete labelings* (Eq. 34), and *fixing composition* (Eq. 36) are constructed similarly and intersected. So all of the constraints from the 2008/2012 papers compose cleanly in the ZDD formalism — they're just additional intersection terms.

#### Empirical scaling vs enumlib (Section V, Figs. 8–10, 13)

| System | enumlib max index reachable | ZDD max index reachable | Enumeration count gain |
|---|---|---|---|
| FCC, $k=2$ | 29 | 48 | $10^{15}$ (cumulative) vs $10^9$ |
| FCC, $k=3$ | 19 | 31 | comparable factor |
| FCC, $k=4$ | 15 | 26 | comparable factor |
| HCP, $k=2$ | not reported | 50 sites (= index 25) | — |
| HCP, $k=3$ | not reported | 30 sites (= index 15) | — |

- **Memory at fcc binary index 29:** enumlib peak ~3.0 GB; ZDD peak ~25 MB. **~120× less.**
- **Compression:** ZDD nodes are ~$10^4$× fewer than the labelings they represent (at the upper end). E.g., $10^{12}$ nonequivalent labelings stored in $10^8$ non-terminal nodes.
- **Time:** ZDD is *not* uniformly faster than enumlib at all indices. Fig. 10 shows that for binary and small indices, enumlib can be similar or faster; ZDD pulls ahead at larger indices because enumlib hits the memory wall first. The ZDD wins are primarily memory-driven, secondarily time.

The number of nonequivalent labelings derived from the ZDD matches Pólya counting exactly — confirms correctness via independent route.

#### Implementation reality check

The Fortran enumlib + Morgan tree are good algorithms; ZDD is a *different* representation. For a Julia rewrite, what does this paper actually say to do?

1. **Don't replace enum4 with a ZDD implementation as the default.** The 2017 tree streams structures one at a time, which is what users typically want — they need to write each structure to disk (POSCAR), feed it into a DFT code, etc. ZDD stores the *set* compactly but you still have to traverse paths to get individual structures, and the paper doesn't claim ZDD streaming is faster than the 2017 tree.
2. **Do consider ZDD as an *optional* representation for very large enumerations.** The user-facing case is: "I have an enumeration with $10^{14}$ candidates, I just want to know how many there are or to enumerate a particular subset matching a constraint." For that workload, ZDD lets you compute the count and enumerate filtered subsets without ever materializing the whole set.
3. **The Julia ecosystem has no mature ZDD library.** TdZdd is C++. Implementing a ZDD library in Julia (especially with frontier-based construction) is a substantial undertaking — probably 1-2 person-months of careful work. This is a "v0.3 optimization" candidate, not a v0.1 must-have.
4. **The non-isomorphism elimination idea (Eq. 9 / ref 25)** is what's load-bearing in the paper, and it's *independent* of ZDD: defining the unique representative of an orbit as the lex-maximum labeling. The 2008-2017 algorithms use the equivalent but slightly different "first reached in tree traversal" convention. Worth a Phase 6 design check: is lex-maximum a cleaner canonical representative than depth-first-first?

#### Reference harvest (per user request)

Phase 8 follow-up candidates surfaced by this paper's bibliography:

| Ref | Citation | Why interesting |
|---|---|---|
| 16 | Mustapha, D'Arco, De La Pierre, Noël, Ferrabone, Dovesi, *J. Phys.: Condens. Matter* **25**, 105401 (2013) | A non-enumlib enumeration approach (CRYSTAL code group at Torino). Worth comparing — a third school of derivative-structure enumeration. |
| 23 | Iwashita, Nakazawa, Kawahara, Uno, Minato, Tech. Rep. TCS-TR-A-10-64 (2013) | Frontier-based method for ZDDs. Foundation of the present paper's algorithm. |
| 25 | Horiyama, Miyasaka, Sasaki, *Proc. Canad. Conf. Comput. Geom.* (2018) | Non-isomorphism elimination via lex-maximum representative — the heart of this paper, and possibly relevant to Phase 6's canonical-representative choice. |
| 35 | Bryant, *IEEE Trans. Comput.* **C-35** (1986) | Original BDD paper. Foundation. |
| 36 | Bryant, *ACM Comput. Surv.* **24** (1992) | BDD survey paper. |
| 39 | Togo, Tanaka, "Spglib," arXiv:1808.01590 | Symmetry-finding library. Already a known dep candidate (could replace Spacey for some cases or complement it). |
| 7 | Predith, Ceder, Wolverton, Persson, Mueller, *Phys. Rev. B* **77**, 144104 (2008) | Symmetry-adapted configurational ensemble approach to site-disordered solids. Possibly relevant for Phase 9 (pymatgen — Ceder, Persson are pymatgen contributors). |
| 2 | Huang, Kitchaev, Dacek, Rong, Urban, Cao, Luo, Ceder, *Phys. Rev. B* **94**, 134424 (2016) | Configurational disorder in alloys. Same group; pymatgen-adjacent. |

These are the "big ask" Phase 8 candidates. Recommendation: in Phase 8, hunt down refs 25 and 16 first (algorithmic), then 7 and 2 for pymatgen context, then the BDD foundations 35/36 for completeness. Each is one PDF and a paragraph in research.md.

#### Terminology added to the glossary

| Term | Meaning |
|---|---|
| Binary Decision Diagram (BDD) | Rooted DAG representing a Boolean function. Internal nodes = variables; 1-edge/0-edge children; paths to 1-terminal = satisfying assignments. Bryant 1986. |
| Zero-Suppressed BDD (ZDD) | Variant of BDD optimized for sparse subset families. Reduction rule: nodes whose 1-edge points to 0-terminal are eliminated. Minato 1993. |
| Frontier-based method | DP-style ZDD construction algorithm tracking only the "frontier" of decided variables relevant to future merges. Avoids materializing the full binary decision tree. Iwashita et al. 2013. |
| Isomorphism-eliminated ZDD | A ZDD whose 1-paths correspond exactly to one representative per symmetry orbit (lex-maximum). The intersection of pairwise-comparison ZDDs $\tilde{\mathcal{C}}^{(\sigma)}$ over all $\sigma$ in the symmetry group. |
| Non-isomorphic permutation group | The set of distinct permutation groups arising from non-equivalent sublattices for a given index. Different from the count of HNFs because two HNFs can give the same permutation group. |
| One-hot encoding | Encoding $k$-ary labels as $k$-bit binary vectors with exactly one bit set per site. Used in the 2020 paper to extend the ZDD method from binary to multicomponent. |
| Lex-maximum representative | Convention for choosing one representative per symmetry orbit: the maximum labeling in lexicographic order. Used by Shinohara et al. 2020; alternative to the depth-first canonical representative used in Hart-Forcade 2008. |

#### What carries into the rewrite (synthesis update through 2020)

After all five papers, here's the cumulative algorithmic landscape:

| Mode | Algorithm | Memory | Best for | Status for Julia rewrite |
|---|---|---|---|---|
| Pure counting | Pólya / Burnside | $O(|H|)$ | Pre-flight, scale safety | **v0.1 priority** (Phase 7 deliverable) |
| All concentrations, small $n$, $k \le 3$ | 2008 base-$k$ hash + crossing-out | $O(k^n)$ | Small cases | v0.2 — implementing full crossing-out is medium effort |
| Fixed concentration, no site restrictions | 2012 multinomial hash + crossing-out | $O(C)$ | Narrow concentration | v0.2 |
| Fixed concentration + site restrictions | 2012 backtracking tree | varies | Narrow $C$ + restrictions | v0.2 |
| High configurational freedom | 2017 recursive-stabilizer tree | $O(\text{tree size})$ | Large $n$, $k \ge 3$, big enumerations | **v0.2 priority** — the modern default |
| Memory-bound very large enumerations | 2020 ZDD | $O(\text{ZDD nodes})$ — much smaller | Very large $n$, count + filter | v0.3 optimization (substantial implementation cost) |

For the immediate rewrite (v0.1 → v0.2), focus on Pólya counting + the 2008/2012/2017 algorithms with clean dispatch. ZDD is a v0.3+ optimization for users who hit the memory wall the 2017 tree creates. It also raises an open question for Phase 6: should the canonical representative of an orbit be lex-maximum (2020 convention) or depth-first-first (older convention)? Lex-maximum is cleaner mathematically and composes with the ZDD formalism, but the 2017 tree algorithm uses location-vector ordering which is its own thing. Worth a deliberate decision rather than inheriting one by accident.


---


## Phase 5 — Algorithmic dispatch strategy

Phase 4 surfaced five algorithmic modes that the rewrite needs to support, plus pure counting. Phase 5 designs the *public-facing* API: one entry point, auto-dispatch with explicit override, separate top-level entry for counting, lazy iteration as default. Type names (`Site`, `Supercell`, `EnumeratedStructure`, etc.) are placeholders here — Phase 6 will lock them down.

### 5.1 Goals

- **One canonical user-facing function** for enumeration (`enumerate`), one for counting (`count_inequivalent`). No `polya=true` short-circuits hidden inside enumerate; counting is its own thing.
- **Auto-dispatch by default**, explicit-override always available. Default behavior chooses the best-fit algorithm given inputs; users who know what they want pass `algorithm=:multinomial` or similar.
- **Lazy iteration as default output** (per §3.2 review): `enumerate(...)` returns a `Channel`-like / `Iterator` that streams `EnumeratedStructure` values. `collect()` materializes when needed.
- **BigInt-safe**: counts can be `BigInt`; labelings can be `BigInt` if the configuration space overflows `Int64` (binary $n>62$, ternary $n>39$, …).
- **Pre-flight by default for scale safety**: when auto-dispatch detects an enumeration that would exceed a memory threshold, it raises a clear error suggesting either `algorithm=:recursive_stabilizer` (streams without the bitmap), `:bdd` (future), or `count_only=true`.

### 5.2 The public API

A small surface — three functions plus the kwargs.

```julia
# (1) Enumerate. Returns a lazy iterator.
function enumerate(parent::ParentLattice,
                   sites::Vector{Site};
                   volume_range::AbstractRange{Int},     # required (no default — see §5.11 Q1)
                   concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                   fixed_cells::Union{Nothing, Vector{HNF}} = nothing,
                   algorithm::Symbol = :auto,
                   memory_budget::Int = 8 * 2^30,   # 8 GiB default
                   on_overflow::Symbol = :error)    # :error, :warn, or :ignore
    ...
end

# (2) Count without enumerating. Pólya / fixed-conc Pólya.
function count_inequivalent(parent::ParentLattice,
                            sites::Vector{Site};
                            volume_range::AbstractRange{Int} = 1:10,
                            concentration = nothing) :: BigInt
    ...
end

# (3) Estimate memory + time for an upcoming enumeration. Wraps count_inequivalent
#     and adds the per-mode bookkeeping cost. Returns a small struct so the user
#     can decide whether to proceed.
function estimate_cost(parent::ParentLattice,
                       sites::Vector{Site};
                       kwargs...) :: EnumerationCostEstimate
    ...
end
```

Three other things the API doesn't do:

- **No file paths.** Reading `struct_enum.in` lives in `Enumlib.LegacyImport.read_struct_enum_in(path)` and returns the four arguments above. No magic-file loading from the main entry.
- **No mutable state.** No `setupChebyTable(k)`-style side effects. Caches that are needed are computed once per call and live inside the iterator's state.
- **No global config.** `memory_budget` and `on_overflow` are kwargs, not module-level settings.


Actualy I understood this from the beginning except I misread that these argument were optional arguments, keyword args
> **Claude:** Quick Julia idiom primer since you flagged this for both `concentration` and `fixed_cells`:
>
> **`Union{Nothing, T}` is Julia's "optional" type.** It says "this kwarg accepts either a value of type `T` or the special value `nothing`". Roughly equivalent to `Optional<T>` in Java, `T?` in Kotlin/Swift, or `Maybe T` in Haskell. The Julia community pattern is to use `Union{Nothing, T}` for kwargs where "no value supplied" needs to be distinguishable from "some specific default value."
>
> **Why `nothing` and not just a default?** For `volume_range = 1:10`, the default *is* a value (the range 1:10). The user can override it. For `concentration`, there is no natural default value — "no concentration constraint at all" is conceptually different from "constrain to some specific concentration." `nothing` represents that absence cleanly.
>
> Concrete: a user calling
>
> ```julia
> enumerate(fcc, sites; volume_range=1:8)
> ```
>
> doesn't pass `concentration`, so it defaults to `nothing` → "no concentration constraint, enumerate everything." Internally the function checks `if concentration === nothing` and runs the unrestricted path.
>
> A user calling
>
> ```julia
> enumerate(fcc, sites; volume_range=32:32, concentration=Concentration([15, 17]))
> ```
>
> passes a `Concentration` value → constrained enumeration.
>
> The user almost never types `concentration=nothing` explicitly — it's the default. They just *omit* the kwarg when they want the unrestricted case.
>
> **Why this is preferable to alternatives:**
> - **Sentinel default** like `concentration = AllConcentrations()`: more verbose, requires inventing a sentinel type, and the value `AllConcentrations()` carries no useful information beyond "no constraint." `nothing` is the standard Julia way to say that.
> - **Separate functions** like `enumerate_unrestricted(...)` vs `enumerate_at_concentration(...)`: doubles the API surface and makes documentation harder.
> - **Multiple dispatch** on a singleton type: works but typically used when the unrestricted and restricted paths have *very* different behavior; here they share most of the dispatch tree, so kwarg-based switching is cleaner.
>
> **Where this idiom appears in Base Julia:**
> - `findfirst(f, A)` returns `Union{Nothing, Int}` — `nothing` if no match, `Int` if found.
> - `tryparse(Int, str)` returns `Union{Nothing, Int}` — same pattern.
> - `Iterators.peel(itr)` returns `Union{Nothing, Tuple}`.
>
> So `Union{Nothing, T}` is idiomatic, not exotic. Once you've internalized it, the pattern reads as "this is optional; the typical caller omits it."
>
> Same idiom for `fixed_cells = nothing`: omit it (default), and HNFs are enumerated freshly per the algorithm; pass `fixed_cells = my_hnf_list`, and only those HNFs are considered.


### 5.3 The algorithm modes

Five live modes plus the future BDD slot:

| `algorithm` value | Source paper | Memory | Best for | Status |
|---|---|---|---|---|
| `:exhaustive` | 2008 | $O(k^n)$ | Small $n$, no concentration restriction; reference correctness | v0.2 |
| `:multinomial` | 2012, no site restrictions | $O(C)$ where $C = \binom{n}{a_1,\ldots,a_k}$ | Fixed concentration, no site restrictions | v0.2 |
| `:multinomial_restricted` | 2012, backtracking tree | varies (typically $\ll C$) | Fixed concentration + site restrictions | v0.2 |
| `:recursive_stabilizer` | Morgan 2017 | $O(\text{tree size})$, streaming | Large $n$, $k \ge 3$, no memory bound | **v0.2 priority** (default) |
| `:bdd` | Shinohara 2020 | $O(\text{ZDD nodes})$ | Memory-bound very-large enumerations | v0.3 |
| `:auto` | dispatch (this section) | — | default | v0.2 |

Plus pure counting (no enumeration generated):

| `count_inequivalent` mode | Source | Notes |
|---|---|---|
| Full Pólya | Pólya 1937 + Rosenbrock 2016 numerical implementation | Counts at all concentrations |
| Fixed-concentration Pólya | HNF 2012 Appendix A.2 | Counts at a target multiplicity vector |

The Rosenbrock 2016 paper (`papers/RosenbrockEtAl_2016_NumericalPolyaEnumerationTheorem.pdf`) provides the numerical algorithm that makes these counts cheap in practice — to be digested as §4.6 in a follow-up Phase 4 commit.

Is this algorithm something others might use? Should we put it in a separate package and share it? Or is it too niche?

> **Claude:** Plausible audience exists, but I'd lean against extracting on day one. Reasoning:
>
> **Who else might use it.** Pólya enumeration is a general counting principle for orbits of finite group actions on functions. Real users beyond derivative-structure enumeration:
> - **Combinatorial chemistry / chemical graph theory.** Pólya himself was motivated by counting isomers; Read & Tarjan and others built on this. Anyone counting molecules-up-to-symmetry uses some form of Pólya.
> - **Algebraic combinatorics.** Cycle index manipulation appears in many problems involving finite group actions on functions (necklace counting, partition problems, Latin squares).
> - **Computer-aided enumeration in CS.** Enumerating equivalence classes of graphs, tilings, designs — Pólya gives a closed-form count when the group action is known.
> - **Niche enough that a Julia-native polished implementation probably doesn't already exist.** `Combinatorics.jl` has `multinomial` and basic permutation utilities but not the Rosenbrock-style numerical Pólya. `Nemo.jl`/`Hecke.jl` are about commutative algebra, not Pólya enumeration. A targeted small package would have a real (if small) audience.
>
> **Why not extract on day one:**
> - **Maintenance overhead.** Two repos, two registrations, two CI setups, separate version compatibility to manage. Worth it only if the audience materializes.
> - **API risk.** While we're still designing how Enumlib uses it, the Pólya counter's API will shift. Extracting prematurely freezes a draft API. Extract once it's stable internally.
> - **Discoverability cost.** A separate `Polya.jl` adds a search path; Enumlib's users find the function via Enumlib's docs without thinking about packaging.
>
> **Recommendation:**
> 1. Implement the Rosenbrock numerical Pólya inside Enumlib as a submodule (e.g., `Enumlib.Polya` with `polya_count(group, k, n)` and friends).
> 2. Keep the submodule's API clean and self-contained — no leakage of Enumlib types into it.
> 3. Once Enumlib v0.2+ is stable, do a small extraction PR: move `Enumlib.Polya` → `Polya.jl`, add it as a dep of Enumlib. Low-friction at that point.
> 4. Announce the extraction on Julia Discourse / chemistry channels to find the audience.
>
> This is the standard "extract when needed, not before" pattern. Phase 8 (literature survey) gets a small to-do: check if anyone in the Julia ecosystem has already published a Pólya counter we could use or contribute to instead of writing our own.
I accept your recommendation

### 5.4 The auto-dispatch decision tree

`algorithm = :auto` walks a decision tree. The tree is short:

```
Inputs: parent, sites, volume_range, concentration, fixed_cells, memory_budget

1. If `concentration == nothing` (no concentration restriction):
   1a. Estimate `total = sum(k^(n*nD) for n in volume_range)` (or BigInt).
   1b. If `total * sizeof(visited_bit) ≤ memory_budget`:
       → :exhaustive  (2008 algorithm, full crossing-out)
   1c. Else:
       → :recursive_stabilizer  (2017 streaming tree)

2. Else (concentration restriction is set):
   2a. If `any(site.allowed_labels has < k labels for site in sites)` (site restrictions):
       → :multinomial_restricted  (2012 backtracking)
   2b. Else:
       2b.i. Estimate `C = sum(multinomial(n*nD; concentration*n*nD) for n in volume_range)`.
       2b.ii. If `C * sizeof(visited_bit) ≤ memory_budget`:
              → :multinomial  (2012 crossing-out)
       2b.iii. Else:
              → :recursive_stabilizer  (2017, also handles fixed concentration)
```

A few notes:

- **`:recursive_stabilizer` is the catch-all for "too big to materialize."** Per Morgan 2017 it streams without keeping a global bitmap, so it's robust to large enumerations.
- **`:bdd` is not in `:auto` for v0.2.** When implemented, it slots in as a memory-pressure fallback below `:recursive_stabilizer`. Currently the user opts in explicitly.
- **`fixed_cells` (constraining HNFs to a user-supplied list) doesn't change the dispatch** — it just restricts the HNF set fed into whichever algorithm runs.

### 5.5 The pre-flight gate

Even with `:auto`, very large requests will overflow the chosen algorithm's resources (e.g., user asks for binary $n=70$ at all concentrations — the bitmap alone is $2^{70}$ bits = 128 EiB). The pre-flight check happens *before* the iterator starts emitting:

```julia
estimate = estimate_cost(parent, sites; kwargs...)
if estimate.peak_memory > memory_budget
    on_overflow == :error  && throw(EnumerationTooLargeError(estimate))
    on_overflow == :warn   && @warn "Enumeration may exceed memory budget" estimate
    on_overflow == :ignore && nothing
end
```

`EnumerationTooLargeError` carries the estimate and a suggested mitigation (often "use `:recursive_stabilizer`" or "set `concentration=...` to narrow the search"). This is the user-protection feature §2.10 #1 (the hardwired `max_binomial`) deserved but never got.

### 5.6 What `enumerate(...)` actually yields

The iterator's element type is `EnumeratedStructure` (Phase 6 will lock this; provisional shape):

```julia
struct EnumeratedStructure
    supercell_id::Int           # index into a separate Vector{Supercell}, shared across structures
    labeling::LabelingRepresentation   # Vector{Int8} or Int (BigInt) — see §6 for choice
    hnf_degeneracy::Int
    labeling_degeneracy::Int
    concentration::Vector{Int}   # multiplicities (a_1, ..., a_k)
end
```

The iterator also makes the `Vector{Supercell}` reachable so the user can access HNF/SNF for each yielded structure without re-computation. Two convenience accessors close the loop:

```julia
hnf(s::EnumeratedStructure, enum::Enumeration)        :: SMatrix{3,3,Int}
real_space_atoms(s, enum) :: Vector{SVector{3,Float64}}   # the (HNF, labeling) → atomic positions mapping
```

`real_space_atoms` is `map_enumStr_to_real_space` from the Fortran's `enumeration_utilities.f90`. It's the missing piece for DFT-output workflows (POSCAR writing etc.) per §3.4 priority (1).

### 5.7 Multilattice and inactive-site handling — orthogonal to dispatch

**Multilattice.** Multilattices ($n_D > 1$) don't affect dispatch at all. They affect the *sizes* the dispatch sees: a binary $n=10$ HCP enumeration has $n \cdot n_D = 20$ "effective sites" feeding into the labeling space. The decision tree applies to $n \cdot n_D$ uniformly.

**Inactive sites and equivalencies.** Same story: they're normalized into the `Vector{Site}` at the API boundary (any site with a single allowed label is "inactive"; any pair of sites with `equivalent_to == j` collapses into a Union-Find class), and the algorithm sees only the *active*, *canonical* sites. The internal representation is unified — Phase 6 design point — and dispatch is concentration-and-site-restriction-aware via the kwargs above.

This is the cleanup of the Fortran's parallel-array soup (`dFull/d`, `labelFull/label`, `equivalencies`, `inactives`) into a single `Vector{Site}`: dispatch reads what it needs from that vector, no special-casing.

### 5.8 Worked examples

```julia
using Enumlib

# FCC binary, all concentrations, up to 12 sites — exhaustive (2008) auto-picked.
fcc = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
sites = [Site(zero_position, allowed=[0,1])]
for s in enumerate(fcc, sites; volume_range=1:12)
    write_poscar("POSCAR.$(s.supercell_id).$(s.labeling)", s, fcc, sites)
end

# Fixed-concentration Ag–Pt 15:17 in a 32-site cell — multinomial (2012) auto-picked.
agpt_sites = [Site(zero_position, allowed=[0,1])]
agpt = enumerate(fcc, agpt_sites;
                 volume_range=32:32,
                 concentration=Concentration([15, 17]))
println(length(collect(agpt)), " distinct 15:17 structures")

# HCP ternary, n up to 8 — recursive_stabilizer (2017) auto-picked because |D|=2
# pushes the labeling-space size past the memory budget.
hcp = ParentLattice(hcp_basis, dset=[zero, hcp_offset])
hcp_sites = [Site(p, allowed=[0,1,2]) for p in hcp.dset]
hcp_struct = enumerate(hcp, hcp_sites; volume_range=1:8)

# Pre-flight: how many configurations would FCC quaternary n=20 produce?
n_struct = count_inequivalent(fcc, [Site(zero, allowed=[0,1,2,3])];
                              volume_range=20:20)
@show n_struct       # BigInt; useful for sanity-checking before launching

# Explicit override: force the recursive-stabilizer tree even when auto would pick exhaustive.
for s in enumerate(fcc, sites;
                   volume_range=1:6,
                   algorithm=:recursive_stabilizer)
    process(s)
end
```

### 5.9 Decision points for Phase 6 (open)

These are the threads Phase 6 needs to settle so Phase 5 can be implemented:

1. **`Site` representation** — already discussed; Union-Find for equivalencies, `BitSet` for `allowed_labels`, etc.
2. **`Concentration` vs `ConcentrationRange`** — single multiplicity vector vs. min/max/denom triples per species. Range decomposition into a list of single-concentration calls happens inside the dispatcher.
3. **`LabelingRepresentation`** — `Vector{Int8}` (decoded) vs `Int64`/`BigInt` (hash). Phase 4-review §2.8 flagged this as a Phase 6 decision; my tentative is "Vector{Int8} for v0.1 default; integer-hash representation as an opt-in for memory-bound cases."
4. **Iterator implementation choice** — `Channel{EnumeratedStructure}`, custom `iterate` method on a state struct, or `Base.AsyncCollections.@spawnall`-style. Each algorithm mode wants different things; the dispatcher hides this behind the common `Iterator{EnumeratedStructure}` interface.
5. **`fixed_cells` shape** — `Vector{HNF}` of integer matrices, or a more structured `FixedCells` carrying user-supplied symmetry info if any. Phase 6 design point.
6. **Where `:bdd` slots in** — in `:auto`'s decision tree once implemented (v0.3+); for now it's user-opt-in only.

### 5.10 Comparison with the Fortran dispatch

To be explicit about what's being replaced:

| Fortran | Julia equivalent |
|---|---|
| `driver.f90 + driver_polya.f90` (CLI executables) | `enumerate(...)` and `count_inequivalent(...)` (functions) |
| `polya=true/false` flag | Separate function `count_inequivalent` |
| `origCrossOutAlgorithm=true/false` flag | `algorithm=:exhaustive`, `:multinomial`, `:multinomial_restricted`, `:recursive_stabilizer`, `:bdd` |
| Hardwired `max_binomial = 1E10` threshold (`derivative_structure_generator.f90:1268`) | `memory_budget` kwarg with explicit error / warning |
| `concCheck=true/false` + `cRange` | `concentration::Union{Nothing, Concentration, ConcentrationRange}` |
| Site restriction inferred from `digit < k` | First-class via `Site.allowed_labels` |
| Inactive sites detected via `digit == 1` | First-class via `Site` with single `allowed_labels` |
| Implicit `inactives` table populated by `make_inactive_table` | Implicit in the `Vector{Site}` after construction; no separate table |
| Equivalencies as a `nD`-element integer array | Union-Find inside `Vector{Site}` |
| Direct write to unit 14 | Iterator yielding `EnumeratedStructure` values |

The named-symbol algorithm choice + auto-dispatch + memory-budget kwarg replace three separate Fortran knobs (`origCrossOutAlgorithm`, `polya`, `max_binomial`) with a coherent API. The first-class `Site` type subsumes four parallel arrays. The iterator subsumes the file-output coupling.

### 5.11 Open questions for the user

1. **Defaults.** I've defaulted `volume_range = 1:10`, `memory_budget = 8 GiB`, `on_overflow = :error`. Reasonable? The volume default in particular is a guess — it's small enough to be safe, but a user wanting a serious enumeration will always pass their own. Alternative: no default, force the user to specify. No default is my preference.

> **Claude:** Updated the function signature in §5.2 to drop the default — `volume_range::AbstractRange{Int}` is now required. Calling `enumerate(parent, sites)` without it is a `MethodError`. Forces the user to think about the search space rather than silently accept whatever I picked.
>
> Keeping `memory_budget = 8 GiB` and `on_overflow = :error` defaults — those are *safe* defaults (they protect the user from accidentally launching a too-large run), and the user almost never wants to override them on the first call. If you'd prefer those required too, easy change.

2. **`count_inequivalent`'s return.** I have it returning `BigInt`. Could also return a struct that breaks the count down by volume / concentration / supercell. Useful when the user wants to see "where are all my structures coming from." Worth it, or wait? Tell me more about the possibility of returning the struct with more info

> **Claude:** Sketch of what a richer return looks like. Two-tier API:
>
> ```julia
> # Tier 1: just give me the number.
> n = count_inequivalent(parent, sites; volume_range=1:20)   # → BigInt
>
> # Tier 2: give me the breakdown.
> breakdown = count_inequivalent_breakdown(parent, sites; volume_range=1:20)
> # → InequivalentCount, with fields:
> #     total::BigInt
> #     by_volume::Vector{Tuple{Int, BigInt}}
> #     by_concentration::Vector{Tuple{Concentration, BigInt}}    # if concentration was a range
> #     by_hnf_class::Dict{HNFClassId, BigInt}                    # per-symmetry-class HNF count
> ```
>
> Or as a single function with a kwarg:
>
> ```julia
> # Default returns BigInt.
> n = count_inequivalent(parent, sites; volume_range=1:20)
>
> # Pass `breakdown=true` to get the full struct instead.
> b = count_inequivalent(parent, sites; volume_range=1:20, breakdown=true)
> b.total                    # BigInt
> b.by_volume[5]             # (5, count_at_n_5)
> ```
>
> **What the breakdown is good for.** Concrete cases I've seen this pattern matter:
>
> - **"Why is my enumeration so big?"** User asks for FCC ternary $n \in 1:20$ and gets $10^{12}$ structures. The breakdown shows $99.9\%$ of those are at $n=18, 19, 20$. They cap at $n \le 17$ and life is good.
> - **"Which concentrations matter for my phase diagram?"** User scans a concentration range; the per-concentration count tells them which compositions are dense enough to be worth running DFT on, and which are sparse enough that random sampling would miss things.
> - **"Is this HNF class doing something weird?"** Per-HNF-class counts surface degeneracy patterns. If one HNF class produces 100× more configs than its neighbors, that's diagnostic.
>
> **Cost of supporting it.** The Pólya algorithm computes per-volume / per-concentration counts as part of its work anyway — they're intermediate values inside the cycle-index sum. Returning them costs zero extra computation; just don't discard. The struct is ~10 lines of code; the kwarg adds ~3 lines of dispatch.
>
> **My recommendation:** ship Tier 1 (BigInt return) in v0.2, add Tier 2 in v0.2.x or v0.3 once we've seen what users actually want from the breakdown. Risk is low (purely additive) so deferring isn't dangerous. But if you'd like Tier 2 in v0.2 from the start, it's small.

Let's do Tier 2 in v0.2 from the start

> **Claude:** Locked in. v0.2 ships both `count_inequivalent(...)` returning `BigInt` and `count_inequivalent(...; breakdown=true)` returning `InequivalentCount`. Phase 6 puts `InequivalentCount` in the type catalog with the four fields (`total`, `by_volume`, `by_concentration`, `by_hnf_class`).

>
> Tentative shape locked in for Phase 6: `InequivalentCount` struct exists in the type catalog regardless of whether it's the immediate return. Then we can wire either API on top.

3. **`estimate_cost` separate function.** I split it from `enumerate` — i.e., a user can call `estimate_cost(...)` to see the predicted memory before deciding to launch. Necessary, or just bake it into the pre-flight inside `enumerate`? Like have a separate function too

> **Claude:** Confirmed. Both: `estimate_cost(...)` is a public function the user can call to get a `EnumerationCostEstimate` (peak memory, predicted wall time, predicted structure count, recommended algorithm choice). And `enumerate(...)` *also* internally calls `estimate_cost` as part of its pre-flight gate, so the user gets protection automatically without explicit estimation.
>
> Two separate APIs serving the same machinery: explicit when you want to plan, automatic when you don't.

4. **Future: streaming compute callbacks.** A common pattern would be `enumerate(...; on_each = s -> compute_energy(s))` so the user doesn't have to wire up an explicit `for` loop. Worth supporting from v0.2, or leave it to the user to compose `for` over the iterator? Tell me more about what you are thinking here?

> **Claude:** The idea is a convenience shorthand for the most common downstream workflow: "enumerate, compute something on each, save it." Today the user writes:
>
> ```julia
> for s in enumerate(fcc, sites; volume_range=1:8)
>     energy = compute_dft(s)
>     save_to_database(s, energy)
> end
> ```
>
> That's already idiomatic Julia and works fine. The "callback" form would be:
>
> ```julia
> enumerate(fcc, sites; volume_range=1:8,
>           on_each = s -> begin
>               energy = compute_dft(s)
>               save_to_database(s, energy)
>           end)
> ```
>
> Or with a named function:
>
> ```julia
> compute_and_save(s) = save_to_database(s, compute_dft(s))
> enumerate(fcc, sites; volume_range=1:8, on_each = compute_and_save)
> ```
>
> **Where it might pay off:**
> - **Parallelism.** If we want to fan out the per-structure work across threads, a callback API can do that internally (`Threads.@threads` over the iterator), whereas the user-written for-loop is sequential by default. Could matter for DFT workflows where each structure takes minutes.
> - **Progress reporting / batching.** With a callback, the iterator can report progress every N callbacks, batch I/O, etc. With a manual for-loop the user wires that up themselves.
> - **Flow control.** A `return :stop` from the callback could let the user abort the enumeration mid-way (e.g., stop after finding the first low-energy structure). Less natural with a for-loop (`break` only works in the same scope).
>
> **Why I leaned "wait" originally:**
> - Adds API surface; one more thing to document and test.
> - The for-loop form is already short and idiomatic.
> - If parallelism is the goal, `foreach(callback, enumerate(...))` + a parallel `foreach` from `Folds.jl` or `Transducers.jl` gets there without needing our API to know about it.
>
> **The case for v0.2.** If you anticipate users plugging Enumlib into DFT pipelines (as you said in the original prompt is the typical application), the callback form is the API they'd reach for. It's short, it documents intent ("for each enumerated structure, do X"), and it leaves room for parallelism / progress / abort later without breaking the user-facing signature.

Let's do this. I think this will be a common use case.

> **Claude:** Locked in for v0.2. Naming pattern decision below.
>
> **My recommendation, revised:** include `on_each::Union{Nothing, Function} = nothing` in `enumerate(...)` from v0.2. Default behavior (no callback) returns the iterator; with callback, it consumes the iterator and applies the callback eagerly, returning `nothing`. Two return shapes for one function isn't ideal, so alternatively: a small wrapper `enumerate_each(callback, parent, sites; ...)` that's purely for the callback case and returns nothing.
>
> Open: which name pattern do you prefer? `enumerate(...; on_each=...)` (one function, two return shapes) or `enumerate_each(callback, ...)` (two functions, clean separation)?
I'm not sure. What things should I consider here?

> **Claude:** Six things to weigh; some are stylistic, some are real engineering trade-offs.
>
> **1. Type stability.** Julia's compiler infers a function's return type from its arguments + dispatch. A function whose return type depends on a *kwarg value* (i.e., one shape when `on_each=nothing`, another when `on_each=cb`) is type-unstable: callers compiled once for the kwarg-less case can't assume the return type. In hot paths this matters — type instability prevents inlining and forces dynamic dispatch. Two-functions wins here cleanly: `enumerate(...)` returns `Iterator{EnumeratedStructure}`, `enumerate_each(cb, ...)` returns `Nothing`. Neither needs to dispatch on a value.
>
> **2. `do`-block syntax.** Julia has a beautiful sugar for "first arg is a callback":
>
> ```julia
> # With do block — only works when callback is first positional arg:
> enumerate_each(parent, sites; volume_range=2:8) do s
>     energy = compute_dft(s)
>     save_to_database(s, energy)
> end
>
> # Without do block — kwarg form requires you to write the lambda inline or hoist it:
> enumerate(parent, sites; volume_range=2:8,
>           on_each = s -> begin
>               energy = compute_dft(s)
>               save_to_database(s, energy)
>           end)
> ```
>
> The `do` form is significantly nicer for non-trivial callbacks. It's the strongest argument for two functions in my view. Note: `do` syntax also works if `enumerate_each` takes the callback as a *positional* arg (Julia matches `do` to the first positional function arg). Kwarg-form callbacks can't use `do`.
>
> **3. Convention in the Julia ecosystem.** Base has both patterns and they coexist:
> - `foreach(f, iter)` — separate function for the consume-with-callback case (this is exactly the pattern I'm proposing for `enumerate_each`).
> - `open(f, path)` — function takes the callback as first arg; supports `do`.
> - `Threads.@threads for` — macro form, neither a kwarg nor a separate function.
>
> Cross-pattern, when a function "just consumes" with a callback, the convention is two-functions-with-do-friendly-form (like `foreach`, `open`, `lock`, `withenv`). When a function "produces and the callback is incidental", kwarg form sometimes appears (like `Plots.plot(...; series_callback=...)`). Enumeration → callback → side-effect feels squarely in the `foreach`/`open` camp.
>
> **4. Future extensibility.** If we later want parallel/threaded callbacks, that's another set of behaviors:
> - Two-functions: add `enumerate_pmap(f, ...)`, `enumerate_threaded(f, ...)`, etc. Clean.
> - Kwarg-form: add `parallel = true`, `threaded = true` kwargs to `enumerate`. Each adds another value the function's behavior depends on; the function bloats.
>
> Naming related variants is generally cheaper than expanding one function's kwarg surface. Two-functions wins again.
>
> **5. Discoverability.** With one function: `?enumerate` shows the callback option in the docstring. With two: the user has to find `enumerate_each` separately. Mitigations for the two-function case: cross-references in each docstring, alphabetical doc listing, IDE tab-completion (typing `enumerate_` shows both `enumerate` and `enumerate_each`). In practice this is a real but minor cost.
>
> **6. Mental model.** Some users think "I want to enumerate, applying X to each" as one operation; others think "I want to enumerate, then apply X" as two. The first lean toward kwarg form, the second toward two-functions. The `do` block is so canonical in Julia that even users from the "one operation" camp adapt to it quickly.
>
> ---
>
> **What I'd choose:** `enumerate_each(callback, parent, sites; ...)` — two functions, clean separation, do-block friendly, type-stable, naturally extensible to parallel variants. The single biggest reason is the `do`-block: for non-trivial callbacks (the realistic case in DFT pipelines) the syntactic difference is significant.
>
> But the trade-offs above are the things to weigh; if you have a strong preference for the kwarg form for code-reading reasons, that's a fair choice too. The `do`-block question is the one that would tip me decisively toward two functions if I were doing this solo.
>
> If you want a hybrid: `enumerate(...)` always returns the iterator; `enumerate_each(cb, ...)` is the callback form. Both exist, neither has surprising return shapes. (`enumerate(...; on_each=cb)` becomes a thin alias if you want it later — easy to add, no commitment now.)
Go with two functions


---

<!-- ============= BEGIN CLAUDE-ADD: Phase 6 section ============= -->

## Phase 6 — Data-structure design proposals

This is the type catalog the rewrite hangs on. Phase 5 referenced placeholders (`Site`, `Supercell`, `EnumeratedStructure`, `Enumeration`, `InequivalentCount`, `EnumerationCostEstimate`, `Concentration`, `ConcentrationRange`, `HNF`); Phase 6 nails them down with field definitions, invariants, construction APIs, and the rationale.

The design is informed by:
- **Design Principles 1–3** (top of doc): Fortran file divisions advisory; current Julia layout not a baseline; no Fortran-format compat.
- **The five algorithmic modes** (Phase 5): types must serve unrestricted enumeration, fixed-concentration, site-restricted, recursive-stabilizer, and (future) ZDD without forcing the dispatch to special-case.
- **Iterator-first API** (§3.2 review): `Enumeration` is iterable and lazy by default.
- **Phase 4 review feedback**: Site abstraction unifies parallel arrays, equivalencies via Union-Find, labeling-as-Int as opt-in for memory-bound cases, no exposed `L` (left transform), Tier 2 `InequivalentCount` from v0.2.

### 6.1 Design principles for the type catalog

Five rules I'll apply consistently below:

1. **Validate at construction.** Inner constructors check invariants (HNF lower-triangular bounds, concentration fractions sum to 1, point group has identity, …). Fail loud at construction, never silently at runtime.
2. **Immutable by default.** All types are `struct`, not `mutable struct`, unless there's a clear need (essentially: only the iteration state inside the enumeration loop is mutable). Immutability gives free hashing/equality and prevents many classes of bugs.
3. **Static arrays for fixed-shape data.** `SMatrix{3,3,...}` and `SVector{3,...}` from `StaticArrays.jl` for crystallographic basis matrices and positions. Allocation-free, vectorized, fast.
4. **Don't expose internal state in the public API.** The SNF left transform $L$ is computed when needed and not stored on `Supercell`. The visited bitmap is internal to the dedup pass, never escapes.
5. **No global state.** No `setupChebyTable(k)`-style side effects, no module-level caches. Per-call caches live inside the iterator's state.

### 6.2 Type catalog overview

Tell me more about how we are planning to use `Site` and `Sites` types.

<!-- BEGIN CLAUDE-RESPONSE: Site/Sites usage -->
> **Claude:** Both types are about *describing the user's substitution problem* before any enumeration runs:
>
> - **`Site`** is one position in (or near) the parent cell where atomic substitution can happen. It carries (a) the position itself and (b) the set of allowed atomic species at that position. The set determines whether the site is "active" (>1 species allowed → free configurational variable) or "inactive" (1 species allowed → fixed, doesn't enumerate).
> - **`Sites`** is the collection of all `Site`s in the problem, plus an equivalence relation declaring which sites should be treated as identical for enumeration purposes (e.g., images on opposite faces of a slab; symmetry-related positions the user wants to constrain to share labels).
>
> **Construction flow.** The user typically starts with the dset of the parent lattice (say, 2 sites for HCP), creates one `Site` per dset element with whatever species each can host, and wraps them in `Sites`. Then optionally calls `equate!(sites, i, j)` to declare equivalencies.
>
> **Algorithm consumption.** The dispatcher (`enumerate(...)`) reads `Sites` to know:
> 1. The number of "effective sites" per parent cell = number of *active*, *canonical* sites = `length(active_canonical_sites(sites))`.
> 2. Per-site allowed labels — feeds the site-restriction branch of the dispatch tree.
> 3. The equivalence partition — collapses configurations differing only by relabelings of equivalent sites.
>
> **Why bundle them into `Sites` rather than passing a `Vector{Site}` and a separate equivalencies argument:** the equivalence relation is a property of the *set* of sites, not of any individual site. Bundling makes the invariant ("equivalencies index into this list") representable in the type. Two `Sites` with different equivalence partitions are different inputs even if their `list` matches.
<!-- END CLAUDE-RESPONSE -->

| Type | Purpose | Mutability | Notes |
|---|---|---|---|
| `ParentLattice` | The crystal: basis vectors + dset (multilattice basis sites) + cached point group | immutable | Constructed once per study; reused across many `enumerate` calls |
| `Site` | Per-dset-site description: position + allowed atomic species | immutable | One per element of the dset, then potentially expanded with site-restriction sites |
| `Sites` | Collection of `Site` plus an `IntDisjointSets` for equivalencies | mutable* | *Only the disjoint-set is mutable, for `equate!` calls during construction |
| `Concentration` | A single concentration: `Vector{Rational{Int}}` summing to 1 | immutable | Used for fixed-concentration enumeration |
| `ConcentrationRange` | Per-species (min, max) Rational bounds | immutable | Decomposes into a list of `Concentration`s at each cell volume |
| `HNF` | Validated lower-triangular integer 3×3 matrix | immutable | Inner constructor enforces HNF bounds |
| `Supercell` | An HNF + cached SNF diagonal + cached permutation group | immutable | One per symmetry-distinct HNF class; shared by many `EnumeratedStructure`s |
| `Enumeration{L}` | Top-level result: parent + sites + supercells + structures, parametrized by labeling representation `L` | immutable | Iterable and indexable |
| `EnumeratedStructure{L}` | A single enumerated structure: supercell ref + labeling + degeneracies + concentration | immutable | Yielded by iteration over `Enumeration{L}` |
| `InequivalentCount` | Pólya-derived count, total + breakdowns | immutable | Returned by `count_inequivalent(...; breakdown=true)` |
| `EnumerationCostEstimate` | Pre-flight prediction: count + peak memory + walltime + chosen algorithm | immutable | Returned by `estimate_cost(...)` |
| `HNFClass` | Symmetry-equivalence class of HNFs at a given volume | immutable | Used inside `InequivalentCount.by_hnf_class` |

The full graph fits on one screen. No parallel arrays, no dead types, no Fortran-format encodings. What do you mean the "full graph fit on one screen"?

<!-- BEGIN CLAUDE-RESPONSE: type-graph-fits-on-screen -->
> **Claude:** Just meant the type-relationship diagram (which type holds which other type) is visually small — no chains of indirection, no 20-deep type hierarchies. The composition depth is roughly `ParentLattice → Sites → Supercell → EnumeratedStructure → Enumeration` and that's it. Removing the metaphor: the catalog is small enough to read top-to-bottom in one sitting and hold in your head.
<!-- END CLAUDE-RESPONSE -->

### 6.3 `ParentLattice`

The geometric description of the parent multilattice: basis vectors + dset (no atomic species — those enter via `Sites`).
Technicially I wouldn't call it a "parent crystal" It has a dset, but that just makes it a multilattice, not a crystal. A crystal defines atoms at each point

<!-- BEGIN CLAUDE-RESPONSE: parent-lattice not parent-crystal -->
> **Claude:** Fair point — corrected. A crystal includes both the lattice and the species at each site; `ParentLattice` only captures the *lattice* (basis + dset positions) without committing to species. The species enter via `Sites`, separately. The Fortran also called this a "parent lattice" (`parLV` / `pLat`), so the rename is just my drift.
<!-- END CLAUDE-RESPONSE -->

```julia
using StaticArrays
using Spacey: pointGroup    # symmetry library; returns lattice-coord rotations

struct ParentLattice
    A::SMatrix{3,3,Float64,9}            # column j is the j-th basis vector (Cartesian)
    dset::Vector{SVector{3,Float64}}     # basis sites in fractional coords (within [0,1)^3)
    point_group::Vector{SMatrix{3,3,Int,9}}   # lattice point group in lattice coords (Spacey.jl's `pointGroup(A)` output) not fortran's terminology but in Spacey.jl's terminology

    function ParentLattice(A::AbstractMatrix, dset::AbstractVector{<:AbstractVector})
        @assert size(A) == (3, 3) "Basis matrix must be 3×3"
        @assert det(A) > 0 "Basis matrix must have positive determinant (right-handed)"
        @assert all(0 .<= d .< 1 for d in dset) "All d-vectors must be in [0,1)"
        # @assert any(iszero, dset) "dset must contain the origin (convention)"  -- removed per user feedback
        Have we insisted on this in the past? Not sure we want to. What about diamond? If we put the origin at the inversion site between the two atoms then the hamiltonian matrix becomes real, instead of complex in DFT calculations. This is just an example. What is the reason for insisting the dset contain the origin. I don't remember doing that in the past.

<!-- BEGIN CLAUDE-RESPONSE: dset-origin assertion removed -->
> **Claude:** You're right — the assertion was wrong, removing. The Fortran code doesn't enforce it (I checked), and your diamond/inversion-site example is a real case where the origin should be elsewhere. The convention I imported was just my error.
>
> The math doesn't require the origin in the dset: `getCartesianPts` and the interior-points loops iterate over `(HNF translations) × (dset positions)` regardless of where the dset is anchored. Updated the constructor to drop the assertion (commented out above; will be deleted on the cleanup pass).
>
> One small caveat to flag for users: `pointGroup(A)` returns symmetries that fix the origin in lattice coordinates. If a user's chosen dset anchoring breaks the parent's symmetry (e.g., a dset that's supposed to have inversion through (½, ½, ½)), they may need to translate their basis matrix to put the relevant symmetry center at the origin. That's a user responsibility regardless of where the dset sits.
<!-- END CLAUDE-RESPONSE -->
        Asm = SMatrix{3,3,Float64,9}(A)
        ds = [SVector{3,Float64}(d) for d in dset]
        pg = pointGroup(Asm)             # cache the point group at construction
        new(Asm, ds, pg)
    end
end

# Convenience: single-lattice (Bravais) constructor
ParentLattice(A) = ParentLattice(A, [SVector{3,Float64}(0,0,0)])
```

**Notes:**
- `point_group` is computed once at construction and cached. (Fortran recomputes per call; minor inefficiency in practice since `gen_multilattice_derivatives` is typically called once or a handful of times — caching is a small ergonomic win, not a perf claim.)
This is not such a big deal. In typical use cases `gen_multilattice_derivatives was called only once or a handful of times`

<!-- BEGIN CLAUDE-RESPONSE: cache framing softened -->
> **Claude:** Acknowledged — softened the wording above. The cache is for ergonomics ("call sites can read `parent.point_group` without invoking `pointGroup(A)` again"), not for measurable speedup in typical workflows. Withdrawing the "wasteful" framing.
<!-- END CLAUDE-RESPONSE -->
- We store the *integer* lattice-coord point group, not the Cartesian one. Conversions to Cartesian happen on demand inside the geometric routines (`map_to_real_space`, etc.).
- `dset` does not have to contain the origin. Single Bravais lattices have one element; HCP has 2; perovskite has 5. (Per user feedback above, the assertion was a mistake on my part — the old Fortran code didn't enforce this either.)

### 6.4 `Site` and `Sites`

The unification of the Fortran's `dFull/d`, `labelFull/label`, `digitFull/digit`, `equivalencies`, and `inactives` arrays. Per Phase 4 review: a single struct, with Union-Find for equivalencies enforcing transitivity by construction.

```julia
using DataStructures: IntDisjointSets, union!, find_root!

struct Site
    position::SVector{3,Float64}    # fractional coords (matches a dset element, or a user-added position) -- "sub-site" wording removed per user feedback
    allowed_labels::BitSet          # subset of {0, ..., k-1}
end

is_inactive(s::Site) = length(s.allowed_labels) == 1
What is this function doing exactly? I think I understand. An inactive site can only have one type of label. This function counts the number of allowed labels. If it is 1 then this site is an inactive site; the function will return true

<!-- BEGIN CLAUDE-RESPONSE: is_inactive confirmed -->
> **Claude:** Exactly right. One-liner: returns `true` iff the site has only one allowed label, meaning it's locked to that label and contributes no configurational freedom. The dispatcher uses it to skip such sites entirely from the enumeration's labeling space.
>
> Also added an `is_active(s::Site) = !is_inactive(s)` companion for readability at call sites where the positive form reads more naturally.
<!-- END CLAUDE-RESPONSE -->

mutable struct Sites
    list::Vector{Site}
    equiv::IntDisjointSets         # disjoint-set over indices 1:length(list) So is this essentially keeping track of which sites may map to other sites under the symmetry operations? Or is it telling us which sites may have the same label?
    Is it necessary, or good practice, to specify the type of the argument in this constructor function? It seems redundant; you could just say `Sites(list)` Help me understand

<!-- BEGIN CLAUDE-RESPONSE: equivalencies semantics + Julia type-annotation explanation -->
> **Claude (on equivalencies):** Neither symmetry-computed nor about labels per se — it's *user-declared* equivalence. The user says "for the purposes of this enumeration, treat sites $i$ and $j$ as identical." Two common cases:
>
> 1. **Slab geometry**: a site at $z=0$ and a site at $z=L$ should be treated as the same (translation symmetry across the slab). These sites are *not* related by any parent-lattice rotation; they're related by a translation that the user knows about because they set up the slab.
> 2. **Crystallographic equivalence the user knows in advance**: the user knows from the problem setup that two positions are equivalent and wants the enumeration to share labels across them.
>
> The Fortran's `equivalencies` array was the same idea (per HISTORY.md, it was "Tobias's modification" added for the slab case). Importantly, it's *not* derived from `pointGroup` — symmetry analysis would be wrong for case 1 (the slab images aren't related by a parent symmetry op) and unnecessary for case 2 (the user already knows the answer).
>
> So `IntDisjointSets` represents an arbitrary user-asserted partition of the site indices. The dispatcher then collapses configurations that differ only by relabelings of equivalent sites — they would otherwise be enumerated as distinct.
>
> **Claude (on type annotations):** Three reasons annotations on constructor arguments earn their keep, even when they look redundant:
>
> 1. **Documentation.** `Sites(list::AbstractVector{Site})` tells the reader (and IDE / language server) what's expected. Without the annotation, users have to dig into the function body to learn what `list` should look like.
> 2. **Better error messages.** A user calling `Sites("hello")` gets `MethodError: no method matching Sites(::String)` immediately. Without the annotation they get a deeper, less obvious error from inside the function body.
> 3. **Multiple-dispatch capacity.** Annotated arguments let us add specialized constructors later — e.g., `Sites(list, classes::Vector{Vector{Int}})` for the upfront-partition variant from §6.13 Q1. Without annotations, the dispatcher can't tell variants apart.
>
> Cost: zero at runtime. Julia compiles a specialized method per concrete type; annotations are documentation + dispatch infrastructure, not slowdown.
>
> So almost all Julia constructors and library functions in the wild have annotated arguments. The exception is genuinely-polymorphic functions whose body just calls protocol methods (e.g., `f(x) = abs(x) + 1` works for any number-like `x`). Constructors usually aren't that flexible — they're building specific types from specific input shapes.
<!-- END CLAUDE-RESPONSE -->
    function Sites(list::AbstractVector{Site})
        new(collect(list), IntDisjointSets(length(list)))
    end
end

# Equate two sites (idempotent, transitive by construction)
function equate!(s::Sites, i::Integer, j::Integer)
    union!(s.equiv, i, j)
    return s
end

# The canonical site index for `i` (root of its equivalence class).
# Equivalence classes are *user-declared* (via `equate!`), not symmetry-computed -- see CLAUDE-RESPONSE above.
canonical(s::Sites, i::Integer) = find_root!(s.equiv, i)

# Iteration: list active, canonical sites only
# These are the sites that have configurational degrees of freedom; they can be colored
function active_canonical_sites(s::Sites)
    seen_roots = Set{Int}()
    [(i, s.list[i]) for i in eachindex(s.list)
     if !is_inactive(s.list[i]) && (root = canonical(s, i); push!(seen_roots, root); root == i)]
end
```

**Why `BitSet` for `allowed_labels`.** Sets of small nonneg integers. `BitSet` gives O(1) membership and very compact storage. `Set{Int}` would also work but with hash overhead.

**Why the `Sites` wrapper rather than a `Vector{Site}`.** Equivalencies are conceptually a partition over the site indices. Storing the partition state on individual `Site` objects (e.g., a `parent::Int` field) makes reading correct but writing fragile — you can break transitivity by setting `Site.parent` directly. With Union-Find centralized in `Sites.equiv`, transitivity is enforced by the data structure; users can't break it.

**Inactive vs equivalent.** "Inactive" = single allowed label (no configurational freedom on this site). "Equivalent" = same physical/symmetry role as another site. Both reduce the active enumeration space. Both are first-class on `Site` / `Sites` rather than tracked in parallel arrays.

### 6.5 `Concentration` and `ConcentrationRange`

Per Phase 5 §5.2: `concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing`. Both types use `Rational{Int}` for clean handling of fractions.

```julia
struct Concentration
    fractions::Vector{Rational{Int}}      # one per species; should sum to 1
    function Concentration(fractions::AbstractVector{<:Rational})
        @assert sum(fractions) == 1//1 "Concentration fractions must sum to 1"
        @assert all(0 <= f <= 1 for f in fractions) "Each fraction must be in [0,1]"
        @assert length(fractions) >= 2 "Need at least 2 species for a meaningful concentration"
        new(collect(Rational{Int}, fractions))
    end
end

# Convenience constructors
Concentration(integers::AbstractVector{<:Integer}) =
    Concentration([n // sum(integers) for n in integers])
# e.g., Concentration([15, 17])  ↔  [15//32, 17//32]

struct ConcentrationRange
    bounds::Vector{Tuple{Rational{Int}, Rational{Int}}}    # one (min, max) per species
    function ConcentrationRange(bounds::AbstractVector)
        @assert all(0 <= lo <= hi <= 1 for (lo, hi) in bounds) "Each bound must satisfy 0 ≤ min ≤ max ≤ 1"
        new(collect(Tuple{Rational{Int}, Rational{Int}}, bounds))
    end
end

# Resolve a Concentration to integer multiplicities at a given supercell size
function multiplicities(c::Concentration, n_total::Integer)
    multiset = [Int(c.fractions[i] * n_total) for i in eachindex(c.fractions)]
    @assert sum(multiset) == n_total "Concentration fractions don't divide n_total cleanly: $multiset"
    multiset
end

# Resolve a ConcentrationRange to a list of Concentrations at a given supercell size
function concentrations_in_range(cr::ConcentrationRange, n_total::Integer)
    # Enumerate all integer (a_1, ..., a_k) with sum n_total satisfying the per-species bounds
    # Returns Vector{Concentration}
    ...
end
```

**The user calls:**
```julia
c = Concentration([15, 17])                     # 15:17 binary; resolves to 15//32 + 17//32 at n*nD = 32
cr = ConcentrationRange([(2//5, 3//5), (2//5, 3//5)])    # binary, each species in [40%, 60%]
```

**The dispatcher's job.** When the user passes `Concentration`, the dispatcher resolves it to multiplicities at each cell volume in `volume_range`. If the multiplicities don't divide cleanly (e.g., `Concentration([1//2, 1//2])` at $n=3$, can't have 1.5 atoms of each), the dispatcher skips that volume with a one-line warning. It's possible that none of the multiplicities divide cleanly at the sizes the user specifices, so the enumeration is "empty". Will we check for that and error out? Or just return an empty enumeration. I don't really like the latter...

When the user passes `ConcentrationRange`, the dispatcher walks each volume × each integer concentration in the range. The decision tree from §5.4 then runs per-concentration.
Same comment could apply here, yes? 

<!-- BEGIN CLAUDE-RESPONSE: empty enumeration → error -->
> **Claude:** Agree — error rather than silent empty result. Updating the design: if no concentration in the volume range divides cleanly into the requested fractions, throw an `EmptyEnumerationError` with a message like:
>
> ```
> ERROR: EmptyEnumerationError: no integer multiplicities in volume_range=2:8 satisfy
>   concentration=Concentration([1//3, 1//3, 1//3]).
>   Try volume_range divisible by 3 (e.g., 3, 6, 9, ...) or relax the concentration.
> ```
>
> Same logic for `ConcentrationRange` — confirmed the same comment applies. Same `EmptyEnumerationError` type, slightly different message ("no concentration in the range × no volume in the range produces any valid multiplicity vector").
>
> Implementation: the dispatcher computes the resolved (volume, concentration) pairs upfront — it's a small Cartesian-product loop over `volume_range × range_partitions(concentration_range)`. If the result is empty, throw immediately. The user gets the error before any HNF generation or memory allocation.
<!-- END CLAUDE-RESPONSE -->

### 6.6 `HNF` and `Supercell`

```julia
struct HNF
    matrix::SMatrix{3,3,Int,9}
    function HNF(m::AbstractMatrix{<:Integer})
        @assert size(m) == (3, 3) "HNF must be 3×3"
        # Lower-triangular form check
        @assert m[1,2] == 0 && m[1,3] == 0 && m[2,3] == 0 "HNF must be lower-triangular"
        a, c, f = m[1,1], m[2,2], m[3,3]
        @assert a > 0 && c > 0 && f > 0 "HNF diagonals must be positive"
        @assert 0 <= m[2,1] < c "HNF[2,1] out of range [0, $(c-1)]"
        @assert 0 <= m[3,1] < f "HNF[3,1] out of range [0, $(f-1)]"
        @assert 0 <= m[3,2] < f "HNF[3,2] out of range [0, $(f-1)]"
        new(SMatrix{3,3,Int,9}(m))
    end
end

# Convenience accessors
volume(h::HNF) = h.matrix[1,1] * h.matrix[2,2] * h.matrix[3,3]   # det of lower triangular = diagonal product
Base.det(h::HNF) = volume(h) This is overloading det so that it returns an Int for HNFs, right?

<!-- BEGIN CLAUDE-RESPONSE: Base.det overload -->
> **Claude:** Yes — extending `Base.det` to dispatch on our `HNF` type. Same name, different argument type. When the user calls `det(some_hnf::HNF)`, our method runs (returns `Int` via the fast diagonal-product formula). When they call `det(some_matrix::Matrix{Float64})`, Julia's existing method runs.
>
> **Why bother:** `det` is the natural function name for "determinant of an HNF" (which equals the supercell volume / index $n$). If we named it `hnf_volume(h)` instead, users would have to remember our name; with the overload they reuse the standard Base function.
>
> The `Int` return is exact (no float rounding) since the diagonal product is the determinant for any lower-triangular integer matrix. Slightly faster than calling Base's general LU-based `det`, but the win is nominal — readability is the main reason.
<!-- END CLAUDE-RESPONSE -->

struct Supercell
    # parent_id::Int                          # index into the Enumeration's parent — REMOVED per user feedback (YAGNI; see CLAUDE-RESPONSE below)
    # CLAUDE-RESPONSE: agreed YAGNI, dropping. Justification was "what if a future
    # Enumeration spans multiple parents?" but I can't construct a realistic case
    # where that's useful (different parents have different symmetry groups,
    # dsets, etc.; you'd want them in separate Enumerations). The Enumeration knows
    # its single parent; the Supercell doesn't need a back-pointer.
    hnf::HNF
    snf::SVector{3,Int}                     # diagonal of SNF: (s_1, s_2, s_3) with s_1 | s_2 | s_3
    point_group_order::Int                  # |stabilizer of this superlattice| from the parent point group
    permutation_group::Vector{Vector{Int}}  # permutations of the n*nD supercell sites induced by stabilizer + translations
    # Note: SNF left transform L is intentionally NOT stored. Recomputed when needed
    # for (HNF, labeling) → real-space mapping. Per Phase 4 review §2.10 #4: L isn't unique.
end
```

**Why no `L` field.** The SNF $S = L H R$ has unique $S$ but non-unique $L, R$. Storing $L$ on `Supercell` would (a) leak the non-uniqueness into the public API and (b) make two correct enumerations look "different" if their $L$'s happened to differ. Internal routines that need $L$ recompute it on demand from the HNF.

**Why cache `permutation_group`.** Computing it from the HNF + parent point group is the most expensive step per supercell. Caching saves the recomputation across all labelings on the same supercell. Memory cost: a few KB per supercell, vs hundreds of supercells per typical enumeration → negligible.

### 6.7 Labeling representation (parametric)

Per Phase 4-5 review: `Vector{Int8}` default for ergonomics, `Int64`/`BigInt` opt-in for memory-bound cases. The parametric type is what makes both work without runtime dispatch.

```julia
# A labeling is one of:
#   Vector{Int8}   — n*nD entries in 0:k-1, the "decoded" form
#   Int64          — base-k or multinomial hash, decoded on demand
#   BigInt         — same as Int64 but for very-large enumerations

const LabelingRepresentation = Union{Vector{Int8}, Int64, BigInt}

# Encode/decode helpers — same machinery as the perfect-hash discussion in §4.1
So the hash value is going to be a BigInt by default?

# CLAUDE-RESPONSE: good catch — BigInt as the default return is overkill.
# Better: separate functions for Int and BigInt, dispatcher picks based on
# whether overflow is possible at the per-Enumeration level. See response block
# below the encode/decode pair.
function encode_basek(digits::AbstractVector{<:Integer}, k::Integer)::BigInt
    result = BigInt(0)
    for j in length(digits):-1:1
        result = result * k + digits[j]
    end
    result
end

function decode_basek(idx::Integer, k::Integer, n::Integer)::Vector{Int8}
    out = zeros(Int8, n)
    x = idx
    for j in 1:n
        out[j] = Int8(mod(x, k))
        x ÷= k
    end
    out
end

# For fixed-concentration: the multinomial hash from HNF 2012 §3.1 is similar but with Cᵢ as mixed radixes
# (skipped here for brevity; same encode/decode pattern, different radix scheme)
```

<!-- BEGIN CLAUDE-RESPONSE: BigInt default is overkill -->
> **Claude:** You're right — `encode_basek` returning `BigInt` always is overkill. Better:
>
> ```julia
> # Default Int64 path — errors if it would overflow Int.
> function encode_basek(digits::AbstractVector{<:Integer}, k::Integer)::Int
>     ...
> end
>
> # Explicit BigInt path — used when overflow is possible.
> function encode_basek_big(digits::AbstractVector{<:Integer}, k::Integer)::BigInt
>     ...
> end
> ```
>
> The dispatcher knows whether overflow is possible at the per-`Enumeration` level (it checks `k^n` against `typemax(Int)` once during cost estimation) and picks the appropriate path. The user never sees this detail; it's invisible behind `Enumeration{L}`.
<!-- END CLAUDE-RESPONSE -->

**The per-`Enumeration` choice.** Each `Enumeration{L}` commits to one labeling representation across all its structures. The dispatcher picks based on the algorithm:

- `:exhaustive` (full $k^n$ table): `L = Vector{Int8}` if total memory < threshold; else `L = Int64` if the index fits; else `L = BigInt`.
Just to make sure I understand: L is a vector, the hash table? Since it only needs a handful of possible values at each element, Int8 saves memory.

<!-- BEGIN CLAUDE-RESPONSE: L vs visited bitmap — two different things -->
> **Claude:** Two different things conflated; let me untangle.
>
> 1. **`L` (the type parameter on `Enumeration{L}` and `EnumeratedStructure{L}`)** is the storage type for *one labeling* per `EnumeratedStructure`. Three concrete types are allowed:
>    - `L = Vector{Int8}`: each labeling is a length-`n*n_D` byte vector. Decoded form. Easy to read, ~`n*n_D` bytes per structure.
>    - `L = Int64`: each labeling is a single 8-byte integer (the base-$k$ hash). Compact. Decoded on access.
>    - `L = BigInt`: same idea but for cases that overflow `Int64`.
>
>    The dispatcher picks one of the three at construction time based on enumeration size. All `EnumeratedStructure`s in the same `Enumeration` use the same representation.
>
> 2. **The "visited bitmap"** is a *separate* internal data structure used during the dedup pass — a `BitVector` of length $k^n$ (or $C$ for fixed-concentration) where bit $i$ means "the labeling with hash $i$ has been visited." It exists only during enumeration; once enumeration finishes, it's discarded. Every algorithm that uses the perfect-hash idea from §4.1 has some version of this bitmap.
>
> So `Vector{Int8}` and `Int64` (and `BigInt`) are *output storage* per structure (one per `EnumeratedStructure`). The bitmap is *intermediate state* (one per enumeration run, lifetime = the dedup loop). Different scopes, different lifetimes.
>
> Your intuition about `Int8` saving memory is correct — but it's saving memory on the *output*, not on the visited bitmap. The bitmap is always 1 bit per possible labeling regardless of `L`.
<!-- END CLAUDE-RESPONSE -->
- `:multinomial`: same logic with $C$ instead of $k^n$.
- `:recursive_stabilizer`: streams as `Vector{Int8}` typically (the tree's location vector is small).
- `:bdd`: irrelevant — the BDD is the storage; `EnumeratedStructure` materializes from a path.

**The user's view.** The user gets `Enumeration{L}` and iterates. Convenience accessors (`materialize(s)::Vector{Int8}`) hide the representation:

In general, I don't think we want volume_range defaults. In fact, we don't always enumerate over volume ranges. Sometimes we want to enumerate over a list of HNFs, maybe of a common *radius* not necessarily a common volume. If this assumption is ubiquitous in the design we need to pause, rethink, and redesign. Maybe this is a big deal in the current design thinking?

<!-- BEGIN CLAUDE-RESPONSE: SupercellSelection — volume_range generalization -->
> **Claude:** Substantial concern — agreed, this is a structural issue worth addressing before Phase 7. The current API bakes "enumerate by volume range" into the entry point, which doesn't fit:
>
> 1. **Radius-bounded enumeration** (already implemented in `radiusEnumeration.jl`): user wants HNFs with Minkowski-reduced cell radius ≤ some threshold, regardless of volume.
> 2. **User-supplied HNF list** (the `fixed_cells` kwarg from §5.2): user has a curated set of HNFs and wants to enumerate labelings on those.
> 3. **Hybrid** (e.g., "radius-bounded but capped at volume 50 for safety"): combines two criteria.
>
> The right reframing: replace `volume_range` and `fixed_cells` with a single "supercell selection" abstraction.
>
> **Proposed shape:**
>
> ```julia
> abstract type SupercellSelection end
>
> struct VolumeRange <: SupercellSelection
>     range::AbstractRange{Int}
> end
>
> struct RadiusBound <: SupercellSelection
>     max_radius::Float64                          # in units of parent cell radii (per radiusEnumeration.jl convention)
>     volume_cap::Int = typemax(Int)               # safety: never enumerate beyond this volume
> end
>
> struct ExplicitHNFs <: SupercellSelection
>     hnfs::Vector{HNF}
> end
>
> # The entry point becomes:
> function enumerate(parent::ParentLattice, sites::Sites;
>                    supercells::SupercellSelection,                    # required
>                    concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
>                    algorithm::Symbol = :auto,
>                    memory_budget::Int = 8 * 2^30,
>                    on_overflow::Symbol = :error)
>     # 1. Generate the HNF list from `supercells`. (The only place this varies across modes.)
>     # 2. Symmetry-reduce the HNFs (same code path regardless of source).
>     # 3. Run the dispatch + enumeration loop on the reduced list.
> end
> ```
>
> **User code:**
>
> ```julia
> # Volume-range case:
> enumerate(parent, sites; supercells = VolumeRange(2:8))
>
> # Radius-bound case:
> enumerate(parent, sites; supercells = RadiusBound(max_radius = 3.0))
>
> # Explicit list:
> my_hnfs = filter(some_predicate, all_hnfs_in_volume_range)
> enumerate(parent, sites; supercells = ExplicitHNFs(my_hnfs))
> ```
>
> **What this changes elsewhere in the design:**
> - `volume_range::AbstractRange{Int}` (currently in §5.2 / §6) → `supercells::SupercellSelection` (required, no default).
> - The dispatch decision tree (§5.4) gets one new step at the top: "generate the HNF list from `supercells`, then proceed." The downstream tree is unchanged.
> - The cost estimator handles each `SupercellSelection` subtype with its own size predictor (`VolumeRange` knows the count exactly; `RadiusBound` needs a quick scan up to `volume_cap`; `ExplicitHNFs` is direct from `length(hnfs)`).
> - `EnumerationCostEstimate` gets an extra field for which selection method was used (so warning messages can suggest "try a tighter radius" vs "try a smaller volume range" appropriately).
> - The `fixed_cells` kwarg is *removed* — its functionality is now `ExplicitHNFs`.
>
> **What it changes for users:** the API is slightly more verbose at the call site (`supercells = VolumeRange(2:8)` instead of `volume_range = 2:8`) but more honest about what's happening — and it composes. Adding a new selection method later (e.g., `VolumeAndRadius` for a hybrid criterion, or `MorganExponentialBound` for some future heuristic) is a one-class addition, not an API redesign.
>
> **Backward-compat sweetener (if you want it):** keep a `volume_range` keyword as a thin alias that constructs `VolumeRange` under the hood. Trade-off is that we then have two ways to say the same thing; my mild lean is to NOT include the alias and force users to write the more honest form.
>
> **Should I refactor Phase 5 and Phase 6 to reflect this now**, or leave it as a flag for follow-up cleanup before Phase 7? Lean toward refactor now since both phases are still under review; once we move to Phase 7+ the assumption ossifies. If you say go, I'll do a follow-up edit pass that updates the §5.2 signature, the §5.4 decision tree, and the §6 catalog references in one commit.
<!-- END CLAUDE-RESPONSE -->

```julia
for s in enumerate(parent, sites; volume_range=2:10)
    digits = materialize(s)              # always returns Vector{Int8}, regardless of L
    # ...
end
```

So users don't need to think about `L` unless they're optimizing memory. Library authors writing extensions can dispatch on `EnumeratedStructure{L}` if they need the underlying representation.

### 6.8 `EnumeratedStructure{L}` and `Enumeration{L}`

The output types. Per §3.2 review: normalized representation, `Supercell` shared across many `EnumeratedStructure`s.

```julia
struct EnumeratedStructure{L<:LabelingRepresentation}
    supercell_id::Int                    # index into Enumeration.supercells
    labeling::L                          # representation chosen at the Enumeration level
    hnf_degeneracy::Int                  # number of HNFs in this supercell's symmetry class
    labeling_degeneracy::Int             # for label-rotation duplicates within the supercell
    concentration::Concentration         # the realized concentration for this structure
end

struct Enumeration{L<:LabelingRepresentation}
    parent::ParentLattice
    sites::Sites
    supercells::Vector{Supercell}        # ~hundreds; shared across structures
    structures::Vector{EnumeratedStructure{L}}    # ~thousands to billions
end

# Iteration: yields EnumeratedStructure{L} values
Base.length(e::Enumeration) = length(e.structures)
Base.iterate(e::Enumeration, state=1) =
    state > length(e.structures) ? nothing : (e.structures[state], state + 1)
Base.eltype(::Type{Enumeration{L}}) where L = EnumeratedStructure{L}
Base.IteratorSize(::Type{<:Enumeration}) = Base.HasLength()
```

**For lazy iteration** (the user-facing entry from `enumerate(...)`), we *don't* materialize `structures::Vector{...}` upfront. Instead, return a `LazyEnumeration{L}` that's a `Channel`-like or generator producing structures one at a time:

```julia
struct LazyEnumeration{L}
    parent::ParentLattice
    sites::Sites
    state::EnumerationState              # algorithm-specific iteration state
end

# Same iterator interface, but produces structures on demand
Base.IteratorSize(::Type{<:LazyEnumeration}) = Base.SizeUnknown()
Base.iterate(e::LazyEnumeration{L}, state=...) where L = ...

# Convert lazy → eager when the user wants the full materialized form
Base.collect(e::LazyEnumeration{L}) where L = ... # walks the iterator, builds Enumeration{L}
```

Both `Enumeration{L}` and `LazyEnumeration{L}` satisfy the iterator protocol. The user can treat them interchangeably for `for` loops and `foreach`; only `length()`, `getindex(i)`, and `collect()` differ.

**Why the parametric `L` is cleaner than an abstract type.** Inside the iterator's hot loop, dispatching on a parametric type is statically resolved — no runtime overhead. Dispatching on an abstract supertype would require dynamic dispatch per yielded structure. For an enumeration yielding billions of structures, that's the difference between fast and slow.

### 6.9 `InequivalentCount`, `EnumerationCostEstimate`, `HNFClass`

Per Phase 5 review: Tier 2 in v0.2.

```julia
struct HNFClass
    # A symmetry-equivalence class of HNFs at a given volume.
    representative::HNF                  # one HNF in the class
    class_size::Int                      # number of HNFs that are symmetry-equivalent to this one (related by parent point-group rotations) # That is, how many HNFs have the same permutation group, right?
end

<!-- BEGIN CLAUDE-RESPONSE: HNFClass class_size definition -->
> **Claude:** Almost — one nuance. Two HNFs that are symmetry-equivalent under the parent lattice's point group will yield isomorphic permutation groups (so "same permutation group" is a *consequence* of being in the same class), but the *defining* relation is "related by a parent rotation": $H_2 \cong H_1$ iff there exists $R$ in the parent point group such that $H_1 R H_2^{-1}$ is a unimodular integer matrix.
>
> So `class_size` = "number of HNFs that the symmetry reduction in step 2 of the 2008 algorithm collapsed into one representative." Two HNFs in the same class give equivalent enumerations (same set of derivative structures up to a relabeling of supercell sites). The permutation-group isomorphism follows but isn't itself the defining test.
<!-- END CLAUDE-RESPONSE -->

struct InequivalentCount
    total::BigInt
    by_volume::Vector{Tuple{Int, BigInt}}                         # (n, count_at_n)
    by_concentration::Vector{Tuple{Concentration, BigInt}}        # populated when concentration was a range
    by_hnf_class::Dict{HNFClass, BigInt}                          # for diagnostic exploration
end

struct EnumerationCostEstimate
    total_count::BigInt                      # predicted #structures
    peak_memory_bytes::Int                   # worst-case peak across the chosen algorithm's lifetime
    estimated_walltime_seconds::Float64      # predicted; uses simple per-mode rules of thumb
    chosen_algorithm::Symbol                 # :exhaustive, :multinomial, :recursive_stabilizer, …
    notes::Vector{String}                    # warnings, e.g., "Switched to :recursive_stabilizer because :exhaustive's bitmap would exceed memory_budget"
end
```

`InequivalentCount` is the structured return of `count_inequivalent(...; breakdown=true)`. `EnumerationCostEstimate` is the structured return of `estimate_cost(...)`.

### 6.10 Construction patterns

A typical end-to-end flow:

```julia
using Enumlib
using StaticArrays

# 1. Define the parent lattice (HCP example: hexagonal Bravais + 2-element dset).
A_hcp = SMatrix{3,3}(1.0, 0.0, 0.0,
                     0.5, sqrt(3)/2, 0.0,
                     0.0, 0.0, sqrt(8/3))
dset_hcp = [SVector(0.0, 0.0, 0.0),
            SVector(1/3, 1/3, 1/2)]
hcp = ParentLattice(A_hcp, dset_hcp)

# 2. Define the sites and allowed substitutions. Both d-sites can take any of 3 species.
sites = Sites([Site(d, BitSet(0:2)) for d in hcp.dset])

# 3. (Optional) declare equivalencies. Here, pretend sites 1 and 2 should be treated identically.
# equate!(sites, 1, 2)

# 4. (Optional) constrain to a specific concentration.
c = Concentration([1//3, 1//3, 1//3])    # equimolar ternary

# 5. Enumerate.
for s in enumerate(hcp, sites; volume_range=2:6, concentration=c)
    process(s)
end

# Or use the callback form (per §5.11 Q4):
enumerate_each(hcp, sites; volume_range=2:6, concentration=c) do s
    process(s)
end

# Or count without enumerating.
count = count_inequivalent(hcp, sites; volume_range=2:6, concentration=c; breakdown=true)
@show count.total
@show count.by_volume
```

### 6.11 Comparison vs Fortran's types

| Fortran | Julia |
|---|---|
| `parLV(3,3)`, `d(:,:)`, `nD`, `LG` (4 separate arrays) | `ParentLattice` (one struct, `point_group` cached) |
| `dFull(:,:)`, `labelFull(:,:)`, `digitFull(:)`, `equivalencies(:)`, `inactives(:,:)` (5 parallel arrays) | `Sites` (one struct with `IntDisjointSets`) |
| `cRange(k, 3)` (integer matrix [min_num, max_num, denom] per species) | `ConcentrationRange` (Rational bounds) |
| HNF as `integer, dimension(3,3)` (no validation) | `HNF` struct with construction validation |
| `RotPermList{perm, RotIndx, nL, v}` | `Supercell` (HNF + SNF + permutation_group cached) |
| `derivStruct{diag, pLat, dVec, nD, HNF, L, n, labeling, conc}` (all fields denormalized per structure) | `EnumeratedStructure{L}` (5 fields, supercell_id refers to shared `Supercell`) |
| Output as `struct_enum.out` flat rows | `Enumeration{L}` in-memory + JLD2 default serialization |
| `derivCryst`, `cryst` (declared "Not used yet") | not in the catalog (dead types not carried forward) |

The Julia catalog is 11 types vs Fortran's 8 active types + 5 parallel arrays + custom file format. The win isn't in count; it's in *coherence* — every relationship is a typed reference, not an array index that the user has to remember to keep in sync.

### 6.12 What's NOT in the catalog (and why)

To be explicit about omissions:

- **No `Tree`-related types.** The Morgan 2017 algorithm uses an enumeration tree internally, but the tree's state is private to the algorithm — never escapes into the user-facing types. From the user's view, the tree algorithm just yields `EnumeratedStructure` values like any other algorithm.
- **No global state types.** No `LookupTables`, no `BasisCache`. Anything that needs caching lives inside an iterator's state.
- **No file-format types.** No `StructEnumIn`, no `StructEnumOut`. The `LegacyImport` submodule has its own internal types for parsing the Fortran format; they don't escape the submodule.
- **No `SuperTile`, `ColoredTile`, `ParentLattice` (the old one).** The Phase 4 review verified those were dead. Replaced by `ParentLattice` (renamed but redesigned), `Supercell`, and the parametric `Enumeration{L}` / `EnumeratedStructure{L}`.
- **No `enumStr`.** Replaced by `EnumeratedStructure{L}` with shared `Supercell`. Old `enumStr` is preserved in `LegacyImport` for reading legacy `struct_enum.out` files.
- **No `RotPermList`.** Folded into `Supercell.permutation_group` (the `perm` part) and `Supercell.point_group_order` (the `RotIndx` count). The `v` field for lattice shifts is recomputed on demand inside `map_to_real_space`.

### 6.13 Open design questions for the user

A short list of questions that affect the catalog and need your input before Phase 7 can proceed cleanly:

1. **`Sites` — partition vs. validation.** I picked `IntDisjointSets` (Union-Find) for equivalencies, with `equate!(sites, i, j)` as the construction API. Alternative: take a `Vector{Vector{Int}}` of equivalence classes upfront and validate that it's a partition. The first is more flexible for incremental construction; the second matches users who already know the equivalence classes from the problem setup. Lean toward Union-Find? Is there a way to accomodate both kinds of users, but with one underlying struct? Should we think more about this?

<!-- BEGIN CLAUDE-RESPONSE: Q1 both APIs with one struct -->
> **Claude:** Yes — both constructors backed by the same internal state. The Union-Find lives inside; the user picks whichever construction style fits their workflow.
>
> ```julia
> mutable struct Sites
>     list::Vector{Site}
>     equiv::IntDisjointSets
>
>     # Variant 1: incremental (call equate! later)
>     function Sites(list::AbstractVector{Site})
>         new(collect(list), IntDisjointSets(length(list)))
>     end
>
>     # Variant 2: upfront partition (validates, builds the same disjoint-set state)
>     function Sites(list::AbstractVector{Site}, classes::AbstractVector{<:AbstractVector{<:Integer}})
>         seen = falses(length(list))
>         for class in classes
>             @assert !isempty(class) "Equivalence classes cannot be empty"
>             for i in class
>                 @assert 1 <= i <= length(list) "Class member $i out of range [1, $(length(list))]"
>                 @assert !seen[i] "Site $i appears in multiple equivalence classes"
>                 seen[i] = true
>             end
>         end
>         eq = IntDisjointSets(length(list))
>         for class in classes, i in class[2:end]
>             union!(eq, class[1], i)
>         end
>         new(collect(list), eq)
>     end
> end
> ```
>
> Both produce the same internal state. The user can mix and match too — start with Variant 2 and call `equate!` later to add more equivalencies.
>
> User code:
>
> ```julia
> # Incremental:
> sites = Sites([Site(...), Site(...), Site(...), Site(...)])
> equate!(sites, 1, 2)
> equate!(sites, 3, 4)
>
> # Upfront:
> sites = Sites([Site(...), Site(...), Site(...), Site(...)],
>               [[1, 2], [3, 4]])
> ```
>
> No deeper thought needed — this is a clean dual-constructor pattern.
<!-- END CLAUDE-RESPONSE -->

2. **`HNF` validation strictness.** I have inner-constructor `@assert`s validating the lower-triangular HNF bounds. In production these should probably be `throw(ArgumentError(...))` instead of `@assert` (which gets stripped at `--check-bounds=no`). Convert to throws? Yes convert to throws
3. **`Supercell.permutation_group` storage size.** For a single enumeration, ~hundreds of `Supercell`s × ~tens to thousands of permutations × `n*nD` Ints each. Worst case maybe ~10 MB. Acceptable cache size, or worth lazy-computing? Acceptable cache size I think. More efficent too, right? How much so, do you estimate?

<!-- BEGIN CLAUDE-RESPONSE: Q3 cache-savings estimate -->
> **Claude:** Order-of-magnitude estimate:
>
> **Cost of computing `permutation_group` for one Supercell:** iterate over each rotation $R$ in the stabilizer subgroup (at most 48 for cubic, 24 for hexagonal, 16 for tetragonal, …) and compute the induced permutation on `n × n_D` supercell sites. Per-rotation work is $O(n \cdot n_D)$ multiplications + mod operations. So at typical sizes ($|G| \sim 48$, $n \cdot n_D \sim 32$): ~1500 basic ops per Supercell — microseconds.
>
> **Read frequency in a typical enumeration:** the perm group is consulted once per labeling check. For an enumeration with $10^6$ labelings on a single Supercell, that's $10^6$ reads per Supercell.
>
> **Without cache** (recompute on every read): $10^6 \times 1500 = 1.5 \times 10^9$ basic ops per Supercell. Order of seconds for one Supercell. With many Supercells in an enumeration, this scales to minutes-to-hours of pure recomputation.
>
> **With cache** (compute once, read many): essentially zero amortized cost.
>
> So caching saves seconds-to-minutes-to-hours depending on enumeration size — not transformative (the labeling enumeration itself is the dominant cost), but real and free given the modest memory footprint. The 10 MB upper bound is when there are hundreds of distinct Supercell symmetry classes; most enumerations have far fewer.
>
> Conclusion: cache it. The memory cost is trivial; the time savings are nontrivial; the code is simpler than lazy-computing with thread-safe memoization.
<!-- END CLAUDE-RESPONSE -->
4. **`Enumeration{L}` vs `LazyEnumeration{L}` — same type or different?** I've drafted them as different types. Alternative: one type with a `materialized::Bool` flag. The two-types form is type-stable and ergonomic; flag form is one type to remember. Lean toward two types unless you prefer the flag. Me too. two types great.
5. **`Concentration` constructor accepting integers.** `Concentration([15, 17])` reads as "15 of species 1, 17 of species 2." But this is ambiguous if the user intends "15:17 ratio" vs "exactly 15 of A and 17 of B in a 32-cell." I've defined the integer form to mean ratio (it normalizes by the sum). Worth a clearer constructor name like `Concentration_ratio([15, 17])` to disambiguate? Yes, maybe. It's verbose but it's only used at the beginning. Clarity better than brevity in this case. Do you agree?

<!-- BEGIN CLAUDE-RESPONSE: Q5 confirm + lock the three constructors -->
> **Claude:** Agreed. Locking in three named constructors, one per intent:
>
> ```julia
> Concentration([15//32, 17//32])                  # canonical: explicit Rational fractions
> Concentration_ratio([15, 17])                    # integer ratio convenience: 15:17 → [15//32, 17//32]
> Concentration_count([15, 17]; n_total=32)        # literal counts: "15 of A and 17 of B in a 32-cell"
> ```
>
> Three unambiguous spellings, each says exactly what it means. The verbose names get typed once at the top of a script; the cost is trivial vs. the cost of writing the wrong one.
>
> `Concentration_count` validates that `sum(counts) == n_total`. If a user writes `Concentration_count([15, 17]; n_total=32)` and `n_total` doesn't match the cell sizes they end up enumerating over (`volume_range` × `n_D`), the dispatcher errors out with the `EmptyEnumerationError` from §6.5.
<!-- END CLAUDE-RESPONSE -->
6. **`materialize(s)` accessor.** Convenience function `materialize(s::EnumeratedStructure{L}) :: Vector{Int8}` decodes the labeling regardless of `L`. Naming alternatives: `decode`, `to_vector`, `digits_of`, `expand`. Pick one to lock in? Basically this is a list of vectors that represend the labeling of the sites in the cell, yes? If that is so, I'm inclined toward something with "label" in the name. I like the sense of the word materialize, because we are making the label concrete (from some sort of hash value).  We are also "expand"ing it into the full label string. (don't love string, though). Let's keep brainstorming before going on.

<!-- BEGIN CLAUDE-RESPONSE: Q6 brainstorm with "label" -->
> **Claude:** Brainstorming with "label" prominent. Ranked roughly by my preference:
>
> 1. **`label_vector(s)`** — concise, says exactly what it returns. Reads like a property accessor (which it functionally is). My top pick.
> 2. **`labels(s)`** — shortest. Plural "labels" reads as "the labels of all the sites in the cell," which is correct. Mild collision risk with property accessors.
> 3. **`materialize_label(s)`** — keeps your "make concrete from hash" sense, with "label" added. A bit long.
> 4. **`expand_label(s)`** — "expand" reads fine for the integer-hash case (expand the int to its digit vector) but oddly for the `Vector{Int8}` case (it's already a vector — there's nothing to expand). Less consistent across the `L` parameter.
> 5. **`decode_label(s)`** — accurate for the integer case (decode the hash) but again odd for `Vector{Int8}` (no decoding needed).
> 6. **`label_digits(s)`** — emphasizes "digit vector with each digit being a species index." Technically accurate but jargony.
>
> First clarification on your "list of vectors" framing: it's a *single* vector (not a list of them) — one entry per site in the supercell, value in `0:k-1` indicating which species sits there. The supercell has `n × n_D` sites, so the labeling vector has length `n × n_D`. (The "list of labelings" is the `Enumeration` itself, which contains many `EnumeratedStructure` values, each carrying one labeling.)
>
> **Lean: `label_vector(s)`.** Reads naturally regardless of the underlying `L`. "Give me the labeling as a vector." Concrete, descriptive, can't be misread.
>
> **Backup: `labels(s)`** if you prefer brevity. The collision risk is low — `EnumeratedStructure` doesn't have a `labels` field. (We'd document that the function exists; users would discover it via tab-completion.)
>
> Other words that came up but I'm not pushing: **`as_vector(s)`** (drops "label"; less informative), **`config(s)`** (says "configuration" without "label"; ambiguous), **`occupations(s)`** (chemistry-flavored — each entry says which species *occupies* that site; a real candidate if you want crystallography vocabulary).
>
> If "occupations" lands for you, I think that's the most natural domain word — chemists/materials scientists routinely talk about "site occupations" for exactly this concept. `occupations(s)` is short, domain-correct, and has zero collision risk in our type catalog. It might actually be better than `label_vector(s)` from the user's perspective even though it doesn't say "label."
<!-- END CLAUDE-RESPONSE -->
7. **2D enumeration types.** `LatticeEnumeration2D` currently has its own (different) `SuperTile` etc. Should the 2D version reuse `ParentLattice` / `Sites` / `Supercell` (with 2×2 matrices instead of 3×3 via parametric dimension), or stay separate? Lean toward "reuse via dimension parameter" but it's invasive. This is tricky because I don't expect the 2D stuff to get used much (but surface scientist and layered materials people might really like it). I lean away from something invasive but we'll we regret it later if 2D applications go viral?

<!-- BEGIN CLAUDE-RESPONSE: Q7 parametric dimension as cheap insurance -->
> **Claude:** Compromise approach: design 3D-only types now but parametrize on dimension so 2D extension is a non-breaking change later. Concretely:
>
> ```julia
> struct ParentLattice{D}                                    # D is the dimension; almost always 3
>     A::SMatrix{D,D,Float64}
>     dset::Vector{SVector{D,Float64}}
>     point_group::Vector{SMatrix{D,D,Int}}
> end
>
> # Constructor infers D from the matrix:
> function ParentLattice(A::AbstractMatrix, dset::AbstractVector{<:AbstractVector})
>     D = size(A, 1)
>     ParentLattice{D}(SMatrix{D,D,Float64}(A),
>                      [SVector{D,Float64}(d) for d in dset],
>                      pointGroup(A))
> end
> ```
>
> All downstream types (`Site`, `Sites`, `HNF`, `Supercell`, `Enumeration`) similarly parametric on `D`.
>
> **What this buys us:**
> - Phase 6 ships 3D as the only tested code path; 2D is structurally allowed but not implemented.
> - Adding 2D later is a matter of writing per-algorithm 2D specializations and tests, not redesigning the type catalog. Each `enumerate{2}(...)`, `count_inequivalent{2}(...)` method has a clear shape to fill in.
> - Users who want 2D today can `include` the existing standalone `LatticeEnumeration2D` submodule, no change.
>
> **Cost:** ~10 minutes of extra typing on the type definitions for the parametric annotations. Zero runtime cost (the compiler specializes per `D` value). Marginal API verbosity (`ParentLattice` becomes `ParentLattice{3}` in some signatures, but the inner constructor infers it from `A`, so users rarely write `{3}` explicitly).
>
> **What this rules out (for now):** wholesale unification of the 3D and 2D code paths in v0.2. The current standalone `LatticeEnumeration2D` stays as-is in v0.2; v0.3+ could fold it into the parametric scheme if 2D demand materializes.
>
> **Lean: do this.** The parametric annotations are cheap insurance against having to break the API later. If 2D never gets demand, we lose ~10 lines of `{D}` annotations and zero runtime cost. If 2D goes viral, we extend without breaking 3D users. Risk-reward is asymmetric in favor of doing it now.
<!-- END CLAUDE-RESPONSE -->

### 6.14 What this enables for Phase 7+

Phase 7 (misuse / scale safety) reads off this catalog directly:
- Pre-flight estimator returns `EnumerationCostEstimate`.
- `BigInt` representation handled via the parametric `L` type — no separate API path.
- The `memory_budget` check happens against `EnumerationCostEstimate.peak_memory_bytes`.

Phase 9 (pymatgen) reads off this catalog: `Enumeration{L}` is what the Python wrapper sees and adapts to pymatgen's `Structure` objects. Conversion is `EnumeratedStructure → real_space_atoms → pymatgen.Structure`.

Phase 10 (CI / regression) reads off this catalog: the regression-comparison utility takes two `Enumeration` values and compares them up to symmetry-equivalence. No file-format intermediation needed.

Phase 11 (DFT outputs) reads off this catalog: the POSCAR writer takes `EnumeratedStructure + ParentLattice + Sites` and emits VASP format.

Phase 12 (synthesis) folds this into a final design document.

<!-- ============= END CLAUDE-ADD: Phase 6 section ============= -->

---

*(Sections for Phases 7–12 will be appended below as they're produced.)*
