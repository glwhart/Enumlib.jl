# Reader for `struct_enum.out` — the input side of `makestr.x`.
#
# `write_struct_enum_out` (io/struct_enum.jl) emits the file; this reads it back
# far enough to rebuild each listed structure as the objects the rest of the
# package already understands (`ParentLattice`, `HNF`, `EnumeratedStructure`), so
# `makestr.x` can hand them to `to_poscar` instead of re-deriving any geometry.
#
# Parsing is positional but anchored on landmark lines rather than fixed line
# numbers ("bulk"/"surf", "Number of points", "-nary", and the "start …" column
# header), because the header block grows by a few lines when a concentration
# restriction is present.
#
# Scope note: this is verified against the files `write_struct_enum_out` produces.
# That writer was templated on real Fortran `enum.x` output, so genuine Fortran
# files are expected to parse, but that is untested here — the Fortran binary is
# not available in this repo's test environment.

"""
    read_struct_enum_out(path_or_io) -> NamedTuple

Parse a `struct_enum.out` file. Returns `(; parent, k, nD, latdim, structures)` where
`structures` is a vector of `(; strN, hnf_id, hnf, labeling, orbit_size, n)` —
enough to rebuild each structure and write it out via [`to_poscar`](@ref).

`labeling` is a `Vector{Int8}` of 0-based colors, in the same site order the
writer used, so a labeling read back here is byte-identical to the one that was
written.
"""
read_struct_enum_out(path::AbstractString) = open(read_struct_enum_out, path, "r")

function read_struct_enum_out(io::IO)
    lines = readlines(io)
    isempty(lines) && throw(ArgumentError("struct_enum.out is empty"))

    _find(pred, what) = begin
        idx = findfirst(pred, lines)
        idx === nothing &&
            throw(ArgumentError("struct_enum.out: could not locate $what"))
        idx
    end

    # --- parent lattice: the three lines after the bulk/surf marker ---
    i_dim = _find(l -> (s = strip(l); s == "bulk" || s == "surf"),
                  "the 'bulk'/'surf' line")
    latdim = strip(lines[i_dim]) == "bulk" ? 3 : 2
    cols = map(1:3) do j
        toks = split(_strip_comment(lines[i_dim + j]))
        length(toks) >= 3 ||
            throw(ArgumentError("struct_enum.out: malformed parent lattice vector " *
                                "on line $(i_dim + j): $(repr(lines[i_dim + j]))"))
        parse.(Float64, toks[1:3])
    end
    A = hcat(cols...)                       # the writer emits column j of A per line

    # --- d-set: cartesian in the file, fractional in ParentLattice ---
    i_nd = _find(l -> occursin("Number of points", l), "the multilattice count")
    nD = parse(Int, first(split(_strip_comment(lines[i_nd]))))
    dset = map(1:nD) do t
        toks = split(_strip_comment(lines[i_nd + t]))
        length(toks) >= 3 ||
            throw(ArgumentError("struct_enum.out: malformed d-vector on line $(i_nd + t)"))
        A \ parse.(Float64, toks[1:3])
    end
    parent = ParentLattice(A, dset)

    i_k = _find(l -> occursin("-nary", l), "the k-nary line")
    k = parse(Int, first(split(strip(lines[i_k]), '-')))

    # --- data rows: everything after the column-header line ---
    i_hdr = _find(l -> startswith(strip(l), "start"), "the column-header line")

    structures = NamedTuple[]
    for idx in (i_hdr + 1):length(lines)
        toks = split(strip(lines[idx]))
        isempty(toks) && continue
        length(toks) >= 27 ||
            throw(ArgumentError("struct_enum.out line $idx has $(length(toks)) " *
                                "tokens, expected ≥ 27"))
        v = parse.(Int, toks[1:26])
        H = [v[12] 0 0; v[13] v[14] 0; v[15] v[16] v[17]]
        labeling = Int8[Int8(c - '0') for c in toks[27]]
        length(labeling) == nD * v[7] ||
            throw(ArgumentError("struct_enum.out line $idx: labeling has " *
                                "$(length(labeling)) sites but nD·n = $(nD * v[7])"))
        push!(structures, (strN = v[1], hnf_id = v[2], hnf = HNF{3}(H),
                           labeling = labeling, orbit_size = v[4], n = v[7]))
    end

    return (; parent, k, nD, latdim, structures)
end

# Drop a trailing `# comment`, which the writer appends to lattice and d-vectors.
_strip_comment(line::AbstractString) = first(split(line, '#'))
