# Exhaustive enumeration (HF 2008)

The chunk-5 default, drawn from Hart & Forcade, *Algorithm for generating derivative structures*, PRB 77, 224115 (2008). Iterate every coloring; canonicalize each into an orbit representative; emit one per orbit. The simplest of the three algorithms and the right choice when `k^n` fits in memory.

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

## Why this is the default

Three reasons it remains the chunk-5 default and the `algorithm = :auto` pick when no `Concentration` is supplied:

1. **Simplicity** — easy to reason about correctness, easy to debug, easy to extend (e.g., R50.2b's multilattice extension just inflated `n` to `n_D · n`).
2. **Memory efficiency at small `n`** — a `BitVector` is the densest representation of "which labelings survive" you can ship, byte-for-byte.
3. **No concentration assumption** — covers the `concentration = nothing` case naturally. (The multinomial algorithm is more efficient *when* there's a concentration to exploit.)

## Where it falls down

- **Memory blows up at large `n`.** `BitVector(k^n)` is `k^n / 8` bytes. At `k=2, n=30` that's 128 MB; at `k=3, n=20` that's ~440 MB; at `k=4, n=15` ~130 MB. Past those points either the [multinomial algorithm](multinomial-2012.md) (if you have a concentration) or the [recursive-stabilizer algorithm](recursive-stabilizer-2017.md) (which doesn't materialize the bitmap) is the right choice.
- **Concentration restriction is wasteful.** If only 5% of the `k^n` labelings have the right composition, the exhaustive sweep visits the other 95% only to cross them off as wrong-composition.

The [dispatch-and-cost-gate](dispatch-and-cost-gate.md) explanation covers how `algorithm = :auto` makes this choice.

## See also

- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — the concentration-restricted variant.
- [Recursive stabilizer (Morgan-Hart 2017)](recursive-stabilizer-2017.md) — when memory is the binding constraint.
- [Pólya counting](polya-counting.md) — how `count_inequivalent` prices an exhaustive run without doing it.
