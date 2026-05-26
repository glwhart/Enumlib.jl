module Enumlib

using CodecZlib: GzipCompressorStream, GzipDecompressorStream
using Combinatorics
using Dates
using LinearAlgebra
using NormalForms
using Printf
using Spacey, MinkowskiReduction
using Tar
using TOML
using DataStructures: IntDisjointSets, find_root!, union!

# --- v0.2 type catalog ---
include("types/symmetry_op.jl")    # chunk 1
include("types/parent_lattice.jl") # chunk 1
include("types/site.jl")           # chunk 2
include("types/sites.jl")          # chunk 2

export
    # v0.2 type catalog (chunk 1)
    SymmetryOp, ParentLattice,
    basis, dset, space_group, ndset, n_nonzero_translations,
    lattice_rotations,
    # v0.2 type catalog (chunk 2)
    Site, Sites, SymbolSite,
    is_active, is_inactive,
    equate!, canonical, active_canonical_sites,
    n_active, n_canonical, n_effective,
    species_symbols, to_atom_labeling,
    # v0.2 type catalog (chunk 3)
    HNF, Supercell,
    volume,
    # v0.2 type catalog (chunk 4)
    SupercellSelection, VolumeRange, RadiusBound, ExplicitHNFs,
    enumerate_hnfs,
    # v0.2 type catalog (chunk 5) — Base.enumerate is extended, not exported separately
    Enumeration, EnumeratedStructure,
    to_labeling, default_memory_budget,
    # v0.2 type catalog (chunk 6)
    Concentration, concentration_ratio, concentration_count,
    ConcentrationRange, n_species,
    multiplicities, concentrations_in_range,
    multinomial_count, multinomial_hash, multinomial_unhash,
    EmptyEnumerationError, PartitionExplosionError,
    # v0.2 type catalog (chunk 7) — Polya + counting
    InequivalentCount, count_inequivalent,
    polya_count, cycle_structure, aperiodic_orbit_count,
    # v0.2 type catalog (chunk 7.5) — cost estimator + memory-budget gate
    EnumerationCostEstimate, EnumerationTooLargeError,
    estimate_cost, format_bytes,
    # v0.2 type catalog (chunk 11a/b/c) — POSCAR I/O
    to_poscar, write_enumeration_archive,
    read_results, attach_results,
    # Cell utilities
    avg_cell_radius
    # NOTE: chunk 13b.1 unexports the legacy lattice-coord API, internal
    # helpers, and cluster-equivalence helpers. Internal helpers stay in
    # the module — call them as `Enumlib.foo(...)` if you need them. The
    # nine legacy I/O symbols are reachable via `Enumlib.LegacyImport.foo`
    # with a per-call deprecation warning; targeted for removal in v0.3.

"""
    avg_cell_radius(B) -> Float64

Get the average distance from the center of the unit cell `B` to its 8 corners. Used as a unit-cell size measure for the radius-based supercell selection ([`RadiusBound`](@ref)). Minkowski-reduces the basis first so the measure is independent of the user's cell representation (e.g., a skewed basis and its Minkowski-reduced equivalent get the same value).

Average distance (rather than max) gives finer tie-breaking — 8 corner distances rarely all match pairwise — and is more descriptive for elongated cells (max gets dominated by the longest direction; avg weights all axes smoothly). For a cube `avg ≈ max ≈ side·√3/2` so the difference only shows up for non-cubic cells.

# Examples
A unit cube spans `[0, 1]^3`; its center is at `(0.5, 0.5, 0.5)`, equidistant from all 8 corners at `√3/2 ≈ 0.866`.
```jldoctest
julia> using LinearAlgebra: I

julia> avg_cell_radius(Matrix{Float64}(I, 3, 3))
0.8660254037844385
```
"""
function avg_cell_radius(B)
    A = minkReduce(B)
    center = (A[:,1] + A[:,2] + A[:,3]) ./ 2
    corners = [[0., 0., 0.], A[:,1], A[:,2], A[:,3],
               A[:,1]+A[:,2], A[:,1]+A[:,3], A[:,2]+A[:,3], A[:,1]+A[:,2]+A[:,3]]
    distances = [norm(center - c) for c in corners]
    return sum(distances) / length(distances)
end

# --- cluster equivalence (no enum-file deps) ---

"""
    canonClustOrder!(clust)

Apply canonical ordering of cluster vertices for robust comparison.
"""
function canonClustOrder!(clust)
    clust .= hcat(sort(eachslice(clust, dims=2))...)
end

