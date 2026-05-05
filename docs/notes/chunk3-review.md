# Chunk 3 — review and revise round

This file collects review items on chunk 3 (`HNF{D}`, `Supercell{D}`, the legacy Cartesian-API drops, and the `getSymInequivHNFs` port).

Workflow:
1. Read the chunk 3 files (listed below) and add inline `#gh ...` comments wherever something needs discussion.
2. Tell me you're done; I read your comments and respond inline here under numbered items.
3. We iterate until everything is signed off.
4. I batch any code changes as chunk 3.1 (one commit) and we move to chunk 4.

## Files in scope

**New (chunk 3):**
- `src/types/hnf.jl` (104 lines) — `HNF{D}` struct, validation, `volume`, `LinearAlgebra.det` overload, equality + hashing, pretty-print, plus the new-API `getSymInequivHNFs(n, parent::ParentLattice{D})` wrapper.
- `src/types/supercell.jl` (78 lines) — `Supercell{D}` struct with cached SNF / stabilizer order / permutation group; field-access API (no accessor functions).
- `test/test_hnf.jl` (146 lines) — 66 passing tests across HNF validation, equality, Supercell construction (simple cubic + HCP), inequivalent-HNF count corpus across 5 lattices × 5 sizes, bridge test against the legacy API, Supercell equality + show.

**Modified:**
- `src/LatticeColoringEnumeration.jl` — Cartesian-coord variants of `basesAreEquiv`, `getSymInequivHNFs`, `getFixingOps` deleted; `getFixingLatticeOps` renamed to `getFixingOps`.
- `src/Enumlib.jl` — Cartesian `getPermG` deleted; chunk-3 includes added near the bottom (after the legacy code that they depend on); chunk-3 exports added to the `export` block.
- `test/runtests.jl` — existing FCC corpus refactored to use the lattice-coord legacy API; chunk-1, -2, -3 test files included so a single `Pkg.test()` runs all 176 tests.

## Items found by me during chunk 3 implementation (already fixed; flagged for transparency)

### Item A — `Base.det` vs `LinearAlgebra.det`

Initial attempt was `Base.det(h::HNF) = volume(h)`. Wrong: `det` lives in `LinearAlgebra`, not `Base`. Fixed to `LinearAlgebra.det(h::HNF) = volume(h)`. Worth knowing for chunks 5+ when more `LinearAlgebra` functions get overloaded (e.g., `tr`, `inv`).

### Item B — Accessor functions can shadow imported names

I initially defined `snf(s::Supercell) = s.snf` as an accessor. This *would have* shadowed `NormalForms.snf` inside the Enumlib namespace — the same family of bug as chunk 2.1's `hash` shadow. Caught at smoke-test time when the constructor body's `snf(hnf.matrix)` resolved to my accessor (which only takes `Supercell`) instead of `NormalForms.snf`.

Fix applied: **dropped the accessor functions** for `Supercell` (`hnf`, `snf`, `space_group_order`, `permutation_group`); use field access (`s.hnf`, `s.snf`, …). More idiomatic Julia for stable struct fields anyway.

Lesson generalized for the working agreement (might want to add to `v0.2-plan.md`): **Don't define a function in our module with the same name as a function from an imported package** unless we're explicitly extending it (and qualifying the call). The chunk 2.1 / chunk 3 lessons together suggest we should think about this *every* time we name a function or accessor — not just for `hash`.

### Item C — Test assertion was too strong

I had asserted `length(perm_group) == space_group_order × volume`. The legacy `getPermG` deduplicates rotation actions on supercell sites — different rotations can induce the same permutation, and `unique(...)` collapses them. Relaxed to `length(perm_group) % volume == 0`, between `volume` and `space_group_order × volume`.

## Items from your review

### Item 1 — `space_group_order` field name is ambiguous

**Where:** `src/types/supercell.jl` line 20.

**Your comment:**
> is this the number of symmetries of the supercell?

**Diagnosis.** The name is genuinely ambiguous. Two readings, both plausible:
- **"Order of the space group"** — the size of the parent's *full* space group (48 for cubic, 24 for HCP, etc.). This is the natural reading of the field name.
- **"Order of the stabilizer subgroup"** — the number of parent ops that fix this *specific* supercell. This is what we actually store.

The docstring explains it correctly (number of stabilizer ops), but the field name doesn't match the docstring's intent. A reader scanning `s.space_group_order` without reading the docstring would expect the parent's full count, not the stabilizer-subgroup count.

**Plus a subtler point.** The "symmetries of the supercell" in the broadest sense include both the rotational stabilizer AND the supercell's own translation group. Those combine in the `permutation_group` field (which has `length = stabilizer_ops × n` typically). So the field we're naming is *just the rotational stabilizer*, not the supercell's full symmetry count.

