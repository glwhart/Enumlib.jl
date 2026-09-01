# Enumerating at a fixed concentration

[Tutorial 01](01-first-enumeration.md) produced *every* coloring on the chosen supercells. Real materials problems usually want a slice of that space: "exactly 50% A and 50% B," or "between 25% and 50% A." This tutorial adds a *concentration constraint* to the enumeration.

## What you'll build

On the same FCC binary parent as Tutorial 01[^terms]:

- You'll enumerate at fixed concentration 1:3 (one A atom and three B atoms in a four-atom supercell) — 7 configurations.
- You'll watch Enumlib silently skip volumes 4 and 5 when you ask for a 1:2 concentration that doesn't divide 4 or 5 evenly.
- You'll sweep a *range* of concentrations on a 4-atom cell and see the per-concentration breakdown.

[^terms]: Tutorial 01 introduced the terminology used throughout: a **configuration** is a supercell plus a coloring (an [`EnumeratedStructure`](@ref) value); a **coloring** is the per-site species vector (also called the *labeling*; the API accessor is [`to_labeling`](@ref)). See the [glossary](../explanation/glossary.md) for the full term list.

## Setup

Same FCC binary parent and sites as Tutorial 01:

```jldoctest concentration_tutorial
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites(parent, [0, 1]);
```

## Three ways to write the same concentration

A [`Concentration`](@ref) is a vector of `Rational{Int}` fractions summing to 1[^1] — the composition of the coloring. Enumlib gives you three constructors that all land on the same `Concentration` value; pick whichever matches the form your data is in:

| Constructor | Use when you have ... | Example |
|---|---|---|
| `Concentration([f₁, f₂, ...])` | Fractions in hand | `Concentration([1//4, 3//4])` |
| `concentration_ratio([a₁, a₂, ...])` | Raw ratios | `concentration_ratio([1, 3])` |
| `concentration_count([n₁, n₂, ...]; n_total = N)` | Atom counts in a specific cell | `concentration_count([3, 9]; n_total = 12)` |

All three of those produce the same `Concentration(1//4, 3//4)` *value*:

```jldoctest concentration_tutorial
julia> Concentration([1//4, 3//4]) == concentration_ratio([1, 3]) == concentration_count([3, 9]; n_total = 12)
true
```

**The key thing to understand.** A `Concentration` is just a pair of fractions — it doesn't carry the supercell size it was constructed at. So `concentration_count([3, 9]; n_total = 12)` produces *the same* `Concentration(1//4, 3//4)` as the other two forms, not a "concentration locked to volume 12." The `n_total = 12` is a validation hook at construction time — it checks that `[3, 9]` sums to 12 and that the resulting fractions are well-defined — but the resulting value applies cleanly to any supercell whose volume is a multiple of 4 (which is what the denominators require). At volume 4 you get a 1-A-and-3-B labeling space; at volume 8 you get 2-A-and-6-B; at volume 12 you get 3-A-and-9-B; etc.

The `concentration_count` form is most common in practice because it documents the supercell size you had in mind alongside the composition — but it doesn't restrict the resulting value to that cell.

[^1]: Using `Rational{Int}` keeps the arithmetic exact — no floating-point fuzz when checking whether a fraction times the supercell volume comes out to an integer.

## Step 1 — enumerate at one concentration

Pass the [`Concentration`](@ref) as the `concentration` kwarg. Reuse `Concentration(1//4, 3//4)` from above — but this time on a *volume-8* supercell, so we get 2 A and 6 B atoms per cell instead of 1 A and 3 B:

```jldoctest concentration_tutorial
julia> c = Concentration([1//4, 3//4]);

julia> e = enumerate_structures(parent, sites; supercells = VolumeRange(8:8), concentration = c)
Enumeration{3, Vector{Int8}} (42 configurations, 20 supercells, 1 site)
  parent: 48-op space group, 1-element dset
```

42 configurations across 20 supercells — note that 42 > 20, so several supercells host more than one inequivalent coloring at this composition. (For comparison, the same `Concentration` on `VolumeRange(4:4)` gives 7 configurations across 7 supercells: one labeling per supercell, the simpler case.)

Every emitted coloring has exactly two `0`s and six `1`s:

```jldoctest concentration_tutorial
julia> unique((count(==(0), to_labeling(s)), count(==(1), to_labeling(s))) for s in e)
1-element Vector{Tuple{Int64, Int64}}:
 (2, 6)
```

A single tuple, because the concentration constraint forces every configuration to the same composition.

## Step 2 — divisibility, and Enumlib's silent skipping

Some concentrations don't fit on every supercell size. Asking for "1/3 of species 0 and 2/3 of species 1" only makes sense on supercells whose volume is a multiple of 3 — at volume 4 you'd need 4/3 of an atom, which is impossible.

**Enumlib's action: silently skip the volumes where the concentration doesn't fit cleanly.** Watch:

```jldoctest concentration_tutorial
julia> c_third = Concentration([1//3, 2//3]);

julia> e_third = enumerate_structures(parent, sites; supercells = VolumeRange(3:6), concentration = c_third);

julia> sort(unique(length(to_labeling(s)) for s in e_third))   # volumes actually enumerated
2-element Vector{Int64}:
 3
 6
```

Only volumes 3 and 6 — the multiples of 3 in `3:6`. Volumes 4 and 5 emit nothing, with no error or warning. That's the natural semantics ("at this volume, this composition is impossible"), not a bug.

Under the hood the test is performed by the [`multiplicities`](@ref) function[^2], which resolves a `Concentration` to integer atom counts at a given supercell size. It throws [`EmptyEnumerationError`](@ref) when the resolution doesn't come out cleanly; `enumerate` catches that and skips the volume.

[^2]: `multiplicities(c_third, 6)` returns `[2, 4]` (2 A atoms + 4 B atoms in a 6-atom cell — fine). `multiplicities(c_third, 4)` would throw, because `4 · 1/3 = 4/3` isn't an integer.

## Step 3 — a *range* of concentrations

[`ConcentrationRange`](@ref) holds a `(lower, upper)` bound on each species' fraction. The enumerator sweeps every concentration *inside* the range that resolves to integer counts at each volume.

Enumlib does **not** automatically collapse the binary-symmetric label-exchange image (the `1:3` ↔ `3:1` pair, for instance — those are physically distinct A-poor-vs-B-poor configurations). To get one half of the symmetric range, bound it tighter — here we restrict to "species 0 is at most half, species 1 is at least half":

```jldoctest concentration_tutorial
julia> cr = ConcentrationRange([(0//1, 1//2), (1//2, 1//1)])
ConcentrationRange((0//1, 1//2), (1//2, 1//1))

julia> concentrations_in_range(cr, 4)
3-element Vector{Concentration}:
 Concentration(0//1, 1//1)
 Concentration(1//4, 3//4)
 Concentration(1//2, 1//2)
```

Three in-range concentrations at volume 4: pure B (0:4), one A in four (1:3), and 50/50 (2:2). [`enumerate`](@ref) returns the union of configurations across them:

```jldoctest concentration_tutorial
julia> length(enumerate_structures(parent, sites;
                         supercells = VolumeRange(4:4),
                         concentration = cr))
12
```

## Step 4 — see the breakdown

[`count_inequivalent`](@ref) with `breakdown = true` returns an [`InequivalentCount`](@ref) carrying per-volume / per-concentration / per-HNF total. This operation is fast — it doesn't generate configurations; it merely *counts* them using the [Pólya enumeration theorem](https://en.wikipedia.org/wiki/P%C3%B3lya_enumeration_theorem) (see also [the Pólya-counting explanation](../explanation/polya-counting.md) for the version Enumlib implements, including the aperiodic-orbit correction). This is useful for sizing the request before running it:

```jldoctest concentration_tutorial
julia> ic = count_inequivalent(parent, sites;
                                supercells = VolumeRange(4:4),
                                concentration = cr,
                                breakdown = true);

julia> ic.total
12

julia> ic.by_concentration
3-element Vector{Tuple{Concentration, BigInt}}:
 (Concentration(0//1, 1//1), 0)
 (Concentration(1//4, 3//4), 7)
 (Concentration(1//2, 1//2), 5)
```

`12 = 0 + 7 + 5`. The 0 at the pure-B concentration is the default *super-periodicity* policy at work: all-B on a volume-4 supercell is a periodic replica of all-B on volume 1, so it's dropped to avoid double-counting across a volume sweep. Pass `include_superperiodic = true` to keep it.[^3]

[^3]: `count_inequivalent` and `length(enumerate(...))` agree byte-for-byte by construction — both use the same Pólya machinery internally to apply the super-periodicity policy.

## What just happened

You went from "every coloring" (Tutorial 01) to "only the colorings at a fixed composition." Four takeaways:

- Three constructors (`Concentration`, `concentration_ratio`, `concentration_count`) all land on the same value — pick the one that matches your input shape. The constructed value is a pure pair of fractions; it isn't locked to any supercell size.
- A single concentration plus a multi-volume `VolumeRange` typically produces more configurations than supercells, because multiple inequivalent colorings can share one supercell (42 configs across 20 supercells in our 1:3 at volume-8 example).
- A fixed concentration silently *skips* supercell volumes where the composition doesn't fit cleanly. That's correct semantics, not an error.
- [`ConcentrationRange`](@ref) lets you sweep a band of concentrations; `count_inequivalent(...; breakdown = true)` slices the count by volume / concentration / HNF for sanity checks before you commit.

## Where to go next

- **Ship the configurations to a DFT calculator**: [Tutorial 03 — Generating a DFT/MLIP training database](03-dft-training-database.md).
- **Multi-element parents** (HCP, diamond, ...): [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).
- **Decide what concentration to even use**: [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md) — recipe-level guidance.
- **Estimate before running**: [Count without enumerating](../how-to/count-without-enumerating.md), [Estimate the cost](../how-to/estimate-cost.md).
- **The underlying math**: [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md), [Pólya counting](../explanation/polya-counting.md).
