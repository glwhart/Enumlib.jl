# Chunk 2 — `Site{D}` + `Sites{D}` + `equate!` (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §6.4 (Site/Sites with Union-Find for equivalencies), §6.13 Q1 (dual constructor pattern), §6.10 (perovskite/slab usage examples), `docs/notes/v0.2-plan.md` Chunk 2.

**Goal:** describe a substitution problem on top of a `ParentLattice{D}`. Each parent-cell position gets a `Site{D}` carrying its allowed atomic species; a `Sites{D}` collection bundles them with an equivalencies relation (user-declared partition of site indices that must share their label).

---

## What lives in chunk 2

### `Site{D}` — one position with its allowed species

```julia
"""
    Site{D}

A single position in the parent cell where atomic substitution can happen. 
Carries the position itself plus the set of species labels allowed at this position.

The position is in fractional coordinates of the parent lattice (`ParentLattice{D}.A`),
matching the convention used by `ParentLattice{D}.dset`. Allowed labels are stored as
a `BitSet` of integers from `0:k-1`, where `k` is the number of species in the
problem.

A site is **inactive** if `length(allowed_labels) == 1` — only one species can occupy
it, so it has no configurational freedom and gets stripped from the labeling space
during enumeration. A site is **active** otherwise.
"""
struct Site{D}
    position::Vector{Float64}    # length D, in fractional coords of the parent
    allowed_labels::BitSet       # subset of {0, 1, ..., k-1}
end
```

**Constructors:**
- Inner: validates `length(position) == D`, `!isempty(allowed_labels)`.
- Outer: `Site(position, allowed_labels::BitSet)` infers `D` from `length(position)`.
- Convenience: `Site(position, allowed::AbstractVector{<:Integer})` — accept a vector and convert to `BitSet`. Lets users write `Site([0.5,0.5,0.5], [0,1])` instead of `Site([0.5,0.5,0.5], BitSet([0,1]))`.

**Predicates:**
- `is_inactive(s::Site)` → `length(s.allowed_labels) == 1`
- `is_active(s::Site)` → `!is_inactive(s)`

### `Sites{D}` — collection plus equivalencies

```julia
"""
    Sites{D}

A collection of `Site{D}`s plus an equivalence relation declaring which sites must
carry the same label across configurations. Equivalencies are *user-declared* — they
are NOT derived from the parent's space group. Use cases include slab geometries
(mirror-image layers must share composition; the slab vacuum breaks the parent's
3D periodicity that would otherwise tie them) and any other physical constraint the
user knows but the symmetry analysis can't see.

The equivalence relation is stored as a Union-Find (`IntDisjointSets`) over the site
indices. This makes transitivity automatic by data structure: if you declare site i ↔ j
and j ↔ k, the data structure correctly returns i, j, k as a single class without any
further work on the user's part.

Two-variant constructor:
- Incremental: build the `Sites` with no equivalencies first via `Sites([Site(...), Site(...)])`, then declare equivalencies one-by-one via `equate!(sites, i, j)`.
- Upfront partition: `Sites([Site(...), Site(...)], [[1,2], [3,4]])` validates the
  partition and builds the Union-Find in one shot. Suitable when the user already
  knows the equivalence classes from problem setup.

The two variants produce the same internal state and can be mixed (start with the
upfront variant and call `equate!` later).
"""
mutable struct Sites{D}
    list::Vector{Site{D}}
    equiv::IntDisjointSets       # over indices 1:length(list)
    # Note: only `equiv` is mutable (during construction-time `equate!` calls).
    # The `list` is treated as immutable by convention; we don't expose mutators.
end
```

**Constructors:**
- Inner variant 1 (incremental): `Sites{D}(list::AbstractVector{Site{D}}) where D` — initializes Union-Find with each site in its own singleton class.
- Inner variant 2 (upfront partition): `Sites{D}(list, classes::AbstractVector{<:AbstractVector{<:Integer}}) where D` — validates the partition (every site appears in exactly one class; no overlaps; no out-of-range indices) and builds the Union-Find by unioning each class's members.
- Outer constructors infer `D` from the site list.

**Mutators (only Union-Find is mutable):**
- `equate!(sites::Sites, i::Integer, j::Integer)` — declare sites `i` and `j` equivalent. Idempotent; transitive by virtue of Union-Find.

