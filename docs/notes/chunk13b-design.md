# Chunk 13b — Reference quadrant + docstring audit (design)

Pre-implementation design doc. Edit any section directly — wording, restructuring, code, prose; I'll sweep `git diff` for your changes when you're done. No `#gh` markers needed (chunk 13a process change).

**Design references:** `docs/notes/documentation_plan.md` §3.4, §5.4 (locked 2026-05-08), §6 Phase 13b. The locked policy:

- Every public function gets a docstring (no exceptions).
- Every public function gets ≥1 doctest.
- Multiple kwargs / use cases / interesting edge behavior → multiple doctests.
- Err toward more, then ask whether to trim.
- Public/private boundary: un-export legacy Fortran-format I/O (`enumStr`, `readStructenumout`, `readEnergies`, `readStrIn`) into an `Enumlib.LegacyImport` submodule with deprecation warnings; keep around for one v0.2 minor release; full removal scheduled for v0.3. Same treatment for any other borderline export symbols identified during audit.

**Goal:** raise the documentation `checkdocs` from `:none` to `:exports` and have the Reference quadrant render cleanly with auto-injected docstrings — i.e., every public symbol carries enough docstring + doctest content that Documenter is happy. After 13b, the Reference site is read-once-and-trust authoritative, even though the four content-heavy quadrants (Tutorials / How-to / Explanation) are still placeholders.

This is the **largest content chunk** of Phase 13. Documentation plan estimated 2-3 days under the locked stronger policy. I want to break it across 4 sub-commits so review pressure stays manageable; see §3.

---

## 1. Current state, by the numbers

Public exports from `src/Enumlib.jl`: ~80 symbols. Roughly:

- **v0.2 type catalog** (chunks 1–8, 11): ~50 symbols across 16 source files in `src/types/`, `src/algorithms/`, `src/io/`. Coverage of docstrings is uneven but generally non-empty (audit pass needed; `git grep '"""' src/types src/algorithms src/io` shows ~100 docstring blocks).
- **Legacy lattice-coord API** (pre-chunk-5): ~25 symbols still exported from `src/Enumlib.jl`, `src/LatticeColoringEnumeration.jl`, etc. Mixed status — some are still load-bearing internally (`getPermG`, `getTransGroup`), some are subsumed by chunk-4/5 types (`getAllHNFs`), some are pure legacy (`enumStr`, `readStructenumout`).
- **Cluster utilities** (`isRotTransEquiv`, `isTransEquiv`, `canonClustOrder!`, etc.): leftover from earlier CE work; arguably do not belong in Enumlib at all and should migrate to JuCE.

The Reference quadrant has 7 pages (Phase 13a placeholders). Each one targets a coherent function group; mapping in §4.

---

## 2. Public/private boundary decisions to confirm

The documentation plan §5.4 listed candidates; this is where we make the final call. **Q1-Q6 below — please tag each `keep`, `unexport`, `legacy`, or `migrate` directly in the table. (`legacy` = move to `Enumlib.LegacyImport.foo(...)` with deprecation warning per Q2 lock; `migrate` = move to a different package, e.g. JuCE.)**

