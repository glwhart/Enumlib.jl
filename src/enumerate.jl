"""
    enumerate(parent::ParentLattice{D}, sites::Sites{D};
              supercells::SupercellSelection,
              concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
              algorithm::Symbol = :auto,
              memory_budget::Int = default_memory_budget(),
              on_overflow::Symbol = :error,
              partition_threshold::Int = 100,
              on_partition_overflow::Symbol = :error,
              include_superperiodic::Bool = false,
              skip_resource_check::Bool = false) -> Enumeration{D, Vector{Int8}}

Enumerate symmetry-inequivalent derivative structures of `parent` decorated by labelings drawn from `sites.allowed_labels`, over the supercells specified by `supercells`, optionally constrained to a fixed `concentration` or `ConcentrationRange`.

## Algorithm dispatch

- `algorithm = :auto` (default): the tree (`:recursive_stabilizer`) for almost everything — including unrestricted enumeration, where `:auto` synthesizes a full-range `ConcentrationRange` internally (bench Section 5 shows ~2-3× speedup and ~half the memory vs the bitmap). With `concentration` supplied, picks between `:multinomial` and `:recursive_stabilizer` by predicted memory; for Regime C, picks `:recursive_stabilizer`. Falls through to `:exhaustive` only for the (unsupported) "Regime C unrestricted" case so the validation error fires.
- `algorithm = :exhaustive` (Hart-Forcade 2008): unrestricted enumeration via the `k^n` bitmap; ignores `concentration` if supplied. Not `:auto`'s default — use it explicitly for the bitmap's memory profile or to cross-check the tree.
- `algorithm = :multinomial` (Hart-Forcade 2012): fixed-concentration enumeration via the multinomial-hash crossing-out. Requires `concentration !== nothing`; Regime A and Regime B only.
- `algorithm = :multinomial_restricted` (HF 2012 §A.1): the bitmap variant with a site-mask filter, for heterogeneous sublattices (Regime C — perovskite, half/full Heusler, wurtzite, zinc-blende, etc.). Requires `concentration !== nothing`.
- `algorithm = :recursive_stabilizer` (Morgan 2017): tree-search-with-shrinking-stabilizers; streams (no bitmap) and beats the bitmap algorithms in nearly every measured case. `:auto`'s default for both unrestricted and fixed-concentration when the bitmap doesn't fit (or always, for Regime C).

## Concentration handling

- `concentration === nothing` → unrestricted.
- `concentration::Concentration` → single fixed concentration; the multinomial-hash algorithm enumerates the exactly-`a_i`-of-each-species labelings.
- `concentration::ConcentrationRange` → loops over `concentrations_in_range(cr, n)` for each supercell volume; gates against partition explosion via `partition_threshold` (default 100).

## Super-periodicity policy

`include_superperiodic = false` (default) drops colorings whose true period strictly divides the supercell — these are duplicates of smaller-supercell derivatives across a volume sweep (HF 2008 step 5d). `include_superperiodic = true` keeps them and returns the full Burnside orbit space; useful for theoretical comparisons or single-volume queries where the user wants every orbit.

## Returns

`Enumeration{D, Vector{Int8}}` containing the parent, sites, list of distinct supercells encountered, and the enumerated structures. Iterable + indexable.

# Examples
Setup used in all examples below — FCC primitive, one binary substitution site:
```jldoctest enumerate_examples
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);
```

**Unrestricted enumeration** (no concentration): all 19 symmetry-inequivalent binary FCC structures at supercell volume 4.
```jldoctest enumerate_examples
julia> e = enumerate(p, sites; supercells = VolumeRange(4:4));

julia> length(e)
19

julia> to_labeling(e[1])
4-element Vector{Int8}:
 0
 1
 1
 1
```

**Fixed concentration** via `concentration_count`: the canonical HF 2012 FCC binary 4:4 at n=8 → 94 structures.
```jldoctest enumerate_examples
julia> c = concentration_count([4, 4]; n_total = 8);

julia> e = enumerate(p, sites; supercells = VolumeRange(8:8), concentration = c);

julia> length(e)
94
```

**Concentration range** restricting the first species to 1..2 of 12 atoms — illustrates `ConcentrationRange`'s natural use (sparse / dilute regime). The two partitions `(1,11)` and `(2,10)` together yield 216 structures at n=12.
```jldoctest enumerate_examples
julia> cr = ConcentrationRange([(1//12, 2//12), (10//12, 11//12)]);

julia> e = enumerate(p, sites; supercells = VolumeRange(12:12), concentration = cr);

julia> length(e)
216
```

**Explicit algorithm** — `:recursive_stabilizer` (Morgan 2017) on the same fixed-concentration case as before. Returns the same 94 structures; the algorithm-equivalence guarantee.
```jldoctest enumerate_examples
julia> e = enumerate(p, sites; supercells = VolumeRange(8:8), concentration = c,
                     algorithm = :recursive_stabilizer);

julia> length(e)
94
```
"""
function Base.enumerate(parent::ParentLattice{D}, sites::Sites{D};
                        supercells::SupercellSelection,
                        concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                        algorithm::Symbol = :auto,
                        memory_budget::Int = default_memory_budget(),
                        on_overflow::Symbol = :error,
                        partition_threshold::Int = 100,
                        on_partition_overflow::Symbol = :error,
                        include_superperiodic::Bool = false,
                        skip_resource_check::Bool = false) where D

    # ---- Algorithm dispatch ----
    # Preserve the user's original kwargs so the resource-check call into
    # estimate_cost re-runs the same dispatch with the same lightweight
    # cost-path semantics (it has its own :auto branch that mirrors this
    # one; passing the synthesized values would force it to redo synthesis
    # and re-pay the per-partition count_inequivalent cost we want to skip).
    user_concentration = concentration
    user_algorithm = algorithm
    if algorithm == :auto
        if concentration === nothing
            # v0.3 default for unrestricted enumeration: run the tree over a
            # synthetic full-range `ConcentrationRange`. Bench Section 5
            # (2026-05-22) shows :recursive_stabilizer is ~2-3× faster than
            # :exhaustive across FCC binary/ternary and HCP, and uses ~half
            # the memory (no k^n bitmap). Regime C unrestricted is rejected
            # by validation regardless of algorithm — fall through to
            # :exhaustive so the user gets the existing error message.
            if ndset(parent) >= 2 && !_sites_are_uniform(sites)
                algorithm = :exhaustive
            else
                # Regime A/B: k is the number of distinct labels at the
                # (uniform) sites. Mirrors _validate_enumerate_inputs.
                k_syn = length(sites.list[1].allowed_labels)
                concentration = ConcentrationRange([(0//1, 1//1) for _ in 1:k_syn])
                algorithm = :recursive_stabilizer
                # Partition decomposition is an implementation detail of the
                # synthetic concentration; the user didn't ask for a
                # concentration constraint and shouldn't see partition_threshold
                # errors as a consequence.
                partition_threshold = typemax(Int)
            end
        elseif ndset(parent) >= 2 && !_sites_are_uniform(sites)
            # Regime C: default to :recursive_stabilizer (the tree scales by
            # the valid-colorings subspace, while :multinomial_restricted
            # allocates the *full* multinomial bitmap and lazily skips mask-
            # invalid slots — fine for dense masks, slow for sparse ones
            # like the Heusler / wurtzite / perovskite family where most
            # positions are inactive). Users opt into :multinomial_restricted
            # explicitly for dense-mask cases (e.g. zinc-blende-style "every
            # sublattice active with disjoint labels"). A heuristic that picks
            # automatically based on mask sparsity is queued for v0.3 polish.
            algorithm = :recursive_stabilizer
        else
            # Regime B (or single-lattice) with concentration. Pick
            # :multinomial vs :recursive_stabilizer by predicted bitmap.
            # Tree streams (no bitmap) so it's the right choice when the
            # multinomial bitmap would exceed memory_budget × 0.8.
            algorithm = _multinomial_bitmap_fits(parent, supercells, concentration,
                                                  memory_budget) ?
                        :multinomial : :recursive_stabilizer
        end
    end

    # Now `algorithm` is one of :exhaustive, :multinomial, :recursive_stabilizer,
    # :multinomial_restricted, :bdd, or something unknown.
    if algorithm == :bdd
        throw(ArgumentError(
            "algorithm = :bdd (Shinohara 2020 ZDD) is reserved for v0.3+."))
    elseif algorithm != :exhaustive && algorithm != :multinomial &&
           algorithm != :multinomial_restricted &&
           algorithm != :recursive_stabilizer
        throw(ArgumentError(
            "unknown algorithm `:$algorithm`. Supported: :exhaustive (no " *
            "concentration), :multinomial / :multinomial_restricted / " *
            ":recursive_stabilizer (with concentration), :auto (default)."))
    end

    # Regime-C dispatch: :multinomial (the bitmap without the site-mask filter)
    # would over-allocate and over-emit for heterogeneous sublattices. The user
    # must pick :multinomial_restricted or :recursive_stabilizer explicitly, or
    # use :auto.
    if algorithm == :multinomial && ndset(parent) >= 2 && !_sites_are_uniform(sites)
        throw(ArgumentError(
            "algorithm = :multinomial doesn't support per-site `allowed_labels` " *
            "(Regime C). Use `algorithm = :multinomial_restricted` (chunk 6.5a) " *
            "or `algorithm = :recursive_stabilizer` (chunk 6.5b)."))
    end

    # :multinomial_restricted is Regime-C-specific; for Regime A/B the bitmap
    # variant without the mask filter is the natural choice.
    if algorithm == :multinomial_restricted &&
       !(ndset(parent) >= 2 && !_sites_are_uniform(sites))
        throw(ArgumentError(
            "algorithm = :multinomial_restricted is designed for heterogeneous " *
            "sublattices (Regime C). For uniform sublattices use :multinomial " *
            "(or :auto)."))
    end

    # Validation: concentration-requiring algorithms.
    if (algorithm == :multinomial || algorithm == :multinomial_restricted ||
        algorithm == :recursive_stabilizer) && concentration === nothing
        throw(ArgumentError(
            "algorithm = :$algorithm requires a `concentration` kwarg. " *
            "For unrestricted enumeration use :exhaustive (or :auto with concentration=nothing)."))
    end

    k = _validate_enumerate_inputs(parent, sites, concentration)

    # ---- Label-equivalence-aware effective parent (chunk 6.5c) ----
    # Sub-set parent.space_group / dset_perms / dset_shifts to ops whose
    # action respects the Sites' per-position allowed_labels classes. Regime
    # A/B short-circuits to the original `parent` object (byte-identical
    # behavior); Regime C may return a freshly-built filtered ParentLattice.
    # The user's original `parent` is never mutated.
    parent_eff = _effective_parent(parent, sites)

    # ---- Enumeration resource check (chunk 7.5) ----
    if !skip_resource_check
        estimate = estimate_cost(parent_eff, sites; supercells,
                                 concentration = user_concentration,
                                 algorithm = user_algorithm,
                                 include_superperiodic)
        if estimate.peak_memory_bytes > memory_budget
            if on_overflow === :error
                throw(EnumerationTooLargeError(estimate, memory_budget))
            elseif on_overflow === :warn
                @warn "Predicted peak memory exceeds memory_budget" estimate memory_budget
            end
            # :ignore falls through.
        end
    end

    # ---- Resolve supercells (with degeneracies for Supercell.hnf_degeneracy) ----
    hnfs_with_degens = _enumerate_hnfs_with_degeneracies(supercells, parent_eff)
    isempty(hnfs_with_degens) && return Enumeration{D, Vector{Int8}}(
        parent, sites, Supercell{D}[], EnumeratedStructure{D, Vector{Int8}}[])

    # ---- Algorithm bodies ----
    # Pass `parent_eff` for Supercell construction (it consults `dset_perms` /
    # `dset_shifts` via `getPermG`), but the returned `Enumeration` stores the
    # user's original `parent` — that's the object they handed us.
    if algorithm == :exhaustive
        return _enumerate_exhaustive(parent_eff, sites, hnfs_with_degens, k;
                                     include_superperiodic, user_parent = parent)
    elseif algorithm == :multinomial
        return _enumerate_multinomial(parent_eff, sites, hnfs_with_degens, k, concentration,
                                      partition_threshold, on_partition_overflow;
                                      include_superperiodic, user_parent = parent)
    elseif algorithm == :multinomial_restricted
        return _enumerate_multinomial_restricted(parent_eff, sites, hnfs_with_degens, k, concentration,
                                                  partition_threshold, on_partition_overflow;
                                                  include_superperiodic, user_parent = parent)
    else  # :recursive_stabilizer
        return _enumerate_recursive_stabilizer(parent_eff, sites, hnfs_with_degens, k, concentration,
                                                partition_threshold, on_partition_overflow;
                                                include_superperiodic, user_parent = parent)
    end
end

# ------------------------------------------------------------------------------
# Orbit size of a labeling under a permutation group, via the orbit-stabilizer
# theorem: |orbit| = |G| / |Stab|. Stabilizer membership: σ ∈ Stab(c) iff
# applying σ to c leaves c unchanged. Computed once per surviving canonical
# labeling at enumerate time; stored on EnumeratedStructure for downstream
# consumers (R33, 2026-05-14).
# ------------------------------------------------------------------------------
function _orbit_size(perm_group::AbstractVector, coloring::AbstractVector)
    stab_count = count(perm_group) do σ
        all(coloring[σ[i]] == coloring[i] for i in eachindex(coloring))
    end
    return length(perm_group) ÷ stab_count
end

# Super-periodicity check: a coloring is super-periodic iff some non-identity
# *pure translation* fixes it. By the `getPermG` convention, `perm_group[1..n_cells]`
# is identity-rotation × the supercell's translation subgroup (identity sorts first),
# so we walk that prefix. Used as the single post-filter for both :multinomial and
# :recursive_stabilizer — chunk 6.5b moved the per-algorithm checks here so n_cells
# (the multilattice-correct translation count) is in scope at call time.
function _is_super_periodic(coloring::AbstractVector, perm_group::AbstractVector,
                            n_cells::Int)
    for ig in 2:min(n_cells, length(perm_group))
        if coloring[perm_group[ig]] == coloring
            return true
        end
    end
    return false
end

# ------------------------------------------------------------------------------
# :exhaustive algorithm body — chunk 5's logic, factored out.
# ------------------------------------------------------------------------------

function _enumerate_exhaustive(parent::ParentLattice{D}, sites::Sites{D},
                               hnfs_with_degens::AbstractVector{Tuple{HNF{D}, Int}}, k::Int;
                               include_superperiodic::Bool = false,
                               user_parent::ParentLattice{D} = parent) where D
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]
    for (hnf, hnf_deg) in hnfs_with_degens
        sc = Supercell(hnf, parent; hnf_degeneracy = hnf_deg)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)
        # n_translations = n_cells (NOT n_D · n_cells) — super-periodicity is
        # detected by fix-by-pure-translation, and pG[1..n_cells] is the
        # identity-rotation × translation-subgroup block in the dset-blocks layout.
        n_cells = volume(hnf)
        colorings = getUniqueColorings(k, sc.permutation_group;
                                       include_superperiodic,
                                       n_translations = n_cells)
        for c in colorings
            osz = _orbit_size(sc.permutation_group, c)
            push!(structures, EnumeratedStructure{D, Vector{Int8}}(
                sc_id, Int8.(c), osz))
        end
    end
    return Enumeration{D, Vector{Int8}}(user_parent, sites, supercells_list, structures)
end

# ------------------------------------------------------------------------------
# :multinomial algorithm body — chunk 6's HF 2012 hash + crossing-out.
# ------------------------------------------------------------------------------

function _enumerate_multinomial(parent::ParentLattice{D}, sites::Sites{D},
                                hnfs_with_degens::AbstractVector{Tuple{HNF{D}, Int}},
                                k::Int,
                                concentration::Union{Concentration, ConcentrationRange},
                                partition_threshold::Int,
                                on_partition_overflow::Symbol;
                                include_superperiodic::Bool = false,
                                user_parent::ParentLattice{D} = parent) where D
    return _enumerate_per_concentration(parent, sites, hnfs_with_degens, k, concentration,
        partition_threshold, on_partition_overflow, include_superperiodic,
        # site_mask is ignored: :multinomial doesn't yet support per-site
        # restrictions (queued for chunk 6.5a). The Regime-C dispatch in
        # `enumerate(...)` won't route here when site_mask is non-trivial.
        (perm_group, mults, _site_mask) -> getUniqueColorings_multinomial(perm_group, mults);
        user_parent)
end

# ------------------------------------------------------------------------------
# :multinomial_restricted algorithm body — chunk 6.5a's bitmap + site mask.
# Same shared per-concentration sweep as :multinomial; the coloring_fn forwards
# the site_mask (which is `nothing` only in Regime A/B, but the Regime-C
# dispatch in `enumerate(...)` is what routes here in the first place).
# ------------------------------------------------------------------------------

function _enumerate_multinomial_restricted(parent::ParentLattice{D}, sites::Sites{D},
                                            hnfs_with_degens::AbstractVector{Tuple{HNF{D}, Int}},
                                            k::Int,
                                            concentration::Union{Concentration, ConcentrationRange},
                                            partition_threshold::Int,
                                            on_partition_overflow::Symbol;
                                            include_superperiodic::Bool = false,
                                            user_parent::ParentLattice{D} = parent) where D
    return _enumerate_per_concentration(parent, sites, hnfs_with_degens, k, concentration,
        partition_threshold, on_partition_overflow, include_superperiodic,
        (perm_group, mults, site_mask) -> getUniqueColorings_multinomial_restricted(
            perm_group, mults, site_mask);
        user_parent)
end

# ------------------------------------------------------------------------------
# :recursive_stabilizer algorithm body — chunk 8's Morgan 2017 tree.
# ------------------------------------------------------------------------------

function _enumerate_recursive_stabilizer(parent::ParentLattice{D}, sites::Sites{D},
                                          hnfs_with_degens::AbstractVector{Tuple{HNF{D}, Int}},
                                          k::Int,
                                          concentration::Union{Concentration, ConcentrationRange},
                                          partition_threshold::Int,
                                          on_partition_overflow::Symbol;
                                          include_superperiodic::Bool = false,
                                          user_parent::ParentLattice{D} = parent) where D
    return _enumerate_per_concentration(parent, sites, hnfs_with_degens, k, concentration,
        partition_threshold, on_partition_overflow, include_superperiodic,
        (perm_group, mults, site_mask) -> getUniqueColorings_recursive_stabilizer(
            perm_group, mults; site_mask);
        user_parent)
end

# ------------------------------------------------------------------------------
# Site-mask helpers (chunk 6.5 — Regime C support).
#
# `_sites_are_uniform`: true iff every dset position carries the same
# `allowed_labels`. Single-site Regime A and uniform-multilattice Regime B are
# both "uniform" — no site_mask needed in those cases.
#
# `_build_site_mask`: construct the `BitMatrix(n_total, k)` mask for the given
# `Sites` and supercell. Position layout matches the dset-blocks convention
# used everywhere else: site index `(α-1)*n_cells + cell_idx` belongs to dset
# block `α`. `mask[i, c+1] = true` iff species `c` is allowed at dset block α.
# ------------------------------------------------------------------------------

_sites_are_uniform(sites::Sites) =
    all(s.allowed_labels == sites.list[1].allowed_labels for s in sites.list)

function _build_site_mask(sites::Sites, n_cells::Int, k::Int)
    n_D = length(sites.list)
    mask = falses(n_D * n_cells, k)
    for α in 1:n_D
        allowed = sites.list[α].allowed_labels
        offset = (α - 1) * n_cells
        for c in allowed
            (0 <= c < k) || continue          # outside the active-species range
            for cell in 1:n_cells
                mask[offset + cell, c + 1] = true
            end
        end
    end
    return mask
end

# Per-supercell safety net (chunk 6.5b). Filter a supercell perm group to
# those permutations that preserve the site_mask — i.e., σ ∈ filtered iff
# `mask[σ[i], :] == mask[i, :]` for all i.
#
# Chunk 6.5c moved the *actual* Regime-C fix one layer earlier (see
# `_effective_parent` below): drops label-violating ops from the parent space
# group *before* `getPermG`'s `unique!()` dedup, so they never reach this
# stage. With that fix the filter is idempotent on our corpus — it has no
# work to do. We keep it as a cheap safety net (defense-in-depth) against
# any future divergence between dset-class equivalence and site-mask
# preservation.
#
# Historically (chunk 6.5b alone) this was the only Regime-C filter, but it's
# *insufficient* for cases like wurtzite where the over-symmetric parent ops
# survive `getPermG`'s `unique!()` by merging into the same site-permutation
# as a legitimate op — the merged result passes the mask check and can't be
# distinguished. Chunk 6.5c fixes that at the source.
function _filter_perm_group_by_mask(perm_group::AbstractVector,
                                    site_mask::BitMatrix)
    return [σ for σ in perm_group
            if all(view(site_mask, σ[i], :) == view(site_mask, i, :)
                   for i in eachindex(σ))]
end

# ------------------------------------------------------------------------------
# Label-equivalence-aware effective parent (chunk 6.5c, 2026-05-19).
#
# `ParentLattice` builds its cached `space_group` by calling Spacey with
# uniform types (`ones(Int, length(ds))`) — correct for Regime A and Regime B,
# but over-symmetric for Regime C: it returns every isometry that preserves
# the position set, including ops that swap dset positions across
# `allowed_labels` classes. Those ops aren't symmetries of the labeled
# configuration; if they reach `getPermG`, its `unique!()` step can merge
# them with legitimate ops in a way that's no longer distinguishable
# post-hoc (the wurtzite mismatch in chunk 6.5b's initial commit).
#
# At `enumerate(...)` entry (and `count_inequivalent` / `estimate_cost`) we
# have `Sites` in scope, so we can sub-set the parent's space group to
# label-respecting ops only. `_effective_parent(parent, sites)` returns the
# original `parent` object unchanged when no ops would be dropped (Regime
# A/B fast path, byte-identical to the pre-6.5c behavior), or a fresh
# `ParentLattice{D}` built via the internal direct-fields constructor when
# filtering is needed.
# ------------------------------------------------------------------------------

# Class id per dset position: positions sharing `allowed_labels` get the same
# id, assigned in first-seen order. `length(sites.list) == ndset(parent)` is
# guaranteed by the validation gate that runs before this helper is called.
function _dset_equivalence_classes(sites::Sites)
    classes = Int[]
    seen = Dict{BitSet, Int}()
    next_id = 0
    for s in sites.list
        id = get(seen, s.allowed_labels, -1)
        if id == -1
            next_id += 1
            seen[s.allowed_labels] = next_id
            id = next_id
        end
        push!(classes, id)
    end
    return classes
end

# True iff the dset permutation π maps every position to one in the same
# equivalence class (so the op is a symmetry of the labeled configuration).
_dset_perm_preserves_classes(π::AbstractVector{<:Integer},
                             classes::AbstractVector{<:Integer}) =
    all(classes[π[i]] == classes[i] for i in eachindex(π))

function _effective_parent(parent::ParentLattice{D}, sites::Sites{D}) where D
    # Regime A: only one dset position; nothing to filter, every op trivially
    # class-preserving. Skip the work and return the parent verbatim — this
    # is byte-identical to pre-6.5c behavior, and downstream `===` checks
    # observe the no-op.
    ndset(parent) == 1 && return parent

    classes = _dset_equivalence_classes(sites)
    # Regime B: every dset position shares allowed_labels → one class → every
    # op trivially class-preserving. Same fast-path return.
    all(c == classes[1] for c in classes) && return parent

    # Regime C: filter. Walk parent.dset_perms, keep ops whose π preserves
    # classes; sub-set space_group / dset_perms / dset_shifts in parallel.
    keep_idx = [op_idx for (op_idx, π) in enumerate(parent.dset_perms)
                if _dset_perm_preserves_classes(π, classes)]
    # If the filter retained every op (e.g., the parent symmetry happens to
    # respect the labels with no help needed), short-circuit to the same
    # parent object — still byte-identical to pre-6.5c.
    length(keep_idx) == length(parent.space_group) && return parent

    return ParentLattice{D}(parent.A, parent.dset,
                            parent.space_group[keep_idx],
                            parent.dset_perms[keep_idx],
                            parent.dset_shifts[keep_idx])
end

# ------------------------------------------------------------------------------
# Shared HNF + per-concentration sweep used by :multinomial and
# :recursive_stabilizer. Caller passes a `coloring_fn(perm_group, mults, site_mask)`
# that returns Vector{Vector{Int8}} for a single (supercell, multiplicity vector).
# `site_mask` is `BitMatrix(n_total, k)` for Regime C, or `nothing` otherwise.
# ------------------------------------------------------------------------------

function _enumerate_per_concentration(parent::ParentLattice{D}, sites::Sites{D},
                                       hnfs_with_degens::AbstractVector{Tuple{HNF{D}, Int}},
                                       k::Int,
                                       concentration::Union{Concentration, ConcentrationRange},
                                       partition_threshold::Int,
                                       on_partition_overflow::Symbol,
                                       include_superperiodic::Bool,
                                       coloring_fn;
                                       user_parent::ParentLattice{D} = parent) where D
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]
    n_D = ndset(parent)

    # Site mask for Regime C — built once per (sites, n_total) since the
    # dset-block site layout determines which colors are allowed at which
    # positions. For uniform Regime A / Regime B sites, this returns nothing
    # (every position permits every color); the algorithms treat nothing as
    # "no restriction." See chunk6.5-design.md §3.2.
    site_mask_uniform = _sites_are_uniform(sites)

    for (hnf, hnf_deg) in hnfs_with_degens
        sc = Supercell(hnf, parent; hnf_degeneracy = hnf_deg)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)
        n = volume(hnf)
        n_total = n_D * n   # total supercell sites = n_D · n
        site_mask = site_mask_uniform ? nothing : _build_site_mask(sites, n, k)

        # Regime C: drop perms that swap dset positions with different
        # allowed_labels. The parent space group can map e.g. an A-site
        # position to a B-site position when those positions are related by
        # parent symmetry — fine for Regime B (uniform labels) but not a
        # symmetry of the labeled configuration in Regime C. Same filtered
        # group must be used downstream in `_orbit_size`.
        effective_perm_group = site_mask === nothing ? sc.permutation_group :
                               _filter_perm_group_by_mask(sc.permutation_group, site_mask)

        # Resolve the concentration(s) to enumerate at this supercell volume.
        # Multiplicities live on n_D · n sites; single-lattice falls out as the
        # degenerate case (n_total = n).
        concs = if concentration isa Concentration
            try
                multiplicities(concentration, n_total)  # validate divisibility
                Concentration[concentration]
            catch e
                e isa EmptyEnumerationError || rethrow()
                # Concentration doesn't divide cleanly; skip the volume.
                Concentration[]
            end
        else  # ConcentrationRange
            crs = concentrations_in_range(concentration, n_total)
            if length(crs) > partition_threshold
                if on_partition_overflow === :error
                    throw(PartitionExplosionError(length(crs), partition_threshold,
                        "supercell volume = $n; range = $(concentration.bounds)"))
                elseif on_partition_overflow === :warn
                    @warn "ConcentrationRange decomposes into $(length(crs)) " *
                          "multiplicity vectors at n=$n (threshold = $partition_threshold)" concentration
                end
                # :ignore falls through.
            end
            crs
        end

        for c in concs
            mults = multiplicities(c, n_total)
            colorings = coloring_fn(effective_perm_group, mults, site_mask)
            for coloring in colorings
                # Super-periodicity filter (chunk 6.5b refactor): drop colorings
                # fixed by a non-identity pure translation. `effective_perm_group[1..n]`
                # is identity-rotation × the supercell's n_cells = n translations
                # (per getPermG's sorted construction). Single source of truth for
                # both :multinomial and :recursive_stabilizer.
                if !include_superperiodic && _is_super_periodic(coloring, effective_perm_group, n)
                    continue
                end
                osz = _orbit_size(effective_perm_group, coloring)
                push!(structures, EnumeratedStructure{D, Vector{Int8}}(
                    sc_id, coloring, osz))
            end
        end
    end

    return Enumeration{D, Vector{Int8}}(user_parent, sites, supercells_list, structures)
