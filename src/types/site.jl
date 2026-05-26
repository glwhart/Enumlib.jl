"""
    Site{D}

A single position in the parent cell where atomic substitution can happen. Carries the position itself plus the set of species labels allowed at this position.

The position is in fractional coordinates of the parent lattice (`ParentLattice{D}.A`), matching the convention used by `ParentLattice{D}.dset`. Allowed labels are stored as a `BitSet` of integers from `0:k-1`, where `k` is the number of species in the problem. (D is typically 3, for 3D crystals.)

A site is **inactive** if `length(allowed_labels) == 1` — only one species can occupy it, so it has no configurational freedom and gets stripped from the labeling space during enumeration. A site is **active** otherwise.

`Site` does not validate the position against any specific `ParentLattice`. Cross-validation happens at the `enumerate(parent, sites)` boundary — keeps `Site` parametric on `D` only.

# Examples
A binary substitution site (active — two allowed labels) and a fixed-species site (inactive — one allowed label):
```jldoctest
julia> Site([0.0, 0.0, 0.0], [0, 1])
Site{3}([0.0, 0.0, 0.0], species {0, 1})

julia> Site([0.5, 0.5, 0.5], [0])
Site{3}([0.5, 0.5, 0.5], species {0}  [inactive])
```
"""
struct Site{D}
    position::Vector{Float64}    # length D, in fractional coords of the parent
    allowed_labels::BitSet       # subset of {0, 1, ..., k-1}

    function Site{D}(position::AbstractVector{<:Real}, allowed_labels::BitSet) where D
        length(position) == D ||
            throw(ArgumentError("position must have length $D, got $(length(position))"))
        isempty(allowed_labels) &&
            throw(ArgumentError("allowed_labels must be non-empty"))
        # Copy the BitSet so the user's BitSet can't mutate our state externally.
        new(Vector{Float64}(position), copy(allowed_labels))
    end
end

# Outer constructor: infer D from the position's length.
Site(position::AbstractVector{<:Real}, allowed_labels::BitSet) =
    Site{length(position)}(position, allowed_labels)

# Convenience constructor: accept a vector/range/tuple of integers and convert to
# BitSet. Saves users typing `BitSet(...)` for the common case
# `Site([0.5, 0.5, 0.5], [0, 1])`. Costs zero at runtime.
Site(position::AbstractVector{<:Real}, allowed) =
    Site(position, BitSet(allowed))

# ------------------------------------------------------------------------------
# Atomic-label convenience — Site(pos, [:Al, :Ga]) returns a SymbolSite which
# the Sites constructor folds into integer-labeled Site{D}s plus a per-Sites
# species_symbols mapping. Lets users write atomic symbols at construction time
# while the enumeration kernels keep operating on integer labels.
# ------------------------------------------------------------------------------

"""
    SymbolSite{D}

Intermediate type for constructing [`Sites`](@ref) with atomic-symbol labels.
Holds a `position` and a `Vector{Symbol}` of allowed species (e.g.
`[:Al, :Ga]`). The integer↔symbol mapping is established when the
`SymbolSite` is folded into a `Sites` collection — the `Sites` constructor
walks the list in order and assigns the first-seen symbol to label 0, the
second-seen to label 1, etc.

Users typically don't construct a `SymbolSite` directly. It's the return
type of `Site(position, syms::AbstractVector{Symbol})`:

```julia
Site([0.0, 0.0, 0.0], [:Al, :Ga])    # → SymbolSite{3}, not Site{3}
```

See [`Sites`](@ref) for how a `Vector{SymbolSite{D}}` becomes a fully-
populated `Sites` with `species_symbols`.
"""
struct SymbolSite{D}
    position::Vector{Float64}
    allowed_symbols::Vector{Symbol}

    function SymbolSite{D}(
        position::AbstractVector{<:Real}, allowed_symbols::AbstractVector{Symbol}
    ) where D
        length(position) == D || throw(
            ArgumentError(
                "position must have length $D, got $(length(position))"
            ),
        )
        isempty(allowed_symbols) &&
            throw(ArgumentError("allowed_symbols must be non-empty"))
        new(Vector{Float64}(position), Vector{Symbol}(allowed_symbols))
    end
end

# Infer D from position length.
SymbolSite(position::AbstractVector{<:Real}, allowed_symbols::AbstractVector{Symbol}) =
    SymbolSite{length(position)}(position, allowed_symbols)

# `Site(pos, [:Al, :Ga])` dispatches here and returns a SymbolSite instead of a
# Site{D}. The Sites constructor reconciles the SymbolSites into Site{D}s plus
# the integer↔symbol mapping. This is a deliberate type-of-result switch: it
# means `Site` is the user-facing constructor name for both integer and symbol
# labels, but the symbol case carries enough information for Sites to build
# the mapping without per-call boilerplate.
Site(position::AbstractVector{<:Real}, allowed::AbstractVector{Symbol}) =
    SymbolSite(position, allowed)

"""
    is_inactive(s::Site) -> Bool

A site is inactive iff its `allowed_labels` has exactly one element — only one species can occupy it, so it contributes no configurational freedom to the enumeration.

# Examples
```jldoctest
julia> is_inactive(Site([0.0, 0.0, 0.0], [0, 1]))
false

julia> is_inactive(Site([0.5, 0.5, 0.5], [0]))
true
```
"""
is_inactive(s::Site) = length(s.allowed_labels) == 1

"""
    is_active(s::Site) -> Bool

A site is active iff it has more than one allowed label. Active sites are the ones the enumeration algorithm will assign labels to.

# Examples
```jldoctest
julia> is_active(Site([0.0, 0.0, 0.0], [0, 1]))
true

julia> is_active(Site([0.5, 0.5, 0.5], [0]))
false
```
"""
is_active(s::Site) = !is_inactive(s)

# Equality and hashing — value semantics across structurally-equal Sites with matching
# D. Same pairing-rule pattern as `SymmetryOp`. See v0.2-plan.md glossary.
Base.:(==)(a::Site{D}, b::Site{D}) where D =
    a.position == b.position && a.allowed_labels == b.allowed_labels
function Base.hash(s::Site, h::UInt)
    h = hash(s.allowed_labels, h)
    h = hash(s.position, h)
    return h
end

# Pretty printing — clear-and-complete per the working agreement. One line per site;
# the `[inactive]` tag is only printed when applicable, so the default reader can
# scan a list of Sites and spot inactive ones quickly.
function Base.show(io::IO, s::Site{D}) where D
    species_str = "{" * join(sort(collect(s.allowed_labels)), ", ") * "}"
    inactive_tag = is_inactive(s) ? "  [inactive]" : ""
    print(io, "Site{$D}(", round.(s.position, digits=4),
              ", species ", species_str, inactive_tag, ")")
end
