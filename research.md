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

<!-- ============= BEGIN CLAUDE-ADD: Phase 2 section ============= -->

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

<!-- BEGIN CLAUDE-RESPONSE: site abstraction -->
> **Claude:** Logged as a Phase 6 priority. Tentative shape (subject to refinement when we get there): a `Site` struct carrying `(position::SVector{3}, allowed_labels::BitSet, equivalent_to::Int, inactive_label::Union{Nothing,Int})`, with `equivalent_to` enforced via Union-Find at construction so transitivity can't silently break (addresses your gotcha #5 below). The parent lattice + dset becomes a `Vector{Site}` plus the basis matrix, replacing the parallel arrays `dFull/d`, `labelFull/label`, `equivalencies`, `inactives`.
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: off-by-one risk -->
> **Claude:** Honest answer — I don't have direct evidence it has been a fielded bug. I overcalled the risk; the Fortran code's interior-points loop is well-tested at this point. The phrase was speculative ("silently miss or duplicate atoms" is the *kind* of error those bounds could produce, not one we know happened). Concrete derisking for the rewrite: write a property-based test that, for a curated set of (lattice, HNF, dset) cases, verifies (a) the right number of atoms come out (`n × n_D`) and (b) all atoms are distinct after lattice-reduction. If we get those two right, off-by-one in the loop is caught immediately. So: not a hot risk, but cheap to lock down — Phase 10 task.
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: rethink struct_enum.in format -->
> **Claude:** Worth doing. The Fortran format is *operational* (it's what the CLI driver eats) rather than *semantic* (it doesn't model the enumeration problem cleanly). Specifically: it conflates parent lattice description, multilattice dset, label-allowance, equivalencies, concentration constraints, and enumeration parameters all into one freeform text file with positional sensitivity. A cleaner Julia-native posing would separate:
> 1. **Crystal structure**: `ParentLattice` (basis vectors + dset). Just geometry.
> 2. **Allowed substitutions**: `Vector{Site}` with per-site `allowed_labels` (covers active/inactive/restricted).
> 3. **Constraints**: a `Constraints` struct with `concentration_range`, `fixed_cells`, etc. — optional.
> 4. **Enumeration parameters**: `volume_range`, `algorithm`, etc. — kwargs on the entry function.
>
> The Julia call site becomes `enumerate(parent, sites, constraints; volume_range=2:10)` rather than reading a magic file. *Per the no-Fortran-compat directive in §2.10 #5:* a one-way `Enumlib.LegacyImport.read_struct_enum_in(path)` reader exists in a separate submodule for migrating existing Fortran setups, but it's not the primary API and not load-bearing.
>
> Phase 6 (data structures) and Phase 9 (pymatgen) jointly own this decision.
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: normalize the output format -->
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
<!-- END CLAUDE-RESPONSE -->
I like all of this. One thought to flag and reconsider later: the labeling element in EnumeratedStructure could be replaced a single Int (Big Int?) that could be regenerated into the labeling. Not sure that is efficient, but might save space. Let's flag it and rethink later.

<!-- BEGIN CLAUDE-RESPONSE: labeling-as-integer -->
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
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: bitstring markers explained -->
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
<!-- END CLAUDE-RESPONSE -->
Good catch. We'll make sure that the same opaqueness doesn't happen in the julia code. It will be well documented and commented in the code.


4. **SNF non-uniqueness** — left transform is not uniquely determined; `compare_two_enum_files` handles the resulting automorphisms. Julia rewrite needs to either nail down a canonical SNF (NormalForms.jl?) or replicate the automorphism handling. 
SNF is canonical by definition. It's the left transform that isn't unique. Not sure what effort would be necessary to enforce that. Probably easier not to rely on it and compute equivalencies. In any case, we need to think about this more.

<!-- BEGIN CLAUDE-RESPONSE: SNF terminology correction -->
> **Claude:** You're right — I was sloppy with the language. The SNF matrix $S$ itself (the diagonal entries $s_1 \mid s_2 \mid s_3$) is canonical given $H$. It's the left and right unimodular transforms $L, R$ in $L H R = S$ that are not unique — many $L, R$ pairs yield the same $S$. And per HISTORY.md 2.0.3, when symlib's SNF routine was updated, the produced $L$ changed even though $S$ didn't, which cascaded into different output rows for "equivalent" enumerations.
>
> The correct phrasing is "left-transform non-uniqueness," not "SNF non-uniqueness." I'll fix the wording in the Phase 2 main text and the synthesis bullet on a follow-up pass.
>
> Your second point — "probably easier not to rely on it and compute equivalencies" — is the right framing. Rather than fight to canonicalize $L$, we accept that two correct enumerations may disagree on row content and rely on `compare_two_enum_files`-style equivalence checking. That's what the Fortran code already does post-2.0.3. Phase 6 should make this an explicit design decision: **don't expose $L$ in the public output API; keep it internal to the (HNF, labeling) → real-space mapping**, and provide a structure-equivalence comparator for users who need to compare enumerations across versions.
<!-- END CLAUDE-RESPONSE -->
Yes

