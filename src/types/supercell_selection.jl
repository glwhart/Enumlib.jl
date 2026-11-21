"""
    abstract type SupercellSelection end

User-facing description of "which supercells should we enumerate over?". Three concrete subtypes:

- `VolumeRange(range)` — enumerate all symmetry-inequivalent HNFs of supercell volume in `range`.
- `RadiusBound(; max_radius_ratio, max_volume)` — enumerate HNFs whose `mean_reduced_length` is at most `max_radius_ratio` times the parent cell's, with a `max_volume` safety stop.
- `ExplicitHNFs(hnfs)` — pass a hand-curated list of HNFs through; no symmetry reduction happens (the user has already done it).

The dispatcher `enumerate_hnfs(::SupercellSelection, parent)` turns any selection into a concrete `Vector{HNF{D}}` that downstream code can iterate over uniformly.
"""
abstract type SupercellSelection end

# ------------------------------------------------------------------------------
# VolumeRange
# ------------------------------------------------------------------------------

"""
    VolumeRange(range::AbstractRange{Int})

Enumerate all symmetry-inequivalent HNFs whose volume `det(h)` lies in `range`. The most common selection — covers the "I want all supercells of size 2 through 8" use case.
"""
struct VolumeRange <: SupercellSelection
    range::AbstractRange{Int}

    function VolumeRange(range::AbstractRange{Int})
        isempty(range) &&
            throw(ArgumentError("VolumeRange must be non-empty"))
        all(n -> n >= 1, range) ||
            throw(ArgumentError("VolumeRange must have all volumes ≥ 1; got $range"))
        new(range)
    end
end

# ------------------------------------------------------------------------------
# RadiusBound
# ------------------------------------------------------------------------------

"""
    RadiusBound(; max_radius_ratio::Real, max_volume::Integer = typemax(Int))

Enumerate symmetry-inequivalent HNFs whose size, measured by [`mean_reduced_length`](@ref), is at most `max_radius_ratio` times the parent cell's own value. The `max_volume` is a safety stop — without it, very large `max_radius_ratio` values would scan unbounded volumes.

The size of a cell is the mean length of its three Minkowski-reduced basis vectors. In 3D these lengths are the successive minima of the lattice, so they do not depend on which reduced basis is chosen, and a supercell and its rotated copies under the parent's symmetry are always kept or dropped together. Each kept class therefore carries its full orbit as its degeneracy.

In v0.4.2 and earlier the measure was [`avg_cell_radius`](@ref), the mean distance from the center of the reduced cell to its corners. That value depends on which reduced basis `minkReduce` returns when reduced vectors tie in length, so the cut could keep part of a symmetry class and drop the rest.
"""
struct RadiusBound <: SupercellSelection
    max_radius_ratio::Float64
    max_volume::Int

    function RadiusBound(; max_radius_ratio::Real, max_volume::Integer = typemax(Int))
        max_radius_ratio > 0 ||
            throw(ArgumentError("max_radius_ratio must be positive; got $max_radius_ratio"))
        max_volume > 0 ||
            throw(ArgumentError("max_volume must be positive; got $max_volume"))
        new(Float64(max_radius_ratio), Int(max_volume))
    end
end

# ------------------------------------------------------------------------------
# ExplicitHNFs
# ------------------------------------------------------------------------------

"""
    ExplicitHNFs(hnfs::AbstractVector{HNF{D}})

Enumerate over a user-supplied list of HNFs. No symmetry reduction or filtering — the dispatcher passes the list through unchanged, since the user has already curated it.

Useful for: domain-specific HNF filters, regression tests against literature reference cases, hand-picked supercells the user wants to study individually.
"""
struct ExplicitHNFs{D} <: SupercellSelection
    hnfs::Vector{HNF{D}}

    function ExplicitHNFs{D}(hnfs::AbstractVector{HNF{D}}) where D
        isempty(hnfs) &&
            throw(ArgumentError("ExplicitHNFs must have at least one HNF"))
        new(collect(hnfs))
    end
end

