# Tutorials

Walkthroughs that teach you the package by doing real work end-to-end. Read them in order if you're new — each builds on the previous one.

1. **[Your first enumeration](01-first-enumeration.md)** — `ParentLattice`, `Sites`, `enumerate(...)` on a small `VolumeRange`. Inspect labelings and orbit sizes. ~5 minutes.
2. **[Enumerating at a fixed concentration](02-fixed-concentration.md)** — the three `Concentration` constructors, divisibility, `ConcentrationRange`, the `breakdown = true` count. ~10 minutes.
3. **[Generating a DFT/MLIP training database](03-dft-training-database.md)** — the DFT/MLIP roundtrip workflow: `write_enumeration_archive` → fill energies → `read_results` + `attach_results`. ~15 minutes.
4. **[Multilattice with per-sublattice concentration](04-multilattice-per-sublattice.md)** — Regime C: heterogeneous sublattices with distinct species, and the `Concentration(sites, per_sublattice)` constructor that states composition per dset position. ~10 minutes.

After the tutorials, the [How-to guides](../how-to/index.md) cover specific recipes (multilattice, cost estimation, super-periodicity, ...) and the [Reference](../reference/index.md) is the full API.
