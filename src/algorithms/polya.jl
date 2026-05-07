# Pólya / Burnside orbit counting and the Möbius-corrected aperiodic count.
#
# Two layers:
#
# 1. Math primitives (`polya_count`, `cycle_structure`) — raw Burnside orbit
#    counts. Always include super-periodic orbits. The standard Pólya
#    enumeration theorem.
#
# 2. Aperiodic helper (`aperiodic_orbit_count`) — Möbius inversion over the
#    subgroup lattice of the supercell's translation subgroup T. Subtracts
#    super-periodic orbits to match `enumerate(...)`'s default-`false` count.
#
# Used by `count_inequivalent(...)` (in src/enumerate.jl) to give users a
# pre-flight count without enumerating. See research.md §4.6, §5.2.1, §7.2.

module Polya

using ..Enumlib: ParentLattice, Sites, Supercell, HNF

export polya_count, cycle_structure, aperiodic_orbit_count

"""
    cycle_structure(perm) :: Vector{Int}

Cycle-length multiset of a permutation, sorted descending.

For `perm = [2, 1, 4, 3, 5]`: cycles are `(1 2)(3 4)(5)`, so result is `[2, 2, 1]`.
"""
function cycle_structure(perm::AbstractVector{<:Integer})::Vector{Int}
    n = length(perm)
    visited = falses(n)
    lengths = Int[]
    for i in 1:n
        visited[i] && continue
        len = 0
        j = i
        while !visited[j]
            visited[j] = true
            j = perm[j]
            len += 1
        end
        push!(lengths, len)
    end
    sort!(lengths, rev = true)
    return lengths
end

"""
    polya_count(perm_group, k::Integer) :: BigInt

Burnside-averaged count of orbits of `k`-colorings under `perm_group` — the raw orbit count, including super-periodic orbits. For each `ρ ∈ perm_group` with `c(ρ)` cycles, fix(ρ) = `k^c(ρ)`; orbit count = `(1/|G|) Σ_ρ k^c(ρ)`.

Returns `BigInt`. Cost: O(|G| · n).

The aperiodic version is [`aperiodic_orbit_count`](@ref).
"""
function polya_count(perm_group, k::Integer)::BigInt
    isempty(perm_group) && throw(ArgumentError("perm_group must be non-empty"))
    total = BigInt(0)
    for perm in perm_group
        c = _num_cycles(perm)
        total += BigInt(k)^c
    end
    return total ÷ length(perm_group)
end

"""
    polya_count(perm_group, multiplicities::AbstractVector{<:Integer}) :: BigInt

Burnside-averaged orbit count at fixed multiplicities. For each `ρ` with cycle lengths `[c_1, ..., c_t]`, the number of fixed colorings is the coefficient of `x_1^{a_1}⋯x_k^{a_k}` in `∏_j (x_1^{c_j} + ⋯ + x_k^{c_j})` (HF 2012 §A.2). Computed via dynamic programming over partial-multiplicity states.

Cost per permutation: O(t · ∏(a_i + 1) · k). Across the whole group: O(|G| · t · ∏(a_i + 1) · k).
"""
function polya_count(perm_group, multiplicities::AbstractVector{<:Integer})::BigInt
    isempty(perm_group) && throw(ArgumentError("perm_group must be non-empty"))
    n_total = sum(multiplicities)
    for perm in perm_group
        length(perm) == n_total ||
            throw(DimensionMismatch(
                "permutation length $(length(perm)) ≠ sum(multiplicities) = $n_total"))
    end
    total = BigInt(0)
    for perm in perm_group
        cyc = cycle_structure(perm)
        total += _fixed_colorings_at_concentration(cyc, multiplicities)
    end
    return total ÷ length(perm_group)
end

"""
    aperiodic_orbit_count(perm_group, snf_diagonal, k_or_mults) :: BigInt

Aperiodic orbit count — orbits whose stabilizer in the supercell's translation subgroup `T` is trivial. Matches `length(enumerate(...; include_superperiodic = false))` per supercell.

`snf_diagonal` is a 3-tuple `(d_1, d_2, d_3)` from the supercell HNF's Smith Normal Form, with `d_1 | d_2 | d_3` (so `T = Z/d_1 × Z/d_2 × Z/d_3` and `|T| = d_1·d_2·d_3 = n`). `k_or_mults` is either an `Integer` (unrestricted, k colors) or `AbstractVector{<:Integer}` (fixed multiplicities).

Burnside on the aperiodic-labeling subspace, with the per-permutation count expanded by Möbius inversion over the subgroup lattice of `T`:

    N_aperiodic = (1/|G|) · Σ_{g ∈ G} Σ_{H ⊆ T} μ_T(H) · |fix(g) ∩ fix(H)|

where `|fix(g) ∩ fix(H)|` is the number of labelings fixed by both `g` and every element of `H` — equivalently, labelings constant on each joint orbit of `{g} ∪ H_perms` acting on supercell positions. For unrestricted k-colorings this is `k^(num joint orbits)`; for fixed multiplicities it's the polynomial-coefficient DP on the joint-orbit partition.

This formulation is correct for non-normal H (subgroups of T need not be normal in G — e.g., for SNF `(1, 2, 2)` where `T = Z/2 × Z/2` is non-cyclic). Earlier sketches assumed H-normality and gave wrong counts on non-cyclic T.

For our v0.2 sizes (|T| ≤ ~32), subgroup enumeration is cheap; the inner per-(g, H) joint-orbit computation is `O(n + |H|)` via union-find.
"""
function aperiodic_orbit_count(perm_group, snf_diagonal::NTuple{3,Int}, k::Integer)::BigInt
    return _aperiodic_orbit_count_impl(perm_group, snf_diagonal) do orbit_sizes
        # Unrestricted k-coloring fixed-count: k^(num joint orbits).
        BigInt(k)^length(orbit_sizes)
    end
end

function aperiodic_orbit_count(perm_group, snf_diagonal::NTuple{3,Int},
                               multiplicities::AbstractVector{<:Integer})::BigInt
    n = sum(multiplicities)
    n == prod(snf_diagonal) ||
        throw(DimensionMismatch(
            "sum(multiplicities) = $n ≠ prod(snf_diagonal) = $(prod(snf_diagonal))"))
    return _aperiodic_orbit_count_impl(perm_group, snf_diagonal) do orbit_sizes
        # Fixed-multiplicity fixed-count: polynomial coefficient on orbit sizes
        # (the "cycle structure" for the polynomial DP).
        _fixed_colorings_at_concentration(orbit_sizes, multiplicities)
    end
end

# ------------------------------------------------------------------------------
# Internal helpers
# ------------------------------------------------------------------------------

# Number of cycles in a permutation.
function _num_cycles(perm::AbstractVector{<:Integer})::Int
    n = length(perm)
    visited = falses(n)
    count = 0
    for i in 1:n
        visited[i] && continue
        count += 1
        j = i
        while !visited[j]
            visited[j] = true
            j = perm[j]
        end
    end
    return count
end

# Coefficient of x_1^{a_1}⋯x_k^{a_k} in ∏_j (x_1^{c_j} + ⋯ + x_k^{c_j}).
#
# DP: state = partial-multiplicity vector; after processing cycle j we have the
# coefficient of each reachable monomial. Transition: for cycle j of length c_j,
# for each color i, add c_j to the i'th coordinate. Drop paths where any
# coordinate exceeds the target.
#
# Storage: dense Array{BigInt, k}. Trip-wire — memory grows as ∏(a_i + 1):
# 1 MB at k=5 with all a_i=10; 100 MB at k=6 with all a_i=13.
function _fixed_colorings_at_concentration(cycle_lengths::AbstractVector{<:Integer},
                                           multiplicities::AbstractVector{<:Integer})::BigInt
    k = length(multiplicities)
    k == 0 && return BigInt(1)
    dims = ntuple(i -> multiplicities[i] + 1, k)
    state = zeros(BigInt, dims...)
    state[ntuple(_ -> 1, k)...] = BigInt(1)    # the (0,0,...,0) partial state
    for c in cycle_lengths
        new_state = zeros(BigInt, dims...)
        for I in CartesianIndices(state)
            count = state[I]
            iszero(count) && continue
            for color in 1:k
                new_idx = I[color] + c          # 1-indexed
                new_idx > multiplicities[color] + 1 && continue
                J = CartesianIndex(ntuple(j -> j == color ? new_idx : I[j], k))
                new_state[J] += count
            end
        end
        state = new_state
    end
    return state[ntuple(i -> multiplicities[i] + 1, k)...]
