# Pólya counting

The [Pólya enumeration theorem](https://en.wikipedia.org/wiki/P%C3%B3lya_enumeration_theorem) ([Burnside's lemma](https://en.wikipedia.org/wiki/Burnside%27s_lemma) in a coloring guise) and the [Möbius-inversion](https://en.wikipedia.org/wiki/M%C3%B6bius_inversion_formula) correction Enumlib uses to count *non-super-periodic* structures without materializing them.

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

The `k^{c(g)}` form assumes the labels are *unrestricted* — every position free to take any of the `k` species. When that isn't true — heterogeneous [`Sites`](@ref) with per-position `allowed_labels` — the same "constant on each cycle" argument yields a different, smaller fixed-point count. That's the label-restricted case, two sections down.

## Fixed concentration

For a labeling with prescribed per-species counts `[a_1, ..., a_k]` (a multiplicity vector with `Σ aᵢ = n`), the number of colorings fixed by `g` is the coefficient of `x_1^{a_1} ⋯ x_k^{a_k}` in the product

```
∏_j (x_1^{c_j} + x_2^{c_j} + ⋯ + x_k^{c_j})
```

over the cycle lengths `c_j` of `g`. This is the **cycle index polynomial** evaluated at fixed power sums. Enumlib extracts that coefficient by walking the cycles one at a time and carrying a running table of how many labelings reach each partial species count — the standard bookkeeping trick for coefficient extraction, which avoids ever expanding the product (cost: `O(t · ∏(aᵢ + 1) · k)` per permutation). See `polya_count(perm_group, multiplicities)`.

## Label-restricted positions

Heterogeneous [`Sites`](@ref) give each dset position its own `allowed_labels`: in zinc-blende the cation sublattice takes `{0, 1}` and the anion sublattice `{2, 3}`; in a half-Heusler `XYZ` the Y and Z sublattices are each pinned to one species while X mixes; in perovskite ABO₃ the three oxygens are fixed while the A and B cations mix independently. A position pinned to one species is not free to take any of the `k` labels, so `k^{c(ρ)}` is the wrong fixed-point count.

The correction falls out of the fact Burnside's lemma already rests on: a coloring fixed by `ρ` is **constant on each cycle** of `ρ`. A cycle can therefore only carry a label that is allowed at *every* position the cycle visits:

```
fix(ρ) = ∏_{cycles C of ρ} |⋂_{p ∈ C} allowed_labels[p]|
```

The product collapses to `0` as soon as one cycle's intersection is empty — that permutation fixes no valid coloring at all. `allowed_labels` is a per-position `Vector{BitSet}` indexed in the supercell's own position layout — the dset-blocks layout described under *Multilattice extension* below — so each factor is a `BitSet` intersection over the cycle's members. A uniform `allowed_labels` reduces to `k` for every factor and reproduces `k^{c(ρ)}` term by term, which is why uniform `Sites` keep the scalar-`k` fast path rather than paying for the intersections.

At fixed concentration the restriction threads through the same dynamic program: where the uniform version lets each cycle contribute any of the `k` species to the partial-multiplicity state, the restricted version lets it contribute only species in its own intersection.

Both live as extra methods of the same two entry points — `polya_count(perm_group, allowed_labels[, multiplicities])` and `aperiodic_orbit_count(perm_group, snf_diagonal, allowed_labels[, multiplicities])`. [`count_inequivalent`](@ref) picks between the uniform and restricted families automatically, from the `Sites` you hand it.

### Why the distinction is not a rounding error

Counting a restricted position as free overcounts by orders of magnitude, and the gap widens with supercell volume. Aperiodic counts for zinc-blende (FCC parent; cation sublattice `{0, 1}`, anion sublattice `{2, 3}`):

| supercell volume | label-restricted | labels unrestricted |
| ---: | ---: | ---: |
| 1 | 4 | 16 |
| 2 | 11 | 204 |
| 3 | 52 | 2960 |
| 4 | 290 | 64196 |

Perovskite diverges faster still: 4, 15, 48 at volumes 1–3 against 875, 2272000, and 6002278500. The left column is what [`enumerate_structures`](@ref) actually produces; the right is what the same permutation group yields if every position is treated as free over all `k` labels.

Because [`estimate_cost`](@ref) prices a run with the same count, the restricted formulas are also what keep the resource check from refusing a request that is in fact small.

## Super-periodicity correction

The Burnside count above includes super-periodic orbits (labelings fixed by some non-identity pure translation in the supercell). Enumlib's default policy drops these — they're equivalent to derivatives on a smaller supercell and a volume-range sweep would double-count them.

The **aperiodic orbit count** is obtained by Möbius inversion over the subgroup lattice of the supercell's translation subgroup `T`. Schematically:

```
N_aperiodic = (1 / |G|) · Σ_{g ∈ G} Σ_{H ≤ T} μ_T(H) · |fix(g) ∩ fix(H)|
```

where `μ_T` is the Möbius function on the subgroup lattice of `T`, and `|fix(g) ∩ fix(H)|` counts labelings fixed by both `g` and every translation in `H` (= labelings constant on each joint orbit of `{g} ∪ H_perms`).

If Möbius inversion is unfamiliar, the idea is inclusion–exclusion, generalized from sets to the lattice of subgroups. Counting labelings fixed by *at least* the translations in a given subgroup is easy; what we actually want is the labelings fixed by *nothing but* the identity translation — the aperiodic ones. Going from "at least" to "exactly" means subtracting the cases that are fixed by more, then adding back what the subtraction double-removed, and so on. The Möbius function `μ_T` is precisely the set of ± weights that makes that alternation come out right for a given lattice; for the simplest case, a cyclic `T` of prime order, it reduces to "all labelings minus the constant ones". [Möbius inversion](https://en.wikipedia.org/wiki/M%C3%B6bius_inversion_formula) and [incidence algebras](https://en.wikipedia.org/wiki/Incidence_algebra) cover the general statement; Stanley's *Enumerative Combinatorics* vol. 1, §3.7 is the standard reference.

This formulation is correct for **non-normal** subgroups `H` (subgroups of `T` need not be normal in `G` — e.g., for SNF `(1, 2, 2)` where `T = Z/2 × Z/2` is non-cyclic). Earlier sketches assumed `H`-normality and gave wrong counts on non-cyclic `T`.

At the supercell sizes Enumlib targets (`|T| ≤ ~32`), subgroup enumeration is cheap; the inner per-`(g, H)` joint-orbit computation is `O(n + |H|)` via union-find. See [`Enumlib.Polya.aperiodic_orbit_count`](@ref).

The label restriction composes with this cleanly. The Möbius inversion is unchanged — only the inner `|fix(g) ∩ fix(H)|` changes, from `k^(joint orbits)` to the intersection product over each joint orbit. The joint-orbit partition is exactly the object the intersection needs, so the union-find pass returns orbit *membership* rather than only orbit sizes.

## Unconstrained concentration ranges

A [`ConcentrationRange`](@ref) that leaves every species free over `[0, 1]` constrains nothing. Every coloring has exactly one concentration, so summing the per-concentration counts across all in-range concentrations reproduces the unrestricted Burnside count exactly. [`count_inequivalent`](@ref) therefore collapses such a range to a single evaluation instead of running the dense dynamic program once per composition of the site count into `k` parts. The shortcut is an identity, not an approximation.

This is not an edge case. `Enumlib.read_struct_enum_in` synthesizes exactly that range for a `full`-mode `struct_enum.in`, and [`enumerate_structures`](@ref) rejects *unrestricted* enumeration on heterogeneous sublattices — so "no concentration constraint" on such a parent has to be spelled as a full-range `ConcentrationRange` in the first place. Without the collapse, the per-composition walk dominates: it is the difference between milliseconds and tens of minutes on a perovskite of modest volume.

One consequence is user-visible: with an unconstrained range, `count_inequivalent(...; breakdown = true)` returns an **empty `by_concentration`**, because materializing that field is precisely the per-composition walk being skipped. `total`, `by_volume`, and `by_hnf` are unaffected. Pass a narrower range when you want the per-concentration slice. The collapse is internal to `count_inequivalent`: [`enumerate_structures`](@ref) still decomposes the same range into partitions, since it has to produce the structures.

## Default policy match

Pólya / aperiodic count matches `length(enumerate(...))` byte-for-byte when both use the same super-periodicity policy:

- `count_inequivalent(...; include_superperiodic = false)` (default) = `length(enumerate(...; include_superperiodic = false))` (default).
- `count_inequivalent(...; include_superperiodic = true)` = `length(enumerate(...; include_superperiodic = true))`.

This holds for heterogeneous `Sites` as well as uniform ones — it is the reason the label-restricted formulas exist, rather than being an optimization. The Pólya testsuite asserts the cross-check on the full fixed-concentration reference corpus, and the `struct_enum.in` corpus asserts it per locked reference row across the fcc, hcp, diamond, zinc-blende, half- and full-Heusler, and perovskite families.

## Multilattice extension

For multilattice parents (`n_D ≥ 2`), the labeling space lives on `n_D · n` sites in the **dset-blocks layout**: dset position `i` owns supercell positions `(i-1)·n + 1 … i·n`. The Pólya/aperiodic machinery extends straightforwardly: the permutation group acts on `n_D · n` positions; cycle counts of each `g` are computed on the larger position space; the translation subgroup `T` acts identically on each dset block (translations don't move atoms between dsets), so its perms are block-replicated.

That layout is also what indexes `allowed_labels` in the label-restricted formulas: every position in block `i` carries `sites.list[i].allowed_labels`, so the per-position vector is each sublattice's label set repeated `n` times per block. Heterogeneity across sublattices is therefore always a multilattice phenomenon — a single-dset parent has just one label set by construction, and takes the scalar-`k` path.

## See also

- [Algorithm overview](algorithm-overview.md) — the three enumeration algorithms Pólya prices.
- [Super-periodicity](super-periodicity.md) — the policy choice the Möbius correction implements.
- [Count without enumerating](../how-to/count-without-enumerating.md) — recipe-oriented use, including the heterogeneous-`Sites` and unconstrained-range cases above.
- [The drop-in executables](pymatgen-interop.md) — the `polya.x` command-line wrapper around this count, and why it exists.
- [`count_inequivalent`](@ref), [`Enumlib.Polya.polya_count`](@ref), [`Enumlib.Polya.aperiodic_orbit_count`](@ref).
