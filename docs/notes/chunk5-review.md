# Chunk 5 — review and revise round

This file collects review items on chunk 5 (`Enumeration{D,L}` + `EnumeratedStructure{D,L}` + the public `Base.enumerate(...)` entry + the exhaustive 2008 algorithm body + the legacy-code cleanup).

Workflow:
1. Read the chunk 5 files (listed below) and add inline `#gh ...` comments wherever something needs discussion.
2. Tell me you're done; I read your comments and respond inline here under numbered items.
3. We iterate until everything is signed off.
4. I batch any code changes as chunk 5.1 (one commit) and we move to chunk 6.

## Files in scope

**New (chunk 5):**
- `src/types/enumeration.jl` (114 lines) — `EnumeratedStructure{D,L}`, `Enumeration{D,L}`, `to_labeling(s)`, iteration protocol, equality + hashing, pretty-print.
- `src/enumerate.jl` (122 lines) — extends `Base.enumerate(parent::ParentLattice{D}, sites::Sites{D}; supercells, algorithm, memory_budget, on_overflow, skip_preflight)`. Algorithm dispatch + Sites/multilattice/allowed-labels validation + the `:exhaustive` 2008 algorithm body. Plus `default_memory_budget()` per Phase 7 §7.3.
- `test/test_enumerate.jl` (148 lines) — 42 passing tests including the four load-bearing FCC reference counts that prove the chunk 1→5 stack is end-to-end correct.

**Modified:**
- `src/Enumlib.jl` — chunk-5 includes added near the bottom; chunk-5 exports (`Enumeration`, `EnumeratedStructure`, `to_labeling`, `default_memory_budget`); removed `SuperTile`, `ColoredTile`, `coloringsOfHNFList` from the export block.
- `src/LatticeColoringEnumeration.jl` — deleted `SuperTile` and `ColoredTile` structs; deleted `coloringsOfHNFList` function. Replaced with a deletion-history comment.
- `test/runtests.jl` — added `include("test_enumerate.jl")`.

## Items found by me during chunk 5 implementation (already fixed; flagged for transparency)

### Item A — `$SLURM_MEM_PER_NODE` was being string-interpolated

Inside the `default_memory_budget` docstring, I wrote `memory_budget = $SLURM_MEM_PER_NODE` to suggest the HPC pattern. Julia's docstring parser tried to evaluate `$SLURM_MEM_PER_NODE` as a variable and threw `UndefVarError: SLURM_MEM_PER_NODE not defined`. Caught at first `using Enumlib` after the file was added. Fix: escape with `\$SLURM_MEM_PER_NODE`.

Generalizable lesson: docstrings are interpolated like regular strings. Any `$something` in user-facing doc text needs `\$` to avoid binding to a variable. Worth a one-line note in the working agreement (added below).

### Item B — Two `SuperTile` structs in the codebase

While doing the cleanup pass, I noticed `LatticeEnumeration2D.jl` defines its own `SuperTile` struct (different from the 3D one in `LatticeColoringEnumeration.jl`). The 2D file is heavily used by `runtests2D.jl` but `runtests2D.jl` is *not* included in the main `runtests.jl`. So the 2D code is an orphaned subsystem.

Decision for chunk 5: deleted the 3D `SuperTile` (the dead one); left the 2D file untouched. The 2D codebase is a separate concern that probably wants its own audit before we delete anything.

Worth knowing about: there are two `runtests*.jl` files. `runtests.jl` is what `Pkg.test()` runs. `runtests2D.jl` runs only if someone explicitly `include`s it, and would currently fail because it tests the orphaned 2D code that no current callers reach.

Logged as a potential v0.2 polish task: decide what to do with `LatticeEnumeration2D.jl` — port to chunk-by-chunk style, or delete.

### Item C — Many guards rejecting things "for chunk 6+" or "for v0.3"

Chunk 5 carries five rejection guards in `enumerate(...)`:

1. `algorithm = :multinomial` or `:multinomial_restricted` → "chunk 6"
2. `algorithm = :recursive_stabilizer` → "chunk 8"
3. `length(parent.dset) > 1` (multilattice) → "v0.3"
4. `length(sites.list) > 1` (multi-site Sites) → "chunk 6+"
5. Non-zero-indexed-dense `allowed_labels` → "chunk 6+"

Each guard is a `throw(ArgumentError(...))` with a message naming the chunk where support arrives. None silently mis-handles; all surface clearly to the user. The chunk 5 surface is therefore narrow but well-defined: "single-lattice, single-site, zero-indexed-dense, exhaustive."

Worth knowing: when chunks 6 / 7 / 8 land, each will remove one or more of these guards. The error messages are reminders to the implementer, not user-facing forever.

## Items from your review

**Clean pass — no inline comments raised.** Signing off on chunk 5 as-is, including the three transparency items (A: `$SLURM` interpolation; B: orphaned 2D subsystem; C: chunk-5 rejection guards).

---

## Summary

| # | Item | Action | Status |
|---|---|---|---|
| A | `$SLURM_MEM_PER_NODE` docstring interpolation | Already fixed (escaped with `\$`) | Closed |
| B | Two `SuperTile` structs (3D deleted; 2D orphaned) | Logged as v0.2 polish task | Closed |
| C | Five chunk-5 rejection guards (chunks 6/7/8 / v0.3) | Reminder to implementer; user-facing always | Closed |

No code changes needed. Chunk 5 is closed; v0.2-alpha milestone shipped. Moving to chunk 6.
