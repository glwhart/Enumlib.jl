# Documentation Plan for Enumlib.jl

A planning document for building user-facing documentation for Enumlib.jl. Modeled on `Spacey.jl/documentation_plan.md` per user direction (2026-05-08): we want documentation that's *at least as detailed, careful, and useful* as Spacey's. Reads of Spacey's plan, MinkowskiReduction.jl's docs structure, our own `research.md` and `docs/notes/chunk*-design.md` files inform the proposal below.

This is a planning document — not the docs themselves. Decisions and trade-offs are recorded so the actual writing has a clear target.

---

## 1. Documentation philosophy: what we're adopting

### 1.1 Diátaxis as the spine

The Diátaxis framework (Daniele Procida) splits documentation into four mutually exclusive types based on the user's situation along two axes:

|              | **Skill acquisition** (learning) | **Skill application** (working) |
|---           |---                               |---                              |
| **Action**   | **Tutorials**                    | **How-to guides**               |
| **Cognition**| **Explanation**                  | **Reference**                   |

The four types serve different needs and require different writing styles. Mixing them is the most common source of confusing documentation.

The "compass" decision rule: when adding a piece of documentation, ask *what is the reader doing?* (action vs cognition) and *what state are they in?* (learning vs applying). The answer points at exactly one quadrant.

We adopt Diátaxis directly from Spacey's plan — same four-quadrant `docs/src/` tree, same per-page Diátaxis-purity rule. We do *not* invent a fifth category, nor split content randomly into "Getting Started", "API", "Cookbook" etc. as is common but anti-pattern.

### 1.2 Supporting principles from Write the Docs

Diátaxis tells you the *structure*; Write the Docs adds *quality* practices that complement it:

- **Skimmability.** Descriptive headings, lead with the concept, link aggressively. Readers rarely read sequentially.
- **Concrete examples.** Every page that allows it should have a runnable code block.
- **Source proximity.** Docstrings live next to the code they describe; written prose lives in `docs/src/`. Single source of truth for each.
- **Currency.** Out-of-date documentation is worse than missing — it actively misleads. Doctests + CI catch the drift.
- **Strategic repetition.** A small amount of repetition (e.g. example signatures in both reference and how-to) is better than aggressive de-duplication that forces readers to chase links.

### 1.3 Other approaches we considered and why we're not using them

Identical considerations to Spacey's §1.3 (DITA, Information Mapping, Good Docs Project, RTD default, Documenter `@autodocs`-only). Same conclusion: **Diátaxis structure + Write-the-Docs quality + Documenter.jl tooling**. None of the alternatives offer something Diátaxis doesn't already.

---

## 2. Sources we already have

Most of the Enumlib documentation content already exists in scattered form across the chunk-by-chunk design and review docs. Mapping each source to its proper Diátaxis quadrant tells us what to lift verbatim, what to adapt, and what to write fresh.

| Source                                       | Best target quadrant   | What to do                                                                                          |
|---                                           |---                     |---                                                                                                  |
| Source code docstrings                       | Reference              | Lift via `@autodocs` per-topic. **Audit pass** required first — many were terse during chunk-by-chunk implementation. |
| `research.md` Phase-4 paper digests (§4.1, 4.3, 4.4, 4.6) | Explanation | The four-algorithm theory pages lift directly from §4 digests. Trim research-narrative tone.       |
| `research.md` §5 (algorithmic dispatch)      | Explanation            | The auto-dispatch decision tree, super-periodicity policy (§5.2.1), pre-flight gate (§5.5).        |
| `research.md` §7 (misuse / scale-safety)     | Explanation            | The cost estimator (§7.2), memory-budget gate (§7.3), partition gate (§7.6) — all rationale-heavy. |
| `docs/notes/chunk1-review.md` (glossary)     | Explanation            | The type-system glossary (thin wrapper, parametric `where`, hash pairing, view) is reusable teaching material. |
| `docs/notes/chunkN-design.md` files          | Internal               | Stay internal — planning history, design Q&A, trade-offs. Not user-facing. Linked from explanation pages where the trade-off matters. |
| `docs/notes/chunkN-review.md` files          | Internal               | Same — review records, not docs.                                                                    |
| `docs/notes/v0.2-plan.md`                    | Internal               | Execution log; gets frozen at v0.2.0 release.                                                       |
| `test/test_*.jl` files                       | Tutorial / How-to source | Existing tests are a cookbook of "how to use this on a real materials problem" — mine for examples. The chunk-7 Ag-Pt 15:17 reference test is especially useful for the canonical tutorial. |
| `papers/*.pdf` (HF 2008, HF 2012, Morgan 2017, Rosenbrock 2016) | Explanation (cited, not lifted) | Reference these in explanation pages; users can read them for depth. |
| `CLAUDE.md`                                  | Internal               | Explicitly for AI-assisted development; out of scope for user docs.                                 |

