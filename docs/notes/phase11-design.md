# Phase 11 — POSCAR writer + DFT/MLIP roundtrip glue (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `v0.2-plan.md` Phase 11 (locked decisions A1–A3, B, Q1–Q8); `research.md` §2.10 (Fortran I/O; what we are and aren't replacing); `papers/` for paper-specific test cases. VASP POSCAR format spec is the authoritative source for line-by-line layout.

**Goal:** ship the *first user-facing application* of Enumlib.jl — the generate-then-share-then-fit pipeline for cluster-expansion training-database generation. After Phase 11: an Enumlib user can call `enumerate(...)` → `write_enumeration(dir, ...)` → hand the directory to a collaborator → the collaborator runs DFT and fills in the `energy_eV=` slot in each POSCAR's header → user runs `read_results(dir)` and `attach_results(...)` → enriched `Enumeration` ready for CE fitting via JuCE.jl.

This is a **substantial chunk** (~300 lines source + ~50 tests). Splitting into four sub-chunks (11a–11d), each its own focused diff with review pass.

---

## Background — what gets written and read

The contract between Enumlib and the calculator (the human or workflow doing DFT/MLIP):

1. **Enumlib writes** a directory of POSCARs + a manifest. Each POSCAR's *line 1* is a comment we control:
   ```
   # enumlib_id=42 hnf=14 concentration=15:17 super_periodic=false energy_eV=
   ```
   Followed by VASP-5+ format on lines 2 through end.
2. **Calculator runs** DFT (or an MLIP) on each POSCAR. Their job is to fill in the `energy_eV=` slot on line 1 with their computed energy in eV per cell. Everything else stays unchanged. They can do this with a one-line `sed` or a 5-line Python script.
3. **Enumlib reads** the directory back. The `read_results` walker parses line 1 of each POSCAR, extracts the structure ID and the energy, returns a `Dict{Int, Float64}`. Then `attach_results(enumeration, results)` matches IDs to `EnumeratedStructure` instances and produces an enriched enumeration.

**Why this design:** a single file per structure end-to-end. No parallel CSVs to keep in sync; no per-structure sidecar files to multiply directory bloat. The collaborator's deliverable is *the same directory you sent them*, just with the `energy_eV=` slot filled. Manual edit OR a quick script — both work.

**What's deliberately NOT in the contract:**
- We don't parse `vasprun.xml` or `OUTCAR`. The calculator's DFT-side parsing is their problem.
- We don't carry forces / stresses for v0.2.0 (CE-only fitting). Schema is forward-compatible: future `forces_eV_per_A=...` slot doesn't break existing files.
- We don't cross-reference Fortran enumlib's `makestr` output. VASP POSCAR format compliance is the only correctness anchor.

---

## What lives in chunk 11

### 11a — POSCAR writer for a single structure (~120 lines)

`src/io/poscar.jl` (new file; new `src/io/` directory introduced — first algorithm-side I/O code).

```julia
"""
    to_poscar(io::IO, structure::EnumeratedStructure{D,L}, parent::ParentLattice{D},
              hnf::HNF{D}; species_symbols, super_periodic, comment_extras = String[]) where {D,L}

Write a single POSCAR (VASP-5+ format, compatible with VASP 5 and VASP 6) representing the given enumerated structure on the given supercell HNF, decorated with the given species labels.

Line 1 is a comment we control:

    # enumlib_id=<id> hnf=<hnf_idx> concentration=<a:b:...> super_periodic=<true|false> energy_eV=

The `energy_eV=` slot is empty when written. Collaborators fill it in (manual edit or 5-line script) after running DFT/MLIP. Enumlib's `read_results(dir)` later parses these slots back.

Lines 2 through end are standard VASP-5+ POSCAR:
    line 2: scale factor (we always write 1.0)
    lines 3-5: lattice vectors (Cartesian, columns of A_p · hnf.matrix)
    line 6: species symbols (e.g., "Ag Pt")
    line 7: per-species atom counts (e.g., "15 17")
    line 8: coordinate mode ("Direct" — fractional coordinates)
    lines 9-end: atomic positions in fractional coordinates

Arguments:
- `io` — open IO stream to write to.
- `structure::EnumeratedStructure{D,L}` — the enumerated labeling; `to_labeling(structure)` gives the per-site colors.
- `parent::ParentLattice{D}` — the parent lattice (provides `parent.A` for the primitive basis).
- `hnf::HNF{D}` — the HNF for the structure's supercell. Cartesian basis = `parent.A * hnf.matrix`.
- `species_symbols::Vector{String}` — kwarg, required. Length k. Maps color 0 → species_symbols[1], color 1 → species_symbols[2], etc. E.g., `["Ag", "Pt"]` for the Ag-Pt binary.
- `super_periodic::Bool` — kwarg, required. The `include_superperiodic` policy this structure was enumerated under (true = full Burnside; false = primitive only).
- `comment_extras::Vector{String}` — optional. Additional `key=value` pairs to append to the comment line (e.g., `["author=alice"]`).

Throws `ArgumentError` if `length(species_symbols) ≠ k` (k inferred from the structure's allowed labels).
"""
function to_poscar(io::IO, structure::EnumeratedStructure{D,L},
                   parent::ParentLattice{D}, hnf::HNF{D};
                   species_symbols::Vector{String},
                   super_periodic::Bool,
                   comment_extras::Vector{String} = String[]) where {D,L}
    ...
end
```

**Implementation notes:**

- **Structure ID provenance.** `EnumeratedStructure` doesn't currently carry a global ID; chunks 5–6 used `(supercell_idx, position_in_supercell)` for traceability. Phase 11 needs a *flat global integer* `enumlib_id` that's monotonic across the whole `Enumeration`. Two options:
  1. Compute on the fly: `enumlib_id` = the index of `structure` in `enumeration.structures`. Implicit, no struct change.
  2. Add an `id::Int` field to `EnumeratedStructure`. Explicit, but requires a struct migration that ripples into chunks 5–8 tests.
  
  My lean: **option 1**, computed at write time. No struct migration; the ID is a presentation detail, not a permanent property. `read_results` reads back whatever ID the collaborator's filled-in line says.

> option one. 
- **HNF index provenance.** `EnumeratedStructure` has `supercell_idx` pointing into `enumeration.supercells`. The HNF index in the manifest is just `supercell_idx`. Stable across `enumerate(...)` calls with the same input.

- **Concentration string format.** Locked: `<a>:<b>:...` — colon-separated integer counts (e.g., `15:17` for 15 of color 0 and 17 of color 1). **Always the actual labeling's counts, not the enumeration-query's.** Every POSCAR represents *one* specific structure with *one* specific composition; whether the enumeration was unrestricted or fixed-concentration doesn't matter — at write time, the count is computable from the labeling and gets written verbatim. Your understanding (line 93 review) is correct: each POSCAR has its own concrete a:b:... count, no "empty for unrestricted" edge case.

- **VASP 5+ specifics.** Line 6 contains species symbols ("Ag Pt"); line 7 contains per-species counts ("15 17") in the *same order as line 6*. The atomic positions in lines 9+ are grouped by species, in the same order as line 6/7. For a labeling `[0, 1, 0, 1, 0, ...]`, we write all color-0 positions first, then all color-1 positions, etc. **No permutation tracking needed** (per your line 96 conclusion): the calculator only sends back the energy, which belongs to the structure-as-a-whole regardless of position-ordering. The `enumlib_id` on line 1 is the unambiguous identifier; we don't need a position permutation to round-trip energies.


- **Cartesian basis (VASP rows convention; locked).** Per your line 100 confirmation: VASP reads lines 3–5 as the `(a, b, c)` lattice vectors, one vector per line. Internally Enumlib stores basis as columns (`A_p[:, j]` is the j-th lattice vector), so the POSCAR write transposes — line `2+j` contains `A_super[1,j] A_super[2,j] A_super[3,j]`, where `A_super = parent.A * hnf.matrix`. This Julia-column / VASP-row convention difference will be a one-line comment at the writer site to prevent future readers from getting confused.
- **Atomic positions in Direct (fractional) coordinates — locked.** Per your line 102 confirmation: always use Direct mode. Each atom's position is reported in `(c1, c2, c3)` ∈ [0, 1)³ where the Cartesian position is `A_super * [c1, c2, c3]'`. The supercell's $n$ sites have fractional positions on a regular grid determined by the HNF's SNF diagonal — derived from the chunk-3 supercell-position layout. We never write Cartesian-mode POSCARs.
**Validation tests (locked at write time, byte-for-byte):** small hand-verified POSCAR for FCC binary at n=4 with concentration 2:2 — known good byte sequence. Plus structural tests: `read_back_after_writing` matches the original structure for several cases.

### 11b — Bulk write as a tarball + manifest (~100 lines)

`src/io/poscar.jl` (continued). **Locked Q9-A: tarball-primary; directory is internal scratch.**

```julia
"""
    write_enumeration_archive(path::AbstractString, enumeration::Enumeration{D,L};
                              species_symbols::Vector{String} = String[],
                              super_periodic::Bool,
                              label::AbstractString = "",
                              manifest_filename::AbstractString = "enumeration.toml") -> String

Write every structure in `enumeration` to a single tarball at `path`. Returns the actual tarball path written (which may differ from `path` if `path` is a directory or if a timestamp was auto-appended).

If `path` ends in `.tar.gz` or `.tgz`, the file is written as that exact name. If `path` is a directory, the tarball is auto-named:

    enumlib_<label>_<yyyy-mm-ddTHH-MM-SS>.tar.gz

where `<label>` defaults to a short summary of the enumeration (parent / species / supercell range / concentration); user can override via the `label` kwarg.

Internally, builds a temp directory containing one POSCAR per structure (filenames `POSCAR.00001`, `POSCAR.00002`, ... per Q1-B lock) plus a TOML manifest, then tars + gzips into `path`. Temp directory is cleaned up unless `keep_directory=true`.

Tarball entries:
- `POSCAR.00001`, `POSCAR.00002`, ... — one per `EnumeratedStructure`. ID = monotonic index in `enumeration.structures` (Q5-A).
- `enumeration.toml` — manifest mapping each filename to `(structure_id, hnf_idx, concentration, super_periodic, poscar_filename)`. Plus a top-level `[enumeration]` section recording the parent lattice + sites description.

`species_symbols` defaults to `["A", "B", "C", ...]` (Q3-B); calling user can override with real chemistry. `super_periodic::Bool` is required so each POSCAR's header records the policy used at enumeration time.
"""
function write_enumeration_archive(path::AbstractString, enumeration::Enumeration{D,L};
                                    species_symbols::Vector{String} = String[],
                                    super_periodic::Bool,
                                    label::AbstractString = "",
                                    manifest_filename::AbstractString = "enumeration.toml",
                                    keep_directory::Bool = false) where {D,L}
    ...
end
```

**Implementation notes:**

- **Tarball machinery.** `Tar` is Julia stdlib (no new direct dep needed). For gzip wrapping, use `CodecZlib` if it's already in the dep tree (it's a transitive dep through Plots/Documenter); else fall back to `.tar` (uncompressed) for v0.2.0. Decision deferred to implementation time after a quick `Pkg.dependencies` check.
- **Auto-named tarball filename.** Default form: `enumlib_<parent>_<species_or_k>_<volume_range>_<concentration>_<timestamp>.tar.gz`. Example: `enumlib_FCC_AgPt_n32_15-17_2026-05-08T14-30-00.tar.gz`. Per your line-150 review note: the timestamp makes accidental same-filename collisions impossible. The `label` kwarg lets the user override the descriptive part if they want.
- **Manifest as TOML.** Julia stdlib has TOML. Schema mirrors the POSCAR header line so collaborators can verify consistency by eye.
- **Filename per POSCAR inside the tarball.** `POSCAR.00001`, `POSCAR.00002`, ... per Q1-B (zero-padded number after a dot, no `.vasp` extension; original VASP convention). Width determined by the largest ID in the enumeration (so n=99 uses width 2; n=99999 uses width 5). 

### 11c — Roundtrip read (~70 lines)

`src/io/poscar.jl` (continued). **Auto-detects tarball vs directory** per Q9-A.

```julia
"""
    read_results(path::AbstractString; manifest_filename = "enumeration.toml")
        -> Dict{Int, Float64}

Read back results from a path that's either:
- A `.tar.gz` / `.tgz` / `.tar` file — extracts to a temp dir, reads, cleans up.
- A directory of POSCAR files — reads directly.

Walks every POSCAR, parses line 1's `energy_eV=` slot, returns a Dict mapping `enumlib_id` to `energy` in eV.

Skips POSCARs whose `energy_eV=` slot is still empty (calculator hasn't filled it in yet) and emits an `@info` message listing them. Throws if any POSCAR's line 1 doesn't match the expected `# enumlib_id=...` format.

If the manifest file is present in `dir`, cross-checks each POSCAR's filename against the manifest's `poscar_filename` field and warns on mismatches.

Returns just the energies — `attach_results(enumeration, results)` does the matching to `EnumeratedStructure` instances.
"""
function read_results(dir::AbstractString;
                      manifest_filename::AbstractString = "enumeration.toml")::Dict{Int, Float64}
    ...
end

"""
    attach_results(enumeration::Enumeration{D,L}, results::Dict{Int, Float64})
        -> Vector{Tuple{EnumeratedStructure{D,L}, Float64}}

Match the structure IDs in `results` to `EnumeratedStructure` instances in `enumeration` and return paired tuples. Errors if any ID in `results` doesn't appear in the enumeration; warns on enumeration structures that don't have a corresponding result (calculator didn't fill in energy yet).

Returns a flat `Vector{Tuple{...}}` rather than a typed `EnrichedEnumeration` for now — JuCE.jl can consume the tuples directly. A typed wrapper (with energies stored as a parallel field on Enumeration) is v0.3 polish.
"""
function attach_results(enumeration::Enumeration{D,L},
                        results::Dict{Int, Float64}) where {D,L}
    ...
end
```

**Implementation notes:**

- **Energy parsing.** Regex on line 1: `r"energy_eV\s*=\s*([-+]?\d+\.?\d*([eE][-+]?\d+)?)?"`. Match the optional float; if absent, the slot is empty.
- **No `EnrichedEnumeration` type.** Per chunk 7 design Q3 (and matching that minimalism here), we don't introduce a new wrapper type for the result-attached form. Just return tuples; the caller (JuCE.jl) decides how to package them. Easy to add a typed wrapper in a future v0.3 chunk if usage patterns argue for it.

### 11d — End-to-end tutorial doc (~150 lines, prose; in `docs/notes/`)

`docs/notes/phase11-tutorial.md` (becomes Phase 13d's `tutorials/03-dft-training-database.md`).

A single end-to-end worked example: binary FCC training-database generation. Full code blocks, expected outputs, "now hand the directory to your collaborator" workflow narrative. Demonstrates:

1. Set up parent + sites + supercells + a small `ConcentrationRange`.
2. `count_inequivalent(...)` first to size the request.
3. `enumerate(...)` to actually generate.
4. `write_enumeration("./batch1/", enumeration; species_symbols=["Ag", "Pt"], super_periodic=false)`.
5. Show what `cat batch1/POSCAR_00001.vasp` looks like (the header line and the body).
6. Simulate the collaborator filling in energies (a small Julia loop using `sed`-like substitution, *as if* a Python script did it).
7. `read_results("./batch1/")` returns the Dict.
8. `attach_results(enumeration, results)` returns the tuples.
9. Hand off to JuCE.jl for the CE fit.

**Why in `docs/notes/` initially:** Phase 13 hasn't shipped yet, so we don't have the Documenter.jl tree. The tutorial lands as a plain Markdown doc that gets *moved* into `docs/src/tutorials/03-dft-training-database.md` when Phase 13d arrives.

---

## What's deliberately NOT in chunk 11

- **Multi-lattice support** (perovskite, half-Heusler). Single-lattice only per Q4 lock; v0.3.
- **Forces / stresses** in the schema. Energy-only per A2-(i); forward-compatible for later extension.
- **Site-restricted enumeration's POSCAR output.** Chunk 6.5 gates this; not yet wired.
- **VASP `vasprun.xml` / `OUTCAR` parsing on Enumlib's side.** Calculator's responsibility.
- **Fortran enumlib `makestr` cross-reference.** Q6 lock — VASP format compliance is the only correctness anchor on the writer.
- **A typed `EnrichedEnumeration` wrapper.** v0.3 polish.
- **Streaming / lazy iteration of `write_enumeration` on huge directories.** v0.3 if 100k+ structure cases hit memory.

---

## Tests planned (`test/test_phase11_poscar.jl`)

### POSCAR writer correctness

1. **Single-structure POSCAR byte-for-byte.** Hand-write the expected POSCAR for FCC binary at n=4 with concentration 2:2 + a known canonical labeling (one of the chunk-5/6 reference cases). Lock the byte string; `to_poscar(io, ...)` must produce exactly that.
2. **Header line format.** Construct several POSCARs at varying inputs; parse the line-1 `key=value` pairs back; verify each key is present with the expected value. Specifically test the `energy_eV=` slot is empty when written.
3. **Lines 6 / 7 species ordering.** Build a structure with `[1, 0, 1, 0, 1, 1]` (3 of color 1, 3 of color 0). Verify line 6 reports both species in canonical order, line 7 reports counts in matching order, and lines 9+ are *grouped* by species (color 0 first, color 1 second).
4. **Cartesian basis.** Build a non-trivial HNF (e.g., the cubic 2×2×2 from chunk-8 tests). Verify lines 3–5 of the resulting POSCAR are exactly the three Cartesian lattice vectors of `A_p * hnf.matrix`, formatted to consistent precision.
5. **`species_symbols` length mismatch.** Pass a 3-symbol vector to a binary structure; `to_poscar` should `throw ArgumentError`.
6. **VASP 6 round-trip via pymatgen** *(optional, cross-validation)*: write a POSCAR, read it back via `pymatgen` (Python interop), check the resulting `Structure` has the right cell, species, and positions. Skipped if `pymatgen` isn't available; useful as a v0.2-polish CI check.

### Bulk write + manifest

7. **Round-trip an Enumeration.** `write_enumeration("./testdir/", e; ...)` then enumerate `./testdir/`; verify N POSCARs were created (where N = `length(e)`), each named according to `filename_pattern`. Read the manifest, parse it, verify each entry corresponds to a real POSCAR.
8. **Empty-dir guard.** Pre-populate `./testdir/` with a junk file; `write_enumeration` should throw without `force=true` and succeed with `force=true`.
9. **Filename pattern.** Override `filename_pattern = "structure_{id:03d}.poscar"`; verify generated files match.
10. **Manifest content.** Inspect the TOML; verify per-structure sections + the `[enumeration]` top-level section.

### Roundtrip read

11. **`read_results` on filled-in POSCARs.** Write the directory, then *programmatically fill in* the `energy_eV=` slots with a fake Dict (simulate the calculator); call `read_results`; verify the returned Dict matches the fake Dict.
12. **`read_results` on partially-filled POSCARs.** Fill in only some `energy_eV=` slots; `read_results` should @info-log the unfilled ones and return only the filled ones.
13. **`read_results` on a malformed POSCAR.** Replace line 1 with a non-conforming string; `read_results` throws with a clear message naming the file.
14. **`attach_results` matching.** Pair an Enumeration with a synthetic results Dict; verify the returned tuples match.
15. **`attach_results` ID-not-found.** Pass a Dict with an ID that's not in the Enumeration; throws.
16. **`attach_results` Enumeration-structure-without-result.** Pass a Dict missing some IDs; warns; returned tuples are just the matched ones.

### End-to-end

17. **Full pipeline test.** `enumerate(...)` → `write_enumeration` → fake calculator fills in `energy_eV=` for all → `read_results` → `attach_results` → verify the count, the energies, and the structure-by-structure correspondence.

Total: 17 testsets, ~30 individual tests.

---

## Open questions — resolved (locked 2026-05-08)

- **Q1 → B.** Filename pattern: `POSCAR.00042` — original VASP convention (no `.vasp` extension; zero-padded number after a dot).
- **Q2 → A.** Header line: space-separated `key=value` pairs on a single comment line.
- **Q3 → B.** `species_symbols` is *optional* with default `["A", "B", "C", ...]` (color-as-letter). Rationale: the calling user (the person calling Enumlib) may not have decided which elements yet; the collaborator gets to choose at DFT-prep time. Enumlib doesn't need to know the chemistry to enumerate; we just need the calculator to give us back realistic energies on whatever species they pick. Calling user can override with `species_symbols=["Ag","Pt"]` when chemistry is locked at enumeration time.
- **Q4 → A.** `read_results` v0.2.0 strict-energy. Returns `Dict{Int, Float64}`. Force/stress extension is a v0.2.x minor when the schema matures.
- **Q5 → A.** ID = index in `enumeration.structures` at write time. No struct migration.
- **Q6 → A.** `src/io/poscar.jl` flat in the Enumlib namespace. Sub-module-ize later if scope grows.
- **Q7 → A.** Strict 11a → 11b → 11c → 11d order. Tutorial closes the chunk after the API is real.
- **Q8 → value-equality, not byte-for-byte.** Tests parse the written POSCAR back and check the *values* match the originals (lattice vectors numerically equal, fractional coordinates equal, species/counts correct, header keys present). Don't lock down whitespace, float precision, trailing newlines, etc. — those are formatting details that a writer rewrite could change without semantic effect. Faster to write, more robust to harmless tweaks.

## One remaining open question

### Q9 — Tarball as the deliverable form?

Your line-150 review note: "Even better, we could just write a zip tar ball instead of even bothering with the directory. And we could give it a verbose name so it was easy not to confuse it with other things. Maybe even incorporate the date and time into the file name so that it is impossible to write the same file name twice. Do you think this is a good idea, or is this too much?"

I think this is genuinely a good idea — the "deliverable as one thing" model fits how collaborators receive and re-send work better than a loose directory. Email/Slack/upload a `.tar.gz`; uncompress to edit; re-tar to send back. The directory model still works as an intermediate step but is awkward to ship as-is.

Three flavor options:

- **A. Tarball as primary deliverable; directory is internal scratch.** Top-level public function is `write_enumeration_archive(path, enumeration; ...)`, writing a single `.tar.gz`. Internally we build a temp dir, then tar+compress, then delete the temp dir. Filename auto-includes a timestamp: e.g., `enumlib_AgPt_15-17_n32_2026-05-08T14-30-00.tar.gz`. `read_results` accepts either a tarball path or a directory path (auto-detect). Cleanest collaborator UX.

- **B. Both forms equally supported.** Two top-level public functions: `write_enumeration(dir, ...)` writes a directory (as currently planned in 11b); `write_enumeration_archive(path, ...)` writes a tarball. User picks based on their workflow. `read_results` auto-detects either.

- **C. Directory primary; tarball is a kwarg.** `write_enumeration(dir, enumeration; archive::Bool=false, ...)`: when `archive=true`, after writing the directory, also creates `dir.tar.gz` (and optionally deletes the directory if `keep_directory=false`). Simpler API surface; one entry point.

- **D. Status quo — directory only.** No tarball machinery. User uses `tar` themselves if they want to ship as a single file.

**My lean: A.** Reasons:
1. Matches your framing: "the deliverable" is one named thing, not a directory. Tarball is the natural "ship-as-a-deliverable" form.
2. Timestamp-in-filename solves the "easy to confuse two batches" problem you raised.
3. Atomic write — no half-finished directory if the writer is interrupted.
4. Compression — saves ~3–10× transfer size on text POSCARs.
5. Internally we still write to a temp dir then tar; the directory-mode is just "skip the tar step."

If you prefer C, the kwarg-additive approach is also clean and adds optionality without forcing the tarball model on every user.

> Your response:
My lean is A as well.

**Locked: Q9 → A.** Public top-level for bulk-write is `write_enumeration_archive(path, enumeration; ...)` — produces a single timestamped tarball. The directory form is internal scratch (a temp dir, tar'd then cleaned up). `read_results(path)` auto-detects: tarball file → extract to temp dir, read, clean up; directory path → read directly. The 11b sub-chunk (below) is updated to reflect this; the directory-write is no longer a public function.
---

## Implementation plan (locked)

All Q1–Q9 answered. After this commit lands the doc, I begin coding:

1. **11a** — `src/io/poscar.jl::to_poscar`. Header with all-explicit concentration; species defaults to `["A","B",...]`; lattice vectors as VASP rows; Direct coordinates only. Value-equality tests (parse-back-and-compare); no byte-for-byte. ~130 lines + 6 testsets.
2. **11b** — `write_enumeration_archive(path, ...)` writes a single `.tar.gz` with auto-timestamped filename. POSCAR-inside-tarball naming `POSCAR.00001` etc. (Q1-B). Internal: temp dir, tar, gzip-via-CodecZlib-if-available, cleanup. ~100 lines + 4 testsets.
3. **11c** — `read_results(path)` auto-detecting tarball vs directory; `attach_results(enumeration, results::Dict{Int,Float64})`. Returns `Vector{Tuple{EnumeratedStructure, Float64}}`. ~70 lines + 6 testsets.
4. **11d** — `docs/notes/phase11-tutorial.md` end-to-end walkthrough. ~150 lines prose + 1 end-to-end test. Becomes Phase 13d's `tutorials/03-dft-training-database.md`.
5. Update `src/Enumlib.jl` includes + exports: `to_poscar`, `write_enumeration_archive`, `read_results`, `attach_results`.
6. Update `test/runtests.jl` with `include("test_phase11_poscar.jl")`.
7. Update `docs/notes/v0.2-plan.md` — Phase 11 → done; advance Phase 13.
8. Run all tests. Expect 573 + ~30 = ~603 passing.

**Estimated:** 2–3 focused sessions. 11a is the biggest single piece (the writer + the test references); 11b is moderate (tarball glue + manifest TOML); 11c is small (parser + dict-merge); 11d is prose + one end-to-end smoke test.

---

## After your sign-off

- Each sub-chunk lands as `Chunk 11a/b/c/d: POSCAR ...`. Per-sub-chunk review pass per workflow.
- After Phase 11 closes: real users (collaborators) start consuming POSCAR tarballs. Phase 13 (docs) starts as soon as Phase 11 is solid in production for at least a few days.

**Signed off (inline review 2026-05-08); no further questions remain. Beginning chunk 11a.**
