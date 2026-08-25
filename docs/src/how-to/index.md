# How-to guides

Task-oriented recipes. Each page answers a focused **"I have X, I want Y"** question without re-teaching the package fundamentals — those live in the [Tutorials](../tutorials/index.md) (for learners) and the [Reference](../reference/index.md) (for the API).

## Build the inputs

- [Construct a parent lattice](construct-a-parent-lattice.md) — `ParentLattice` for Bravais and multilattice cases.
- [Describe substitution sites](describe-substitution-sites.md) — `Site`, `Sites`, allowed labels, and equivalence classes.
- [Select supercells](select-supercells.md) — `VolumeRange`, `RadiusBound`, `ExplicitHNFs`.

## Enumerate and count

- [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md) — the three `Concentration` constructors.
- [Sweep concentration ranges](sweep-concentration-ranges.md) — `ConcentrationRange` and the partition gate.
- [Count without enumerating](count-without-enumerating.md) — Pólya / Burnside counts via `count_inequivalent`, including heterogeneous sublattices.
- [Enumerate on a multilattice parent](enumerate-multilattice.md) — HCP, diamond, and other dset-bearing parents (HF 2009).
- [Specify concentration per sublattice](specify-per-sublattice-concentration.md) — `Concentration(sites, per_sublattice)` for Regime C / perovskite / Heusler.

## Tune and control

- [Pick an algorithm](pick-an-algorithm.md) — `:auto` vs explicit `:exhaustive` / `:multinomial` / `:recursive_stabilizer`.
- [Estimate the cost of an enumeration](estimate-cost.md) — `estimate_cost`, the resource-check kwargs, the `memory_budget` gate.
- [Handle super-periodicity](handle-super-periodicity.md) — when to set `include_superperiodic = true`.

## Hand off to DFT / MLIPs

- [Write POSCARs for DFT](write-poscars-for-dft.md) — `to_poscar`, `write_enumeration_archive`, `read_results`, `attach_results`.
