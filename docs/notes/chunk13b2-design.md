# Chunk 13b.2 — Type-catalog docstring sweep + doctests (design)

Pre-implementation design doc. Edit any section directly — wording, restructuring, code, prose; I'll sweep `git diff` for your changes when you're done.

**Design references:** `docs/notes/documentation_plan.md` §3.4, §5.4 (locked 2026-05-08); `docs/notes/chunk13b-design.md` §3 (sub-chunk split), §4 (reference-page → symbol mapping), §5 (doctest strategy, Q11 lock), §6 (`@docs` vs `@autodocs`, Q13 lock).

**Goal of 13b.2.** Bring the type-catalog public surface up to the locked documentation policy: every public function has a docstring + ≥1 doctest; multi-kwarg / multi-use-case functions get more (Q11 lock: 4 on `enumerate`, 3 on `count_inequivalent`, 1 on most others). After 13b.2, the reference pages "parent-and-sites", "supercells", "concentrations", "enumerate-and-count", and "cost-estimator" can be populated with `@docs` blocks (in 13b.4) and the docstrings they inject will satisfy `checkdocs = :exports`.

Algorithms (`src/algorithms/*.jl`) and POSCAR I/O (`src/io/poscar.jl`) are 13b.3 territory and excluded here.

---

## 1. Current state, by the numbers (audit 2026-05-13)

Scope: every symbol exported from `src/Enumlib.jl` whose definition lives in `src/types/*.jl`, plus the four headline entries in `src/enumerate.jl` (`Base.enumerate`, `count_inequivalent`, `estimate_cost`, `default_memory_budget`).

- **45 public symbols total** (19 types + 26 functions/accessors/constructors).
- **39/45 have docstrings (87%).** Six gaps:
  - `basis`, `dset`, `space_group`, `ndset` in `parent_lattice.jl` (one-line accessors, zero docstring)
  - `n_nonzero_translations` in `parent_lattice.jl` (inline comment but no docstring block)
  - `n_species(::ConcentrationRange)` in `concentration.jl` (has docstring for the `Concentration` method; range method silently undocumented)
- **Doctest coverage: ~3/26 functions have any example block; ~0/26 use `jldoctest`.** Eleven functions have *prose* example blocks (e.g., `equate!`, `volume`, `multiplicities`, `concentration_ratio`, `concentration_count`, `format_bytes`, `to_labeling`); these need conversion. The headline `Base.enumerate` / `count_inequivalent` / `estimate_cost` have no examples at all.
- **Type docstrings are uniformly strong.** All 19 types have rich docstrings (2 terse, 6 medium, 11 rich); no rewrites needed, just doctests added where the constructor + accessor pattern is reproducible.
- **No stale `Concentration_count` / `Concentration_ratio` references** in live docstrings (the 13b.1 rename was clean; only internal scrapbook docs still have the old names, per chunk13b1-review item F).

The full per-symbol audit table is in the agent run that produced these numbers — not vendored here to keep this pad focused on the *plan*. I'll surface specific symbols only where there's a design decision attached.

---

## 2. Scope & exclusions

**In scope (Reference pages: parent-and-sites, supercells, concentrations, enumerate-and-count, cost-estimator):**

