# Chunk 6.5 — per-site allowed-labels enumeration (Regime C)

Two parallel algorithm extensions to lift the Regime-C gate:

- **6.5a — `:multinomial_restricted`** — HF 2012 §A.1: bitmap encoding + site-restriction mask, tree-walk to skip impossible states. Mirrors Fortran's `generate_permutation_labelings` in `labeling_related.f90`.
- **6.5b — Extend `:recursive_stabilizer`** — the Morgan-Hart 2017 tree generalizes naturally to per-site `allowed_labels` (the inner-loop branching consults `allowed_labels[i]` instead of `0:k-1`).

Both produce the **same labeling set** for any (parent, sites, supercells, concentration) tuple in Regime C. They differ only in performance characteristics. Implementing both gives us head-to-head benchmarks on perovskite-style problems.

## 1. Capability question

I argued earlier that `:recursive_stabilizer` extended for per-site restrictions subsumes `:multinomial_restricted` in capability. Re-checking the algorithm details:

- Both work at **fixed concentration only** (a `Concentration` is required).
- Both can express **per-site `allowed_labels`** where each dset position carries a possibly-different set of admissible species.
- Both handle the same **multilattice cases** (Regime C — heterogeneous sublattices on `n_D ≥ 2`).

Edge cases worth checking:

- **Concentration vs allowed_labels consistency.** If position i is restricted to `{0}` and concentration demands `a_0 < n_D` (so not every position-1 site is species-0), the problem is unsatisfiable. Both algorithms should detect this and return an empty enumeration (or throw an `EmptyEnumerationError` at validation, parallel to existing behavior for non-divisible concentrations).

> Yes good idea.

- **Inactive sites.** A site with `allowed_labels = {0}` is *inactive*. The existing `Sites` machinery already distinguishes active vs inactive. Both algorithms should respect inactive sites — those positions are pinned to species 0, not branched over.
- **Sites with empty `allowed_labels`.** Should be rejected at `Sites` construction time, not reach the enumerator. (Verify the existing constructor catches this.)

> Yes

I don't see a corner case `:multinomial_restricted` covers that the extended `:recursive_stabilizer` doesn't.

> But keep your eyes open. Conceptually the multinomial came first and it seems the recursive algorithm is just a generalization, but I didn't really see it that way clearly. Let's keep open minds.

**[Revision 2026-05-18]** Acknowledged — I'll watch for the following during implementation and flag if any surface:

- Cases where the bitmap algorithm's *exact-rank crossing-out* catches a symmetry equivalence the tree's *canonicality test* misses (or vice versa). The two algorithms are equivalent in the math but use different machinery to detect "already visited"; subtle off-by-one or partial-canonicalization bugs could differ.
- Performance regimes where `:multinomial_restricted`'s tighter restrictions on the bitmap (skip-disallowed-states) produce smaller working sets than the tree's per-node branching can match. The tree has constant per-node stabilizer-bookkeeping cost; the bitmap has constant per-slot O(1) random access. Different constants → different crossover behavior.
- Numerical-precision questions in the colex-rank arithmetic at very high concentrations — the bitmap allocates `binomial(n_total, a_1, ..., a_k)` slots, which can overflow `Int` even when the *valid* (restricted) count is small. The bitmap algorithm has to handle that defensively; the tree never allocates a bitmap.

If 6.5a or 6.5b surfaces a case the other can't handle, that's a real finding — bring it back here.

## 2. `:multinomial_restricted` design (chunk 6.5a)

### 2.1 The algorithm

From research.md §1043-1115 + Fortran `labeling_related.f90:310-512`:

1. **Allocate the multinomial bitmap** of size `M = n_total! / (a_1! · ... · a_k!)` — same as `:multinomial`. Bitmap entries map to labelings via the mixed-radix colex encoding (already implemented in `src/algorithms/multinomial.jl`).
2. **Build a site-restriction mask** `E :: BitMatrix(n_total, k)` where `E[i, j+1] = true` iff species `j` is allowed at site `i`. Per the dset-blocks layout, `E[i, :]` for sites in dset block `α` is the species mask `allowed_labels[α]`.
3. **Tree-walk the bitmap with backtracking pruning.** At each step the algorithm tracks the current partial labeling depth-by-depth; whenever a site would be assigned a species disallowed by `E`, the entire sub-branch (and its hash-table slot) is skipped without ever visiting.
4. **Crossing-out for orbit canonicalization** continues to use the existing perm-group → hash → mark-non-canonical machinery from `:multinomial`. The site-restriction mask just prunes the iteration; the symmetry crossing-out is unchanged.
5. **Super-periodicity** handled the same way as `:multinomial` (drop labelings fixed by a non-identity pure translation).

> All good

### 2.2 Code layout

- New file: `src/algorithms/multinomial_restricted.jl`. Exports `getUniqueColorings_multinomial_restricted(perm_group, multiplicities, site_mask; include_superperiodic)`.
- `src/enumerate.jl`: add a `_enumerate_multinomial_restricted` wrapper alongside the existing `_enumerate_multinomial` and `_enumerate_recursive_stabilizer`. Calls into `_enumerate_per_concentration` with the appropriate `coloring_fn`.
- `src/enumerate.jl`: `algorithm = :multinomial_restricted` no longer throws — dispatches to the new helper. `:auto` picks it when a per-site-restricted Sites is supplied.
- `_validate_enumerate_inputs`: regime-C branch flips from `throw(ArgumentError(...))` to falling through (mirrors R50.2b's regime-B flip).

### 2.3 Reuse from chunk 6

Chunk 6's `getUniqueColorings_multinomial` already:
- Allocates and crosses out the multinomial bitmap.
- Handles the colex-rank ↔ labeling conversions.
- Does the super-periodicity check.

The restricted variant *adds* the site-mask pruning. Likely cleanest: refactor chunk 6's core into a function that takes an optional `site_mask` kwarg; if not supplied, behaves identically to the current `:multinomial`. If supplied, prunes via the mask.

> I agree

### 2.4 Tests

**[Revision 2026-05-18]** Replacing the headline corpus with real Heusler / half-Heusler / perovskite cases (the original Diamond + HCP-inactive-sublattice examples are demoted to code-branch coverage only — those reduce to single-site FCC essentially, per your feedback).

Fortran-validated headline cases:

- **Half-Heusler (C1b structure, XYZ stoichiometry).** FCC parent with a 3-atom dset at standard half-Heusler positions: X at (0,0,0), Y at (1/4,1/4,1/4), Z at (3/4,3/4,3/4). Per-site `allowed_labels`:
  - X site: `{0, 1}` (binary X substitution, e.g., Ti ↔ Zr in TiCoSb ↔ ZrCoSb)
  - Y site: `{2}` (fixed, e.g., Co)
  - Z site: `{3}` (fixed, e.g., Sb)
  
  At n = 2, 4, 6 with concentration `[1//2, 1//2, 1//3, 1//3]` × `n_total/3` — wait, let me re-think the species-count mapping for the flat-vector. With 4 species total and n_cells supercell volume = 6n_cells total sites: 2*n_cells species-0, 2*n_cells species-1, 2*n_cells species-2 (fixed Y), 2*n_cells species-3 (fixed Z). Flat fractions `[1//6, 1//6, 1//3, 1//3]`. Concrete: at n_cells = 2, n_total = 6, multiplicities = [1, 1, 2, 2]. (Validate this against Fortran when capturing the reference counts.)

- **Full Heusler (L2₁ structure, X₂YZ stoichiometry).** FCC parent with a 4-atom dset; two X sites, one Y, one Z. Per-site `allowed_labels`:
  - X sites (positions 1, 2): `{0, 1}` (binary X substitution, e.g., Cu₂MnAl ↔ Cu·Pt·MnAl)
  - Y site (position 3): `{2}` (fixed)
  - Z site (position 4): `{3}` (fixed)
  
  Two restricted positions sharing the *same* allowed_labels — exercises Regime-C handling more thoroughly than half-Heusler (one restricted position) and prevents over-fitting to single-restricted-site cases. At n = 2, 3, 4 with binary X substitution at 50/50 on the X sublattice.

- **Perovskite ABO₃ (cubic Pm-3m).** Simple cubic parent with 5-atom dset: A at (0,0,0), B at (1/2,1/2,1/2), three O atoms at (1/2,1/2,0), (1/2,0,1/2), (0,1/2,1/2). Per-site `allowed_labels`:
  - A site: `{0, 1}` (binary, e.g., Sr ↔ Ba)
  - B site: `{2, 3}` (binary, e.g., Ti ↔ Zr)
  - O sites (×3): `{4}` (fixed oxygen)
  
  At n = 1, 2 (and 3 if affordable) with 50/50 on both A and B sublattices.

Code-branch coverage (not the headline reference cases):

- **Diamond with one inactive sublattice**: reduces to single-site FCC, but exercises the "inactive site as part of multi-site Sites" code branch. Add a single test case as a smoke check.
- **HCP with one inactive sublattice**: similar smoke check; exercises multilattice + Regime C path on a hex parent.

**[Revision 2026-05-18]** Test depth: go beyond total-count cross-checks against `enum.x`. Per your feedback, lock the following per-case in `test/test_enumerate.jl`:

- **Total configuration count** (the canonical 4793-style number).
- **Per-volume breakdown** (`count_inequivalent(...; breakdown = true).by_volume`).
- **Per-HNF breakdown** (`...by_hnf`). For each canonical HNF at each volume, the configuration count.
- **Per-concentration breakdown** (`...by_concentration`) for `ConcentrationRange` tests.
- **Cross-algorithm equality** between `:multinomial_restricted` and the extended `:recursive_stabilizer` — `Set(to_labeling.(e1)) == Set(to_labeling.(e2))` for every case.

The `count_inequivalent(...; breakdown = true)` API already exposes these (chunk-7); the Fortran reference dump also reports per-HNF rows. Cross-checking at this granularity should catch HNF-ordering bugs, per-supercell-stabilizer bugs, and label-rotation bugs that a total-count check would miss.

## 3. Extended `:recursive_stabilizer` design (chunk 6.5b)

### 3.1 The change

Currently the tree walk in `src/algorithms/recursive_stabilizer.jl` branches on `binomial(n_unfilled, a_here)` — *every* unfilled position is a candidate for color `depth`. The site-restricted extension:

- Filter `unfilled_positions` to those where color `depth` is allowed.
- The branching factor becomes `binomial(length(allowed_unfilled), a_here)`.
- If `allowed_unfilled < a_here`, this color is unsatisfiable at this depth — the branch is pruned (no leaf reached on this path, nothing added to the output list).

The `_inverse_colex_rank` machinery (`recursive_stabilizer.jl:96`) still works; the input set is just smaller.

> You keep using the word "emitting" when you talk about walking the tree. Is that standard terminology? Can you define it for me?

**[Revision 2026-05-18]** Replaced "emit" with plain "add to the output list" / "produce a result." For the record:

In tree-walk / backtracking algorithms, "emit" is informal jargon for *"the algorithm has reached a leaf node with a complete, valid result and adds that result to its output list."* It comes from the streaming-iterator idiom in functional programming (a generator that "emits" values one at a time) rather than from any specific algorithms-textbook tradition. It's interchangeable with "produce" or "output." I'll favor plain phrasings in the code comments and docstrings going forward.


### 3.2 Code layout

Extend the existing `getUniqueColorings_recursive_stabilizer` to accept an optional `site_mask :: BitMatrix` kwarg. When supplied, the inner loop filters. When omitted, behaves identically to today.

`_enumerate_per_concentration` (in src/enumerate.jl) constructs the mask from `sites` and passes it through to the coloring function for each supercell. The mask is per-supercell (size `n_D · n × k`) — built by replicating the per-dset-position `allowed_labels` across cells.

### 3.3 Tests

**[Revision 2026-05-18]** Same Fortran corpus as 6.5a (real half-Heusler / full Heusler / perovskite, plus the diamond-and-HCP inactive-sublattice smoke checks). Per-HNF / per-concentration / per-volume cross-validation against `enum.x`, as in §2.4. **Cross-algorithm equality** between `:multinomial_restricted` and the extended `:recursive_stabilizer`: `Set(to_labeling.(e1)) == Set(to_labeling.(e2))` for every Regime-C case. This cross-check is the load-bearing correctness test once both algorithms land — if they disagree, one of them is wrong, and the disagreement narrows down where the bug is.

## 4. Validation gate flip

`_validate_enumerate_inputs` (`src/enumerate.jl:354-377`): the regime-C branch currently throws

> `Multilattice with per-site allowed_labels (heterogeneous sublattices) requires the multinomial-restricted algorithm — chunk 6.5.`

After chunk 6.5:

- Drop the throw.
- Add validation: every dset position must have non-empty `allowed_labels` (probably already enforced at `Sites` construction).
- Resolve concentration species count `k` to the **union of all dset positions' allowed_labels**, not just `sites.list[1]` (which is what regime B uses). Reject if any position uses labels outside `0..k-1`.
- Algorithm dispatch: with concentration and a Regime-C Sites, `:auto` picks `:multinomial_restricted` if the bitmap fits, else `:recursive_stabilizer`. Same memory-budget logic as `:auto` today, but applied to the restricted bitmap size (which is `≤ unrestricted multinomial coefficient`).

## 5. Benchmark plan (after both land)

**[Revision 2026-05-18]** Add Section 5 to `bench/runbench.jl`:

- **Cross-algorithm head-to-head** on half-Heusler binary X-substitution at n = 2, 3, 4.
- Cross-algorithm on full Heusler binary X-substitution at n = 2, 3, 4.
- Cross-algorithm on perovskite 50/50 A and B sublattices at n = 1, 2.
- (Optional: spinel AB₂O₄ if tractable at n = 1.)

The two algorithms should produce the same counts; only the wall-clock and allocation summaries differ. Captured per-algorithm timings settle whether to keep both forever or whether one is strictly dominated by the other on real-world Regime-C cases. Side benefit: feeds into the v0.3+ ergonomics decision (if `:recursive_stabilizer` wins on every realistic case, the per-sublattice Concentration API can target it exclusively).

## 6. Open questions

**Q1 (split or bundle).** Should 6.5a and 6.5b be one commit or two? My lean: two — easier to bisect, easier to review, and the two algorithms cross-validate each other (when both land, run them on the same problem; they must agree).

> Two

**Q2 (order).** Implement 6.5b first (smaller change, unblocks Regime C immediately) or 6.5a first (matches the existing chunk numbering)? My lean: **6.5b first** — the extension is mechanically smaller and gives us a Regime-C-capable algorithm fast. Then 6.5a follows with cross-validation against 6.5b.

> 6.5b first

**Q3 (concentration handling).** When `allowed_labels` differs across dset positions, the `Concentration` constraint operates on the **union** of species. Should the user be allowed to specify e.g. `concentration = [Sr: 1/2, Ba: 1/2, Ti: 1, O: 3]` literally? Today's `Concentration([f₁, f₂, ...])` is a flat fractions vector; the species indices are implicit. For Regime C, do we keep the flat-vector semantics (with the species count = max allowed_labels + 1) and let the user encode "Ti = 1 of 1" naturally, or do we introduce a per-sublattice concentration?


My lean: **flat-vector semantics, no API change**. User specifies counts/fractions for *all* k species; sites with restricted allowed_labels just can't host the disallowed species, so those species' counts have to fit on the positions that *can* host them. Forcing the user to encode the consistency themselves matches HF 2012's behavior. Add a validation check that catches obvious unsatisfiability (e.g., "you asked for 4 atoms of species 2, but only 3 positions allow it") with an `EmptyEnumerationError`.

> Basically we are improving the 2012 algorithm to move complexity away from the user on input. Am I reading that right? Are we making any implicit restrictions we're not seeing? Are there use cases for which this new input will be really inconvenient?

**[Revision 2026-05-18]** Reading-check: I'd actually phrase it the *opposite* way. The flat-vector approach **leaves complexity on the user**, not on the algorithm. The user has to translate "50% A on the A sublattice" into the equivalent *global* fraction at the cell-size they have in mind. The algorithm gets a simple 1D vector and doesn't have to know about sublattices.

**Implicit restrictions we're not seeing:**

- **Species numbering is global, not per-sublattice.** If A site allows {Sr, Ba} and B site allows {Ti, Zr}, the user has to pick a global numbering (e.g., Sr=0, Ba=1, Ti=2, Zr=3, O=4). They can't reuse `0,1` for both sublattices. For two-species substitution on two sublattices that's harmless, but for many-sublattice problems the renumbering becomes mental gymnastics.
- **Inactive-site contributions are counted in the species multiplicities.** A perovskite ABO₃ at n_cells = 1 has 5 atoms: 1 A, 1 B, 3 O. If A is 50/50 Sr/Ba, the global species counts are `[0, 1, 1, 0, 3]` (one each of Sr or Ba, one each of Ti, zero Zr, three O — or some pattern matching what the user wants). The user has to include the "3 O" contribution explicitly in the Concentration. There's no `Sites`-level shortcut for "the fixed sublattices' contributions are pre-determined; just specify the substitutional sublattices."
- **Concentration totals must sum to 1 exactly.** With fixed sublattices, the achievable composition space is a *subset* of the simplex (because fixed atoms occupy known fractions). The user has to compute the available "free" fraction themselves — the API doesn't help.

**Use cases where the flat-vector input is genuinely inconvenient:**

- **Perovskite at 50/50 on both A and B sublattices, O fixed.** Per-sublattice description: `A: 1:1 (Sr,Ba)`, `B: 1:1 (Ti,Zr)`, `O: fixed`. Flat-vector: `Concentration([1//10, 1//10, 1//10, 1//10, 6//10])` at n_cells = 2 (n_total = 10: 1 Sr, 1 Ba, 1 Ti, 1 Zr, 6 O). The translation step is not hard, but it's error-prone — easy to forget that the O multiplicity has to be exactly `3 × n_cells` and have it accidentally drift.
- **Spinel AB₂O₄.** Three sublattices, ratios 1:2:4. Per-sublattice: `A: binary, B: binary, O: fixed`. Flat-vector: the user has to express each per-sublattice fraction *relative to the total*, not relative to the sublattice — so 50/50 A on the A sublattice becomes `1/14 each` of two species, etc. Easy to typo.
- **High-entropy alloys (HEAs) on multi-sublattice parents.** 5 elements on the A site, 3 on the B site, fixed Z. The user has to express 8 global fractions where the A-fractions necessarily sum to A-site total and similarly for B. Cross-sublattice constraints become implicit constraints on the input.

**Proposed path:** ship flat-vector for chunk 6.5 to get the algorithm working and match HF 2012's semantics. Queue a **per-sublattice `Concentration`** as a v0.3+ ergonomics improvement (similar in spirit to the R51 `Sites(parent, labels)` convenience constructors). The flat-vector and per-sublattice APIs would internally produce the same multiplicity vector — only the user-facing shape differs. That's strictly an *additive* improvement; no breakage.

A first sketch of what per-sublattice might look like:

```julia
Concentration(parent, sites,
    [ConcentrationOnSublattice(1, [1//2, 1//2]),
     ConcentrationOnSublattice(2, [1//2, 1//2]),
     ConcentrationOnSublattice(3, [1//1])])
```

or, even cleaner, attached to the `Sites` object itself:

```julia
sites = Sites(parent, [[0,1], [2,3], [4]];
              concentration = ([1//2, 1//2], [1//2, 1//2], [1//1]))
```

Both are fine ergonomic improvements for v0.3+; both expand to a flat-vector internally. Not part of chunk 6.5 scope.

> Sounds good. Let's not forget to revisit it.

**[Revision 2026-05-18]** Tracking added to `docs/notes/v0.2-plan.md` "v0.3+ shopping list" so the per-sublattice `Concentration` ergonomics improvement is captured as a discrete item with its own entry.

**Q4 (test corpus capture).** Capture the Fortran reference counts now (before implementing) or after? My lean: **before** — gives us locked-in targets to hit. Same workflow as R50.2b: build `struct_enum.in` for each test case, run Fortran `enum.x`, lock the per-volume counts in the design doc.
> Before, but more than just counts. Test over as many features as you can (see earlier comment)

**Q5 (does extending `:recursive_stabilizer` break the existing chunk-8 testset?).** The existing tests use it with no `site_mask` kwarg. If we default the kwarg to nothing/uniform, the behavior is unchanged. Risk: low.
> Default to nothing


## 7. Scope estimate

- **6.5a (`:multinomial_restricted`)**: ~150-250 lines of Julia, mostly refactoring chunk 6's `getUniqueColorings_multinomial` to accept a site mask. ~30 lines in `_validate_enumerate_inputs` for the regime-C flip. ~30 tests against Fortran corpus.
- **6.5b (extend `:recursive_stabilizer`)**: ~80-120 lines, localized to `recursive_stabilizer.jl` and a small dispatch update.
- **Validation gate + tests**: ~50 lines across `enumerate.jl` and test files.
- **Benchmark**: ~30 lines added to `bench/runbench.jl`.

Estimated wall-clock: one focused session for 6.5b, one or two for 6.5a (Fortran-cross-validation captures + the bitmap-mask refactor are the time sinks).

## 8. Numbered responses

**[Revision 2026-05-18]**

- **Q1** Two commits: confirmed.
- **Q2** 6.5b first: confirmed.
- **Q3** Flat-vector API: confirmed for chunk 6.5; expanded analysis of inconvenient cases (perovskite, spinel, HEAs) and a sketch of the per-sublattice ergonomics improvement queued for v0.3+.
- **Q4** Capture Fortran reference data before implementing — *more* than just counts: per-volume, per-HNF, per-concentration breakdowns. The cross-validation harness should match `enum.x`'s output rows by HNF, not just by summed totals. Confirmed.
- **Q5** Default `site_mask` to `nothing` in the extended `:recursive_stabilizer`: confirmed.

## 9. Pre-implementation workflow

**[Revision 2026-05-18]** Before any code lands:

1. Build three `struct_enum.in` files for the headline cases (half-Heusler, full Heusler, perovskite) at supercell volumes 1..4 (or 1..6 where tractable).
2. Run Fortran `enum.x` on each, capture:
   - Per-volume total counts.
   - Per-HNF breakdowns (the `struct_enum.out` row-per-canonical-HNF format).
   - The `lab_degen × hnf_degen` columns for each row (so cross-validating the degeneracy-tracking R33 + Supercell.hnf_degeneracy plumbing too).
3. Lock the numbers in this design doc as a §10 "Fortran reference corpus" section.
4. *Then* implement 6.5b (extended `:recursive_stabilizer`), cross-checking against the locked numbers.
5. Then 6.5a (`:multinomial_restricted`), cross-checking against both the locked numbers and 6.5b's output (set-equality).
6. Add bench Section 5.