end

"""
    default_memory_budget()

The default `memory_budget` for `enumerate(...)` — adapts to the host machine. 25% of the system's physical memory, with a 2 GiB floor.

**Caveat:** `Sys.total_memory()` reports the *machine's* RAM, not the cgroup / Slurm / Kubernetes allocation in containerized environments. HPC users on a shared cluster need to pass `memory_budget = \$SLURM_MEM_PER_NODE` (or similar) explicitly.
"""
default_memory_budget() = max(2 * 2^30, Int(Sys.total_memory() ÷ 4))

# ------------------------------------------------------------------------------
# Shared input-validation helper used by both enumerate(...) and count_inequivalent(...).
# Chunk 5/6 single-lattice / single-site / dense-zero-indexed gates plus
# concentration-consistency-with-k. Returns `k` (the species count).
# ------------------------------------------------------------------------------

function _validate_enumerate_inputs(parent::ParentLattice{D}, sites::Sites{D},
                                    concentration) where D
    # ---- Regime discrimination (R50.1) ----
    # Distinguishes the four cases the user can hit:
    #   • Regime A          — single-site parent + single-site Sites → falls through.
    #   • A-confused        — single-site parent + multi-site Sites  → setup error.
    #   • dset/Sites mismatch — multilattice parent + Sites length ≠ ndset → setup error.
    #   • Regime B          — multilattice parent + uniform Sites    → HF 2009 (R50.2 pending).
    #   • Regime C          — multilattice parent + heterogeneous Sites → chunk 6.5.
    nd  = ndset(parent)
    nsl = length(sites.list)

    if nd == 1
        if nsl != 1
            throw(ArgumentError(
                "Sites of length $nsl on a single-site parent — only one site " *
                "is allowed when ndset(parent) = 1."))
        end
        # Regime A: falls through to the rest of validation below.
    else  # nd >= 2 (multilattice parent)
        if nsl != nd
            throw(ArgumentError(
                "ndset(parent) = $nd but Sites has $nsl entries; one site per " *
                "dset position is required. Consider `Sites(parent, [0, 1])` " *
                "(R51 convenience constructor)."))
        end
        # Regime B vs C: check whether all sites carry the same allowed_labels.
        # Both are admitted post-R50.2b (Regime B) and chunk 6.5b (Regime C).
        # The downstream validation differs: for Regime B the species count
        # comes from sites.list[1]; for Regime C it's the union across all
        # dset positions. Sub-cascade below.
    end

    if !(ndset(parent) >= 2 && !_sites_are_uniform(sites))
        # Regime A or Regime B — uniform sites; sites.list[1] is representative.
        site = sites.list[1]
        is_active(site) || throw(ArgumentError(
            "the only site is inactive (`length(allowed_labels) == 1`); nothing to enumerate."))

        allowed = sort(collect(site.allowed_labels))
        k = length(allowed)
        if allowed != collect(0:k-1)
            throw(ArgumentError(
                "zero-indexed dense allowed_labels required (`{0, 1, ..., k-1}`). " *
                "Got `$(site.allowed_labels)`. Sparse / non-zero-indexed labels — chunk 6.5."))
        end
    else
        # Regime C — heterogeneous sublattices (chunk 6.5b). Species count is
        # the union of all dset positions' allowed_labels. Reject if any
        # position uses labels outside `0..k-1` (dense, zero-indexed) or if no
        # position is active.
        union_labels = reduce(union, (s.allowed_labels for s in sites.list))
        any(is_active, sites.list) || throw(ArgumentError(
            "every dset position is inactive; nothing to enumerate."))
        allowed = sort(collect(union_labels))
        k = length(allowed)
        if allowed != collect(0:k-1)
            throw(ArgumentError(
                "Regime C requires the union of per-site allowed_labels to be " *
                "dense zero-indexed (`{0, 1, ..., k-1}`). Got `$union_labels`. " *
                "Renumber the species so every label in 0..k-1 appears on at " *
                "least one dset position."))
        end
        # Regime C requires a concentration to be supplied (the algorithms that
        # handle per-site restrictions all need fixed multiplicities).
        if concentration === nothing
            throw(ArgumentError(
                "Multilattice with per-site `allowed_labels` (Regime C — " *
                "heterogeneous sublattices) requires a `concentration` kwarg. " *
                "Unrestricted enumeration on heterogeneous sublattices isn't " *
                "supported; pass a `Concentration` or `ConcentrationRange`."))
        end
    end

    if concentration isa Concentration
        n_species(concentration) == k ||
            throw(ArgumentError(
                "concentration has $(n_species(concentration)) species but " *
                "allowed_labels has k=$k species."))
    elseif concentration isa ConcentrationRange
        n_species(concentration) == k ||
            throw(ArgumentError(
                "concentration range has $(n_species(concentration)) species but " *
                "allowed_labels has k=$k species."))
    end

    return k
