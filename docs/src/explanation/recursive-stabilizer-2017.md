# Recursive stabilizer (Morgan-Hart 2017)

The chunk-8 algorithm, drawn from Morgan & Hart, *A recursive method for enumerating derivative structures*, J. Stat. Mech. 053401 (2017). A tree walk over partial colorings using progressively-shrunken stabilizer subgroups. Doesn't need a bitmap, so it dominates the [HF 2008](exhaustive-2008.md) / [HF 2012](multinomial-2012.md) algorithms when the bitmap stops fitting in memory.

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

`algorithm = :auto` picks the recursive-stabilizer tree when:

- A [`Concentration`](@ref) is supplied (so the search is shape-bounded — without a concentration, the unrestricted exhaustive sweep is the default), AND
- The multinomial bitmap `M = n! / (a_1! · ... · a_k!)` would exceed the memory budget. (More precisely: the `_multinomial_bitmap_fits` helper checks whether the worst-case bitmap across all in-range concentrations fits in 80% of the memory budget.)

For unrestricted (no-concentration) enumerations, this algorithm doesn't currently apply — the exhaustive sweep stays the default. Lifting that restriction is queued for chunk 8b polish.

## Cost

- **Time.** Worst-case `O(|G| · output_count · n)` — for each emitted structure, the tree walk does `O(|G|·n)` of partial-coloring stabilizer checks. In practice this is *much* faster than HF 2012 once the bitmap doesn't fit, because the tree skips entire subtrees when the partial coloring is identified as non-canonical early.
- **Memory.** Streaming — only the current branch's partial coloring + stabilizer subset live in memory at once. The resource check's tree-mode prediction is `total_count × n × Int_overhead` as a conservative upper bound; per chunk-7.5 design Q6 this is deliberately loose, and the output term (= the final `Vector{EnumeratedStructure}`) dominates in practice.

For a back-of-envelope: at `n = 48` binary 24:24, `M = C(48, 24) ≈ 7.6 · 10^13` — the bitmap is ~9 TB, infeasible. The recursive-stabilizer tree handles the same problem in single-digit GB of working memory.

## Validation against HF 2012

The chunk-8 testsuite asserts that for every problem where *both* algorithms apply, they produce identical structure sets (up to ordering of the output vector). The Morgan-Hart 2017 tree is *guaranteed* equivalent to HF 2012's bitmap-canonicalization at the math level; the testsuite makes that operational.

## Why not the default

Three reasons HF 2012's bitmap stays the default when it fits:

1. **Constants.** The bitmap's `O(1)` random access has tighter constants than the tree's per-node stabilizer-subset bookkeeping.
2. **Predictability.** The bitmap's runtime is determined entirely by `|G|·M`; the tree's runtime depends on how aggressively partials get pruned, which is more problem-shape-dependent.
3. **Memory budget allowing.** The bitmap fits comfortably for the cases practitioners hit most often; ceding to the tree when it does fit would leave performance on the table.

The `algorithm = :auto` dispatch is calibrated to ride the bitmap until it stops fitting, then switch.

## See also

- [Algorithm overview](algorithm-overview.md)
- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — the bitmap algorithm the tree replaces.
- [Dispatch and the resource check](dispatch-and-cost-gate.md) — how `algorithm = :auto` picks.
- [Pick an algorithm](../how-to/pick-an-algorithm.md) — recipe.
