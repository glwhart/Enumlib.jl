# Chunk 8 — Recursive-stabilizer tree (Morgan 2017) (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §4.4 (Morgan-Hart-Forcade 2017 algorithm digest), §5.4 (auto-dispatch decision tree); `papers/MorganHartForcade2017_recStabEnumeration.pdf`. Plus chunk 6 multinomial-hash machinery (location-vector hash is the same primitive); chunk 7.5 cost-gate (we add the memory prediction for the new algorithm).

**Goal:** the v0.2.0 milestone — add the third enumeration algorithm so `enumerate(...)` can handle high-configurational-freedom cases (large $n$, $k \ge 3$) that overflow the chunk-5/6 bitmap. Morgan 2017's tree-search-with-shrinking-stabilizers is asymptotically two orders of magnitude faster than the 2012 algorithm at FCC ternary $n = 20$, and unlocks cell sizes that were previously unreachable.

After chunk 8: `algorithm = :recursive_stabilizer` is a real choice; `:auto` dispatch picks it for cases that exceed a threshold; `count_inequivalent` doesn't need a corresponding tree (Pólya already handles counting cheaply); chunk 7.5's cost-gate has a memory model for it.

This is a **bigger chunk than 6 or 7** — Morgan 2017's algorithm is a substantial new piece of machinery. Estimating ~400 lines of source + ~50 tests. Possibly two sessions.

---

## Background — what the tree gives us

The 2008 / 2012 algorithms generate the *whole* labeling table and prune duplicates leaf-by-leaf. Memory and time scale with the table size — i.e., $k^n$ or $\binom{n}{a_1, \ldots, a_k}$ — even when the unique-structure count is much smaller.

Morgan 2017 observes that for high configurational freedom (large $n$, $k \ge 3$), the table grows much faster than the unique count, and most of the work is wasted. The fix: **build the table as a tree, color by color**, and prune entire subtrees of equivalents in one comparison.

**Two key ideas:**

1. **Partial colorings.** A node at depth $\ell$ has placed colors $1, \ldots, \ell$. All children share the partial. If a partial is symmetry-equivalent to one already saved at this level, *every* full coloring beneath it is a duplicate too — prune the whole subtree.

2. **Shrinking stabilizers.** The *stabilizer* of a partial coloring is the subgroup of the parent's symmetry group that fixes the placed colors. The stabilizer shrinks monotonically with depth — by the time you've placed two colors, the symmetries fixing both are a subgroup of those fixing just one. The duplicate check at depth $\ell$ uses only the parent's stabilizer (not the full point group), and that's a *smaller* group as you go deeper.

Together: comparisons get cheaper with depth even as branch count grows. Memory is $O(\text{depth} + \sum_\ell |\text{unique partials at level } \ell|)$, far less than $O(\text{full table})$.

**Empirical wins from the paper (Fig. 5):** at FCC ternary equal concentration, the tree catches the 2012 algorithm around $n = 5$ and pulls ahead, reaching 100× faster at $n = 20$. At quaternary, similar. The 9-atom worked example: 1260 candidate full colorings; Pólya count is 24 unique; the tree explores only 106 of 1296 candidate nodes.

