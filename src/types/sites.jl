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
    # Note: only `equiv` is mutable — through `equate!` calls during construction.
    # The `list` is treated as immutable by convention; we don't expose mutators.

    # Variant 1: incremental — every site starts in its own singleton class.
    function Sites{D}(list::AbstractVector{Site{D}}) where D
        isempty(list) && throw(ArgumentError("Sites must contain at least one site"))
        new(collect(list), IntDisjointSets(length(list)))
    end

    # Variant 2: upfront partition — validate, then build the Union-Find by unioning
    # each class's members. Sites not appearing in any class stay in their own
    # singleton class.
    function Sites{D}(list::AbstractVector{Site{D}},
                      classes::AbstractVector{<:AbstractVector{<:Integer}}) where D
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
        new(collect(list), eq)
    end
end

# Outer constructors infer D from the site list's element type.
Sites(list::AbstractVector{Site{D}}) where D = Sites{D}(list)
Sites(list::AbstractVector{Site{D}}, classes) where D = Sites{D}(list, classes)

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

# Pretty printing — per the working agreement, prefer clear-and-complete over terse.
# Format: header line with summary counts; one line per site with position + species
# + optional `[inactive]` tag; final line listing non-trivial equivalence classes.
function Base.show(io::IO, s::Sites{D}) where D
    n = length(s.list)
    nact = n_active(s)
    ncanon = n_canonical(s)
    println(io, "Sites{$D} with $n site$(n==1 ? "" : "s") ",
                "($nact active, $ncanon canonical equivalence class$(ncanon==1 ? "" : "es"))")
    for (i, site) in enumerate(s.list)
        species_str = "{" * join(sort(collect(site.allowed_labels)), ", ") * "}"
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