**Accessors:**
- `canonical(sites::Sites, i::Integer)` → root of equivalence class containing `i`. The "canonical representative" the dispatcher uses.
- `active_canonical_sites(sites::Sites)` → vector of `(index, Site)` pairs for the *active* sites that are *canonical* in their equivalence class. This is what the enumeration algorithm sees as the labeling space.
- `n_active(sites::Sites)` → count of active (≥ 2 allowed labels) sites.
- `n_canonical(sites::Sites)` → count of equivalence classes (length of `unique(canonical(sites, i) for i in 1:length(sites.list))`).
- `n_effective(sites::Sites)` → count of *active canonical* sites — the actual labeling-space dimension after stripping inactive sites and collapsing equivalencies.

---

## What's deliberately not in chunk 2

- **No species-name mapping.** Labels are integers `0..k-1`; the chemistry-friendly `Dict{Int,Symbol}` mapping (e.g., `0 → :Fe`, `1 → :Co`) is a v0.3 helper. Keeping chunk 2 focused on the configurational substrate.
- **No `Concentration` integration.** Chunk 6 territory.
- **No `ParentLattice`–`Sites` consistency check.** Question for you below: should the `Sites` constructor verify that the site positions match the parent's dset (or are otherwise contained in the parent cell)? My lean is that this is a *separate* validation that a higher-level `enumerate(parent, sites; ...)` does, not a `Sites` construction concern. Keeps `Sites` parametric on `D` only, not on a specific parent.

---

## Tests planned (`test/test_sites.jl`)

Closely matches the §6.10 patterns in the design doc:

1. **`Site` validation.** Position-length check; `BitSet` non-empty check; the convenience `Site(p, [0,1])` form converts to BitSet correctly.
2. **`is_active` / `is_inactive`.** Active and inactive cases.
3. **`Sites` incremental construction.** Build with empty equivalencies; `n_active`, `n_canonical`, `n_effective` all match expectations.
4. **`Sites` upfront-partition construction.** Build with `[[1,2], [3,4]]`; verify Union-Find state matches; `n_canonical = 2`; `n_effective` correct after factoring active vs inactive.
5. **`Sites` upfront-partition validation.** Reject overlapping classes (`[[1,2], [2,3]]`); reject out-of-range index; reject empty class.
6. **`equate!` idempotence and transitivity.** `equate!(s, 1, 2); equate!(s, 2, 3)` results in `canonical(s, 1) == canonical(s, 3)` even though we never explicitly equated 1 and 3.
7. **Perovskite ABO₃ pattern (§6.10 Pattern A).** 5 sites: A and B substitutional with `BitSet([0,1])`; three O sites with `BitSet([2])` (inactive). `active_canonical_sites` returns just A and B; `n_effective == 2`.
8. **Slab pattern (§6.10 Pattern B).** N=4 layers, each with full substitution `BitSet([0,1])`; pair (1,4) and (2,3) via `equate!`. `n_effective == 2` (one canonical per mirror pair).
9. **Mixed construction.** Start with upfront `[[1,2]]`, then `equate!(s, 3, 4)` later. Verify final state has two equivalence classes.

---

## Open questions for you (chunk 2 design)

1. **`Sites` consistency with `ParentLattice`.** Should `Sites` constructors require the positions to match the parent's `dset`, or to lie within `[0,1)^D` (anywhere in the parent cell), or no constraint? Three options:

   - **A:** No constraint at construction. The site positions are just labels (Float64 vectors); the `enumerate(parent, sites)` entry validates them against the parent. Cleanest separation; `Sites` is parametric on `D` only.
   - **B:** Require positions in `[0,1)^D` (silent canonicalization via `mod(., 1)`, like `ParentLattice` does for the dset). Catches user errors at construction time.
   - **C:** Require positions to *exactly* match the parent's dset. Strongest validation, but tightly couples `Sites` to a specific `ParentLattice`.

   My lean: **A** for v0.2 — keep `Sites` independent of any specific parent. Validation happens at `enumerate(...)` boundary. Easy to tighten later.
> Let's do A

