# Your first enumeration

Build a parent lattice, declare substitution sites, run [`enumerate`](@ref) on a small supercell range, and inspect the results. End-to-end in five minutes on a binary alloy.

## What you'll build

A symmetry-inequivalent enumeration of binary configurations (composed of atoms A and B) on an FCC lattice at supercell volumes 1 through 3. By the end:

- You'll have a list of enumerated *configurations*[^terms] (in an [`Enumeration`](@ref) container) that you can iterate over.
- You'll know how to read each configuration's (each is an [`EnumeratedStructure`](@ref)) *coloring* (list of atomic species at each site), supercell (unit cell), and orbit size (number of equivalent rotations/translations of this configuration).
- You'll be set up for [tutorial 02](02-fixed-concentration.md) (fixed concentration) and [tutorial 03](03-dft-training-database.md) (POSCAR export for DFT).

[^terms]: Terminology used throughout these docs: a **configuration** is a supercell plus a coloring (what an `EnumeratedStructure` carries). A **coloring** is the atom-species vector for one supercell (the API calls it the *labeling*; the accessor function is [`to_labeling`](@ref)). We avoid the word *structure* in body prose because of the collision with Julia's `struct`; the original HF 2008 paper title uses "derivative structures," which is the same idea.

## Step 1 — install and load

```julia
using Pkg
Pkg.add(url = "https://github.com/glwhart/Enumlib.jl")  # while unregistered
using Enumlib
```

## Step 2 — declare the parent lattice

The parent lattice is *what your supercells are built on*. (A supercell is an integer multiple of the parent lattice.) For a single-site Bravais lattice (FCC, BCC, simple cubic, etc.) you supply only the basis matrix; the columns of the matrix are the lattice vectors:

```jldoctest first_enum
julia> using Enumlib

julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
ParentLattice{3}
  basis (columns): [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
  dset (1 site): [[0.0, 0.0, 0.0]]
  space group: 48 operations (0 non-symmorphic)
```

The `ParentLattice` constructor computes and caches the parent's space group (48 operations for FCC — full cubic symmetry, all symmorphic). That group is used by the enumeration algorithm to identify symmetry-equivalent configurations. Equivalent configurations are removed from the list, leaving behind a list of configurations which are all symmetry-*inequivalent*. These are configurations that are physically distinct.

For multilattice parents (HCP, diamond, ...) you must supply the *dset*, in addition to the basis vectors. The dset is a list of positions inside the unit cell where atoms sit. See [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).

## Step 3 — declare the substitution sites

`Sites` says *where in the parent cell* substitution can happen and *which species* are allowed there. For an FCC parent lattice and a binary enumeration, that's one site at the origin allowing atomic species 0 or 1:

```jldoctest first_enum
julia> sites = Sites(parent, [0, 1])
Sites{3} with 1 site (1 active, 1 canonical equivalence class)
  site 1: [0.0, 0.0, 0.0]    species {0, 1}
  equivalencies: (none)
```

For a case where there is only one site in the unit cell (as in this tutorial), the `Sites(parent, labels)` applies the labels to the one[^1] dset position in the unit cell. For the multi-site cases (when `parent` has `ndset > 1`) the same call assigns the same labels to every dset position. For more control — different labels at each position, equivalence-class ties — see the [substitution-sites how-to](../how-to/describe-substitution-sites.md).

[^1]: Enumlib automatically defaults to `dset = [0, 0, 0]` in the single-site case, which is why we didn't have to pass one.

## Step 4 — enumerate

The third input is the *supercell selection*: the user chooses which supercells to enumerate over. The simplest choice is a [`VolumeRange`](@ref):

```jldoctest first_enum
julia> e = enumerate(parent, sites; supercells = VolumeRange(1:3))
Enumeration{3, Vector{Int8}} (10 structures, 6 supercells, 1 site)
  parent: 48-op space group, 1-element dset
```