> The docstrings should not be too terse. Every function should have one. Every function should also have at least on doctest, more if that's useful, there are multiple kwargs, multiple use cases, etc. When in doubt, make extra and then ask me if we should delete some.

**Locked docstring policy (2026-05-08):** every public function has a docstring (no exceptions). Every public function has *at least one* doctest. Functions with multiple kwargs / multiple use cases / interesting edge behavior get *multiple* doctests. **Err on the side of more, then ask whether to trim.** This stronger policy expands Phase 13b's scope from "audit existing prose" to "audit + add doctests to bring every function up to the doctest minimum." Estimate adjusted accordingly in §6.
---

## 3. Proposed documentation structure

A `docs/src/` tree organized by the four Diátaxis quadrants, with an entry-point `index.md` that orients new readers. Mirrors Spacey's structure in shape; content is Enumlib-specific.

```
docs/src/
├── index.md                                  ← landing: 1-minute orientation + 4 paths
├── tutorials/
│   ├── index.md                              ← 1-paragraph intro, links to:
│   ├── 01-first-enumeration.md               ← "Enumerate all binary FCC structures up to n=8"
│   ├── 02-fixed-concentration.md             ← "Find all 15:17 Ag-Pt structures in the cubic 2×2×2 supercell"
│   └── 03-dft-training-database.md           ← Phase 11 workflow: enumerate → POSCAR → DFT → fit
├── how-to/
│   ├── index.md                              ← intro + table of contents
│   ├── construct-a-parent-lattice.md         ← `ParentLattice` constructor patterns; primitive vs conventional FCC
│   ├── describe-substitution-sites.md        ← `Sites`, `Site`, allowed_labels, equate!, active vs inactive
│   ├── select-supercells.md                  ← `VolumeRange`, `RadiusBound`, `ExplicitHNFs` — when to use each
│   ├── enumerate-at-fixed-concentration.md   ← `Concentration`, `Concentration_ratio`, `Concentration_count` patterns
│   ├── sweep-concentration-ranges.md         ← `ConcentrationRange` + the partition gate
│   ├── pick-an-algorithm.md                  ← `:auto` vs explicit `:exhaustive` / `:multinomial` / `:recursive_stabilizer`
│   ├── count-without-enumerating.md          ← `count_inequivalent` for Pólya pre-flight
│   ├── estimate-cost.md                      ← `estimate_cost`, `EnumerationCostEstimate`, the memory gate
│   ├── handle-super-periodicity.md           ← `include_superperiodic` kwarg; when to use which value
│   └── write-poscars-for-dft.md              ← Phase 11 writer + manifest workflow
├── reference/
│   ├── index.md                              ← `@index` + module overview
│   ├── parent-and-sites.md                   ← `ParentLattice`, `Site`, `Sites`, `equate!`, accessors
│   ├── supercells.md                         ← `HNF`, `Supercell`, `SupercellSelection` and concrete subtypes
│   ├── concentrations.md                     ← `Concentration`, `Concentration_ratio`, `Concentration_count`, `ConcentrationRange`, `multiplicities`, `concentrations_in_range`
│   ├── enumerate-and-count.md                ← `enumerate`, `count_inequivalent`, `Enumeration`, `EnumeratedStructure`, `InequivalentCount`
│   ├── cost-estimator.md                     ← `estimate_cost`, `EnumerationCostEstimate`, `EnumerationTooLargeError`, `format_bytes`, `default_memory_budget`
│   ├── polya.md                              ← `polya_count`, `cycle_structure`, `aperiodic_orbit_count`
│   └── poscar-io.md                          ← Phase 11 functions (`to_poscar`, `write_enumeration`, `read_results`, `attach_results`)
└── explanation/
    ├── index.md                              ← intro: "why Enumlib decides what it decides"
    ├── algorithm-overview.md                 ← End-to-end pipeline + the four algorithms in one diagram
    ├── exhaustive-2008.md                    ← Hart-Forcade 2008 crossing-out (`:exhaustive`)
    ├── multinomial-2012.md                   ← Hart-Nelson-Forcade 2012 mixed-radix hash + crossing-out (`:multinomial`)
    ├── recursive-stabilizer-2017.md          ← Morgan-Hart-Forcade 2017 tree (`:recursive_stabilizer`)
    ├── polya-counting.md                     ← Pólya / Burnside + Möbius for aperiodic counts (chunk 7)
    ├── dispatch-and-cost-gate.md             ← `:auto` decision tree + memory-budget gate rationale
    ├── super-periodicity.md                  ← The "no duplicates" principle, the kwarg, when each branch is right
    ├── concentration-and-multiplicity.md     ← Why three constructors, the `Rational{Int}` choice, partition gate rationale
    └── glossary.md                           ← Terms used across the docs (lifted from chunk-1 review glossary)
```

