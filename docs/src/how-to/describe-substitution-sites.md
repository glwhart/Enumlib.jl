# Describe substitution sites

Specify *where* substitution can happen (positions in the parent cell) and *which species* are allowed at each one — plus any constraint declaring two sites must always carry the same label (an *equivalence class*).

## Setup

```jldoctest sites_recipe
julia> using Enumlib

julia> p_fcc = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);   # FCC primitive

julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);  # two-site multilattice
```

## The fast path — `Sites(parent, labels)`

For most problems, build `Sites` directly from the [`ParentLattice`](@ref) using the same labels on every dset position:

```jldoctest sites_recipe
julia> Sites(p_fcc, [0, 1])                # single-site binary
Sites{3} with 1 site (1 active, 1 canonical equivalence class)
  site 1: [0.0, 0.0, 0.0]    species {0, 1}
  equivalencies: (none)

julia> Sites(p_hcp; k = 2)                 # HCP binary — k-species shorthand
Sites{3} with 2 sites (2 active, 2 canonical equivalence classes)
  site 1: [0.0, 0.0, 0.0]    species {0, 1}
  site 2: [0.3333, 0.6667, 0.5]    species {0, 1}
  equivalencies: (none)
```

For **heterogeneous** sublattices (perovskite-style: ternary on one site, fixed on another), pass a per-position list:

```jldoctest sites_recipe
julia> Sites(p_hcp, [[0, 1, 2], [0]])      # ternary on first sublattice, fixed (inactive) on second
Sites{3} with 2 sites (1 active, 2 canonical equivalence classes)
  site 1: [0.0, 0.0, 0.0]    species {0, 1, 2}
  site 2: [0.3333, 0.6667, 0.5]    species {0}    [inactive]
  equivalencies: (none)
```

**Coverage today:** `enumerate(...)` handles both single-site Bravais parents *and* uniform multilattices (the HCP / Diamond / etc. case where every dset position shares the same `allowed_labels`). The per-position **heterogeneous** case (perovskite-style — different labels per sublattice) is also supported via the `:recursive_stabilizer` algorithm with a site-mask filter (chunk 6.5b); it requires a `concentration` kwarg. See [enumerate-multilattice](enumerate-multilattice.md#heterogeneous-sublattices-regime-c) for the worked example.

## Atomic-symbol labels

Anywhere the integer-label form `[0, 1]` is accepted, you can also pass atomic symbols like `[:Al, :Ga]`. Internally the integers are still what the enumerator manipulates; the symbols are recorded on the `Sites` for display, for read-back after enumeration, and as the default `species_symbols` when writing POSCARs.

```jldoctest sites_recipe
julia> sites = Sites([
           Site([0.0, 0.0, 0.0],     [:Al, :Ga]),
           Site([0.25, 0.25, 0.25],  [:As]),
       ]);

julia> species_symbols(sites)
3-element Vector{Symbol}:
 :Al
 :Ga
 :As
```

The integer↔symbol mapping is built **first-seen across the list, in declaration order**: the first new symbol seen becomes label 0, the next new symbol becomes label 1, etc. Above: `Al`→0, `Ga`→1, `As`→2.

The same symbol form works on the parent-based fast paths:

```jldoctest sites_recipe
julia> Sites(p_fcc, [:Al, :Ga])               # single-site, uniform
Sites{3} with 1 site (1 active, 1 canonical equivalence class)
  site 1: [0.0, 0.0, 0.0]    species {:Al, :Ga}
  equivalencies: (none)

julia> Sites(p_hcp, [[:Al, :Ga], [:As]])      # per-position, multilattice
Sites{3} with 2 sites (1 active, 2 canonical equivalence classes)
  site 1: [0.0, 0.0, 0.0]    species {:Al, :Ga}
  site 2: [0.3333, 0.6667, 0.5]    species {:As}    [inactive]
  equivalencies: (none)
```

After enumeration, [`to_atom_labeling`](@ref) gives you the labeling back as atomic symbols:

```julia
e = enumerate(p_fcc, Sites(p_fcc, [:Al, :Ga]); supercells = VolumeRange(2:2))
to_atom_labeling(e[1], sites)    # → Vector{Symbol} like [:Al, :Ga]
```

When you write POSCARs via [`write_enumeration_archive`](@ref), the symbol mapping is automatically used as `species_symbols=` — no need to pass it explicitly:

```julia
sites = Sites(p_fcc, [:Al, :Ga])
e = enumerate(p_fcc, sites; supercells = VolumeRange(2:2))
write_enumeration_archive("batch", e; super_periodic = false)
# Each POSCAR's species line reads "Al Ga", picked up from the Sites mapping.
```

Mixing integer labels with symbol labels in the **same** `Sites` is rejected with an `ArgumentError` — pick one style per `Sites`. If you have integer-labeled `Site`s but want a symbol mapping for downstream display / POSCAR output, pass `species_symbols = [:Al, :Ga, ...]` as a kwarg to the `Sites` constructor.

## The longer path — building from individual `Site`s

When you need fine-grained control — different allowed labels per position *plus* equivalence-class ties between sites — drop down to constructing each [`Site`](@ref) yourself:

```jldoctest sites_recipe
julia> s_active   = Site([0.0, 0.0, 0.0], [0, 1])     # active: A (0) or B (1)
Site{3}([0.0, 0.0, 0.0], species {0, 1})

julia> s_inactive = Site([0.5, 0.5, 0.5], [0])        # inactive: only A allowed
Site{3}([0.5, 0.5, 0.5], species {0}  [inactive])

julia> is_active(s_active), is_inactive(s_inactive)   # one is active, one isn't
(true, true)
```

A site with **one** allowed label is **inactive** — it contributes no configurational freedom and is dropped from the labeling space during enumeration. A site with two or more allowed labels is **active**.

## Adding equivalence classes

[`Sites`](@ref) wraps a `Vector{Site}` plus a *Union-Find* data structure that tracks which sites must carry the same label across all configurations. Two ways to declare equivalence:

**Incremental** — start with every site in its own equivalence class, then declare ties with [`equate!`](@ref):

```jldoctest sites_recipe
julia> list = [Site([0.0, 0.0, 0.0], [0, 1]),         # active
               Site([0.5, 0.5, 0.5], [0, 1]),         # active
               Site([0.25, 0.25, 0.25], [0])];        # inactive

julia> s = Sites(list);

julia> equate!(s, 1, 2);                              # site 1 and site 2 must match

julia> n_active(s)                                    # 2 active out of 3
2

julia> n_canonical(s)                                 # 2 equivalence classes: {1,2} and {3}
2

julia> n_effective(s)                                 # 1 active-and-canonical: just the {1,2} class
1
```

**Upfront partition** — declare equivalence classes at construction time:

```jldoctest sites_recipe
julia> s2 = Sites(list, [[1, 2]]);                    # same final state as the equate! version

julia> canonical(s2, 2)                               # the equivalence-class root of site 2
1
```

Both styles produce the same internal state. Use whichever matches how you have the data in hand.

## Why equivalence classes?

These ties are **user-declared**, not derived from the parent's space group. Typical use cases:

- **Slab geometries.** Mirror-image layers must share composition, but the vacuum gap in a slab breaks the parent's 3D periodicity that would otherwise tie them automatically.
- **Composition constraints.** "This dopant goes equally onto both sites of a dimer."

The enumerator only assigns independent labels to the **active canonical** sites — `n_effective` is the dimension of the labeling space it sees.

## See also

- Reference: [`Site`](@ref), [`Sites`](@ref), [`SymbolSite`](@ref), [`equate!`](@ref), [`is_active`](@ref), [`is_inactive`](@ref), [`canonical`](@ref), [`active_canonical_sites`](@ref), [`n_active`](@ref), [`n_canonical`](@ref), [`n_effective`](@ref), [`species_symbols`](@ref), [`to_atom_labeling`](@ref).
- How-to: [Construct a parent lattice](construct-a-parent-lattice.md) — done first; [Select supercells](select-supercells.md) — the next step.
- Explanation: [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md).
