"""
    SymmetryOp{D}

A space-group operation in lattice coordinates: a rotation `R` (D×D integer matrix) plus a fractional translation `t` (length-D float vector). For a single Bravais lattice, all `t == 0`. For a multilattice (more than one position in the dset), the dset induces fractional translations (screws / glides) that must be tracked alongside the rotation.

`SymmetryOp{3}` is the type of every element of `ParentLattice{3}.space_group`. The parametric `D` is for forward compatibility with 2D enumerations (v0.3+).

Note: this is a thin wrapper around Spacey's `SpacegroupOp`, parametrized on the dimension `D` so downstream Enumlib code can specialize. The fractional translation `t` is canonicalized to `[0,1)^D` at construction (delegated to Spacey's `_canonicalize_τ`).
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

# Equality and hashing — exact comparison; the `t` canonicalization happens upstream.
Base.:(==)(a::SymmetryOp{D}, b::SymmetryOp{D}) where D = a.R == b.R && a.t == b.t
Base.hash(op::SymmetryOp, h::UInt) = hash(op.R, hash(op.t, h))