end

# ------------------------------------------------------------------------------
# count_inequivalent — chunk 7 public top-level, Pólya / Burnside counting.
# ------------------------------------------------------------------------------

"""
    count_inequivalent(parent::ParentLattice{D}, sites::Sites{D};
                       supercells::SupercellSelection,
                       concentration = nothing,
                       include_superperiodic::Bool = false,
                       breakdown::Bool = false) -> BigInt or InequivalentCount{D}

Count symmetry-inequivalent derivative structures *without enumerating them*. Pólya / Burnside-averaged orbit count.

- `include_superperiodic = false` (default): primitive (aperiodic) count via Möbius inversion. Matches `length(enumerate(parent, sites; ..., include_superperiodic = false))`.
- `include_superperiodic = true`: full Burnside orbit count, super-periodic included. Matches `length(enumerate(parent, sites; ..., include_superperiodic = true))`.
- `breakdown = false` (default) returns the `BigInt` total.
- `breakdown = true` returns `InequivalentCount{D}` with per-volume / per-concentration / per-HNF breakdowns.

Heterogeneous `Sites` (per-site `allowed_labels` — zinc-blende, half/full-Heusler, perovskite, or any site pinned to one species) are counted with the label-restricted Pólya formulas, which intersect `allowed_labels` across each orbit. Uniform `Sites` keep the scalar-`k` fast path.

An **unconstrained** `ConcentrationRange` (every species free over `[0, 1]`, as `read_struct_enum_in` synthesizes for `full` mode) is treated as no concentration constraint at all — exact, since every coloring has one concentration, and far cheaper than iterating every composition. Consequence: in that case the returned `by_concentration` is empty, because materializing it would mean enumerating every composition of the site count. Pass a narrower `ConcentrationRange` if you need that breakdown.

Cost: O(|G| · n) per supercell for the unrestricted case; with Möbius correction add subgroup-enumeration of `T` (cheap at typical supercell sizes). Sub-second across the full reference corpus.

See `research.md` §5.2.1 for the super-periodicity policy and `research.md` §4.6 / §7.2 for the underlying Pólya machinery.

# Examples
Setup — FCC binary, one substitution site:
```jldoctest count_examples
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);
```

**Basic count** — the canonical FCC binary n=12 unrestricted total:
```jldoctest count_examples
julia> count_inequivalent(p, sites; supercells = VolumeRange(12:12))
7140
```

**Include super-periodics** — adds the 745 super-periodic orbits that the default policy drops (HF 2008 step 5d). Matches `length(enumerate(...; include_superperiodic = true))`.
```jldoctest count_examples
julia> count_inequivalent(p, sites; supercells = VolumeRange(12:12), include_superperiodic = true)
7885
```

**Breakdown over a volume range** — `breakdown = true` returns an [`InequivalentCount`](@ref); `by_volume` is a sorted `Vector{Tuple{Int, BigInt}}` so indexing is deterministic.
```jldoctest count_examples
julia> ic = count_inequivalent(p, sites; supercells = VolumeRange(8:12), breakdown = true);

julia> ic.total
10609

julia> ic.by_volume[1]   # smallest volume in the range
(8, 390)

julia> ic.by_volume[end] # largest
(12, 7140)
```
"""
function count_inequivalent(parent::ParentLattice{D}, sites::Sites{D};
                            supercells::SupercellSelection,
                            concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                            include_superperiodic::Bool = false,
                            breakdown::Bool = false) where D
    k = _validate_enumerate_inputs(parent, sites, concentration)
    # Chunk 6.5c: label-equivalence-aware effective parent. No-op for Regime
    # A/B (returns the user's parent verbatim); filters for Regime C.
    parent_eff = _effective_parent(parent, sites)
    n_D = ndset(parent_eff)

    # Heterogeneous `Sites` need the label-restricted Pólya counts: the scalar-`k`
    # formulas assume every position may take any of the k labels, which overcounts
    # zinc-blende / Heusler / perovskite-style inputs by orders of magnitude. Only
    # take the restricted path when it is actually needed, so the uniform corpus
    # keeps its existing (fast, reference-locked) behavior.
    full_labels = BitSet(0:(k - 1))
    uniform_labels = all(s -> s.allowed_labels == full_labels, sites.list)

    # An unconstrained ConcentrationRange — every species free over [0, 1], which
    # is what `read_struct_enum_in` synthesizes for `full` mode — imposes nothing,
    # so a single Burnside evaluation is exact: every coloring has exactly one
    # concentration, hence the unrestricted count equals the sum over all in-range
    # concentrations. The per-partition path instead runs the dense DP once per
    # composition of n_total into k parts: 92 s for perovskite n = 3, and still
    # unfinished after 80 min at n = 4. This is the same shortcut `estimate_cost`
    # already takes for its own synthesized range.
    unconstrained_range = concentration isa ConcentrationRange &&
                          all(b -> b == (0 // 1, 1 // 1), concentration.bounds)
    concentration_eff = unconstrained_range ? nothing : concentration

    hnfs_with_degens = _enumerate_hnfs_with_degeneracies(supercells, parent_eff)

    total = BigInt(0)
    by_volume_dict = Dict{Int, BigInt}()
    by_concentration_dict = Dict{Concentration, BigInt}()
    by_hnf = Tuple{HNF{D}, BigInt}[]

    for (hnf, hnf_deg) in hnfs_with_degens
        sc = Supercell(hnf, parent_eff; hnf_degeneracy = hnf_deg)
        n = volume(hnf)
        n_total = n_D * n                # total sites = n_D · n
        snf_diag = (Int(sc.snf[1]), Int(sc.snf[2]), Int(sc.snf[3]))

        # Per-position allowed labels, in the permutation domain's own layout:
        # dset site i owns positions (i-1)·n+1 … i·n (see Polya._translation_perms,
        # which block-replicates translations with offsets (i-1)·n).
        allowed_pos = uniform_labels ? nothing :
            BitSet[sites.list[fld(p - 1, n) + 1].allowed_labels for p in 1:n_total]

        # Resolve concentration(s) to enumerate at this supercell volume.
        # Multiplicities are resolved against the total site count n_total =
        # n_D · n, not n — for multilattice (n_D ≥ 2) the colorings live on
        # n_D · n supercell sites. Single-lattice (n_D = 1) is the degenerate
        # case where n_total = n.
        concs_here = if concentration_eff === nothing
            Union{Concentration, Nothing}[nothing]
        elseif concentration_eff isa Concentration
            try
                multiplicities(concentration_eff, n_total)  # validates divisibility
                Union{Concentration, Nothing}[concentration_eff]
            catch e
                e isa EmptyEnumerationError || rethrow()
                Union{Concentration, Nothing}[]
            end
        else  # ConcentrationRange
            Union{Concentration, Nothing}[c for c in concentrations_in_range(concentration_eff, n_total)]
        end

        hnf_count = BigInt(0)
        for c in concs_here
            # Four combinations: {no concentration, fixed concentration} ×
            # {uniform labels → scalar k, restricted labels → allowed_pos}. The
            # concentration itself pins the alphabet in the uniform case, so the
            # scalar-k branch passes `mults` alone (its established signature).
            count_here = if c === nothing
                if allowed_pos === nothing
                    include_superperiodic ?
                        Polya.polya_count(sc.permutation_group, k) :
                        Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag, k)
                else
                    include_superperiodic ?
                        Polya.polya_count(sc.permutation_group, allowed_pos) :
                        Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag, allowed_pos)
                end
            else
                mults = multiplicities(c, n_total)
                if allowed_pos === nothing
                    include_superperiodic ?
                        Polya.polya_count(sc.permutation_group, mults) :
                        Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag, mults)
                else
                    include_superperiodic ?
                        Polya.polya_count(sc.permutation_group, allowed_pos, mults) :
                        Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag,
                                                    allowed_pos, mults)
                end
            end

            total += count_here
            hnf_count += count_here
            by_volume_dict[n] = get(by_volume_dict, n, BigInt(0)) + count_here
            if c isa Concentration && concentration isa ConcentrationRange
                by_concentration_dict[c] = get(by_concentration_dict, c, BigInt(0)) + count_here
            end
        end

        if breakdown
            push!(by_hnf, (hnf, hnf_count))
        end
    end

    breakdown || return total

    by_volume = sort([(n, c) for (n, c) in by_volume_dict]; by = first)
    by_concentration = sort([(c, ct) for (c, ct) in by_concentration_dict];
                            by = x -> x[1].fractions)
    return InequivalentCount{D}(total, by_volume, by_concentration, by_hnf)
