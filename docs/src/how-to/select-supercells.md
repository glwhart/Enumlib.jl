# Select supercells

Tell `enumerate` which supercells (multiples of the parent cell) to iterate over via the [`SupercellSelection`](@ref) family. The three concrete subtypes cover the common cases.

## Setup

```jldoctest supcells_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);   # FCC primitive
```

## The three options at a glance

| Selection | Use when | Example |
|---|---|---|
| [`VolumeRange`](@ref) | "all supercells of volume N to M" | `VolumeRange(2:8)` |
| [`RadiusBound`](@ref) | "supercells whose physical size (cell radius) is ≤ X" | `RadiusBound(; max_radius_ratio = 2.0)` |
| [`ExplicitHNFs`](@ref) | "this specific list of HNFs" — regression tests, literature reference cases | (see below) |

## VolumeRange — most common

Enumerate every symmetry-inequivalent supercell of volume `n` for each `n` in the range:

```jldoctest supcells_recipe
julia> hnfs = enumerate_hnfs(VolumeRange(2:4), p);

julia> length(hnfs)              # symmetry-inequivalent HNFs at volumes 2, 3, 4 combined
12
```

The 12 is the FCC inequivalent-HNF count summed across n = 2, 3, 4.

## RadiusBound — when cell *shape* matters

For DFT convergence and similar applications, the supercell's physical *size* (distance between periodic images) may be a more useful criterion for enumeration than atom count (i.e., volume). `RadiusBound` enumerates HNFs whose Minkowski-reduced cell radius is at most `max_radius_ratio` times the parent cell's radius:

```jldoctest supcells_recipe
julia> sel = RadiusBound(; max_radius_ratio = 1.5, max_volume = 8);  # ≤ 1.5x parent radius, hard cap at vol 8

julia> length(enumerate_hnfs(sel, p))
5
```

The `max_volume` is a **safety stop** — without it, a generous `max_radius_ratio` could scan very large volumes, leading to a combinatorial explosion.

## ExplicitHNFs — hand-curated

Pass a list of `HNF`s you've chosen yourself. No symmetry reduction happens (the dispatcher assumes you've already done it):

```jldoctest supcells_recipe
julia> custom = [HNF([1 0 0; 0 1 0; 0 0 2]),    # 1×1×2 stacking
                 HNF([1 0 0; 0 1 0; 0 0 3]),    # 1×1×3 stacking
                 HNF([1 0 0; 0 1 0; 0 0 4])];   # 1×1×4 stacking

julia> length(enumerate_hnfs(ExplicitHNFs(custom), p))
3
```

Useful for regression tests, literature reference cases, or when you want to study one specific supercell in isolation.

## See also

- Reference: [`SupercellSelection`](@ref), [`VolumeRange`](@ref), [`RadiusBound`](@ref), [`ExplicitHNFs`](@ref), [`enumerate_hnfs`](@ref), [`avg_cell_radius`](@ref), [`HNF`](@ref), [`Supercell`](@ref).
- How-to: [Describe substitution sites](describe-substitution-sites.md) — done first; [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md) — the next step.
- Explanation: [Algorithm overview](../explanation/algorithm-overview.md). *(Coming in 13e.)*
