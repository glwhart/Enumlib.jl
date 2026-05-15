# Output types for `enumerate(parent, sites; ...)`. Two types in this file:
#
#   - `EnumeratedStructure{D,L}` — one enumerated derivative structure.
#   - `Enumeration{D,L}`         — the top-level result; a vector of structures
#                                  plus the parent / sites / supercells they
#                                  reference.
#
# Plus the `to_labeling(s)` accessor and the iteration protocol on `Enumeration`.

"""
    EnumeratedStructure{D,L}

A single enumerated derivative structure: a reference to a `Supercell{D}` (by index into the parent `Enumeration.supercells` vector) plus the labeling that decorates it.

The parametric `L` is the labeling representation (the "string" of atom types). For chunk 5 (v0.2-alpha) only `L = Vector{Int8}` is supported — the decoded form, ~n bytes per structure. Phase 6 §6.7 contemplates `L = Int64` (hash-based, compact) and `L = BigInt` (very-large enumerations), deferred to v0.3+ as the test-corpus sizes (n ≤ 12) don't motivate them.

Two degeneracy fields are reserved for future chunks:

- `hnf_degeneracy` — when `ConcentrationRange` is supplied, multiple HNFs may share a structure under label-symmetry; this counts how many. Always 1 in chunk 5.
- `labeling_degeneracy` — when label-rotation duplicates collapse, this counts how many user-facing labelings collapse to one canonical representative. Always 1 in chunk 5.

Both are kept as fields (8 bytes each) so chunk 6 doesn't need to migrate the struct shape.

The `orbit_size` field (R33, 2026-05-14) is the symmetry-orbit size of the labeling under the supercell's permutation group `G` — i.e., `|G| / |Stab(labeling)|`, via the orbit-stabilizer theorem. This is UNCLE's `d_F` (HF 2008 Eq. 3); downstream consumers use it for free-energy weighting in MC simulations, convex-hull degeneracy display, and phase-space coverage diagnostics.

# Examples
```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> e = enumerate(p, sites; supercells = VolumeRange(2:2),
                     concentration = concentration_count([1, 1]; n_total = 2));

julia> e[1].orbit_size            # the only orbit at this concentration has size |G|/|Stab|
2
```
"""
struct EnumeratedStructure{D,L}
    supercell_id::Int
    labeling::L
    hnf_degeneracy::Int
    labeling_degeneracy::Int
    orbit_size::Int

    function EnumeratedStructure{D,L}(supercell_id::Integer, labeling::L,
                                       hnf_degeneracy::Integer = 1,
                                       labeling_degeneracy::Integer = 1,
                                       orbit_size::Integer = 1) where {D,L}
        supercell_id >= 1 ||
            throw(ArgumentError("supercell_id must be ≥ 1, got $supercell_id"))
        hnf_degeneracy >= 1 ||
            throw(ArgumentError("hnf_degeneracy must be ≥ 1, got $hnf_degeneracy"))
        labeling_degeneracy >= 1 ||
            throw(ArgumentError("labeling_degeneracy must be ≥ 1, got $labeling_degeneracy"))
        orbit_size >= 1 ||
            throw(ArgumentError("orbit_size must be ≥ 1, got $orbit_size"))
        new(Int(supercell_id), labeling,
            Int(hnf_degeneracy), Int(labeling_degeneracy), Int(orbit_size))
    end
end

# Outer constructor — D and L inferred from the labeling's type. For Vector{Int8}
# (the chunk-5 default) the user provides D explicitly: EnumeratedStructure{3}(1, [Int8(0), Int8(1)]).
EnumeratedStructure{D}(supercell_id::Integer, labeling::L,
                       hnf_degeneracy::Integer = 1,
                       labeling_degeneracy::Integer = 1,
                       orbit_size::Integer = 1) where {D,L} =
    EnumeratedStructure{D,L}(supercell_id, labeling,
                             hnf_degeneracy, labeling_degeneracy, orbit_size)

"""
    to_labeling(s::EnumeratedStructure) -> Vector{Int8}

Return the labeling of structure `s` as a `Vector{Int8}`. For chunk-5's `L = Vector{Int8}` representation this is a no-op pass-through. Future representations (`Int64`, `BigInt`) will decode on access.

# Examples
Small case — FCC binary at volume 2 (the first structure of two):
```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> e = enumerate(p, sites; supercells = VolumeRange(2:2));

julia> to_labeling(e[1])
2-element Vector{Int8}:
 0
 1
```

Larger case — BCC binary at volume 8 with 4:4 concentration (chunk-6 fixed-concentration enumeration), the 7th of 94 structures:
```jldoctest
julia> A_bcc = 0.5 * [-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0];

julia> p = ParentLattice(A_bcc);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> e = enumerate(p, sites; supercells = VolumeRange(8:8),
                     concentration = concentration_count([4, 4]; n_total = 8));

julia> to_labeling(e[7])
8-element Vector{Int8}:
 0
 0
 0
 0
 1
 1
 1
 1
```
"""
to_labeling(s::EnumeratedStructure{D,Vector{Int8}}) where D = s.labeling

# Equality + hashing — value semantics across all five fields.
Base.:(==)(a::EnumeratedStructure{D,L}, b::EnumeratedStructure{D,L}) where {D,L} =
    a.supercell_id == b.supercell_id &&
    a.labeling == b.labeling &&
    a.hnf_degeneracy == b.hnf_degeneracy &&
    a.labeling_degeneracy == b.labeling_degeneracy &&
    a.orbit_size == b.orbit_size
function Base.hash(s::EnumeratedStructure, h::UInt)
    h = hash(s.supercell_id, h)
    h = hash(s.labeling, h)
    h = hash(s.hnf_degeneracy, h)
    h = hash(s.labeling_degeneracy, h)
    h = hash(s.orbit_size, h)
    return h
end

# Pretty printing. orbit_size is always shown (it's the load-bearing degeneracy
# field downstream consumers actually use); the two placeholder degeneracy
# fields are only shown when non-trivial.
function Base.show(io::IO, s::EnumeratedStructure{D,L}) where {D,L}
    deg = (s.hnf_degeneracy == 1 && s.labeling_degeneracy == 1) ? "" :
          ", deg=(hnf=$(s.hnf_degeneracy), labeling=$(s.labeling_degeneracy))"
    print(io, "EnumeratedStructure{$D}(supercell #$(s.supercell_id), labeling=",
              s.labeling, deg, ", orbit_size=$(s.orbit_size))")
end


# ------------------------------------------------------------------------------

"""
    Enumeration{D,L}

The output of `enumerate(parent, sites; supercells, ...)`. Holds the full result of an enumeration call: the parent lattice, the sites description, the list of distinct supercells encountered (shared across structures by index), and the structures themselves.

`Enumeration` is iterable and indexable:

```julia
e = enumerate(parent, sites; supercells = VolumeRange(2:6))
for s in e
    digits = to_labeling(s)
    # ...
end
n = length(e)
first = e[1]
```

For chunk 5 the structures vector is fully materialized at construction (eager). Phase 6 §6.8 contemplates a lazy variant for streaming output of very large enumerations; deferred to v0.3+.
"""
struct Enumeration{D,L}
    parent::ParentLattice{D}
    sites::Sites{D}
    supercells::Vector{Supercell{D}}
    structures::Vector{EnumeratedStructure{D,L}}
end

# Iterator protocol — yields EnumeratedStructure{D,L} values in the order they
# were materialized (which is "outer loop over supercells, inner loop over
# unique colorings on that supercell").
Base.length(e::Enumeration) = length(e.structures)
Base.iterate(e::Enumeration, state::Int=1) =
    state > length(e.structures) ? nothing : (e.structures[state], state + 1)
Base.eltype(::Type{Enumeration{D,L}}) where {D,L} = EnumeratedStructure{D,L}
Base.IteratorSize(::Type{<:Enumeration}) = Base.HasLength()
Base.getindex(e::Enumeration, i::Integer) = e.structures[i]
Base.firstindex(::Enumeration) = 1
Base.lastindex(e::Enumeration) = length(e.structures)

# Pretty printing — clear-and-complete per the working agreement.
function Base.show(io::IO, e::Enumeration{D,L}) where {D,L}
    n_structs = length(e.structures)
    n_supercells = length(e.supercells)
    n_sites = length(e.sites.list)
    println(io, "Enumeration{$D, $(L)} ",
                "($n_structs structure$(n_structs==1 ? "" : "s"), ",
                "$n_supercells supercell$(n_supercells==1 ? "" : "s"), ",
                "$n_sites site$(n_sites==1 ? "" : "s"))")
    print(io,   "  parent: ", length(e.parent.space_group), "-op space group, ",
                ndset(e.parent), "-element dset")
end
