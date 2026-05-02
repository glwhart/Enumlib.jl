"""
    ParentLattice{D}

The geometric description of the parent multilattice for an enumeration: basis vectors `A`, dset `dset` (basis sites in fractional coordinates), and the cached `space_group` of the multilattice (rotation + fractional-translation pairs).

The dset captures the multilattice basis — for a Bravais lattice, length-1 (single site at the origin); for HCP, length-2; for perovskite ABO₃, length-5. **The dset is not required to contain the origin** — anchoring the dset where it makes physical sense (e.g., the inversion center for diamond) is a user choice and the enumeration math doesn't require origin-in-dset.

The space group is computed once at construction by calling `Spacey.spacegroup(c::Crystal)` with a uniform-species Crystal built from `(A, dset)`. Cached for ergonomics — call sites read `parent.space_group` without re-invoking Spacey.

The parametric `D` is the spatial dimension. Almost all uses are `D=3`; `D=2` is reserved for the future surface/2D extension. The constructor infers `D` from `size(A,1)`.
"""
struct ParentLattice{D}
    A::Matrix{Float64}                    # column j is the j-th basis vector (Cartesian)
    dset::Vector{Vector{Float64}}         # basis sites in fractional coords
    space_group::Vector{SymmetryOp{D}}    # multilattice space group (rotation + fractional translation)

    function ParentLattice{D}(A::AbstractMatrix, dset::AbstractVector{<:AbstractVector}) where D
        size(A) == (D, D) || throw(ArgumentError("basis matrix must be $D×$D, got $(size(A))"))
        # Allow either handedness — Hart-Forcade's algorithm is handedness-agnostic;
        # the existing test corpus uses a left-handed FCC primitive basis.
        abs(det(A)) > 1e-12 ||
            throw(ArgumentError("basis matrix must be non-singular (got |det| < 1e-12)"))
        all(length(d) == D for d in dset) ||
            throw(ArgumentError("all dset positions must have length $D"))
        all(all(0 ≤ x < 1 for x in d) for d in dset) ||
            throw(ArgumentError("all dset positions must be in [0,1)^$D"))

        Af = Matrix{Float64}(A)
        ds = [Vector{Float64}(d) for d in dset]

        # Build a Spacey Crystal with uniform "same-species" labels: this gives us the
        # multilattice space group (rotation + fractional translation pairs) rather than
        # just the Bravais point group. Positions in the dset are columns of `r`.
        r = hcat(ds...)
        crystal = Spacey.Crystal(Af, r, ones(Int, length(ds)); coords = :fractional)
        ops = Spacey.spacegroup(crystal)
        sg = SymmetryOp{D}[SymmetryOp{D}(op) for op in ops]

        new(Af, ds, sg)
    end
end

# Outer constructor: infer D from the basis matrix's first dimension.
ParentLattice(A::AbstractMatrix, dset::AbstractVector{<:AbstractVector}) =
    ParentLattice{size(A, 1)}(A, dset)

# Convenience: single-lattice (Bravais) constructor — dset is just the origin.
ParentLattice(A::AbstractMatrix) =
    ParentLattice(A, [zeros(Float64, size(A, 1))])

# Read-only accessors (mostly for downstream callers that want to be explicit).
basis(p::ParentLattice) = p.A
dset(p::ParentLattice) = p.dset
space_group(p::ParentLattice) = p.space_group
ndset(p::ParentLattice) = length(p.dset)

# Pretty printing — three-line summary (basis is bulky; show it on its own line)
function Base.show(io::IO, p::ParentLattice{D}) where D
    println(io, "ParentLattice{$D}")
    println(io, "  basis (columns): ", round.(p.A, digits=4))
    println(io, "  dset ($(ndset(p)) site$(ndset(p)==1 ? "" : "s")): ", p.dset)
    print(io,   "  space group: $(length(p.space_group)) operations")
end
