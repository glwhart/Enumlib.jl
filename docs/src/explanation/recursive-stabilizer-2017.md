# Recursive stabilizer (Morgan-Hart 2017)

`:auto`'s default for almost everything. Drawn from Morgan & Hart, *A recursive method for enumerating derivative structures*, J. Stat. Mech. 053401 (2017). A tree walk over partial colorings using progressively-shrunken stabilizer subgroups. Doesn't need a bitmap, so it dominates the [HF 2008](exhaustive-2008.md) / [HF 2012](multinomial-2012.md) algorithms when the bitmap stops fitting in memory — and bench Section 5 settles empirically that it beats them by 2-3× even when the bitmap *would* fit.

## The idea

Both HF 2008 and HF 2012 materialize a bitmap over the *whole* labeling space (size `k^n` or `M = multinomial coefficient`) and stream-iterate it, crossing off non-canonicals as they go. That's optimal when the bitmap fits — `O(1)` random access, dense storage. But when `k^n` (or `M`) exceeds the memory budget, the bitmap can't be allocated and the algorithm fails before it starts.

The recursive-stabilizer algorithm replaces the bitmap with a **tree** of partial colorings. At each tree level, the algorithm:

1. Picks the next supercell position (in a fixed order).
2. For each species `s` allowed at that position, builds a candidate partial coloring.
3. Computes the stabilizer subgroup of that partial coloring — the permutations that fix what's been assigned so far.
4. Decides whether to keep the candidate or prune it as non-canonical (i.e., some smaller permuted version of it was already visited).
5. Recurses into the candidate.

Leaves (fully-assigned colorings) emit one canonical orbit representative.

## Why the stabilizer shrinks

As positions get assigned, fewer group elements can preserve the labeling. The permutations that *don't* preserve the assigned positions are dropped — they can't fix any completion of the partial coloring either. The stabilizer at the root is the full group `G`; at the leaves it's typically trivial.

This is the algorithm's name: each tree node carries the *stabilizer subgroup* of its partial coloring, recursively shrunken from the parent.

## When this fires

`algorithm = :auto` picks the recursive-stabilizer tree in nearly every situation:

- **No concentration kwarg** — `:auto` synthesizes a full-range `ConcentrationRange` internally and runs the tree across it. Bench Section 5 measures ~2-3× speedup and ~½ memory vs `:exhaustive` on FCC binary/ternary and HCP binary at sizes n=4–12.
- **Heterogeneous sublattices (Regime C)** — the tree scales by the valid-colorings subspace; the `:multinomial_restricted` bitmap iterates the full multinomial coefficient and ends up ~9-60× slower on the perovskite / Heusler corpus (bench Section 4).
- **Fixed concentration + multinomial bitmap exceeds 80% of `memory_budget`** — the bitmap can't be allocated; the tree streams instead. (The `_multinomial_bitmap_fits` helper checks the worst-case bitmap across all in-range concentrations.)

The remaining case — fixed concentration with a small bitmap — still goes to `:multinomial` because the bitmap's tighter constants edge out the tree at that scale (bench Section 2). The boundary is the memory-budget check.

## Cost

- **Time.** Worst-case `O(|G| · output_count · n)` — for each emitted structure, the tree walk does `O(|G|·n)` of partial-coloring stabilizer checks. In practice this is *much* faster than HF 2012 once the bitmap doesn't fit, because the tree skips entire subtrees when the partial coloring is identified as non-canonical early.
- **Memory.** Streaming — only the current branch's partial coloring + stabilizer subset live in memory at once. The resource check's tree-mode prediction is `total_count × n × Int_overhead` as a conservative upper bound; this is deliberately loose, and the output term (= the final `Vector{EnumeratedStructure}`) dominates in practice.

For a back-of-envelope: at `n = 48` binary 24:24, `M = C(48, 24) ≈ 7.6 · 10^13` — the bitmap is ~9 TB, infeasible. The recursive-stabilizer tree handles the same problem in single-digit GB of working memory.

## Validation against HF 2012

The Enumlib testsuite asserts that for every problem where *both* algorithms apply, they produce identical structure sets (up to ordering of the output vector). The Morgan-Hart 2017 tree is *guaranteed* equivalent to HF 2012's bitmap-canonicalization at the math level; the testsuite makes that operational.

## When the bitmap still wins

The single remaining case where `:auto` picks a bitmap algorithm is fixed-concentration enumeration where the multinomial bitmap comfortably fits the memory budget. Bench Section 2 measures `:multinomial` and `:recursive_stabilizer` roughly tied for FCC binary at n=4/8/12 — sometimes the bitmap wins by 10-20%, sometimes the tree does. The dispatch defers to the bitmap there for two reasons:

1. **Constants.** The bitmap's `O(1)` random access has tighter constants than the tree's per-node stabilizer-subset bookkeeping when the bitmap fits.
2. **Predictability.** The bitmap's runtime is determined entirely by `|G|·M`; the tree's runtime depends on how aggressively partials get pruned, which is more problem-shape-dependent.

The `algorithm = :auto` dispatch picks the bitmap when it fits and switches to the tree when it doesn't.

## See also

- [Algorithm overview](algorithm-overview.md)
- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — the bitmap algorithm the tree replaces.
- [Dispatch and the resource check](dispatch-and-cost-gate.md) — how `algorithm = :auto` picks.
- [Pick an algorithm](../how-to/pick-an-algorithm.md) — recipe.
