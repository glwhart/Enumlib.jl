# Chunk 5 — `Enumeration{D,L}` + exhaustive (2008) algorithm + `enumerate(...)` (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §5.2 (public API), §5.4 (decision tree), §5.6 (what `enumerate(...)` yields), §6.7 (labeling representation), §6.8 (Enumeration / EnumeratedStructure), Phase 4 §4.1 (Hart-Forcade 2008 algorithm). Plus `docs/notes/v0.2-plan.md` Chunk 5.

**Goal:** ship the v0.2-alpha milestone — the first working `enumerate(parent, sites; supercells, ...)` call against the new public API. Stitches everything from chunks 1–4 together, ports the Hart-Forcade 2008 algorithm into the new types, and introduces the user-facing output types `Enumeration{D,L}` and `EnumeratedStructure{D,L}`.

This is the biggest chunk yet. **Three distinct workstreams** that all have to land together:

1. **Output types** — `Enumeration{D,L}`, `EnumeratedStructure{D,L}`, plus the labeling-representation parametric `L`.
2. **The 2008 algorithm port** — wrap the existing `getUniqueColorings` into the new types; thread the `Supercell{D}` permutation group through correctly.
3. **The `enumerate(parent, sites; ...)` entry point** — top-level dispatch that ties chunks 1–4 + workstream 2 together.

Plus opportunistic cleanup of dead legacy code (`SuperTile`, `ColoredTile`, `coloringsOfHNFList`).

---

## What lives in chunk 5

### `EnumeratedStructure{D,L}` — one enumerated structure

```julia
"""
    EnumeratedStructure{D,L}

A single enumerated derivative structure: a reference to a `Supercell{D}` plus
the labeling that decorates it.

The parametric `L` is the labeling representation. For chunk 5 (v0.2-alpha) we
only support `L = Vector{Int8}` — the decoded form, ~n bytes per structure. The
Phase-6 design contemplates `L = Int64` (hash-based; compact) and `L = BigInt`
(for very-large enumerations) but those are deferred — `Vector{Int8}` is fine
for the test-corpus sizes (n ≤ 12).
"""
struct EnumeratedStructure{D,L}
    supercell_id::Int                # index into Enumeration.supercells
    labeling::L                      # Vector{Int8} for chunk 5
    hnf_degeneracy::Int              # 1 for chunk 5 (per chunk-3 reduction); reserved for ConcentrationRange in chunk 6
    labeling_degeneracy::Int         # for label-rotation duplicates; 1 by default
end
```

### `Enumeration{D,L}` — top-level result

```julia
"""
    Enumeration{D,L}

The output of `enumerate(parent, sites; supercells, ...)`. Holds the parent
lattice, the sites description, the list of symmetry-inequivalent supercells
encountered (shared across structures), and the structures themselves.

Iterable: `for s in enumeration; ...; end` yields `EnumeratedStructure{D,L}` values.
Indexable: `enumeration[i]` returns the i-th structure.
"""
struct Enumeration{D,L}
    parent::ParentLattice{D}
    sites::Sites{D}
    supercells::Vector{Supercell{D}}
    structures::Vector{EnumeratedStructure{D,L}}
end

# Iterator protocol — yields EnumeratedStructure{D,L} values.
Base.length(e::Enumeration) = length(e.structures)
Base.iterate(e::Enumeration, state=1) =
    state > length(e.structures) ? nothing : (e.structures[state], state + 1)
Base.eltype(::Type{Enumeration{D,L}}) where {D,L} = EnumeratedStructure{D,L}
Base.IteratorSize(::Type{<:Enumeration}) = Base.HasLength()
Base.getindex(e::Enumeration, i::Integer) = e.structures[i]
```

For chunk 5 the iteration is *eager* — `Enumeration` carries a fully-materialized `structures` vector. Phase 6 §6.8 specifies a `LazyEnumeration` for streaming output; that's deferred to a v0.3 follow-up. For the v0.2 test corpus sizes (≤ tens of thousands of structures), eager is fine.

### `to_labeling(s::EnumeratedStructure)` — the per-structure accessor