> **Claude:** Locked: option A. `Sites` constructors don't touch parent positions; cross-validation lives in `enumerate(parent, sites)`.

2. **`Site` position type.** `Vector{Float64}` (current proposal) vs `SVector{D,Float64}` (StaticArrays, faster but adds a dep). For chunk 1 I went with `Vector{Float64}` to mirror Spacey's representation. Keeping consistent for chunk 2 unless you have a reason to introduce StaticArrays now.
> Should spacey have considered static arrays? If that's the only reason to lean away from staticarrays here, maybe we should consider updating spacey to use static arrays. Why did we not consider static arrays for spacey when we were refactoring it?

> **Claude:** Honest answer first: I don't know what trade-offs you weighed during the Spacey v0.7→v0.8 refactor — that work was done outside our session, before I joined the project. I can only reason about it now from the code. Looking at Spacey v0.8.0 source:
>
> - `Crystal` struct holds `A::Matrix{Float64}` (3×3 basis), `r::Matrix{Float64}` (3×N positions), `a::Vector{Int}` (N atom-types).
> - `SpacegroupOp` struct holds `R::Matrix{Int}` (3×3 rotation), `τ::Vector{Float64}` (3-vector translation).
>
> **Would StaticArrays have helped?** Yes, measurably. The hot loops in `spacegroup` are over the symmetry operations — for each candidate (R, τ), `isSpacegroupOp` does ~N matrix-vector multiplies. With `Matrix{Int}`, each `R * v` allocates a new `Vector{Int}` (heap allocation, GC pressure). With `SMatrix{3,3,Int}`, the compiler unrolls the multiplication into 9 multiplies + 6 adds, no allocation, and the result is a stack-allocated `SVector{3,Int}`.
>
> **Why this matters for Enumlib too:** `getPermG` (chunks 3+) calls the parent's space-group ops in similarly hot loops, applying each rotation to each supercell site. The same allocation savings would apply.
>
> **The trade-off:** StaticArrays adds a dep, restricts the dimension at compile time (3 means 3, not "some integer"), and makes some Julia idioms slightly different (`SMatrix(...)` constructors, no in-place mutation, etc.). For Spacey, the trade-off probably tilts toward "yes, do it" because Spacey is performance-critical for large workflows. Same for Enumlib.
>
> **Three paths forward, ranked by my preference:**
>
> 1. **Defer to v0.3.** Continue with `Vector`/`Matrix` for chunk 2 (mirroring Spacey). When v0.2 ships and we have a working enumerator, profile the hot loops and decide whether StaticArrays is worth the conversion based on real numbers. *Pro:* don't optimize on speculation. *Con:* changing field types on `Site` after users have started building things on top is breaking.
> 2. **Switch Spacey + Enumlib together for v0.2.** Submit a Spacey PR that converts `R::Matrix{Int}` → `SMatrix{3,3,Int}`, `τ::Vector{Float64}` → `SVector{3,Float64}`, etc. Update Enumlib's `SymmetryOp{D}` and chunk 2's `Site{D}` to match. *Pro:* both packages get the speedup; types are correct from the start. *Con:* coordinated change across two packages; modest delay (Spacey PR + register a v0.9.0).
> 3. **Switch only Enumlib's wrapper types now; convert at the Spacey boundary.** Inside Enumlib, `SymmetryOp{D}` uses `SMatrix`/`SVector`; the constructor that takes a `Spacey.SpacegroupOp` does the conversion. *Pro:* doesn't block on Spacey. *Con:* the conversion happens on every `spacegroup` call (allocation savings only inside Enumlib's loops, not in Spacey's own hot path). And the path-2 work has to happen eventually if Spacey is also performance-critical.
>
> **My lean: option 1 (defer to v0.3) for chunk 2.** Reasons: (a) we don't yet know whether the Spacey/Enumlib loops are actually hot enough for StaticArrays to matter — for a 4-site fcc enumeration with 7 HNFs and ~15 colorings, we're talking microseconds either way; (b) Spacey just hit v0.8.0 and is awaiting registry; piling another breaking change on top before v0.2 ships is fragile; (c) chunk 2 is about substrate types (Site/Sites), not hot-loop types — a Site's position is touched once per enumeration, not per labeling check.
>
> **The real win from StaticArrays will be in chunks 3 and 5** (Supercell.permutation_group construction; the labeling enumeration loop). At that point we'll have actual benchmark numbers and can decide based on data.
>
> **Concrete proposal:** keep `Vector{Float64}` for chunk 2 (Site, Sites). Log a v0.3 task: "Profile Spacey + Enumlib hot loops; if speedup is meaningful, propose Spacey StaticArrays PR + matching Enumlib type updates as a coordinated v0.3 release."

