# Chunk 13b.4 — Reference quadrant `@docs` blocks + `checkdocs = :exports` raise (design)

Pre-implementation design doc. Edit any section directly; I'll sweep `git diff` for your changes when you're done. This is the final 13b sub-chunk.

**Design references:** `docs/notes/documentation_plan.md` §3.4, §5.4 (locked 2026-05-08); `docs/notes/chunk13b-design.md` §3 (sub-chunk split), §4 (reference-page → symbol mapping), §6 (`@docs` per page, Q13 lock); `docs/notes/chunk13b2-design.md` and `chunk13b3-design.md` (the docstring/doctest content this chunk surfaces).

**Goal of 13b.4.** Make the reference quadrant render. After 13b.4:
- Every public symbol shows its docstring on its assigned reference page.
- `julia --project=docs docs/make.jl` builds with `checkdocs = :exports` and no warnings.
- The reference quadrant is publication-ready; tutorials + how-to + explanation content (13c–13e) can begin without further reference-side work.

13b.2 and 13b.3 produced the docstring + doctest content; this chunk routes it onto the 7 reference pages and tightens the build to fail on undocumented exports.

---

## 1. Current state

- **7 placeholder pages** in `docs/src/reference/`: index, parent-and-sites, supercells, concentrations, enumerate-and-count, cost-estimator, polya, poscar-io. Each is currently ~10 lines: a one-line intro + Phase-13a placeholder warning admonition.
- **`checkdocs = :none`** in `docs/make.jl` line 20 (set explicitly with a comment pointing at this chunk to raise it).
- **Every public export already has a docstring** post-13b.2/13b.3. Coverage is 100% across `src/types/`, `src/algorithms/`, `src/io/`, `src/enumerate.jl`, and `src/Enumlib.jl`.
- **Doctests already pass** under `doctest(Enumlib)` (verified end of 13b.3).

---

## 2. Scope & exclusions

**In scope:**

- All 7 pages in `docs/src/reference/`: replace the Phase-13a placeholder warnings with `@docs` blocks per the chunk13b-design §4 mapping.
- `docs/make.jl`: raise `checkdocs = :none` → `:exports`.
- (If stragglers surface) any missing-docstring fixes the `:exports` check exposes.

**Out of scope:**

