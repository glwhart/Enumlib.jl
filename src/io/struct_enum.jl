# Fortran-enumlib `struct_enum.in` reader for the drop-in `enum.x` CLI (Phase 9).
# See docs/notes/phase9-design.md. This is chunk 9.1a — the reader only; the
# `struct_enum.out` writer + `bin/enum.jl` CLI entry land in the next increment.
#
# Not exported: the CLI and tests reach these as `Enumlib.read_struct_enum_in`.

# --- small parsing helpers (prefixed `_seio_` to avoid collisions) ------------

# Data part of a line = everything before the first inline `#`, stripped.
# A blank or pure-comment line yields "".
_seio_data_part(ln::AbstractString) = strip(first(split(ln, '#'; limit = 2)))

_seio_floats(s::AbstractString) = [parse(Float64, t) for t in split(s)]
_seio_first_int(s::AbstractString) = parse(Int, first(split(s)))

# Parse a whole line as ints, or return `nothing` if any token isn't an integer
# (used to detect the optional trailing concentration block).
function _seio_try_ints(s::AbstractString)
    vals = Int[]
    for t in split(s)
        v = tryparse(Int, t)
        v === nothing && return nothing
        push!(vals, v)
    end
    return vals
end

"""
    read_struct_enum_in(io::IO) -> NamedTuple

Parse a Fortran-enumlib `struct_enum.in` stream into Enumlib.jl inputs. Returns

    (; title, latdim, parent, sites, selection, concentration, eps, mode)

ready to feed `enumerate_structures(parent, sites; supercells = selection, concentration)`.

Scope (chunk 9.1, v0.3): `bulk` only; `full` mode only; single- and multilattice
with per-d-vector allowed labels; optional concentration block. `surf`/2D, the
inactive-site label encoding (a label ≥ `k`), explicit equivalencies, and `part`
mode are deferred and raise `ArgumentError` — see docs/notes/phase9-design.md §4.
"""
function read_struct_enum_in(io::IO)
    # Keep the data part of every non-blank, non-comment line, in order. Mirrors
    # the Fortran `co_ca` comment/blank skipping in io_utils.f90:read_input.
    sig = String[]
    for ln in readlines(io)
        d = _seio_data_part(ln)
        isempty(d) || push!(sig, d)
    end
    isempty(sig) && throw(ArgumentError("empty struct_enum.in"))

    i = 1
    _next() = (v = sig[i]; i += 1; v)

    title  = _next()
    lattyp = lowercase(_next())
    startswith(lattyp, "bulk") || throw(ArgumentError(
        "struct_enum.in: only 'bulk' is supported in v0.3 (got '$lattyp'); 'surf'/2D is deferred"))
    latdim = 3

    A = hcat(_seio_floats(_next())[1:3], _seio_floats(_next())[1:3], _seio_floats(_next())[1:3])
    Ainv = inv(A)                       # columns of A are the lattice vectors

    k  = _seio_first_int(_next())
    nD = _seio_first_int(_next())

    positions = Vector{Vector{Float64}}()
    labelsets = Vector{Vector{Int}}()
    for _ in 1:nD
        line = _next()
        toks = split(line)
        length(toks) >= 3 || throw(ArgumentError(
            "struct_enum.in: d-vector line needs 3 coordinates: '$line'"))
        frac = Ainv * parse.(Float64, toks[1:3])          # Cartesian → fractional
        labs = [parse(Int, t) for t in split(join(toks[4:end]), '/') if !isempty(t)]
        isempty(labs) && throw(ArgumentError(
            "struct_enum.in: no labels on d-vector line: '$line'"))
        any(>(k - 1), labs) && throw(ArgumentError(
            "struct_enum.in: inactive-site label encoding (label ≥ k=$k) is deferred in v0.3: '$line'"))
        push!(positions, frac)
        push!(labelsets, labs)
    end

    # Optional 'Equivalencies' keyword; otherwise this line is 'Nmin Nmax'.
    if startswith(uppercase(sig[i]), "E")
        throw(ArgumentError("struct_enum.in: explicit equivalencies are deferred in v0.3"))
    end

    nrange = _seio_try_ints(_next())
    (nrange === nothing && throw(ArgumentError("struct_enum.in: expected 'Nmin Nmax'")))
    length(nrange) >= 2 || throw(ArgumentError("struct_enum.in: expected 'Nmin Nmax'"))
    Nmin, Nmax = nrange[1], nrange[2]

    eps  = _seio_floats(_next())[1]

    mode = lowercase(split(_next())[1])
    startswith(mode, "full") || throw(ArgumentError(
        "struct_enum.in: only 'full' mode is supported ('part' is being sunset); got '$mode'"))

    # Optional concentration block: up to k lines of `num_low num_high denom`.
    conc = nothing
    bounds = Tuple{Rational{Int},Rational{Int}}[]
    while i <= length(sig)
        c = _seio_try_ints(sig[i])
        (c === nothing || length(c) < 3) && break
        lo, hi, den = c[1], c[2], c[3]
        push!(bounds, (lo // den, hi // den))
        i += 1
    end
    isempty(bounds) || (conc = ConcentrationRange(bounds))

    # Use the file's finite-precision parameter as the dset-matching tolerance,
    # matching how the Fortran enum.x uses `eps`. pymatgen writes coordinates with
    # ~1e-5 numerical noise (CIF / symmetry refinement) and sets `eps` accordingly
    # (its `enum_precision_parameter`, default ~1e-3); the ParentLattice default of
    # 1e-6 is too tight for that and makes symmetry-op dset matching fail. Floor at
    # 1e-6 so an unusually tight file `eps` can't regress clean-input cases.
    eps_dset  = max(eps, 1e-6)
    parent    = nD == 1 ? ParentLattice(A; eps_dset) : ParentLattice(A, positions; eps_dset)
    sites     = Sites([Site(positions[j], labelsets[j]) for j in 1:nD])
    selection = VolumeRange(Nmin:Nmax)

    # Heterogeneous multilattice (Regime C) requires an explicit concentration —
    # `enumerate` rejects unrestricted Regime C. An unrestricted struct_enum.in
    # therefore maps to the full-range box, matching the Fortran enum.x's
    # all-concentrations behavior. (Single-lattice and uniform multilattice
    # accept `nothing`; enumerate's :auto synthesizes the range for those.)
    if conc === nothing && nD > 1 && !all(l -> l == labelsets[1], labelsets)
        conc = ConcentrationRange([(0//1, 1//1) for _ in 1:k])
    end

    return (; title, latdim, parent, sites, selection, nmin = Nmin, nmax = Nmax,
            concentration = conc, eps, mode)
end

"""
    read_struct_enum_in(path::AbstractString)

Convenience: open `path` and parse it.
"""
read_struct_enum_in(path::AbstractString) = open(read_struct_enum_in, path)

"""
    write_struct_enum_out(io::IO, e::Enumeration; input, stdout_io::IO = stdout)

Write `e` in Fortran-`enum.x`-compatible `struct_enum.out` form to `io`, plus the
Fortran-style progress table (the `…RunTot` table pymatgen scans for the structure
count) to `stdout_io`. `input` is the NamedTuple from [`read_struct_enum_in`](@ref);
it supplies the header fields (title, eps, cell-size range, concentration).

Per-row layout is the 27-token form `makeStr.py` parses by position
(docs/notes/phase9-design.md §1c). The `Left transform` column is the SNF left
transform `U` from `snf(hnf)` — the same `U` `getPermG` used to order the labeling —
written row-major, matching `makeStr`'s `gIndx` with `g = U·[z1,z2,z3] mod S`.
"""
function write_struct_enum_out(io::IO, e::Enumeration{D}; input, stdout_io::IO = stdout) where D
    A  = basis(e.parent)
    sl = e.sites.list
    nD = length(sl)
    k  = maximum(maximum(s.allowed_labels) for s in sl) + 1

    # ---- header (templated on real Fortran enum.x output; makeStr parses by line/token position) ----
    println(io, " # <enumlib.jl drop-in enum.x></enumlib.jl>")
    println(io, input.title)
    println(io, input.latdim == 3 ? "bulk" : "surf")
    for j in 1:3
        println(io, @sprintf(" %14.8f %14.8f %14.8f        # a%d parent lattice vector",
                             A[1, j], A[2, j], A[3, j], j))
    end
    println(io, @sprintf(" %3d # Number of points in the multilattice", nD))
    for (idx, s) in enumerate(sl)
        cart = A * s.position
        labs = join(sort(collect(s.allowed_labels)), "/")
        println(io, @sprintf(" %14.8f %14.8f %14.8f        # d%02d d-vector, labels: %s",
                             cart[1], cart[2], cart[3], idx, labs))
    end
    println(io, " ", k, "-nary case")
    println(io, @sprintf(" %3d %3d # Starting and ending cell sizes for search",
                         input.nmin, input.nmax))
    println(io, @sprintf(" %.8E # Epsilon (finite precision parameter)", input.eps))
    if input.concentration === nothing
        println(io, "Concentration check:"); println(io, "    F")
    else
        println(io, "Concentration check:"); println(io, "    T")
        println(io, "Including only structures of which the concentration   of each atom is in the range:")
        for (t, (lo, hi)) in enumerate(input.concentration.bounds)
            println(io, @sprintf("Type %d:    %d/  %d --    %d/  %d", t,
                                 numerator(lo), denominator(lo), numerator(hi), denominator(hi)))
        end
    end
    println(io, "full list of labelings (including incomplete labelings) is used")
    println(io, "(Non)Equivalency list:  ", join(1:nD, " "))
    println(io, "start   #tot      HNF     Hdegn   labdegn   Totdegn   #size idx    pg    SNF             HNF                 Left transform                          labeling")

    # ---- data rows (27 tokens each) ----
    volcount = Dict{Int,Int}()
    hnf_index = Dict{Int,Int}(); next_hnf = 0
    for (strN, s) in enumerate(e.structures)
        sc = e.supercells[s.supercell_id]
        H  = sc.hnf.matrix
        n  = volume(sc.hnf)
        volcount[n] = get(volcount, n, 0) + 1
        if !haskey(hnf_index, s.supercell_id)
            next_hnf += 1; hnf_index[s.supercell_id] = next_hnf
        end
        _, U, _ = NormalForms.snf(H)                 # U = SNF left transform (= getPermG's L_snf)
        L = round.(Int, U)
        labdeg = s.orbit_size
        row = (strN, hnf_index[s.supercell_id], sc.hnf_degeneracy, labdeg,
               sc.hnf_degeneracy * labdeg, strN, n, sc.n_stabilizer_ops,
               sc.snf[1], sc.snf[2], sc.snf[3],
               H[1,1], H[2,1], H[2,2], H[3,1], H[3,2], H[3,3],
               L[1,1], L[1,2], L[1,3], L[2,1], L[2,2], L[2,3], L[3,1], L[3,2], L[3,3])
        println(io, join(row, " "), " ", join(Int.(to_labeling(s))))
    end

    # ---- stdout progress table: pymatgen reads the last (RunTot) token ----
    println(stdout_io, "Volume       CPU        #HNFs  #SNFs    #reduced    % dups      volTot      RunTot")
    runtot = 0
    for v in input.nmin:input.nmax
        vc = get(volcount, v, 0); runtot += vc
        println(stdout_io, @sprintf("%6d %12.4f %8d %6d %10d %10.4f %10d %10d",
                                    v, 0.0, 0, 0, vc, 0.0, vc, runtot))
    end
    return nothing
end
