# Reading structures back: the inverse of `to_poscar`.
#
# A derivative structure arrives from outside Enumlib (a POSCAR, an extxyz file, an ASE
# database, a DFT code) as a cell and Cartesian positions. Reading it back means two steps:
#
#   1. Which supercell (HNF) and labeling is it, in the cell it was given?  -> `supercell_and_labeling`
#   2. Which structure of an enumeration is it equivalent to?             -> `canonical_form`, `structure_lookup`
#
# Step 1 is bookkeeping: the cell is an integer combination of the parent lattice vectors, its
# Hermite normal form is the supercell, and each atom is matched to a site of
# `supercell_fractional_positions(hnf, parent)` -- the site order `to_poscar` writes and the
# enumeration's labelings use. Step 2 needs symmetry: a structure read from a file is in general
# a symmetry image of the enumerated representative (a different HNF, a permuted labeling).
# `canonical_form` maps every image to the same key by minimising over the parent space group
# and the supercell translations, so matching is a dictionary lookup.
#
# Public entry points: the `EnumeratedStructure(e, cell, positions, labels)` constructor, which
# any format reader can call once it has arrays, and `from_poscar`, the converse of `to_poscar`.
# Other formats (extxyz, ASE) are read by the packages that need them and end in the constructor.

"""
    Enumlib.supercell_and_labeling(parent::ParentLattice{3}, cell::AbstractMatrix,
                                   positions::AbstractMatrix, labels::AbstractVector{<:Integer};
                                   atol::Real = 1e-3) -> (hnf = HNF{3}, labeling = Vector{Int8})

Identify a derivative structure given in Cartesian form, in the cell it was given: return the
supercell `hnf` and the `labeling` in the site order of [`to_poscar`](@ref) (the order
enumerated labelings use). Most callers want the
[`EnumeratedStructure`](@ref)`(e, cell, positions, labels)` constructor instead, which also
finds the structure in an enumeration.

- `cell` — 3×3, columns are the supercell lattice vectors, in the same units as `parent.A`.
- `positions` — 3×N Cartesian positions, one column per atom.
- `labels` — length-N colors (0-based), e.g. species indices.
- `atol` — Cartesian tolerance for "this vector is a lattice vector" and "this atom sits on
  this site". Ideal (unrelaxed) structures need only round-off; relaxed structures must be
  mapped onto the parent lattice first.

The cell may be any basis of the superlattice (Minkowski-reduced, left-handed, …); the HNF is
the same. Throws `ArgumentError` if the cell is not a superlattice of `parent`, if the atom
count is wrong, or if the atoms do not occupy every site exactly once.

The result describes the structure in the cell it was given. A structure given in a larger
cell than its primitive one (super-periodic) is a different `(hnf, labeling)` from its
primitive form; see `Enumlib.canonical_form`.

# Example

Round trip through [`to_poscar`](@ref)'s site layout:

```jldoctest
julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> h = HNF{3}([1 0 0; 0 1 0; 0 1 2]);

julia> sites = Enumlib.supercell_fractional_positions(h, parent);

julia> X = reduce(hcat, [parent.A * h.matrix * collect(s) for s in sites]);

julia> r = Enumlib.supercell_and_labeling(parent, parent.A * h.matrix, X, [1, 0]);

julia> r.hnf == h, r.labeling
(true, Int8[1, 0])
```
"""
function supercell_and_labeling(
    parent::ParentLattice{3},
    cell::AbstractMatrix,
    positions::AbstractMatrix,
    labels::AbstractVector{<:Integer};
    atol::Real = 1e-3,
)
    size(cell) == (3, 3) || throw(ArgumentError("cell must be 3×3, got $(size(cell))"))
    size(positions, 1) == 3 ||
        throw(ArgumentError("positions must be 3×N (one column per atom), got $(size(positions))"))
    n_atoms = size(positions, 2)
    length(labels) == n_atoms ||
        throw(ArgumentError("$(length(labels)) labels for $n_atoms atoms"))

    # The cell in parent-lattice coordinates must be an integer matrix.
    M = parent.A \ Matrix{Float64}(cell)
    Mi = round.(Int, M)
    err = maximum(LinearAlgebra.norm(parent.A * (M[:, j] - Mi[:, j])) for j = 1:3)
    err <= atol || throw(
        ArgumentError(
            "cell is not a superlattice of the parent lattice: a cell vector is " *
            "$(round(err; sigdigits = 3)) from the nearest lattice vector (atol = $atol). " *
            "Check that the parent lattice has the same lattice constant as the structure.",
        ),
    )
    vol = abs(round(Int, LinearAlgebra.det(Mi)))
    vol > 0 || throw(ArgumentError("cell is singular"))
    n_sites = vol * ndset(parent)
    n_atoms == n_sites || throw(
        ArgumentError(
            "the cell is $vol parent cells ($n_sites sites) but $n_atoms atoms were given",
        ),
    )

    hnf = HNF{3}(_lower_hnf(Mi))
    B = parent.A * hnf.matrix                       # Cartesian supercell basis
    frac = B \ Matrix{Float64}(positions)            # supercell-fractional atom positions
    sites = supercell_fractional_positions(hnf, parent)
    labeling = fill(Int8(-1), n_sites)
    for i = 1:n_atoms
        j = _match_site(view(frac, :, i), sites, B, atol)
        j == 0 && throw(
            ArgumentError("atom $i is not within atol = $atol of any lattice site"),
        )
        labeling[j] == -1 || throw(ArgumentError("two atoms occupy site $j"))
        labeling[j] = Int8(labels[i])
    end
    return (hnf = hnf, labeling = labeling)
end

"""
    Enumlib.canonical_form(parent::ParentLattice{3}, hnf::HNF{3}, labeling::AbstractVector{<:Integer})
        -> Tuple{Vector{Int}, Vector{Int8}}

A key that is equal for two `(hnf, labeling)` pairs exactly when they are the same crystal
up to the parent's space group and lattice translations (with colors held fixed, i.e. no
species relabeling). It is the lexicographic minimum of `(vec(H′), labeling′)` over every
image of the structure: each space-group operation maps the superlattice to `H′` and permutes
the sites, and each translation of the supercell shifts the labeling.

[`structure_lookup`](@ref) indexes an enumeration by this key. The key is cell-specific: a super-periodic structure given in a non-primitive
cell does not match its primitive enumerated representative.
"""
function canonical_form(
    parent::ParentLattice{3},
    hnf::HNF{3},
    labeling::AbstractVector{<:Integer},
)
    H = hnf.matrix
    sites = supercell_fractional_positions(hnf, parent)
    length(labeling) == length(sites) || throw(
        ArgumentError("labeling has length $(length(labeling)), supercell has $(length(sites)) sites"),
    )
    x = [H * collect(s) for s in sites]             # parent-lattice coordinates of each site
    tol = 1e-6
    best = nothing
    image = Vector{Int8}(undef, length(sites))
    for op in parent.space_group
        H2 = _lower_hnf(op.R * H)
        h2 = HNF{3}(H2)
        B2 = parent.A * H2
        sites2 = supercell_fractional_positions(h2, parent)
        H2inv = inv(Float64.(H2))
        for i in eachindex(x)
            j = _match_site(H2inv * (op.R * x[i] + op.t), sites2, B2, tol)
            j == 0 && error("space-group image of site $i is not a site; parent symmetry is inconsistent")
            image[j] = labeling[i]
        end
        key_H = vec(H2)
        for c in supercell_fractional_positions(h2)  # lattice translations within the supercell
            shifted = similar(image)
            for j in eachindex(sites2)
                k = _match_site(collect(sites2[j]) .+ collect(c), sites2, B2, tol)
                shifted[k] = image[j]
            end
            cand = (key_H, shifted)
            if best === nothing || isless(cand, best)
                best = (copy(key_H), shifted)
            end
        end
    end
    return best
end

"""
    structure_lookup(enumeration::Enumeration{3}) -> Dict{Tuple{Vector{Int},Vector{Int8}},Int}

Map the canonical form (`Enumlib.canonical_form`) of every structure in `enumeration` to its
index in `enumeration.structures`: two structures share a key exactly when they are symmetry
equivalent. Build it once and pass it as `lookup` to [`EnumeratedStructure`](@ref)`(e, …)` or
[`from_poscar`](@ref) when reading many structures; the default rebuilds it on every call.

```julia
lookup = structure_lookup(e)
structs = [EnumeratedStructure(e, cell, X, labels; lookup) for (cell, X, labels) in frames]
```
"""
function structure_lookup(enumeration::Enumeration{3})
    parent = enumeration.parent
    d = Dict{Tuple{Vector{Int},Vector{Int8}},Int}()
    for (i, s) in enumerate(enumeration.structures)
        hnf = enumeration.supercells[s.supercell_id].hnf
        key = canonical_form(parent, hnf, to_labeling(s))
        haskey(d, key) && error(
            "structures $(d[key]) and $i of the enumeration are equivalent; the enumeration has duplicates",
        )
        d[key] = i
    end
    return d
