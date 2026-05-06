"""
    enumerate(parent::ParentLattice{D}, sites::Sites{D};
              supercells::SupercellSelection,
              concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
              algorithm::Symbol = :auto,
              memory_budget::Int = default_memory_budget(),
              on_overflow::Symbol = :error,
              partition_threshold::Int = 100,
              on_partition_overflow::Symbol = :error,
              skip_preflight::Bool = false) -> Enumeration{D, Vector{Int8}}

Enumerate symmetry-inequivalent derivative structures of `parent` decorated by labelings drawn from `sites.allowed_labels`, over the supercells specified by `supercells`, optionally constrained to a fixed `concentration` or `ConcentrationRange`.

## Algorithm dispatch (chunk 6)

- `algorithm = :auto` (default): picks `:exhaustive` when `concentration === nothing`, `:multinomial` otherwise.
- `algorithm = :exhaustive` (Hart-Forcade 2008): unrestricted enumeration; ignores `concentration` if supplied.
- `algorithm = :multinomial` (Hart-Forcade 2012): fixed-concentration enumeration via the multinomial-hash crossing-out. Requires `concentration !== nothing`.
- `algorithm = :multinomial_restricted` and `:recursive_stabilizer` reserved for chunk 6.5+ and chunk 8 respectively.

## Concentration handling

- `concentration === nothing` → unrestricted (chunk 5 path).
- `concentration::Concentration` → single fixed concentration; the multinomial-hash algorithm enumerates the exactly-`a_i`-of-each-species labelings.
- `concentration::ConcentrationRange` → loops over `concentrations_in_range(cr, n)` for each supercell volume; gates against partition explosion via `partition_threshold` (default 100; chunk 6 review item 4).

## Pre-flight cost-estimator gate (chunk 6: partial)

Chunk 6 wires only the partition-explosion gate; the memory-budget gate is still a stub (chunk 7 lands the real estimator with the Polya counter). Reserved kwargs (`memory_budget`, `on_overflow`, `skip_preflight`) are accepted and largely ignored for now.

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
                        skip_preflight::Bool = false) where D

    # ---- Algorithm dispatch ----
    if algorithm == :auto
        algorithm = concentration === nothing ? :exhaustive : :multinomial
    end

    # Now `algorithm` is one of :exhaustive, :multinomial, :multinomial_restricted,
    # :recursive_stabilizer, :bdd, or something unknown.
    if algorithm == :multinomial_restricted
        throw(ArgumentError(
            "algorithm = :multinomial_restricted (HF 2012 §A.1, site-restricted " *
            "backtracking) is reserved for chunk 6.5."))
    elseif algorithm == :recursive_stabilizer
        throw(ArgumentError(
            "algorithm = :recursive_stabilizer (Morgan 2017 tree) is reserved for chunk 8."))
    elseif algorithm == :bdd
        throw(ArgumentError(
            "algorithm = :bdd (Shinohara 2020 ZDD) is reserved for v0.3+."))
    elseif algorithm != :exhaustive && algorithm != :multinomial
        throw(ArgumentError(
            "unknown algorithm `:$algorithm`. Supported: :exhaustive (no " *
            "concentration), :multinomial (with concentration), :auto (default)."))
    end

    # Validation: :multinomial requires a concentration.
    if algorithm == :multinomial && concentration === nothing
        throw(ArgumentError(
            "algorithm = :multinomial requires a `concentration` kwarg. " *
            "For unrestricted enumeration use :exhaustive (or :auto with concentration=nothing)."))
    end

    # ---- Multilattice gate (chunk 5 single-lattice only) ----
    if ndset(parent) > 1
        throw(ArgumentError(
            "single-lattice parents only (`length(parent.dset) == 1`). Got dset of " *
            "length $(ndset(parent)). Multilattice support (HCP, perovskite, slab) " *
            "requires extending getPermG to handle n × n_D sites; deferred to v0.3."))
    end

    # ---- Sites validation: single-site only (chunk 5) ----
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

    # Validate concentration consistency with k.
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

    # ---- Resolve supercells ----
    hnfs = enumerate_hnfs(supercells, parent)
    isempty(hnfs) && return Enumeration{D, Vector{Int8}}(
        parent, sites, Supercell{D}[], EnumeratedStructure{D, Vector{Int8}}[])

    # ---- Algorithm bodies ----
    if algorithm == :exhaustive
        return _enumerate_exhaustive(parent, sites, hnfs, k)
    else  # :multinomial
        return _enumerate_multinomial(parent, sites, hnfs, k, concentration,
                                      partition_threshold, on_partition_overflow)
    end
end

# ------------------------------------------------------------------------------
# :exhaustive algorithm body — chunk 5's logic, factored out.
# ------------------------------------------------------------------------------

function _enumerate_exhaustive(parent::ParentLattice{D}, sites::Sites{D},
                               hnfs::AbstractVector{HNF{D}}, k::Int) where D
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]
    for hnf in hnfs
        sc = Supercell(hnf, parent)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)
        colorings = getUniqueColorings(k, sc.permutation_group)
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
                                on_partition_overflow::Symbol) where D
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
            # Partition-explosion gate (Phase 7 §7.6, chunk-6-review-locked threshold = 100).
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

        # Enumerate per concentration.
        for c in concs
            mults = multiplicities(c, n)
            colorings = getUniqueColorings_multinomial(sc.permutation_group, mults)
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
