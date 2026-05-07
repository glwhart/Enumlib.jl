# Chunk 6.2 — `include_superperiodic` kwarg retrofit (design)

Pre-implementation design doc per the working agreement. Sign off before I write code. Intentionally small.

**Design references:** `research.md` §5.2.1 (super-periodicity policy, locked); `docs/notes/chunk7-design.md` Round 3 + Resolution.

**Goal:** add the `include_superperiodic::Bool = false` kwarg to `enumerate(...)` and plumb it through both algorithm bodies. Default behavior unchanged — existing 406 tests stay green. Opt-in `true` returns the full orbit space.

**Why this lands before chunk 7.** The kwarg needs to exist on `enumerate(...)` before chunk 7 implements the matching kwarg on `count_inequivalent(...)` — otherwise chunk 7 would have to retrofit the older API in the same diff. Splitting it out keeps each chunk focused on one thing.

---

## What lives in chunk 6.2

### 1. `enumerate(...)` gains the kwarg

```julia
function Base.enumerate(parent::ParentLattice{D}, sites::Sites{D};
                        supercells::SupercellSelection,
                        concentration::Union{Nothing, Concentration, ConcentrationRange} = nothing,
                        algorithm::Symbol = :auto,
                        memory_budget::Int = default_memory_budget(),
                        on_overflow::Symbol = :error,
                        partition_threshold::Int = 100,
                        on_partition_overflow::Symbol = :error,
                        include_superperiodic::Bool = false,   # ← new
                        skip_preflight::Bool = false) where D
    ...
end
```

Plumbed into `_enumerate_exhaustive(...)` and `_enumerate_multinomial(...)` as a positional or trailing-kwarg parameter.

### 2. `getUniqueColorings(k, perm_group)` — chunk 5's body, kwarg added

Current logic (`src/Enumlib.jl` line 318):

```julia
for (i, ic) in enumerate(CartesianIndices(idx))
    c = reverse(Tuple(ic))
    if !hashTbl[i] continue end
    for (ig, g) ∈ enumerate(pG[2:end])
        test = coloring_hash(mul, c[g]) + 1
        if test > i || test == i && ig < n   # ← second clause is the super-periodicity drop
            hashTbl[test] = false
        end
    end
end
```

The clause `test == i && ig < n` says: "if some non-identity element from the first `n-1` group elements (the non-identity translations) maps `c` to itself, drop it." 
> This is because the first n elements of the group are all pure translations?

**Yes — exactly that.** Confirmed by reading `getPermG` (`src/Enumlib.jl` line 290):

```julia
for iR ∈ rotGrp           # outer: rotations
    for iT ∈ tGrp         # inner: translations
        push!(perm, iR[iT])
    end
end
```

The outer loop is rotations and the inner loop is translations, so `perm[1..n]` is the identity rotation composed with the full $n$-element translation subgroup. `perm[1]` is the full identity (identity rotation × identity translation); `perm[2..n]` are the $n-1$ non-identity pure translations. After that, `perm[n+1..2n]` is the first non-identity rotation × all translations, and so on.

So in the inner loop `for (ig, g) ∈ enumerate(pG[2:end])`, the index `ig` runs `1, 2, ..., length(pG)-1`, and the condition `ig < n` selects exactly `ig ∈ 1..n-1` — which corresponds to `pG[2..n]`, the non-identity pure translations. A coloring fixed by any of those is super-periodic by the §5.2.1 definition.

Skipping that clause when `include_superperiodic = true` keeps super-periodic colorings.

Proposed signature:

```julia
function getUniqueColorings(k, pG; include_superperiodic::Bool = false)
    ...
    if test > i || (!include_superperiodic && test == i && ig < n)
        hashTbl[test] = false
    end
    ...
end
```

One-line condition change. The default-`false` path is byte-for-byte identical to the current behavior.

### 3. `getUniqueColorings_multinomial(perm_group, multiplicities)` — chunk 6's body

Current logic (`src/algorithms/multinomial.jl` line 188):

```julia
is_super_periodic = false
for ig in 2:n
    ig <= length(perm_group) || break
    permuted = coloring[perm_group[ig]]
    if permuted == coloring
        is_super_periodic = true
        break
    end
end

if is_super_periodic
    visited[idx + 1] = false
    continue
end
```

Proposed: wrap the entire super-periodicity check in `if !include_superperiodic`:

```julia
function getUniqueColorings_multinomial(perm_group, multiplicities;
                                        include_superperiodic::Bool = false)
    ...
    if !include_superperiodic
        is_super_periodic = false
        for ig in 2:n
            ig <= length(perm_group) || break
            permuted = coloring[perm_group[ig]]
            if permuted == coloring
                is_super_periodic = true
                break
            end
        end
        if is_super_periodic
            visited[idx + 1] = false
            continue
        end
    end
    ...
end
```