end

"""
    EnumeratedStructure(e::Enumeration{3}, cell::AbstractMatrix, positions::AbstractMatrix,
                        labels::AbstractVector{<:Integer};
                        atol::Real = 1e-3, lookup = structure_lookup(e))

The structure of enumeration `e` that a structure given in Cartesian form is equivalent to.
This is the common end point for every structure reader: [`from_poscar`](@ref) parses a POSCAR
and calls it, and readers for other formats (extxyz, ASE databases) only have to produce the
arrays.

- `cell` — 3×3, columns are the lattice vectors, in the units of `e.parent.A`. Any basis of
  the superlattice will do.
- `positions` — 3×N Cartesian positions, one column per atom, in any order.
- `labels` — length-N colors (0-based) in the enumeration's label set, e.g. species indices.
- `atol` — Cartesian tolerance for matching the cell to the parent lattice and atoms to sites.
  Ideal structures need only round-off; relaxed structures must first be mapped onto the
  parent lattice.
- `lookup` — from [`structure_lookup`](@ref)`(e)`. Build it once when reading many structures.

The structure may be any symmetry image of the enumerated one (rotated, translated, in another
basis). Throws `ArgumentError` if it is not a derivative structure of `e.parent`, or if it is
not in `e`: outside its volume or concentration range, or super-periodic (given in a larger
cell than its primitive one, which an enumeration without super-periodic structures lists
under the smaller cell).

# Example

The FCC binary with alternating (001) planes, given in a cell of two parent cells:

```jldoctest
julia> parent = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> e = enumerate_structures(parent, Sites([Site([0.0, 0.0, 0.0], [0, 1])]);
                                supercells = VolumeRange(1:4));

julia> cell = [0.0 0.5 1.0; 0.5 0.0 1.0; 0.5 0.5 0.0];

julia> s = EnumeratedStructure(e, cell, [0.0 0.5; 0.0 0.5; 0.0 0.0], [0, 1]);

julia> s in e.structures, volume(e.supercells[s.supercell_id].hnf)
(true, 2)
```
"""
function EnumeratedStructure(
    e::Enumeration{3},
    cell::AbstractMatrix,
    positions::AbstractMatrix,
    labels::AbstractVector{<:Integer};
    atol::Real = 1e-3,
    lookup = structure_lookup(e),
)
    r = supercell_and_labeling(e.parent, cell, positions, labels; atol)
    i = get(lookup, canonical_form(e.parent, r.hnf, r.labeling), 0)
    i == 0 && throw(
        ArgumentError(
            "the structure (volume $(volume(r.hnf)), labeling $(r.labeling)) is not in the " *
            "enumeration: it is outside its volume or concentration range, uses labels the " *
            "sites do not allow, or is super-periodic (given in a larger cell than its " *
            "primitive one)",
        ),
    )
    return e.structures[i]
end

