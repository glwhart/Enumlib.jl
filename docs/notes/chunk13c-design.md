# Chunk 13c — How-to guides (design)

Pre-implementation design doc. Edit any section directly; I'll sweep `git diff` for your changes when you're done.

**Design references:** `docs/notes/documentation_plan.md` §3.3 (how-to scope, 10 pages); `docs/notes/v0.2-plan.md` Phase 13c; Diátaxis "how-to" definition (https://diataxis.fr/how-to-guides/). Reference work from 13b.2–13b.4 is the foundation — every how-to call resolves to a documented API surface, and doctest output can be cross-checked against the locked reference values.

**Goal of 13c.** Populate the 10 how-to guide placeholders with task-focused recipes. Each recipe: short, problem-driven, recipe-style ("I have X, I want Y, what calls do I make?"). After 13c, working users have a cookbook of "here's how to do the canonical operations" — orthogonal to the reference (which lists the API) and the explanation (which gives the rationale).

---

## 1. Current state

- **10 placeholder pages** in `docs/src/how-to/`: index, construct-a-parent-lattice, describe-substitution-sites, select-supercells, enumerate-at-fixed-concentration, sweep-concentration-ranges, pick-an-algorithm, count-without-enumerating, estimate-cost, handle-super-periodicity, write-poscars-for-dft.
- Each is currently ~10 lines: title + 1–2 line "what this page covers" intro + Phase-13a placeholder warning.
- One of the 10 (`enumerate-at-fixed-concentration.md`) was *partially* written during chunk 11 in passing — has some content already. Check that file before overwriting; merge or replace as appropriate.
- Reference quadrant from 13b.4 carries the canonical API surface; every how-to recipe will use a call documented there.

---

## 2. Diátaxis "how-to" defined

A how-to in Diátaxis is **task-oriented practical guidance**, distinct from:
- **Tutorial** — guided learning (13d). "Let me walk you through this from scratch."
- **Reference** — austere API description (13b). "Here are the parameters and return values."
- **Explanation** — discussion of the why and the math (13e). "Here's the rationale."

A how-to:
1. **Answers a problem the user has.** Title is "How do I X?" — explicit task framing.
2. **Assumes the user knows the basics.** Doesn't re-explain `ParentLattice` if a recipe uses one; links to the reference for full signatures and to the parent-lattice construct-recipe.
3. **Is a sequence.** Numbered steps with code, not prose-explanation.
4. **Produces a visible result.** The user runs the recipe and sees output they expect (which is why every recipe needs a `jldoctest` or at minimum a deterministic example).
5. **Is short.** Target ≤ 1 page (~50–150 lines of markdown).

The recipe template (proposed):
```markdown
# How do I X?

One-line task statement.

## Setup

(Any imports / data the user needs to follow along.)

## Steps

1. <Step description> — `code`.
2. <Step description> — `code`.

## Expected output

(Tied to the example; ideally as a `jldoctest` so it doesn't drift.)

## See also

- Reference: [link to relevant reference page].
- Explanation: [link to relevant explanation page]. *(Skipped for v0.2.0 since
  explanation pages don't exist yet — added in 13f.)*
```

---

## 3. Scope: the 10 how-to pages and their tasks

Per `documentation_plan.md` §3.3, the 10 pages cover the canonical questions a working scientist asks:

| # | Page | Task |
|---|------|------|
| 1 | `construct-a-parent-lattice.md` | "I have a primitive basis; how do I build a `ParentLattice`?" + the Bravais vs multilattice (HCP) cases + the singularity check. |
| 2 | `describe-substitution-sites.md` | "I have substitution sites with allowed labels and equivalencies; how do I describe them?" + active vs inactive + Union-Find equivalencies. |
| 3 | `select-supercells.md` | "Which `SupercellSelection` should I use?" + `VolumeRange` / `RadiusBound` / `ExplicitHNFs` patterns. |
| 4 | `enumerate-at-fixed-concentration.md` | "How do I enumerate at exactly X% A and Y% B?" + the three named constructors (canonical, ratio, count). |
| 5 | `sweep-concentration-ranges.md` | "How do I sweep across a range of concentrations?" + `ConcentrationRange` + the partition gate. |
| 6 | `pick-an-algorithm.md` | "Which algorithm is best for my case?" + `:auto` vs explicit + when each beats the others. |
| 7 | `count-without-enumerating.md` | "How many structures *would* I get?" — `count_inequivalent`, breakdown, super-periodicity policy. |
| 8 | `estimate-cost.md` | "Will this fit in memory?" — `estimate_cost`, `memory_budget`, the resource-check kwargs. |
| 9 | `handle-super-periodicity.md` | "When should I keep super-periodic structures?" + the `include_superperiodic` kwarg + the asymmetric-concentration trip-wire. |
| 10 | `write-poscars-for-dft.md` | Phase 11 workflow: `to_poscar`, `write_enumeration_archive`, the `energy_eV=` slot, read-back via `read_results`/`attach_results`. |

---

## 4. Approach: sub-chunk split

10 pages is too much for one review pad. Proposed sub-chunk split:

**13c.1 — Setup recipes (3 pages):** construct-a-parent-lattice, describe-substitution-sites, select-supercells.
- Foundation for everything else; user needs these before any enumeration.
- ~250 lines markdown delta.

**13c.2 — Concentration recipes (3 pages):** enumerate-at-fixed-concentration, sweep-concentration-ranges, count-without-enumerating.
- Concentration handling is the user's primary lever; three closely-related recipes that share examples.
- ~200 lines markdown delta.

**13c.3 — Algorithm-control recipes (2 pages):** pick-an-algorithm, estimate-cost.
- Power-user / advanced concerns; let users tune dispatch and memory budgets.
- ~150 lines markdown delta.

**13c.4 — Policy + I/O recipes (2 pages):** handle-super-periodicity, write-poscars-for-dft.
- Super-periodicity is a policy lock; POSCAR I/O is the v0.2.0 first-application workflow (load-bearing for DFT collaborators).
- ~250 lines markdown delta.

Each sub-chunk: separate review pad, single commit (matching the 13b sub-chunk cadence). ~4 review cycles total for 13c.

**Q1 (sub-chunk split).** My lean: 4 sub-chunks as drafted. Alternative: 3 sub-chunks (merge 13c.3 into either 13c.2 or 13c.4). Or 2 sub-chunks (basics + advanced). Or single chunk (push all 10 through one review cycle — would be heavy).

Push them all through at the same time. While I'm in "review mode" I'll just do them all. Seems easier.

---

## 5. Open questions

**Q2 (recipe template).** The template proposed in §2 has: title / one-line task / setup / numbered steps / expected output / see-also. Variations:

- (a) **As proposed.**
- (b) **Drop "See also" for v0.2.0** since explanation pages don't exist yet. Add in 13f.
- (c) **Add an "Output" section explicitly** distinct from the steps' inline output — useful when the steps' output is small but the headline result is the count / structure / file.

My lean: **(a) + (b) deferred** — keep "See also" with reference-quadrant links from the start (those exist), defer explanation cross-links to 13f.

Confirm or adjust.
Yes that's good

**Q3 (jldoctest density).** Each recipe should have ≥ 1 runnable jldoctest so the recipe doesn't drift. Two patterns:

- (a) **One big jldoctest per recipe** — entire recipe is one labeled block; subsequent `julia>` lines share state. Recipe reads like a REPL session.
- (b) **Multiple short jldoctest blocks** interleaved with prose — each step gets its own block; clearer step-by-step, more verbose.

My lean: **(a)** — matches the "recipe as a REPL session" mental model and is closer to what the user will actually run. Caveat: requires a recipe-wide label so blocks share state.

Confirm.
(a)

**Q4 (mining from test files).** `test/test_*.jl` contains many concrete cases (chunk-6 FCC binary 4:4=94, chunk-7 cyclic C_4 = 6, etc.). Should how-to recipes use these locked reference values for verifiability, or pick *fresher* examples tailored to the recipe's narrative?

My lean: **lock to reference values** where they fit the recipe — the chunk-5/6 references are already battle-tested and the doctest output is already known to be stable. Use fresh examples only when the locked refs don't match the recipe shape.

Confirm.
Yes

**Q5 (recipe length cap).** Documentation_plan §3.3 says "≤ 1 page." In rendered Documenter HTML that's roughly 50–150 lines of markdown. Some recipes (e.g., write-poscars-for-dft, which has 4 functions to thread together) may run longer.

My lean: target 50–150 lines, but **don't truncate the load-bearing 10th recipe** (POSCAR DFT workflow) if it needs more — it's the v0.2.0 first-application story per the documentation_plan. Confirm.
yes


**Q6 (cross-linking to the not-yet-written explanation pages).** Same situation as 13b.4 Q8 — explanation pages are 13e, not yet written. If a recipe wants to point at "see also: the auto-dispatch rationale on `explanation/dispatch-and-cost-gate.md`," that link will be dangling until 13e ships.

My lean: **skip explanation cross-links until 13f polish pass** — same as 13b.4 Q8. Include reference cross-links from the start (those exist). Confirm.

Put in the closs links now. Good for the proofreader, even if they are only stubs.

**Q7 (existing partial content on `enumerate-at-fixed-concentration.md`).** Chunk 11 wrote some content here. Read it first; preserve good prose, merge into the new recipe shape, or overwrite if it's stale relative to the post-13b.1 public API. Decide per-line during 13c.2 — surface anything non-trivial back to you before overwriting.

Confirm.
Yes

**Q8 (how-to index page).** `how-to/index.md` is currently a placeholder. It should become a navigable catalog: one-sentence summary per how-to, grouped by topic (basics / concentration / algorithms / policy+IO). Mirrors the reference/index pattern.

My lean: yes, build this during 13c.1 (alongside the first three how-tos). Confirm.
Yes


---

## 6. Out of scope for chunk 13c

- Tutorials (13d), Explanation (13e), Polish + cross-linking (13f).
- Reference quadrant changes — 13b.4 locked it; touch the source docstring only if a how-to surfaces a clarity bug.
- Adding new public API or new doctests in `src/` — 13c is pure docs/src/how-to/ work, no source changes expected (with the docstring-clarity-bug exception above).

---

## 7. Verification at sign-off (per sub-chunk)

- `julia --project=docs docs/make.jl` builds clean with `checkdocs = :exports`, doctest on, zero warnings.
- `doctest(Enumlib)` passes — including any new how-to jldoctest blocks.
- `git diff` of `docs/src/how-to/*.md` shows only how-to-page additions (and `how-to/index.md` updates in 13c.1).
- Spot-check rendered HTML for the new how-to pages.

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass.)

---

## 9. Summary

(Filled after sign-off on the whole 13c — likely after 13c.4 lands.)