Ten configurations across volumes 1, 2, and 3 — matches Table 1 of [Hart & Forcade 2008](../explanation/algorithm-overview.md#reference-derivative-structure-counts) for FCC binary. By default the enumeration drops *super-periodic* colorings (those equivalent to a smaller-supercell derivative); pass `include_superperiodic = true` to keep them.

## Step 5 — inspect the result

[`Enumeration`](@ref) iterates over its `EnumeratedStructure`s in the order the algorithm produced them, ascending by supercell volume:

```jldoctest first_enum
julia> length(e)
10

julia> [to_labeling(s) for s in e]
10-element Vector{Vector{Int8}}:
 [0]
 [1]
 [0, 1]
 [0, 1]
 [0, 0, 1]
 [0, 1, 1]
 [0, 0, 1]
 [0, 1, 1]
 [0, 0, 1]
 [0, 1, 1]
```

Two of length 1 (the pure-A and pure-B unit cells), two of length 2, and six of length 3. Note that several volume-3 configurations share the coloring `[0, 0, 1]` or `[0, 1, 1]` — those configurations sit on **different supercells** (different HNFs, different lattice geometries), so they're distinct derivative configurations.

Each [`EnumeratedStructure`](@ref) carries the coloring, a reference to its supercell, and the orbit size. Pick a 3-atom example (`e[5]`) to see something less trivial than the pure-A and pure-B cases:

```jldoctest first_enum
julia> s = e[5]
EnumeratedStructure{3}(supercell #4, labeling=Int8[0, 0, 1], orbit_size=3)

julia> to_labeling(s)
3-element Vector{Int8}:
 0
 0
 1
```

`orbit_size = 3` means three of the `2^3 = 8` possible colorings on this supercell are equivalent to `[0, 0, 1]` under the supercell's symmetry — concretely, `[0, 0, 1]`, `[0, 1, 0]`, and `[1, 0, 0]`, the three positions where the lone B can sit. Enumlib emits one representative per orbit; the orbit size tells you how many it stood in for.

## Step 6 — get to the supercell

Each configuration carries a `supercell_id`. Pick a more interesting one than `e[1]` — say `e[8]`, a volume-3 configuration on a *sheared* supercell:

```jldoctest first_enum
julia> sc = e.supercells[e[8].supercell_id]
Supercell{3} (n = 3, |stabilizer| = 8, |perm group| = 6, hnf_degeneracy = 6)
  HNF: 1 0 0 / 0 1 0 / 0 1 3
  SNF diag: [1, 1, 3]
```

The HNF's bottom row `0 1 3` is the giveaway — the third supercell-lattice vector is `parent.A · (0, 1, 3)`, not just a stretched version of one of the parent vectors. `A_super = parent.A * sc.hnf.matrix` is what VASP would see if you wrote this configuration to a POSCAR (see [Tutorial 03](03-dft-training-database.md)). The full list of six supercells is at `e.supercells`.

## What just happened

Three function calls — `ParentLattice`, `Sites`, `enumerate` — produced 10 symmetry-inequivalent FCC binary configurations across volumes 1, 2, and 3 (matching Hart & Forcade 2008, Table 1). Each [`EnumeratedStructure`](@ref) carries a coloring (`to_labeling`), a supercell reference (`supercell_id` → `e.supercells[...]`), and an orbit size. The same call shape extends to larger volume ranges, multilattice parents, and fixed-concentration enumerations (Tutorial 02).

## Where to go next

- **Restrict to a target concentration** (e.g., "binary, exactly 4 A and 4 B in a volume-8 supercell"): [Tutorial 02 — Enumerating at a fixed concentration](02-fixed-concentration.md).
- **Export configurations for DFT or MLIP runs**: [Tutorial 03 — Generating a DFT/MLIP training database](03-dft-training-database.md).
- **Multi-element parents** (HCP, diamond, perovskites, ...): [Enumerate on a multilattice parent](../how-to/enumerate-multilattice.md).
- **Larger problems and timing**: [Estimate the cost](../how-to/estimate-cost.md) and [Count without enumerating](../how-to/count-without-enumerating.md).