- Tutorials (13d), How-to (13c), Explanation (13e).
- Index landing page changes (`docs/src/index.md` is stable from 13a.1 / 13b.2's double-space fix).
- Doctest content changes — 13b.2 / 13b.3 already locked the doctests.
- Removing or renaming any exported symbols — `checkdocs = :exports` checks the *current* export list against what's documented; mismatches are fixed by adding docstrings, not by changing exports.

---

## 3. Approach: per-page `@docs` population

Per chunk13b-design Q13 lock: `@docs` per page (manual symbol listing), not `@autodocs` (auto-scan with `Pages = [...]` filter). Spacey uses this pattern. Order within each block matches the chunk13b-design §4 mapping — author-chosen, not alphabetical — so related symbols (constructors, accessors) sit together.

**Per-page `@docs` content (proposed; each is roughly 5–10 symbols):**

### `reference/parent-and-sites.md`
```
@docs
SymmetryOp
ParentLattice
basis
dset
space_group
ndset
n_nonzero_translations
lattice_rotations
Site
Sites
is_active
is_inactive
equate!
canonical
active_canonical_sites
n_active
n_canonical
n_effective
```

### `reference/supercells.md`
```
@docs
HNF
Supercell
volume
SupercellSelection
VolumeRange
RadiusBound
ExplicitHNFs
enumerate_hnfs
avg_cell_radius
```

### `reference/concentrations.md`
```
@docs
Concentration
concentration_ratio
concentration_count
ConcentrationRange
n_species
multiplicities
concentrations_in_range
multinomial_count
multinomial_hash
multinomial_unhash
```

### `reference/enumerate-and-count.md`
```
@docs
Base.enumerate(::ParentLattice, ::Sites)
Enumeration
EnumeratedStructure
to_labeling
default_memory_budget
count_inequivalent
InequivalentCount
EmptyEnumerationError
PartitionExplosionError
```

### `reference/cost-estimator.md`
```
@docs
estimate_cost
EnumerationCostEstimate
EnumerationTooLargeError
format_bytes
```

### `reference/polya.md`
```
@docs
Enumlib.Polya
Enumlib.Polya.polya_count
Enumlib.Polya.cycle_structure
Enumlib.Polya.aperiodic_orbit_count
```

### `reference/poscar-io.md`
```
@docs
to_poscar
write_enumeration_archive
read_results
attach_results
```

**Index page (`reference/index.md`):** keep the existing navigation list (links to the 7 pages); add an `@index` block at the bottom so the page also acts as a typeable function/type catalog. Spacey precedent: yes, `@index` on the reference index.

---

## 4. Sub-chunk split

Single commit. ~70 lines of markdown delta across the 7 reference pages + 1 line change in `make.jl`. The work is mechanical; review surface is small.

**Q1 (single commit).** My lean: yes, like 13b.2 and 13b.3. Confirm.
Single commit

---

## 5. Open questions

**Q2 (page intro text).** Each placeholder has a one-line intro + the Phase-13a warning admonition. Options for the final shape:

(a) **Replace placeholder entirely with `@docs` block only** — clean, austere, matches Documenter convention for pure reference pages.
(b) **Keep the intro line + add `@docs` block** — gentle context for readers landing on the page from a link.
(c) **Replace placeholder, add a 1-paragraph intro, then `@docs` block** — slightly more guidance.

My lean: **(b)** — one-line intro is enough; readers know "this page is the API for X" without us explaining. The intro line in each placeholder is already good ("Public API for `to_poscar`, `write_enumeration_archive`, ..."). Drop the Phase-13a admonition, keep the intro line, add the `@docs` block.

Confirm or override.
Let's do (b)

**Q3 (Polya submodule injection).** Inside the polya page, the proposed block is:
```
@docs
Enumlib.Polya
Enumlib.Polya.polya_count
Enumlib.Polya.cycle_structure
Enumlib.Polya.aperiodic_orbit_count
```

The first line (`Enumlib.Polya`) injects the **module-level docstring** (added in 13b.3). The next three inject the function docstrings.

Alternative: `Enumlib.Polya` alone (relying on `@autodocs` semantics where module = all exports), but we said `@docs` per page in Q13 lock. My lean: list explicitly. Confirm.
list explicitly

**Q4 (`Base.enumerate` method-specific docstring injection).** Julia method dispatch lets `Base.enumerate` mean different things in different contexts (over collections vs our extension). Documenter's `@docs Base.enumerate` would match all methods — likely undesirable.

Three syntax options:
(a) `Base.enumerate(::ParentLattice, ::Sites)` — exact signature dispatch.
(b) `Base.enumerate(::Enumlib.ParentLattice, ::Enumlib.Sites)` — fully qualified.
(c) `Enumlib.enumerate` — relies on `Enumlib.enumerate` being a function-name binding; might not work for `Base.enumerate` extensions.

My lean: **(a)** — Spacey uses this pattern for its `Base.show` extension docstrings. Confirm or adjust.
(a)

**Q5 (`@index` block on reference/index.md).** The `@index` block produces a flat sorted list of every documented symbol with a link. Spacey has one on its reference index. Useful for users hunting by name.

My lean: yes, add it. Limit the scope with `Pages = ["parent-and-sites.md", "supercells.md", ...]` so it covers reference but not tutorials/how-to/explanation.

Confirm.
Add it.

**Q6 (`checkdocs = :exports` straggler risk).** The audit in 13b.2 / 13b.3 confirmed 100% docstring coverage of exports. But `checkdocs = :exports` will also catch:

- Exports whose docstring references a non-existent symbol (`[`foo`](@ref)` where `foo` doesn't exist).
- Exports whose docstring has malformed Documenter markup.
- Methods that aren't matched by any `@docs` block (a method shadowed by another file's docstring etc.).

If a straggler surfaces, the fix is mechanical (add the docstring, fix the cross-ref) and lands in the same commit. My lean: **proceed and fix in-place**; if a straggler is structural (requires re-thinking the export surface), surface it back to you before fixing.

Confirm or override.
Confirm

**Q7 (visual: function vs type ordering within a page).** Each `@docs` block renders symbols in the order listed. The chunk13b-design §4 mapping orders by *topic group* (types first, then constructors, then accessors, then related functions). E.g., `parent-and-sites.md` is: `SymmetryOp`, `ParentLattice`, then the parent accessors, then `Site`, `Sites`, then the site accessors and equivalence helpers.

Spacey's pattern: types first (uppercase), then functions (lowercase). My §4 order roughly follows this with some interleaving (e.g., `basis`/`dset` after `ParentLattice` but before `Site`).

Confirm the proposed order, or want a strict types-then-functions sort?
proposed order is good

**Q8 (intro tone — see-also links).** Should each page's intro line carry "see also" cross-links to the relevant explanation pages (e.g., `cost-estimator.md` linking to `explanation/dispatch-and-cost-gate.md`)? Explanation content isn't written yet (13e); the links would be dangling until then.

My lean: **skip cross-links in 13b.4** — they break checkdocs's CrossReferences pass when targets don't yet exist. Add them in 13f (polish/cross-linking pass) once tutorials/how-to/explanation are written. Confirm.
Add them in 13f

---

## 6. Out of scope for chunk 13b.4

- Tutorials, how-to, explanation content (13c–13e).
- Polish pass / cross-linking between quadrants (13f).
- Theme / styling (locked: default Documenter HTML for v0.2.0 per documentation_plan §7 Q3).
- `DocumenterCitations` — v0.2.x polish, not v0.2.0.

---

## 7. Verification at sign-off

- `julia --project=docs docs/make.jl` builds with `checkdocs = :exports` and zero warnings.
- `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` still passes (no regression).
- `Pkg.test()` (via direct include workaround): 1644 tests still pass.
- Spot-check 3 rendered HTML pages — parent-and-sites, polya, poscar-io — confirm `@docs` blocks render with full docstring + jldoctest output.
- `git diff` of `docs/src/reference/*.md` shows only `@docs`-block additions and placeholder-warning removals; no source code changes outside docs/.

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass. Same flow as 13b.2 / 13b.3.)

---

## 9. Summary

(Filled after sign-off.)
