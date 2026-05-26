# Super-periodicity

What it means for a labeling on a volume-`m` supercell to be a *replica* of a labeling on a smaller supercell, why Enumlib filters these out by default, and when you'd keep them.

## The phenomenon

A coloring on a volume-`m` supercell is **super-periodic** if it's invariant under some non-identity pure translation in the supercell's translation subgroup `T`. Equivalently: the coloring's "true" period divides `m` strictly, so the same physical structure can be described on a smaller supercell.

Concrete example. Take a 1×1×4 supercell and the binary coloring `[A, B, A, B]`. The translation by half the supercell maps this to itself: it's the period-2 coloring `[A, B]` "re-described" on a doubled cell. Symmetric (period-1) colorings like `[A, A, A, A]` and `[A, B, A, B]`'s shorter cousins fall into the same bucket.

## Why filter by default

If you enumerate over a *range* of supercell volumes, super-periodic structures cause double-counting: the same physical derivative shows up once at every volume that's a multiple of its true period. For most workflows — CE training, convex-hull construction, structure-property mapping — you want one occurrence per physical structure, not one occurrence per `(volume, periodic-replica)` pair.

Enumlib's default is `include_superperiodic = false`. Across a `VolumeRange(1:6)` sweep on the FCC binary, this gives 7140 distinct derivatives at volume 12 (matching HF 2008), all aperiodic at that volume. The 745 super-periodic colorings at volume 12 are excluded — they show up at volume 6, 4, 3, 2, or 1.

## When to keep them

Pass `include_superperiodic = true` when:

- **You're enumerating at a single fixed volume** and need the full Burnside orbit space (e.g., a single-volume MC simulation that doesn't care about cross-volume duplicates).
- **You're validating against a reference that includes them** — the original HF 2008 paper, some legacy enumlib runs, etc.
- **You want to measure** how much super-periodicity is dropping (the difference `length(enumerate(...; include_superperiodic=true)) - length(enumerate(...; include_superperiodic=false))` is the super-periodic count at that volume).

Both [`enumerate`](@ref) and [`count_inequivalent`](@ref) carry the same kwarg, and the two stay byte-for-byte consistent: `length(enumerate(...; include_superperiodic = p)) == count_inequivalent(...; include_superperiodic = p)` for either policy.

## How filtering works algorithmically

In the exhaustive HF 2008 algorithm, super-periodicity is detected at the hash-canonicalization step: a coloring is super-periodic iff applying a non-identity pure translation produces a coloring with the same hash. The hash table iterates over `k^n` candidates and crosses off both *non-canonical* (orbit duplicates) and *super-periodic* ones in the same pass — at `O(|G|·n·k^n)` total cost, no measurable overhead vs unrestricted Burnside.

In the multinomial HF 2012 algorithm and the recursive-stabilizer 2017 algorithm, super-periodicity is detected the same way during partial-coloring expansion. The same kwarg flips the same behavior.

On the Pólya / counting side, the **aperiodic orbit count** is what matches the filtered enumeration. See [polya-counting](polya-counting.md) for the Möbius-inversion machinery that makes it cheap to compute.

## Multilattice extension

For multilattice parents, "translation" still means a pure supercell-lattice translation (translations don't move atoms between dset positions), and the filtering policy works the same. The translation subgroup `T` has size `n` (the supercell volume in Bravais cells), the same as the single-lattice case — it doesn't grow with `n_D`.

## See also

- [Pólya counting](polya-counting.md) — the aperiodic-count Möbius correction.
- [Handle super-periodicity](../how-to/handle-super-periodicity.md) — recipe-oriented.
- [Algorithm overview](algorithm-overview.md).