> **Claude (round 2):** Locked: `Vector{Float64}` for chunk 2. v0.3 profiling task added to v0.2-plan.md's v0.3 shopping list.

3. **`equate!` return value.** Returns `sites` (idiomatic Julia for chainable mutators) or `nothing` (more conservative)? My lean: return `sites` — supports `Sites([...]) |> sites -> equate!(sites, 1, 2) |> sites -> equate!(sites, 3, 4)`. Mild win.
> Your lean on this one

> **Claude:** Locked: `equate!` returns `sites`.

4. **Convenience constructor `Site(position, [0,1])` (vector form for allowed_labels).** Worth supporting in addition to `Site(position, BitSet([0,1]))`? My lean: yes — saves the user typing `BitSet(...)` for the common case. Costs zero at runtime.
> Yes

> **Claude:** Locked: both constructor forms supported.

5. **What does `Base.show(io, sites::Sites)` print?** My current sketch:
   ```
   Sites{3} with 5 sites (3 active, 2 canonical equivalence classes)
     site 1: [0.0, 0.0, 0.0]    species {0, 1}
     site 2: [0.5, 0.5, 0.5]    species {0, 1}
     site 3: [0.5, 0.5, 0.0]    species {2}              [inactive]
     site 4: [0.5, 0.0, 0.5]    species {2}              [inactive]
     site 5: [0.0, 0.5, 0.5]    species {2}              [inactive]
     equivalencies: (none) | classes [{1,2}, {3,4,5}]
   ```
   Good? Too verbose? Anything missing?
> Not too verbose. User-facing functions that help debug or inform should tend to avoid being terse. Clear and complete, easy for the human to parse, is better than short

> **Claude:** Locked: current sketch ships. Filing the principle for future `Base.show` methods (Supercell, Enumeration, etc.): clear-and-complete over short-and-clever. Adding a one-liner to the v0.2-plan working agreement.

6. **`Sites` test coverage of edge cases.** Specific cases I'm not yet listing:
   - Single-site `Sites` (1 site, no equivalencies). Trivial; do we test it?
   > Test it for what? What kind of errors? Or what invariants?
   - All-inactive `Sites` (every site has `BitSet([0])`). The labeling space is empty / trivial. Should `enumerate(parent, all_inactive_sites)` return one structure (the trivially-locked one) or throw `EmptyEnumerationError`?
   > Probably throw error, don't you think? Could there be a use case for enumerate() on all inactive sites? I can't think of one, can you?
   - All-equivalent `Sites` (one big equivalence class). `n_effective == 1` (or 0 if all inactive). Realistic for the slab case in the limit.
> This one might have a use case. 

   My lean: include the single-site and all-equivalent cases in tests; defer the all-inactive question to chunk 5 (when we have `enumerate(...)` to test against).