"""
    from_poscar(io::IO, e::Enumeration{3}; species_symbols = nothing, atol = 1e-3,
                lookup = structure_lookup(e)) -> EnumeratedStructure
    from_poscar(path::AbstractString, e::Enumeration{3}; kwargs...)

Read a POSCAR and return the structure of `e` it is equivalent to: the converse of
[`to_poscar`](@ref). Any POSCAR of a derivative structure of `e.parent` works, not only ones
`to_poscar` wrote; the cell may be any basis and the structure any symmetry image.

Colors come from the species line. By default the n-th species listed is color `n-1`, which
is `to_poscar`'s convention (it lists all `k` species, zero counts included). Pass
`species_symbols` (color 0 first) to map symbols instead, e.g. for a POSCAR that omits
zero-count species or lists them in another order. VASP 4 files, with no species line, take
color `n-1` for the n-th count. Handles a negative scale factor (a target volume), Selective
dynamics, and Direct or Cartesian coordinates. `atol` and `lookup` are as for
[`EnumeratedStructure`](@ref)`(e, …)`.
"""
function from_poscar(
    io::IO,
    e::Enumeration{3};
    species_symbols::Union{Nothing,AbstractVector{<:AbstractString}} = nothing,
    atol::Real = 1e-3,
    lookup = structure_lookup(e),
)
    lines = [strip(l) for l in eachline(io)]
    length(lines) >= 8 || throw(ArgumentError("POSCAR has only $(length(lines)) lines"))
    scale = parse(Float64, first(split(lines[2])))
    cell = reduce(hcat, [parse.(Float64, split(lines[k])[1:3]) for k = 3:5])
    if scale < 0                                        # negative: the target cell volume
        scale = cbrt(-scale / abs(LinearAlgebra.det(cell)))
    end
    cell .*= scale

    # VASP 5 has a species line before the counts; VASP 4 goes straight to the counts.
    k = 6
    symbols = nothing
    if tryparse(Int, first(split(lines[k]))) === nothing
        symbols = split(lines[k])
        k += 1
    end
    counts = parse.(Int, split(lines[k]))
    k += 1
    colors = if symbols === nothing || species_symbols === nothing
        collect(0:(length(counts)-1))
    else
        map(symbols) do sym
            c = findfirst(==(sym), species_symbols)
            c === nothing &&
                throw(ArgumentError("species $sym is not in species_symbols = $species_symbols"))
            c - 1
        end
    end
    symbols === nothing ||
        length(symbols) == length(counts) ||
        throw(ArgumentError("$(length(symbols)) species but $(length(counts)) counts"))

    uppercase(lines[k][1]) == 'S' && (k += 1)          # Selective dynamics
    cartesian = uppercase(lines[k][1]) in ('C', 'K')
    k += 1
    n = sum(counts)
    length(lines) >= k + n - 1 || throw(
        ArgumentError("POSCAR lists $n atoms but has only $(length(lines) - k + 1) position lines"),
    )
    X = reduce(hcat, [parse.(Float64, split(lines[k+i-1])[1:3]) for i = 1:n])
    positions = cartesian ? scale .* X : cell * X
    labels = reduce(vcat, [fill(colors[j], counts[j]) for j in eachindex(counts)])
    return EnumeratedStructure(e, cell, positions, labels; atol, lookup)
end

from_poscar(path::AbstractString, e::Enumeration{3}; kwargs...) =
    open(io -> from_poscar(io, e; kwargs...), path)

# Lower-triangular column Hermite normal form in Enumlib's convention: positive diagonal and
# 0 <= H[i,j] < H[i,i] for j < i. NormalForms.hnfc gives the lower-triangular form; the
# off-diagonal reduction here fixes the sign convention.
function _lower_hnf(M::AbstractMatrix{<:Integer})
    H = Matrix{Int}(NormalForms.hnfc(Matrix{Int}(M)).H)
    D = size(H, 1)
    for i = 1:D
        if H[i, i] < 0
            H[:, i] .*= -1
        end
    end
    for i = 2:D, j = 1:(i-1)
        q = fld(H[i, j], H[i, i])
        q == 0 || (H[:, j] .-= q .* H[:, i])
    end
    return H
end

# Index of the site in `sites` (supercell-fractional tuples) that `f` coincides with modulo
# the supercell lattice, within Cartesian tolerance `atol` (B is the Cartesian supercell
# basis); 0 if none.
function _match_site(f::AbstractVector, sites, B::AbstractMatrix, atol::Real)
    for (j, s) in enumerate(sites)
        d1 = f[1] - s[1]; d1 -= round(d1)
        d2 = f[2] - s[2]; d2 -= round(d2)
        d3 = f[3] - s[3]; d3 -= round(d3)
        cx = B[1, 1] * d1 + B[1, 2] * d2 + B[1, 3] * d3
        cy = B[2, 1] * d1 + B[2, 2] * d2 + B[2, 3] * d3
        cz = B[3, 1] * d1 + B[3, 2] * d2 + B[3, 3] * d3
        cx * cx + cy * cy + cz * cz <= atol * atol && return j
    end
    return 0
end
