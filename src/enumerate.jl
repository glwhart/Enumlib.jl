"""
    enumerate(parent::ParentLattice{D}, sites::Sites{D};
              supercells::SupercellSelection,
              algorithm::Symbol = :exhaustive,
              memory_budget::Int = default_memory_budget(),
              on_overflow::Symbol = :error,
              skip_preflight::Bool = false) -> Enumeration{D, Vector{Int8}}

Enumerate all symmetry-inequivalent derivative structures of `parent` decorated by labelings drawn from `sites.allowed_labels`, over the supercells specified by `supercells`.

This is the v0.2-alpha entry point — first working `enumerate(...)` call against the new public API.

## Chunk 5 (v0.2-alpha) supports

- `algorithm = :exhaustive` (the only supported value): the Hart-Forcade 2008 algorithm. Wraps the legacy `getUniqueColorings` in the new types.
- Single-lattice parents (`length(parent.dset) == 1`). Multilattice (HCP, perovskite, slab) errors with a "v0.3 feature" message.
- Single-site `Sites` (one `Site` matching the parent's single dset position). Multi-site `Sites` (perovskite-style with mixed `allowed_labels` per site) errors with a "chunk 6+ site restriction" message.
- Zero-indexed dense allowed_labels (`{0, 1, ..., k-1}`). Sparse / non-zero-indexed labels (`{3, 5, 7}`) error with a "chunk 6+" message.

## Reserved kwargs (chunk 5: stub behavior)

- `memory_budget`, `on_overflow`, `skip_preflight` — Phase 7 designed the pre-flight cost gate. Chunk 7 (Polya counter) implements the real estimator. Chunk 5's gate is a stub that always passes.

## Returns

`Enumeration{D, Vector{Int8}}` containing the parent, sites, list of distinct supercells encountered, and the enumerated structures themselves. Iterable + indexable.
"""
function Base.enumerate(parent::ParentLattice{D}, sites::Sites{D};
                        supercells::SupercellSelection,
                        algorithm::Symbol = :exhaustive,
                        memory_budget::Int = default_memory_budget(),
                        on_overflow::Symbol = :error,
                        skip_preflight::Bool = false) where D

    # Algorithm validation — chunk 5 only knows :exhaustive.
    if algorithm == :multinomial || algorithm == :multinomial_restricted
        throw(ArgumentError(
            "algorithm = :$algorithm requires the multinomial (Hart-Forcade " *
            "2012) algorithm, which lands in chunk 6. Use :exhaustive for now."))
    elseif algorithm == :recursive_stabilizer
        throw(ArgumentError(
            "algorithm = :recursive_stabilizer requires the Morgan 2017 " *
            "recursive-stabilizer tree algorithm, which lands in chunk 8."))
    elseif algorithm == :auto
        # :auto would dispatch among the algorithms based on inputs; for chunk 5
        # there's only one algorithm, so :auto and :exhaustive are equivalent.
        algorithm = :exhaustive
    elseif algorithm != :exhaustive
        throw(ArgumentError(
            "unknown algorithm `:$algorithm`. Supported in chunk 5: :exhaustive " *
            "(default). Reserved for future chunks: :multinomial, " *
            ":multinomial_restricted, :recursive_stabilizer, :bdd."))
    end

    # Multilattice gate — chunk 5 single-lattice only.
    if ndset(parent) > 1
        throw(ArgumentError(
            "chunk 5 supports single-lattice parents only " *
            "(`length(parent.dset) == 1`). Got dset of length $(ndset(parent)). " *
            "Multilattice support (HCP, perovskite, slab geometries) requires " *
            "extending getPermG to handle n × n_D sites; deferred to v0.3."))
    end

    # Sites validation — chunk 5 single-site only.
    if length(sites.list) != 1
        throw(ArgumentError(
            "chunk 5 supports a single-site Sites only " *
            "(`length(sites.list) == 1`). Got $(length(sites.list)) sites. " *
            "Multi-site Sites (per-site `allowed_labels`, perovskite-style site " *
            "restrictions) requires the multinomial-restricted algorithm; " *
            "deferred to chunk 6+."))
    end

    site = sites.list[1]
    is_active(site) || throw(ArgumentError(
        "the only site is inactive (`length(allowed_labels) == 1`); nothing to " *
        "enumerate. The structure is trivially fixed."))

    # Allowed labels validation — chunk 5 zero-indexed dense.
    allowed = sort(collect(site.allowed_labels))
    k = length(allowed)
    if allowed != collect(0:k-1)
        throw(ArgumentError(
            "chunk 5 requires zero-indexed dense allowed_labels " *
            "(`{0, 1, ..., k-1}`). Got `$(site.allowed_labels)`. Sparse / " *
            "non-zero-indexed labels deferred to chunk 6+."))
    end

    # Pre-flight gate — chunk 5 stub. Real estimator lands with chunk 7.
    # We accept and ignore memory_budget / on_overflow / skip_preflight.
    # The signature shape is stable so users can experiment with the kwargs
    # against future chunks without rewriting their call sites.

    # Resolve the supercell selection into a concrete HNF list.
    hnfs = enumerate_hnfs(supercells, parent)
    isempty(hnfs) && return Enumeration{D, Vector{Int8}}(
        parent, sites, Supercell{D}[], EnumeratedStructure{D, Vector{Int8}}[])

    # The 2008 algorithm body.
    structures = EnumeratedStructure{D, Vector{Int8}}[]
    supercells_list = Supercell{D}[]
    for hnf in hnfs
        sc = Supercell(hnf, parent)
        push!(supercells_list, sc)
        sc_id = length(supercells_list)

        # `getUniqueColorings(k, perm_group)` returns Vector{Vector{Int}} —
        # one labeling per symmetry-inequivalent coloring on this supercell,
        # length-`n` (where n = volume of the supercell).
        # Conversion to Vector{Int8} keeps the chunk-5 storage representation
        # consistent (~1 byte per site instead of 8).
        colorings = getUniqueColorings(k, sc.permutation_group)
        for c in colorings
            push!(structures, EnumeratedStructure{D, Vector{Int8}}(
                sc_id, Int8.(c), 1, 1))
        end
    end

    return Enumeration{D, Vector{Int8}}(parent, sites, supercells_list, structures)
end

"""
    default_memory_budget()

The default `memory_budget` for `enumerate(...)` — adapts to the host machine. 25% of the system's physical memory, with a 2 GiB floor. Chunk 5's pre-flight gate is a stub that always passes; chunk 7 (Polya counter) makes this a real check.

**Caveat:** `Sys.total_memory()` reports the *machine's* RAM, not the cgroup / Slurm / Kubernetes allocation in containerized environments. HPC users on a shared cluster need to pass `memory_budget = \$SLURM_MEM_PER_NODE` (or similar) explicitly.
"""
default_memory_budget() = max(2 * 2^30, Int(Sys.total_memory() ÷ 4))