> **Claude responses to your three sub-questions:**
>
> **Single-site test — for what?** Fair question. Concrete invariants the test pins down:
> - **Boundary case for partition logic:** With 1 site, `n_canonical(s) == 1` and `equate!(s, 1, 1)` is a no-op (and shouldn't crash). The Union-Find data structure is sometimes brittle at size 1 in other libraries; this test confirms `IntDisjointSets(1)` works as expected.
> - **Iteration boundary:** `active_canonical_sites(s)` should return either `[(1, site)]` (if active) or `[]` (if inactive), not crash. The test exercises both.
> - **Show formatting:** `Base.show` should produce a sane single-line description for the trivial case, not e.g. assume there's always > 1 site.
>
> So the test catches "did you accidentally write code that assumes ≥ 2 sites?" — a real class of bug at the size-1 boundary that wouldn't show up in the perovskite/slab tests. Worth keeping.
>
> **All-inactive: throw or return one structure?** I agree with you — throw. Use cases I considered for "return one trivially-locked structure":
> - **Frozen-composition validation pipeline:** user has a list of fixed candidate compositions and wants to "enumerate" each as a sanity check that the geometry is valid. But this isn't really enumeration; they should call `validate_geometry(parent, sites)` or build the structure directly. Forcing them through `enumerate` confuses the API.
> - **Scripted parameter sweeps:** in a loop over many `(parent, sites)` pairs, all-inactive is one degenerate case the script wants to silently skip. But `try/catch` on `EmptyEnumerationError` (which we already throw for other empty cases per Phase 7 §7.5) handles this idiomatically.
>
> No real use case I can think of either. Locking: `enumerate(all_inactive_sites)` throws `EmptyEnumerationError`. Consistent with the §7.5 design ("throw forces the caller to confront the mismatch"). Test for this lives in chunk 5.
>
> **All-equivalent — what use case?** Curious about your "this one might have a use case" — I can think of one but want to check it matches yours: **a single-species disordered approximation.** A user has a multi-layer slab and wants to enumerate all configurations where every layer carries the same (active) composition — i.e., the *whole slab* substitutes uniformly across layers. This is the limit of equating all layers; the result is k different structures (one per species choice), validating that "uniform substitution" is what you wanted.
>
> Or maybe you're thinking of something else? In any case: lock the all-equivalent test in. n_effective should be 1 (or 0 if all inactive); active_canonical_sites returns one entry; the test catches subtle bugs in the canonical-iteration code.

---

## Implementation plan

1. Write `src/types/site.jl`. Includes `Site{D}` struct, `is_inactive`/`is_active`, validation, convenience constructors. ~40 lines + docstrings.
2. Write `src/types/sites.jl`. Includes `Sites{D}` mutable struct, both inner constructors, `equate!`, `canonical`, `active_canonical_sites`, `n_active`/`n_canonical`/`n_effective`, `Base.show`. ~120 lines + docstrings.
3. Update `src/Enumlib.jl` to `include` the new files and export the names.
4. Add `DataStructures` to `Project.toml` (we need `IntDisjointSets`).
5. Write `test/test_sites.jl` with the 9 testsets above. ~150 lines.
6. Run all tests (chunk 1 + chunk 2). Expect ~60+ passing.

**Estimated: one focused session.**

---

## After your sign-off

- I'll batch the implementation as one chunk-2 commit (`Chunk 2: Site{D} + Sites{D} + equate!`).
- Open `docs/notes/chunk2-review.md` for the review pass.
- Land chunk 2.1 with whatever revisions surface.
- Then chunk 3 (`HNF{D}` + `Supercell{D}` + `getSymInequivHNFs`) — first chunk that touches the 2008 algorithm port.

**Sign off below or annotate items 1–6 inline:**

Looks good, but see my inline comments above that section first. Let's nail down those before implementing. Also, check the files from chunk1 for inline comments. I revisited one or two of those.

> **Claude — round 1 status:**
>
> **Locked:**
> - Item 1 (consistency check): option A — no constraint at construction.
> - Item 3 (`equate!` return): returns `sites` for chainability.
> - Item 4 (vector-form constructor): yes.
> - Item 5 (`Base.show` format): current sketch; principle "clear and complete over terse" added to the working agreement.
> - Single-site test: included; pins down size-1 boundary invariants (n_canonical == 1, equate!(s,1,1) is a no-op, active_canonical_sites doesn't crash).
> - All-inactive: throws `EmptyEnumerationError` at chunk 5; no v0.2 use case identified.
> - All-equivalent: included; tests the limit-of-equating-everything case.
>
> **One question outstanding:** item 2 (StaticArrays). My recommendation: defer to v0.3, profile-driven. I'd appreciate a thumbs-up or pushback before I start writing code.
>
> **Chunk 1 inline comment addressed:** the `#gh` confusion about `D` in `symmetry_op.jl` line 30 — answered with an inline comment in the source file (substantial walkthrough of how D is bound at compile time vs. the function body's runtime boolean return) plus an expanded note in the v0.2-plan.md "Parametric type / type variable / `where`" glossary entry.
>
> **Once item 2 is locked, I'll write chunk 2.**