**~25 markdown files total** (1 landing + 4 quadrant indexes + 3 tutorials + 10 how-to + 7 reference + 9 explanation). Each page targets a single Diátaxis quadrant; cross-links between quadrants are heavy but content is not duplicated.

This is bigger than Spacey's 17 files because Enumlib has more public API surface (four algorithms vs Spacey's one main algorithm; structured concentration types; cost estimator + Pólya counter + tree). The rough size ratio (Enumlib's ~25 vs Spacey's ~17) tracks the rough source-line ratio (Enumlib ~3000 lines of new v0.2 code vs Spacey's ~1500).

### 3.1 Landing page — what `index.md` does

Three jobs:
1. **Tagline + one-paragraph what-is-Enumlib:** "Enumerate symmetry-inequivalent derivative superstructures of a parent lattice. Used for cluster expansion, MLIP training-database generation, and structural phase searches in alloys, oxides, and other periodic systems."
2. **Four-path navigation** mirroring the Diátaxis quadrants, with one-sentence descriptions:
   - "I'm new — *follow a tutorial*"
   - "I have a specific task — *find a how-to guide*"
   - "I need to look something up — *consult the reference*"
   - "I want to understand how Enumlib decides — *read an explanation*"
3. **One install-and-test snippet** — `Pkg.add("Enumlib")` (post-registration) or `Pkg.develop` (pre-registration), plus a 5-line "find 19 inequivalent FCC binary structures at n=4" verification.

### 3.2 Tutorials (3 of them, narrowly scoped)

A tutorial in Diátaxis is a *guided learning experience*, not a tour. It must produce a concrete, visible result and never explain. Three are right for Enumlib:

- **`01-first-enumeration.md`** — "Enumerate all binary FCC structures up to n=8." Walks through `using Enumlib`, defining a primitive FCC `ParentLattice`, building a single-site `Sites` with `BitSet([0,1])`, calling `enumerate(parent, sites; supercells = VolumeRange(2:8))`, getting back an `Enumeration` with 390+19+(other small-n counts) structures. **~10 minutes.** Touches: `ParentLattice`, `Site`, `Sites`, `VolumeRange`, `enumerate`, `Enumeration`, `EnumeratedStructure`. Does NOT touch concentration, algorithms, cost gate, or POSCAR writing.

- **`02-fixed-concentration.md`** — "Find all 15:17 Ag-Pt structures in the cubic 2×2×2 supercell — count first, then enumerate." Walks the canonical Ag-Pt case from chunk 7/8: build `Concentration_count([15, 17]; n_total = 32)`, find the cubic HNF programmatically (Minkowski-reduce trick from `test_recursive_stabilizer.jl`), call `count_inequivalent` to get the locked **379,926** number, discuss what to do about it (4M is too big for `enumerate(...)` casually). **~15 minutes.** Touches: `Concentration_count`, `count_inequivalent`, `ExplicitHNFs`, `:auto` dispatch picking `:recursive_stabilizer`. Does NOT touch POSCAR writing or cost-estimator.

- **`03-dft-training-database.md`** — "Generate a DFT training database from an enumeration." End-to-end Phase 11 workflow: enumerate at a small concentration sweep, `write_enumeration` to a directory with manifest, show what the POSCAR header looks like (with `energy_eV=` slot), simulate filling in the energies, `read_results` + `attach_results` to get a tagged `Enumeration`, hand off to a CE-fitting workflow. **~20 minutes.** **Load-bearing tutorial** — the v0.2.0 first-application story.

Each tutorial:
- Shows the input *and* the expected output verbatim, so readers know they're on track.
- Avoids vocabulary beyond what's needed for the next step.
- Does NOT explain *why* the count is what it is — that's an explanation page, linked from the wrap-up.

### 3.3 How-to guides (10 of them, problem-focused)

Each how-to is ≤ 1 page. Pure recipe form: numbered steps, code, expected output. No explanation; cross-link to the explanation pages where relevant.

The 10 above cover the canonical questions a working scientist asks. Some highlights:

- **`pick-an-algorithm.md`** — when `:auto` is right (almost always); when to override; how the bitmap-vs-tree decision works at the threshold; what the `notes::Vector{String}` field of `EnumerationCostEstimate` tells you.
- **`handle-super-periodicity.md`** — the `include_superperiodic` kwarg; when each branch is right (cross-volume sweep → drop; single-volume orbit-count comparisons → keep); the asymmetric-concentration trip-wire (no super-periodics at 15:17 in n=32).
- **`estimate-cost.md`** — call `estimate_cost` first to size your request; interpret `peak_memory_bytes`; what `:error / :warn / :ignore` does; when to bump `memory_budget`.
- **`write-poscars-for-dft.md`** — the Phase 11 workflow with the explicit POSCAR-header format, the `energy_eV=` slot semantics, what to tell collaborators about the manifest.

### 3.4 Reference (auto + curated)

The reference quadrant is austere and complete. For Enumlib:

- **Each reference page** uses `@docs` blocks to inject the docstrings of a coherent function group.
- **Augmented with `@index` blocks** so each section has a typeable function index.
- **No tutorial or explanation content** in reference pages — strictly signatures, parameters, returns, doctests.

**Pre-condition for the reference quadrant to land cleanly:** every public symbol needs a docstring with at least signature + summary + params + returns + (where possible) a doctest. Audit shows current coverage is uneven — many docstrings were written terse during chunk-by-chunk implementation; some have rich examples (chunk-2's `Sites`, chunk-6's concentration types) and some are one-liners (chunk-3's `HNF`, chunk-1's `SymmetryOp`). Pre-flight: docstring audit + cleanup before docs publication. **This is Phase 13b's primary task.**

Public/private boundary: a few currently-`export`ed symbols may be borderline internal (`coloring_hash`, `coloring_unhash`, `getPermG`, etc. — many are legacy from pre-chunk-5 code). Decide before reference quadrant publishes: keep exported and document, or unexport and stop including in `@autodocs`.

### 3.5 Explanation (9 pages, each illuminating a "why")

The most valuable pages for a research library — they're the difference between "a user can call the function" and "a user understands when the function will mislead them." Sources are pre-existing prose in our internal documents (research.md is rich here).

| Explanation page                      | Lifts from                              | What it covers                                                                       |
|---                                    |---                                      |---                                                                                   |
| Algorithm overview                    | research.md §5.4 + chunk-by-chunk reviews | The end-to-end pipeline + four-algorithm bird's-eye view; one Mermaid flowchart     |
| Exhaustive 2008                       | research.md §4.1 + chunk-5 design       | Hart-Forcade 2008 crossing-out; when bitmap-of-all-labelings is the right tool      |
| Multinomial 2012                      | research.md §4.3 + chunk-6 design + chunk-6.1 review | HF-2012 mixed-radix hash + bitmap; why it's $C$-memory not $k^n$        |
| Recursive-stabilizer 2017             | research.md §4.4 + chunk-8 design       | Morgan 2017 tree; partial colorings + shrinking stabilizers                         |
| Pólya counting                        | research.md §4.6 (Rosenbrock 2016) + chunk-7 design | Burnside / Pólya / Möbius for aperiodic; why count-before-enumerate is cheap |
| Dispatch and cost gate                | research.md §5.4 / §5.5 / §7.2 / §7.3 + chunk-7.5 / 8b designs | `:auto`, the `0.8 × memory_budget` rule, error/warn/ignore semantics |
| Super-periodicity                     | research.md §5.2.1                      | The "no duplicates" principle, the kwarg, the asymmetric-concentration trip-wire   |
| Concentration and multiplicity        | research.md §6.5 + chunk-2 review item 5 | Why three named constructors; `Rational{Int}` choice; partition-gate rationale     |
| Glossary                              | chunk-1 review (type-system glossary)   | Thin wrapper, parametric `where`, hash pairing, view, Hadamard ratio — terms recurring across pages |

Each explanation page:
- Discusses, doesn't instruct.
- Acknowledges alternatives where they exist (e.g., "ZDD for memory-bound very-large enumerations is v0.3 work"; "label-exchange and arrow enumeration are deferred").
- Includes references to literature (HF 2008/2012, Morgan 2017, Rosenbrock 2016, Bublikov 2011, Horiyama 2018).
- Links cross-quadrant: forward to relevant how-tos, back to relevant reference.

---

## 4. Theory pieces from `research.md` and chunk reviews worth surfacing

### From `research.md`

- **Phase 4 §4.1 (HF 2008)** — algorithm 5-step description, super-periodicity step 5d, label-rotation. **Surface in:** Explanation / Exhaustive 2008.
- **Phase 4 §4.3 (HF 2012)** — multinomial mixed-radix hash, Eq. 3, fixed-concentration crossing-out, Ag-Pt application. **Surface in:** Explanation / Multinomial 2012 (and the canonical Ag-Pt tutorial).
- **Phase 4 §4.4 (Morgan 2017)** — partial colorings, shrinking stabilizers, the 9-atom worked example. **Surface in:** Explanation / Recursive-stabilizer 2017.
- **Phase 4 §4.6 (Rosenbrock 2016)** — the numerical Pólya algorithm citation; algorithmic implications. **Surface in:** Explanation / Pólya counting.
- **Phase 5 §5.2** — the public API surface design rationale. **Surface in:** Explanation / Algorithm overview (closing).
- **Phase 5 §5.2.1** — super-periodicity policy, the principle, the kwarg, the v0.3 smart-default candidates. **Surface in:** Explanation / Super-periodicity.
- **Phase 5 §5.4** — `:auto` dispatch decision tree. **Surface in:** Explanation / Dispatch and cost gate.
- **Phase 7 §7.2** — pre-flight cost estimator; per-algorithm memory model. **Surface in:** Explanation / Dispatch and cost gate.
- **Phase 7 §7.3** — memory-budget gate; `:error / :warn / :ignore` semantics; default budget heuristic. **Surface in:** Explanation / Dispatch and cost gate.
- **Phase 7 §7.6** — partition-count gate, the 100 threshold and its rationale. **Surface in:** Explanation / Concentration and multiplicity.
- **Phase 6 §6.5** — `Concentration` + `ConcentrationRange` design rationale. **Surface in:** Explanation / Concentration and multiplicity.

### From chunk-by-chunk reviews

- **chunk-1 review type-system glossary** — thin wrapper, parametric `where`, hash pairing, view, Hadamard ratio. **Surface in:** Explanation / Glossary.
- **chunk-2 review item 5** (three concentration constructors). **Surface in:** Explanation / Concentration and multiplicity.
- **chunk-6.1 review** (BigInt vs Combinatorics.multinomial overflow analysis). **Surface in:** Explanation / Multinomial 2012 (mention the `multinomial_count` BigInt choice for users curious why it returns BigInt).
- **chunk-7 review** (Möbius-non-normality formulation). **Surface in:** Explanation / Pólya counting.
- **chunk-8 design + Q7-C reality check** (Ag-Pt 1003 misremembering, the corrected 379,926). **Surface in:** Explanation / Pólya counting (the canonical-reference story is teaching material).

Most of these go in trimmed form — the discussion-document narrative ("we considered X, then Y, then settled on Z") is internal. The user-facing version states the conclusion plus the reasoning.

---

## 5. Technical setup

### 5.1 Documenter.jl configuration

A new `docs/` directory with `Project.toml` for the docs build, plus `make.jl` similar to Spacey's:

```julia
using Documenter
using Enumlib

DocMeta.setdocmeta!(Enumlib, :DocTestSetup, :(using Enumlib, LinearAlgebra); recursive=true)

makedocs(
    sitename = "Enumlib.jl",
    authors  = "Gus Hart and contributors",
    repo     = "https://github.com/glwhart/Enumlib.jl/blob/{commit}{path}#{line}",
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical  = "https://glwhart.github.io/Enumlib.jl",
        assets     = String[],
    ),
    modules  = [Enumlib],
    pages = [
        "Home" => "index.md",
        "Tutorials" => [...],
        "How-to guides" => [...],
        "Reference" => [...],
        "Explanation" => [...],
    ],
)

deploydocs(
    repo      = "github.com/glwhart/Enumlib.jl",
    devbranch = "main",
    devurl    = "dev",
    target    = "build",
    branch    = "gh-pages",
    versions  = ["stable" => "v^", "v#.#"],
)
```

### 5.2 Doctests

Every example in tutorials, how-to, and reference should be a `jldoctest` block. CI runs `Pkg.test()` followed by a `doctest = true` makedocs and fails on stale examples. **Primary defense against documentation rot.**

Many existing docstrings have illustrative examples but not `jldoctest` blocks. Phase 13b should convert where the output is reproducible (most chunk-1/2/3 type construction; chunk-5 small enumerations; chunk-7 small Pólya cases). Keep prose-only examples for cases where the output isn't suitable for doctesting (large counts; randomized outputs).

### 5.3 GitHub Actions

Two workflows:
- **`.github/workflows/CI.yml`** — runs `Pkg.test()` on push and PR. Matrix per Q8: Linux + macOS, Julia stable + LTS. **Currently no CI configured at all** — Phase 13a's first task.
- **`.github/workflows/Documentation.yml`** — builds + deploys docs on push to `main` and on tags. Standard Documenter recipe.

### 5.4 Pre-launch source-side prerequisites

- **Docstring audit.** Every public symbol must have a docstring with at least: signature line, one-sentence summary, parameter list, return description, and one example (preferably as a `jldoctest`). Phase 13b's primary task.
- **Doctest passing.** Existing examples in source need to be updated where they reflect old API (e.g., chunk-2 may have docstring examples that pre-date chunk-2.1's `coloring_hash` rename; verify by running `doctest = true` once Phase 13a's pipeline is up).
- **Public/private boundary.** Some currently-`export`ed symbols are arguably internal. Audit list (preliminary):
  - `coloring_hash`, `coloring_unhash` — used internally by `getUniqueColorings`. Likely keep exported with "internal helper" docstring.
  - `getPermG`, `getTransGroup`, `gCoordsToOrdinals`, `ordinalToGcoords`, `getCartesianPts`, `getOrdinalsFromCartesian`, `get_nonzero_index` — legacy lattice-coord-API symbols still exported. Some may be internal-only post-chunk-5.
  - `isaGroup`, `generateGroup` — group-theory helpers; may be internally useful.
  - `enumStr`, `readStructenumout`, `readEnergies`, `readStrIn` — legacy I/O for the Fortran-format file. Phase 11's POSCAR I/O probably supersedes these for v0.2.0; decide whether to keep them as "legacy compat" exports or unexport.
  - `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius`, `estimatedTime` — mostly subsumed by chunk-4's `SupercellSelection`. Decide.

  Decision before Phase 13b: **draw the public/private line explicitly**, update `Enumlib.jl`'s exports, document the public set, leave private symbols accessible via qualified `Enumlib.foo(...)`.

---

## 6. Phasing

Don't write everything at once. Phased rollout (mirrors Spacey's D1–D6):

