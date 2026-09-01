# Multilattice with per-sublattice concentration

[Tutorial 02](02-fixed-concentration.md) constrained a single-lattice binary alloy to a fixed concentration. Real materials are often *multi-sublattice*: a half-Heusler `XYZ` carries three distinct chemical roles, a perovskite `ABO₃` two cation sublattices around a fixed oxygen framework, a spinel `AB₂O₄` likewise. This tutorial enumerates a half-Heusler-style problem where one sublattice is binary while the other two are each fixed to a different species, and shows how the per-sublattice [`Concentration`](@ref) constructor keeps the user-side spec clean.

## What you'll build

- A half-Heusler-shape parent lattice: FCC with three dset positions `(0, 0, 0)`, `(1/4, 1/4, 1/4)`, `(3/4, 3/4, 3/4)`.
- Sites with **distinct** species per sublattice: X = {Na, K} (two cation choices), Y = fixed Mg, Z = fixed F. (Hypothetical chemistry — the numbers are about the symmetry, not the bonding.)
- A 50/50 composition on X with the per-sublattice constructor, then run [`enumerate_structures`](@ref) and inspect what comes back.
- Compare to the flat-vector form to convince yourself they produce the same `Concentration`.
- Size the run first with [`count_inequivalent`](@ref), which honors each sublattice's `allowed_labels`.

By the end you'll see the [`Concentration(sites, per_sublattice)`](@ref) call shape and how it slots into the same `enumerate(...)` you already know from Tutorial 02.

## Setup

The FCC parent and the three dset positions (in fractional coordinates of the FCC primitive basis):

```jldoctest psl_tutorial
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                               [[0.0, 0.0, 0.0],
                                [0.25, 0.25, 0.25],
                                [0.75, 0.75, 0.75]]);
```

`ParentLattice` resolves Spacey's space group for this parent automatically. With three sites per primitive cell it's a multilattice; with each site potentially holding a different chemistry it's Regime C (heterogeneous sublattices).

## Step 1 — describe the sublattices

The whole point of Regime C is that each dset position carries its own `allowed_labels`. Half-Heusler `XYZ` with the X cation sublattice binary and Y, Z each fixed to a distinct species:

```jldoctest psl_tutorial
julia> sites = Sites([
           Site([0.0,  0.0,  0.0 ], [:Na, :K]),     # X — binary cation
           Site([0.25, 0.25, 0.25], [:Mg]),         # Y — fixed
           Site([0.75, 0.75, 0.75], [:F ]),         # Z — fixed
       ]);
```

