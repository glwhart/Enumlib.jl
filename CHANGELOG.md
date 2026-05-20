# Changelog

All notable changes to Enumlib.jl. SemVer commitment begins with v0.2.0 (Phase 12 lock in `docs/notes/v0.2-plan.md`).

## v0.2.0 — 2026-05-19

First release with a complete `enumerate(...)` public API, four production algorithms with auto-dispatch, multilattice support (Regime A, B, C), POSCAR roundtrip for DFT/MLIP workflows, and a full Diátaxis documentation site.

### Added

- **Public API.**
  - `enumerate(parent, sites; supercells, concentration, algorithm, ...)` — the top-level entry point. Returns an `Enumeration{D, Vector{Int8}}` indexable like a flat list of `EnumeratedStructure`s.
  - `count_inequivalent(parent, sites; ...)` — Pólya / Burnside count without materializing structures. Optional `breakdown = true` returns per-volume / per-HNF / per-concentration aggregates as an `InequivalentCount{D}`.
  - `estimate_cost(parent, sites; ...)` — predicts memory and structure count before enumeration. Drives the built-in resource-check gate inside `enumerate(...)`.
- **Types.** `ParentLattice{D}`, `Sites{D}`, `Site{D}`, `HNF{D}`, `Supercell{D}`, `SupercellSelection` (`VolumeRange`, `RadiusBound`, `ExplicitHNFs`), `Enumeration{D, L}`, `EnumeratedStructure{D, L}`, `Concentration`, `ConcentrationRange`, `SymmetryOp{D}`, `EnumerationCostEstimate`. Convenience constructors `Sites(parent, labels)` for uniform and per-position cases.
- **Algorithms.**
  - `:exhaustive` (HF 2008) — unrestricted enumeration via the `BitVector(k^n)` bitmap.
  - `:multinomial` (HF 2012) — fixed-concentration via mixed-radix-hash crossing-out.
  - `:recursive_stabilizer` (Morgan-Hart 2017) — fixed-concentration tree, no bitmap, scales to high configurational freedom.
  - `:auto` — picks between `:multinomial` and `:recursive_stabilizer` from the predicted bitmap size against `memory_budget`; falls through to `:exhaustive` when no concentration is supplied.
- **Multilattice.** All three algorithms accept multilattice parents (`length(parent.dset) ≥ 2`). Regime A (single-site), Regime B (uniform `allowed_labels` across sublattices, HF 2009), and Regime C (heterogeneous `allowed_labels` — perovskite, half/full Heusler, wurtzite, zinc-blende families) all handled. Regime C currently uses `:recursive_stabilizer` only; `:multinomial_restricted` (chunk 6.5a) queued for v0.2.1.
- **POSCAR roundtrip (Phase 11).** `to_poscar(io, structure, parent, hnf; ...)` writes VASP-5+ format with a comment-line metadata header carrying an `energy_eV=` slot. `write_enumeration_archive(path, enumeration; ...)` produces a single `.tar.gz` bundle with a TOML manifest. `read_results(path)` parses energies from the filled-in POSCARs and returns `Dict{Int, Float64}`. `attach_results(enumeration, results)` merges energies back onto the enumeration for downstream cluster-expansion / MLIP fits.
- **Pólya / Burnside counting (chunk 7).** `Enumlib.Polya` submodule with `polya_count` and `aperiodic_orbit_count`. Möbius-inversion correction for aperiodic (non-super-periodic) orbits.
- **Enumeration resource check (chunk 7.5).** `EnumerationCostEstimate` + `EnumerationTooLargeError`. `enumerate(...; memory_budget, on_overflow)` refuses or warns before allocating an oversized bitmap; bypass with `skip_resource_check = true`.
- **Super-periodicity policy (chunk 6.2).** `include_superperiodic` kwarg on `enumerate`, `count_inequivalent`, and `estimate_cost`. Default is `false` (drop colorings fixed by a non-identity pure translation, matching HF 2008 step 5d). `true` returns the full Burnside orbit space.
- **Concentration ranges (chunk 6).** `ConcentrationRange` accepts per-species `(min, max)` fractional bounds. Internally decomposes to a list of integer-multiplicity partitions per supercell volume; `enumerate` runs the fixed-concentration algorithm once per partition. Partition-explosion guarded by `partition_threshold` (default 100, configurable with `on_partition_overflow = :warn / :ignore`).
- **Documentation (Phase 13).** Diátaxis site at `https://glwhart.github.io/Enumlib.jl/dev/`: tutorials (first enumeration, fixed-concentration, DFT training database), how-to recipes (multilattice, super-periodicity, resource-check, algorithm choice, etc.), reference (auto-generated from docstrings), and explanation (the four algorithms, dispatch, Pólya counting, super-periodicity policy). CI deploys to `gh-pages` on every push.
- **CI + coverage.** GitHub Actions matrix (Linux + macOS, Julia 1.11 + LTS). Codecov integration. Docs deploy + doctests in the same workflow.