"""
    isTransEquiv(c1, c2)

Returns true if cluster 1 `c1` and  cluster `c2` are translates of each other.
"""
# The difference between the first vertex of c1 and c2 is the same as the difference between all the other vertices of c1 and c2
function isTransEquiv(c1, c2)
    return any([all([(c1.-c2)[:,1]] .≈ eachslice(c1.-c2, dims=2)[2:end])])
end

"""
    isRotTransEquiv(t1, t2, G)

Returns true if `t1` and any `g*t2` for `g ∈ G` are just translates of each
other. The point group `G` should be in the same coordinates as the points.
"""
function isRotTransEquiv(t1, t2, G)
    t1 = canonClustOrder!(t1)
    for g ∈ G
        t2g = hcat(sort(eachslice(g * t2, dims=2))...)
        if isTransEquiv(t1, t2g)
            return true
        end
    end
    return false
end

"""
    deleteTransDuplicates!(clusterList)

Remove clusters from `clusterList` that are translational duplicates of
another cluster.
"""
function deleteTransDuplicates!(clusterList)
    mask = falses(length(clusterList))
    for jr in eachindex(clusterList)
        if mask[jr] continue end
        for kr in jr+1:length(clusterList)
            t1 = hcat(sort(eachslice(clusterList[jr], dims=2))...)
            t2 = hcat(sort(eachslice(clusterList[kr], dims=2))...)
            if isTransEquiv(t1, t2)
                mask[kr] = true
            end
        end
    end
    deleteat!(clusterList, mask)
end

# --- group theory utilities ---

"""
    isaGroup(G)

Check whether the rows of `G` are closed under composition (i.e., form a
permutation group).
"""
# Is G a vector of matrices? Or a 3D array? Let's document this a bit better. 
function isaGroup(G)
    isagroup = true
    for iG in eachrow(G)
        for jG in eachrow(G)
            if iG[jG] ∉ eachrow(G)
                isagroup = false
            end
        end
    end
    return isagroup
end

