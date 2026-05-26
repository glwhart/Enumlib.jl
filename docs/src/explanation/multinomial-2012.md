# Multinomial mixed-radix hash (HF 2012)

Drawn from Hart, Nelson, & Forcade, *Generating derivative structures at a fixed concentration*, Comp. Mat. Sci. 59, 101 (2012). When the user pins a concentration, iterate only the labelings at that concentration via a mixed-radix encoding over the multinomial coefficient — drastically cheaper than exhaustive when the multinomial is small relative to `k^n`.

## When this fires

[`enumerate`](@ref) chooses the multinomial algorithm when:

- A [`Concentration`](@ref) is passed (so the multiplicity vector `[a_1, ..., a_k]` is known per supercell), AND
- The bitmap for the multinomial coefficient `n! / (a_1! · ... · a_k!)` fits in the memory budget.

For [`ConcentrationRange`](@ref), the algorithm runs once per in-range concentration; the [partition-explosion gate](#partition-explosion) below caps how many that can be.

## Why a separate algorithm

The exhaustive algorithm visits every labeling in `k^n` regardless of composition. For binary 50/50 at `n = 12`, only `C(12, 6) = 924` of the `2^12 = 4096` labelings have the right composition — exhaustive wastes 77% of its work crossing off wrong-composition labelings. As `n` grows the ratio gets worse: `C(20, 10) / 2^20 ≈ 18%`; `C(40, 20) / 2^40 ≈ 0.013%`.

The multinomial algorithm encodes the *concentration-restricted* labeling space directly via a mixed-radix index, so it never visits a wrong-composition labeling.

## The encoding

A labeling at fixed multiplicities `[a_1, ..., a_k]` is one of `M = n! / (a_1! · ... · a_k!)` distinct arrangements of those species. Index them by **colex rank**: list positions in decreasing order; for each position, ask "of the unplaced species, how many distinct labelings remain if I commit this position to species `s`?" The cumulative answers index a unique integer in `[0, M)`.

Concretely, the inverse (rank → labeling) builds the labeling position-by-position, tracking the remaining multiplicities; the forward (labeling → rank) reverses this. Cost of each direction is `O(n · k)`. The algorithm uses both: the forward to canonicalize-and-cross-off, the inverse to iterate.

## The hash-canonicalization step

Same structure as the [exhaustive HF 2008](exhaustive-2008.md) algorithm:

```
hashTbl = trues(M)                       # M = multinomial coefficient
for r in 0:(M - 1):
    if not hashTbl[r]: continue
    c = decode_colex(r, multiplicities)
    for g in G[2:end]:
        s = encode_colex(g · c, multiplicities)
        if s > r:
            hashTbl[s] = false
        elif s == r and is_pure_translation(g):
            hashTbl[r] = false
            break
canonical_ranks = findall(hashTbl)
```

The only difference from exhaustive: the iteration variable is over `M` ranks at the target concentration, not over `k^n` labelings.

## Cost

- **Time.** `O(|G| · M · n)` — for each of the `M` ranks, apply each of `|G|` group elements (cycle-shifted via colex rank arithmetic in `O(n)`).
- **Memory.** `O(M / 8)` for the bitmap + output.

For FCC binary 4:4 at `n = 8`: `M = C(8, 4) = 70`, runtime is sub-second. For binary 16:16 at `n = 32`: `M ≈ 600M`, the bitmap is ~75 MB, still tractable. Past `M ≈ 10^10` the bitmap stops fitting and the [recursive-stabilizer algorithm](recursive-stabilizer-2017.md) takes over.

## Partition explosion

A [`ConcentrationRange`](@ref) at a given supercell volume decomposes into one [`Concentration`](@ref) per multiplicity vector in the range. For binary at `n = 32` with the full range `[(0,1), (0,1)]`, that's 33 individual concentrations (`a_1 = 0, 1, 2, ..., 32`). For ternary at `n = 12` with the full range, that's `C(12+2, 2) = 91` multiplicity vectors. The count grows roughly like `C(n+k-1, k-1)`.

Enumlib limits this with a `partition_threshold` kwarg on `enumerate(...)` (default: 50). If the range decomposes into more partitions than the threshold, the response is one of:

- `:error` (default) — throw `PartitionExplosionError` with the decomposition count.
- `:warn` — `@warn` and continue.
- `:ignore` — silently continue.

Users who hit the threshold typically want to either tighten the range or pass `on_partition_overflow = :ignore`.

## Multilattice extension

For multilattice parents (`n_D ≥ 2`), the labeling space is `n_total = n_D · n` positions. The multinomial coefficient is `n_total! / (a_1! · ... · a_k!)` and the colex encoding is unchanged in shape — just with `n_total` in place of `n`. `multiplicities(c, n_total)` and friends resolve against the larger total.

## See also

- [Algorithm overview](algorithm-overview.md)
- [Exhaustive enumeration (HF 2008)](exhaustive-2008.md) — the unrestricted variant.
- [Recursive stabilizer (Morgan-Hart 2017)](recursive-stabilizer-2017.md) — when the multinomial bitmap also stops fitting.
- [Concentration and multiplicity](concentration-and-multiplicity.md) — the type layer above.
- [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md) — the partition-explosion gate in practice.