| Symbol | Source | Status today | My lean | Your call |
|---|---|---|---|---|
| `enumStr`, `readStructenumout`, `readEnergies`, `readStrIn` | `CEdataSupport.jl` (Fortran-format file I/O) | exported | `legacy` (per doc-plan Q2 lock) |  |
| `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius`, `estimatedTime` | `radiusEnumeration.jl` | exported | `legacy` — chunk 4's `RadiusBound` supersedes |  |
| `coloring_hash`, `coloring_unhash` | `Enumlib.jl` (top-level) | exported | `unexport` — internal helpers; `multinomial_hash` / `multinomial_unhash` are the public surface |  |
| `getColorings`, `getSymEqvColorings_slow`, `reduceColorings` | `Enumlib.jl` (top-level) | exported | `unexport` — pre-chunk-5 brute-force routines; `enumerate(...)` is the public path |  |
| `getUniqueColorings` | `Enumlib.jl` (top-level) | exported | `unexport` — internal worker for `Enumeration`; `enumerate(...)` is the public path. Note: `getUniqueColorings_recursive_stabilizer` (chunk 8) is the public Morgan-2017 entry; should it follow the same un-export-and-route-through-`enumerate` pattern? See Q5. |  |
| `getPermG`, `getTransGroup` | `Enumlib.jl` (top-level) | exported | `unexport` — used by `Supercell` constructor; not user-facing |  |
| `gCoordsToOrdinals`, `ordinalToGcoords`, `getCartesianPts`, `getOrdinalsFromCartesian`, `get_nonzero_index` | `LatticeColoringEnumeration.jl` | exported | `unexport` — coordinate-conversion utilities; not user-facing |  |
| `getAllHNFs`, `tripletList`, `basesAreEquiv`, `getSymInequivHNFs`, `getFixingOps`, `checkCartesianPt` | `LatticeColoringEnumeration.jl` | exported | `unexport` — used internally by chunk-3 `Supercell` constructor and `enumerate_hnfs`; the public path is via `Supercell` and `enumerate_hnfs` |  |
| `isaGroup`, `generateGroup` | `Enumlib.jl` (top-level) | exported | `unexport` — group-theory helpers; not user-facing |  |
| `isRotTransEquiv`, `isTransEquiv`, `canonClustOrder!`, `deleteTransDuplicates!`, `shiftToOrigin`, `isEquivClusters` | `clusterequvi.jl` + `Enumlib.jl` | exported | `migrate` to JuCE — these are cluster-equivalence helpers for cluster expansion, not derivative-structure enumeration |  |
| `avg_cell_radius` | `Enumlib.jl` (top-level) | exported | `keep` — used by `RadiusBound`, useful for users sizing supercells |  |

**Q1.** Anything you'd reclassify? Add a column entry or strike through.
No. Thanks.

**Q2.** Deprecation period for `legacy` symbols: doc-plan said "one v0.2 minor release; full removal scheduled for v0.3." Stick with that, or longer / shorter?
That's still the plan

**Q3.** For `migrate to JuCE`: we cut these from `src/Enumlib.jl`'s export list now (so they don't appear in the reference quadrant), but the actual move into JuCE is a separate piece of work (cross-repo). Is doing the un-export now and the migration in a follow-up acceptable, or want both at once?
Both at once, unless you think that is a bad idea

**Q4.** `getUniqueColorings_recursive_stabilizer` (chunk 8) is the only public *direct-algorithm-entry* in the export list — every other algorithm is reached via `enumerate(...)` dispatch. Keep it as a direct entry (matches `getUniqueColorings` / `getUniqueColorings_slow` precedent), or fold it behind `enumerate(..., algorithm=:recursive_stabilizer)` exclusively and unexport the direct entry?
Don't you think we should unexport? we should be able to call it inside `enumerate`, just like the others.

**Q5.** Naming consistency: the v0.2 type-catalog uses `snake_case` (`enumerate_hnfs`, `count_inequivalent`, `to_poscar`, `to_labeling`). The legacy API uses `camelCase` (`getAllHNFs`, `getSymInequivHNFs`, `basesAreEquiv`, `getPermG`). After un-exporting most of the legacy API, the only legacy-naming symbols in the public surface are likely `getUniqueColorings_recursive_stabilizer` (chunk 8) and `avg_cell_radius`. Want a rename pass on those before reference docs publish? My lean: rename `getUniqueColorings_recursive_stabilizer` → `recursive_stabilizer_enumeration` (or similar) since it's a chunk-8 newcomer; leave `avg_cell_radius` because it's a downstream-stable measure.

I want to move exclusively to snake case.


**Q6.** New `Enumlib.LegacyImport` submodule: skeleton looks like:

```julia
module LegacyImport
import ..Enumlib: enumStr as _enumStr  # …etc
function enumStr(args...; kwargs...)
    Base.depwarn("Enumlib.LegacyImport.enumStr is deprecated; use … instead", :enumStr)
    _enumStr(args...; kwargs...)
end
end
```

Or a one-time `@warn` at module load? Or a per-call `Base.depwarn` (above)? My lean: `Base.depwarn` so it shows up at user call-sites, not load.

---

## 3. Sub-chunk split

Audit + boundary changes + doctest sweep + `@docs` block construction is too much for one commit. Proposed split:

**13b.1 — Boundary enactment (small).** Apply the §2 decisions: shrink `src/Enumlib.jl`'s export list, create `Enumlib.LegacyImport` shim with `Base.depwarn`-wrapped legacy I/O, run tests to confirm nothing internal broke. ~50 lines source delta + a small test for the deprecation warning. **(Output: clean export list before docstring writing starts.)**

**13b.2 — Type-catalog docstring sweep + doctests.** Audit and fill the docstrings in `src/types/*.jl` (16 files, ~50 type-related public symbols). Add `jldoctest` blocks to every constructor and accessor where output is reproducible. ~300 lines of docstring delta; ~50 new doctest blocks. **(Output: type-catalog reference is publication-ready.)**

**13b.3 — Algorithm + I/O docstring sweep + doctests.** Same treatment for `src/algorithms/*.jl` (multinomial, polya, recursive_stabilizer) and `src/io/poscar.jl`. ~200 lines of docstring delta; ~25 new doctest blocks. **(Output: algorithm + I/O reference is publication-ready.)**

**13b.4 — Reference quadrant `@docs` blocks + checkdocs raise.** Populate the 7 reference pages with `@docs` blocks (mapping in §4). Raise `make.jl`'s `checkdocs = :none` to `checkdocs = :exports` and confirm the build still succeeds. **(Output: reference quadrant fully renders; checkdocs catches any future undocumented exports.)**

