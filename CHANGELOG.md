# Changelog

All notable changes to Enumlib.jl. SemVer commitment begins with v0.2.0 (Phase 12 lock in `docs/notes/v0.2-plan.md`).

## v0.3.2 — 2026-05-27

### Added

- **Tutorial 04 — Multilattice with per-sublattice concentration.** Worked walkthrough of a half-Heusler `XYZ` enumeration (X=(Na,K) binary, Y=fixed-Mg, Z=fixed-F) using the per-sublattice `Concentration(sites, per_sublattice)` constructor end-to-end.
- **How-to: Specify concentration per sublattice.** Recipe page for the per-sublattice constructor, with perovskite ABO₃ as the canonical example, gotchas list, and a "when to reach for it" comparison table (flat vs per-sublattice across Regimes A/B/C).
- **`extra_per_structure` kwarg on `write_enumeration_archive`** for per-config manifest fields.

### Changed

- **Tarball mtimes preserved.** `write_enumeration_archive` now shells out to the system `tar` for archiving so file mtimes are preserved in the archive (Tar.jl deliberately zeroes them for reproducibility). For a collaborator-facing deliverable, human-readable timestamps are more useful and we don't rely on tarball-hash reproducibility.
- **Docs scrubbed of version / chunk / review identifiers.** Tutorials, how-tos, explanation pages, and public docstrings now describe the present-tense capability rather than referencing release timing (`v0.3`, `as of v0.3`, `chunk 6`, `R50.2a`, `Phase 7 §7.6`, etc.). Version history lives in this CHANGELOG and `docs/notes/`; user-facing docs read like documentation of what exists.

### Fixed

- **CI deploy workflow nudged.** A docs-deploy trigger commit (818ed8c, then cea99bf) was needed to push the accumulated v0.3 documentation to `gh-pages`, since every v0.3 development commit had been tagged to skip CI per standing preference. Subsequent pushes deploy automatically as usual.

## v0.3.1 — 2026-05-23

### Added

- **Per-sublattice `Concentration` constructor for Regime C.** `Concentration(sites, per_sublattice)` lets users state per-dset-position composition ratios ("1:1 on A, 1:1 on B, fixed on O") directly instead of computing the global flat-vector by hand. Each row of `per_sublattice` is normalized within its sublattice (so `[1, 1]` and `[1//2, 1//2]` are interchangeable), summed across positions, and divided by `ndset(parent)` to produce the canonical flat-vector form. Strictly additive — the flat-vector constructor remains canonical and the new method delegates to it. Useful for perovskite, half/full Heusler with distinct sublattice species, spinel, and HEAs on multi-sublattice parents.
- **Real-world resource-check gate-firing test (v0.2-polish #3).** FCC binary `:exhaustive` at n=30 predicts 2.6 × 10^9 structures and ~230 GiB peak — the default 8 GiB budget refuses without the `memory_budget = 1` lever the existing gate tests use. Paired negative-counterpart test at n=18 confirms a moderate enumeration passes.
- **HF 2012 Table-1 per-HNF anchors (v0.2-polish #2).** Locked per-HNF count vectors for FCC binary 2:2 at n=4 (`[1,1,1,1,1,0,0]`) and 4:4 at n=8 (a 20-element vector). Includes an `include_superperiodic = true` companion for n=4 that pins the super-periodic policy behavior.
- **Pólya orbit-count reference table (v0.2-polish #1).** `test/data/polya_reference.csv` vendors 40 reference rows across FCC/BCC/HCP/Diamond binary, FCC ternary, and FCC binary fixed-concentration — both aperiodic (default) and `include_superperiodic = true` counts, cross-checked against HF 2008 and HF 2012 references. `test/test_polya_reference.jl` asserts the current `count_inequivalent` matches every row. Catches silent drift in cycle-structure / Burnside / Möbius math that the algorithm-side tests might compensate for.
- **Bench Section 6.** `:multinomial` vs `:recursive_stabilizer` at FCC binary 50% from n=14 to n=18 — locks the v0.3.1 finding that the bitmap wins 2.2-5.2× for fixed concentration when it fits the budget (gap widening with n), validating the existing 80%-of-budget pivot in `_multinomial_bitmap_fits`. No threshold tune needed.

### Fixed

- **`estimate_cost` regression at small n.** v0.3.0's `:auto` synthesized a full-range `ConcentrationRange` and passed it through to `estimate_cost`, which then iterated per-partition for `count_inequivalent` — at FCC binary n=4 unrestricted that took 5.5 ms vs 2 ms in v0.2. Fix: thread the user's original `concentration` and `algorithm` kwargs into `estimate_cost` (it has its own `:auto` branch); inside, when `:auto` synthesizes the full-range concentration, use the original (`nothing`) for the `count_inequivalent` call. `partition_count` also reports 1 for the synthesized case (consistent with the user not having asked for a concentration constraint). Section 1 of the bench is now back in line with v0.2 numbers.

### Documented

- **Wurtzite Fortran-corpus divergence resolved.** `docs/notes/chunk6.5-design.md` §11.4 updated: Fortran enumlib is wrong, Enumlib.jl is correct. Wurtzite's 6₃ screw maps cation₁ ↔ cation₂ and anion₁ ↔ anion₂ — preserves label-class structure, so it's a legitimate symmetry of the labeled structure. Fortran dropping it is an artifact of not supporting per-position `allowed_labels` in the first place. Migration guide (Phase 13f / later release) will document the count discrepancy for users moving from Fortran.

## v0.3.0 — 2026-05-22

### Changed

- **`:auto` dispatch defaults to `:recursive_stabilizer` for unrestricted enumeration.** When `enumerate(...)` is called without a `concentration` kwarg, `:auto` now synthesizes a full-range `ConcentrationRange` internally and routes to the tree. Bench Section 5 (`bench/results-20260522.txt`) measured the tree at ~2-3× faster than `:exhaustive` and using ~half the memory across FCC binary/ternary and HCP at sizes n=4–12 (e.g., FCC binary n=12: 280 ms / 429 MiB vs 497 ms / 1.05 GiB). The structure *count* is invariant; the per-orbit *canonical representative* differs between the two algorithms, so `to_labeling(e[i])` will not be byte-identical across the upgrade — same orbits, different reps. `:exhaustive` remains available as an explicit `algorithm =` choice. Regime C unrestricted (heterogeneous sublattices without `concentration`) still errors at validation, regardless of algorithm. Answers the question logged in `docs/notes/v0.2-plan.md` line 445.
- **`EnumerationCostEstimate.partition_count` for unrestricted `:auto` runs.** Now reflects the partitions of the synthetic `ConcentrationRange` (e.g. 35 for FCC binary at n=4: 5 partitions × 7 HNFs), where previously it reported 1. The `notes` field carries a "synthetic full-range ConcentrationRange" line so users reading the estimate understand the dispatch.
- **Docs revised** — Algorithm overview, dispatch/cost-gate page, exhaustive-2008 page, recursive-stabilizer-2017 page, pick-an-algorithm how-to, estimate-cost how-to, tutorial 01, and the `enumerate(...)` docstring all updated to reflect the new default. The bench README's Section 5 entry documents the surprise result.

## v0.2.1 — 2026-05-19

### Added

- **Chunk 6.5a — `:multinomial_restricted` algorithm.** HF 2012 §A.1: the bitmap variant for heterogeneous sublattices (Regime C), implemented as a linear iteration over the full multinomial space with a lazy `site_mask` check per slot. Same bitmap layout and crossing-out machinery as `:multinomial`, plus the mask filter. Users opt in explicitly via `algorithm = :multinomial_restricted`; cross-validated against `:recursive_stabilizer` count-by-count on the zinc-blende / half-Heusler (Y=Z={2}) / perovskite corpus.

### Changed

- **`:auto` dispatch for Regime C still picks `:recursive_stabilizer`.** The linear-iteration `:multinomial_restricted` scales by the *full* multinomial space, not the valid subspace, so for sparse masks (the Heusler / wurtzite / perovskite family where most positions are inactive) the tree is much faster. A tree-walk variant that prunes at branching time — which would scale by valid subspace — is queued as a v0.3 perf-polish item. Until then, `:multinomial_restricted` is opt-in only.

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
