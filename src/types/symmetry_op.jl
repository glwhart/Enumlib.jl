"""
    SymmetryOp{D}

A space-group operation in lattice coordinates: a rotation `R` (D×D integer matrix) plus a fractional translation `t` (length-D float vector). For a single Bravais lattice, all `t == 0`. For a multilattice (more than one position in the dset), the dset induces fractional translations (screws / glides) that must be tracked alongside the rotation.

`SymmetryOp{3}` is the type of every element of `ParentLattice{3}.space_group`. The parametric `D` is for forward compatibility with 2D enumerations (v0.3+). See `docs/notes/v0.2-plan.md` (Type-system glossary) for the meaning of "thin wrapper", "specialize", and parametric types.

Thin wrapper around Spacey's `SpacegroupOp`. The fractional translation `t` is canonicalized to `[0,1)^D` at construction (delegated to `Spacey._canonicalize_τ`); we don't need to wrap again.
"""
struct SymmetryOp{D}
    R::Matrix{Int}                   # lattice-coord rotation/reflection (D×D)
    t::Vector{Float64}               # fractional translation in [0,1)^D

    function SymmetryOp{D}(R::AbstractMatrix{<:Integer}, t::AbstractVector{<:Real}) where D
        size(R) == (D, D) || throw(ArgumentError("rotation must be $D×$D, got $(size(R))"))
        length(t) == D    || throw(ArgumentError("translation must have length $D, got $(length(t))"))
        new(Matrix{Int}(R), Vector{Float64}(t))
    end
end

# Construct from Spacey's SpacegroupOp (which has the same shape but no D parameter).
SymmetryOp{D}(op::Spacey.SpacegroupOp) where D = SymmetryOp{D}(op.R, op.τ)

# `==` and `hash` are paired by Julia convention so hash-based collections (Dict, Set,
# unique) work correctly on `SymmetryOp`s. Both walk the same fields (R, t). The
# `where D` constraint forces both arguments to have matching dimension; cross-D
# comparisons fall through to Base's default (returns false). See v0.2-plan.md
# glossary for "pairing rule" and "where D".
Base.:(==)(a::SymmetryOp{D}, b::SymmetryOp{D}) where D = a.R == b.R && a.t == b.t
Base.hash(op::SymmetryOp, h::UInt) = hash(op.R, hash(op.t, h))
