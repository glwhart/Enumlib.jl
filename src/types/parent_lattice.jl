"""
    ParentLattice{D}

The geometric description of the parent multilattice for an enumeration: basis vectors `A`, dset `dset` (basis sites in fractional coordinates), and the cached `space_group` of the multilattice (rotation + fractional-translation pairs).

The dset captures the multilattice basis — for a Bravais lattice, length-1; for HCP, length-2; for perovskite ABO₃, length-5. **The dset is not required to contain the origin** — placing the origin where it makes physical sense (e.g., at the inversion center for diamond) is a user choice and the enumeration math doesn't require origin-in-dset.

## What the constructor canonicalizes silently

1. **Periodic-coordinate wrap.** Each dset position is folded into `[0,1)^D` via `mod(., 1)`. So `[1.5, -0.5, 0.5]` becomes `[0.5, 0.5, 0.5]` — mathematically equivalent under lattice translation. (Matches the convention in ASE / pymatgen.)
2. **Bravais origin shift (only when `length(dset) == 1`).** A single-site dset has a degenerate choice of origin — there's no geometric structure picking one position over another. We shift the lone dset entry to the origin, so the resulting `space_group` doesn't carry artifact `t`-translations introduced by the user's choice of origin. **For multilattice (`length(dset) ≥ 2`) we never shift** — the relative positions encode physically meaningful structure (placing the origin at diamond's inversion center is the canonical example).

## Numerical scale check

The basis is rejected as singular if `|det(A)| / prod(‖aⱼ‖) ≤ 1e-12`. This is the **Hadamard ratio** — `1` for orthogonal columns, `0` for linearly dependent columns, dimensionless and therefore unit-independent. So the check works whether the user works in Ångströms, nm, or meters; what it catches is *geometric* near-singularity, not absolute determinant magnitude.

## Space group

Computed once at construction by calling `Spacey.spacegroup(c::Crystal)` with a uniform-species Crystal built from `(A, dset)`. Cached for ergonomics — call sites read `parent.space_group` without re-invoking Spacey.

The parametric `D` is the spatial dimension. Almost all uses are `D=3`; `D=2` is reserved for the future surface/2D extension. The constructor infers `D` from `size(A,1)`.
"""
struct ParentLattice{D}
    A::Matrix{Float64}                    # column j is the j-th basis vector (Cartesian)
    dset::Vector{Vector{Float64}}         # basis sites in fractional coords (canonicalized to [0,1)^D)
    space_group::Vector{SymmetryOp{D}}    # multilattice space group (rotation + fractional translation)

    function ParentLattice{D}(A::AbstractMatrix, dset::AbstractVector{<:AbstractVector}) where D
        # ---- Shape checks ----
        size(A) == (D, D) ||
            throw(ArgumentError("basis matrix must be $D×$D, got $(size(A))"))
        all(length(d) == D for d in dset) ||
            throw(ArgumentError("all dset positions must have length $D"))
        isempty(dset) &&
            throw(ArgumentError("dset must be non-empty (at least one site)"))

        # ---- Geometric singularity check (Hadamard ratio) ----
        # |det(A)| / prod(‖aⱼ‖) is dimensionless: it equals 1 for orthogonal columns
        # and 0 for linearly dependent columns. The 1e-12 threshold catches numerical
        # singularity (collinear/coplanar columns to within float precision) regardless
        # of the user's unit choice.
        col_norms = (norm(view(A, :, j)) for j in 1:D)
        any(iszero, col_norms) &&
            throw(ArgumentError("basis matrix has a zero-length column"))
        scale = prod(norm(view(A, :, j)) for j in 1:D)
        hadamard_ratio = abs(det(A)) / scale
        hadamard_ratio > 1e-12 ||
            throw(ArgumentError("basis matrix is near-singular (Hadamard ratio = $hadamard_ratio)"))

        Af = Matrix{Float64}(A)

        # ---- Canonicalize the dset ----
        # 1. Wrap each entry into [0,1)^D.
        ds = [Vector{Float64}(mod.(d, 1.0)) for d in dset]
        # 2. Bravais case only: shift the lone dset entry to the origin so the resulting
        #    space group doesn't carry artifact translations from the user's choice of
        #    origin. For multilattice (length ≥ 2), the relative positions are physically
        #    meaningful and we leave the user's choice of origin untouched.
        if length(ds) == 1
            ds[1] = zeros(Float64, D)
        end

        # ---- Compute and cache the space group ----
        # Build a Spacey Crystal with uniform "same-species" labels so spacegroup gives
        # us the multilattice space group (rotation + fractional translation pairs)
        # rather than just the Bravais point group.
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

# Read-only accessors. Useful both for downstream callers that want to be explicit
# (rather than reaching into struct fields) and for future-proofing — if we ever
# change the internal representation, the accessor stays stable.
basis(p::ParentLattice) = p.A
dset(p::ParentLattice) = p.dset
space_group(p::ParentLattice) = p.space_group
ndset(p::ParentLattice) = length(p.dset)

# Count operations whose fractional translation is non-zero — useful for distinguishing
# symmorphic (all `t = 0`) from non-symmorphic (some `t ≠ 0`) space groups.
n_nonzero_translations(p::ParentLattice; tol::Real = 1e-9) =
    count(op -> any(abs(t) > tol for t in op.t), p.space_group)

# Pretty printing — three-line summary (basis is bulky; show it on its own line).
function Base.show(io::IO, p::ParentLattice{D}) where D
    println(io, "ParentLattice{$D}")
    println(io, "  basis (columns): ", round.(p.A, digits=4))
    println(io, "  dset ($(ndset(p)) site$(ndset(p)==1 ? "" : "s")): ", p.dset)
    print(io,   "  space group: $(length(p.space_group)) operations ",
                "($(n_nonzero_translations(p)) non-symmorphic)")
end