### Changed (breaking — v0.3-prep items landed pre-v0.2.0)

- **`skip_preflight` → `skip_resource_check`.** Kwarg rename throughout `enumerate(...)` and the `EnumerationTooLargeError` constructor. The old name is *not* aliased; calls using `skip_preflight=` will error.
- **`EnumeratedStructure` field cleanup.** `labeling_degeneracy` removed (it was always equal to `orbit_size`, the genuine field added in R33). `hnf_degeneracy` removed from `EnumeratedStructure` and moved onto `Supercell` as `Supercell.hnf_degeneracy` — it's intrinsically a per-supercell property, not per-structure.
- **`Enumeration` show method.** "N structures" → "N configurations" to match the body-prose terminology settled on in Phase 13d.
- **Legacy radius-enumeration API removed.** `radiusEnumHNFs`, `getHNFColorings`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius`, `estimatedTime` and the `src/radiusEnumeration.jl` module gone. The chunk-4 `RadiusBound` supercell-selection path supersedes them.
- **Legacy `getPermG(h, fixingOps, LG::Vector{Matrix{Int}})` method removed.** The chunk-1-era pre-multilattice variant. The parent-aware `getPermG(h, fixingOps, parent::ParentLattice)` (R50.2b) is the only path now; single-lattice falls out as the degenerate case.

### Fixed

- **Chunk 6.5b/6.5c — Regime-C correctness.** Two bugs that affected multilattice enumeration with heterogeneous `allowed_labels`:
  - Super-periodicity check assumed `pG[1..n_total]` were translations; for multilattice the translation subgroup is `n_cells` long. Fixed by lifting super-periodicity to a single `_is_super_periodic` post-filter in `_enumerate_per_concentration` where `n_cells = volume(hnf)` is in scope. One implementation across both `:multinomial` and `:recursive_stabilizer`.
  - `_location_vector` ranked positions in the unfiltered set while `_descend!` ranked in the site-mask-filtered set; the two encodings disagreed at every depth where inactive sublattices interleaved with active ones, letting equivalent labelings through as canonical duplicates. Fixed by threading `site_mask` into `_location_vector`.
  - **Chunk 6.5c.** `_effective_parent(parent, sites)` sub-sets `parent.space_group` / `dset_perms` / `dset_shifts` to ops that respect the per-position `allowed_labels` equivalence classes. Closes a fragility in chunk 6.5b's per-supercell `_filter_perm_group_by_mask` workaround, which couldn't tell over-symmetric ops apart from legitimate ones after `getPermG`'s `unique!()` step had merged their site-permutations. Prerequisite for `:multinomial_restricted` (chunk 6.5a, v0.2.1).

### Deferred

- **Chunk 6.5a — `:multinomial_restricted` algorithm.** Bitmap-with-site-mask fixed-concentration enumeration for Regime C. Reserved kwarg today (errors with a clear message); the corpus testset asserts the gate fires. Land in v0.2.1.
- **Phase 9 — pymatgen / matsci / ASE integration.** Trigger condition unchanged: external production use of Enumlib + JuCE in DFT/MLIP workflows for several weeks, then schedule. Native Julia interop only useful for the subset of users writing Python interop — most users consuming POSCARs do their own pymatgen/ASE handling on the receiving end. Deferred to a later release.