**Q7.** Sub-chunk split — does this 4-way split work, or want it different (e.g., merge 13b.2 + 13b.3 since they're parallel work; split 13b.4 into "@docs blocks" and "checkdocs raise" because the latter might surface stragglers)?

**Q8.** Each sub-chunk gets the standard chunk-review pad (`docs/notes/chunk13b1-review.md`, etc.), or run them all under one `chunk13b-review.md` since they're closely related?

---

## 4. Reference page → public symbol mapping

Each reference page is an `@docs` block (or several) listing the symbols to inject docstrings for. Mapping:

### `reference/parent-and-sites.md`
```
ParentLattice
basis, dset, ndset, n_nonzero_translations
SymmetryOp
space_group, lattice_rotations
Site, Sites
is_active, is_inactive
equate!, canonical, active_canonical_sites
n_active, n_canonical, n_effective
```

### `reference/supercells.md`
```
HNF, Supercell
volume
SupercellSelection (abstract)
VolumeRange, RadiusBound, ExplicitHNFs
enumerate_hnfs
avg_cell_radius
```

### `reference/concentrations.md`
```
Concentration, Concentration_ratio, Concentration_count
ConcentrationRange
n_species, multiplicities, concentrations_in_range
multinomial_count, multinomial_hash, multinomial_unhash
```

### `reference/enumerate-and-count.md`
```
Enumeration, EnumeratedStructure
to_labeling
default_memory_budget
Base.enumerate(::ParentLattice, ::Sites; …)   # the headline entry
InequivalentCount
count_inequivalent
EmptyEnumerationError, PartitionExplosionError
# (algorithm = :recursive_stabilizer / :exhaustive / :multinomial / :auto documented as kwargs of `enumerate`, not as separate entries — modulo Q4 above)
```

### `reference/cost-estimator.md`
```
EnumerationCostEstimate
estimate_cost
EnumerationTooLargeError
format_bytes
```

### `reference/polya.md`
```
Enumlib.Polya   # submodule overview block
polya_count
cycle_structure
aperiodic_orbit_count
```

### `reference/poscar-io.md`
```
to_poscar
write_enumeration_archive
read_results
attach_results
```

**Q9.** Mapping looks right? Anything to move between pages, or split a page that's getting heavy (concentrations is densest; should `multinomial_*` move to its own page or fold into `enumerate-and-count.md` as algorithm-internals)?

Fine

**Q10.** Do you want a `reference/legacy.md` page that documents the deprecated `Enumlib.LegacyImport.*` shims, so users porting old code can find them? My lean: yes, one page, marked clearly as "deprecated — for porting only."

No

---

## 5. Doctest strategy

**Default per documentation plan:** every public function ≥1 `jldoctest` block. Concrete patterns:

- **Constructors / accessors with reproducible output** → `jldoctest`.
  ```julia
  julia> p = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
  ParentLattice{3, Float64}( … )
  ```
- **Functions whose output is large or has timestamps / random elements** → prose `# Examples` block, not `jldoctest`. (E.g., `enumerate(...)` on anything beyond n=4 returns thousands of structures; `write_enumeration_archive` produces a timestamped filename.)
- **Functions whose output is platform-dependent** (`format_bytes` of a memory budget; estimates) → mark `jldoctest filter = ...` with the regex sanitizer, OR convert to `# Examples` prose.


**Q11.** Doctest density on multi-method dispatched functions (e.g., `enumerate` has many keyword combinations). Doc-plan said multi-kwarg → multiple doctests. My lean: 4 doctests on `enumerate` (no concentration / fixed concentration / range / explicit algorithm); 3 on `count_inequivalent` (basic / fixed concentration / over a range); 1 each on most types. Acceptable, or want a different shape?

Good

**Q12.** Doctest stability: doctests fail CI if output drifts. Some current docstring examples may have output that's sensitive to the Julia version, or to BigInt formatting (`count_inequivalent` returns `BigInt`, which might display as `9` vs `BigInt(9)` depending on context). My lean: use `jldoctest filter` regexes liberally where output is structural ("any matrix of the right shape") rather than exact. Add a CI step that runs `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` so drift is caught immediately, not only at `make.jl` time.

Yes
---

## 6. `@docs` vs `@autodocs`

`@autodocs` sweeps a module and drops every docstring; `@docs` lists symbols by name. The doc plan didn't lock this; my lean: **`@docs` per page** because it gives explicit control over the symbol order on each page (alphabetical by default with `@autodocs`, which scrambles related-but-differently-named symbols like `Concentration` / `Concentration_count` / `Concentration_ratio`).

**Q13.** `@docs` per page (manual curation), or `@autodocs` per page with `Pages = [filename]` filter (auto)? My lean above. Spacey uses `@docs` per page in `docs/src/reference/`.

Same as spacey

---

## 7. Out of scope for chunk 13b

- **Tutorials / How-to / Explanation content.** Those are 13c–13e; this chunk only populates Reference.
- **`docs/src/index.md` polish.** Stays as-is from 13a; cosmetic refinement comes in 13f.
- **DocumenterCitations / citation system.** Decided "no" in doc-plan §7 Q3 for v0.2.0.
- **JuCE-side migration of cluster-equivalence helpers** (Q3 above). This chunk un-exports them on the Enumlib side; the actual cross-repo move happens in a JuCE chunk.
- **Symbols I haven't listed in §4** that turn out to be public-but-undocumented during audit. Plan: surface them in 13b.2 / 13b.3 and ask before adding.

---

## 8. Verification at sign-off

- `julia --project=docs docs/make.jl` builds with `checkdocs = :exports` and no warnings.
- `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` passes.
- `Pkg.test()` still passes (the export list shrank and a deprecation submodule appeared).
- `git diff` of `src/Enumlib.jl` shows shrunk export list; no other behavior change.
- Reference pages all show their docstrings in the rendered HTML.

---

## 9. Numbered responses to your review pass

**1 — Q1 (boundary table reclassifications): no changes.** Table stands.

**2 — Q2 (deprecation period): one v0.2 minor → remove in v0.3.** As doc-plan locked.

**3 — Q3 (cross-repo timing for `migrate to JuCE`): pushing back, recommend two-step.** "Both at once" means 13b.1 grows from "shrink the export list + add `LegacyImport` shim for legacy I/O" (~50 lines, single repo) to "shrink list + shim + cross-repo coordinated PR adding the cluster-equivalence helpers to JuCE.jl". Reasons I want to split:

- 13b.1 was deliberately scoped small to land cleanly before the docstring sweep starts. Cross-repo coordination doubles the review surface.
- The two repos move at different cadences. Coordinating "Enumlib unexports `isRotTransEquiv` *and* JuCE picks it up under its own namespace" requires lockstep commits; if one side fails review, the other is stuck mid-migration.
- The user-facing impact in v0.2.0 is the same either way: the cluster helpers don't appear in Enumlib's reference quadrant. Whether JuCE picks them up today or next week is invisible.

**Recommended path:**
- 13b.1 (Enumlib-side, this chunk): un-export the cluster-equivalence helpers from `src/Enumlib.jl`'s export list. The internals (`clusterequvi.jl`) stay in place — JuCE can import via `Enumlib.isRotTransEquiv(...)` while the migration is in flight.
- Separate JuCE-side chunk (peer chunk in JuCE.jl, after 13b.1 ships): import the helpers into JuCE under their target namespace (likely `JuCE.Clusters.*`).
- Cleanup pass after JuCE adopts: remove the now-unused internals from Enumlib altogether (delete `clusterequvi.jl`, drop the cluster-equivalence section of `src/Enumlib.jl`).

**Confirm or override** — if you'd rather one shot of cross-repo work, say so and I'll fold it into 13b.1.

**4 — Q4 (`getUniqueColorings_recursive_stabilizer` unexport): yes, route through `enumerate(..., algorithm=:recursive_stabilizer)` only.** Matches the dispatch convention used for the other two algorithms. Net effect on the public surface: the only way to reach Morgan-2017 is via `enumerate`'s `algorithm` kwarg.

**5 — Q5 (exclusively snake_case): need a scope clarification.** "Exclusively snake_case" lands clearly for *functions*. But three groups have edge cases:

- **(a) Type constructors that look like type names:** `Concentration_count(...)`, `Concentration_ratio(...)`. These are functions that return `Concentration` instances. Today they're styled with a leading capital + underscore (`Concentration_count`) — neither pure snake_case nor PascalCase. Strict interpretation of your rule renames to `concentration_count`, `concentration_ratio`. Looser interpretation (constructors-as-types) keeps the capital. **My read:** rename to `concentration_count` / `concentration_ratio` is the right call — pure snake_case for functions, capital-first reserved for type names. This is an API-breaking rename so it needs to land in 13b.1 alongside the un-exports, not silently mid-chunk later.
- **(b) Internal/unexported camelCase functions** (`getPermG`, `getColorings`, `basesAreEquiv`, etc.): after Q1's un-exports, these are all internal. Strict reading says rename them too; pragmatic reading says leave internals alone since they're not part of the public-API contract. **My read:** leave internals as-is for v0.2.0; rename pass on internals can land later as a non-breaking refactor.
- **(c) Type names**: `ParentLattice`, `Sites`, `HNF`, `Concentration`, `EnumeratedStructure`, etc. all use `UpperCamelCase` per Julia convention. Snake_case rule is for functions, not types — these stay.

**Confirm interpretation:** rename `Concentration_count`/`Concentration_ratio` → `concentration_count`/`concentration_ratio` in 13b.1; leave internals camelCase for now; types stay `UpperCamelCase`. Override if you want a wider sweep.

**6 — Q6 (deprecation mechanism): `Base.depwarn` per-call.** As I leaned. Catches uses at user call-sites, doesn't spam at module load.

**7 — Q7 (4-way sub-chunk split): yes, 4 sub-chunks as drafted.** No pushback from your edit pass.

**8 — Q8 (one review pad or four): four — separate `chunk13bN-review.md` per sub-chunk.** Each sub-chunk lands as a separate commit, so a fresh review pad per commit keeps the review pattern uniform with the rest of the project.

**9 — Q9 (reference page mapping): accepted as drafted.**

**10 — Q10 (legacy reference page): no.** Legacy `LegacyImport.*` shims will be undocumented in the rendered site; the deprecation warnings at call-time tell users where to look.

**11 — Q11 (doctest density): accepted (4 on `enumerate`, 3 on `count_inequivalent`, 1 on most types).**

**12 — Q12 (doctest stability via `filter` + CI step): yes.** I'll add the `doctest(Enumlib)` invocation to the Documentation.yml workflow so drift fails CI directly.

**13 — Q13 (`@docs` per page, like Spacey): yes.**

---

## 10. Two clarifications I need before starting 13b.1

**A.** Q3 cross-repo timing — confirm two-step (Enumlib un-export now, JuCE migration as a follow-up peer chunk), or override to one-shot.

**B.** Q5 snake_case scope — confirm the §9 item-5 interpretation: rename `Concentration_count`/`Concentration_ratio` → `concentration_count`/`concentration_ratio` in 13b.1; leave internals as-is; types stay `UpperCamelCase`. Override if you want a wider sweep.

Once A and B land, I start 13b.1.
