# Describe substitution sites

Specify *where* substitution can happen (positions in the parent cell) and *which species* are allowed at each one — plus any constraint declaring two sites must always carry the same label (an *equivalence class*).

## Setup

```jldoctest sites_recipe
julia> using Enumlib
```

## A single position with allowed species

A [`Site`](@ref) carries a fractional-coordinate position and a set of allowed species labels (integers from `0` to `k-1`). The convenience constructor accepts a plain integer vector and converts it to a `BitSet`:

```jldoctest sites_recipe
julia> s_active   = Site([0.0, 0.0, 0.0], [0, 1])   # active: A (0) or B (1)
Site{3}([0.0, 0.0, 0.0], species {0, 1})

julia> s_inactive = Site([0.5, 0.5, 0.5], [0])      # inactive: only A allowed
Site{3}([0.5, 0.5, 0.5], species {0}  [inactive])

julia> is_active(s_active), is_inactive(s_inactive) # one is active, one isn't
(true, true)
```

A site with **one** allowed label is **inactive** — it contributes no configurational freedom and is dropped from the labeling space during enumeration. A site with two or more allowed labels is **active**.

## A collection of sites — and equivalence classes

[`Sites`](@ref) wraps a `Vector{Site}` plus a *Union-Find* data structure that tracks which sites must carry the same label. Two construction styles:

**Incremental** — start with every site in its own equivalence class, then declare ties with [`equate!`](@ref):

```jldoctest sites_recipe
julia> list = [Site([0.0, 0.0, 0.0], [0, 1]),       # active
               Site([0.5, 0.5, 0.5], [0, 1]),       # active
               Site([0.25, 0.25, 0.25], [0])];      # inactive

julia> s = Sites(list);

julia> equate!(s, 1, 2);                            # site 1 and site 2 must match

julia> n_active(s)                                  # 2 active out of 3
2

julia> n_canonical(s)                               # 2 equivalence classes: {1,2} and {3}
2

julia> n_effective(s)                               # 1 active-and-canonical: just the {1,2} class
1
```

**Upfront partition** — declare equivalence classes at construction time:

```jldoctest sites_recipe
julia> s2 = Sites(list, [[1, 2]]);                  # same final state as the equate! version

julia> canonical(s2, 2)                             # the equivalence-class root of site 2
1
```

Both styles produce the same internal state. Use whichever matches how you have the data in hand.

## Why equivalence classes?

These ties are **user-declared**, not derived from the parent's space group. Typical use cases:

- **Slab geometries.** Mirror-image layers must share composition, but the vacuum gap in a slab breaks the parent's 3D periodicity that would otherwise tie them automatically.
- **Composition constraints.** "This dopant goes equally onto both sites of a dimer."

The enumerator only assigns independent labels to the **active canonical** sites — `n_effective` is the dimension of the labeling space it sees.

## See also

- Reference: [`Site`](@ref), [`Sites`](@ref), [`equate!`](@ref), [`is_active`](@ref), [`is_inactive`](@ref), [`canonical`](@ref), [`active_canonical_sites`](@ref), [`n_active`](@ref), [`n_canonical`](@ref), [`n_effective`](@ref).
- How-to: [Construct a parent lattice](construct-a-parent-lattice.md) — done first; [Select supercells](select-supercells.md) — the next step.
- Explanation: [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md). *(Coming in 13e.)*