### Phase 13.0 — Documentation plan (this doc)
- Land `docs/notes/documentation_plan.md` with the full structure, source-mapping, prerequisites, visuals candidate list. **Reviewed before Phase 13a starts.** **(Pending)**

### Phase 13a — Infrastructure (~½–1 day)
- New `docs/Project.toml`, `docs/make.jl` with the full page tree (mostly empty pages).
- GitHub Actions: `CI.yml` for `Pkg.test()` (Linux + macOS, Julia stable + LTS) + `Documentation.yml` for docs build/deploy.
- Confirms the full skeleton compiles + deploys to `gh-pages` before content writing.

### Phase 13b — Reference (~2–3 days; revised upward from ~1–2 because of stronger docstring policy)
- Cleanest quadrant in *structure* (lifts directly from source docstrings) but largest in *work* under the locked policy: every public function gets a complete docstring + at least one doctest; functions with multiple kwargs / use cases get more.
- Public/private boundary decisions enacted (un-export internals per Q2 lock — `enumStr`, `readStructenumout`, etc. move to `Enumlib.LegacyImport.foo(...)` with deprecation warnings).
- Add `@docs` / `@autodocs` blocks per reference page.
- Doctest fixes + additions as needed.

### Phase 13c — How-to guides (~2 days)
- Each how-to is a small, focused, runnable recipe.
- The 10 pages can be written largely independently; mining `test/test_*.jl` provides realistic examples for several.

