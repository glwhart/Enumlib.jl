# Chunk 4 — `SupercellSelection` (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §5.4 (decision tree), §6.2 (catalog), §6.6 (SupercellSelection types). Plus chunk 2 review item 2 (cellRadius max → avg switch). Plus `docs/notes/v0.2-plan.md` Chunk 4.

**Goal:** introduce a single user-facing abstraction for "which supercells should we enumerate over?" — replacing the implicit `n in volume_range` loop with a typed `SupercellSelection`. Three concrete subtypes (`VolumeRange`, `RadiusBound`, `ExplicitHNFs`) cover the v0.2 use cases. Plus the locked-in `cellRadius` max → avg switch.

This is a small, low-risk chunk: types are mostly thin wrappers, the dispatcher is one function, the algorithm-side changes are zero. The *interesting* work is the cellRadius switch and the test-corpus updates that follow.

---

## What lives in chunk 4

### `SupercellSelection` — abstract type

```julia
"""
    abstract type SupercellSelection end

User-facing description of "which supercells should we enumerate over?". Three
concrete subtypes cover the v0.2 use cases. The dispatcher (`resolve(::SupercellSelection,
parent)`) turns any selection into a concrete `Vector{HNF{D}}` that downstream
code can iterate over uniformly.

Replaces the implicit `n in volume_range` loop pattern that earlier phases used.
"""
abstract type SupercellSelection end
```

### `VolumeRange <: SupercellSelection`

```julia
"""
    VolumeRange(range::AbstractRange{Int})

Enumerate all symmetry-inequivalent HNFs whose volume `det(h)` lies in `range`.
The most common selection — covers the "I want all supercells of size 2 through 8"
use case.
"""
struct VolumeRange <: SupercellSelection
    range::AbstractRange{Int}

    function VolumeRange(range::AbstractRange{Int})
        all(n -> n >= 1, range) ||
            throw(ArgumentError("VolumeRange must have all volumes ≥ 1; got $range"))
        isempty(range) && throw(ArgumentError("VolumeRange must be non-empty"))
        new(range)
    end
end
```

### `RadiusBound <: SupercellSelection`

```julia
"""
    RadiusBound(; max_radius_ratio::Float64, volume_cap::Int = typemax(Int))

Enumerate symmetry-inequivalent HNFs whose Minkowski-reduced cell radius is
at most `max_radius_ratio` times the parent cell's own radius. The
`volume_cap` is a safety stop — without it, very large `max_radius_ratio`
values would scan unbounded volumes.

Per chunk 2 review item 2, the radius measure is the **average** distance
from cell center to corners (changed from max in chunk 4). See the
`cell_radius` discussion below for why.
"""
struct RadiusBound <: SupercellSelection
    max_radius_ratio::Float64
    volume_cap::Int

    function RadiusBound(; max_radius_ratio::Real, volume_cap::Integer = typemax(Int))
        max_radius_ratio > 0 ||
            throw(ArgumentError("max_radius_ratio must be positive; got $max_radius_ratio"))
        volume_cap > 0 ||
            throw(ArgumentError("volume_cap must be positive; got $volume_cap"))
        new(Float64(max_radius_ratio), Int(volume_cap))
    end
end
```

### `ExplicitHNFs{D} <: SupercellSelection`

```julia
"""
    ExplicitHNFs(hnfs::AbstractVector{HNF{D}})

Enumerate over a user-supplied list of HNFs. The dispatcher passes them through
unchanged (no further symmetry reduction — the user has already curated the
list). Useful for: domain-specific HNF filters, regression tests against
literature reference cases, hand-picked supercells the user wants to study.
"""
struct ExplicitHNFs{D} <: SupercellSelection
    hnfs::Vector{HNF{D}}

    function ExplicitHNFs{D}(hnfs::AbstractVector{HNF{D}}) where D
        isempty(hnfs) &&
            throw(ArgumentError("ExplicitHNFs must have at least one HNF"))
        new(collect(hnfs))
    end
end

# Outer constructor — infer D from the HNF list.
ExplicitHNFs(hnfs::AbstractVector{HNF{D}}) where D = ExplicitHNFs{D}(hnfs)
```

### `resolve(s::SupercellSelection, parent::ParentLattice{D}) :: Vector{HNF{D}}`

The dispatcher. Three methods, one per subtype:

- **`resolve(::VolumeRange, parent)`** loops through volumes in the range, calls `getSymInequivHNFs` per volume, concatenates.
- **`resolve(::RadiusBound, parent)`** loops volumes 1..volume_cap, computes each candidate HNF's cell radius (avg-distance measure), keeps those ≤ `max_radius_ratio × parent_cell_radius`, then symmetry-reduces.
- **`resolve(::ExplicitHNFs, parent)`** returns the user's list unchanged.

All three return `Vector{HNF{D}}`. Downstream code treats them uniformly.

---

## The cellRadius switch (chunk 2 review item 2)

Decided in chunk 2: switch from **max** distance (current) to **avg** distance (new) from cell center to corners. Avg gives finer tie-breaking and is more descriptive for elongated cells.

**What changes:**

- `cellRadius(B)` body: replace `max(norm.(...)...)` with `mean(norm.(...))`.
- The TODO marker placed in chunk 2.1 above `cellRadius` gets removed.
- All `radiusEnumeration.jl` functions inherit the new measure transparently — `radiusEnumHNFs`, `radEnumByXcellRadius`, `getSymInequivHNFsByCellRadius` all just call `cellRadius`.

**What breaks:**

The existing `radiusEnumeration.jl` tests are not currently in the test suite — let me check what tests exist for radius-based enumeration before locking the change.

Actually, on a quick `grep`, **there are no tests covering radius-based enumeration in the current corpus**. The legacy `radiusEnumeration.jl` functions have docstrings but no tests. Chunk 4's new `test_supercell_selection.jl` is therefore the *first* test corpus for radius enumeration. It can validate the new avg-distance measure directly, no tests to break.

This actually means:
- Switching cellRadius from max to avg is a clean change with no test breakage.
- Chunk 4 adds the *first* tests for radius-based enumeration (across `RadiusBound` + the legacy `radiusEnumHNFs`).

---

## Bug to fix as part of chunk 4

While reading the legacy code I noticed: my chunk-3 rename `getFixingLatticeOps` → `getFixingOps` left **two stale references** that the tests don't exercise:

- `src/LatticeColoringEnumeration.jl:5` — exports `getFixingLatticeOps` (no longer defined)
- `src/LatticeColoringEnumeration.jl:220` — call site in `coloringsOfHNFList`
- `src/radiusEnumeration.jl:39` — call site in `getHNFColorings`

The test suite passes because `coloringsOfHNFList` and `getHNFColorings` aren't exercised. They WOULD break if called. Chunk 4 fixes these as a prep task (they touch the same files as chunk 4's main changes).

---

## What's deliberately not in chunk 4

- **No public `enumerate(...)` entry point.** That's chunk 5+.
- **No labeling-side changes.** Chunk 5.
- **No deletion of `radiusEnumeration.jl`.** The legacy file gets re-pointed at the new `cellRadius`, but the legacy functions stay until chunk 5 cleanup deletes the file entirely.

---

## Tests planned (`test/test_supercell_selection.jl`)

### `VolumeRange` tests
1. **Construction validation.** Reject empty range, range with non-positive elements.
2. **`resolve` matches `getSymInequivHNFs` per volume.** For FCC at `VolumeRange(2:6)`, `resolve` returns the concatenation of `getSymInequivHNFs(2, parent)` … `getSymInequivHNFs(6, parent)`.

### `RadiusBound` tests
3. **Construction validation.** Reject non-positive `max_radius_ratio` and `volume_cap`.
4. **Empty result for tight bound.** `RadiusBound(max_radius_ratio = 0.5)` on simple cubic returns `[]` — no supercell can be smaller than the parent.
5. **`max_radius_ratio = 1.0` returns just the parent (volume 1).** The trivial `[1 0 0; 0 1 0; 0 0 1]` HNF is the only one.
6. **Non-trivial bound — confirm against a captured reference.** Capture the result of `RadiusBound(max_radius_ratio = 2.0)` on FCC during chunk 4 development (run once, lock in tests).

### `ExplicitHNFs` tests
7. **Construction validation.** Reject empty list.
8. **`resolve` is a no-op.** Pass in a list of 3 HNFs, get back exactly those 3, in order.

### `cellRadius` switch
9. **Avg-distance behavior.** For a 1×1×1 cube, avg-distance = sqrt(3)/2 ≈ 0.866 (same as max for a cube). For an elongated 1×1×4 box, avg-distance < max-distance. Capture both numerically.

### Bug-fix verification
10. **`coloringsOfHNFList` and `getHNFColorings` work after the rename fix.** Direct calls don't error.

---

## Open questions for you (chunk 4 design)

1. **`RadiusBound` field naming.** I have `max_radius_ratio` (max ratio of supercell-radius to parent-radius) and `volume_cap`. Alternative names:
   - `max_radius_ratio` vs `max_ratio` (shorter; mild ambiguity about what's being ratio'd)
   - `volume_cap` vs `max_volume` (latter is clearer)

   My lean: `max_radius_ratio` and `max_volume`. Verbose but unambiguous.
> Your lean is mine too

2. **What `cell_radius` definition for `RadiusBound`?** The chunk 2 decision was max → avg. Two follow-up questions:
   - Should we also expose `min_radius_ratio` (lower bound) for users who want a "donut" of supercell sizes? My lean: no, not for v0.2 — YAGNI; can always add later as an optional kwarg.
   - The avg switch makes the existing `cellRadius` function name slightly misleading (it returns the avg now, not "the radius"). Should we rename `cellRadius` → `avg_cell_radius` or similar? My lean: yes — once the meaning changes, the name should match. New name `avg_cell_radius`. This is a public-API rename that affects exports, but the function isn't currently used by any test or downstream caller, so the breakage is contained.
`avg_cell_radius`

3. **`ExplicitHNFs` validation.** Currently I just check non-empty. Should I also verify all HNFs have the same `D`? In Julia, `Vector{HNF{D}}` already enforces this at the type level — you can't mix `HNF{2}` and `HNF{3}` in one vector. So no extra check needed at construction. Confirm?
No extra check. Constructor contains the problem.

4. **`resolve` function name.** I'm calling the dispatcher `resolve(::SupercellSelection, parent)`. Alternatives: `expand`, `to_hnfs`, `materialize`, `enumerate_hnfs`. My lean: `resolve` — short, accurate, common pattern in Julia (`Pkg.resolve`, `URI.resolve`, etc.).
`enumerate_hnfs` (more familiar to this author despite moving away from common julia pattern)

5. **`resolve` return: `Vector{HNF{D}}` only, or a richer struct?** For `VolumeRange` and `RadiusBound`, the radius / volume info is computed during resolution — sometimes a downstream user might want it. Options:
   - **A:** Return just `Vector{HNF{D}}`. Simplest; downstream computes radius/volume on demand.
   - **B:** Return a richer `(hnfs, volumes, radii)` tuple. More info; tuple-destructuring at callsites.
   - **C:** Define a `ResolvedHNFs{D}` struct with fields `hnfs`, `volumes`, `radii`. Most structured.

   My lean: **A** for chunk 4. We can always introduce a richer return type later if a user needs the metadata. The radii are already easy to compute via `cellRadius.(parent.A * h.matrix for h in hnfs)`.
A

6. **The `cellRadius` rename.** If we go with `avg_cell_radius` (item 2), should we keep the old `cellRadius` name as a deprecated alias for one release cycle? Or hard-delete? My lean: hard-delete — no current users to break, and a soft-deprecation for an internal function adds clutter.
> Hard delete
---

## Implementation plan

1. Switch `cellRadius` → `avg_cell_radius` in `src/Enumlib.jl` (body changes max → avg; rename happens at the same time). Update the docstring. Drop the chunk-2.1 TODO marker.
2. Update the existing legacy callers in `radiusEnumeration.jl` to use the new name.
3. Fix the stale `getFixingLatticeOps` references (3 sites: 1 export, 2 call sites). Keep this in a separate logical group within the chunk 4 commit.
4. Write `src/types/supercell_selection.jl` with the abstract type + 3 concrete subtypes + their constructors.
5. Add `resolve` methods (one per subtype) — they can live in the same file or in a separate `src/types/resolve.jl`. Probably same file for chunk 4 (~40 lines total).
6. Update `src/Enumlib.jl` exports.
7. Write `test/test_supercell_selection.jl` with the 10 testsets above.
8. Run all tests. Expect 176 + ~20 new = ~196.

**Estimated: one focused session.**

---

## After your sign-off

- Implementation lands as `Chunk 4: SupercellSelection + cellRadius max→avg switch`.
- `docs/notes/chunk4-review.md` opened for the review pass (skeleton, plus any issues I flag during implementation).
- Land chunk 4.1 with revisions.
- Then chunk 5 (`Enumeration{D,L}` + the exhaustive 2008 algorithm + `LatticeColoringEnumeration.jl` cleanup).

**Sign off below or annotate items 1–6 inline:**

Your response:
