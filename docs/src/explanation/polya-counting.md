# Pólya counting

The Pólya enumeration theorem (Burnside's lemma in a coloring guise) and the Möbius-inversion correction Enumlib uses to count *non-super-periodic* structures without materializing them.

## Burnside on coloring spaces

For a finite group `G` acting on a set `X`, the number of orbits is the *average number of fixed points*:

```
|X / G| = (1 / |G|) · Σ_{g ∈ G} |fix(g)|
```

Apply this with `X = k^n` (the labeling space on `n` supercell sites with `k` species) and `G =` the supercell permutation group. For each `g ∈ G` with `c(g)` cycles, the labelings fixed by `g` are exactly those constant on each cycle — so `|fix(g)| = k^{c(g)}`. The unrestricted orbit count is

```
N_orbits = (1 / |G|) · Σ_{g ∈ G} k^{c(g)}
```

This is what `polya_count(perm_group, k)` ([`Enumlib.Polya.polya_count`](@ref)) computes. Cost is `O(|G| · n)` per supercell — milliseconds even for hundreds of supercells, hence its use as the resource check's pricing tool.

## Fixed concentration

For a labeling with prescribed per-species counts `[a_1, ..., a_k]` (a multiplicity vector with `Σ aᵢ = n`), the number of colorings fixed by `g` is the coefficient of `x_1^{a_1} ⋯ x_k^{a_k}` in the product

```
∏_j (x_1^{c_j} + x_2^{c_j} + ⋯ + x_k^{c_j})
```

over the cycle lengths `c_j` of `g`. This is the **cycle index polynomial** evaluated at fixed power sums. Enumlib computes this via a dynamic program over partial-multiplicity states (cost: `O(t · ∏(aᵢ + 1) · k)` per permutation). See `polya_count(perm_group, multiplicities)`.

## Super-periodicity correction

The Burnside count above includes super-periodic orbits (labelings fixed by some non-identity pure translation in the supercell). Enumlib's default policy drops these — they're equivalent to derivatives on a smaller supercell and a volume-range sweep would double-count them.

The **aperiodic orbit count** is obtained by Möbius inversion over the subgroup lattice of the supercell's translation subgroup `T`. Schematically:

```
N_aperiodic = (1 / |G|) · Σ_{g ∈ G} Σ_{H ≤ T} μ_T(H) · |fix(g) ∩ fix(H)|
```

where `μ_T` is the Möbius function on the subgroup lattice of `T`, and `|fix(g) ∩ fix(H)|` counts labelings fixed by both `g` and every translation in `H` (= labelings constant on each joint orbit of `{g} ∪ H_perms`).

This formulation is correct for **non-normal** subgroups `H` (subgroups of `T` need not be normal in `G` — e.g., for SNF `(1, 2, 2)` where `T = Z/2 × Z/2` is non-cyclic). Earlier sketches assumed `H`-normality and gave wrong counts on non-cyclic `T`.

For Enumlib's v0.2 supercell sizes (`|T| ≤ ~32`), subgroup enumeration is cheap; the inner per-`(g, H)` joint-orbit computation is `O(n + |H|)` via union-find. See [`Enumlib.Polya.aperiodic_orbit_count`](@ref).

## Default policy match

Pólya / aperiodic count matches `length(enumerate(...))` byte-for-byte when both use the same super-periodicity policy:

- `count_inequivalent(...; include_superperiodic = false)` (default) = `length(enumerate(...; include_superperiodic = false))` (default).
- `count_inequivalent(...; include_superperiodic = true)` = `length(enumerate(...; include_superperiodic = true))`.

The chunk-7 testsuite asserts this cross-check on the entire chunk-6 reference corpus.

## Multilattice extension

For multilattice parents (`n_D ≥ 2`), the labeling space lives on `n_D · n` sites in the dset-blocks layout. The Pólya/aperiodic machinery extends straightforwardly: the permutation group acts on `n_D · n` positions; cycle counts of each `g` are computed on the larger position space; the translation subgroup `T` acts identically on each dset block (translations don't move atoms between dsets), so its perms are block-replicated. See R50.2c (bundled into R50.2b, 2026-05-15).

## See also

- [Algorithm overview](algorithm-overview.md) — the three enumeration algorithms Pólya prices.
- [Super-periodicity](super-periodicity.md) — the policy choice the Möbius correction implements.
- [Count without enumerating](../how-to/count-without-enumerating.md) — recipe-oriented use.
- [`count_inequivalent`](@ref), [`Enumlib.Polya.polya_count`](@ref), [`Enumlib.Polya.aperiodic_orbit_count`](@ref).