- `src/types/symmetry_op.jl` — `SymmetryOp`, `lattice_rotations`
- `src/types/parent_lattice.jl` — `ParentLattice`, `basis`, `dset`, `space_group`, `ndset`, `n_nonzero_translations`
- `src/types/site.jl` — `Site`, `is_active`, `is_inactive`
- `src/types/sites.jl` — `Sites`, `equate!`, `canonical`, `active_canonical_sites`, `n_active`, `n_canonical`, `n_effective`
- `src/types/hnf.jl` — `HNF`, `volume`, `getSymInequivHNFs` (the new-API wrapper)
- `src/types/supercell.jl` — `Supercell`
- `src/types/supercell_selection.jl` — `SupercellSelection`, `VolumeRange`, `RadiusBound`, `ExplicitHNFs`, `enumerate_hnfs`
- `src/types/concentration.jl` — `Concentration`, `concentration_ratio`, `concentration_count`, `ConcentrationRange`, `n_species` (both methods), `multiplicities`, `concentrations_in_range`
- `src/types/enumeration.jl` — `Enumeration`, `EnumeratedStructure`, `to_labeling`
- `src/types/inequivalent_count.jl` — `InequivalentCount`
- `src/types/cost_estimate.jl` — `EnumerationCostEstimate`, `format_bytes`
- `src/types/errors.jl` — `EmptyEnumerationError`, `PartitionExplosionError`, `EnumerationTooLargeError`
- `src/enumerate.jl` (headlines only) — `Base.enumerate(::ParentLattice, ::Sites; …)`, `count_inequivalent`, `estimate_cost`, `default_memory_budget`. Also `avg_cell_radius` — lives in `src/Enumlib.jl` proper (not `src/types/`), but the reference page "supercells" includes it.

**Out of scope (defer to 13b.3):**

- `src/algorithms/*.jl` — Pólya submodule, multinomial primitives, recursive-stabilizer driver.
- `src/io/poscar.jl` — `to_poscar`, `write_enumeration_archive`, `read_results`, `attach_results`.

**Out of scope entirely:**

- Reference page `@docs` blocks (those are 13b.4).
- `checkdocs = :exports` raise (13b.4).
- Internal (un-exported) symbols — they don't go through `checkdocs`, and the v0.2-plan working agreement keeps internal-name renames as non-breaking refactors that can land separately.

---

## 3. Approach: three categories of work

**(a) Fill the six gaps.** New docstrings for `basis`, `dset`, `space_group`, `ndset`, `n_nonzero_translations`, and `n_species(::ConcentrationRange)`. Each gets a minimal block (1-sentence summary + parameters/returns + 1 jldoctest where output is small and stable).

**(b) Convert prose-example docstrings to `jldoctest`.** Eleven candidates (`equate!`, `canonical`, `volume`, `multiplicities`, `concentration_ratio`, `concentration_count`, `to_labeling`, `format_bytes`, `enumerate_hnfs`, `lattice_rotations`, `active_canonical_sites`). For each: lift the existing prose example into a `jldoctest` block and verify it runs. Where the prose example was abstract (no concrete numbers), pick a small reproducible case (e.g., simple cubic / FCC at n ≤ 4 / a 4-element `Concentration`).

**(c) Add doctests to the four headline entries.** Per chunk13b-design Q11 lock:

- **`Base.enumerate(parent, sites; …)`: 4 doctests.** Locked cases:
  1. No concentration: small FCC binary at `VolumeRange(2:2)` — verifies the basic flow returns an `Enumeration` with the right `length`.
  2. Fixed concentration: `concentration_count([2, 2]; n_total = 4)` at FCC, showing the count-mode pathway.
  3. Concentration range: `ConcentrationRange(...)` showing the partition sweep on a tiny case.
  4. Explicit algorithm: `algorithm = :recursive_stabilizer` for a case where it matters (or `:exhaustive` for the no-conc branch).

- **`count_inequivalent`: 3 doctests.**
  1. Basic unrestricted count — FCC binary at `VolumeRange(2:2)`, returns a small `BigInt`.
  2. With `include_superperiodic = true` — same small case, showing the larger count.
  3. With `breakdown = true` — returns `InequivalentCount{D}` and shows its `by_volume` / `by_hnf` fields.

- **`estimate_cost`: 1 doctest.** Small case; check `total_count` matches `count_inequivalent` and that `chosen_algorithm = :exhaustive` (or whatever `:auto` resolves to).

- **`default_memory_budget`: 0 doctests** — machine-dependent (`Sys.total_memory()` varies). Keep the existing prose docstring; mark it explicitly as "not doctested" with a one-line note.

**Doctest stability defenses (per Q12 lock):**

