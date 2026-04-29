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
| 4 | Paper digests (Hart-Forcade 2008, 2009, 2012; Morgan-Hart-Forcade 2017; Shinohara et al. 2020) | in progress | One paper per pass. 2008 done. |
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

### 2.9 Tests

`~/Drive/Work/codes/enumlib/tests/` is structured as XML-driven test definitions colocated with the source files. `tests/derivative_structure_generator/` alone has 5820 directories of test cases; `enumeration_utilities/` has 10224. The format is mostly: input file → expected output file → comparison tool checks them. The unit-test runner is in `tests/unittests/test_driver.f90` (menu-driven).

Per HISTORY.md, after the 2.0.x changes many tests were re-enabled and outputs updated. The disabled `find_site_equivalencies` tests are UNCLE-only.

For the Julia rewrite: don't try to port the whole test corpus. Pick representative cases that cover (a) HNF generation correctness vs Table IV of the 2008 paper, (b) coloring counts on small FCC/BCC/HCP cases, (c) round-trip via `map_enumStr_to_real_space`, (d) concentration-restricted spot checks, (e) inactive-site spot checks, (f) compare-two-enums regression. Phase 10 (CI + perf regression) will lay this out properly.

### 2.10 Open questions and gotchas (raised by the digest, to track)

1. **Hardwired `max_binomial = 1E10`** (`derivative_structure_generator.f90:1268`) — algorithm-dispatch threshold with a magic constant.
2. **enum4 inactive-site support is incomplete** — confirm via testing before relying on it for non-trivial cases.
3. **Bitstring labeling markers (`lab`, `lm`)** in `generate_permutation_labelings` — opaque, undocumented degeneracy heuristic. Risk surface for the rewrite.
4. **SNF non-uniqueness** — left transform is not uniquely determined; `compare_two_enum_files` handles the resulting automorphisms. Julia rewrite needs to either nail down a canonical SNF (NormalForms.jl?) or replicate the automorphism handling.
5. **Equivalencies transitivity is unchecked** — if the user passes a non-transitive `equivalencies` array, the code silently produces wrong answers.
6. **Concentration partition enumeration uses GCDs** (`enumeration_routines.f90:70`) — for large k, performance unclear.
7. **Direct-write to unit 14 inside the enumeration loop** — incomplete output if interrupted.
8. **`derivCryst` and `cryst` types are dead** — leftover from an unfinished earlier refactor.

### 2.11 What this means for the Julia design (synthesis)

Pulling the threads from the digest into design implications for later phases:

- **Phase 5 (algorithm dispatch).** At least three known dispatch dimensions: explicit override, site-restricted vs not, multinomial size. Replace the single `origCrossOutAlgorithm` boolean with named algorithm choices and an automatic predictor. The `polya=true` short-circuit becomes a separate top-level entry: `count_inequivalent`.
- **Phase 6 (data structures).** Live types are `RotPermList`, `opList`, `derivStruct`, `tree`. Dead types (`cryst`, `derivCryst`) should not be carried forward. Replace parallel-array site representation (`dFull/d`, `labelFull/label`, `equivalencies`, `inactives`) with a single `Site` struct. SNF non-uniqueness needs a deliberate decision (canonicalize or carry automorphisms).
- **Phase 7 (scale safety).** Pre-flight Pólya count is the obvious entry point. The `max_binomial = 1E10` threshold is a placeholder for a real cost model. BigInt comes in for the count itself; the labeling representation can stay machine-int once n×nD is bounded.
- **Phase 9 (pymatgen).** Pymatgen wraps the CLI driver, which means it parses `struct_enum.out`. Either preserve that file format byte-for-byte or write a thin Julia→Pymatgen shim.
- **Phase 10 (CI + perf).** Regression test = run our enumeration vs Fortran's `compare_two_enum_files`-style equivalence, on a curated test corpus. Performance regression = walltime on a fixed set of hard cases.
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
| `LatticeColoringEnumeration.jl` | 287 | HNF/SNF/labeling primitives — `getAllHNFs`, `tripletList`, `basesAreEquiv`, `getSymInequivHNFs`, `getFixingOps`, `getFixingLatticeOps`, `getTransGroup`, `gCoordsToOrdinals`, `ordinalToGcoords`, `getCartesianPts`, `checkCartesianPt`, `get_nonzero_index`, `getOrdinalsFromCartesian`, `coloringsOfHNFList`, plus structs `SuperTile`, `ColoredTile`, `ParentLattice`. |
| `CEdataSupport.jl` | 120 | The `enumStr` struct + `readStructenumout`, `readEnergies`, `readStrIn` (UNCLE structures.in reader, gzip-aware). |
| `clusterequvi.jl` | 34 | `shiftToOrigin`, `isEquivClusters` (Cartesian-coordinate cluster equivalence). |
| `radiusEnumeration.jl` | 123 | `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius`, `estimatedTime` — radius-bounded enumeration variants. |
| `LatticeEnumeration2D.jl` | 481 | Standalone 2D submodule (own module declaration, own deps `Plots`, `SmithNormalForm`, `StaticArrays`). NOT loaded by `Enumlib.jl` by default; users `include` it manually. |

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
- **No POSCAR pipeline.** `scratch/{read,make}POSCAR.jl` need cleanup before they can be loaded as module code, and `genPOSCARs` even has a captured-global-`A` bug.
- **No regression-comparison tooling.** Without something like `compare_two_enum_files`, we can't validate the rewrite against the Fortran gold standard.
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

### 3.4 Implications for the rewrite plan

- **Build the missing 90%, don't rewrite the 10%.** Most of what's there (HNF/SNF/symmetry primitives, getUniqueColorings) is correct and well-isolated. The rewrite should preserve these as a foundation and *add* the missing capabilities on top, with an opportunity to redesign the data model (Phase 6) at the layer boundary.
- **Phase 6 priority list** for data structures: (a) replace `enumStr`; (b) design a `Site` abstraction unifying `dFull/d`, `labelFull/label`, `equivalencies`, `inactives`; (c) design `Configuration` (the labeling state) so concentration/site restrictions can hook in cleanly; (d) decide on canonical SNF or carry automorphisms.
- **Phase 5 dispatch** should expose `enumerate(parent, …)` with kwargs for concentration_range, site_restrictions, fixed_cells, algorithm=:auto. The :auto path uses Pólya counting + multinomial size to choose enum3 vs enum4.
- **Order of feature delivery (rough guess; Phase 12 will refine):** (1) `map_enumStr_to_real_space` + POSCAR writer (unblocks DFT users on what we already have), (2) Pólya pre-flight count, (3) concentration restrictions, (4) inactive sites + equivalencies, (5) full multilattice support, (6) recursive-stabilizer algorithm, (7) compare-two-enums regression tool, (8) struct_enum.out writer + pymatgen-compatibility shim.

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
- **Incompleteness of FWZ-style correlation deduplication** is the historical reason the geometry-free approach was developed. The Julia rewrite must not regress on this — any future "fast deduplication" optimization (Phase 8 / Shinohara 2020) needs to be checked for completeness in the same way.

#### Open question

The paper says (Sec. II.A): "the implementation of the HNF-generating algorithm can be rigorously checked" using the closed-form count from Eq. 2. Worth wiring this as a CI test in Phase 10: `count(getAllHNFs(n)) == closed_form_HNF_count(n)` for $n$ up to, say, 30.

<!-- ============= END CLAUDE-ADD: Phase 4 — paper digests (in progress) ============= -->

---

*(Phase 4 continues with 2009, 2012, 2017, 2020. Sections for Phases 5–12 will be appended below as they're produced.)*