**Proposal.** Rename `space_group_order` → `n_stabilizer_ops`. Explicit, accurate, matches the chunk-1 "explicit is better than jargon" lean (user's choice of origin, etc.).

Alternatives considered:
- `stabilizer_order` — concise but uses group-theory jargon ("order" = size of group).
- `n_supercell_symmetries` — domain-friendly but misleading (the supercell's full symmetry count is `length(permutation_group)`, which is bigger).

**My lean:** `n_stabilizer_ops`. Will rename in chunk 3.1 if you agree.

**Your response:**


---

### Item 2 — `[op.R for op in parent.space_group]` — why the list comprehension?

**Where:** `src/types/supercell.jl` line 26 and `src/types/hnf.jl` line 89.

**Your comment:**
> Again, why not just grab the ops as a single vector from Spacey? Why do we need a list comprehension? Spacey returns a vector already...is it because we don't need the fractional translations?

**Answer.** Yes — exactly because we don't need the fractional translations here.

`parent.space_group` is `Vector{SymmetryOp{D}}`, where each `SymmetryOp{D}` is the chunk-1 wrapper around Spacey's `SpacegroupOp`, holding both:
- `R::Matrix{Int}` — the rotation (lattice coords)
- `t::Vector{Float64}` — the fractional translation in `[0,1)^D`

The legacy `getFixingOps`, `getPermG`, and `basesAreEquiv` all take rotation-only `Vector{Matrix{Int}}` because **HNF symmetry equivalence depends only on rotations**, not on fractional translations. (HNF equivalence is `H_2 ≅ H_1 iff ∃R s.t. H_1 R H_2^{-1}` is unimodular — pure rotation.) So we strip the `t` parts and pass just the `R`s.

The list comprehension `[op.R for op in parent.space_group]` is the extraction. It's a one-line idiomatic Julia way to project out one field from a vector of structs. Equivalent in spirit to Python's `[op.R for op in parent.space_group]` or pandas's `df['R']`.

**Could we avoid the comprehension?** A few options:
- **Option A (current):** `[op.R for op in parent.space_group]` at every call site. Works but repeats the extraction in two places (HNF wrapper, Supercell constructor).
- **Option B:** Helper function `lattice_rotations(parent) = [op.R for op in parent.space_group]`. Removes duplication; still one allocation per call.
- **Option C:** Cache `lattice_rotations` as a derived field on `ParentLattice`. Zero per-call allocation; small memory cost. But changes the chunk-1 type.
- **Option D:** Make `parent.space_group` *be* the rotations from the start, and put translations in a separate field. But then we lose the convenient pairing — many uses (chunk 5+ for the multilattice labeling case) need both R and t for the same op.

**My lean: Option B for chunk 3.1.** Add `lattice_rotations(parent::ParentLattice{D}) :: Vector{Matrix{Int}}` as an internal helper near `parent_lattice.jl`. Both call sites use it. Less repetition, no behavior change, easy to extend to caching (option C) later if profiling motivates it.

**Your response:**


---

### Item 3 — Why preserve the legacy code? Why not just copy it here?

**Where:** `src/types/hnf.jl` line 91.

**Your comment:**
> Why preserve the legacy code? Why not just copy it here and be done?

**Honest answer.** The legacy `getSymInequivHNFs(n, LG)` is only ~15 lines of code, but it depends on `getAllHNFs(n)` and `basesAreEquiv(H1, H2, LG)`, both of which also live in `LatticeColoringEnumeration.jl`. So inlining just the wrapper doesn't actually shrink the code surface — we'd still have to go to `LatticeColoringEnumeration.jl` for the dependencies.

The full consolidation (delete `LatticeColoringEnumeration.jl` entirely; move all the HNF-side code into `src/types/hnf.jl` + `src/types/supercell.jl`) is a chunk-5 cleanup task that I deferred deliberately:

1. Chunks 3 + 4 only port the parts of the legacy file that are HNF-side. Chunk 5 ports the labeling-side code (`getColorings`, `getUniqueColorings`, `coloring_hash`, etc.). It's natural to do both ports together with a single sweep that empties out and deletes `LatticeColoringEnumeration.jl` at the end.
2. Smaller chunk-3 diff. The legacy file is currently load-bearing (both `test/runtests.jl` and the new wrappers depend on it). Refactoring it now adds risk; doing it once during chunk 5 cleanup is one focused operation.

**Honest cost of the deferral.** Two files (`LatticeColoringEnumeration.jl` + `src/types/hnf.jl`) instead of one for the next ~2-3 chunks. The new code is slightly more indirect (wrapper calls into legacy). Manageable.

**Your call:** keep my deferral plan, or pull the consolidation forward?

If you want it pulled forward, the chunk 3.1 work expands to: inline `getAllHNFs`, `basesAreEquiv` (lattice-coord version), and the body of `getSymInequivHNFs(n, LG)` into `src/types/hnf.jl`; delete the `LatticeColoringEnumeration.jl` entries; update `test/runtests.jl` to use the new API only. Probably ~30 minutes of code motion. Not breaking, not particularly risky.

**My lean: defer to chunk 5** — keeps chunk 3 focused on types, reserves the full file deletion for one operation. But happy to pull forward if you'd prefer a cleaner state right now.

**Your response:**


---

## Summary

| # | Item | Action | Status |
|---|---|---|---|
| 1 | `space_group_order` field name | Rename to `n_stabilizer_ops` | Awaiting sign-off |
| 2 | `[op.R for op in ...]` extraction | Add `lattice_rotations(parent)` helper | Awaiting sign-off |
| 3 | Inline legacy code or defer? | My lean: defer to chunk 5 cleanup | Awaiting your call |

When all three are signed off, chunk 3.1 lands as one commit (rename + helper + any inlining you choose). Then chunk 4.

**Your response (when you're done):**
I agree with all three of your suggestions. Go ahead.