Per Phase 6 §6.7: convenience accessor that returns `Vector{Int8}` regardless of `L`.

```julia
to_labeling(s::EnumeratedStructure{D,Vector{Int8}}) where D = s.labeling
# (Future: methods for L = Int64 and L = BigInt that decode-on-access. v0.3+.)
```

### `enumerate(parent, sites; supercells, algorithm=:exhaustive, ...)` — entry point

```julia
"""
    enumerate(parent::ParentLattice{D}, sites::Sites{D};
              supercells::SupercellSelection,
              algorithm::Symbol = :exhaustive,
              memory_budget::Int = default_memory_budget(),
              on_overflow::Symbol = :error,
              skip_preflight::Bool = false) -> Enumeration{D,L}

Enumerate all symmetry-inequivalent derivative structures of `parent` decorated
by labelings drawn from `sites.allowed_labels`, over the supercells specified by
`supercells`.

For chunk 5 (v0.2-alpha):
- `algorithm = :exhaustive` is the only supported value (Hart-Forcade 2008).
  Concentration restriction (chunk 6 / 2012 algorithm) and the recursive
  stabilizer (chunk 8 / 2017) are not yet wired in.
- The pre-flight cost-estimator gate is a stub (always passes); the real
  estimator lands with chunk 7 (Polya).
- Multilattice (`length(parent.dset) > 1`) errors with a "v0.3 feature" message
  — the legacy `getPermG` / `getUniqueColorings` are single-lattice only and
  need to be extended to handle the n × n_D site count properly.
"""
function enumerate(parent, sites; supercells, ...)
    # 1. Validate: sites match parent's dset shape (chunk 5 stub)
    # 2. enumerate_hnfs(supercells, parent) -> Vector{HNF{D}}
    # 3. For each HNF, build Supercell(hnf, parent), which caches the
    #    permutation group.
    # 4. For each Supercell, run the 2008 algorithm (getUniqueColorings on the
    #    perm group) to get the labelings.
    # 5. Wrap each labeling in EnumeratedStructure{D, Vector{Int8}}.
    # 6. Bundle into Enumeration{D, Vector{Int8}}.
end
```

The signature roughly matches Phase 6 §6.10. Chunk 5 supports the no-concentration single-lattice path; chunk 6 adds concentration; multilattice is a v0.3 extension.

### `Base.enumerate` extension vs new function name

Two paths:
- **Path A:** Extend `Base.enumerate` with our new method. Users write `enumerate(parent, sites; ...)` (the unqualified `enumerate` resolves correctly since the signatures don't collide with Base's `enumerate(iter)`).
- **Path B:** Use a new function name like `derivative_structures` or `enumerate_structures`. Avoids any subtle dispatch confusion; the function name is more descriptive.

My lean: **Path A (extend `Base.enumerate`)** — Phase 5/6 design committed to this name; users find it via tab-completion; the dispatch is unambiguous because of the parametric types.
> Are there any other advantages to extending the Base function? What things do we get for free?

