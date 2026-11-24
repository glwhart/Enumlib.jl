# Draft — PR description (pymatgen-core)

**Suggested title:** Add drop-in compatibility CI for Enumlib.jl's `enum.x` (a Julia successor to the Fortran enumlib)

---

## Summary

I'm Gus Hart — a co-author of the Fortran `enumlib` (`enum.x` / `makeStr.py`) that `EnumlibAdaptor` has wrapped for years. I've rewritten the enumeration engine from scratch in Julia ([**Enumlib.jl**](https://github.com/glwhart/Enumlib.jl)) and verified it as a **drop-in replacement for `enum.x`** — concretely, **`tests/command_line/test_enumlib_caller.py` passes unmodified against it, green in CI:**

**→ https://github.com/glwhart/pymatgen-core/actions/runs/30926741986** (4/4 passed)

This PR opens that up for you: it adds an **opt-in CI job** that builds the Julia `enum.x` from source, puts it on `PATH` in place of the Fortran binary, and runs your existing enumlib suite against it. **No runtime code in pymatgen changes** — the drop-in works through the existing subprocess + file contract, so this is purely additive coverage. I'm also glad to reshape or drop the PR (docs-only, or nothing at all) depending on how you'd prefer to consume this.

## What this PR changes

- **Adds** `.github/workflows/enumlib-jl-dropin.yml` — installs Julia + released pymatgen, builds `enum.x` from Enumlib.jl, runs `test_enumlib_caller.py` with your fixtures. Short and readable.
- **Does not touch** `EnumlibAdaptor`, `enumlib_caller.py`, or any runtime path. Only `enum.x` is swapped at the binary level; `makeStr.py` is reused as-is.

## Why bother — what Enumlib.jl improves over the Fortran `enum.x`

- **Failures are catchable exceptions with messages**, not silent nonzero exits or runaway subprocesses — the class of friction behind #4185 (timeouts not honored through the subprocess) and the `EnumlibAdaptor` rough edges in #1063.
- **A pre-flight cost estimate + memory-budget gate** — a combinatorially explosive request becomes a fast, upfront "this would generate ~N structures / ~M GB; proceed or refuse?" (overridable) instead of churning or OOM-ing.
- **Count-without-enumerating** (Pólya) — report how many symmetry-distinct structures a request yields *before* generating them.
- Fixed-concentration / concentration-range enumeration, a recursive-stabilizer algorithm for high-freedom cases, and automatic algorithm selection.
- A modern, tested (~1,900 tests), documented, semver'd codebase under active development.

## Why "it's Julia" never reaches your users

The engine ships as a **standalone `enum.x` with the Julia runtime baked into the binary** (PackageCompiler) — no Julia install, no `juliacall`, nothing Julia-visible — distributed through conda-forge exactly like today's `enumlib` package. You depend on a version; CI builds every platform per release; users `conda update`. No hand-shipped binaries. (The CI job in this PR uses the faster build-from-source path; the shipped artifact is the self-contained binary.)

## Evidence

- **Your suite, green in public CI** against the Julia `enum.x`: the run linked above (LiFePO₄ → 86, Cu₇Te₅ → 197, garnet → 7/20, timeout handling).
- **End-to-end via `EnumlibAdaptor`**, unchanged: Fortran vs. Julia `enum.x` on the same disordered structure → identical `Structure`s (`StructureMatcher`).
- **Count parity with Fortran `enum.x`** at every cell size to **~166 million** structures (fcc/bcc/sc, hcp, diamond) and **~50 million** for a multilattice *ternary* case, correct across Bravais classes.
- Enumlib.jl's own suite (294 struct-I/O tests + ~1,900 total) is green in its CI.

## Honest notes

- **Footprint:** the self-contained binary is ~650 MB (bundled Julia runtime), ~200–250 MB compressed — in range of other compiled scientific packages. An optional in-process (`juliacall`) path exists for anyone who prefers a lean install and doesn't mind Julia installing on first use — strictly opt-in, never a core dependency.
- **Magnetic enumeration** (the `MagneticStructureEnumerator` path) needs one more piece, targeted for the next release; everything else is current.
- **One deliberate difference from Fortran, in a narrow corner:** when two symmetry-equivalent sublattices are assigned *different* species sets, Enumlib.jl treats them as physically distinct and returns the mathematically correct count for the full space group; the Fortran convention conflates them and returns a different number. Your suite doesn't hit this, but a user's structure could — Enumlib.jl's answer is the correct one, and I'd document it in a short migration note.
- Not leading with generation speed (head-to-head benchmarking in progress); the *counting* path is dramatically faster.

## How I'd like to proceed

Happy to take this any direction you prefer: merge the compatibility CI as-is, pare it back to a docs note, or keep it as a reference while you consume Enumlib.jl however suits you (conda-forge binary vs. the optional `juliacall` path — I'd value your read on that, given your users' install constraints). Glad to demo or discuss first.

## Checklist

- [ ] Reviewer: confirm the added workflow is acceptable (opt-in, no runtime changes).
- [ ] Decide packaging preference (self-contained binary vs. `juliacall`).
- [ ] (If desired) I add the short migration note on the documented Fortran-count divergence.
