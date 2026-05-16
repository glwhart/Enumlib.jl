# Construct a parent lattice

Build a [`ParentLattice`](@ref) from a primitive basis matrix (Bravais) or a basis + dset (multilattice).

## Setup

```jldoctest construct_parent
julia> using Enumlib
```

## Bravais lattice (single-site)

Pass the basis matrix alone. Enumlib uses **column-major** basis matrices: column `j` of `A` is the `j`-th lattice vector in Cartesian coordinates.

```jldoctest construct_parent
julia> A_fcc = [0.0 0.5 0.5;
                0.5 0.0 0.5;
                0.5 0.5 0.0];

julia> p = ParentLattice(A_fcc); # If not specified, one atomic site in the dset, at (0,0,0) 

julia> ndset(p)                  # one dset position, at the origin
1

julia> length(space_group(p))    # 48 ops (Pm-3m point group of FCC)
48
```

## Multilattice (HCP, diamond, perovskite, …)

Pass the basis plus a dset of basis-site fractional positions:

```jldoctest construct_parent
julia> A_hcp = [1.0 -0.5 0.0;
                0.0 sqrt(3)/2 0.0;
                0.0 0.0 sqrt(8/3)];

julia> dset_hcp = [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]];

julia> p_hcp = ParentLattice(A_hcp, dset_hcp);

julia> ndset(p_hcp) # The dset has two atomic sites
2

julia> n_nonzero_translations(p_hcp)   # P6_3/mmc has 12 screw ops of 24
12
```

## What gets canonicalized silently

1. Each dset position is adjusted to be in between 0 and 1: wrapped into `[0,1)^D` via `mod(·, 1)`.
2. For lattices with only one atomic site ("Bravais" lattices), the lone dset entry is automatically shifted to the origin so the space group doesn't carry "artificial" translations from the user's choice of origin.
3. Bases with Hadamard ratio `|det(A)| / prod(‖aⱼ‖) ≤ 1e-12` are rejected as *flat*, not defining a lattice in 3D. The Hadamard ration is a scale-free singularity check that works whether you express positions in Ångströms, nm, Bohr, or anything else.

## See also

- Reference: [`ParentLattice`](@ref), [`basis`](@ref), [`dset`](@ref), [`space_group`](@ref), [`n_nonzero_translations`](@ref).
- How-to: [Describe substitution sites](describe-substitution-sites.md) — the next step.
- Explanation: [Glossary entry on the Hadamard ratio](../explanation/glossary.md).
