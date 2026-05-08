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
    A_super = parent.A * hnf.matrix
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
    fractional_positions = supercell_fractional_positions(hnf)
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

Fractional coordinates (in the supercell basis) of each of the `volume(hnf)` sites in the supercell, in the same order as `getPermG`'s site indexing.

Internal helper for POSCAR writing. Derivation: from the SNF `U·h·V = S` (NormalForms.jl convention) with `S = diag(d_1, ..., d_D)`, site `(i_1, ..., i_D)` in SNF coords has primitive-lattice integer position `U^{-1}·(i_1, ..., i_D)`, so its supercell-fractional position is `h^{-1}·U^{-1}·(i_1, ..., i_D) = V·(i_1/d_1, ..., i_D/d_D)` (mod 1).

The site iteration order matches `getPermG`'s `[[i,j,k] for i ∈ 0:d_1-1 for j ∈ 0:d_2-1 for k ∈ 0:d_3-1]` (3D specialization), so site `m` returned here corresponds to color `coloring[m]` in any chunk-5/6/8 enumeration.

# Example

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