Atomic-symbol labels (`:Na`, `:K`, …) are a convenience — Enumlib maps them to integer labels internally (`:Na → 0`, `:K → 1`, `:Mg → 2`, `:F → 3`), and you get `Vector{Symbol}` back from [`to_atom_labeling`](@ref) at the end. See [Describe substitution sites](../how-to/describe-substitution-sites.md#atomic-symbol-labels) for the mechanism.

## Step 2 — state the concentration per sublattice

50/50 on X, fixed on Y and Z. One way is to write the global flat-vector by hand:

```jldoctest psl_tutorial
julia> # X has 1 of label 0 + 1 of label 1; Y has 1 of label 2; Z has 1 of label 3.
       # Per primitive cell that's [1/2, 1/2, 1, 1] atoms; divided by 3 dset
       # positions gives [1/6, 1/6, 1/3, 1/3].
       c_flat = Concentration([1//6, 1//6, 1//3, 1//3])
Concentration(1//6, 1//6, 1//3, 1//3)
```

The mental gymnastics in that comment is the whole problem the per-sublattice constructor solves. Same `Concentration`, stated directly:

```jldoctest psl_tutorial
julia> c = Concentration(sites, [[1, 1],   # X: 1:1 on the binary cation
                                  [1],      # Y: fixed (one entry per sublattice, always)
                                  [1]])     # Z: fixed
Concentration(1//6, 1//6, 1//3, 1//3)
```

Each row corresponds to one dset position, in `parent.dset` order. Each row's entries correspond to the *sorted* labels at that position — for X with `[:Na, :K]` (mapped to `[0, 1]`), the row `[1, 1]` means "ratio 1 of label 0 (Na) to 1 of label 1 (K)." The constructor normalizes within each row and divides by the number of dset positions to produce the global vector.

To convince yourself the two forms agree:

```jldoctest psl_tutorial
julia> c == Concentration([1//6, 1//6, 1//3, 1//3])
true
```

## Step 3 — ask how big it is before enumerating

[`enumerate_structures`](@ref) allocates every configuration it finds. [`count_inequivalent`](@ref) takes the same arguments and returns the number that call *would* produce, by Pólya/Burnside orbit counting instead of construction — so it is the cheap pre-flight check before committing to a run:

```jldoctest psl_tutorial
julia> count_inequivalent(parent, sites; supercells = VolumeRange(2:2), concentration = c)
2
```

Heterogeneous sublattices need no extra ceremony here. Each dset position contributes only the labels it allows — Mg never lands on X, Na never on Z — and where symmetry ties several positions together, the counter keeps only the species allowed at *every* one of them, rather than treating all four as available everywhere. That distinction is worth orders of magnitude on multi-sublattice parents; see [Pólya counting](../explanation/polya-counting.md).

Widening the range shows both where the cost lives and where the composition doesn't fit:

```jldoctest psl_tutorial
julia> ic = count_inequivalent(parent, sites; supercells = VolumeRange(1:6),
                                concentration = c, breakdown = true);

julia> ic.total
32

julia> ic.by_volume
3-element Vector{Tuple{Int64, BigInt}}:
 (2, 2)
 (4, 5)
 (6, 25)
```

Odd volumes are *absent* rather than zero. `c` carries a denominator of 6 against 3 dset positions, so only even supercell volumes give whole atom counts; the rest are skipped as inapplicable, not enumerated and found empty. And volume 6 alone outweighs volumes 2 and 4 together — the usual shape of a volume sweep, and the reason to read this table before launching one.

## Step 4 — enumerate

The `concentration` kwarg accepts the per-sublattice-constructed value directly — `enumerate` doesn't know or care which constructor produced it:

```jldoctest psl_tutorial
julia> e = enumerate_structures(parent, sites; supercells = VolumeRange(2:2), concentration = c)
Enumeration{3, Vector{Int8}} (2 configurations, 2 supercells, 3 sites)
  parent: 48-op space group, 3-element dset
```

Two inequivalent configurations of `(NaK)MgF` at supercell volume 2. The Y and Z sublattices contribute one each per primitive cell, so a volume-2 supercell holds 2 Na/K + 2 Mg + 2 F = 6 atoms.

## Step 5 — read off the configurations

Each [`EnumeratedStructure`](@ref) carries an integer labeling; [`to_atom_labeling`](@ref) maps it back to the symbols you specified:

```jldoctest psl_tutorial
julia> for s in e
           println(to_atom_labeling(s, sites))
       end
[:Na, :K, :Mg, :Mg, :F, :F]
[:Na, :K, :Mg, :Mg, :F, :F]
```

Both configurations carry the same labeling `[Na, K, Mg, Mg, F, F]` — they're inequivalent because they sit on **different supercells** (different HNFs / lattice geometries), not because the labels differ. The cation-binary mixture has only one inequivalent way to place 1 Na + 1 K on each supercell at this volume, but the two distinct HNFs at volume 2 give two distinct supercell geometries to enumerate over.

You can read off the supercell for any configuration via `e.supercells[s.supercell_id]`:

```jldoctest psl_tutorial
julia> e.supercells[e[1].supercell_id].snf
3-element Vector{Int64}:
 1
 1
 2
```

(The SNF diagonal `[1, 1, 2]` is the shape of this supercell's quotient group.)

## Step 6 — asymmetric per-sublattice ratios

Two examples to anchor the spec:

```jldoctest psl_tutorial
julia> Concentration(sites, [[3, 1], [1], [1]])    # X 3:1, Y fixed, Z fixed
Concentration(1//4, 1//12, 1//3, 1//3)

julia> Concentration(sites, [[1//3, 2//3], [1], [1]])   # equivalent fraction form
Concentration(1//9, 2//9, 1//3, 1//3)
```

The first reads as "75% Na, 25% K on the X sublattice." The second uses fractions instead of ratios — equivalent to `[1, 2]` after normalization within the row. Use whichever form your input naturally takes.

## What just happened

Three concepts, three Enumlib calls:

1. **Multilattice parent** with three dset positions ([`ParentLattice`](@ref)).
2. **Heterogeneous sublattices** with distinct species per position ([`Sites`](@ref), atomic-symbol form).
3. **Per-sublattice concentration** stated per-position instead of globally ([`Concentration(sites, per_sublattice)`](@ref)).

Plus one habit worth keeping: [`count_inequivalent`](@ref) before [`enumerate_structures`](@ref), so you learn the size of a run before paying for it.

That's the whole Regime C user surface. The output [`Enumeration`](@ref) flows into POSCAR export ([Tutorial 03](03-dft-training-database.md)), cluster-expansion training (JuCE), and the rest of the downstream toolchain the same way single-lattice outputs do.

## Where to go next

- **Express ranges instead of one fixed concentration:** [Sweep concentration ranges](../how-to/sweep-concentration-ranges.md). The per-sublattice constructor doesn't apply to ranges — use a `ConcentrationRange` directly — but the Regime C dispatch otherwise works the same.
- **Generate POSCARs for the configurations above:** [Tutorial 03](03-dft-training-database.md) walks through the POSCAR roundtrip for DFT/MLIP training; the same `write_enumeration_archive` works on multilattice [`Enumeration`](@ref) values.
- **Multi-sublattice with non-trivial concentrations on multiple sublattices** (perovskite ABO₃ at A 1:1, B 1:1; HEAs on multi-sublattice parents): [Specify concentration per sublattice](../how-to/specify-per-sublattice-concentration.md) recipe.
- **Understand the dispatch:** [Dispatch and the resource check](../explanation/dispatch-and-cost-gate.md) — Regime C runs on the recursive-stabilizer tree by default.
- **Size a run without one:** [Count without enumerating](../how-to/count-without-enumerating.md) covers the breakdown fields and the unconstrained-range case.
