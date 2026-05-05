# Chunk 2 — review and revise round

This file collects review items on chunk 2 (`Site{D}`, `Sites{D}`, plus chunk 2.1 — the `coloring_hash` rename to fix the `Base.hash` shadow). Items 1–2 are the inline comments you left on the source files this round. Items 3+ are spillover from the chunk-2.1 work I just did, listed for transparency.

Respond inline under each item. When all items are signed off, chunk 2.1 lands as one commit alongside any chunk-2 revisions, then we move to chunk 3 design.

---

## Item 1 — `site.jl` docstring clarification (acknowledged)

**Where:** `src/types/site.jl` line 6.

**Your edit:** added "(D is typically 3, for 3D crystals.)" to the docstring's BitSet paragraph.

> **Claude:** Acknowledged and kept as-is. Useful clarification for someone reading the docstring without the v0.2-plan.md glossary in hand. No code change required.

**Your response (sign off if you want):**
Good

---

## Item 2 — `cellRadius` measure: max vs avg distance to corners?

**Where:** `src/Enumlib.jl` line 50 (your `#gh` comment).

**Your comment:**
> I wonder if we should change the cell radius to be not the max, but the *avg* distance from the center to the corners? Might break a lot of ties and maybe is more descriptive.

**Background.** Current `cellRadius(B)` (line 51 onward) Minkowski-reduces `B`, then returns the max distance from the cell center to any of the 8 corners. Used downstream by `radiusEnumeration.jl` to filter HNFs by radius threshold.

**Trade-offs of max vs avg:**

| Measure | Geometric meaning | Tie-breaking | Behavior on elongated cells |
|---|---|---|---|
| **Max** (current) | radius of smallest enclosing sphere | many ties between cells with different shapes but same outermost corner | dominated by the longest direction; nearly insensitive to other axes |
| **Avg** (your proposal) | typical lengthscale across all corners | finer (the 8 corner distances rarely coincide pairwise) | smoothly weights all axes; an elongated cell has lower avg than max |
| **RMS** | sqrt(mean of squared distances) | finer than max, less than avg's sensitivity to outliers | same family as avg but more "norm-like" |
| **Min** (inscribed-sphere radius) | "no atom inside the cell is closer than X to the wall" | finer than max | useful for steric / interaction-cutoff arguments |

**You're right that avg is more descriptive for tie-breaking.** For nearly-cubic cells, `avg ≈ max ≈ side·√3/2` — they don't differ much. For elongated supercells (slabs, vacuum-padded structures), `avg < max` significantly, and avg distinguishes shapes that max collapses.

**Caveat — breaking-change risk.** Changing `cellRadius`'s definition changes what `radEnumByXcellRadius`, `radiusEnumHNFs`, and `getSymInequivHNFsByCellRadius` return. The existing test corpus has at least one radius-enumeration test (per the original Phase 3 inventory). Switching to avg would break that test if its expected counts depend on the current max-radius cutoff. Worth re-running before deciding.

**My lean: defer the decision to chunk 4 (`SupercellSelection`).** That's the chunk that introduces `RadiusBound{D}` as a user-facing type. There's a natural design question there: which radius measure should `RadiusBound` use? Options I'd put on the chunk 4 table:

1. **Keep `cellRadius` as max** (current default), but expose the choice via a kwarg or a strategy type: `RadiusBound(max_radius = 3.0, measure = :max)` vs `:avg` vs `:rms`.
2. **Change the default to avg** with a `legacy_max=true` escape hatch for users reproducing old behavior.
3. **Provide both as named functions** (`cell_radius_max`, `cell_radius_avg`, `cell_radius_rms`) and let the user pick.

For chunk 2.1, this is out of scope — `cellRadius` isn't part of chunk 2's deliverables. **My proposal: log this as a chunk 4 design question and address it deliberately when we get there.** I'll put a TODO on the existing `cellRadius` line in code so it's surfaced when we revisit.

**Your response:**
Defer to chunk 4, but we don't decide there...I'm already sure that I want to do that. Let's pull the trigger in chunk 4 and fix the downstream problems it causes.

---

## Item 3 — `coloring_hash` / `coloring_unhash` rename (chunk 2.1, done)

**Where:** `src/Enumlib.jl` lines ~163–187.

Renamed:
- `hash(mul, c)` → `coloring_hash(mul, c)`
- `hash2coloring(idx, k, n)` → `coloring_unhash(idx, k, n)` (also renamed the `hash` parameter to `idx` in the inverse function — was self-shadowing on top of the Base shadow!)

Call-site updates:
- `reduceColorings`: `hash(mul, ic[g])` → `coloring_hash(mul, ic[g])`
- `getUniqueColorings`: `Enumlib.hash(mul, c[g])` → `coloring_hash(mul, c[g])` (the `Enumlib.` qualifier was already there as a workaround — confirms someone hit this issue before)
- `getUniqueColorings` final return: `hash2coloring(i, k, n)` → `coloring_unhash(i, k, n)`

Cleanup that became possible afterward:
- Dropped the `Base.hash` qualifier from the `SymmetryOp` and `Site` hash bodies — the bare `hash(...)` now correctly resolves to `Base.hash` since the local shadow is gone.
- Removed the workaround comments in `symmetry_op.jl` and `site.jl`.
- Removed the "Active landmines" entry from `v0.2-plan.md` (the landmine is closed).

**Verification:**
- Chunk 1 tests: 38/38 pass.
- Chunk 2 tests: 63/63 pass.
- Existing FCC enumeration corpus (the `Colorings and HNF enumeration` testset that exercises `getUniqueColorings`): 9/9 pass — proves the rename didn't break the algorithm.

**Your response (sign off):**
Good

---

## Item 4 — Permanent fix path going forward

Now that the local shadow is gone, every new struct's `Base.hash(::OurType, ::UInt) = hash(field1, hash(field2, h))` can use the bare name without the qualifier dance. Going forward (chunks 3–6, e.g. when `Supercell`, `Enumeration`, `EnumeratedStructure` get hash methods), the standard pattern is the clean one:

```julia
Base.:(==)(a::Supercell{D}, b::Supercell{D}) where D = a.hnf == b.hnf && a.snf == b.snf
Base.hash(s::Supercell, h::UInt) = hash(s.hnf, hash(s.snf, h))
```

No special qualifier; no comment about the trap. The trap is gone.

**Your response (sign off):**
Good

---

## Summary

| # | Item | Action | Status |
|---|---|---|---|
| 1 | `site.jl` docstring tweak | None — kept as-is | Acknowledged |
| 2 | `cellRadius` max vs avg | Defer to chunk 4 design question | Awaiting your sign-off on deferral |
| 3 | `coloring_hash` rename + cleanup | Done in chunk 2.1; tests green | Awaiting your sign-off |
| 4 | Forward pattern for new `Base.hash` defs | Convention recorded | Awaiting your sign-off |

When items 2–4 are signed off, chunk 2.1 lands as one commit (the rename, the qualifier removal, the v0.2-plan.md updates) and we move to chunk 3 design.
