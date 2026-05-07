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
              skip_preflight::Bool = false) -> Enumeration{D, Vector{Int8}}

Enumerate symmetry-inequivalent derivative structures of `parent` decorated by labelings drawn from `sites.allowed_labels`, over the supercells specified by `supercells`, optionally constrained to a fixed `concentration` or `ConcentrationRange`.

## Algorithm dispatch (chunk 6)

- `algorithm = :auto` (default): picks `:exhaustive` when `concentration === nothing`, `:multinomial` otherwise.
- `algorithm = :exhaustive` (Hart-Forcade 2008): unrestricted enumeration; ignores `concentration` if supplied.
- `algorithm = :multinomial` (Hart-Forcade 2012): fixed-concentration enumeration via the multinomial-hash crossing-out. Requires `concentration !== nothing`.
- `algorithm = :recursive_stabilizer` (Morgan 2017): tree-search-with-shrinking-stabilizers; same fixed-concentration scope as `:multinomial`, but streams (no bitmap) so it scales to high configurational freedom. `:auto` picks it when the multinomial bitmap would exceed `memory_budget × 0.8`.
- `algorithm = :multinomial_restricted` reserved for chunk 6.5.

## Concentration handling

- `concentration === nothing` → unrestricted (chunk 5 path).
- `concentration::Concentration` → single fixed concentration; the multinomial-hash algorithm enumerates the exactly-`a_i`-of-each-species labelings.
- `concentration::ConcentrationRange` → loops over `concentrations_in_range(cr, n)` for each supercell volume; gates against partition explosion via `partition_threshold` (default 100; chunk 6 review item 4).

## Pre-flight cost-estimator gate (chunk 6: partial)

Chunk 6 wires only the partition-explosion gate; the memory-budget gate is still a stub (chunk 7 lands the real estimator with the Polya counter). Reserved kwargs (`memory_budget`, `on_overflow`, `skip_preflight`) are accepted and largely ignored for now.

## Super-periodicity policy (chunk 6.2)

`include_superperiodic = false` (default) drops colorings whose true period strictly divides the supercell — these are duplicates of smaller-supercell derivatives across a volume sweep (HF 2008 step 5d). `include_superperiodic = true` keeps them and returns the full Burnside orbit space; useful for theoretical comparisons or single-volume queries where the user wants every orbit. See `research.md` §5.2.1.

## Returns

`Enumeration{D, Vector{Int8}}` containing the parent, sites, list of distinct supercells encountered, and the enumerated structures. Iterable + indexable.

## Constraints (still in place after chunk 6)

- Single-lattice parents only (`length(parent.dset) == 1`). Multilattice → "v0.3 feature."
- Single-site `Sites` only. Multi-site (perovskite-style site restrictions) → chunk 6.5.
- Zero-indexed dense `allowed_labels` (`{0, 1, ..., k-1}`). Sparse labels → chunk 6.5.
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
                        skip_preflight::Bool = false) where D

    # ---- Algorithm dispatch ----
    if algorithm == :auto
        if concentration === nothing
            algorithm = :exhaustive
        else
            # Pick :multinomial vs :recursive_stabilizer by predicted bitmap.
            # Tree streams (no bitmap) so it's the right choice when the
            # multinomial bitmap would exceed memory_budget × 0.8.
            algorithm = _multinomial_bitmap_fits(parent, supercells, concentration,
                                                  memory_budget) ?
                        :multinomial : :recursive_stabilizer
        end
    end

    # Now `algorithm` is one of :exhaustive, :multinomial, :recursive_stabilizer,
    # :multinomial_restricted, :bdd, or something unknown.
    if algorithm == :multinomial_restricted
        throw(ArgumentError(
            "algorithm = :multinomial_restricted (HF 2012 §A.1, site-restricted " *
            "backtracking) is reserved for chunk 6.5."))
    elseif algorithm == :bdd
        throw(ArgumentError(
            "algorithm = :bdd (Shinohara 2020 ZDD) is reserved for v0.3+."))
    elseif algorithm != :exhaustive && algorithm != :multinomial &&
           algorithm != :recursive_stabilizer
        throw(ArgumentError(
            "unknown algorithm `:$algorithm`. Supported: :exhaustive (no " *
            "concentration), :multinomial / :recursive_stabilizer (with concentration), " *
            ":auto (default)."))
    end

    # Validation: concentration-requiring algorithms.
    if (algorithm == :multinomial || algorithm == :recursive_stabilizer) &&
       concentration === nothing
        throw(ArgumentError(
            "algorithm = :$algorithm requires a `concentration` kwarg. " *
            "For unrestricted enumeration use :exhaustive (or :auto with concentration=nothing)."))
    end

    k = _validate_enumerate_inputs(parent, sites, concentration)

    # ---- Pre-flight cost gate (chunk 7.5) ----
    if !skip_preflight
        estimate = estimate_cost(parent, sites; supercells, concentration,
                                 algorithm, include_superperiodic)
        if estimate.peak_memory_bytes > memory_budget
            if on_overflow === :error
                throw(EnumerationTooLargeError(estimate, memory_budget))
            elseif on_overflow === :warn
                @warn "Predicted peak memory exceeds memory_budget" estimate memory_budget
            end
            # :ignore falls through.
        end
    end

    # ---- Resolve supercells ----
    hnfs = enumerate_hnfs(supercells, parent)
    isempty(hnfs) && return Enumeration{D, Vector{Int8}}(
        parent, sites, Supercell{D}[], EnumeratedStructure{D, Vector{Int8}}[])

    # ---- Algorithm bodies ----
    if algorithm == :exhaustive
        return _enumerate_exhaustive(parent, sites, hnfs, k; include_superperiodic)
    elseif algorithm == :multinomial
        return _enumerate_multinomial(parent, sites, hnfs, k, concentration,
                                      partition_threshold, on_partition_overflow;
                                      include_superperiodic)
    else  # :recursive_stabilizer
        return _enumerate_recursive_stabilizer(parent, sites, hnfs, k, concentration,
                                                partition_threshold, on_partition_overflow;
                                                include_superperiodic)
    end
end

# ------------------------------------------------------------------------------
# :exhaustive algorithm body — chunk 5's logic, factored out.
# ------------------------------------------------------------------------------

function _enumerate_exhaustive(parent::ParentLattice{D}, sites::Sites{D},
                               hnfs::AbstractVector{HNF{D}}, k::Int;
                               include_superperiodic::Bool = false) where D
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]
    for hnf in hnfs
        sc = Supercell(hnf, parent)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)
        colorings = getUniqueColorings(k, sc.permutation_group; include_superperiodic)
        for c in colorings
            push!(structures, EnumeratedStructure{D, Vector{Int8}}(
                sc_id, Int8.(c), 1, 1))
        end
    end
    return Enumeration{D, Vector{Int8}}(parent, sites, supercells_list, structures)
end

# ------------------------------------------------------------------------------
# :multinomial algorithm body — chunk 6's HF 2012 hash + crossing-out.
# ------------------------------------------------------------------------------

function _enumerate_multinomial(parent::ParentLattice{D}, sites::Sites{D},
                                hnfs::AbstractVector{HNF{D}}, k::Int,
                                concentration::Union{Concentration, ConcentrationRange},
                                partition_threshold::Int,
                                on_partition_overflow::Symbol;
                                include_superperiodic::Bool = false) where D
    return _enumerate_per_concentration(parent, sites, hnfs, k, concentration,
        partition_threshold, on_partition_overflow,
        (perm_group, mults) -> getUniqueColorings_multinomial(perm_group, mults;
                                                              include_superperiodic))
end

# ------------------------------------------------------------------------------
# :recursive_stabilizer algorithm body — chunk 8's Morgan 2017 tree.
# ------------------------------------------------------------------------------

function _enumerate_recursive_stabilizer(parent::ParentLattice{D}, sites::Sites{D},
                                          hnfs::AbstractVector{HNF{D}}, k::Int,
                                          concentration::Union{Concentration, ConcentrationRange},
                                          partition_threshold::Int,
                                          on_partition_overflow::Symbol;
                                          include_superperiodic::Bool = false) where D
    return _enumerate_per_concentration(parent, sites, hnfs, k, concentration,
        partition_threshold, on_partition_overflow,
        (perm_group, mults) -> getUniqueColorings_recursive_stabilizer(perm_group, mults;
                                                                       include_superperiodic))
end

# ------------------------------------------------------------------------------
# Shared HNF + per-concentration sweep used by :multinomial and
# :recursive_stabilizer. Caller passes a `coloring_fn(perm_group, mults)` that
# returns Vector{Vector{Int8}} for a single (supercell, multiplicity vector).
# ------------------------------------------------------------------------------

