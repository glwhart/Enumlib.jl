# POSCAR I/O for the DFT/MLIP training-database workflow.
#
# Phase 11 — chunk 11a: single-structure POSCAR writer.
#
# Writes VASP-5+ POSCARs (compatible with VASP 5 and VASP 6). Line 1 is a
# comment we control; we encode the structure's identity metadata + an
# `energy_eV=` slot the calculator fills in after running DFT/MLIP. Round-
# tripping the energy back to Enumlib happens via `read_results(...)` (chunk
# 11c).
#
# Locked design decisions (see docs/notes/phase11-design.md):
#   - VASP-5+ format (compatible with VASP 5 and VASP 6).
#   - Lattice vectors in VASP rows convention (transpose from Julia's column
#     basis convention).
#   - Direct (fractional) coordinates only; never Cartesian-mode.
#   - species_symbols defaults to ["A", "B", "C", ...] (calling user can
#     override; collaborator picks chemistry at DFT-prep time).
#   - Concentration in header is the actual labeling's a:b:... counts.
#   - No permutation tracking; energy round-trips by enumlib_id only.

# -- Header line format --------------------------------------------------------
#
#   # enumlib_id=<n> hnf=<i> concentration=<a:b:...> super_periodic=<bool>[ <extras>] energy_eV=
#
# Notes:
#   - enumlib_id is the position in `enumeration.structures` at write time.
#   - hnf is the supercell_id field of the EnumeratedStructure.
#   - concentration is the actual count multiplicities derived from the labeling.
#   - super_periodic records the include_superperiodic kwarg used during
#     enumerate(...) — needed so a reader knows which orbit policy generated this.
#   - extras (optional) are user-supplied additional `key=value` pairs.
#   - energy_eV= is *last* and starts empty; the calculator fills in a number.

"""
    to_poscar(io::IO, structure::EnumeratedStructure{D,L},
              parent::ParentLattice{D}, hnf::HNF{D};
              super_periodic::Bool,
              species_symbols::Vector{String} = String[],
              comment_extras::Vector{String} = String[],
              enumlib_id::Integer = 0,
              hnf_idx::Integer = structure.supercell_id) where {D,L}

Write a single POSCAR (VASP-5+ format) for `structure` to `io`.

Line 1 is a comment carrying identity metadata and an empty `energy_eV=` slot the calculator fills in after DFT/MLIP. Lines 2 onwards are standard VASP-5+ POSCAR.

Required kwargs:
- `super_periodic::Bool` — the `include_superperiodic` policy this structure was enumerated under (`true` = full Burnside; `false` = primitive only). Recorded in the header so a reader knows the orbit-policy provenance.

Optional kwargs:
- `species_symbols::Vector{String}` — length ≥ k. Default is `["A", "B", "C", ...]` (one letter per color). Override with real chemistry symbols at the call site if known. Ordering: color 0 → species_symbols[1], color 1 → species_symbols[2], etc.
- `comment_extras::Vector{String}` — additional `key=value` pairs inserted before the `energy_eV=` slot (e.g., `["author=alice", "calc_id=run42"]`).
- `enumlib_id::Integer` — the structure's flat ID. Bulk callers (`write_enumeration_archive`) compute the index in `enumeration.structures` and pass it; single-call users can leave at 0 if the ID isn't meaningful.
- `hnf_idx::Integer` — the HNF index in the manifest. Default = `structure.supercell_id`.

# Example

```jldoctest
julia> using Enumlib

julia> parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]);

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);

julia> e = enumerate(parent, sites; supercells = VolumeRange(2:2));

julia> io = IOBuffer();

julia> hnf_for_structure = e.supercells[e.structures[1].supercell_id].hnf;

julia> to_poscar(io, e.structures[1], parent, hnf_for_structure;
                 super_periodic = false, enumlib_id = 1);

julia> first(split(String(take!(io)), '\\n'), 1)
1-element Vector{SubString{String}}:
 "# enumlib_id=1 hnf=1 concentration=1:1 super_periodic=false energy_eV="
```
"""
function to_poscar(io::IO, structure::EnumeratedStructure{D,L},
                   parent::ParentLattice{D}, hnf::HNF{D};
                   super_periodic::Bool,
                   species_symbols::Vector{String} = String[],
                   comment_extras::Vector{String} = String[],
                   enumlib_id::Integer = 0,
                   hnf_idx::Integer = structure.supercell_id) where {D,L}
    coloring = to_labeling(structure)
    n = length(coloring)

    # k inference. If species_symbols is supplied, it implicitly defines the
    # full species set and k = length(species_symbols). Otherwise we infer
    # from the highest color seen in the labeling — caveat: a monochromatic
    # all-color-0 labeling would inferr k=1 even if the parent's allowed
    # labels were {0, 1}, leaving the second species unrepresented in the
    # POSCAR. Bulk callers (chunk 11b's write_enumeration_archive) will
    # always pass species_symbols of the correct length, so the inference
    # fallback only matters for ad-hoc single-call users.
    k = if isempty(species_symbols)
        isempty(coloring) ? 0 : Int(maximum(coloring)) + 1
    else
        length(species_symbols)
    end

    # Validate per-color labelings are in 0..k-1 (catches misuse where a
    # supplied species_symbols is too short).
    isempty(coloring) || maximum(coloring) < k ||
        throw(ArgumentError(
            "species_symbols has length $(length(species_symbols)) but the labeling " *
            "uses color $(maximum(coloring)); supply at least $(Int(maximum(coloring))+1) symbols."))

    # Default species symbols are ASCII letters: ["A", "B", ...]. The calling
    # user can override with real chemistry; the calculator can also override
    # before running DFT (the species line in the POSCAR is what their tool
    # reads).
    species = isempty(species_symbols) ?
        [string(Char(Int('A') + (i - 1))) for i in 1:k] :
        species_symbols

    # Per-color counts; this IS the concentration.
    counts = zeros(Int, k)
    for c in coloring
        counts[Int(c) + 1] += 1
    end
    concentration_str = join(counts, ":")

    # ---- Line 1: header comment ----
    # extras inserted between the fixed-key metadata and the energy_eV= slot,
    # so the energy slot is always last and trivially regex-extractable.
    extras_str = isempty(comment_extras) ? "" : " " * join(comment_extras, " ")
    println(io, "# enumlib_id=", enumlib_id,
                " hnf=", hnf_idx,
                " concentration=", concentration_str,
                " super_periodic=", super_periodic,
                extras_str,
                " energy_eV=")

    # ---- Line 2: scale factor (always 1.0) ----
    println(io, "1.0")

    # ---- Lines 3..2+D: lattice vectors in VASP rows convention ----
    # Julia stores basis with columns = lattice vectors (A_super[:, j] is the
    # j-th lattice vector). VASP reads each row of POSCAR as one lattice
    # vector. So we transpose: row j of the POSCAR is column j of A_super.
    #
    # Right-handedness: VASP refuses to process POSCARs with a left-handed
    # basis (det < 0). Enumlib's parent lattice can be left-handed (chunk 1.1
    # relaxed the right-handedness check to non-singularity). When that's the
    # case, swap columns 1 and 2 of the supercell basis to flip the sign of
    # det while preserving Cartesian positions; the matching position fix
    # below swaps the first two components of every fractional coordinate.
    # The Cartesian geometry VASP reads is identical to what Enumlib enumerated.
    A_super = parent.A * hnf.matrix
    chirality_swap = LinearAlgebra.det(A_super) < 0
    if chirality_swap
        A_super = A_super[:, [2, 1, 3]]
    end
    for j in 1:D
        for i in 1:D
            print(io, @sprintf("%22.12f", A_super[i, j]))
        end
        println(io)
    end

    # ---- Line 3+D: species symbols (all k, including zero-count species) ----
    # ---- Line 4+D: per-species counts in the same order (zeros included) ----
    # Per chunk 11a review item D: list every species the labeling could use,
    # including those with zero count in this specific structure. The
    # calculator's POTCAR file sequence must match the POSCAR's species line;
    # dropping zero-count species would force the calculator to also edit the
    # POTCAR by hand, which is inconvenient. Modern VASP handles zero counts
    # cleanly. (Earlier draft dropped them; reverted.)
    println(io, join(species[1:k], " "))
    println(io, join((string(counts[i]) for i in 1:k), " "))

    # ---- Line 5+D: coordinate mode ----
    println(io, "Direct")

    # ---- Lines 6+D onwards: atomic positions, grouped by species ----
    # Order matches lines (3+D) and (4+D): all color-0 atoms, then all color-1, etc.
    # Zero-count colors emit no position lines (the inner loop naturally
    # skips them). Within each color group, atoms are in supercell-site-index
    # order (`getPermG`'s convention).
    #
    # If we swapped columns 1↔2 of A_super to fix chirality (above), the
    # corresponding fractional positions must also have their first two
    # coordinates swapped so the Cartesian positions stay invariant.
    # For multilattice parents (n_D ≥ 2), positions cover n_D · n_cells sites
    # in the dset-blocks layout matching the labeling. For single-lattice
    # this degenerates to the n_cells case.
    fractional_positions = supercell_fractional_positions(hnf, parent)
    if chirality_swap
        fractional_positions = [(p[2], p[1], p[3]) for p in fractional_positions]
    end
    for color_one_indexed in 1:k
        target_color = color_one_indexed - 1
        for site in 1:n
            if Int(coloring[site]) == target_color
                fp = fractional_positions[site]
                for d in 1:D
                    print(io, @sprintf("%22.12f", fp[d]))
                end
                println(io)
            end
        end
    end

    return nothing
end

"""
    supercell_fractional_positions(hnf::HNF{D}) :: Vector{NTuple{D,Float64}}
    supercell_fractional_positions(hnf::HNF{D}, parent::ParentLattice{D}) :: Vector{NTuple{D,Float64}}

Fractional coordinates (in the supercell basis) of each of the `n_D · volume(hnf)` sites in the supercell, in the same order as `getPermG`'s site indexing. The parent-aware overload handles multilattice (`n_D ≥ 2`); the single-argument form is the single-lattice case (`n_D = 1`, returns `volume(hnf)` positions).

Internal helper for POSCAR writing. Derivation: from the SNF `U·h·V = S` (NormalForms.jl convention) with `S = diag(d_1, ..., d_D)`, the Bravais site `(i_1, ..., i_D)` in SNF coords has parent-fractional position `U^{-1}·(i_1, ..., i_D)`, so its supercell-fractional position is `h^{-1}·U^{-1}·(i_1, ..., i_D) = V·(i_1/d_1, ..., i_D/d_D)` (mod 1). For multilattice, the atom at dset position `α` adds `h^{-1}·dset[α]` to this Bravais position.

The site iteration order matches the dset-blocks layout used by the parent-aware `getPermG` (R50.2b): `flat_idx(α, g) = (α-1)·n + g_idx` with `g_idx` iterating `[[i,j,k] for i ∈ 0:d_1-1 for j ∈ 0:d_2-1 for k ∈ 0:d_3-1]` (3D specialization). So site `m` in the returned vector corresponds to color `coloring[m]` in any chunk-5/6/8 enumeration.

# Examples

Single-lattice (Bravais), returns `n_cells` positions:
```jldoctest
julia> using Enumlib

julia> h = HNF{3}([1 0 0; 0 1 0; 0 0 4]);

julia> Enumlib.supercell_fractional_positions(h)
4-element Vector{Tuple{Float64, Float64, Float64}}:
 (0.0, 0.0, 0.0)
 (0.0, 0.0, 0.25)
 (0.0, 0.0, 0.5)
 (0.0, 0.0, 0.75)
```

HCP multilattice (`n_D = 2`), returns `2 · n_cells` positions in dset-blocks layout — first all cells for dset position 1, then all cells for dset position 2:
```jldoctest
julia> using Enumlib

julia> A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)];

julia> p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]]);

julia> h = HNF{3}([1 0 0; 0 1 0; 0 0 2]);

julia> Enumlib.supercell_fractional_positions(h, p)
4-element Vector{Tuple{Float64, Float64, Float64}}:
 (0.0, 0.0, 0.0)
 (0.0, 0.0, 0.5)
 (0.3333333333333333, 0.6666666666666666, 0.25)
 (0.3333333333333333, 0.6666666666666666, 0.75)
```
"""
function supercell_fractional_positions(hnf::HNF{3})
    F = NormalForms.snf(hnf.matrix)
    S, V = F.S, F.V
    d = (Int(S[1,1]), Int(S[2,2]), Int(S[3,3]))
    n = d[1] * d[2] * d[3]
    positions = Vector{NTuple{3,Float64}}(undef, n)
    idx = 0
    snf_frac = Vector{Float64}(undef, 3)
    for i in 0:d[1]-1, j in 0:d[2]-1, k in 0:d[3]-1
        idx += 1
        snf_frac[1] = i / d[1]
        snf_frac[2] = j / d[2]
        snf_frac[3] = k / d[3]
        sup_frac = V * snf_frac
        positions[idx] = (mod(sup_frac[1], 1.0),
                          mod(sup_frac[2], 1.0),
                          mod(sup_frac[3], 1.0))
    end
    return positions
end

function supercell_fractional_positions(hnf::HNF{3}, parent::ParentLattice{3})
    n_D = ndset(parent)
    cell_positions = supercell_fractional_positions(hnf)   # n_cells positions
    n_D == 1 && return cell_positions

    # Multilattice: add h^{-1} · dset[α] to each cell position, in dset-blocks
    # layout matching the parent-aware getPermG site indexing.
    h_inv = inv(hnf.matrix)
    n_cells = length(cell_positions)
    positions = Vector{NTuple{3,Float64}}(undef, n_D * n_cells)
    for α in 1:n_D
        dset_super = h_inv * parent.dset[α]   # supercell-fractional offset for this dset position
        offset = (α - 1) * n_cells
        for g_idx in 1:n_cells
            cp = cell_positions[g_idx]
            positions[offset + g_idx] = (mod(cp[1] + dset_super[1], 1.0),
                                         mod(cp[2] + dset_super[2], 1.0),
                                         mod(cp[3] + dset_super[3], 1.0))
        end
    end
    return positions
end

# ============================================================================
# Chunk 11b — bulk write to a tarball + TOML manifest.
# ============================================================================

"""
    write_enumeration_archive(path, enumeration::Enumeration{D,L};
                               super_periodic::Bool,
                               species_symbols::Vector{String} = String[],
                               label::AbstractString = "",
                               keep_directory::Bool = false) -> String

Write every structure in `enumeration` to a single `.tar.gz` deliverable at `path`. Returns the actual tarball path written (may differ from `path` if `path` was a directory and the writer auto-named the file).

The tarball contains:
- `POSCAR.NNNNN` — one per structure, where N is zero-padded to fit `length(enumeration.structures)` (width = `max(2, ndigits(N))`). Each POSCAR's header line 1 carries `enumlib_id=NNNNN` matching the filename, plus an empty `energy_eV=` slot the calculator fills in.
- `enumeration.toml` — manifest mapping each filename to its structure metadata, plus a `[enumeration]` top-level section recording the parent lattice, species symbols, super-periodicity policy, etc.

# Arguments

- `path` — output tarball path. If `path` ends in `.tar.gz` or `.tgz`, the file is written exactly there. Otherwise `path` is treated as a directory and the writer auto-names the tarball inside it as `enumlib_<label>_<yyyy-mm-ddTHH-MM-SS>.tar.gz` (timestamped to make collisions impossible).

# Required kwargs

- `super_periodic::Bool` — the `include_superperiodic` policy this enumeration was produced under. Recorded in every POSCAR header and in the manifest's `[enumeration]` section.

# Optional kwargs

- `species_symbols::Vector{String}` — length ≥ k. Default `["A", "B", "C", ...]` (one ASCII letter per color). Override at the call site if real chemistry is known at enumeration time; the calculator can also override at DFT-prep time.
- `label::AbstractString` — descriptive component of the auto-named filename (e.g., `"FCC_AgPt_n32_15-17"`). If empty, defaults to `"enum"`.
- `keep_directory::Bool = false` — if true, also keep the assembled directory next to the tarball at `<tarball-stem>/`. Useful for inspection or for users who'd rather not extract before editing.

# Example

```julia
parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
e = enumerate(parent, sites; supercells = VolumeRange(4:4))
out = write_enumeration_archive("./batch1/", e;
                                  super_periodic = false,
                                  species_symbols = ["Ag", "Pt"],
                                  label = "FCC_AgPt_n4")
# out: "./batch1/enumlib_FCC_AgPt_n4_2026-05-08T14-30-00.tar.gz"
```
"""
function write_enumeration_archive(path::AbstractString, enumeration::Enumeration{D,L};
                                    super_periodic::Bool,
                                    species_symbols::Vector{String} = String[],
                                    label::AbstractString = "",
                                    keep_directory::Bool = false) where {D,L}
    n_structures = length(enumeration.structures)
    n_structures > 0 ||
        throw(ArgumentError(
            "enumeration has zero structures; nothing to write. Check your " *
            "VolumeRange / concentration constraints."))

    # Resolve output tarball path.
    out_path = if endswith(path, ".tar.gz") || endswith(path, ".tgz")
        # User provided an exact filename.
        path
    else
        # Treat `path` as a directory; auto-name with timestamp.
        ts = Dates.format(Dates.now(), "yyyy-mm-ddTHH-MM-SS")
        label_part = isempty(label) ? "enum" : label
        joinpath(path, "enumlib_$(label_part)_$(ts).tar.gz")
    end

    # Make parent directory if needed.
    parent_dir = dirname(out_path)
    if !isempty(parent_dir) && !isdir(parent_dir)
        mkpath(parent_dir)
    end

    # Build the directory of POSCARs + manifest, then tar+gzip it.
    if keep_directory
        # Persistent directory next to the tarball (no temp).
        stem = replace(out_path, r"\.(tar\.gz|tgz)$" => "")
        isdir(stem) && rm(stem; recursive = true, force = true)
        mkpath(stem)
        _build_enumeration_directory(stem, enumeration;
                                     super_periodic, species_symbols)
        _tar_gzip_directory(stem, out_path)
    else
        # Temp dir — auto-cleaned after tarring.
        mktempdir() do temp_dir
            _build_enumeration_directory(temp_dir, enumeration;
                                         super_periodic, species_symbols)
            _tar_gzip_directory(temp_dir, out_path)
        end
    end

    return out_path
end

# Build a directory with one POSCAR per structure plus a TOML manifest.
function _build_enumeration_directory(dir::AbstractString,
                                       enumeration::Enumeration{D,L};
                                       super_periodic::Bool,
                                       species_symbols::Vector{String}) where {D,L}
    n_structures = length(enumeration.structures)
    width = max(2, ndigits(n_structures))

    # Resolve k from species_symbols length if supplied; otherwise infer from
    # the maximum color seen across all structures (handles the rare case
    # where some structures use fewer colors than others).
    inferred_k = isempty(species_symbols) ?
        maximum(maximum(to_labeling(s)) for s in enumeration.structures) + 1 :
        length(species_symbols)
    k = isempty(species_symbols) ? inferred_k : length(species_symbols)

    # Build manifest dict in parallel with writing POSCARs.
    manifest = Dict{String, Any}()
    manifest["enumeration"] = Dict{String, Any}(
        "created_at" => Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"),
        "n_structures" => n_structures,
        "n_supercells" => length(enumeration.supercells),
        "super_periodic" => super_periodic,
        "species_symbols" => isempty(species_symbols) ?
            [string(Char(Int('A') + (i - 1))) for i in 1:k] : species_symbols,
        "parent_basis_columns" => [collect(enumeration.parent.A[:, j]) for j in 1:D],
        "k" => k,
    )
    structures_section = Dict{String, Any}()

    for (idx, structure) in enumerate(enumeration.structures)
        sc = enumeration.supercells[structure.supercell_id]
        hnf = sc.hnf
        labeling = to_labeling(structure)
        # Compute concentration string from the labeling.
        counts = zeros(Int, k)
        for c in labeling
            counts[Int(c) + 1] += 1
        end
        concentration_str = join(counts, ":")

        filename = "POSCAR." * lpad(string(idx), width, '0')
        filepath = joinpath(dir, filename)
        open(filepath, "w") do io
            to_poscar(io, structure, enumeration.parent, hnf;
                       super_periodic,
                       species_symbols,
                       enumlib_id = idx,
                       hnf_idx = structure.supercell_id)
        end

        structures_section[string(idx)] = Dict{String, Any}(
            "hnf_idx" => structure.supercell_id,
            "concentration" => concentration_str,
            "poscar_filename" => filename,
            "hnf_matrix_columns" => [collect(hnf.matrix[:, j]) for j in 1:D],
        )
    end

    manifest["structure"] = structures_section

    # Write the manifest.
    open(joinpath(dir, "enumeration.toml"), "w") do io
        TOML.print(io, manifest; sorted = true)
    end

    return nothing
end

# Tar+gzip a directory's contents into the target path.
function _tar_gzip_directory(dir::AbstractString, out_path::AbstractString)
    open(out_path, "w") do io
        gz_io = GzipCompressorStream(io)
        try
            Tar.create(dir, gz_io)
        finally
            close(gz_io)
        end
    end
    return out_path
end

# ============================================================================
# Chunk 11c — round-trip read of calculator-filled POSCARs.
# ============================================================================

"""
    read_results(path::AbstractString;
                 manifest_filename::AbstractString = "enumeration.toml") -> Dict{Int, Float64}

Read back DFT/MLIP results from a directory of POSCARs (where collaborators have filled in the `energy_eV=` slot on each POSCAR's line 1) or from a tarball produced by [`write_enumeration_archive`](@ref).

Auto-detects the input form:
- `path` is a `.tar.gz`, `.tgz`, or `.tar` file → extracts to a temp dir, reads, cleans up.
- `path` is a directory → reads directly.

Returns a `Dict{Int, Float64}` mapping each filled-in `enumlib_id` to its energy in eV. POSCARs whose `energy_eV=` slot is still empty (calculator hasn't filled them in) are skipped with an `@info` message listing the missing IDs.

Throws `ArgumentError` if any POSCAR's line 1 doesn't match the expected format (missing `enumlib_id=`, missing `energy_eV=`, or unparseable energy value).

Hand-edit and shell-script workflows both work: collaborators can run e.g. `sed -i 's/energy_eV=\$/energy_eV=-123.45/' POSCAR.42` after their DFT job, then ship the directory or tarball back.

# Example

```julia
results = read_results("./batch1_filled.tar.gz")
# Dict(1 => -123.45, 2 => -123.46, ...)
pairs = attach_results(enumeration, results)
# Vector{Tuple{EnumeratedStructure, Float64}}, ready for CE fitting
```
"""
function read_results(path::AbstractString;
                     manifest_filename::AbstractString = "enumeration.toml")::Dict{Int, Float64}
    if isfile(path) && (endswith(path, ".tar.gz") || endswith(path, ".tgz") || endswith(path, ".tar"))
        return mktempdir() do parent_dir
            extract_dir = joinpath(parent_dir, "extracted")
            _extract_archive(path, extract_dir)
            _read_results_from_directory(extract_dir; manifest_filename)
        end
    elseif isdir(path)
        return _read_results_from_directory(path; manifest_filename)
    else
        throw(ArgumentError(
            "read_results: '$path' is neither a tarball file (.tar.gz/.tgz/.tar) " *
            "nor a directory"))
    end
end

"""
    attach_results(enumeration::Enumeration{D,L}, results::Dict{Int, Float64})
        -> Vector{Tuple{EnumeratedStructure{D,L}, Float64}}

Pair each `enumlib_id → energy` entry in `results` with the corresponding `EnumeratedStructure` from `enumeration`. Returns a flat `Vector{Tuple{EnumeratedStructure, Float64}}` ready for downstream cluster-expansion or MLIP fitting.

Throws `KeyError` if any ID in `results` is out of range `[1, length(enumeration.structures)]`. Emits an `@info` message naming structure IDs that appear in the enumeration but not in `results` (calculator hasn't filled in energy yet — usually expected mid-batch).

A typed `EnrichedEnumeration` wrapper is intentionally NOT introduced here; the flat tuple list is the simplest interchange shape and the current consumer (JuCE.jl's CE fitter) expects it. Wrapping is v0.3+ polish if a richer view becomes useful.
"""
function attach_results(enumeration::Enumeration{D,L},
                        results::Dict{Int, Float64}) where {D,L}
    n = length(enumeration.structures)
    pairs = Tuple{EnumeratedStructure{D,L}, Float64}[]
    for (id, energy) in results
        if id < 1 || id > n
            throw(KeyError(
                "attach_results: structure_id $id is out of range [1, $n]"))
        end
        push!(pairs, (enumeration.structures[id], energy))
    end

    # Sort by ID for deterministic ordering (Dict iteration is unordered).
    sort!(pairs; by = p -> _enumlib_id_position(enumeration, p[1]))

    missing_ids = setdiff(1:n, keys(results))
    if !isempty(missing_ids)
        @info "attach_results: $(length(missing_ids)) of $n structure(s) have no matching result " *
              "(calculator hasn't filled in energy_eV yet for these IDs)" missing_ids
    end

    return pairs
end

# ----------------------------------------------------------------------------
# Internal helpers for read_results.
# ----------------------------------------------------------------------------

# Find the 1-indexed position of a structure within enumeration.structures.
# Used for sorting attach_results output deterministically.
function _enumlib_id_position(enumeration::Enumeration, structure::EnumeratedStructure)
    for (i, s) in enumerate(enumeration.structures)
        s === structure && return i
    end
    return 0
end

# Extract a tarball into target_dir (which must not yet exist).
function _extract_archive(archive_path::AbstractString, target_dir::AbstractString)
    if endswith(archive_path, ".tar.gz") || endswith(archive_path, ".tgz")
        open(archive_path, "r") do io
            gz_io = GzipDecompressorStream(io)
            try
                Tar.extract(gz_io, target_dir; copy_symlinks = false)
            finally
                close(gz_io)
            end
        end
    elseif endswith(archive_path, ".tar")
        open(archive_path, "r") do io
            Tar.extract(io, target_dir; copy_symlinks = false)
        end
    else
        throw(ArgumentError(
            "_extract_archive: unknown archive format for '$archive_path'; " *
            "expected .tar.gz, .tgz, or .tar"))
    end
    return target_dir
end

# Walk every POSCAR in a directory, parse line 1 of each, return Dict{Int, Float64}.
function _read_results_from_directory(dir::AbstractString;
                                      manifest_filename::AbstractString = "enumeration.toml")::Dict{Int, Float64}
    results = Dict{Int, Float64}()
    unfilled = Int[]
    n_seen = 0

    for filename in sort!(readdir(dir))
        startswith(filename, "POSCAR") || continue
        filename == manifest_filename && continue   # not a POSCAR
        filepath = joinpath(dir, filename)
        isfile(filepath) || continue
        n_seen += 1

        line1 = open(readline, filepath)

        # Parse enumlib_id from line 1.
        m_id = match(r"enumlib_id=(\d+)", line1)
        m_id === nothing && throw(ArgumentError(
            "$(filepath): line 1 does not contain `enumlib_id=N` " *
            "(expected Enumlib-format POSCAR header). First line was:\n  $line1"))
        id = parse(Int, m_id.captures[1])

        # Parse energy_eV slot from line 1. Permissive on the float format
        # (the calculator might write -12.345, -1.2345e+01, +12.345, etc.);
        # strict on the slot key being exactly `energy_eV=`.
        m_e = match(r"energy_eV\s*=\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)?", line1)
        if m_e === nothing
            throw(ArgumentError(
                "$(filepath): line 1 does not contain `energy_eV=` slot. " *
                "First line was:\n  $line1"))
        end

        if m_e.captures[1] === nothing || isempty(strip(m_e.captures[1]))
            push!(unfilled, id)
            continue
        end

        energy_str = strip(m_e.captures[1])
        local energy::Float64
        try
            energy = parse(Float64, energy_str)
        catch
            throw(ArgumentError(
                "$(filepath): could not parse energy_eV value '$energy_str' " *
                "as a Float64. First line was:\n  $line1"))
        end
        results[id] = energy
    end

    if !isempty(unfilled)
        @info "read_results: $(length(unfilled)) of $n_seen POSCARs had empty " *
              "`energy_eV=` slot; skipped (calculator hasn't filled them in yet)" unfilled_ids = sort(unfilled)
    end

    return results
end