end

# Driver. Walks (g, H) pairs and sums μ_T(H) · |fix(g) ∩ fix(H)|. The closure
# `fix_count(orbit_sizes::Vector{Int})` returns the labeling-fixed-count given
# the joint-orbit partition: `k^(length)` for unrestricted, polynomial-DP for
# fixed-multiplicity.
function _aperiodic_orbit_count_impl(fix_count::Function, perm_group,
                                     snf_diagonal::NTuple{3,Int})::BigInt
    n = prod(snf_diagonal)
    isempty(perm_group) && throw(ArgumentError("perm_group must be non-empty"))
    length(perm_group[1]) == n ||
        throw(DimensionMismatch(
            "permutation length $(length(perm_group[1])) ≠ |T| = $n"))

    # Pre-materialize each subgroup H as a list of permutations on n positions.
    H_perms_with_mu = [(_translation_perms(snf_diagonal, H), mu)
                       for (H, mu) in _subgroups_with_mobius(snf_diagonal) if mu != 0]

    total_sum = BigInt(0)
    for g in perm_group
        for (H_perms, mu) in H_perms_with_mu
            orbit_sizes = _joint_orbit_partition(g, H_perms, n)
            total_sum += mu * fix_count(orbit_sizes)
        end
    end
    return total_sum ÷ length(perm_group)
end

# Subgroups of T = Z/d_1 × Z/d_2 × Z/d_3 with their Möbius coefficients
# μ({0}, H) on the subgroup lattice of T.
#
# A subgroup H is given by a set of generators (each a triple in Z/d_1 × Z/d_2 ×
# Z/d_3), but we want a canonical representation. Strategy: enumerate H by its
# "elements" (every H-element is a 3-tuple modulo (d_1, d_2, d_3)). For our
# v0.2 sizes (|T| ≤ ~32), brute-force enumeration of subsets-that-form-subgroups
# is trivially fast.
#
# Möbius computation: build the subgroup poset, then compute μ via the standard
# recurrence μ({0}, {0}) = 1; μ({0}, H) = -Σ_{K ⊊ H} μ({0}, K).
#
# Returns Vector{Tuple{Set{NTuple{3,Int}}, Int}} where each entry is (H as a
# set of elements, Möbius coefficient).
function _subgroups_with_mobius(snf_diagonal::NTuple{3,Int})
    d1, d2, d3 = snf_diagonal
    T_elements = [(i, j, k) for i in 0:d1-1, j in 0:d2-1, k in 0:d3-1] |> vec

    # Enumerate all subgroups by a saturating-closure walk: start from a candidate
    # generator set, close under addition, that's a subgroup. Two candidate sets
    # produce the same subgroup if they generate the same closure; deduplicate.
    subgroup_set = Set{Set{NTuple{3,Int}}}()
    push!(subgroup_set, Set([(0, 0, 0)]))         # trivial subgroup
    for elt in T_elements
        elt == (0, 0, 0) && continue
        # Cyclic subgroup generated by elt.
        cyclic = _cyclic_subgroup(elt, snf_diagonal)
        push!(subgroup_set, cyclic)
    end
    # Close under pairwise span: for each pair of subgroups already found, their
    # span is also a subgroup. Iterate to fixpoint.
    while true
        added = false
        for H in collect(subgroup_set), K in collect(subgroup_set)
            spanned = _span(H, K, snf_diagonal)
            if !(spanned in subgroup_set)
                push!(subgroup_set, spanned)
                added = true
            end
        end
        added || break
    end

    # Order subgroups for Möbius: process from smallest to largest.
    subgroups = sort(collect(subgroup_set); by = length)

    # Möbius computation: μ({0}, H) = δ_{H,{0}} - Σ_{K ⊊ H} μ({0}, K).
    mu = Dict{Set{NTuple{3,Int}}, Int}()
    for H in subgroups
        if length(H) == 1
            mu[H] = 1
        else
            total = 0
            for K in subgroups
                length(K) >= length(H) && break
                issubset(K, H) || continue
                total += mu[K]
            end
            mu[H] = -total
        end
    end

    return [(H, mu[H]) for H in subgroups]
end