function _enumerate_per_concentration(parent::ParentLattice{D}, sites::Sites{D},
                                       hnfs::AbstractVector{HNF{D}}, k::Int,
                                       concentration::Union{Concentration, ConcentrationRange},
                                       partition_threshold::Int,
                                       on_partition_overflow::Symbol,
                                       coloring_fn) where D
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]

    for hnf in hnfs
        sc = Supercell(hnf, parent)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)
        n = volume(hnf)

        # Resolve the concentration(s) to enumerate at this supercell volume.
        concs = if concentration isa Concentration
            try
                multiplicities(concentration, n)  # validate divisibility
                Concentration[concentration]
            catch e
                e isa EmptyEnumerationError || rethrow()
                # Concentration doesn't divide cleanly into this n; skip the volume.
                Concentration[]
            end
        else  # ConcentrationRange
            crs = concentrations_in_range(concentration, n)
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
            mults = multiplicities(c, n)
            colorings = coloring_fn(sc.permutation_group, mults)
            for coloring in colorings
                push!(structures, EnumeratedStructure{D, Vector{Int8}}(
                    sc_id, coloring, 1, 1))
            end
        end
    end

    return Enumeration{D, Vector{Int8}}(parent, sites, supercells_list, structures)
end

"""
    default_memory_budget()

The default `memory_budget` for `enumerate(...)` — adapts to the host machine. 25% of the system's physical memory, with a 2 GiB floor. The pre-flight cost gate is still a stub through chunk 6; chunk 7 (Polya counter) makes it a real check.

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
    if ndset(parent) > 1
        throw(ArgumentError(
            "single-lattice parents only (`length(parent.dset) == 1`). Got dset of " *
            "length $(ndset(parent)). Multilattice support (HCP, perovskite, slab) " *
            "requires extending getPermG to handle n × n_D sites; deferred to v0.3."))
    end

    if length(sites.list) != 1
        throw(ArgumentError(
            "single-site Sites only. Got $(length(sites.list)) sites. " *
            "Multi-site Sites (per-site `allowed_labels`, perovskite-style site " *
            "restrictions) requires the multinomial-restricted algorithm; chunk 6.5."))
    end

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

Cost: O(|G| · n) per supercell for the unrestricted case; with Möbius correction add subgroup-enumeration of `T` (cheap for our v0.2 sizes). Sub-second across the chunk-6 corpus.

See `research.md` §5.2.1 for the super-periodicity policy and `research.md` §4.6 / §7.2 for the underlying Pólya machinery.
"""
function count_inequivalent(parent::ParentLattice{D}, sites::Sites{D};
                            supercells::SupercellSelection,
                            concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                            include_superperiodic::Bool = false,
                            breakdown::Bool = false) where D
    k = _validate_enumerate_inputs(parent, sites, concentration)

    hnfs = enumerate_hnfs(supercells, parent)

    total = BigInt(0)
    by_volume_dict = Dict{Int, BigInt}()
    by_concentration_dict = Dict{Concentration, BigInt}()
    by_hnf = Tuple{HNF{D}, BigInt}[]

    for hnf in hnfs
        sc = Supercell(hnf, parent)
        n = volume(hnf)
        snf_diag = (Int(sc.snf[1]), Int(sc.snf[2]), Int(sc.snf[3]))

        # Resolve concentration(s) to enumerate at this supercell volume.
        concs_here = if concentration === nothing
            Union{Concentration, Nothing}[nothing]
        elseif concentration isa Concentration
            try
                multiplicities(concentration, n)  # validates divisibility
                Union{Concentration, Nothing}[concentration]
            catch e
                e isa EmptyEnumerationError || rethrow()
                Union{Concentration, Nothing}[]
            end
        else  # ConcentrationRange
            Union{Concentration, Nothing}[c for c in concentrations_in_range(concentration, n)]
        end

        hnf_count = BigInt(0)
        for c in concs_here
            count_here = if c === nothing
                # Unrestricted (no concentration).
                if include_superperiodic
                    Polya.polya_count(sc.permutation_group, k)
                else
                    Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag, k)
                end
            else
                mults = multiplicities(c, n)
                if include_superperiodic
                    Polya.polya_count(sc.permutation_group, mults)
                else
                    Polya.aperiodic_orbit_count(sc.permutation_group, snf_diag, mults)
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
# without enumerating. Internally consulted by enumerate(...)'s pre-flight gate.
# ------------------------------------------------------------------------------