# Outer constructor — infer D from the HNF list's element type. Julia's
# Vector{HNF{D}} type already enforces D-uniformity (you can't mix HNF{2} and
# HNF{3} in one vector), so no explicit dimension check needed.
ExplicitHNFs(hnfs::AbstractVector{HNF{D}}) where D = ExplicitHNFs{D}(hnfs)

# ------------------------------------------------------------------------------
# enumerate_hnfs — the dispatcher
# ------------------------------------------------------------------------------

"""
    enumerate_hnfs(s::SupercellSelection, parent::ParentLattice{D}) -> Vector{HNF{D}}

Turn a `SupercellSelection` into a concrete `Vector{HNF{D}}` for the `parent` lattice. Three methods, one per subtype:

- `VolumeRange`: loop through volumes in the range; concatenate per-volume `getSymInequivHNFs` results.
- `RadiusBound`: scan volumes 1..`max_volume`, compute each candidate's `mean_reduced_length`, keep those within the bound, then symmetry-reduce.
- `ExplicitHNFs`: pass through unchanged.

Downstream code (`enumerate(...)`) treats the returned vector uniformly regardless of which selection produced it.

# Examples
FCC has 2 symmetry-inequivalent HNFs at volume 2:
```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> hnfs = enumerate_hnfs(VolumeRange(2:2), p);

julia> length(hnfs)
2

julia> volume.(hnfs)
2-element Vector{Int64}:
 2
 2
```
"""
function enumerate_hnfs(s::VolumeRange, parent::ParentLattice{D}) where D
    result = HNF{D}[]
    for n in s.range
        append!(result, getSymInequivHNFs(n, parent))
    end
    return result
end

enumerate_hnfs(s::RadiusBound, parent::ParentLattice) = first.(_enumerate_hnfs_with_degeneracies(s, parent))

enumerate_hnfs(s::ExplicitHNFs{D}, parent::ParentLattice{D}) where D = copy(s.hnfs)

# ------------------------------------------------------------------------------
# _enumerate_hnfs_with_degeneracies — internal helper that pairs each canonical
# HNF with its parent-point-group orbit size on the HNFs at that volume (the
# Fortran enumlib's hnf_degen). Used by `enumerate(...)` / `count_inequivalent`
# to populate `Supercell.hnf_degeneracy` without each Supercell construction
# re-running the symmetric-HNF reduction (which would be O(N²) total).
# ------------------------------------------------------------------------------

function _enumerate_hnfs_with_degeneracies(s::VolumeRange, parent::ParentLattice{D}) where D
    result = Tuple{HNF{D}, Int}[]
    for n in s.range
        append!(result, getSymInequivHNFs_with_degeneracies(n, parent))
    end
    return result
end

function _enumerate_hnfs_with_degeneracies(s::RadiusBound, parent::ParentLattice{D}) where D
    # The measure is a lattice invariant, so rotated copies of a supercell agree
    # up to rounding; the small relative slack keeps a cell that sits exactly on
    # the cutoff from being kept in one orientation and dropped in another.
    cutoff = s.max_radius_ratio * mean_reduced_length(parent.A) * (1 + 1e-9)

    survivors = Matrix{Int}[]
    for n in 1:s.max_volume
        for m in getAllHNFs(n)
            mean_reduced_length(parent.A * m) <= cutoff && push!(survivors, m)
        end
    end
    canonical, sizes = _reduce_by_orbits(survivors, lattice_rotations(parent))
    return [(HNF{D}(h), k) for (h, k) in zip(canonical, sizes)]
end

# ExplicitHNFs: user-supplied HNFs aren't necessarily canonical reps, so each
# one's degeneracy is computed independently. Same O(N · |getAllHNFs|) cost as
# direct `Supercell(hnf, parent)` construction.
function _enumerate_hnfs_with_degeneracies(s::ExplicitHNFs{D}, parent::ParentLattice{D}) where D
    LG = lattice_rotations(parent)
    return [(h, _compute_hnf_degeneracy(h, LG)) for h in s.hnfs]
end