> **Claude:** Honest list of what extending `Base.enumerate` actually buys us. Some are real wins; some are genuinely nothing.
>
> **Real wins:**
> 1. **Tab-completion discoverability.** Once `using Enumlib` is loaded, typing `enum<TAB>` in the REPL surfaces `enumerate` as a candidate — *and* the docstring shown in `?enumerate` includes our method's signature alongside Base's. The user doesn't need to remember it's an Enumlib-specific name.
> 2. **No naming bikeshed.** `enumerate` is the obvious verb for what we're doing. Reaching for a synonym (`derivative_structures`, `enumerate_structures`) trades a familiar name for a longer, more domain-specific one — fine, but loses the immediate-recognition benefit.
> 3. **Idiomatic Julia.** Extending Base functions on user types is *the* mainstream Julia pattern. `Base.show`, `Base.hash`, `Base.length`, `Base.iterate`, `Base.det` — we've already extended five of these in chunks 1–4. `enumerate` joins the same family. Not a "we're being clever" choice; it's the path that matches what every Julia library does.
> 4. **No name collision warnings.** If we picked a new name, a future package using the same name (e.g., a hypothetical `Crystallography.derivative_structures`) would clash. With `Base.enumerate` we're extending a "blessed" name that the language itself expects to be multi-method.
> 5. **Multiple-dispatch routing for free.** `Base.enumerate(::AbstractVector)` (Base's iterator-with-index method) and `Base.enumerate(::ParentLattice, ::Sites; supercells=...)` (ours) coexist without dispatch ambiguity — Julia routes by argument types, not by name. Users can call both without conflict.
>
> **Things we DON'T get for free:**
> - Behavior. Implementation is 100% ours; Base contributes nothing.
> - Documentation. We still write our own docstring.
> - Tests. We still write our own tests.
> - Performance. The dispatch lookup cost is identical for our own name vs `Base.enumerate`.
>
> **One small risk:**
> - **Doc-string clash (cosmetic).** `?enumerate` shows multiple methods. Users skimming might see Base's `enumerate(iter)` first and miss ours, or vice versa. Mitigation: write a clear chunk-5 docstring that's distinctive ("Enumerate symmetry-inequivalent derivative structures..." vs Base's "Iterator yielding (index, value) pairs"). The two are different enough in tone and content that a reader skimming both methods will distinguish them.
>
> **Net assessment:** discoverability + idiomatic-Julia + no-name-clash are the three concrete wins. The rest is "doesn't hurt." Path A stays the right call. Logging the wins as a teachable principle: when adding a major operation on our types, prefer extending Base over inventing a name, *if* the operation conceptually fits Base's vocabulary.

---

## What chunk 5 cleans up (legacy code consolidation)

Per chunk 3 review item 3, the consolidation lands here. With chunk 5's new top-level entry point, the legacy code that's no longer reachable from new public-API call paths can be deleted.

**Likely deletions** (will verify by `grep`-ing call sites before committing):
- `struct SuperTile` — flagged "not yet used" in original. No callers.
- `struct ColoredTile` — same.
- `function coloringsOfHNFList(hnfs, k, LG)` — supplanted by `enumerate(parent, sites; supercells)`. Existing callers (if any) refactor.

**Keep** (still load-bearing for chunks 3–4 wrappers and the test corpus):
- `getAllHNFs`, `tripletList`, `basesAreEquiv` — used by `getSymInequivHNFs(n, parent)` chunk-3 wrapper.
- `getSymInequivHNFs(d, LG)` — used by chunk-3 wrapper and `RadiusBound.enumerate_hnfs`.
- `getFixingOps`, `getPermG`, `getTransGroup` — used by `Supercell{D}` constructor.
- `getColorings`, `reduceColorings`, `getSymEqvColorings_slow`, `getUniqueColorings` — used by the legacy test corpus and (after chunk 5) by the new `enumerate` entry indirectly.
- `gCoordsToOrdinals`, `ordinalToGcoords`, `getCartesianPts`, `getOrdinalsFromCartesian`, `checkCartesianPt`, `get_nonzero_index` — utilities that may be needed for the multilattice extension or chunk 11's POSCAR writer.

**Possibly move** (some of the keeps could relocate from `LatticeColoringEnumeration.jl` to a more appropriately named file):
- The HNF helpers (`getAllHNFs`, `tripletList`, `basesAreEquiv`) feel more naturally at home next to `src/types/hnf.jl`. But moving = touching imports + unlikely to change behavior.
- I'd defer the file-organization cleanup to a v0.3 polish pass. Chunk 5 keeps the deletions minimal and load-bearing.

**My lean:** delete `SuperTile`, `ColoredTile`, and `coloringsOfHNFList` only. Leave file organization for a later polish pass. Doesn't shrink `LatticeColoringEnumeration.jl` to nothing, but does close the chunk-3-review item.
> We can wait to do the file reorg later, but I think it's clear that with all the refactoring we are doing that we should be able to come up with a better organization.

> In fact, as a bit of a tangent, I notice that you favor lots of small files (100-200 lines) rather than 2-3 large files (my normal workflow). What do you think are the pros and cons of each approach? (You have essentially the entire world's experience to draw on.)

> **Claude:** Both approaches have merit; the right answer depends on the project's stage and audience. Here's the honest trade-off, drawing on the broader pattern across published libraries vs solo-author research code:
>
> ### Pros of many small files (the pattern I've defaulted to)
>
> - **Single-responsibility files are faster to grok.** A file named `site.jl` containing just `Site` is faster to understand on first read than the same code as part of a 1000-line `types.jl`.
> - **Better grep / search.** `grep -rn 'function basis' src/` lands on one file, not the middle of a long one.
> - **Easier code review.** Reviewers (you, in chunk-N-review.md) read one file at a time without scrolling fatigue. Smaller diffs per file.
> - **Easier reorganization.** Moving a small file to a new location is one operation; moving a section of a big file requires surgical extraction.
> - **Better git history per concept.** `git log src/types/site.jl` shows just Site's evolution. With one big file, `git log` mixes concept changes.
> - **Less merge-conflict risk in multi-author setups.** Two devs editing different small files don't conflict; two editing the same big one do.
> - **Bias toward decoupling.** When concepts have their own files, you notice when `site.jl` accidentally reaches into `parent_lattice.jl` internals. Big files invite invisible coupling.
> - **Better tooling responsiveness.** Some IDEs / language servers slow down on large files.
>
> ### Cons of many small files
>
> - **Navigation overhead.** "Where's the SNF computation?" → check 3 files instead of scanning one.
> - **More boilerplate.** Each file has its own docstring header, imports, etc.
> - **Risk of fragmentation.** A concept spread across 5 files reads as 5 vignettes, not one narrative.
> - **More include lines.** Module file gets longer just from `include("...")` statements.
> - **Marginally more compile metadata** (negligible in practice).
>
> ### Pros of 2–3 large files (your normal workflow)
>
> - **Easier to scan for context.** Scrolling within one file is faster than alt-tabbing between files.
> - **Narrative arcs visible.** A long, tightly-coupled algorithm reads like a story when colocated; readers see the flow without context-switching.
> - **One source of truth per "module."** "The Enumeration code" is in one file; you know where to look.
> - **Lower include-graph complexity.** Fewer `include` statements; less attention to ordering.
> - **Faster onboarding for the author.** If you wrote it, your spatial memory of the file ("the SNF stuff is below the HNF construction") works immediately.
> - **Less cognitive switching cost.** When working on a feature that spans multiple concepts, having them all in view beats jumping files.
>
> ### Cons of 2–3 large files
>
> - **Larger merge conflicts.** Multi-author edits collide more.
> - **Harder to grok in pieces.** A 1000-line file is overwhelming for a new reader.
> - **Risk of "god files."** Without active discipline, the file accumulates everything tangentially related.
> - **Harder to test in isolation.** When the file has many couplings, you can't unit-test parts independently.
> - **Tools struggle at the extremes** — some language servers slow down past ~2000 lines.
>
> ### My honest read on the trade-off for Enumlib.jl
>
> The right answer depends on the *stage* of the project:
>
> - **Exploratory / research code, solo author, short-lived:** large files win. Less ceremony, faster iteration, narrative-forward.
> - **Published library, public API, future external contributors:** small files win. Discoverability, code review, merge safety.
> - **Enumlib.jl is moving toward the second category** — registered (or about to be), public API, expected to attract issues / PRs from materials-science users. The small-file pattern matches that trajectory.
>
> ### A middle path
>
> You're right that "100–200 line files" is biased small. A reasonable Julia community average is 200–400 lines per file — neither dramatically small nor sprawling. If we wanted to thicken the chunks-1–4 layout without rewriting:
>
> - **Merge `symmetry_op.jl` into `parent_lattice.jl`** (~150 combined). They're tightly coupled; SymmetryOp only exists for ParentLattice.
> - **Merge `hnf.jl` + `supercell.jl`** → `hnf_supercell.jl` (~180 combined). Same reasoning — HNF and Supercell are siblings.
> - Keep `site.jl` + `sites.jl` as a clear pair (or merge to `sites.jl`, ~220 combined).
> - Keep `supercell_selection.jl` separate (~150). It's its own subsystem.
>
> Net: 7 files → 4 files, average ~180 lines. Closer to your ergonomics without the small-file fragmentation.
>
> ### My recommendation
>
> Hold the current layout for chunk 5 (don't rearrange mid-implementation). After chunk 5 lands and the v0.2-alpha milestone is closed, we do a deliberate **file reorganization pass**: discuss the right boundaries, merge / split, settle on a final v0.2 layout. That's the natural moment to revisit (the codebase is at maximum information; we know the actual seams). I'll log it as a v0.2 polish task in v0.2-plan.md.
>
> Filing your preference for "thicker files" so I can bias toward consolidation in future chunks if it stays consistent. The chunk-1-through-5 small-file pattern was my drift, not a designed choice — adjustable if the consolidation pass surfaces a better layout.
---

## Tests planned (`test/test_enumerate.jl`)

The big ones — these regression-test the entire chunk 1→5 stack against the existing FCC corpus's structure counts.

### Output-type tests
1. **`EnumeratedStructure{D,L}` construction.** Build one manually with a hardcoded supercell_id and labeling; verify field access.
2. **`Enumeration{D,L}` iteration.** Build one with 3 hand-crafted structures; verify iteration yields all 3 in order, indexing works, length matches.
3. **`to_labeling(s)` accessor.** Returns `Vector{Int8}` for the chunk-5 default representation.

### `enumerate(parent, sites; supercells, ...)` — single-lattice
4. **FCC primitive, all-volumes, full enumeration matches existing test counts.** This is THE test that proves chunk 5 is correct. For FCC binary at n=8: total structures = 390 (existing test). For FCC binary at n=12: 7140. For FCC ternary at n=4: per-HNF [15, 15, 15, 15, 15, 12, 9] (sum 96). All from `enumerate(...)` with `VolumeRange(...)` and `Sites([Site(zero_pos, [0,1])])`.
5. **Single-volume.** `enumerate(parent, sites; supercells = VolumeRange(2:2))` returns just the structures at volume 2.
6. **Empty enumeration.** `enumerate(parent, sites; supercells = VolumeRange(1:1))` on a binary 1-cell — only 1 structure (or 2, depending on label-rotation handling).
7. **`ExplicitHNFs`.** User-supplied HNF list passes through; results match what `Supercell + getUniqueColorings` would give.

### `algorithm` kwarg validation
8. **`algorithm = :exhaustive` works.** Default. Same as omitting.
9. **`algorithm = :multinomial` errors with "chunk 6+" message.** Reserved for chunk 6; not yet implemented.
10. **`algorithm = :something_else` errors.** Validate kwarg.

### Multilattice — graceful error
11. **`length(parent.dset) > 1` errors with "v0.3 feature" message.** HCP, perovskite — error cleanly with a suggestion.

### Cleanup verification
12. **Deleted types unreachable.** `SuperTile`, `ColoredTile`, `coloringsOfHNFList` don't exist (errors on lookup).

---

## Open questions for you (chunk 5 design)

1. **Eager `Enumeration` for chunk 5; lazy in v0.3?** I'm proposing eager: `Enumeration` carries a fully-materialized vector. Lazy iteration (Phase 6 §6.8 `LazyEnumeration`) is deferred. Reason: simpler chunk 5; lazy adds an iterator-state machine + channel-or-callback patterns that aren't worth the complexity for v0.2-alpha test sizes (≤ tens of thousands of structures). My lean: eager for chunk 5; lazy v0.3+.
> Agreed
2. **`enumerate(...)` vs new function name.** Path A (extend `Base.enumerate`) vs Path B (`derivative_structures` or `enumerate_structures`). Phase 5/6 design committed to Path A. My lean: Path A.
> Agreed, but see earlier comment.
3. **Multilattice — error vs partial support.** For chunk 5, parents with `length(dset) > 1` (HCP, perovskite, slab) need extending the `getPermG` to handle n×n_D sites. Two options:
   - **A:** Error cleanly with a "v0.3 multilattice" message. Limits chunk 5 to single-lattice, but chunk 5 stays focused.
   - **B:** Extend `getPermG` to handle n×n_D in chunk 5. Requires adding the dset-permutation logic from Hart-Forcade 2009 §IV. Larger chunk 5; touches more code.
   
   My lean: **A**. Multilattice deserves its own chunk; mixing it into chunk 5 doubles the scope. The chunk 5 deliverable is "single-lattice end-to-end works" — sufficient for the v0.2-alpha milestone.
> Agreed
4. **`hnf_degeneracy` and `labeling_degeneracy` fields on `EnumeratedStructure`.** Phase 6 §6.8 specifies these for tracking how many user-facing structures collapse to one canonical representative. For chunk 5 (no concentration restriction, the existing 2008 algorithm), both are basically always 1 — unless the user asks for non-collapsed output. Two options:
   - **A:** Carry the fields with default 1; compute properly in chunks 6+.
   - **B:** Drop them for chunk 5; add when chunk 6 needs them.
> A   
   My lean: **A**. The fields are cheap (8 bytes each); carrying them now means chunk 6 doesn't have to migrate the type.

5. **The pre-flight cost gate (`memory_budget`, `on_overflow`).** Phase 7 designed this; chunk 7 (Polya counter) implements the real estimator. For chunk 5, the gate is either: (a) a stub that always passes, or (b) defer the kwargs entirely until chunk 7. My lean: **(a)** — keep the kwargs in the signature so the public API is stable, but don't enforce the budget. Documents the future behavior; users can experiment with `memory_budget=...` even if chunk 5 ignores it.
> A
6. **Where do `EnumeratedStructure` and `Enumeration` live?** Two options:
   - `src/types/enumeration.jl` — both types in one file, ~80 lines together.
   - `src/types/enumerated_structure.jl` and `src/types/enumeration.jl` — split per type.
   
   My lean: same file (`src/types/enumeration.jl`). They're tightly coupled; splitting feels like over-organization.
> Same file
7. **The 2008 algorithm port — separate file or into `enumerate.jl`?** The exhaustive-algorithm body is ~50 lines of glue code (HNF list → supercells → per-supercell labelings → bundled `EnumeratedStructure`s). Could live next to the public `enumerate(...)` function in a single `src/enumerate.jl`. My lean: single `src/enumerate.jl` with both the public entry and the per-algorithm implementation. Algorithm dispatch (`:exhaustive`, `:multinomial`, `:recursive_stabilizer`) is one match-block; each branch calls into a helper. For chunk 5 there's only one branch.
> Agreed
---

## Implementation plan

1. Write `src/types/enumeration.jl` — `EnumeratedStructure{D,L}` and `Enumeration{D,L}` types + iteration protocol + `to_labeling`.
2. Write `src/enumerate.jl` — public `enumerate(parent, sites; ...)` entry; `:exhaustive` algorithm body; multilattice error; algorithm-kwarg validation.
3. Update `src/Enumlib.jl` — include both new files; export `enumerate`, `EnumeratedStructure`, `Enumeration`, `to_labeling`.
4. Delete `SuperTile`, `ColoredTile`, `coloringsOfHNFList` from `LatticeColoringEnumeration.jl`. Update exports / docstrings.
5. Write `test/test_enumerate.jl` — 12 testsets above. Includes the load-bearing FCC regression tests.
6. Run all tests. Expect ~280 passing (236 + ~45 new).

**Estimated:** one focused session, possibly two given the scope.

---

## After your sign-off

- Implementation lands as `Chunk 5: Enumeration + exhaustive (2008) algorithm + enumerate(...)`.
- `docs/notes/chunk5-review.md` opened for the review pass.
- Land chunk 5.1 with revisions.
- Chunk 5 closes the v0.2-alpha milestone.
- Then chunk 6 (Concentration + multinomial 2012 algorithm) for v0.2-beta.

**Sign off below or annotate items 1–7 inline:**

See my answers above.