- Use `filter` regex aggressively for `BigInt` output (`r"BigInt\(\d+\)" => "BigInt(N)"`) and any printed timestamps. `count_inequivalent` returns `BigInt` even at small counts; the display can be `9` or `BigInt(9)` depending on context. Pick a stable display and lock it.
- Type pretty-prints (`Base.show`) for `ParentLattice`, `Sites`, `Enumeration`, etc. can shift between Julia versions if `show` ever changes. For the headline doctests, anchor on *fields* / *accessor calls* rather than the full pretty-printed struct. E.g., `length(e)` and `e[1] |> to_labeling` are stable; `e` standalone may not be.
- Add `using Enumlib, LinearAlgebra` to the `DocTestSetup` (already in `docs/make.jl` from 13a). Doctests inside docstrings don't need explicit `using` lines.

---

## 4. Sub-chunk split

13b.2 is bounded enough to land as a *single* commit. Rough deltas:

- 6 new docstring blocks (gaps): ~30 lines source delta.
- ~11 prose → jldoctest conversions: ~55 lines source delta (jldoctest blocks are slightly larger than prose).
- 8 new headline doctests (4 on enumerate + 3 on count_inequivalent + 1 on estimate_cost): ~80 lines source delta.
- Total: ~150–180 lines of source delta, all in docstring bodies. No behavior change.

No tests added/removed in `test/`. The implicit "test" is `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` passing — which I'll run at sign-off.

**Q1 (sub-chunk split).** Land as one commit, or split (e.g., 13b.2a = the 6 gaps + prose conversions; 13b.2b = the 8 headline doctests)? My lean: one commit. The work is mechanical and the per-file review surface is small (just docstring deltas). Splitting doubles the review-pad overhead without buying a meaningful safety margin.

one commit

---

## 5. Open questions

**Q2 (accessor docstrings: minimal or expanded?).** The five missing accessors (`basis`, `dset`, `space_group`, `ndset`, `n_nonzero_translations`) all return a field directly. Minimal pattern:

```julia
"""
    basis(p::ParentLattice{D}) -> Matrix{Float64}

Return the basis matrix of the parent lattice. Columns are basis vectors in
Cartesian coordinates; the matrix is `D×D`.

# Examples
```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> basis(p)
3×3 Matrix{Float64}:
 0.0  0.5  0.5
 0.5  0.0  0.5
 0.5  0.5  0.0