"""
    estimate_cost(parent::ParentLattice{D}, sites::Sites{D};
                  supercells::SupercellSelection,
                  concentration = nothing,
                  algorithm::Symbol = :auto,
                  include_superperiodic::Bool = false) -> EnumerationCostEstimate

Predict the cost of `enumerate(...)` *before* running it. Useful as a pre-flight check (sized by humans) and as the engine behind `enumerate(...)`'s memory-budget gate (sized by the gate).

Returns an [`EnumerationCostEstimate`](@ref) with the predicted structure count, peak-memory prediction, chosen algorithm, selection kind, partition count, and any advisory notes. See `research.md` §7.2.

Cost: same as `count_inequivalent(...)` — milliseconds even for hundreds of supercells. The Pólya count is the dominant term; per-algorithm memory is closed-form.
"""
function estimate_cost(parent::ParentLattice{D}, sites::Sites{D};
                       supercells::SupercellSelection,
                       concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                       algorithm::Symbol = :auto,
                       include_superperiodic::Bool = false) where D
    k = _validate_enumerate_inputs(parent, sites, concentration)

    # Resolve algorithm (same logic as enumerate's :auto dispatch).
    # Note: estimate_cost doesn't have memory_budget context, so :auto here
    # uses default_memory_budget() for the multinomial-vs-tree pivot.
    chosen = if algorithm == :auto
        if concentration === nothing
            :exhaustive
        else
            _multinomial_bitmap_fits(parent, supercells, concentration,
                                     default_memory_budget()) ?
                :multinomial : :recursive_stabilizer
        end
    else
        algorithm
    end

    # Reject algorithms that aren't implemented yet (matches enumerate's gate).
    if chosen == :multinomial_restricted
        throw(ArgumentError(
            "algorithm = :multinomial_restricted is reserved for chunk 6.5."))
    elseif chosen == :bdd
        throw(ArgumentError("algorithm = :bdd is reserved for v0.3+."))
    elseif chosen != :exhaustive && chosen != :multinomial &&
           chosen != :recursive_stabilizer
        throw(ArgumentError(
            "unknown algorithm `:$chosen`. Supported: :exhaustive, :multinomial, " *
            ":recursive_stabilizer, :auto."))
    end

    if (chosen == :multinomial || chosen == :recursive_stabilizer) && concentration === nothing
        throw(ArgumentError(
            "algorithm = :$chosen requires a `concentration` kwarg."))
    end

    notes = String[]
    if algorithm == :auto
        push!(notes, "Auto-dispatch chose :$chosen " *
                     "(concentration $(concentration === nothing ? "nothing" : "supplied"))")
    end

    # Resolve the HNF list (deferred work — same call enumerate makes).
    hnfs = enumerate_hnfs(supercells, parent)

    # Total count via the chunk-7 machinery.
    total_count = count_inequivalent(parent, sites; supercells, concentration,
                                     include_superperiodic)

    # Peak memory.
    peak_memory = _predict_peak_memory(hnfs, parent, k, concentration, chosen, total_count)

    # Selection kind.
    selection_kind = supercells isa VolumeRange ? :volume_range :
                     supercells isa RadiusBound ? :radius_bound : :explicit_hnfs

    # Partition count (chunk 6 already exposes the partition machinery).
    partition_count = if concentration isa ConcentrationRange
        sum(length(concentrations_in_range(concentration, volume(h))) for h in hnfs;
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

    n_max = maximum(volume(h) for h in hnfs)
    output_per_struct = 64 + n_max * sizeof(Int8)   # struct overhead + labeling
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
            if algorithm == :exhaustive
                # BitVector(k^n) bytes.
                C = BigInt(k)^n
                bitmap_peak = max(bitmap_peak, _bitmap_bytes(C))
            else  # :multinomial
                # Per (HNF, concentration) bitmap. Take max across concentrations
                # at this volume.
                concs_here = if concentration isa Concentration
                    try
                        multiplicities(concentration, n)
                        [concentration]
                    catch e
                        e isa EmptyEnumerationError || rethrow()
                        Concentration[]
                    end
                elseif concentration isa ConcentrationRange
                    concentrations_in_range(concentration, n)
                else
                    Concentration[]   # shouldn't happen for :multinomial, but safe
                end
                for c in concs_here
                    mults = multiplicities(c, n)
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

    hnfs = enumerate_hnfs(supercells, parent)
    isempty(hnfs) && return true                 # nothing to enumerate; either is fine

    for hnf in hnfs
        n = volume(hnf)
        concs_here = if concentration isa Concentration
            try
                multiplicities(concentration, n)
                [concentration]
            catch e
                e isa EmptyEnumerationError || rethrow()
                Concentration[]
            end
        else  # ConcentrationRange
            concentrations_in_range(concentration, n)
        end
        for c in concs_here
            mults = multiplicities(c, n)
            C = multinomial_count(mults)
            _bitmap_bytes(C) > threshold && return false
        end
    end
    return true
end