### Phase 13d — Tutorials (~1 day)
- Three pages, narrowly scoped. **The DFT-training-database tutorial is load-bearing for v0.2.0** — it's the user-onboarding artifact for the first real application.

### Phase 13e — Explanation (~2–3 days)
- Most expensive in writing time but most valuable for serious users.
- Heavy lift from existing prose in `research.md` / chunk-by-chunk designs, but careful trimming of internal-narrative tone.

### Phase 13f — Polish + cross-linking (~½ day)
- Add cross-references throughout.
- Landing-page polish.
- Search-engine sitemap, badge in the README pointing at the docs URL.

**Total: ~6–9 days of concentrated work across 6 stages**, each with its own review pass per the working agreement. Phase 13a should land first as a standalone commit so the deployment pipeline is verified before content investment.

---

## 7. Open questions — all resolved (2026-05-08)

1. **Stage count.** ✅ **Locked: 6 stages (13.0–13f).** Small bites + frequent review is the principle.

2. **Public/private boundary.** ✅ **Locked: my lean.** Legacy Fortran-format I/O (`enumStr`, `readStructenumout`, `readEnergies`, `readStrIn`) un-exports and moves to `Enumlib.LegacyImport.foo(...)` with deprecation warnings on call. Kept around for one v0.2 minor release; full removal scheduled for v0.3. Same treatment for any other borderline export symbols identified during the §5.4 audit.