Default `false` preserves chunk 6 behavior exactly.

---

## What's deliberately NOT in chunk 6.2

- **`count_inequivalent` and the Möbius math.** Chunk 7. Chunk 6.2 only touches `enumerate(...)` and the two `getUniqueColorings*` algorithm bodies.
- **Smart defaults.** `research.md` §5.2.1 logged three v0.3 candidates (silent no-op when kwarg is moot, warn on multi-volume sweeps with `=true`, etc.). Chunk 6.2 ships the kwarg only — no smart inspection.
- **Documentation rewrite.** The user-facing docstring on `enumerate(...)` gets one sentence added describing the kwarg. The full v0.2 user docs are a v0.2.0 polish task.

---

## Tests planned (extend `test/test_enumerate.jl` and `test/test_concentration.jl`)

### Default-behavior preservation
1. **All 406 existing tests pass.** Whatever they assert at the default kwarg value continues to hold byte-for-byte.

### New `include_superperiodic = true` tests

2. **Cyclic n=4 binary on a synthetic perm-group.** Construct the 4-element cyclic perm-group `[[1,2,3,4], [2,3,4,1], [3,4,1,2], [4,1,2,3]]` directly. Then:
   - `getUniqueColorings(2, perm_group; include_superperiodic=false)` → 3.
   - `getUniqueColorings(2, perm_group; include_superperiodic=true)` → 6.
   - 3 = aperiodic count = (1/4)(2⁴ − 2²) (Möbius); 6 = full Burnside = (1/4)(2⁴ + 2² + 2¹ + 2²) — both hand-verifiable.

3. **FCC binary unrestricted at n=4 with `=true`.** Capture the actual count at implementation time; assert it as a locked reference. Per chunk 5 the `=false` count is 19; the `=true` count will be 19 + (number of super-periodic structures at n=4 across all 7 HNFs). Whatever number that is becomes the locked reference.

4. **FCC binary unrestricted at n=8 with `=true`.** Same — capture, lock. `=false` is 390.

5. **FCC binary at fixed concentration with `=true`.** At asymmetric concentrations (e.g., n=8 3:5) super-periodic is empty by the number-theoretic argument from §5.2.1, so `=true` count == `=false` count == 86. *Trip-wire test:* if these ever differ for an asymmetric concentration, something is wrong.

6. **FCC binary at n=8 50% (4:4) with `=true`.** Symmetric concentration — super-periodic structures exist (period-4 cells doubled). Lock the `=true` count at implementation time; `=false` is 94.

7. **`enumerate(...)` end-to-end at default.** `length(enumerate(parent, sites; supercells=VolumeRange(4:4))) == 19` (existing). Adding `include_superperiodic=false` explicitly returns the same 19. Adding `include_superperiodic=true` returns the locked test-3 reference.

### Internal consistency
8. **Default kwarg matches missing kwarg.** `enumerate(parent, sites; supercells=VolumeRange(4:4))` and `enumerate(parent, sites; supercells=VolumeRange(4:4), include_superperiodic=false)` produce *exactly* the same `Enumeration` (same length; same coloring multiset).

Total: 8 testsets, ~10–15 individual tests.

---

## Implementation plan

1. Add the kwarg to `enumerate(...)` in `src/enumerate.jl`. Plumb into `_enumerate_exhaustive` and `_enumerate_multinomial`.
2. Edit `getUniqueColorings` in `src/Enumlib.jl` — add the kwarg, change the one condition.
3. Edit `getUniqueColorings_multinomial` in `src/algorithms/multinomial.jl` — add the kwarg, wrap the super-periodicity loop in `if !include_superperiodic`.
4. Update docstrings on all four touched functions: one-sentence note on the kwarg.
5. Write the new tests (test cases 2–8 above) into `test/test_enumerate.jl` (for the synthetic + FCC unrestricted cases) and `test/test_concentration.jl` (for the FCC fixed-concentration cases). Capture the test-3, test-4, test-6 reference values during a one-shot implementation run; lock them as `@test`s.
6. Run all tests. Expect 406 + ~12 new = ~418 passing.
7. Land as commit `Chunk 6.2: include_superperiodic kwarg on enumerate(...)`.

**Estimated:** 30 minutes of code + 30 minutes of test writing including the reference-value capture.

---

## After your sign-off

- Implement chunk 6.2; review pass via `docs/notes/chunk6.2-review.md` if anything surfaces.
- Update `docs/notes/chunk7-design.md` to integrate the (now-existing) kwarg into chunk 7's plan.
- Sign off on the integrated chunk 7 plan; implement chunk 7.

**Sign off below or annotate inline:**

Your response:
