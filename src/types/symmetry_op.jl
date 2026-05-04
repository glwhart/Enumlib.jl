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
#
# On the D parameter (re-explained for clarity, since this is a common point of
# confusion): D is an integer (3 for 3D crystals, 2 for 2D). It does NOT take the
# value true/false. The function BODY (`a.R == b.R && a.t == b.t`) returns a
# boolean — that's the *result* of the equality check. But D itself, the type
# parameter, is always an integer dimension. So "D" and "the function's return
# value" are two unrelated things on the same line.
#
# A walkthrough: when you call `op_a == op_b` where both have type
# `SymmetryOp{3}`, Julia's dispatcher resolves `D = 3` (because both arguments
# are `SymmetryOp{3}`) and runs the body, returning `true` or `false` based on
# whether their R's and t's match. The `D = 3` binding is invisible at the call
# site; you never see it. If the user later builds a `SymmetryOp{2}` (in some
# v0.3 2D extension), `D` resolves to `2` for that call. D never sees true/false.
Base.:(==)(a::SymmetryOp{D}, b::SymmetryOp{D}) where D = a.R == b.R && a.t == b.t
# IMPORTANT: must qualify `Base.hash` inside the body. There is a local `hash(mul, c)`
# defined later in `Enumlib.jl` that would shadow the unqualified name and break
# the hash chain. Tracked as a v0.2 landmine — that function should be renamed
# during chunk 5 cleanup (it's only used in `getUniqueColorings`).
Base.hash(op::SymmetryOp, h::UInt) = Base.hash(op.R, Base.hash(op.t, h))
