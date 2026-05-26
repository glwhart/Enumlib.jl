"""
    Supercell{D}

A symmetry-inequivalent supercell representative: an `HNF{D}` plus the cached SNF diagonal and the permutation group induced by the parent space-group operations that fix the superlattice. Carries the per-supercell data the labeling enumeration reuses across all colorings on this supercell.

## Cached fields

- `hnf` — the supercell-defining HNF.
- `snf` — diagonal of the Smith Normal Form decomposition of `hnf.matrix`. Length `D`, with `s_1 | s_2 | ... | s_D`. Used by the labeling enumeration to index supercell sites.
- `n_stabilizer_ops` — number of `parent.space_group` operations whose action fixes the superlattice (the order of the stabilizer subgroup).
- `permutation_group` — permutations of the `n × n_D` supercell sites induced by the stabilizer's rotations composed with the supercell's translation group. This is what the labeling enumeration consults when crossing out symmetry-equivalent labelings.
- `hnf_degeneracy` — the size of this supercell's parent-point-group orbit on the set of volume-`n` HNFs. Mirrors the Fortran enumlib's `hnf_degen`. Diagnostic-grade.

## Construction

`Supercell(hnf::HNF{D}, parent::ParentLattice{D})` builds the SNF, finds the stabilizer subgroup of `parent.space_group`, and constructs the permutation group via `getPermG`. The permutation-group construction is cached at construction time — small memory cost (~kB per supercell) for substantial savings during the labeling enumeration loop, which consults `permutation_group` once per labeling check.

`hnf_degeneracy` is computed on demand by counting the HNF's parent-point-group orbit at the given volume. For batch construction inside `enumerate(...)`, the degeneracy is precomputed via `getSymInequivHNFs_with_degeneracies` and passed in to skip the recomputation: `Supercell(hnf, parent; hnf_degeneracy = precomputed)`.

# Examples
Building one of FCC's two symmetry-inequivalent volume-2 supercells:
```jldoctest
julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);

julia> sc = Supercell(enumerate_hnfs(VolumeRange(2:2), p)[1], p)
Supercell{3} (n = 2, |stabilizer| = 12, |perm group| = 2, hnf_degeneracy = 4)
  HNF: 1 0 0 / 0 1 0 / 0 0 2
  SNF diag: [1, 1, 2]

julia> volume(sc.hnf)
2

julia> sc.snf
3-element Vector{Int64}:
 1
 1
 2
```
"""
struct Supercell{D}
    hnf::HNF{D}
    snf::Vector{Int}
    n_stabilizer_ops::Int
    permutation_group::Vector{Vector{Int}}
    hnf_degeneracy::Int

    function Supercell{D}(hnf::HNF{D}, parent::ParentLattice{D};
                          hnf_degeneracy::Union{Int, Nothing} = nothing) where D
        # Stabilizer subgroup: which parent ops fix the superlattice?
        # `lattice_rotations` projects out just the rotation parts of
        # parent.space_group. HNF symmetry equivalence is rotation-only; the
        # fractional translations (chunk 1's multilattice space-group machinery)
        # don't enter here — they affect the labeling enumeration in chunk 5+.
        LG = lattice_rotations(parent)
        fixingOps = getFixingOps(hnf.matrix, LG)
        n_stabilizer = count(fixingOps)

        # Smith Normal Form diagonal — used by the labeling enumeration to index
        # supercell sites in the quotient group. NormalForms.snf is qualified to
        # be unambiguous; we don't want to extend or shadow that function.
        S, _, _ = NormalForms.snf(hnf.matrix)
        snf_diag = [S[i,i] for i in 1:D]

        # Permutation group: rotations of the stabilizer composed with the
        # supercell's translation group. R50.2b (2026-05-15) switches to the
        # parent-aware `getPermG` method which builds the correct n_D·n-site
        # permutation group for multilattice parents using the dset-permutation
        # precompute (parent.dset_perms / dset_shifts, populated in R50.2a).
        # Single-lattice (n_D = 1) falls out as the degenerate case — output
        # is byte-for-byte identical to the legacy method.
        perm_group = getPermG(hnf.matrix, fixingOps, parent)

        # HNF-class degeneracy. If not provided by a batch caller (e.g.
        # enumerate's internal getSymInequivHNFs_with_degeneracies plumbing),
        # compute it on demand from `getAllHNFs(n) ∩ orbit under LG`.
        deg = hnf_degeneracy === nothing ?
              _compute_hnf_degeneracy(hnf, LG) : hnf_degeneracy
        deg >= 1 ||
            throw(ArgumentError("hnf_degeneracy must be ≥ 1, got $deg"))

        new(hnf, snf_diag, n_stabilizer, perm_group, deg)
    end
end

# Compute the size of `hnf`'s parent-point-group orbit on the set of
# volume-`vol(hnf)` HNFs. Used when Supercell is constructed directly without
# precomputed degeneracy info.
function _compute_hnf_degeneracy(hnf::HNF{D}, LG::Vector{Matrix{Int}}) where D
    target = hnf.matrix
    return count(other -> basesAreEquiv(other, target, LG),
                 getAllHNFs(volume(hnf)))
end

# Outer constructor — infer D from the HNF's dimension.
Supercell(hnf::HNF{D}, parent::ParentLattice{D};
          hnf_degeneracy::Union{Int, Nothing} = nothing) where D =
    Supercell{D}(hnf, parent; hnf_degeneracy)

# Field access is the public API for `Supercell`. Use:
#   `s.hnf`               — the HNF{D} matrix
#   `s.snf`               — the SNF diagonal (Vector{Int}, length D)
#   `s.n_stabilizer_ops` — number of stabilizer ops
#   `s.permutation_group` — Vector{Vector{Int}} of supercell-site permutations
# We deliberately don't define `snf(s::Supercell)` etc. as accessor functions —
# `snf` would shadow `NormalForms.snf` inside the Enumlib namespace (same
# family of bug as chunk 2.1's `hash` shadow). Field access is more idiomatic
# Julia anyway for stable struct fields; "accessor functions for getter-style
# access" is more Java than Julia.

# Equality and hashing — value semantics. Two supercells with the same HNF and
# same parent space group will produce identical SNF / stabilizer / perm group;
# we hash and compare on the cached fields so cache lookups (Set{Supercell},
# Dict{Supercell, ...}) work.
Base.:(==)(a::Supercell{D}, b::Supercell{D}) where D =
    a.hnf == b.hnf && a.snf == b.snf &&
    a.n_stabilizer_ops == b.n_stabilizer_ops &&
    a.permutation_group == b.permutation_group &&
    a.hnf_degeneracy == b.hnf_degeneracy
function Base.hash(s::Supercell, h::UInt)
    h = hash(s.hnf, h)
    h = hash(s.snf, h)
    h = hash(s.n_stabilizer_ops, h)
    h = hash(s.permutation_group, h)
    h = hash(s.hnf_degeneracy, h)
    return h
end

# Pretty printing — clear-and-complete per the working agreement.
function Base.show(io::IO, s::Supercell{D}) where D
    n = volume(s.hnf)
    rows = [join(s.hnf.matrix[i, :], " ") for i in 1:D]
    print(io, "Supercell{$D} (n = $n, |stabilizer| = $(s.n_stabilizer_ops), ",
              "|perm group| = $(length(s.permutation_group)), ",
              "hnf_degeneracy = $(s.hnf_degeneracy))\n")
    print(io, "  HNF: ", join(rows, " / "), "\n")
    print(io, "  SNF diag: ", s.snf)
end
