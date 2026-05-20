# Chunk 6.5c: label-equivalence-aware effective parent for Regime C

**Status (2026-05-19): implemented.** See `src/types/parent_lattice.jl`
(internal direct-fields constructor), `src/enumerate.jl` (`_dset_equivalence_classes`,
`_dset_perm_preserves_classes`, `_effective_parent` helpers + threading through
`enumerate` / `count_inequivalent` / `estimate_cost`), and `test/test_enumerate.jl`
(`_effective_parent (chunk 6.5c)` testset). What we actually observed is captured
in chunk6.5-design.md §11.4. The original plan below is preserved for posterity.

---



## Context

`ParentLattice` constructs its cached `space_group` by calling
`Spacey.spacegroup(Crystal(A, r, ones(Int, length(ds))))` with uniform types
(`src/types/parent_lattice.jl:82–85`). For multilattices with non-uniform sublattice
occupations (wurtzite-style cation/anion, half-Heusler with distinct Y={2} / Z={3}),
this is over-symmetric: Spacey correctly returns every isometry that preserves the
*position set*, but some of those isometries swap dset positions across `allowed_labels`
classes and aren't symmetries of the labeled configuration.

The current per-supercell `_filter_perm_group_by_mask` (`src/enumerate.jl:331–354`)
tries to drop them after the fact, but `getPermG`'s `unique!()` step
(`src/Enumlib.jl:337–338`) has already merged distinct dset_perms into the same
site_perm by then, so legitimate and illegitimate ops can no longer be told apart.

Symptom: wurtzite enumeration returns 3/10/58 inequivalent at n=1..3 vs. Fortran's
4/42/260; half-Heusler with distinct labels fails at n=6,7; full-Heusler with
distinct labels fails at n=2..5.

**Per the user (2026-05-19): fix on the Enumlib side; leave Spacey alone.** The
right group is computable as a subset of Spacey's uniform-types result, given
the `Sites` object.

## Approach

Filter `parent.space_group` / `dset_perms` / `dset_shifts` *at `enumerate()` entry*
(where `Sites` is in scope) by keeping only ops whose `dset_perm[i]` lands in the
same allowed-labels equivalence class as `i` for every `i`. The user's original
`parent` is untouched; the filtered "effective parent" flows through Supercell
construction. Regime A (single dset) and Regime B (uniform allowed_labels) are
no-op fast paths: the filter retains every op, and we return the original
`parent` object so existing tests stay byte-identical.

## Files to modify

### `src/types/parent_lattice.jl`

Add a private direct-fields inner constructor after the existing one
(after line ~103):

```julia
ParentLattice{D}(A, dset, space_group, dset_perms, dset_shifts) where D = new(...)
```

Skips canonicalization, Spacey, and `_dset_permutation` — inputs are assumed
pre-validated (they come from filtering an existing `ParentLattice`).

### `src/enumerate.jl`

**Add three helpers** near the existing site-mask helpers (~line 287):

1. `_dset_equivalence_classes(sites::Sites) -> Vector{Int}` — positions sharing
   `allowed_labels` get the same class id. Iterate `sites.list`, assign class
   ids in first-seen order via `Dict{BitSet, Int}`.
2. `_dset_perm_preserves_classes(π, classes) -> Bool` — one-liner:
   `all(classes[π[i]] == classes[i] for i in eachindex(π))`.
3. `_effective_parent(parent, sites) -> ParentLattice{D}` — computes classes,
   selects retained op indices, returns the original `parent` if every op is
   retained (Regime A/B fast path), otherwise builds a fresh `ParentLattice{D}`
   via the new direct-fields constructor.