**Critical reuse:** the location-vector hash used to identify partial colorings is *exactly* the 2012 multinomial mixed-radix hash (chunk 6's `multinomial_hash`). Applied per-level, with the depth-$\ell$ "alphabet" being just colors $1, \ldots, \ell$. So chunk 8 builds *on top of* chunk 6, not as a replacement.

---

## What lives in chunk 8

### 1. `src/algorithms/recursive_stabilizer.jl` — the tree (~300–400 lines)

```julia
"""
    Tree

Recursive-stabilizer enumeration tree (Morgan 2017). Walks a tree where each level places one color of the target multiplicity vector, with stabilizer-subgroup pruning at each node.

Internal type — not part of the public API. Drives `getUniqueColorings_recursive_stabilizer`.
"""
mutable struct Tree
    multiplicities::Vector{Int}              # a_1 ≤ a_2 ≤ ... ≤ a_k (sorted)
    n::Int                                   # = sum(multiplicities)
    k::Int                                   # number of colors
    perm_group::Vector{Vector{Int}}          # parent symmetry group on n positions
    loc::Vector{Int}                         # current location vector (depth-tagged)
    branches::Vector{Int}                    # branching factor at each depth
    stabilizers::Vector{Vector{Vector{Int}}} # one per depth — subgroup that fixes that depth's partial
    unique_locs::Vector{Vector{Vector{Int}}} # saved unique location vectors per depth
    output::Vector{Vector{Int8}}             # full colorings (depth k)
end

# Initialize at the root (no colors placed; full perm_group is the stabilizer).
function Tree(perm_group, multiplicities)
    sorted = sort(multiplicities)            # smallest concentration first (paper §3, step 1)
    n = sum(sorted)
    k = length(sorted)
    Tree(sorted, n, k, perm_group, Int[],
         [binomial(n - sum(sorted[1:l-1]), sorted[l]) for l in 1:k],
         Vector{Vector{Vector{Int}}}(undef, k+1),
         [Vector{Vector{Int}}() for _ in 1:k],
         Vector{Vector{Int8}}())
end

# Public driver — analog of getUniqueColorings_multinomial from chunk 6.
function getUniqueColorings_recursive_stabilizer(perm_group, multiplicities;
                                                  include_superperiodic = false)
    t = Tree(perm_group, multiplicities)
    t.stabilizers[1] = perm_group            # full group at root
    _enumerate_subtree!(t, 1, include_superperiodic)
    return t.output
end

# Recursive descent.
function _enumerate_subtree!(t::Tree, depth::Int, include_superperiodic)
    # ... walk children at this depth, compute location-vector for each,
    # apply stabilizer to check duplicate, descend on representatives.
end
```

**Key internal pieces:**

- **`_location_vector(coloring, depth, multiplicities)`** — at depth $\ell$, the partial coloring places colors $1, \ldots, \ell$. The location vector is `[x_1, x_2, ..., x_\ell]` where each `x_i` is the multinomial-rank of color $i$'s positions among the slots not yet filled by colors $1, \ldots, i-1$. This is exactly chunk 6's `multinomial_hash`, applied to the partial.
- **`_is_canonical(loc, parent_stabilizer, multiplicities, depth)`** — walks the parent's stabilizer; for each $g$, computes $g \cdot \text{loc}$ (the location vector of the permuted partial); if any image is lexicographically smaller, this loc is a duplicate (prune). Otherwise it's a canonical representative.
- **`_compute_stabilizer(parent_stabilizer, loc, multiplicities, depth)`** — the subgroup of `parent_stabilizer` that maps `loc` to itself. Linear walk through the parent group; filter.
- **Super-periodicity** — same as chunks 5/6: at the leaf level, drop colorings fixed by any non-identity translation (when `include_superperiodic = false`).

### 2. `enumerate(...)` extended in `src/enumerate.jl`

Add the new algorithm body:

```julia
function _enumerate_recursive_stabilizer(parent, sites, hnfs, k, concentration,
                                          partition_threshold, on_partition_overflow;
                                          include_superperiodic = false)
    # Mirror _enumerate_multinomial's HNF + concentration sweep, but call
    # getUniqueColorings_recursive_stabilizer instead of getUniqueColorings_multinomial.
end
```

Plus the dispatch wiring: `algorithm = :recursive_stabilizer` is no longer rejected; `:auto` picks it per the rule below.

### 3. `:auto` dispatch update

Per Phase 5 §5.4, `:auto` should pick `:recursive_stabilizer` when the predicted memory for `:multinomial` exceeds `memory_budget` (because the tree streams; no bitmap). Concrete decision rule:

```
:auto with concentration:
  - cost_estimate at :multinomial → bitmap = binomial(n; mults) bits
  - if bitmap_bytes > memory_budget × 0.8 (rule of thumb):
      pick :recursive_stabilizer
    else:
      pick :multinomial
```

The 0.8 fudge factor leaves headroom for output + scratch. Open question Q5 below.

### 4. Cost-gate prediction for `:recursive_stabilizer`

`_predict_peak_memory` (chunk 7.5) gains a branch for the new algorithm:

```
:recursive_stabilizer peak ≈
   sum_{l=1..k} sizeof(saved_partial_at_l) × num_unique_partials_at_l
   + output (same upper bound as :multinomial)
```

The `num_unique_partials_at_l` is unknowable a priori (it's the count we're trying to compute). For the cost estimate, use a rough upper bound: `total_count × depth × position_size`. Conservative.

### 5. Tests planned (`test/test_recursive_stabilizer.jl`)

- **The Morgan 2017 §3 worked example.** 9-atom 2D cell with multiplicities [2, 3, 4]; expected 24 unique structures (per Pólya / per the paper). Hand-verifiable.
- **Cross-validation against `:multinomial` at every chunk-6 reference.** For each (parent, sites, n, multiplicities) tuple where chunk 6 has a locked count, `:recursive_stabilizer` returns the same number on both kwarg branches. ~16 cases.
- **Cross-validation against `polya_count`** at the same cases.
- **`:auto` picks `:recursive_stabilizer` when the multinomial bitmap would exceed `memory_budget`.**
- **The Ag–Pt 15:17 32-cell case** — finally runnable as enumeration. The paper's Fig. 5 timing suggests this should finish in seconds-to-minutes. Locks the actual count (whatever chunk-7's `count_inequivalent` already says: ~1.2 billion at full sweep, smaller per-HNF). **This is the load-bearing real-test that chunk 7.5 Q6 anticipated.**

