"""
    HNF{D}

A Hermite Normal Form matrix in `D` dimensions: a lower-triangular integer matrix with positive diagonal entries and sub-diagonal entries reduced into `[0, m[i,i])`. The determinant `n = ∏ m[i,i]` is the supercell index — the number of parent cells fitting inside the supercell `B = parent.A * h.matrix`.

Construction validates the HNF form (lower-triangular, positive diagonal, sub-diagonal range). Once built, an `HNF{D}` is guaranteed to satisfy the form; downstream code can rely on that without re-checking.

`HNF{D}` is parametric on the spatial dimension `D` for forward compatibility with 2D enumeration (v0.3+). Almost all uses are `D=3`; the constructor infers `D` from `size(matrix, 1)`.
"""
struct HNF{D}
    matrix::Matrix{Int}    # D×D, lower-triangular, validated at construction

    function HNF{D}(m::AbstractMatrix{<:Integer}) where D
        size(m) == (D, D) ||
            throw(ArgumentError("HNF must be $D×$D, got $(size(m))"))
        # Lower-triangular: all super-diagonal entries must be zero.
        for j in 1:D, i in 1:j-1
            iszero(m[i,j]) ||
                throw(ArgumentError("HNF must be lower-triangular; m[$i,$j] = $(m[i,j])"))
        end
        # Positive diagonal entries.
        for i in 1:D
            m[i,i] > 0 ||
                throw(ArgumentError("HNF diagonal m[$i,$i] = $(m[i,i]) must be positive"))
        end
        # Sub-diagonal entries reduced into [0, m[i,i]).
        for i in 1:D, j in 1:i-1
            d = m[i,i]
            (0 <= m[i,j] < d) ||
                throw(ArgumentError("HNF[$i,$j] = $(m[i,j]) out of range [0, $(d-1)]"))
        end
        new(Matrix{Int}(m))
    end
end

# Outer constructor: infer D from the first dimension of the matrix.
HNF(m::AbstractMatrix{<:Integer}) = HNF{size(m, 1)}(m)

"""
    volume(h::HNF)

The supercell volume / index — the number of parent cells fitting inside the supercell defined by `h`. Equals the product of the diagonal entries (since `h.matrix` is lower-triangular, this is also its determinant).
"""
volume(h::HNF{D}) where D = prod(h.matrix[i,i] for i in 1:D)

# Overload LinearAlgebra.det (det lives there, not in Base). Returns Int (exact;
# no float rounding) since the diagonal product is the determinant for any
# lower-triangular integer matrix. Slightly faster than the general LU-based det
# but the win is nominal — the readability is the main reason.
LinearAlgebra.det(h::HNF) = volume(h)

# Equality and hashing — value semantics across structurally-equal HNFs with
# matching D. Same pairing-rule pattern as SymmetryOp / Site.
Base.:(==)(a::HNF{D}, b::HNF{D}) where D = a.matrix == b.matrix
Base.hash(h::HNF, hash_seed::UInt) = hash(h.matrix, hash_seed)

# Pretty printing — explicit row-by-row with slash separators. More compact than
# Julia's default matrix display, easier to scan inline in REPL output.
function Base.show(io::IO, h::HNF{D}) where D
    rows = [join(h.matrix[i, :], " ") for i in 1:D]
    print(io, "HNF{$D} (volume $(volume(h)))  ", join(rows, " / "))
end


# ------------------------------------------------------------------------------
# getSymInequivHNFs(n, parent::ParentLattice{D})
#
# Wrapper around the legacy pure-integer `getSymInequivHNFs(d, LG)`. Extracts the
# lattice-coord rotations from `parent.space_group` and delegates to the legacy
# implementation. Returns `Vector{HNF{D}}` for the new public API.
#
# Note on multilattice symmetry: HNF equivalence (Hart-Forcade 2008 step 2) is
#     H_2 ≅ H_1  iff  ∃ R in the lattice point group such that
#     H_1 R H_2^{-1} is unimodular.
# This involves only rotations; fractional translations from the multilattice's
# space group don't affect HNF equivalence (they affect the *labeling* enumeration
# in chunks 5+, not the supercell-shape enumeration here).
# ------------------------------------------------------------------------------

"""
    getSymInequivHNFs(n::Int, parent::ParentLattice{D}) where D

Return the symmetry-inequivalent HNFs of supercell volume `n` under the action of `parent`'s lattice point group. One representative HNF per equivalence class.

This is the chunk-3 wrapper around the pure-integer legacy `getSymInequivHNFs(d, LG)`. Extracts the rotation parts of `parent.space_group` (fractional translations don't affect HNF equivalence) and returns `Vector{HNF{D}}`.
"""
function getSymInequivHNFs(n::Int, parent::ParentLattice{D}) where D
    LG = lattice_rotations(parent)
    legacy_hnfs = getSymInequivHNFs(n, LG)   # legacy lattice-coord; returns Vector{Matrix{Int}}
    return [HNF{D}(m) for m in legacy_hnfs]
end