5. **Equivalencies transitivity is unchecked** — if the user passes a non-transitive `equivalencies` array, the code silently produces wrong answers.
We need to make the new code bullet proof to that failure mode

<!-- BEGIN CLAUDE-RESPONSE: enforce transitivity -->
> **Claude:** Two ways to make this bulletproof, in order of preference:
>
> 1. **Use a representation that enforces transitivity by construction.** A Union-Find / Disjoint-Set structure stores equivalence classes directly: there's no array of pointers that could disagree, just "what class is site `i` in?" — answered in nearly $O(1)$. Julia stdlib doesn't ship one, but `DataStructures.jl`'s `IntDisjointSets` works, or we write a tiny one in ~30 lines. Construction API: the user calls `add_equivalent!(sites, i, j)` and the structure handles the rest. Reading `canonical_site(sites, i)` always returns the canonical representative; it's transitively-correct for free.
> 2. **Validate at construction.** If we keep the array form for compat with the Fortran format, validate at construction time: walk the array, for each `i`, follow `equivalencies[i]` to fixed point and check that the same canonical site comes back from any starting point in the cycle. Throw a `DomainError` with a descriptive message if not.
>
> Lean: option (1). Equivalences are conceptually a partition; using a partition data structure expresses that intent and prevents the failure mode at the type level. Phase 6 design point.
<!-- END CLAUDE-RESPONSE -->
I don't anticipate that we'll even want "compat with the Fortran format". Design right, go forward with confidence. Learn from the past, keep the good. Redesign the rest.

<!-- BEGIN CLAUDE-RESPONSE: no Fortran-format compat — strategic note -->
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
<!-- END CLAUDE-RESPONSE -->


6. **Concentration partition enumeration uses GCDs** (`enumeration_routines.f90:70`) — for large k, performance unclear.
We can brainstorm how big k might be, insert some failsafe triggers, or rethink this completely. I don't remember why the GCD was convenient.

<!-- BEGIN CLAUDE-RESPONSE: GCD in concentration partitioning -->
> **Claude:** I haven't traced the exact `enumeration_routines.f90:70` site, but the typical role of GCDs in this kind of code is *fraction reduction* — reducing concentration ranges $[\text{min\_num}, \text{max\_num}, \text{denom}]$ to lowest terms across multiple species, so cell volumes that don't admit the requested concentration are skipped without enumeration. E.g., for $\text{cRange}_A = [1, 1, 4]$ ($A$ is exactly 25%), only cell volumes that are multiples of 4 can produce that concentration; for cell volume 6 the GCD machinery rejects it before the labeling pass starts.
>
> Practical scope: $k$ in materials enumeration is almost always 2 or 3; rarely 4; "high-entropy alloys" cases (HEAs) push to 5–6. So the worst case the algorithm needs to handle gracefully is $k = 5$ or $6$. GCD computations on small integers are ns-fast; the cost isn't in the GCDs themselves, it's in the *number* of partitions to consider, which scales as roughly $\binom{n+k-1}{k-1}$. For $n = 50, k = 6$ that's around 3 million partitions — still tractable.
>
> Concrete plan: implement the partition-enumeration with GCD-based pruning per Fortran, but *also* expose a `partition_count(n, k, ranges)` pre-flight that warns if the number of partitions × estimated configurations-per-partition exceeds a threshold. That way users with weird high-$k$ requests get a clear "this will produce $10^{15}$ structures, abort?" prompt rather than silent thrashing. Phase 7 (misuse mitigation) home.
<!-- END CLAUDE-RESPONSE -->
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

<!-- ============= END CLAUDE-ADD: Phase 2 section ============= -->

---

<!-- ============= BEGIN CLAUDE-ADD: Phase 3 section ============= -->

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

<!-- BEGIN CLAUDE-RESPONSE: dead structs verified -->
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
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: iterator-first API -->
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
<!-- END CLAUDE-RESPONSE -->

- **No POSCAR pipeline.** `scratch/{read,make}POSCAR.jl` need cleanup before they can be loaded as module code, and `genPOSCARs` even has a captured-global-`A` bug.
- **No regression-comparison tooling.** Without something like `compare_two_enum_files`, we can't validate the rewrite against the Fortran gold standard.
We really need this. The Fortran is extremely strong, heavily battle tested. 