Total: ~50 new tests. Expected total after chunk 8: 515 + ~50 = ~565.

---

## What's deliberately NOT in chunk 8

- **Arrow / displacement enumeration.** Per user instruction (`research.md` §4.4 implementation map), we don't port the arrow extension. Color-only tree.
- **Site-restricted tree (per-site `allowed_labels`).** Chunk 6.5 territory. The tree algorithm needs adjustment for site restrictions; current chunk 8 is single-site only.
- **Multilattice tree.** v0.3.
- **BDD / ZDD (`:bdd`).** v0.3.

---

## Open questions for you

### Q1 — Scope: fixed-concentration only, or also handle no-concentration via tree?

Morgan 2017's tree branches over color placement *at fixed multiplicities*. The unrestricted (no-concentration) case doesn't naturally fit — there's no "first place all the reds, then the yellows" because there's no fixed red count.

**A.** Fixed-concentration only. The tree is wired in only when `concentration !== nothing`. For unrestricted, `:exhaustive` (chunk 5) remains the only choice; `:auto` doesn't pick the tree for no-concentration cases.

**B.** Extend the tree to support unrestricted by treating it as "all multinomial partitions of $n$ into $k$ parts" — essentially loop the tree over all $\binom{n+k-1}{k-1}$ multiplicity vectors. Bigger chunk; more code.

**My lean: A.** Matches the paper's formulation. The unrestricted case at large $n$ is rare in practice (users typically have concentration constraints from physics). If it becomes a real need, B can be a v0.3 chunk.

> A. But we should see if this algorithm is sometimes faster, even for full concentration. Maybe we should switch over sometimes. We can test that later

### Q2 — `algorithm = :recursive_stabilizer` for `count_inequivalent`?

The Polya counter (chunk 7) handles all counting cases — orbit count and aperiodic count, both branches. The tree doesn't add a count primitive; it speeds up *enumeration*.

**A.** `count_inequivalent` doesn't take an `algorithm` kwarg (chunk 7 Q6-A locked that). No change in chunk 8.