3. **Docs theme / styling.** ✅ **Locked: my lean.** Default Documenter HTML for v0.2.0. `DocumenterCitations` evaluated only if explanation pages benefit (likely v0.2.x polish, not v0.2.0 blocker).

4. **AFLOW-style validation corpus.** ✅ **Locked: yes, build over time.** Not a docs-stage gate; queued as standing v0.2-polish work. As we ship Phase 11 POSCAR I/O, accumulate a corpus of `(parent, sites, supercells, concentration, expected count)` tuples cross-validated against Fortran enumlib output for canonical cases (Ag-Pt 15:17 cubic 379,926 is the first; FCC binary at chunk-5/6 sizes are next; expand as collaborator workflows surface new use cases).

5. **Visuals.** ✅ **Locked: take all from the beginning.** All five candidate diagrams in scope from Phase 13e onward:
   - Mermaid flowchart of `:auto` dispatch decision tree.
   - Morgan 2017 Fig. 1 (9-atom worked example).
   - Mermaid flowchart of the 4-algorithm pipeline.
   - Diagram of the multinomial mixed-radix hash.
   - "What does cubic 2×2×2 mean" picture for the canonical Ag-Pt tutorial.

   **Plus** a standing watch during writing: when a passage in any quadrant would benefit from an illustration that isn't on the list above, surface it as a candidate before finalizing the page.