# Cyclic subgroup generated by `elt` in T = Z/d_1 × Z/d_2 × Z/d_3.
function _cyclic_subgroup(elt::NTuple{3,Int}, snf_diagonal::NTuple{3,Int})
    d1, d2, d3 = snf_diagonal
    H = Set{NTuple{3,Int}}()
    cur = (0, 0, 0)
    while true
        push!(H, cur)
        cur = (mod(cur[1] + elt[1], d1),
               mod(cur[2] + elt[2], d2),
               mod(cur[3] + elt[3], d3))
        cur in H && break
    end
    return H
end

# Subgroup spanned by H ∪ K under the abelian group operation.
function _span(H::Set{NTuple{3,Int}}, K::Set{NTuple{3,Int}}, snf_diagonal::NTuple{3,Int})
    d1, d2, d3 = snf_diagonal
    spanned = Set{NTuple{3,Int}}()
    for h in H, k in K
        push!(spanned, (mod(h[1] + k[1], d1),
                        mod(h[2] + k[2], d2),
                        mod(h[3] + k[3], d3)))
    end
    # Close under addition until fixpoint.
    while true
        added = false
        elements = collect(spanned)
        for x in elements, y in elements
            sum_xy = (mod(x[1] + y[1], d1),
                      mod(x[2] + y[2], d2),
                      mod(x[3] + y[3], d3))
            if !(sum_xy in spanned)
                push!(spanned, sum_xy)
                added = true
            end
        end
        added || break
    end
    return spanned
end

# Materialize a subgroup H of T = Z/d_1 × Z/d_2 × Z/d_3 as a list of permutations
# on n = d_1·d_2·d_3 positions. Each h = (a, b, c) ∈ H induces the permutation
# "shift position (i, j, k) → ((i+a) mod d_1, (j+b) mod d_2, (k+c) mod d_3)".
#
# Position layout matches `getPermG`'s: index = i*(d_2·d_3) + j*d_3 + k + 1
# with i changing slowest, k fastest. The identity element (0,0,0) is included
# (it's `1:n` and is harmless under union-find — adding a no-op to the joint).
function _translation_perms(snf_diagonal::NTuple{3,Int},
                            H::Set{NTuple{3,Int}})
    d1, d2, d3 = snf_diagonal
    n = d1 * d2 * d3
    factor = (d2 * d3, d3, 1)

    perms = Vector{Vector{Int}}()
    for h in H
        perm = Vector{Int}(undef, n)
        idx = 0
        for i in 0:d1-1, j in 0:d2-1, k in 0:d3-1
            idx += 1
            ni = mod(i + h[1], d1)
            nj = mod(j + h[2], d2)
            nk = mod(k + h[3], d3)
            new_idx = ni * factor[1] + nj * factor[2] + nk * factor[3] + 1
            perm[idx] = new_idx
        end
        push!(perms, perm)
    end
    return perms
end

# Joint-orbit partition of `{g} ∪ H_perms` acting on `n` positions.
#
# Returns the orbit-size multiset (a partition of n). A labeling is fixed by
# every element of this set iff it's constant on each joint orbit. So this
# partition is the "cycle structure" used by both the unrestricted (k^cycles)
# and fixed-multiplicity (polynomial-coefficient DP) fixed-count formulas.
#
# Implementation: union-find. Initialize each position as its own component;
# for each perm `p` (g and every H-perm) and each i, union(i, p[i]).
function _joint_orbit_partition(g::AbstractVector{<:Integer},
                                H_perms::AbstractVector,
                                n::Int)::Vector{Int}
    parent = collect(1:n)

    function find(i)
        root = i
        while parent[root] != root
            root = parent[root]
        end
        # Path compression.
        j = i
        while parent[j] != root
            parent[j], j = root, parent[j]
        end
        return root
    end

    function union(i, j)
        ri, rj = find(i), find(j)
        ri == rj && return
        parent[ri] = rj
    end

    for i in 1:n
        union(i, g[i])
    end
    for p in H_perms, i in 1:n
        union(i, p[i])
    end

    # Tally orbit sizes.
    sizes = Dict{Int, Int}()
    for i in 1:n
        r = find(i)
        sizes[r] = get(sizes, r, 0) + 1
    end
    return collect(values(sizes))
end

end  # module Polya