**B.** Add `algorithm = :recursive_stabilizer_count` for users who want a tree-based count alternative. Probably no real use case.

**My lean: A.** No change.

> A

### Q3 — Submodule (like `Polya`) or flat (like `multinomial.jl`)?

Morgan 2017's tree is closely tied to chunk 6's multinomial machinery (uses the same hash, lives in the same algorithmic family). Not really extraction-eligible (tied to chunk 5/6 perm-group format).

**A.** Flat — single file `src/algorithms/recursive_stabilizer.jl`, `Tree` struct + helpers in the top-level Enumlib namespace. Matches `multinomial.jl`.

**B.** Submodule `Enumlib.RecursiveStabilizer` — more separation, but the gain is small.

**My lean: A.** Less ceremony for code that won't extract.

> A

### Q4 — `Tree` struct: mutable + in-place updates, or immutable + copy-on-step?

Morgan 2017's Fortran `tree_class.f90` uses an OO mutable tree. Idiomatic Julia could go either way.

**A.** Mutable struct with in-place updates (`next!`, `descend!`, `backtrack!`). Matches the Fortran; faster (no allocation per step).

**B.** Immutable struct, return new instances on each step. Cleaner functional style; more allocations.

**My lean: A.** The tree algorithm has nontrivial state (location vector, stabilizer stack, unique-partials per level); copy-on-step would allocate per node. Mutable is the right Julia idiom here. Internal type (not user-facing), so the mutability isn't an API concern.

> A

### Q5 — `:auto` threshold for picking `:recursive_stabilizer` over `:multinomial`?

When does `:auto` pick the tree? Phase 5 §5.4 says "when the bitmap would exceed memory_budget." But the bitmap is *exact* and known; the tree's memory is harder to predict.

**A.** Simple rule — `:auto` picks `:recursive_stabilizer` when `multinomial_count(mults) ÷ 8 > memory_budget × 0.8`. Otherwise `:multinomial`. The 0.8 fudge factor leaves headroom for output + scratch.

**B.** More sophisticated — use the chunk-7.5 cost estimator to compare both algorithms' predicted peak; pick the smaller.

