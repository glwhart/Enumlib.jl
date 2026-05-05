"""
    Supercell{D}

A symmetry-inequivalent supercell representative: an `HNF{D}` plus the cached SNF diagonal and the permutation group induced by the parent space-group operations that fix the superlattice. Carries the per-supercell data the labeling enumeration in chunk 5 will reuse across all colorings on this supercell.

## Cached fields

- `hnf` — the supercell-defining HNF.
- `snf` — diagonal of the Smith Normal Form decomposition of `hnf.matrix`. Length `D`, with `s_1 | s_2 | ... | s_D`. Used by the labeling enumeration to index supercell sites.
- `space_group_order` — number of `parent.space_group` operations whose action fixes the superlattice (the order of the stabilizer subgroup).
- `permutation_group` — permutations of the `n × n_D` supercell sites induced by the stabilizer's rotations composed with the supercell's translation group. This is what the labeling enumeration consults when crossing out symmetry-equivalent labelings.

## Construction

`Supercell(hnf::HNF{D}, parent::ParentLattice{D})` builds the SNF, finds the stabilizer subgroup of `parent.space_group`, and constructs the permutation group via the legacy `getPermG`. The permutation-group construction is cached at construction time (per chunk 2 review item 1) — small memory cost (~kB per supercell) for substantial savings during the labeling enumeration loop, which consults `permutation_group` once per labeling check.
"""
struct Supercell{D}
    hnf::HNF{D}
    snf::Vector{Int}
    space_group_order::Int
    permutation_group::Vector{Vector{Int}}

    function Supercell{D}(hnf::HNF{D}, parent::ParentLattice{D}) where D
        # Stabilizer subgroup: which parent ops fix the superlattice?
        LG = [op.R for op in parent.space_group]
        fixingOps = getFixingOps(hnf.matrix, LG)
        n_stabilizer = count(fixingOps)

        # Smith Normal Form diagonal — used by the labeling enumeration to index
        # supercell sites in the quotient group. NormalForms.snf is qualified to
        # be unambiguous; we don't want to extend or shadow that function.
        S, _, _ = NormalForms.snf(hnf.matrix)
        snf_diag = [S[i,i] for i in 1:D]

        # Permutation group: rotations of the stabilizer composed with the
        # supercell's translation group. Pure-integer arithmetic via the
        # lattice-coord legacy `getPermG`.
        perm_group = getPermG(hnf.matrix, fixingOps, LG)

        new(hnf, snf_diag, n_stabilizer, perm_group)
    end
end

# Outer constructor — infer D from the HNF's dimension.
Supercell(hnf::HNF{D}, parent::ParentLattice{D}) where D = Supercell{D}(hnf, parent)

# Field access is the public API for `Supercell`. Use:
#   `s.hnf`               — the HNF{D} matrix
#   `s.snf`               — the SNF diagonal (Vector{Int}, length D)
#   `s.space_group_order` — number of stabilizer ops
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
    a.space_group_order == b.space_group_order &&
    a.permutation_group == b.permutation_group
function Base.hash(s::Supercell, h::UInt)
    h = hash(s.hnf, h)
    h = hash(s.snf, h)
    h = hash(s.space_group_order, h)
    h = hash(s.permutation_group, h)
    return h
end

# Pretty printing — clear-and-complete per the working agreement.
function Base.show(io::IO, s::Supercell{D}) where D
    n = volume(s.hnf)
    rows = [join(s.hnf.matrix[i, :], " ") for i in 1:D]
    print(io, "Supercell{$D} (n = $n, |stabilizer| = $(s.space_group_order), ",
              "|perm group| = $(length(s.permutation_group)))\n")
    print(io, "  HNF: ", join(rows, " / "), "\n")
    print(io, "  SNF diag: ", s.snf)
end
