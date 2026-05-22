# Exhaustive enumeration (HF 2008)

The original Enumlib algorithm, drawn from Hart & Forcade, *Algorithm for generating derivative structures*, PRB 77, 224115 (2008). Iterate every coloring; canonicalize each into an orbit representative; emit one per orbit. The simplest of the four algorithms; the natural reference implementation for the unrestricted enumeration problem.

!!! note "No longer `:auto`'s default"
    Through v0.2 this was the default for unrestricted enumeration. Bench Section 5 (2026-05-22) showed `:recursive_stabilizer` over a synthesized full-range `ConcentrationRange` is ~2-3× faster and uses ~½ the memory across the cases measured, so as of v0.3 `:auto` defaults to the tree. `:exhaustive` remains available as an explicit `algorithm =` choice for cross-checks and pedagogy — and is still the most direct presentation of the original 2008 algorithm.

## The setup

For each chosen supercell:

1. **Supercell sites are labeled `1..n` in SNF coordinates.** From `U · h · V = S` with `S = diag(d_1, ..., d_D)`, site `(i_1, ..., i_D)` in SNF coords maps to parent-lattice integer position `U^{-1}·(i_1, ..., i_D)`. The flat index iterates `i_D` fastest, `i_1` slowest, so site `m` is at SNF-coord `(i_1, i_2, i_3) = (m-1) ÷ (d_2·d_3), …`.
2. **Each site can carry `k` species** (`{0, 1, ..., k-1}`). The labeling space is `Z_k^n`, isomorphic to integers `0 ≤ x < k^n` via the mixed-radix encoding `x = Σ_i color[i]·k^{n-i}`.
3. **The supercell permutation group `G`** comes from parent-symmetry rotations that fix the superlattice, composed with the supercell translation subgroup. `G` acts on the `n` site indices by permuting them; that action lifts to an action on labelings by permuting colors-at-positions.

## The hash-canonicalization step

A labeling `c` and its image `g · c` under any `g ∈ G` represent the same derivative structure. The algorithm picks one canonical representative per orbit by the rule:

> *The canonical representative of an orbit is the labeling with the smallest mixed-radix integer encoding.*

Concretely:

```
hashTbl = trues(k^n)                    # one bit per labeling
for x in 0:(k^n - 1):
    if not hashTbl[x]: continue         # already crossed off as non-canonical
    c = decode(x)                        # the labeling at integer x
    for g in G[2:end]:                  # skip identity
        y = encode(g · c)                # encoded image of c under g
        if y > x:
            hashTbl[y] = false           # cross off the non-canonical image
        elif y == x and is_pure_translation(g):
            hashTbl[x] = false           # super-periodic — see super-periodicity.md
            break
canonical_labelings = findall(hashTbl)
```

Two crossings happen per group element: orbit non-canonicals (`y > x`) and super-periodics (`y == x` for some non-identity translation `g`). The second one is the chunk-5 super-periodicity filter; pass `include_superperiodic = true` to disable it.

## Cost

- **Time.** `O(|G| · k^n)` — for each of the `k^n` labelings, apply each of `|G|` group elements.
- **Memory.** `O(k^n / 8)` bytes for the `BitVector` hash table, plus the output (`Vector{EnumeratedStructure}` of size = orbit count).

For an FCC binary at volume `n = 12`, that's `2^12 = 4096` candidate labelings, `|G| ≈ 48 · 12 ≈ 576`, runtime ~1 second on a 2026 laptop. For ternary at `n = 8`, `3^8 = 6561` candidates, similar runtime. Once `k^n` crosses ~10^9 the bitmap (or the iteration) becomes the bottleneck.

## Why it's still useful

Even though `:auto` no longer picks it, `:exhaustive` is still worth understanding and occasionally worth running:

1. **Simplicity** — easy to reason about correctness, easy to debug, easy to extend (e.g., R50.2b's multilattice extension just inflated `n` to `n_D · n`). The reference implementation of the original HF 2008 algorithm.
2. **Bitmap memory profile is densest at small `n`** — a `BitVector` is the densest representation of "which labelings survive" you can ship, byte-for-byte. The tree's per-structure output overhead can exceed the bitmap at very small inputs.
3. **Cross-checks** — running `:exhaustive` against `:auto`'s tree on a few cases is a useful sanity check, especially when developing a new use-case.

## Where it falls down

- **Memory blows up at large `n`.** `BitVector(k^n)` is `k^n / 8` bytes. At `k=2, n=30` that's 128 MB; at `k=3, n=20` that's ~440 MB; at `k=4, n=15` ~130 MB. The [recursive-stabilizer algorithm](recursive-stabilizer-2017.md) avoids this by never materializing the bitmap; that's why `:auto` now uses it for unrestricted enumeration.
- **Concentration restriction is wasteful.** If only 5% of the `k^n` labelings have the right composition, the exhaustive sweep visits the other 95% only to cross them off as wrong-composition.

The [dispatch and the resource check](dispatch-and-cost-gate.md) explanation covers how `algorithm = :auto` makes its choice now.

## See also

- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — the concentration-restricted variant.
- [Recursive stabilizer (Morgan-Hart 2017)](recursive-stabilizer-2017.md) — when memory is the binding constraint.
- [Pólya counting](polya-counting.md) — how `count_inequivalent` prices an exhaustive run without doing it.