**C.** Always prefer the tree for fixed-concentration cases (since it's always asymptotically better past $n \approx 5$). Use `:multinomial` only when explicitly requested.

**My lean: A** for chunk 8. B is more elegant but adds dispatch complexity for marginal gain. C overcommits — `:multinomial` is genuinely faster at small $n$ (no per-level overhead). The 0.8 threshold is a starting point; we can tune in v0.3 with usage data.

> A

### Q6 — Memory prediction for `:recursive_stabilizer` — conservative bound, or proportional-to-output?

The tree's memory is hard to predict precisely. Two approaches:

**A.** Conservative upper bound: `total_count × n × sizeof(Int8) + total_count × depth × Int_overhead`. Treats output buffer as the dominant term; ignores per-level partial-saving.

**B.** Proportional to per-level unique partials. Closer to actual but harder to predict — you don't know per-level counts until you enumerate.

**My lean: A.** The cost-gate's job is "refuse to allocate more than the budget," not "predict actual usage to the byte." Conservative wins because it errs toward safety.

> A, if this is too conservative, we can back off later.

### Q7 — How aggressive should the Ag–Pt 15:17 32-cell test be?

Chunk 7.5's Q6 anticipated a "real test" of the cost gate. Chunk 8 makes the Ag–Pt enumeration tractable for the first time. Per chunk 7's analysis, count is ~1.2 billion at the full HNF sweep — too big to enumerate. But per single canonical HNF (the 2x2x2 conventional cell) with `:recursive_stabilizer`, it's much smaller.

**A.** Skip Ag–Pt entirely in chunk 8 tests. Defer to v0.2.0 polish.

**B.** Pick a single HNF and test — `count_inequivalent` already gives the right number per HNF. `enumerate(...; supercells = ExplicitHNFs([h]))` should produce that count.

**C.** Run the full sweep at a single concentration `[15, 17]` — even if it takes minutes — as the load-bearing v0.2.0 reference test. Mark it as a "slow" test that runs in CI's overnight tier.

**My lean: B.** Pick one HNF (the simplest — the canonical 2x2x2 cubic supercell, SNF (2, 2, 2) or similar at n=8 primitive cells × 4 = 32 atoms). Lock the per-HNF count. Fast enough for the test suite. C is good for v0.2.0 polish but slows down ordinary `Pkg.test()` runs.

> C, for now. Back off  if necessary after trying it once.

### Q8 — Concrete chunk-size: one chunk, or split chunk 8 into 8a (tree mechanics) + 8b (`:auto` integration + Ag-Pt test)?

Morgan 2017's algorithm has a lot of moving pieces. Splitting into:
- **Chunk 8a:** the `Tree` struct + the tree-walking algorithm + a single hand-verifiable test (Morgan §3 worked example) + cross-validation against `:multinomial` at chunk-6 references. ~250 lines.
- **Chunk 8b:** `:auto` dispatch update + `_predict_peak_memory` extension + Ag-Pt test + edge cases. ~150 lines.

**A.** Split into 8a + 8b. Each focused diff easier to review.

**B.** One chunk 8. Bigger diff but everything lands together.

**My lean: A** — same reasoning as the chunk-7 / chunk-7.5 split. Smaller chunks → more thorough review. "Smaller chunks are easier to review without the human becoming lazy or complacent" (your words from chunk 7 Q1).

> A

---

## Implementation plan (depends on Q1, Q3, Q5, Q7, Q8)

If A on every Q (my leans):

1. **Chunk 8a** — Pólya-tree mechanics:
   - `src/algorithms/recursive_stabilizer.jl` — `Tree` struct + `getUniqueColorings_recursive_stabilizer` + helpers (location vector, canonicality check via parent stabilizer, stabilizer descent).
   - `src/enumerate.jl` — drop the `:recursive_stabilizer` rejection; add `_enumerate_recursive_stabilizer` body; un-reject in `estimate_cost` too.
   - `src/Enumlib.jl` — include + export the public surface.
   - `test/test_recursive_stabilizer.jl` — Morgan §3 worked example (24 unique on the 9-atom 2D cell); cross-validation against `:multinomial` at every chunk-6 FCC reference (both kwarg branches).
   - Run all tests. Expect 515 + ~30 = ~545.
2. **Chunk 8b** — dispatch + cost-gate + Ag–Pt:
   - `src/enumerate.jl` `:auto` rule update — pick `:recursive_stabilizer` when the multinomial bitmap exceeds `memory_budget × 0.8`.
   - `_predict_peak_memory` extended with the tree-memory bound.
   - `test/test_cost_estimate.jl` extended — verify `:auto` picks the tree at the right boundary.
   - `test/test_recursive_stabilizer.jl` extended — Ag–Pt 15:17 at a single canonical HNF, locked count via `count_inequivalent` for that HNF.
   - Run all tests. Expect ~545 + ~15 = ~560.
3. Update `docs/notes/v0.2-plan.md` — chunks 8a and 8b → done; **v0.2 algorithmic milestone closed**. Move on to Phase 9 (pymatgen integration) and Phase 11 (POSCAR writers) for v0.2.0.

**Estimated:** two focused sessions (one per sub-chunk).

---

## After your sign-off

- Implementation lands as `Chunk 8a: Recursive-stabilizer tree (Morgan 2017)` and `Chunk 8b: :auto dispatch + cost gate + Ag-Pt regression`.
- Per-chunk review docs as usual.
- After chunk 8 lands: v0.2 algorithmic milestones closed. v0.2.0 release work (Phase 9 + Phase 11 + Phase 12) begins.

**Sign off below or annotate Q1–Q8 inline:**

Your response:
