"""
    Sites{D}

A collection of `Site{D}`s plus an equivalence relation declaring which sites must carry the same label across configurations.

**Equivalencies are user-declared** — they are NOT derived from the parent's space group. Use cases include slab geometries (mirror-image layers must share composition; the slab vacuum breaks the parent's 3D periodicity that would otherwise tie them) and any other physical constraint the user knows but the symmetry analysis can't see.

The equivalence relation is stored as a Union-Find (`IntDisjointSets`) over the site indices `1:length(list)`. This makes transitivity automatic by data structure: if you declare site `i ↔ j` and `j ↔ k`, the data structure correctly returns `i, j, k` as a single class without any further work on the user's part.

## Two-variant constructor

- **Incremental:** build the `Sites` with no equivalencies first via `Sites([Site(...), Site(...)])`, then declare equivalencies one-by-one via `equate!(sites, i, j)`.
- **Upfront partition:** `Sites([Site(...), Site(...)], [[1,2], [3,4]])` validates the partition and builds the Union-Find in one shot. Suitable when the user already knows the equivalence classes from problem setup.

The two variants produce the same internal state and can be mixed (start with the upfront variant and call `equate!` later).

# Examples

Upfront-partition: three sites with sites 1 and 2 tied (e.g., mirror-image slab layers); site 3 inactive.
```jldoctest
julia> list = [Site([0.0, 0.0, 0.0], [0, 1]),
               Site([0.5, 0.5, 0.5], [0, 1]),
               Site([0.25, 0.25, 0.25], [0])];

julia> s = Sites(list, [[1, 2]]);

julia> n_active(s)
2

julia> n_canonical(s)
2

julia> canonical(s, 2)  # site 2 collapses to site 1's root
1

julia> n_effective(s)  # active AND canonical = 1
1
```
"""
mutable struct Sites{D}
    list::Vector{Site{D}}
    equiv::IntDisjointSets       # over indices 1:length(list)
    # `species_symbols[i + 1]` is the atomic symbol for integer label `i`
    # (1-based indexing into a 0-indexed label space). `nothing` when the
    # Sites was constructed with integer labels and no explicit mapping —
    # downstream code falls back to printing labels as integers and
    # `to_poscar(...)` requires an explicit `species_symbols=` kwarg as
    # before.
    species_symbols::Union{Nothing,Vector{Symbol}}
    # Note: only `equiv` is mutable — through `equate!` calls during construction.
    # The `list` is treated as immutable by convention; we don't expose mutators.

    # Variant 1: incremental — every site starts in its own singleton class.
    function Sites{D}(
        list::AbstractVector{Site{D}};
        species_symbols::Union{Nothing,AbstractVector{Symbol}}=nothing,
    ) where D
        isempty(list) && throw(ArgumentError("Sites must contain at least one site"))
        syms = _validated_species_symbols(list, species_symbols)
        new(collect(list), IntDisjointSets(length(list)), syms)
    end

    # Variant 2: upfront partition — validate, then build the Union-Find by unioning
    # each class's members. Sites not appearing in any class stay in their own
    # singleton class.
    function Sites{D}(
        list::AbstractVector{Site{D}},
        classes::AbstractVector{<:AbstractVector{<:Integer}};
        species_symbols::Union{Nothing,AbstractVector{Symbol}}=nothing,
    ) where D
        isempty(list) && throw(ArgumentError("Sites must contain at least one site"))
        n = length(list)
        seen = falses(n)
        for class in classes
            isempty(class) && throw(ArgumentError("equivalence class cannot be empty"))
            for i in class
                (1 <= i <= n) ||
                    throw(ArgumentError("class member $i out of range [1, $n]"))
                seen[i] && throw(ArgumentError("site $i appears in multiple equivalence classes"))
                seen[i] = true
            end
        end
        eq = IntDisjointSets(n)
        for class in classes
            # Union the class's members with class[1] as the representative.
            for i in 2:length(class)
                union!(eq, class[1], class[i])
            end
        end
        syms = _validated_species_symbols(list, species_symbols)
        new(collect(list), eq, syms)
    end
end

# Validate species_symbols against the labels actually used across the sites.
# Returns a `Vector{Symbol}` (a copy of the user's input) or `nothing`.
function _validated_species_symbols(
    list::AbstractVector{<:Site}, species_symbols::Union{Nothing,AbstractVector{Symbol}}
)
    species_symbols === nothing && return nothing
    syms = Vector{Symbol}(species_symbols)
    # Find the max label used; species_symbols must have an entry for every
    # label index 0..max_label (Option A: dense, length = max_label + 1).
    max_label = -1
    for site in list
        for lbl in site.allowed_labels
            max_label = max(max_label, Int(lbl))
        end
    end
    needed = max_label + 1
    length(syms) == needed || throw(
        ArgumentError(
            "species_symbols has length $(length(syms)) but Sites uses labels " *
            "0..$max_label (needs exactly $needed entries — dense mapping per " *
            "Option A; pad unused indices with a placeholder symbol if needed).",
        ),
    )
    return syms
end

# Outer constructors infer D from the site list's element type.
Sites(list::AbstractVector{Site{D}}; kwargs...) where D = Sites{D}(list; kwargs...)
Sites(list::AbstractVector{Site{D}}, classes; kwargs...) where D =
    Sites{D}(list, classes; kwargs...)

# ------------------------------------------------------------------------------
# Symbol-labeled construction — fold a Vector{SymbolSite{D}} into integer-
# labeled Site{D}s plus a first-seen species_symbols mapping.
# ------------------------------------------------------------------------------

"""
    Sites(list::AbstractVector{SymbolSite{D}})
    Sites(list::AbstractVector{SymbolSite{D}}, classes)

Construct a `Sites` from a list of `SymbolSite`s (produced by
`Site(position, syms::AbstractVector{Symbol})`). Builds the integer↔symbol
mapping in **first-seen order**: the first symbol encountered when walking
`list` becomes label 0, the next new symbol becomes label 1, and so on. The
resulting `Sites.species_symbols` is a dense `Vector{Symbol}` of length
`k = (max label + 1)`.

# Example
```jldoctest sites_symbols
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

A `Vector` mixing `Site{D}` and `SymbolSite{D}` (or symbol labels with
integer labels) throws `ArgumentError`. Pick one labeling style per
`Sites`.
"""
function Sites(list::AbstractVector{SymbolSite{D}}) where D
    int_sites, syms = _fold_symbol_sites(list)
    return Sites{D}(int_sites; species_symbols=syms)
end

function Sites(
    list::AbstractVector{SymbolSite{D}},
    classes::AbstractVector{<:AbstractVector{<:Integer}},
) where D
    int_sites, syms = _fold_symbol_sites(list)
    return Sites{D}(int_sites, classes; species_symbols=syms)
end

# Walk a Vector{SymbolSite{D}}, building (Vector{Site{D}}, Vector{Symbol})
# pair via first-seen assignment of integer labels.
function _fold_symbol_sites(list::AbstractVector{SymbolSite{D}}) where D
    seen = Dict{Symbol,Int}()   # symbol → 0-indexed integer label
    syms = Symbol[]
    int_sites = Site{D}[]
    for ss in list
        int_labels = Int[]
        for sym in ss.allowed_symbols
            idx = get(seen, sym, -1)
            if idx == -1
                push!(syms, sym)
                idx = length(syms) - 1   # 0-indexed
                seen[sym] = idx
            end
            push!(int_labels, idx)
        end
        push!(int_sites, Site{D}(ss.position, BitSet(int_labels)))
    end
    return int_sites, syms
end

# Reject lists that mix integer Sites and SymbolSites — pick one or the other.
# The eltype on a mixed array is Any (or some common supertype); catch the
# heterogeneous case with an explicit dispatch.
function Sites(list::AbstractVector)
    throw(
        ArgumentError(
            "Sites: mixed integer-labeled `Site` and symbol-labeled " *
            "`SymbolSite` entries in one list. Pick one labeling style — " *
            "either `Site(pos, [0, 1, ...])` everywhere, or " *
            "`Site(pos, [:Al, :Ga, ...])` everywhere.",
        ),
    )
end

# ------------------------------------------------------------------------------
# Convenience constructors from a ParentLattice (R51, 2026-05-14).
# Take a ParentLattice + a label specification and produce a Sites without
# forcing the user to re-thread the dset positions through Site constructors.
# ------------------------------------------------------------------------------

"""
    Sites(parent::ParentLattice{D}, labels) where D
    Sites(parent::ParentLattice{D}; k::Integer) where D

Build a `Sites` directly from a `ParentLattice`, without restating each dset position in a `Site` constructor call.

Three call shapes:

- **Uniform** — `Sites(parent, labels)`: every dset position gets the same `labels`. Accepts a `BitSet`, an integer `AbstractVector`, or an integer `AbstractRange` (e.g., `0:1`, `0:k-1`).
- **Per-position** — `Sites(parent, labels_per_position)`: `labels_per_position[i]` is the allowed-label set for dset position `i`. Length must equal `ndset(parent)`. Each element can be a `BitSet` or any integer vector.
- **k-species shorthand** — `Sites(parent; k::Integer)`: equivalent to `Sites(parent, 0:k-1)`.

The dispatch distinguishes uniform from per-position by element type: a bare `Vector{<:Integer}` is uniform (one label set), while a `Vector{<:Union{BitSet, AbstractVector{<:Integer}}}` is per-position (one label set per position).

# Examples
Simple cubic, single-site binary:
```jldoctest sites_convenience
julia> p = ParentLattice([1.0 0 0; 0 1 0; 0 0 1]);   # single-site Bravais; ndset = 1

julia> Sites(p, [0, 1])                              # uniform binary, integer vector
Sites{3} with 1 site (1 active, 1 canonical equivalence class)
  site 1: [0.0, 0.0, 0.0]    species {0, 1}
  equivalencies: (none)

julia> n_active(Sites(p; k = 3))                     # ternary shorthand
1
```

HCP, two sublattices — uniform vs per-position:
```jldoctest sites_convenience_hcp
julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p_hcp = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);

julia> sites = Sites(p_hcp, [0, 1]);                 # uniform binary on both sublattices

julia> n_active(sites), n_canonical(sites)
(2, 2)

julia> het = Sites(p_hcp, [[0, 1, 2], [0]]);         # ternary on first, fixed on second

julia> n_active(het), n_canonical(het)               # only the first is active
(1, 2)
```

A mismatched per-position length raises:
```jldoctest sites_convenience_hcp
julia> Sites(p_hcp, [[0, 1]])
ERROR: ArgumentError: per-position labels has length 1 but ndset(parent) = 2
[...]
```
"""
function Sites(parent::ParentLattice{D}, labels::BitSet) where D
    list = [Site{D}(pos, labels) for pos in parent.dset]
    return Sites{D}(list)
end

Sites(parent::ParentLattice, labels::AbstractVector{<:Integer}) =
    Sites(parent, BitSet(labels))

Sites(parent::ParentLattice, labels::AbstractRange{<:Integer}) =
    Sites(parent, BitSet(labels))

function Sites(parent::ParentLattice{D},
               labels_per_position::AbstractVector{<:Union{BitSet, AbstractVector{<:Integer}}}) where D
    n = length(parent.dset)
    length(labels_per_position) == n ||
        throw(ArgumentError(
            "per-position labels has length $(length(labels_per_position)) " *
            "but ndset(parent) = $n"))
    list = [Site{D}(pos, BitSet(lbl))
            for (pos, lbl) in zip(parent.dset, labels_per_position)]
    return Sites{D}(list)
end

Sites(parent::ParentLattice; k::Integer) = Sites(parent, 0:k-1)

# Symbol-label variants of the parent-based convenience constructors.
# Same shapes as the integer / BitSet variants above, just with atomic
# symbols. Internally builds SymbolSites and folds them via the regular
# Sites(::Vector{SymbolSite{D}}) path so the first-seen ordering matches
# what the per-Site Sites constructor would produce.

"""
    Sites(parent::ParentLattice{D}, labels::AbstractVector{Symbol})

Uniform atomic-symbol labels across every dset position. Equivalent to
`Sites([Site(pos, labels) for pos in parent.dset])` but reads more
naturally for multilattice parents.

```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites(p, [:Al, :Ga]);

julia> species_symbols(sites)
2-element Vector{Symbol}:
 :Al
 :Ga
```
"""
Sites(parent::ParentLattice{D}, labels::AbstractVector{Symbol}) where D =
    Sites([SymbolSite{D}(pos, labels) for pos in parent.dset])

"""
    Sites(parent::ParentLattice{D},
          labels_per_position::AbstractVector{<:AbstractVector{Symbol}})

Per-position atomic-symbol labels: `labels_per_position[i]` lists the
allowed species at dset position `i`. Length must equal `ndset(parent)`.

```jldoctest
julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);

julia> sites = Sites(p, [[:Al, :Ga], [:As]]);

julia> species_symbols(sites)
3-element Vector{Symbol}:
 :Al
 :Ga
 :As
```
"""
function Sites(
    parent::ParentLattice{D},
    labels_per_position::AbstractVector{<:AbstractVector{Symbol}},
) where D
    n = length(parent.dset)
    length(labels_per_position) == n || throw(
        ArgumentError(
            "per-position labels has length $(length(labels_per_position)) " *
            "but ndset(parent) = $n",
        ),
    )
    return Sites([
        SymbolSite{D}(pos, lbl) for (pos, lbl) in zip(parent.dset, labels_per_position)
    ])
end

"""
    equate!(sites::Sites, i::Integer, j::Integer) -> Sites

Declare sites `i` and `j` equivalent in the user-supplied partition. Idempotent (equating already-equated sites is a no-op) and transitive (equating `(i,j)` then `(j,k)` puts all three in one class). Returns `sites` for chainability.

# Examples
```jldoctest
julia> s = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                  Site([0.5, 0.5, 0.5], [0, 1]),
                  Site([0.25, 0.25, 0.25], [0, 1])]);

julia> equate!(s, 1, 2);  # tie sites 1 and 2

julia> equate!(s, 2, 3);  # transitivity collapses all three into one class

julia> n_canonical(s)
1
```
"""
function equate!(s::Sites, i::Integer, j::Integer)
    n = length(s.list)
    (1 <= i <= n) || throw(ArgumentError("site index $i out of range [1, $n]"))
    (1 <= j <= n) || throw(ArgumentError("site index $j out of range [1, $n]"))
    union!(s.equiv, i, j)
    return s
end

"""
    canonical(sites::Sites, i::Integer) -> Int

Return the canonical (root) site index of the equivalence class containing site `i`. Sites in the same equivalence class share their root; the dispatcher uses one root per class as the labeling-space representative.

# Examples
```jldoctest
julia> s = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                  Site([0.5, 0.5, 0.5], [0, 1])], [[1, 2]]);

julia> canonical(s, 1)
1

julia> canonical(s, 2)  # same equivalence class → same root
1
```
"""
canonical(s::Sites, i::Integer) = find_root!(s.equiv, i)

"""
    active_canonical_sites(sites::Sites{D}) -> Vector{Tuple{Int, Site{D}}}

Return a vector of `(index, Site{D})` pairs for sites that are both active (more than one allowed label) and canonical (the root of their equivalence class). This is the labeling space the enumeration algorithm sees: stripped of inactive sites and collapsed across equivalencies.

# Examples
```jldoctest
julia> list = [Site([0.0, 0.0, 0.0], [0, 1]),
               Site([0.5, 0.5, 0.5], [0, 1]),
               Site([0.25, 0.25, 0.25], [0])];

julia> s = Sites(list, [[1, 2]]);

julia> [i for (i, _) in active_canonical_sites(s)]  # site 1 is the only active canonical
1-element Vector{Int64}:
 1
```
"""
function active_canonical_sites(s::Sites{D}) where D
    result = Tuple{Int, Site{D}}[]
    for i in 1:length(s.list)
        is_active(s.list[i]) || continue
        canonical(s, i) == i || continue
        push!(result, (i, s.list[i]))
    end
    return result
end

"""
    n_active(sites::Sites)

Count of active sites (those with more than one allowed label).
"""
n_active(s::Sites) = count(is_active, s.list)

"""
    n_canonical(sites::Sites)

Count of equivalence classes (number of distinct canonical roots).
"""
function n_canonical(s::Sites)
    n = length(s.list)
    return length(unique(canonical(s, i) for i in 1:n))
end

"""
    n_effective(sites::Sites)

Count of *active canonical* sites — the actual dimension of the labeling space after stripping inactive sites and collapsing equivalencies. This is what `enumerate(...)` will use when it asks "how many free configurational variables does this problem have?"
"""
n_effective(s::Sites) = length(active_canonical_sites(s))

"""
    species_symbols(sites::Sites) -> Union{Nothing, Vector{Symbol}}

Return the atomic-symbol mapping carried by `sites`, or `nothing` if the
Sites was constructed with integer labels and no explicit mapping.

The returned vector is dense and 0-indexed by label: `species_symbols(s)[i + 1]`
is the symbol for integer label `i`. Length equals `k`, the number of
distinct labels across the sites.

```jldoctest sites_symbols_acc
julia> sites = Sites([
           Site([0.0, 0.0, 0.0], [:Al, :Ga]),
           Site([0.25, 0.25, 0.25], [:As]),
       ]);

julia> species_symbols(sites)
3-element Vector{Symbol}:
 :Al
 :Ga
 :As

julia> integer_sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> species_symbols(integer_sites) === nothing
true
```
"""
species_symbols(s::Sites) = s.species_symbols

"""
    to_atom_labeling(structure, sites::Sites) -> Vector{Symbol}

Translate an integer labeling (`to_labeling(structure) :: Vector{Int8}`)
to its atomic-symbol equivalent using `sites.species_symbols`. Throws
`ArgumentError` if `sites` has no symbol mapping.

This is the natural read-back for users who constructed Sites with atomic
symbols and want the post-enumeration labeling in those symbols rather
than as raw integer labels.

```jldoctest sites_to_atom_labeling
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites(p, [:Al, :Ga]);

julia> e = enumerate(p, sites; supercells = VolumeRange(1:1));

julia> to_atom_labeling(e[1], sites)
1-element Vector{Symbol}:
 :Al
```
"""
function to_atom_labeling(structure, sites::Sites)
    syms = species_symbols(sites)
    syms === nothing && throw(
        ArgumentError(
            "to_atom_labeling: Sites has no species_symbols mapping. " *
            "Construct Sites with atomic symbols (e.g. `Site(pos, [:Al, :Ga])`) " *
            "or pass `species_symbols=[:Al, :Ga, ...]` to the Sites constructor.",
        ),
    )
    labeling = to_labeling(structure)
    return [syms[Int(l) + 1] for l in labeling]
end

# Pretty printing — per the working agreement, prefer clear-and-complete over terse.
# Format: header line with summary counts; one line per site with position + species
# + optional `[inactive]` tag; final line listing non-trivial equivalence classes.
# When `species_symbols` is present, allowed-label sets are rendered with the
# atomic symbols (`{:Al, :Ga}`) rather than the raw integer indices.
function Base.show(io::IO, s::Sites{D}) where D
    n = length(s.list)
    nact = n_active(s)
    ncanon = n_canonical(s)
    syms = s.species_symbols
    println(io, "Sites{$D} with $n site$(n==1 ? "" : "s") ",
                "($nact active, $ncanon canonical equivalence class$(ncanon==1 ? "" : "es"))")
    for (i, site) in enumerate(s.list)
        labels_sorted = sort(collect(site.allowed_labels))
        species_str = if syms === nothing
            "{" * join(labels_sorted, ", ") * "}"
        else
            "{" * join((string(":", syms[Int(l) + 1]) for l in labels_sorted), ", ") * "}"
        end
        inactive_tag = is_inactive(site) ? "    [inactive]" : ""
        println(io, "  site $i: ", round.(site.position, digits=4),
                    "    species ", species_str, inactive_tag)
    end
    # Group sites by their canonical root, then drop singletons (size-1 classes
    # are the default and not interesting to display).
    classes = Dict{Int, Vector{Int}}()
    for i in 1:n
        push!(get!(() -> Int[], classes, canonical(s, i)), i)
    end
    nontrivial = sort!([sort(c) for c in values(classes) if length(c) > 1]; by = first)
    if isempty(nontrivial)
        print(io, "  equivalencies: (none)")
    else
        class_strs = ["{" * join(c, ",") * "}" for c in nontrivial]
        print(io, "  equivalencies: ", join(class_strs, ", "))
    end
end
