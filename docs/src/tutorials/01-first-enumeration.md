# Your first enumeration

Build a parent lattice, declare substitution sites, run [`enumerate`](@ref) on a small supercell range, and inspect the results. End-to-end in five minutes on a binary alloy.

## What you'll build

A symmetry-inequivalent enumeration of binary structures (composed of atoms A and B) on an FCC lattice at supercell volumes 1 through 3. By the end:

- You'll have an [`Enumeration`](@ref) value you can iterate over.
- You'll know how to read each [`EnumeratedStructure`](@ref)'s labeling, supercell, and orbit size.
- You'll be set up for [tutorial 02](02-fixed-concentration.md) (fixed concentration) and [tutorial 03](03-dft-training-database.md) (POSCAR export for DFT).

## Step 1 — install and load

```julia
using Pkg
Pkg.add(url = "https://github.com/glwhart/Enumlib.jl")  # while unregistered
using Enumlib
```

## Step 2 — declare the parent lattice

The parent lattice is *what your supercells are built on*. For a single-site Bravais lattice (FCC, BCC, simple cubic, etc.) you supply just the basis matrix; the columns of the matrix are the lattice vectors:

```jldoctest first_enum
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
ParentLattice{3}
  basis (columns): [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
  dset (1 site): [[0.0, 0.0, 0.0]]
  space group: 48 operations (0 non-symmorphic)
```

The constructor computes and caches the parent's space group (48 operations for FCC — full cubic symmetry, all symmorphic). That's what the enumeration will use to identify symmetry-equivalent structures. Equivalent structures are removed, leaving behind a list of structures which are all symmetry-*inequivalent*. These are structures that are physically distinct.

For multilattice parents (HCP, diamond, ...) supply the *dset* too. The dset a list of positions inside the unit cell where atoms sit. See [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).

## Step 3 — declare the substitution sites

`Sites` says *where in the parent cell* substitution can happen and *which species* are allowed there. For an FCC parent lattice and a binary enumeration, that's one site at the origin allowing species 0 and species 1:

```jldoctest first_enum
julia> sites = Sites(parent, [0, 1])
Sites{3} with 1 site (1 active, 1 canonical equivalence class)
  site 1: [0.0, 0.0, 0.0]    species {0, 1}
  equivalencies: (none)
```

For a case where there is only one site in the unit cell (as in this tutorial), the `Sites(parent, labels)` applies the labels to the one* dset position in the unit cell. For the multi-site cases (when `parent` has `ndset > 1`) the same call assigns the labels to every dset position uniformly. For more control — different labels per position, equivalence-class ties — see the [substitution-sites how-to](../how-to/describe-substitution-sites.md).

*Enumlib automatically defaults to `dset = [0,0,0]` in the case of a single-site cell.

## Step 4 — enumerate

The third input is the *supercell selection*: which supercells to enumerate over. The simplest is a [`VolumeRange`](@ref):

```jldoctest first_enum
julia> e = enumerate(parent, sites; supercells = VolumeRange(1:3))
Enumeration{3, Vector{Int8}} (10 structures, 6 supercells, 1 site)
  parent: 48-op space group, 1-element dset
```

Ten structures across volumes 1, 2, and 3 — the chunk-5 reference for unrestricted FCC binary on this range. By default the enumeration drops *super-periodic* colorings (those equivalent to derivatives on a smaller supercell); pass `include_superperiodic = true` to keep them.
#gh make a reference to Table 1 in HF2008

## Step 5 — inspect the result

[`Enumeration`](@ref) iterates over its `EnumeratedStructure`s in the order the algorithm produced them, ascending by supercell volume:

```jldoctest first_enum
julia> length(e)
10

julia> [length(to_labeling(s)) for s in e]   # labeling length = supercell volume
10-element Vector{Int64}:
 1
 1
 2
 2
 3
 3
 3
 3
 3
 3
```

Each [`EnumeratedStructure`](@ref) carries a labeling (a vector of `Int8` species indices), a reference to its supercell, and the orbit size:

```jldoctest first_enum
julia> s = e[1]
EnumeratedStructure{3}(supercell #1, labeling=Int8[0], orbit_size=1)

julia> to_labeling(s)
1-element Vector{Int8}:
 0
```

The first structure (volume 1, single-atom supercell, labeling `[0]`) is the pure-A structure; the second (`[1]`) is pure B. Volume 2 and 3 add mixed labelings — note that several volume-3 structures share the labeling `[0, 0, 1]` or `[0, 1, 1]` but sit on **different supercells** (different HNFs, different lattice geometries), so they're distinct derivative structures.

#gh delete this. Too much detail for first tutorial
`orbit_size` is the number of label assignments equivalent to this one under the supercell's permutation group; it's used downstream for degeneracy-weighted free energies and convex-hull diagnostics (this is the field JuCE.jl reads via R33).

## Step 6 — get to the supercell

Each structure references a supercell via `structure.supercell_id`. The full list of supercells lives at `e.supercells`:

```jldoctest first_enum
julia> sc = e.supercells[s.supercell_id]
Supercell{3} (n = 1, |stabilizer| = 48, |perm group| = 1)
  HNF: 1 0 0 / 0 1 0 / 0 0 1
  SNF diag: [1, 1, 1]
```
#gh would be more interesting to show one of the superlattices that is not volume==1

`sc.hnf` is the HNF matrix defining the supercell (`A_super = parent.A * sc.hnf.matrix`). `sc.permutation_group` is the supercell symmetry the enumeration crossed structures out with.

## Where to go next

- **Restrict to a target concentration** (e.g., "binary, exactly 4 A and 4 B in a volume-8 supercell"): [Tutorial 02 — Enumerating at a fixed concentration](02-fixed-concentration.md).
- **Export structures for DFT or MLIP runs**: [Tutorial 03 — Generating a DFT/MLIP training database](03-dft-training-database.md).
- **Multi-element parents** (HCP, diamond, perovskites, ...): [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).
- **Larger problems and timing**: [Estimate the cost](../how-to/estimate-cost.md) and [Count without enumerating](../how-to/count-without-enumerating.md).
