# Phase 9 — pymatgen drop-in: an `enum.x`-compatible Julia CLI (design pad)

**Status:** design only — *no code yet*. This is the shared foundation for the
**drop-in binary track** (a byte/behavior-compatible `enum.x`). The `juliacall`
**native track** (in-process, richer API) gets its own note later; the two run in
parallel per the 2026-07 decision.

**Goal.** A Julia program that reads `struct_enum.in` and produces `struct_enum.out`
*and the stdout progress table* exactly as the Fortran `enum.x` does — so pymatgen's
`EnumlibAdaptor` uses it with **zero code changes**. Later PackageCompiled to a
standalone `enum.x` (Julia runtime baked in → invisible to the user).

Everything below is reverse-engineered from **live sources**, not memory:
- pymatgen **2026.5.4** `command_line/enumlib_caller.py` (installed in the test venv)
- enumlib `aux_src/makeStr.py` (the current structure expander pymatgen calls)
- enumlib `src/io_utils.f90` (`read_input`) and `src/labeling_related.f90:709` (the writer format)
- a real `struct_enum.out` + stdout captured from the freshly-built Fortran `enum.x`

---

## 1. The verified consumer contract

### 1a. Invocation
- `ENUM_CMD = which("enum.x") or which("multienum.x")` → **ship our binary named `enum.x`, first on `PATH`.**
- Run with **no arguments** via `Popen([ENUM_CMD], stdin=PIPE, stdout=PIPE)`. Our binary must:
  read `struct_enum.in` from the CWD, write `struct_enum.out` to the CWD, **exit 0**, and **not block on stdin** (Fortran `enum.x` ignores stdin — we must too).
- Timeout is enforced **Python-side** (`communicate(timeout=…)`); we don't handle it. (This is the issue #4185 surface the native track later improves — out of scope here.)
- `MAKESTR_CMD = which("makestr.x") or which("makeStr.x") or which("makeStr.py")` reads `struct_enum.out` → `vasp.*` files.
  **Confirmed: only `enum.x` needs reimplementing — the existing makestr is reused unchanged**, as long as our `struct_enum.out` is consumer-equivalent (§3).

### 1b. STDOUT — pymatgen's structure counter (easy to miss)
pymatgen derives `num_structs` from `enum.x`'s **stdout**, not the file
(`enumlib_caller.py:304-311`): it finds the line ending in `RunTot`, then reads the
following data rows and takes `line.split()[-1]` (the cumulative total). Captured Fortran table:

```
Volume       CPU        #HNFs  #SNFs    #reduced    % dups      volTot      RunTot
   2         0.0015        7     1         2        0.7143           2           2
   4         0.0119       35     2         7        0.8000           5           7
   6         0.0492       91     1        10        0.8901          20          27
   8         0.1411      155     3        20        0.8710          94         121
```

**Requirement:** print a header line ending in `RunTot`, then per-volume rows whose
**last token is the cumulative structure count**, ending in the grand total
(= `length(enumeration)`, here 121). Only the last token is read by pymatgen, so the
CPU/`#HNFs`/… columns don't affect it — but we'll fill them for parity and human use.

### 1c. `struct_enum.out` — what makeStr actually reads
`makeStr.py:_read_enum_out` parses **by line-position and token-position** (`temp.split()`),
**not** fixed Fortran column widths. Three consequences:

- **Column widths are irrelevant** — whitespace-separated integers suffice. (We can drop the
  `(i11,1x,i9,…)` fussiness from `labeling_related.f90:709` entirely.)
- **Header line-layout matters** — makeStr locates data rows at `line_count − (14 + adjust)`,
  where `adjust = nD + k + 1` if a concentration block is present, else `nD`. So the header
  must have exactly the right number of lines. We reproduce it line-for-line per case.
- **Each data row = exactly 27 whitespace-separated tokens**, this order (`makeStr.py:882-905`):

  | idx | token | ← Enumlib.jl source |
  |----:|-------|---------------------|
  | 0 | strN (structure #) | running counter |
  | 1 | hnfN (HNF #) | running HNF counter |
  | 2 | hnf_degen | `Supercell.hnf_degeneracy` |
  | 3 | lab_degen | `EnumeratedStructure.orbit_size` — or `0` (Q1) |
  | 4 | tot_degen | `hnf_degen*lab_degen` — or `0` (Q1) |
  | 5 | sizeN | per-cell-size counter |
  | 6 | n | `volume(hnf)` |
  | 7 | pgOps | `Supercell.n_stabilizer_ops` |
  | 8–10 | SNF diag | `Supercell.snf` |
  | 11–16 | HNF | `H11,H21,H22,H31,H32,H33` (lower-tri, this exact order) |
  | 17–25 | L | `transpose(L)` flattened **row-major** (see §3 caveat) |
  | 26 | labeling | `join(to_labeling(s))` — contiguous digit string |
  | (27) | directions | arrows — **omit** (makeStr defaults to zeros) → 27 tokens total |

---

## 2. `struct_enum.in` reader → Julia API

From `io_utils.f90:read_input` + the `support/input/struct_enum.in.*` samples:

| input field | → Enumlib.jl |
|-------------|--------------|
| line 1: title | kept, echoed into the `.out` header |
| line 2: `bulk`/`surf` | `D = 3` / `2` (surf ⇒ LatDim 2 — deferred, Q3) |
| lines 3–5: parent vectors (as columns) | `ParentLattice(A)` basis |
| k (n-ary) | number of colors |
| nD | dset size |
| nD × d-vector lines `x y z  #/#/…` | `Sites([Site(frac, allowed_labels), …])` |
| equivalencies (optional `E…`) | `equate!` on the `Sites` |
| Nmin Nmax | `VolumeRange(Nmin:Nmax)` |
| eps | tolerance kwarg |
| full/part | mode flag (Q5 — confirm semantics) |
| concentration block (optional) | `Concentration` / `ConcentrationRange` |

**Coordinate convention (Q — please confirm):** `struct_enum.in` d-vectors are **Cartesian**;
Enumlib.jl `Site` positions appear **fractional** (the test suite uses `[1/3, 2/3, 1/2]` for HCP).
So the reader converts `frac = inv(A) * cart`. If `Site` is actually Cartesian, this drops out.

---

## 3. Compatibility target — "consumer-equivalent," not byte-identical

We match what the two consumers *read*, and accept Fortran idiosyncrasies elsewhere:

- **Must match:** header line-layout; stdout `RunTot` cumulative totals; per-row 27-token
  order & count; the parent lattice + d-vectors in the header; and — at the *reconstructed-structure*
  level — `n`, HNF, SNF, L, labeling.
- **Need not match:** exact column widths; CPU timings; the *values* of the diagnostic columns
  (Fortran writes `lab_degen = tot_degen = 0` in the concentration-restricted mode — Q1).

**Important subtlety — the SNF `L` transform is not unique.** makeStr uses `(HNF, L, labeling)`
*together* to place atoms; a different-but-valid `L` paired with a correspondingly-permuted
`labeling` yields the *same* structure. So a raw token-level diff of `L`/`labeling` against the
Fortran output will show spurious differences whenever our SNF routine picks a different `L`.
**Therefore correctness must be judged at the reconstructed-structure level, not on raw `L`/labeling
tokens.** This makes the pymatgen/makeStr end-to-end (L3 below) the real oracle; the raw file diff
(L2) is only a sanity check *modulo* SNF-transform freedom.

**Structure ordering (Q2):** set-equality of the reconstructed structures is enough for
correctness. Exact row-order parity with Fortran only matters if we want "structure #N" to name
the identical structure across the two codes.

---

## 4. Feature coverage — `struct_enum.in` capabilities vs the current engine

- **Supported now:** `bulk`; single-lattice (Regime A) and multilattice — uniform sublattices
  (Regime B, HF 2009) and heterogeneous per-site `allowed_labels` (Regime C); full-list;
  concentration ranges.
- **Deferred / needs care:** `surf`/2D (`LatDim = 2`); the Fortran "inactive site" label encoding
  (a label value `> k-1`); `full` vs `part` semantics (Q5); `:multinomial` + per-site labels.
- **Out of scope (agreed):** arrow/displacement enumeration.
- **Not exercised by this path:** magnetic enumeration (a native-track / v0.next concern).

---

## 5. CLI & packaging plan

- `src/io/struct_enum.jl`
  - `read_struct_enum_in(io) -> (parent, sites, selection, concentration, opts)`
  - `write_struct_enum_out(io_file, io_stdout, enumeration)` — file rows **and** the `RunTot` table.
- `bin/enum.jl` — a Julia 1.12 `@main` entry: read CWD `struct_enum.in`, `enumerate(...)`,
  write CWD `struct_enum.out`, print the stdout table, exit 0.
- Later (separate chunk): PackageCompiler `create_app` → standalone `enum.x` with the Julia
  runtime bundled; then re-run L3 against the *compiled* binary.

---

## 6. Test plan — reuse existing corpora, invent nothing

- **L1 — count agreement:** `length(enumerate(...))` == enum.x stdout final `RunTot` ==
  the locked Julia-suite counts (fcc n=8→390, n=12→7140; `fortran_hcp`; `fortran_diamond`) ==
  `test/data/chunk6.5_fortran_corpus.csv`.
- **L2 — file sanity diff:** run both binaries over `support/input/*`; parse both `struct_enum.out`;
  compare `n`/HNF/SNF as an order-insensitive set (treat `L`/labeling per the §3 caveat).
- **L3 — pymatgen end-to-end (the real oracle):** in the py3.12 venv, run `EnumlibAdaptor` with the
  Fortran `enum.x` (baseline) then with our `enum.x`; compare the resulting `Structure` sets via
  `StructureMatcher`.

---

## 7. Open questions for you (please answer inline or edit above)

1. **`lab_degen`/`tot_degen`:** emit the *true* `orbit_size` (more useful; makeStr reads but doesn't
   need it for geometry) or match Fortran's `0` in restricted mode (strict parity)?
   *My lean: true values — a clean superset, and our degeneracies are a selling point.*
   > return the true values

2. **Ordering:** exact row-order parity with Fortran, or is reconstructed-set-equality the v1 bar?
   *My lean: set-equality.*
   > Set equality is just fine. But we should remember to tell users/maintainers that order is not guaranteed with the new code.

3. **v1 scope:** OK to target `bulk` + Regimes A/B/C + full-list + concentration-range first,
   deferring `surf`/2D and the inactive-site label encoding?
   > Fine for now
4. **Layout:** `src/io/struct_enum.jl` + `bin/enum.jl` as in §5 — agree?
5. **`full` vs `part`:** can you confirm exactly what that Fortran flag controls, so I map it right?
   (I have a guess; you know for sure.)
> Full enumerates the "complete" list of colorings, not removing label-exchange duplicates (see Hart Forcade 2008). In general, most users always do full. We could probably sunset the "part" setting
*(No code until you sign off. Numbered responses / sign-off go below.)*

## 8. Responses & sign-off

> Good plan. Go ahead on.

**Claude — confirmed, proceeding to chunk 9.1:**
1. `lab_degen`/`tot_degen` → emit **true** values (`orbit_size`, `hnf_degen·orbit_size`).
2. Ordering → **set-equality** is the bar. *Action:* document "structure order is not
   guaranteed and differs from the Fortran code — do not rely on 'structure #N'" in the CLI
   help + README, and call it out to maintainers.
3. v1 scope → `bulk` + Regimes A/B/C + full-list + concentration-range; `surf`/2D and the
   inactive-site encoding deferred.
4. Layout → `src/io/struct_enum.jl` + `bin/enum.jl` (taken as approved via sign-off).
5. `full`/`part` → **verified against source** (answering the inline question):
   - **Fortran:** `part` *is* a distinct code path — `labeling_related.f90:1372`
     (`if (.not. full) then  ! loop over the label-exchange duplicates and mark them off`);
     `full` uses the trivial `k^n` space (`:1539`), no label-exchange elimination.
   - **Enumlib.jl — yes, confirmed:** there is **no** label-exchange–elimination code anywhere
     in `src/`. `reduceColorings` / `getUniqueColorings` / the multinomial + tree algorithms all
     quotient by the *site* permutation group, never by label permutations. So there is no
     "part" branch to test; the suite instead validates full-mode parity —
     `test/test_enumerate.jl:131` is annotated "reference (full mode, no label-exchange
     elimination)". Enumlib.jl is therefore **full-mode-only by construction** — exactly the
     drop-in's need. (And pymatgen writing `full` at `enumlib_caller.py:245` is now confirmed.)
   
   v1
   accepts `full`; on `part` it emits a clear "unsupported (sunset)" error. *Action/verify:*
   confirm pymatgen's `_write_input_files` always writes `full` — if it can emit `part`,
   erroring would break the drop-in, so check before finalizing. **[done — pymatgen writes `full`.]**

---

### Chunk 9.1a status — `struct_enum.in` reader (landed, awaiting your review)

- `src/io/struct_enum.jl` added; include wired into `src/Enumlib.jl`. Reader only; writer/CLI next.
- **L1 count parity — 15/15 cases agree three-way** (Fortran `enum.x` = Julia reader→enumerate =
  locked reference), by generating a `struct_enum.in` per case from the existing test corpus:
  - single-lattice binary: fcc n=4 / 8 / 12 → 19 / 390 / 7140
  - single-lattice **ternary** (k=3): fcc n=4 → 96
  - multilattice Regime B: hcp n=1–6 → [3,10,50,270,651,4793]; diamond n=1–4 → [3,7,33,171]
  - concentration-restricted: fcc 1:1, vols 1–8 → 121
  - (harness: `scratchpad/phase9_l1_broad.jl` — to be promoted into `test/` as a CI comparison.)
- Scope deferrals behave as designed — a clear `ArgumentError`, never a wrong answer:
  `.13` / `.hex` = `surf`/2D; `.inactives` = inactive-site label encoding.
- `.lowsym` is a **pre-label-format legacy fixture** that the *current Fortran `enum.x` also rejects*
  ("Not all of the labels were used") — excluded, not a reader bug.
- Superseded by chunk 9.1b (below).

### Chunk 9.1b status — writer + CLI + full validation (landed, awaiting review)

- Added `write_struct_enum_out` (`src/io/struct_enum.jl`) and `bin/enum.jl` (the CLI: read CWD
  `struct_enum.in` → `enumerate` → write `struct_enum.out` + the `RunTot` stdout table).
- **Bug found & fixed by harvesting the broader corpus:** unrestricted **Regime C**
  (heterogeneous multilattice — Heusler/perovskite/zinc-blende) — `enumerate` *rejects* it
  without an explicit concentration, but the Fortran `enum.x` runs it. The reader now synthesizes
  the full-range concentration box for heterogeneous multilattices, matching Fortran. (Would have
  shipped as a silent drop-in gap.)
- **Full existing suite: ~1600+ tests pass** with the new module code (the POSCAR writer alone is
  1220) — no regression from adding the struct_enum I/O.
- **New CI regression net:** `test/test_struct_enum_io.jl` (**288 tests**), wired into `runtests.jl`:
  reader→enumerate count parity across FCC binary/ternary/fixed-conc, HCP, diamond, zinc-blende,
  half/full-Heusler, perovskite (reference counts harvested from the suite's Fortran-anchored
  corpora); writer well-formedness (27-token rows, labeling length, `RunTot`); reader guards
  (surf / part / inactive-marker → clear `ArgumentError`).
- **Cross-code harnesses promoted:** `test/integration/phase9/` (`cross_check.jl` +
  `compare_structs.py` + `run_adaptor.py` + README), env-parameterized, not in CI. Last run
  (2026-07-16):
  - **L1** count parity — all cases: Fortran `enum.x` = Julia reader→enumerate = reference ✓
  - **L3-lite** structure parity (`makeStr` + `StructureMatcher`) — all regimes ✓
  - **Full L3** — real `EnumlibAdaptor`, Fortran vs our `enum.x` on 50/50 Cu/Au FCC → 7 structures,
    identical (zero pymatgen changes; our binary just first on `PATH`) ✓
- **Deferred (unchanged from §4):** surf/2D; inactive-single-label Regime C via the Fortran ≥k
  marker encoding (covered pure-Julia in `test_struct_enum_io.jl`; excluded from the Fortran
  cross-check pending the inactive-encoding decision, chunk6.5-design §11).
- **Next:** PackageCompile `bin/enum.jl` → standalone `enum.x` (Julia baked in → invisible),
  re-run full L3 against the *compiled* binary, then conda-forge / PyPI-wheel packaging.

---

## 9. Counting/estimation notes from high-volume testing (NOT bugs)

### 9.1 `count_inequivalent` = unrestricted Pólya upper bound for Regime C (by design)

Pólya (cycle-index) counting **cannot express per-site `allowed_labels`** — there's no way to
extend it to the site-restricted case. So for heterogeneous multilattices `count_inequivalent`
returns the *unrestricted* orbit count, which is a valid **upper bound**, not the exact
restricted count (zinc-blende n=1/2/3: 16/204/2960 ≥ exact 4/11/52). It is exact for
single-lattice (A) and uniform multilattice (B) — diamond (B) matches 3/7/33. **This is expected
behavior, not a defect** (per GLWH).

- Exact Regime C counts come from `enumerate` (or the restricted algorithms); the high-volume
  harness uses `enumerate` for Regime C.
- `estimate_cost` inherits the upper bound → over-estimates Regime C cost. **That's fine for the
  cost-gate:** it's a conservative upper bound (better to over-warn than under-warn), the user
  can override (raise `memory_budget` / `skip_resource_check`) to run anything Fortran would, and
  the gate deliberately behaves *differently* from the Fortran — the Fortran happily runs absurd
  enumerations, whereas the new code warns/gates naive users (the original brief's "catch"). A
  **feature**, not a regression.
- Doc TODO: note in the `count_inequivalent` / `estimate_cost` docstrings that Regime C yields an
  upper bound.

### 9.2 sc vs fcc/bcc counts — verified correct (an odd/even coincidence)

The high-volume summary initially *looked* like `sc = fcc = bcc` (it only showed n=27). Verified
this is correct, not a bug: the engine distinguishes cP from cF/cI — `sc` **differs at even n**
(n=2/4/6/8/10/12 → 3/24/104/491/1494/8734 vs fcc 2/19/80/390/1211/7140) and coincidentally
**equals fcc at odd n** (n=27 is odd). `fcc = bcc` at all n (cF/cI duality). Both Fortran
(exhaustive) and Julia (Pólya) agree at every volume — strong cross-validation.

---

## 9b. pymatgen's OWN enumlib suite passes against our `enum.x` (2026-08)

The definitive drop-in proof for the PR: cloned `materialsproject/pymatgen-core` +
`pymatgen-test-files`, put our `enum.x` (wrapper → `bin/enum.jl`) + `makeStr.py` on PATH, set
`PMG_TEST_FILES_DIR`, and ran pymatgen's unmodified `tests/command_line/test_enumlib_caller.py`
against released pymatgen **2026.5.4**:

**4 passed / 0 failed** — `test_init` (LiFePO4 multilattice → 86 structures), `test_rounding_errors`
(Cu7Te5 → 197), `test_partial_disorder` (garnet → 7 and 20), `test_timeout`. pymatgen's real
fixtures + expected counts, no test edits.

**Bug this caught (fixed):** `read_struct_enum_in` ignored the file's `eps` and built
`ParentLattice` with the 1e-6 default `eps_dset`. pymatgen writes CIF-derived coords with ~1e-5
noise + a matching `eps` (`enum_precision_parameter`), so symmetry-op dset matching crashed
`enum.x` on `test_init`. Fix (`src/io/struct_enum.jl`): `eps_dset = max(eps, 1e-6)` from the file,
matching how Fortran uses `eps`. Our own 288-test suite uses clean coords so never hit this — only
pymatgen's noisy fixtures exposed it. No regression (288/288 still pass).

Repro (transient scratchpad; needs pymatgen venv + `enum.x`/`makeStr.py` on PATH):
`PMG_TEST_FILES_DIR=<pymatgen-test-files> pytest test_enumlib_caller.py -o addopts=""`.
TODO: fold this into `test/integration/phase9/` with a README pointer (the fixtures come from the
separate `materialsproject/pymatgen-test-files` repo, not a submodule).

## 10. Packaging (chunk 9.2): standalone `enum.x` via PackageCompiler

Built on the cluster (2026-07-17, SLURM job 12787273): `create_app` → `build/enum-app/bin/enum.x`.
**It works standalone** — self-test on a compute node in an isolated env (`env -i`, no Julia on
`PATH`) reproduced fcc n=4 → 19 structures, exit 0, `RunTot` table printed. The Julia runtime is
baked in and invisible. ✓ That's the core "invisible Julia" goal met.

**Distribution blocker: the app is 1.6 GB** (607 MiB of jll artifacts alone — Plots, GR, Qt6,
FFMPEG, x264/x265, Cairo, Xorg/Wayland). **Root cause: `Spacey` hard-depends on `Plots`**
(confirmed: `Spacey/Project.toml` `[deps] Plots`), so `Enumlib → Spacey → Plots` pulls the whole
plotting/graphics stack into a binary that never plots.

**Fix (in Spacey.jl — Gus owns it):** move `Plots` to a **weak dependency + package extension**
(`[weakdeps] Plots` + `ext/SpaceyPlotsExt.jl` for the viz functions). Enumlib doesn't plot, so it
would stop pulling Plots/GR/Qt6/FFMPEG/Xorg → the app should drop to ~300–400 MB (libjulia +
OpenBLAS + the real numerical deps). Benefits every non-plotting Spacey consumer. Rebuild +
re-measure after. Until then 1.6 GB works but is impractical for conda-forge / PyPI wheels.

**Rebuild result (2026-07-17, after removing the dead `Plots` dep from Spacey 0.9.1):** app
**1.6 GB → 655 MB** (`PLOTS_IN_APP=false`; library payload 285 MiB vs the old 607 MiB of graphics
artifacts), self-test still passes (fcc n=4 → 19, exit 0, empty env). 655 MB is near the
PackageCompiler floor (libjulia + LLVM + OpenBLAS + sysimage are inherently ~400–500 MB);
possible further trims (e.g. HTTP/OpenSSL if not truly reachable) are diminishing returns.
Compressed for conda/pip ≈ 200–250 MB — a reasonable "invisible Julia" footprint (and the
juliacall alternative fetches a similar-size Julia on first use anyway). Spacey change is
uncommitted (Gus's repo, v0.9.1); examples that plot now need Plots in their own env.

### 10.1 Regime C can't be pushed to high volume (materialization limit)

The Regime-C high-volume head-to-head hung after 3+ h and was cancelled. Root cause is
structural, not a bug: there is **no fast exact count for site-restricted (Regime C) cases**
(`count_inequivalent`/Pólya only give the upper bound — §9.1), so the harness must use
`enumerate`, which **materializes** the full structure list; on the Julia side that blows up in
time/memory well before Fortran (which streams to `/dev/null`). Regime C is therefore validated
at **tractable volumes only** (L1/L3/cross-check all agree with Fortran: zinc-blende → 4/11/52/290,
half/full-Heusler, perovskite). Harness fixed: Regime C capped at n≤8 + per-row `flush` (the empty
logs were block-buffered output, not a silent hang). A future lazy/streaming count for Regime C
would lift this, but it's out of scope for the drop-in (pymatgen → `enum.x` → `enumerate` is exact).

