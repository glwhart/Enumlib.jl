# Multinomial-restricted algorithm — Hart-Forcade 2012 §A.1 (chunk 6.5a).
#
# Fixed-concentration enumeration with per-site `allowed_labels` (Regime C).
# Same machinery as chunk 6's `:multinomial`, with a site-mask filter that
# drops bitmap slots whose underlying coloring violates the per-position
# label restrictions. Cross-checks against `:recursive_stabilizer` (chunk
# 6.5b); both return the same set of orbit-canonical labelings for any
# (parent, sites, supercells, concentration) tuple in Regime C.
#
# Implementation note (initial 6.5a landing): the algorithm uses the same
# linear iteration over the bitmap [0, C-1] as chunk 6 (`C` is the full
# multinomial coefficient `multinomial(n; multiplicities)`), with a lazy
# mask check on each unvisited slot. Slots that violate the mask are
# marked visited and skipped without further work. This is correct but
# allocates the *full* multinomial bitmap even when most slots are
# invalid (a sparse-mask case like perovskite at n=4 has C ≈ 7e5 valid
# Regime-C labelings out of multinomial(20; 2,2,3,3,12) ≈ 7.7e12 total —
# the bitmap is by-construction the full multinomial size). The chunk-7.5
# enumeration resource check gates this against `memory_budget`; for
# very sparse masks the `:auto` dispatch routes to `:recursive_stabilizer`
# instead (the tree never allocates a bitmap and scales by the valid
# subspace, not the multinomial space). A tree-walk variant that prunes
# at branching time (HF 2012 §A.1's "skip disallowed states" framing) is
# queued as a v0.3 perf-polish item if production usage shows it's needed.

"""
    getUniqueColorings_multinomial_restricted(perm_group::AbstractVector,
                                              multiplicities::AbstractVector{<:Integer},
                                              site_mask::BitMatrix) -> Vector{Vector{Int8}}

Symmetry-inequivalent colorings at fixed concentration with per-site `allowed_labels` (Regime C). The chunk-6 bitmap-and-crossing-out machinery, extended with a site-mask filter.

Iterates over all `C = multinomial(n; multiplicities)` valid colorings (each at its hash index), maintains a `BitVector(C)` "visited" mask, and at each unvisited coloring (a) checks the site mask — invalid slots are marked visited and skipped — and (b) when valid, crosses out the σ-images for every σ in `perm_group` (the σ-images are guaranteed mask-valid when `perm_group` is the effective per-supercell group, since chunk 6.5c filters parent ops that don't preserve `allowed_labels` equivalence classes).

Returns every canonical labeling — one per orbit. Super-periodic filtering is the caller's job; `_enumerate_per_concentration` post-filters via `_is_super_periodic` with `n_cells = volume(hnf)` in scope.

The chunk-6.5b analog is `getUniqueColorings_recursive_stabilizer(perm_group, multiplicities; site_mask)`. Both return the same set of canonical labelings under any (parent, sites, supercells, concentration); the cross-algorithm equality assertion is the load-bearing correctness test for chunk 6.5a.
"""
function getUniqueColorings_multinomial_restricted(perm_group,
                                                    multiplicities::AbstractVector{<:Integer},
                                                    site_mask::BitMatrix)
    n = sum(multiplicities)
    k = length(multiplicities)
    size(site_mask) == (n, k) ||
        throw(DimensionMismatch(
            "site_mask must be ($n, $k), got $(size(site_mask))"))

    C = multinomial_count(multiplicities)
    C <= typemax(Int) ||
        throw(ArgumentError(
            "multinomial coefficient $(C) exceeds typemax(Int) — this enumeration " *
            "needs the recursive-stabilizer (Morgan 2017) algorithm. Pass " *
            "`algorithm = :recursive_stabilizer`."))
    C_int = Int(C)

    visited = trues(C_int)
    survivors = Vector{Int8}[]
    for idx in 0:C_int-1
        visited[idx + 1] || continue
        coloring = multinomial_unhash(idx, multiplicities)

        # Site-mask filter: this bitmap slot corresponds to a coloring that
        # may or may not respect the per-position allowed_labels. If it
        # doesn't, mark visited and skip. The σ-images (crossed out below)
        # are guaranteed mask-valid because the effective perm group only
        # contains ops that preserve allowed_labels equivalence classes
        # (chunk 6.5c parent-level filter + chunk 6.5b per-supercell mask
        # filter as defense-in-depth).
        if !_coloring_satisfies_mask(coloring, site_mask)
            visited[idx + 1] = false
            continue
        end

        push!(survivors, coloring)

        # Cross out symmetry-equivalent labelings (including the labeling itself).
        for g in perm_group
            permuted = coloring[g]
            j = multinomial_hash(permuted, multiplicities)
            visited[j + 1] = false
        end
    end
    return survivors
end

# Coloring c is mask-valid iff every position holds a label in its allowed set.
# `site_mask[pos, c+1] == true` means species `c` is allowed at position `pos`.
function _coloring_satisfies_mask(coloring::AbstractVector{<:Integer},
                                   site_mask::BitMatrix)
    @inbounds for pos in eachindex(coloring)
        site_mask[pos, coloring[pos] + 1] || return false
    end
    return true
end