```

Expanded would also discuss when the basis is non-trivial (Bravais shift, etc.), but that's already in the `ParentLattice` docstring. My lean: minimal accessor blocks — point at `ParentLattice` for the deeper context. Confirm or expand.

Confirm

**Q3 (`n_nonzero_translations`).** This is the lone non-trivial parent_lattice accessor; it counts symmetry ops with non-zero translation parts (distinguishes symmorphic from non-symmorphic groups). Has a `tol` kwarg. My lean: medium docstring + 1 jldoctest using a symmorphic case (e.g., simple cubic, expect 0) and one non-symmorphic case (e.g., HCP, expect 12) in *one* doctest block. Confirm, or split into two blocks?

one block

**Q4 (`format_bytes` examples).** The existing docstring has 6 prose examples (0 B, 1023 B, 1.00 KiB, 1.00 MiB, 1.00 GiB, 1.00 TiB). Convert to a *single* `jldoctest` block with 6 `julia>` lines (less repetition), or 6 separate blocks (each runnable in isolation)? My lean: single block — Documenter treats `julia>` lines in one block as sequential REPL inputs, which matches the user's mental model.

single block 

**Q5 (`Base.enumerate` doctest case choice).** The 4 locked cases need concrete examples small enough to display. My proposed cases:

1. *No concentration:* FCC primitive, `Sites([Site([0.0,0.0,0.0], [0,1])])`, `supercells = VolumeRange(2:2)`. Returns 2 structures. Show `length(e)` and `e[1] |> to_labeling`.
2. *Fixed concentration:* same FCC, `concentration = concentration_count([2,2]; n_total=4)`, `supercells = ExplicitHNFs([single HNF])`. Returns 5 structures (chunk-6 reference).
3. *Concentration range:* same FCC at n=4, range from (0,4) to (4,0) — 5 partitions. Show `length(e)` only (full output too large for line-by-line).

That's not a great example because it ends up doing all concentrations. It's equivalent to a "no concentration" enumeration. Not an illustrative example.

4. *Explicit algorithm:* same FCC n=4 case with `algorithm = :recursive_stabilizer`; assert count matches case 2.

Concern: case 3 might churn through the partition gate; need to pick a tight range. My lean: ranges from (1,3) to (3,1) — 3 partitions, no gate concern. Confirm.

Maybe this example is too small. Pick a larger size, but restrict the concentration to 1 or 2 A atoms only?

**Q5-REVISED.** Taking your "too small to be illustrative" pushback. Constraint: doctests run on every `make.jl` build, so each case has to finish in well under a second. From the v0.2-plan benchmark table, FCC binary at n=12 unrestricted runs in ~1.75s (too slow), but at restricted concentrations the work shrinks linearly with the multinomial count. n=8 4:4 (94 structures) is the largest chunk-6 reference test that runs fast in CI. Revised case picks:

1. *No concentration:* FCC binary at `VolumeRange(4:4)` — **19 structures** total across 7 HNFs (chunk-5 reference). Big enough that the count isn't obvious by hand but still small enough that the user can mentally trace it back to FCC's 7 inequivalent HNFs at n=4. Show `length(e) == 19`, then `e[1] |> to_labeling` to display one labeling.
2. *Fixed concentration:* FCC binary at `VolumeRange(8:8)` with `concentration = concentration_count([4, 4]; n_total = 8)` — **94 structures** (chunk-6 locked reference). Illustrates that fixed-concentration enumeration is a *focused subset* of the unrestricted count; concrete number a reader will recognize from any HF 2012 reading.
3. *Concentration range:* FCC binary at `VolumeRange(12:12)` with `ConcentrationRange` restricting the first species to **1..2 atoms only** — 2 partitions: (1,11) and (2,10). Both multinomial counts are small (≪ 7140), so the total enumeration finishes fast. Demonstrates the actual *value* of `ConcentrationRange` — restricting to a sparse / dilute regime where unrestricted enumeration would be wasteful.
4. *Explicit algorithm:* same case as #2 (FCC n=8, 4:4) but with `algorithm = :recursive_stabilizer`; doctest asserts `length(e) == 94` to demonstrate the algorithm-equivalence guarantee.

Q5-REVISED follow-up: confirm these four picks, or adjust further?

Good

**Q6 (`count_inequivalent` doctest case choice).** Proposed:

1. *Basic:* FCC binary at `VolumeRange(2:2)`, returns a small `BigInt`. The exact number depends on the test corpus; n=2 should be tractable.

Too small to be interesting I think. We're only counting here, not listing all configs. Maybe do fcc n=12:12?

2. *With super-periodic:* same case + `include_superperiodic = true`.
3. *Breakdown:* same case + `breakdown = true` returns `InequivalentCount{3}`; show `count.by_volume` (a Dict).

Concern: `by_volume` is a `Dict{Int, BigInt}`. Doctest output for `Dict` is order-dependent unless we filter. My lean: use `filter = r"Dict\{Int.+BigInt\}" => "Dict{Int, BigInt}"` and then literal-compare; or sort the keys ourselves in the doctest. Confirm approach.

Confirm

**Q6-REVISED.** Taking your "do FCC n=12:12" direction. Since `count_inequivalent` uses Pólya math (no enumeration cost), n=12 is fast. Revised cases:

1. *Basic:* FCC binary at `VolumeRange(12:12)` — returns `BigInt(7140)` (chunk-6 locked reference). Big enough to be a number the user *couldn't* have guessed; small enough to recognize as the canonical HF-2008 n=12 binary count.
2. *With super-periodic:* same case + `include_superperiodic = true` — returns `BigInt(7885)` (chunk-6.2 locked reference). The 745-structure delta illustrates the policy in action.
3. *Breakdown:* `count_inequivalent(parent, sites; supercells = VolumeRange(8:12), breakdown = true)` — returns `InequivalentCount{3}`; show `count.total`, then `count.by_volume[8]`, `count.by_volume[12]` individually (avoid the Dict-order issue by indexing). The range exercises the breakdown across multiple volumes, which is the *point* of the breakdown kwarg.

Q6-REVISED follow-up: confirm these three picks, or adjust further?

Confirmed

**Q7 (`estimate_cost` doctest).** Proposed: same FCC binary n=2 case; show `est.total_count` (matches count_inequivalent) and `est.chosen_algorithm` (e.g., `:exhaustive`). `peak_memory_bytes` is mildly platform-dependent (we predict from constants but the constants are exact). My lean: show `est.total_count` and `est.chosen_algorithm` only; *do not* assert on `est.peak_memory_bytes` in the doctest (it's tested in `test/test_cost_estimate.jl`). Confirm.

This case is too small to be interesting or illustrative

**Q7-REVISED.** Pivot to a case that exercises the *gate* mechanism, not just the values. `estimate_cost`'s value-add isn't "report the count" (that's `count_inequivalent`'s job) — it's "predict memory and refuse to run when it's too large." Two candidate shapes:

(a) *Show the prediction agrees with reality.* FCC binary at `VolumeRange(12:12)`: show `est.total_count == BigInt(7140)`, `est.chosen_algorithm == :exhaustive`. Same numbers as Q6 case 1; doctest is a tiny sanity check.

(b) *Show the gate firing.* FCC binary at a deliberately too-large case (e.g., `VolumeRange(20:20)` unrestricted — predicted memory in the GiB range), called with `memory_budget = 1`; doctest catches the `EnumerationTooLargeError` and shows the error's `mitigations` field or `showerror` output. Demonstrates the *purpose* of the function in one example.

My lean: **(b)**, because it captures the function's reason-for-being. (a) is just a count duplicate.

Q7-REVISED follow-up: confirm (b), choose (a), or want both (one doctest each)?

Go with (b)

**Q8 (`Sites` doctest).** The `Sites` type docstring is rich (16 lines) and explains the dual constructor + Union-Find. Adding a doctest requires a worked example showing both constructor variants. My lean: 1 jldoctest showing the upfront-partition variant (3 sites, partition into 2 classes), with `n_active`, `n_canonical`, `canonical(s, 3)` results. Skip showing `equate!` here (it has its own docstring). Confirm.

Confirm

**Q9 (`Enumeration` / `EnumeratedStructure`).** These are output types — instances exist only as the return value of `enumerate(...)`. Doctest pattern would be `e = enumerate(...); e[1]` to show one structure. My lean: skip standalone doctests on the type docstrings; rely on `Base.enumerate`'s doctests (which exercise both) to populate the user's mental model. Confirm, or do you want each type to carry its own doctest (single-line `enumerate(...)[1]` style)?

Agree

**Q10 (`avg_cell_radius`).** Lives in `src/Enumlib.jl`, not `src/types/`, but the "supercells" reference page includes it. In scope for 13b.2? My lean: yes, since it's the only `RadiusBound`-related public function and 13b.2 covers all of "supercells". Confirm.

Confirm 

**Q11 (CI step for doctests).** Chunk 13b-design Q12 locked: "add a CI step that runs `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` so drift is caught immediately." That step lives in `.github/workflows/Documentation.yml`. Land in 13b.2 (alongside the new doctests), in 13b.4 (alongside the `checkdocs` raise), or as a separate tiny chunk? My lean: 13b.2 — the doctests being added now are exactly what the CI step needs to verify, and adding doctests without CI drift-catching is the "every page is potentially wrong by tomorrow" anti-pattern from documentation_plan §1.2.

Do this now

---

## 6. Out of scope for chunk 13b.2

- Anything in `src/algorithms/*.jl` (multinomial primitives, Pólya submodule, recursive-stabilizer driver) — those land in 13b.3.
- Anything in `src/io/poscar.jl` — also 13b.3.
- Reference page `@docs` blocks in `docs/src/reference/*.md` — that's 13b.4.
- Raising `checkdocs = :none → :exports` — that's 13b.4 (after 13b.3 finishes the algorithm-side docstrings).
- Internal (un-exported) symbol renames or rewrites — non-breaking, defer to a separate cleanup pass.
- Tutorial / how-to / explanation content — those are 13c–13e.

---

## 7. Verification at sign-off

- `Pkg.test()` passes: 1644+ tests (no test additions; no behavior change expected, but the test suite confirms doctest changes didn't accidentally break a docstring's surrounding code).
- `julia --project=docs docs/make.jl` builds clean: currently `checkdocs = :none` so missing-docstring warnings don't fire; doctest failures *do* fire on every build. Locally, every doctest must pass.
- `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` passes. New CI step on `Documentation.yml` per Q11.
- `git diff` of `src/types/*.jl` + `src/enumerate.jl` shows only docstring deltas (no executable-code change), with the exception of the six new docstring blocks.
- Spot-check rendered HTML for 2-3 of the touched pages — e.g., the `parent-and-sites.md` placeholder should still build (it has no `@docs` block yet, but doctest execution still happens during the build).

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass on this design pad. Same flow as 13b.)

---

## 9. Follow-up from in-source `#gh` notes (2026-05-13 review pass)

After the first implementation pass landed, you marked three `#gh` notes in `src/types/*.jl`. Two were directly actionable and are now applied:

- **`concentration.jl`** — `Concentration` type docstring rewritten with `[1//4, 3//4]` examples that distinguish the three constructors clearly (scale-free ratio vs anchored count). `concentration_ratio` doctest now uses `[2, 4]` (non-coprime) so the normalization step is visible; `concentration_count` doctest uses `[3, 9]; n_total = 12` to show the same `Concentration(1//4, 3//4)` reached from the anchored side.
- **`enumeration.jl`** — `to_labeling` now carries a second jldoctest: BCC binary at n=8 with 4:4 concentration, picking `e[7]` → `Int8[0, 0, 0, 0, 1, 1, 1, 1]`. Verified live; 94 structures total at this case.

The third `#gh` (in `cost_estimate.jl`) asked for **synonyms for "pre-flight gate"** with clarity over brevity. Candidates:

- (a) **"memory-budget gate"** — describes precisely what is gated (the `memory_budget` kwarg). Internally consistent with the existing kwarg name. My lean.
- (b) **"memory-budget guard"** — softer than "gate"; reads more like a safety feature than a process step.
- (c) **"size check"** — most colloquial; doesn't tie to the specific resource being measured.
- (d) **"cost-prediction guard"** — emphasizes that it's predictive, not just a hard cutoff.
- (e) **"resource-budget guard"** — generalizes "memory" since future versions might gate on walltime too (Phase 7 §7.9 Q2 deferred walltime estimation to v0.3).

I'd go with **(a) "memory-budget gate"** for v0.2.0 — it names the exact API and the exact intervention. If we add walltime estimation in v0.3, switch to (e) at that point.

Mark your pick (or write a fresh alternative) and I'll do a sweep on `cost_estimate.jl` and any other docstrings that use "pre-flight".

I think I like something like "enumeration resource check". I like "check" and I like something referring to size, memory, or required resources.

**Locked: "enumeration resource check"** (user's alternative — generalizes beyond just memory, uses "check" rather than "gate", and reads as a feature description rather than a process step). Applied across `src/enumerate.jl` (5 occurrences) + `src/types/cost_estimate.jl` (1) + `src/types/errors.jl` (2). The kwarg name `skip_preflight` was left alone — renaming would be a breaking API change. Algorithm-side files (`src/algorithms/multinomial.jl`, `src/algorithms/polya.jl`) still have "pre-flight" mentions — queued for the 13b.3 sweep to keep terminology consistent.
 
---

## 10. Summary

(Filled after sign-off.)