<!-- BEGIN CLAUDE-RESPONSE: regression-comparison priority -->
> **Claude:** Promoting in the work plan. Currently item (7) in §3.4's order-of-feature-delivery; should move up. Two reasons:
> 1. Without it we have no objective measure that any new feature is correct against the Fortran reference.
> 2. It's the *gating* tool for porting concentration restrictions, multilattices, and inactive sites — for each, we run Fortran enumlib on a representative case, run the new Julia code on the same case, compare, iterate.
>
> Revised priority order: (1) `map_to_real_space` + POSCAR writer (already partial), (2) **compare-enumerations regression utility** (was 7), (3) Pólya pre-flight count, (4) concentration restrictions, (5) inactive sites + equivalencies, (6) multilattice support, (7) recursive-stabilizer algorithm, (8) `Enumlib.LegacyImport` — read-only Fortran-format reader for migration + test-corpus loading.
>
> *Earlier draft of (8) read "struct_enum.out writer + pymatgen-compatibility shim." Updated per your no-Fortran-compat directive in §2.10 #5: we don't preserve the file format as a long-term API. Pymatgen integration becomes a Python-callable Julia API via PythonCall (Phase 9), not a file-format shim.*
>
> Phase 12 will lock this in; flagging now while the reasoning is fresh.
<!-- END CLAUDE-RESPONSE -->
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

<!-- ============= END CLAUDE-ADD: Phase 3 section ============= -->

---

<!-- ============= BEGIN CLAUDE-ADD: Phase 4 — paper digests (in progress) ============= -->

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

<!-- BEGIN CLAUDE-RESPONSE: perfect hash explained -->
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
<!-- END CLAUDE-RESPONSE -->
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

<!-- BEGIN CLAUDE-RESPONSE: generalize over wrapper -->
> **Claude:** Yes, generalize. Wrappers introduce an extra abstraction layer (you have to remember which version you're calling, what its semantics are, when to convert), and they tend to leak — eventually some caller wants to skip the wrapper for performance and you have two parallel APIs. Generalizing keeps one canonical function with one canonical signature; the singleton-dset case ($n_D = 1$) is just a degenerate input that the same code handles cleanly.
>
> Concrete shape (Phase 6): `getPermG(supercell::Supercell, parent::ParentLattice) :: Vector{Vector{Int}}` returning permutations on `n × n_D` sites. When `parent.dset == [zero_vector]`, the result reduces to the current single-site permutation list and existing call sites work unchanged.
<!-- END CLAUDE-RESPONSE -->

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

<!-- BEGIN CLAUDE-RESPONSE: Rosenbrock paper renamed and queued -->
> **Claude:** Renamed your `papers_polya.pdf` → `papers/RosenbrockEtAl_2016_NumericalPolyaEnumerationTheorem.pdf` per our naming convention. Confirmed first page: Rosenbrock, Morgan, Hart, Curtarolo, Forcade, *ACM J. Exp. Algorithmics* **21**, 1.11 (Aug 2016). DOI: 10.1145/2955094. This is the numerical Pólya implementation that the Morgan 2017 tree algorithm references for its pre-flight count. I'll digest it as **§4.6** in a follow-up Phase 4 commit (small addition; one paper). It directly enables Phase 7 (misuse mitigation) since the pre-flight count is the user-protection feature.
<!-- END CLAUDE-RESPONSE -->

2. **The "smallest first" sort order**. Section 3 notes that placing colors smallest-first minimizes top-level branching. This is a heuristic, not proved optimal. Worth checking whether the Julia implementation should preserve this default and whether other orderings ever win. How would we test that?

<!-- BEGIN CLAUDE-RESPONSE: testing sort orders -->
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
<!-- END CLAUDE-RESPONSE -->

3. **Arrows vs. our scope**. The arrow material is non-trivially intertwined with the coloring tree in Fortran; the Julia rewrite should design the `Tree` API so that an arrow extension *could* slot in cleanly later without forcing the rest of the code to anticipate it. Phase 6 design responsibility. We don't need the arrows, ever. Even if we did, the design was faulty. We need to start from scratch if we ever do arrows again.

<!-- BEGIN CLAUDE-RESPONSE: arrows fully out of scope -->
> **Claude:** Updating the directive: arrows are fully out of scope, full stop. Removing the "design Tree API for arrow extensibility" point — that was overcaution and would only complicate the Tree code without payoff. The Julia `Tree` struct will not anticipate arrows in any way. If a future researcher wants arrow enumeration, they design from scratch with a different starting point.
>
> Will also remove the Tree's `arrow_group::GroupList` field hint and the related extension discussion from the rewrite-implications synthesis. One less degree of freedom is one less source of bugs.
<!-- END CLAUDE-RESPONSE -->


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

<!-- ============= END CLAUDE-ADD: Phase 4 — paper digests (complete) ============= -->

---

*(Sections for Phases 5–12 will be appended below as they're produced.)*