"""
    generateGroup(generators)

Given a matrix whose rows are permutation generators, generate the full
group. Returns the rows sorted (identity first).
"""
function generateGroup(generators)
    while true
        closed = true
        for iG ∈ eachrow(generators)
            for jG ∈ eachrow(generators)
                if iG[jG] ∉ eachrow(generators)
                    generators = [generators; iG[jG]']
                    closed = false
                end
            end
        end
        if closed break end
    end
    return sortslices(generators, dims=1)
end

"""
    coloring_hash(mul, c)

Hash a coloring `c` of a tile into its base-`k` integer using the place values in
`mul`. The unconventional name avoids shadowing `Base.hash` inside the Enumlib module.
"""
function coloring_hash(mul, c)
    return sum(mul .* c)
end

"""
    coloring_unhash(idx, k, n)

Inverse of [`coloring_hash`](@ref): convert a base-`k` integer `idx` back into a
coloring of length `n` with `k` colors.
"""
function coloring_unhash(idx, k, n)
    coloring = zeros(Int64, n)
    r = idx - 1
    for i in n-1:-1:0
        d, r = divrem(r, k^i)
        coloring[n-i] = d
    end
    return coloring
end

# --- colorings ---

"""
    getColorings(k, n)

Generate the full list of `k`-ary colorings on `n` sites. Each coloring is
a vector of integers in `0:k-1`.
"""
function getColorings(k, n)
    return [collect(reverse(Tuple(c))) for c in CartesianIndices(ntuple(i->0:k-1, n))][:]
end

"""
    reduceColorings(colorings, k, G)

Reduce a list of colorings to the symmetrically inequivalent ones under the
group `G` (rows are permutations of the sites).
"""
function reduceColorings(colorings, k, G)
    n = length(colorings[1])
    mul = [k^(i-1) for i ∈ reverse(1:n)]
    hashTbl = trues(length(colorings))
    for (i, ic) in enumerate(colorings)
        if !hashTbl[i] continue end
        for g ∈ eachrow(G)
            test = coloring_hash(mul, ic[g]) + 1
            if test > i
                hashTbl[test] = false
            end
        end
    end
    return colorings[hashTbl]
end

"""
    getSymEqvColorings_slow(k, n, G)

Generate all colorings and reduce to symmetrically inequivalent ones under
`G`. Slower than [`getUniqueColorings`](@ref) (which uses a permutation
group from an HNF) but useful when only a permutation matrix is in hand.
"""
function getSymEqvColorings_slow(k, n, G)
    colorings = getColorings(k, n)
    return reduceColorings(colorings, k, G)
end

# --- enumeration sources (must come after the utilities they don't use,
#     before the functions that depend on getTransGroup, etc.) ---

include("LatticeColoringEnumeration.jl")
include("CEdataSupport.jl")
include("clusterequvi.jl")
# readPOSCAR.jl and makePOSCAR.jl live in scratch/ for now; they're
# standalone scripts with top-level scratch code that needs cleanup before
# they can be part of the module proper.

# --- permutation groups (depend on getTransGroup from LatticeColoringEnumeration) ---

"""
    getPermG(h, fixingOps, parent::ParentLattice{D}) where D

Permutation group for the supercell `h` on the multilattice `D × G` site set
(size `n_D · n` where `n_D = ndset(parent)` and `n = vol(h)`), given the ordinal
mask `fixingOps` selecting the rotations that fix the superlattice.

For each fixing op `(N, t)`, applies the per-site action from the dset-mapping
writeup (`docs/notes/multilattice_dset_mapping_writeup.pdf`) using the
precomputed `(π, v_i)` cached on `parent`:

    (d_i, g)  →  (d_{π(i)}, g')   with  g' = T·v_i + (T·N·T⁻¹)·g   (mod SNF diag)

where `T` is the SNF left-transition matrix. Pure integer arithmetic — the
precomputed `v_i` is integer-valued in lattice coords; no tolerance needed once
we're in the SNF basis. Composes with the supercell translation subgroup
`T_supercell` (each `τ ∈ G` acts as `(d_i, g) → (d_i, g+τ)`, same shift applied
within every dset block).

Site ordering: `flat_idx(d_i, g) = (i-1)·n + g_idx` — "dset blocks", matching
the Fortran enumlib's convention in `get_rotation_perms_lists`. Single-lattice
(n_D = 1) degenerates exactly to the single-site path because the precomputed
`π = [1]` and `v = [[0,0,0]]` make the dset-permutation and shift terms trivial.

Returns `Vector{Vector{Int}}` — perm-group permutations of length `n_D · n`.
"""
function getPermG(h, fixingOps, parent::ParentLattice{D}) where D
    S, L_snf, _ = snf(h)
    Linv = round.(Int, inv(L_snf))
    diag_S = diag(S)
    z1, z2, z3 = diag_S
    n   = prod(diag_S)
    n_D = ndset(parent)
    LG  = lattice_rotations(parent)

    GspcSites = [[i, j, k] for i in 0:z1-1 for j in 0:z2-1 for k in 0:z3-1]
    factor    = [z2*z3, z3, 1]                # g flat index = i*z2*z3 + j*z3 + k + 1

    fixing_indices = findall(fixingOps)
    rotPerms = Vector{Vector{Int}}()
    for op_idx in fixing_indices
        N_op = LG[op_idx]
        π    = parent.dset_perms[op_idx]
        v    = parent.dset_shifts[op_idx]
        TNT⁻¹ = L_snf * N_op * Linv           # T · N · T⁻¹ (integer matrix)
        perm = Vector{Int}(undef, n_D * n)
        for i in 1:n_D
            Tv = L_snf * v[i]                 # T · v_i (integer vector)
            for (g_idx, g) in enumerate(GspcSites)
                g_prime      = mod.(Tv + TNT⁻¹ * g, diag_S)
                g_prime_flat = sum(g_prime .* factor) + 1
                src_idx = (i - 1) * n + g_idx
                img_idx = (π[i] - 1) * n + g_prime_flat
                perm[src_idx] = img_idx
            end
        end
        push!(rotPerms, perm)
    end

    # Deduplicate (different fixing rotations can induce the same site perm)
    # and put into canonical order (matches the legacy single-lattice method's
    # `unique! ∘ sort!`).
    unique!(rotPerms)
    sort!(rotPerms)

    # Compose with the supercell translation subgroup: τ ∈ G acts as
    # (d_i, g) → (d_i, g+τ). In flat indexing, that's the same `tGrp[k]`
    # permutation applied within each dset block.
    tGrp = getTransGroup([z1, z2, z3])        # Vector{Vector{Int}}, perms of length n
    perms = Vector{Vector{Int}}()
    for iR in rotPerms
        for iT in tGrp
            full_iT = vcat((iT .+ (i-1)*n for i in 1:n_D)...)
            push!(perms, iR[full_iT])         # composition: iT then iR
        end
    end
    return perms
end

# --- colorings via permutation group (depends on coloring_hash / coloring_unhash above) ---

"""
    getUniqueColorings(k, pG; include_superperiodic = false)

Given the permutation group `pG` of a supercell (from
[`getPermG`](@ref)), return the symmetrically inequivalent `k`-ary
colorings.

By default (`include_superperiodic = false`), drops super-periodic colorings —
those fixed by some non-identity pure translation, which would be duplicates
of smaller-supercell derivatives across a volume sweep. Pass `true` to keep
them and return the full Burnside orbit space (research.md §5.2.1).
"""
function getUniqueColorings(k, pG; include_superperiodic::Bool = false,
                            n_translations::Int = length(pG[1]))
    n = length(pG[1])
    idx = ntuple(i->0:k-1, n)
    mul = [k^(i-1) for i ∈ reverse(1:n)]
    hashTbl = trues(k^n)
    # Super-periodicity is detected by checking fix-by-translation: pG[1..n_T]
    # is identity-rotation × translation-subgroup (size n_T = |T| = n_cells).
    # For single-lattice n_T = n = n_cells; for multilattice the caller passes
    # n_T = n_cells (n = n_D · n_cells). The legacy default n_T = n preserves
    # single-lattice behavior.
    for (i, ic) in enumerate(CartesianIndices(idx))
        c = reverse(Tuple(ic))
        if !hashTbl[i] continue end
        for (ig, g) ∈ enumerate(pG[2:end])
            test = coloring_hash(mul, c[g]) + 1
            # `ig < n_translations` selects pG[2..n_T] — the n_T-1 non-identity
            # pure translations. A coloring fixed by one of those is super-periodic.
            if test > i || (!include_superperiodic && test == i && ig < n_translations)
                hashTbl[test] = false
            end
        end
    end
    return [coloring_unhash(i, k, n) for i ∈ findall(hashTbl)]
end

# --- chunk 3 type catalog (depends on getFixingOps, getPermG, getSymInequivHNFs,
#     and snf — all defined above) ---
include("types/hnf.jl")
include("types/supercell.jl")

# --- chunk 4 type catalog (depends on chunk 3 types + avg_cell_radius +
#     getAllHNFs + basesAreEquiv) ---
include("types/supercell_selection.jl")

# --- chunk 5: output types + the public `enumerate(...)` entry point.
#     Depends on chunk 1–4 types and the legacy getUniqueColorings (above). ---
include("types/enumeration.jl")
# --- chunk 6: Concentration + multinomial algorithm + Phase-7 error types ---
# Note: cost_estimate.jl must precede errors.jl because EnumerationTooLargeError
# (chunk 7.5) carries an EnumerationCostEstimate as a struct field.
include("types/concentration.jl")
include("types/cost_estimate.jl")
include("types/errors.jl")
include("algorithms/multinomial.jl")
# --- chunk 6.5a: multinomial-restricted (HF 2012 §A.1) — bitmap + site-mask ---
include("algorithms/multinomial_restricted.jl")
# --- chunk 8: Morgan 2017 recursive-stabilizer tree (uses chunk-6 hash) ---
include("algorithms/recursive_stabilizer.jl")
# --- chunk 7: Polya submodule + InequivalentCount type ---
include("algorithms/polya.jl")
include("types/inequivalent_count.jl")
using .Polya: polya_count, cycle_structure, aperiodic_orbit_count
# --- public entry; depends on all of the above ---
include("enumerate.jl")
# --- chunk 11a: POSCAR writer (must come after all types) ---
include("io/poscar.jl")

# --- chunk 13b.1: deprecation shim for legacy I/O symbols ---
#
# The Fortran-format file I/O (CEdataSupport.jl) is un-exported in v0.2 —
# superseded by the chunk-11 POSCAR I/O. It remains reachable via this
# submodule so existing user code can keep running for one minor release;
# each call emits a `Base.depwarn`. Targeted for full removal at some future v0.x.
#
# The radius-based enumeration entry points (formerly in radiusEnumeration.jl —
# `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`,
# `getSymInequivHNFsByCellRadius`, `estimatedTime`) were dropped in v0.3-prep
# (2026-05-17) — superseded by `enumerate(..., supercells = RadiusBound(...))`
# in chunk 4. The legacy `getPermG(h, fixingOps, LG::Vector{Matrix{Int}})`
# method was their only remaining single-lattice consumer; removed in the same
# pass.
module LegacyImport
import ..Enumlib

const _LEGACY = (
    :enumStr, :readStructenumout, :readEnergies, :readStrIn,
)

for fn in _LEGACY
    @eval function $(fn)(args...; kwargs...)
        Base.depwarn(
            "Enumlib.LegacyImport." * $(string(fn)) *
            " is deprecated and will be removed in v0.3.",
            $(QuoteNode(fn)),
        )
        return Enumlib.$(fn)(args...; kwargs...)
    end
end

end # module LegacyImport

end # module Enumlib