---

## 8. Out of scope for this doc plan

- Interactive in-browser examples (Pluto, JuliaHub).
- Localization. English-only.
- Reference cross-linking with Spacey.jl / MinkowskiReduction.jl docs (could add later via Documenter `inventory` or external-references).
- Per-tag versions. `stable` only (matching Spacey).

---

## 9. References / further reading

- Daniele Procida, *[Diátaxis](https://diataxis.fr/)*. Primary framework, full doc-philosophy site.
- *[Diátaxis compass](https://diataxis.fr/compass/)*. Action-vs-cognition × acquisition-vs-application decision rule.
- *[Write the Docs Documentation Principles](https://www.writethedocs.org/guide/writing/docs-principles/)*. Quality-of-writing guidance complementary to Diátaxis.
- *[Documenter.jl Guide](https://documenter.juliadocs.org/stable/man/guide/)*. Julia ecosystem standard.
- *[Julia Manual: Documentation](https://docs.julialang.org/en/v1/manual/documentation/)*. Docstring conventions and the `@doc` macro.
- *[Spacey.jl docs](https://glwhart.github.io/Spacey.jl/)* — the sibling package this plan models on.
- *[Spacey.jl `documentation_plan.md`](https://github.com/glwhart/Spacey.jl/blob/main/documentation_plan.md)* — the plan-document this plan models on.
- *[MinkowskiReduction.jl docs](https://glwhart.github.io/MinkowskiReduction.jl/)* — sibling package; Diátaxis-structured docs already shipped.
- Hart, Forcade, *Algorithm for generating derivative structures*, Phys. Rev. B 77, 224115 (2008).
- Hart, Nelson, Forcade, *Generating derivative structures at a fixed concentration*, Comp. Mater. Sci. 59, 101 (2012).
- Morgan, Hart, Forcade, *Generating derivative superstructures for systems with high configurational freedom*, Comp. Mater. Sci. 136, 144 (2017).
- Rosenbrock, Morgan, Hart, Curtarolo, Forcade, *Numerical algorithm for Pólya enumeration theorem*, ACM J. Exp. Algorithmics 21, 1.11 (2016).

---

## 10. Status

**Plan only — signed off 2026-05-08.** No documentation files have been written or modified by this proposal. The current `docs/` tree does not exist (Enumlib has never had Documenter.jl docs).

§7 open questions all resolved 2026-05-08 (see locks above). Stronger docstring policy (every function gets a docstring + ≥1 doctest; err toward more) folded into §2 / §5.4 / §6 Phase 13b estimate.

Next step: Phase 13 only starts after Phase 11 (POSCAR + DFT/MLIP roundtrip) ships, per the v0.2.0 priority order locked 2026-05-08 (`v0.2-plan.md`).
