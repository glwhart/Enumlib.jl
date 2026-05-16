# Glossary

Compact reference for terms used across the documentation, with pointers to where each one is unpacked in depth.

**Bravais lattice.** A periodic point lattice with one site per primitive cell. `ParentLattice(A)` with no dset argument (or a single-element dset) is Bravais. Contrast with **multilattice**.

**Coloring.** A labeling of supercell sites with species indices (`{0, 1, ..., k-1}`). The output of `enumerate(...)` is the set of symmetry-inequivalent colorings. Synonym: **labeling**.

**Concentration.** The composition of a labeling: the fraction (or count) of each species. See [`Concentration`](@ref) and the [concentration-and-multiplicity](concentration-and-multiplicity.md) explanation.

**Derivative structure.** A symmetry-inequivalent decoration of a supercell — what Enumlib enumerates. From Hart & Forcade 2008.

**dset (basis sites).** For a multilattice, the list of basis-site fractional coordinates in the primitive cell. For FCC, `dset = [(0,0,0)]` (single site). For HCP, `dset = [(0,0,0), (1/3, 2/3, 1/2)]` (two sites).

**Enumeration.** The full set of symmetry-inequivalent derivative structures for a given (parent, sites, supercell selection) tuple. Returned by `enumerate(...)`; see [`Enumeration`](@ref).

**Exhaustive algorithm.** The chunk-5 default. Iterates `k^n` colorings on each supercell, hashes each into the orbit-canonical representative, emits one structure per orbit. Best when `k^n` is small. See [exhaustive-2008](exhaustive-2008.md).

**HF 2008.** Hart & Forcade, *Algorithm for generating derivative structures*, PRB 77, 224115 (2008). The original derivative-structure enumeration algorithm — single-lattice case.

**HF 2009.** Hart & Forcade, *Generating derivative structures from multilattices*, PRB 80, 014120 (2009). The multilattice extension. Enumlib's R50.2 series implemented this.

**HF 2012.** Hart, Nelson, & Forcade, *Generating derivative structures at a fixed concentration*, Comp. Mat. Sci. 59, 101 (2012). Adds the multinomial mixed-radix hash for concentration-restricted enumeration.

**HNF (Hermite Normal Form).** An integer-matrix canonical form for a supercell relative to its parent. Each HNF uniquely identifies a supercell shape up to parent symmetry. See [`HNF`](@ref).

**Labeling.** Synonym for **coloring**. The `Vector{Int8}` field carried by each `EnumeratedStructure`.

**Multilattice.** A parent lattice with two or more dset sites per primitive cell (HCP, diamond, perovskite). Contrast with **Bravais lattice** (single dset site).

**Multinomial algorithm.** The chunk-6 algorithm for concentration-restricted enumeration. Iterates only colorings matching the target concentration via mixed-radix indexing. Best when the multinomial coefficient is much smaller than `k^n`. See [multinomial-2012](multinomial-2012.md).

**Orbit.** An equivalence class of colorings under the supercell's permutation group. Each orbit corresponds to one symmetry-inequivalent derivative structure. `orbit_size` is the number of colorings in an orbit (also called *multiplicity* or *degeneracy*).

**ParentLattice.** Geometric description of the parent multilattice: basis `A`, dset, and cached space group. See [`ParentLattice`](@ref).

**Permutation group.** For a supercell, the group of position permutations induced by the parent symmetry operations that fix the supercell's lattice (rotational stabilizer) composed with the supercell's translation subgroup. The enumeration crosses out colorings under this group.

**Pólya count.** The Burnside-averaged count of orbits of a coloring space under the permutation group. Computed without enumerating. See [polya-counting](polya-counting.md).

**Recursive-stabilizer algorithm.** The chunk-8 algorithm of Morgan & Hart 2017. Tree-walk over partial colorings; never materializes the full hash table. Best when memory dominates over CPU. See [recursive-stabilizer-2017](recursive-stabilizer-2017.md).

**Sites.** A `Sites` object declares which dset positions can be substituted and which species (`allowed_labels`) are allowed at each. Equivalence-class ties between sites are also tracked. See [`Sites`](@ref) and [the substitution-sites how-to](../how-to/describe-substitution-sites.md).

**SNF (Smith Normal Form).** Diagonal canonical form `diag(d_1, ..., d_D)` of an integer matrix with `d_i | d_{i+1}`. The SNF of an HNF gives the supercell's quotient-group structure `Z/d_1 × ... × Z/d_D` — used to index supercell sites.

**Stabilizer subgroup.** For a supercell, the subgroup of the parent space group whose action fixes the superlattice as a set. The supercell **permutation group** is built from the stabilizer's rotations composed with the supercell's translation subgroup.

**Super-periodic structure.** A coloring on a volume-`m` supercell that is also a valid coloring on some volume-`m'` supercell with `m' | m`, `m' < m`. By default Enumlib drops these to avoid double-counting across a volume sweep. See [super-periodicity](super-periodicity.md).

**Supercell.** A larger cell built on top of the parent lattice as `A_super = A_parent · h` for some integer matrix `h`. The HNF is the canonical representative of each shape class. See [`Supercell`](@ref).

**Supercell selection.** A `VolumeRange`, `RadiusBound`, or `ExplicitHNFs` value passed as the `supercells = ...` kwarg to `enumerate(...)`. Determines which HNFs are enumerated over. See [the supercell-selection how-to](../how-to/select-supercells.md).
