# Algorithm overview

A bird's-eye view of the three Hart-Forcade-Nelson enumeration algorithms, the Pólya counter that prices them, and how Enumlib chooses among them.

## What enumeration computes

Given a parent lattice, a set of substitutable sites with allowed species, and a selection of supercells, the **derivative-structure enumeration problem** is: list one representative from each equivalence class of decorated supercells, where two decorations are equivalent if some parent-lattice symmetry operation maps one to the other.

Concretely, for each chosen supercell:

1. The supercell has `n = volume(hnf)` Bravais sites (and `n_D · n` total atoms if the parent is a multilattice with `n_D` dset positions).
2. With `k` allowed species at each site, the *raw* labeling space has `k^n` (or `k^(n_D · n)`) elements.
3. The supercell's **permutation group** — induced by parent rotations that fix the superlattice composed with the supercell's translation subgroup — partitions the labeling space into orbits.
4. Each orbit is one symmetry-inequivalent derivative structure.

By default Enumlib also drops **super-periodic** labelings (those representable on a smaller supercell), so a single run across a volume range doesn't double-count smaller derivatives at larger volumes. See [super-periodicity](super-periodicity.md) for the policy.

## Three algorithms

Enumlib carries three algorithms with overlapping coverage. They differ in *what they iterate*:

| Algorithm | Iterates | Best when | Where |
|---|---|---|---|
| **Exhaustive** (HF 2008) | All `k^n` colorings | `k^n` is small; unrestricted concentration | [exhaustive-2008](exhaustive-2008.md) |
| **Multinomial** (HF 2012) | Only colorings at the target concentration | A specific `Concentration` is fixed; multinomial coefficient ≪ `k^n` | [multinomial-2012](multinomial-2012.md) |
| **Recursive stabilizer** (Morgan-Hart 2017) | A tree of partial colorings | Memory budget rules out the bitmap; very large `n` | [recursive-stabilizer-2017](recursive-stabilizer-2017.md) |

All three produce the same set of symmetry-inequivalent structures for any given input; the choice is purely computational. The [dispatch and the resource check](dispatch-and-cost-gate.md) explanation covers how `algorithm = :auto` picks one.

## Pólya counting — pricing without enumerating

[`count_inequivalent`](@ref) implements the Burnside / Pólya orbit count for the same problem. It doesn't materialize structures; it just averages "number of colorings fixed by each group element" over the permutation group. Cost is `O(|G|·n)` per supercell — milliseconds even for hundreds of supercells.

Two reasons to use it:

1. **Sizing.** Before running a million-structure enumeration, ask Pólya how many structures you're about to get. See [Count without enumerating](../how-to/count-without-enumerating.md).
2. **The resource check.** `enumerate(...)` internally calls Pólya (via [`estimate_cost`](@ref)) to decide whether the predicted memory usage fits the budget, and refuses to start if it doesn't.

By default Pólya returns the **aperiodic** orbit count — orbits whose stabilizer in the translation subgroup is trivial. That matches `length(enumerate(...; include_superperiodic = false))`. Pass `include_superperiodic = true` for the raw Burnside count.

## Multilattice extension

The HF 2008/2012 algorithms were originally stated for single-lattice (Bravais) parents. HF 2009 extended them to multilattices where every dset position carries the same allowed labels ("uniform sublattices"). Enumlib's R50.2 series implemented HF 2009 — same code paths as the single-lattice case, with the permutation group built on `n_D · n` sites instead of `n`. See [enumerate-multilattice](../how-to/enumerate-multilattice.md) for the user-facing recipe.

The **heterogeneous** multilattice case (different allowed labels per dset position — perovskite-style) is supported via the **recursive-stabilizer** algorithm with a site-mask filter, shipped in chunk 6.5b. Requires a `concentration` kwarg (unrestricted heterogeneous enumeration isn't defined). The faster **multinomial-restricted** variant for this regime is still queued for chunk 6.5a; `:auto` picks `:recursive_stabilizer` for Regime C today. See [enumerate-multilattice](../how-to/enumerate-multilattice.md#heterogeneous-sublattices-regime-c) for the user-facing recipe.

## Reference derivative-structure counts

Hart & Forcade 2008 Table 1 lists the unrestricted derivative-structure counts (super-periodics dropped) for the basic Bravais lattices at supercell volumes up to 8 or so. These are the canonical sanity-check numbers — Enumlib's test suite locks against them.

For example, FCC binary at volumes 1 through 3 cumulative = 10 structures (2 + 2 + 6 — matching the chunk-5 reference and HF 2008 Table 1's third column). Reproduce with:

```julia
parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
sites = Sites(parent, [0, 1])
length(enumerate(parent, sites; supercells = VolumeRange(1:3)))   # 10
```

See [Tutorial 01](../tutorials/01-first-enumeration.md) for the walkthrough. HF 2008 Table 1 also covers BCC and HCP (the latter via HF 2009's multilattice extension); the multilattice counts are locked separately as the R50.2b Fortran-corpus anchors (`[3, 10, 50, 270, 651, 4793]` for HCP n = 1..6 and `[3, 7, 33, 171]` for diamond n = 1..4).

## Where to go next

- **Pick an algorithm**: [pick-an-algorithm how-to](../how-to/pick-an-algorithm.md), [dispatch and the resource check](dispatch-and-cost-gate.md).
- **The three algorithms in detail**: [exhaustive-2008](exhaustive-2008.md), [multinomial-2012](multinomial-2012.md), [recursive-stabilizer-2017](recursive-stabilizer-2017.md).
- **Pólya machinery**: [polya-counting](polya-counting.md).
- **Super-periodicity policy**: [super-periodicity](super-periodicity.md).
- **Concentration types**: [concentration-and-multiplicity](concentration-and-multiplicity.md).
