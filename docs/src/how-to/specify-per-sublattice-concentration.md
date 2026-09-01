# Specify concentration per sublattice (Regime C)

For multilattice parents with heterogeneous sublattices — perovskite ABO₃, half/full Heusler with distinct sublattice species, spinel, HEAs on multi-sublattice parents — the *global* flat-vector [`Concentration`](@ref) gets awkward fast. The per-sublattice constructor `Concentration(sites, per_sublattice)` lets you state composition per dset position directly.

This page is a recipe. For the worked walkthrough see [Tutorial 04](../tutorials/04-multilattice-per-sublattice.md); for the mental model see [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md).

## Setup

```jldoctest psl_recipe
julia> using Enumlib

julia> p = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0],
                          [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5],
                           [0.5, 0.5, 0.0], [0.5, 0.0, 0.5], [0.0, 0.5, 0.5]]);   # perovskite ABO₃

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),     # A site: 50/50 (A=0, A'=1)
                       Site([0.5, 0.5, 0.5], [2, 3]),    # B site: 50/50 (B=2, B'=3)
                       Site([0.5, 0.5, 0.0], [4]),       # O₁ — fixed
                       Site([0.5, 0.0, 0.5], [4]),       # O₂ — fixed
                       Site([0.0, 0.5, 0.5], [4])]);     # O₃ — fixed
```

## Steps

Pass one row per dset position. Each row gives the ratio of each label allowed at that position, in the *sorted order of that position's `allowed_labels`*. The constructor normalizes each row internally and computes the global fractions.

```jldoctest psl_recipe
julia> c = Concentration(sites, [[1, 1], [1, 1], [1], [1], [1]])
Concentration(1//10, 1//10, 1//10, 1//10, 3//5)
```

"1:1 on A, 1:1 on B, fixed on O." The translation to the global flat-vector form — `[1//10, 1//10, 1//10, 1//10, 6//10]` (Julia auto-simplifies `6//10` to `3//5`) — is what you no longer have to do by hand.

The result is a plain [`Concentration`](@ref), so it flows into [`enumerate_structures`](@ref) the same way any other concentration does. `c.fractions[1] = 1//10` carries a denominator of 10, so the multiplicities only resolve cleanly when the total atom count `n_D * n` is a multiple of 10 — at n=1 you'd get zero structures (no integer multiplicities), at n=2 the math works:

```jldoctest psl_recipe
julia> e = enumerate_structures(p, sites; supercells = VolumeRange(2:2), concentration = c);

julia> length(e)
3
```

## Asymmetric per-sublattice ratios

The ratio inside each row is arbitrary — `[3, 1]` on a binary sublattice means 75/25, not 50/50:

```jldoctest psl_recipe
julia> Concentration(sites, [[3, 1], [1, 1], [1], [1], [1]])
Concentration(3//20, 1//20, 1//10, 1//10, 3//5)
```

Fractions work too — `[3//4, 1//4]` produces the same result as `[3, 1]`. Each row is normalized to sum to 1 before being merged into the global vector, so `[1, 1]` and `[1//2, 1//2]` and `[7, 7]` all mean "50/50."

## Common gotchas

- **One row per dset position, in `parent.dset` order.** The constructor checks `length(per_sublattice) == length(sites.list)`.
- **Row length matches `allowed_labels` length.** A binary site needs a 2-entry row, a ternary site needs 3, an inactive site needs 1. Mismatched lengths throw `ArgumentError`.
- **Inactive sites still need an entry.** Pass `[1]` (or any single positive number) — Enumlib needs the row to read off "100% of the only allowed label." Skipping the row would shift the rest of the spec to the wrong dset positions.
- **Row order in each sublattice tracks the *sorted* `allowed_labels`.** `Site(..., [1, 0])` and `Site(..., [0, 1])` produce the same [`Site`](@ref) because `allowed_labels` is stored as a `BitSet`. Per-sublattice rows index into the sorted form. Match labels by reading off `sort(collect(s.allowed_labels))` if you're unsure.
- **Equivalent to the flat-vector form.** The new constructor delegates to the canonical `Concentration([f₁, …])` — every existing API path accepts the result. There's no per-sublattice `Concentration` *type*.

## When to reach for it

| Situation | Flat-vector form | Per-sublattice form |
|---|---|---|
| Single-lattice binary FCC at 50/50 | `concentration_ratio([1, 1])` ✓ | `Concentration(sites, [[1, 1]])` |
| Single-lattice ternary FCC at 1:1:2 | `concentration_ratio([1, 1, 2])` ✓ | `Concentration(sites, [[1, 1, 2]])` |
| HCP binary at 50/50 (Regime B — uniform sublattices) | `concentration_ratio([1, 1])` ✓ | `Concentration(sites, [[1, 1], [1, 1]])` |
| Perovskite ABO₃ at 1:1 A, 1:1 B, fixed O | `Concentration([1//10, 1//10, 1//10, 1//10, 6//10])` 😣 | `Concentration(sites, [[1, 1], [1, 1], [1], [1], [1]])` ✓ |
| Half-Heusler X=AB, Y=fixed-C, Z=fixed-D, with X 3:1 | `Concentration([1//4, 1//12, 1//3, 1//3])` 😣 | `Concentration(sites, [[3, 1], [1], [1]])` ✓ |

For Regime A (single dset) and Regime B (uniform sublattices) the flat-vector constructors are usually clearer because the global vector matches the sublattice composition directly. For Regime C the per-sublattice form removes a translation step that's easy to get wrong.

## See also

- [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md) — what a `Concentration` is and how it resolves to integer counts.
- [Enumerate on a multilattice parent](enumerate-multilattice.md) — full Regime A/B/C recipe; the per-sublattice constructor fits the Regime C branch.
- [Tutorial 04 — Multilattice with per-sublattice concentration](../tutorials/04-multilattice-per-sublattice.md) — worked walkthrough.
- Reference: [`Concentration`](@ref).