**Thread `parent_eff = _effective_parent(parent, sites)` through three entry points.**
Order: filter *after* `_validate_enumerate_inputs(...)` (validation errors should
reference the user's original parent), *before* anything that builds a `Supercell`
or reads `dset_perms`.

- `enumerate(...)` at line 167: `parent_eff = _effective_parent(parent, sites)`
  immediately after validation. Pass `parent_eff` to: `estimate_cost(...)` at
  171, `_enumerate_hnfs_with_degeneracies(...)` at 184, and all three algorithm
  body calls (190, 192, 196). The `Enumeration{D}(...)` constructors at 186 and
  the end of each body keep storing the user's `parent`.
- `count_inequivalent(...)` at line ~571: filter after `_validate_enumerate_inputs`,
  use `parent_eff` for `_enumerate_hnfs_with_degeneracies` and `Supercell(hnf, parent_eff, ...)`.
- `estimate_cost(...)` at line ~684: filter after `_validate_enumerate_inputs`,
  use `parent_eff` for `enumerate_hnfs`, the recursive `count_inequivalent` call,
  and `_predict_peak_memory`. The `:auto`-dispatch call to `_multinomial_bitmap_fits`
  at line ~125 can keep the original parent (cost prediction is conservative
  either way).

**Keep `_filter_perm_group_by_mask`** as a no-op safety net (it's idempotent —
after the parent-level fix it never has work to do in our corpus, but the
runtime cost is negligible and it stays correct). Update its docstring
(lines ~316–325) to note the parent-level fix supersedes it for the cases the
chunk 6.5b initial commit relied on it.

### `test/test_enumerate.jl`

Append to the existing `Regime C Fortran corpus` testset:

1. **Wurtzite** — assert `length(enumerate(..., n))` == [4, 42, 260] at n=1..3.
   Site setup: cations at d₁, d₂ with `allowed_labels = [0, 1]`; anions at d₃,
   d₄ with `[2]`. Also assert `length(parent.space_group) == 24` to lock in
   that the *user's parent* is untouched.
2. **Half-Heusler with distinct labels** — Y={2}, Z={3} setup, assert match
   Fortran at n=1..7 (currently fails 6, 7).
3. **Full-Heusler with distinct labels** — Y={2}, Z={3} setup, assert match
   Fortran at n=1..5 (currently fails 2..5).
4. **Regime A/B fast-path identity check** — for a single-lattice FCC parent
   and an HCP-binary Regime-B parent, assert `_effective_parent(parent, sites) === parent`
   (literal object identity — the no-op short-circuit is observable).

## Files to read but not modify (verified)

- `src/Enumlib.jl:301–352` (`getPermG`): reads `parent.dset_perms` / `dset_shifts` /
  `lattice_rotations(parent)`. All three are correct on the filtered parent because
  the filter sub-sets every relevant field consistently. No code change.
- `src/types/supercell.jl`: `Supercell{D}(hnf, parent; hnf_degeneracy)` reads
  `lattice_rotations(parent)` and calls `getPermG(hnf.matrix, fixingOps, parent)`.
  Both work correctly with the filtered parent. No code change.

## Verification

1. `Pkg.test()` — the full 2052-assertion suite must pass. Existing single-lattice
   and Regime-B tests should be byte-identical (the fast path returns the same
   parent object).
2. The four new testsets in `test_enumerate.jl` must pass — wurtzite hits
   4/42/260; half-Heusler distinct hits the full corpus 1..7; full-Heusler
   distinct hits 1..5; fast-path identity test confirms `===`.
3. Update `docs/notes/chunk6.5-design.md` §11.2 (the "option (c) accepted" note)
   to record that the wurtzite path and the distinct-label half/full-Heusler
   paths now also pass, courtesy of the effective-parent fix. The "Spacey bug"
   §11.3 note can be retitled to "wurtzite encoding — fixed in Enumlib via the
   effective-parent filter" with a pointer to the helper.
4. Re-check the chunk6.5_fortran_corpus.csv: every (case, volume) sum should
   match the new Julia counts. If yes, the existing corpus testset (which
   currently uses the `Y=Z={2}` relabeled half/full-Heusler) can be either left
   as-is (still passes) or augmented with the distinct-label rows.
5. Spot-check `parent.space_group` semantics: in a REPL session, construct a
   wurtzite `ParentLattice` and confirm `length(parent.space_group) == 24` — the
   user-visible field is untouched.

## Relationship to chunk 6.5a (`:multinomial_restricted`)

The fix is **algorithm-agnostic**. Both `:recursive_stabilizer` (chunk 6.5b) and
`:multinomial_restricted` (chunk 6.5a, not yet implemented) consume the same
per-supercell `perm_group` and use it identically as the orbit-equivalence
oracle (the bitmap algorithm crosses out `coloring[σ]`; the tree compares
`partial[σ]` to `partial`). An over-symmetric `parent.space_group` would
over-deduplicate both algorithms in exactly the same direction and magnitude.

Chunk 6.5b initially worked around the issue with the per-supercell
`_filter_perm_group_by_mask` (`src/enumerate.jl:331–354`), which catches the
cases where the bad ops survive `getPermG`'s `unique!()` as a distinct
site-permutation. That filter is **insufficient for wurtzite**: the bad ops
merge with a legitimate op during dedup, the merged site-permutation passes
the mask check, and the failure mode is invisible to a per-supercell filter
that only sees the post-`unique!()` perm group.

Chunk 6.5c moves the fix one layer earlier — at the parent level, *before*
`getPermG`'s dedup — so neither algorithm sees bad ops in the first place.
This is a prerequisite for chunk 6.5a landing correctly; if 6.5a lands first,
it'll inherit the wurtzite mismatch from the per-supercell filter's blind spot.

## Out of scope

- Any change to Spacey. The user explicitly said to leave it.
- The actual `:multinomial_restricted` implementation — that's chunk 6.5a; 6.5c
  is its symmetry-input prerequisite.
- Bench cross-algorithm section — orthogonal.
- Public API for explicit "equivalence classes" on `ParentLattice` — not
  needed; the derivation from `Sites.allowed_labels` is sufficient and keeps
  the constructor signature stable.