end

# ------------------------------------------------------------------------------
# estimate_cost — chunk 7.5 public top-level. Returns EnumerationCostEstimate
# without enumerating. Internally consulted by enumerate(...)'s resource check.
# ------------------------------------------------------------------------------

"""
    estimate_cost(parent::ParentLattice{D}, sites::Sites{D};
                  supercells::SupercellSelection,
                  concentration = nothing,
                  algorithm::Symbol = :auto,
                  include_superperiodic::Bool = false) -> EnumerationCostEstimate

Predict the cost of `enumerate(...)` *before* running it. Useful as a manual size check (call it yourself to see what `enumerate` *would* allocate) and as the engine behind `enumerate(...)`'s built-in enumeration resource check (which calls it internally to decide whether to proceed).

Returns an [`EnumerationCostEstimate`](@ref) with the predicted structure count, peak-memory prediction, chosen algorithm, selection kind, partition count, and any advisory notes. See `research.md` §7.2.

Cost: same as `count_inequivalent(...)` — milliseconds even for hundreds of supercells. The Pólya count is the dominant term; per-algorithm memory is closed-form.

# Examples
Sizing a request before running it is the function's primary purpose. The example below shows the *gate firing*: an unrestricted FCC binary enumeration at volume 20 is predicted to need ~138 MiB, far beyond the artificially-tiny `memory_budget = 1` byte we pass in to trigger `EnumerationTooLargeError`.
```jldoctest; filter = r"\\d+\\.\\d+ MiB"
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> try
           enumerate(p, sites; supercells = VolumeRange(20:20), memory_budget = 1)
       catch e
           e isa EnumerationTooLargeError || rethrow()
           format_bytes(e.estimate.peak_memory_bytes)
       end
"137.56 MiB"
```
"""
function estimate_cost(parent::ParentLattice{D}, sites::Sites{D};
                       supercells::SupercellSelection,
                       concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                       algorithm::Symbol = :auto,
                       include_superperiodic::Bool = false) where D
    k = _validate_enumerate_inputs(parent, sites, concentration)
    # Chunk 6.5c: same label-equivalence-aware effective parent that
    # `enumerate(...)` uses. No-op for Regime A/B.
    parent_eff = _effective_parent(parent, sites)

    # Track whether :auto routed an unrestricted request through a synthetic
    # full-range ConcentrationRange (v0.3 default — see enumerate's :auto block).
    # Surfaced in `notes` so users reading the estimate know why partition_count
    # is > 1 for what they typed as "no concentration."
    synthesized_concentration = false

    # Resolve algorithm (same logic as enumerate's :auto dispatch).
    # Note: estimate_cost doesn't have memory_budget context, so :auto here
    # uses default_memory_budget() for the multinomial-vs-tree pivot.
    chosen = if algorithm == :auto
        if concentration === nothing
            # v0.3 default: tree over a synthetic full-range ConcentrationRange
            # for Regime A/B unrestricted. Regime C unrestricted falls through
            # to :exhaustive (validation in enumerate() will reject it).
            # Synthesize here too so peak-memory / total_count / partition_count
            # reflect the algorithm that will actually run.
            if ndset(parent) >= 2 && !_sites_are_uniform(sites)
                :exhaustive
            else
                k_syn = length(sites.list[1].allowed_labels)
                concentration = ConcentrationRange([(0//1, 1//1) for _ in 1:k_syn])
                synthesized_concentration = true
                :recursive_stabilizer
            end
        elseif ndset(parent) >= 2 && !_sites_are_uniform(sites)
            # Regime C: see the same-named branch in `enumerate(...)` for why
            # we default to the tree here rather than the bitmap.
            :recursive_stabilizer
        else
            _multinomial_bitmap_fits(parent_eff, supercells, concentration,
                                     default_memory_budget()) ?
                :multinomial : :recursive_stabilizer
        end
    else
        algorithm
    end

    # Reject algorithms that aren't implemented yet (matches enumerate's gate).
    if chosen == :bdd
        throw(ArgumentError("algorithm = :bdd is reserved for v0.3+."))
    elseif chosen != :exhaustive && chosen != :multinomial &&
           chosen != :multinomial_restricted &&
           chosen != :recursive_stabilizer
        throw(ArgumentError(
            "unknown algorithm `:$chosen`. Supported: :exhaustive, :multinomial, " *
            ":multinomial_restricted, :recursive_stabilizer, :auto."))
    end

    if (chosen == :multinomial || chosen == :multinomial_restricted ||
        chosen == :recursive_stabilizer) && concentration === nothing
        throw(ArgumentError(
            "algorithm = :$chosen requires a `concentration` kwarg."))
    end

    notes = String[]
    if algorithm == :auto
        if synthesized_concentration
            push!(notes, "Auto-dispatch chose :$chosen via a synthetic " *
                         "full-range ConcentrationRange (no user-supplied " *
                         "concentration; v0.3 default).")
        else
            push!(notes, "Auto-dispatch chose :$chosen " *
                         "(concentration $(concentration === nothing ? "nothing" : "supplied"))")
        end
    end

    # Resolve the HNF list (deferred work — same call enumerate makes).
    hnfs = enumerate_hnfs(supercells, parent_eff)
    n_D = ndset(parent_eff)

    # Total count via the chunk-7 machinery. When :auto synthesized a
    # full-range ConcentrationRange, we pass `nothing` to count_inequivalent
    # instead of iterating per-partition: the Pólya count for unrestricted
    # enumeration equals the sum across all in-range concentrations, but
    # the unrestricted call is a single Burnside evaluation while the
    # ConcentrationRange path iterates partitions. At small n the per-
    # partition iteration dominates the resource-check wall time
    # (measured 2026-05-23: 5.5 ms → ~0.5 ms for FCC binary n=4 unrestricted).
    count_concentration = synthesized_concentration ? nothing : concentration
    total_count = count_inequivalent(parent_eff, sites; supercells,
                                     concentration = count_concentration,
                                     include_superperiodic)

    # Peak memory. Pass `nothing` for the synthesized case too — the tree's
    # memory prediction doesn't consult `concentration` (line below in
    # `_predict_peak_memory` short-circuits to `bitmap_peak = 0`), so this
    # is purely an optimization, not a semantic change.
    peak_memory = _predict_peak_memory(hnfs, parent_eff, k, count_concentration, chosen, total_count)

    # Selection kind.
    selection_kind = supercells isa VolumeRange ? :volume_range :
                     supercells isa RadiusBound ? :radius_bound : :explicit_hnfs

    # Partition count (chunk 6 already exposes the partition machinery). For
    # multilattice (n_D ≥ 2), the multiplicity vectors are resolved against
    # n_D · volume(h) total sites, not volume(h). For :auto's synthetic
    # full-range case we report 1 — the user didn't ask for a concentration
    # so partition mechanics are an implementation detail.
    partition_count = if synthesized_concentration
        1
    elseif concentration isa ConcentrationRange
        sum(length(concentrations_in_range(concentration, n_D * volume(h))) for h in hnfs;
            init = 0)
    else
        1
    end

    return EnumerationCostEstimate(total_count, peak_memory, chosen,
                                   selection_kind, partition_count, notes)
end

# ------------------------------------------------------------------------------
# Memory prediction.
# ------------------------------------------------------------------------------

# Peak memory prediction for the given algorithm, in bytes.
#
# - Bitmap: BitVector(C) costs ceil(C / 8) bytes per HNF (or per (HNF, conc)
#   for :multinomial). The peak across the run is the max of these per-HNF
#   bitmaps.
# - Output: Vector{EnumeratedStructure{D, Vector{Int8}}} of length total_count.
#   Each EnumeratedStructure carries a Vector{Int8} labeling of length n
#   (worst-case at the largest HNF), plus a few Ints. We approximate with a
#   per-structure size of ~64 bytes plus the labeling vector.
#
# Total peak ≈ max_per_HNF_bitmap + final_output_size. (Upper bound: at
# end-of-run, output holds all structures and the last bitmap is still alive.)
function _predict_peak_memory(hnfs, parent, k::Int, concentration, algorithm::Symbol,
                              total_count::BigInt)::Int
    isempty(hnfs) && return 0

    n_D = ndset(parent)
    n_max = maximum(volume(h) for h in hnfs)
    # Labeling length = n_D · n; output_per_struct grows with total sites.
    output_per_struct = 64 + n_D * n_max * sizeof(Int8)
    output_total = clamp(Int(min(total_count, typemax(Int) ÷ max(1, output_per_struct))),
                         0, typemax(Int)) * output_per_struct

    bitmap_peak = 0
    if algorithm == :recursive_stabilizer
        # Tree streams — no bitmap. Conservative bound: depth × per-node state.
        # Per chunk-7.5 design Q6, intentionally upper-bound the per-level cost
        # at total_count × n × Int_overhead (roughly: every saved partial keeps
        # a location vector + a stabilizer subset). Won't be tight; safe for
        # the gate's "refuse if exceeds budget" decision.
        # The output term dominates anyway for typical use; bitmap_peak stays 0.
        bitmap_peak = 0
    else
        for hnf in hnfs
            n = volume(hnf)
            n_total = n_D * n
            if algorithm == :exhaustive
                # BitVector(k^(n_D·n)) bytes.
                C = BigInt(k)^n_total
                bitmap_peak = max(bitmap_peak, _bitmap_bytes(C))
            else  # :multinomial or :multinomial_restricted — same bitmap layout
                # Per (HNF, concentration) bitmap. Take max across concentrations
                # at this volume. :multinomial_restricted allocates the full
                # multinomial bitmap and skips invalid slots at iter time, so
                # the peak-memory prediction is identical.
                concs_here = if concentration isa Concentration
                    try
                        multiplicities(concentration, n_total)
                        [concentration]
                    catch e
                        e isa EmptyEnumerationError || rethrow()
                        Concentration[]
                    end
                elseif concentration isa ConcentrationRange
                    concentrations_in_range(concentration, n_total)
                else
                    Concentration[]   # shouldn't happen for bitmap algorithms
                end
                for c in concs_here
                    mults = multiplicities(c, n_total)
                    C = multinomial_count(mults)
                    bitmap_peak = max(bitmap_peak, _bitmap_bytes(C))
                end
            end
        end
    end

    return clamp(bitmap_peak + output_total, 0, typemax(Int))
end

# BitVector(C) costs ceil(C / 8) bytes (rounded up) plus a small Vector header.
# Clamp to typemax(Int) so absurd inputs don't overflow the field type.
function _bitmap_bytes(C::BigInt)::Int
    bytes = (C + BigInt(7)) ÷ BigInt(8)
    return Int(min(bytes, BigInt(typemax(Int))))
end

# :auto dispatch helper. Returns `true` if the worst-case multinomial bitmap
# across all (HNF, concentration) pairs in the request fits comfortably
# (≤ 80% of memory_budget). Used to pick :multinomial vs :recursive_stabilizer.
#
# We're conservative — return `false` if any single (HNF, concentration)
# bitmap would exceed the threshold. The tree never needs the bitmap.
function _multinomial_bitmap_fits(parent::ParentLattice{D},
                                   supercells::SupercellSelection,
                                   concentration::Union{Concentration, ConcentrationRange},
                                   memory_budget::Int) where D
    threshold = (memory_budget * 8) ÷ 10        # 80% of budget
    n_D = ndset(parent)

    hnfs = enumerate_hnfs(supercells, parent)
    isempty(hnfs) && return true                 # nothing to enumerate; either is fine

    for hnf in hnfs
        n_total = n_D * volume(hnf)
        concs_here = if concentration isa Concentration
            try
                multiplicities(concentration, n_total)
                [concentration]
            catch e
                e isa EmptyEnumerationError || rethrow()
                Concentration[]
            end
        else  # ConcentrationRange
            concentrations_in_range(concentration, n_total)
        end
        for c in concs_here
            mults = multiplicities(c, n_total)
            C = multinomial_count(mults)
            _bitmap_bytes(C) > threshold && return false
        end
    end
    return true
end
