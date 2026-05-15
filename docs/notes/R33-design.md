# R33 — `EnumeratedStructure` orbit-size / degeneracy field (design)

Pre-implementation design doc for cross-repo request R33 (JuCE → Enumlib). Edit any section directly; I'll sweep `git diff` for your changes when you're done.

**Ticket reference:** `/Users/glh43/Library/CloudStorage/GoogleDrive-gus.hart@gmail.com/My Drive/Work/codes/JuCE.jl/cross_repo_requests.md` §R33.

**Goal.** Expose the **symmetry-orbit size** of each canonical labeling as a field on `EnumeratedStructure`. JuCE reads this and populates `Configuration{T}.degeneracy::Union{Nothing,Int}` — UNCLE's $d_F$ at the configuration level (HF 2008 Eq. 3).

JuCE's three use cases (per ticket):
1. Free-energy weighting in Monte Carlo simulations.
2. Convex-hull display ("how many degenerate-by-symmetry structures sit at this hull point?").
3. Phase-space coverage diagnostics in `RandomCoherenceMinimal` configuration selection.

---

## 1. Background: what's "orbit size"?

For a labeling `c` on a supercell with permutation group `G` (rotations of the supercell stabilizer × the supercell's translation subgroup, per `Supercell.permutation_group`):

- The *orbit* of `c` is `{σ(c) : σ ∈ G}`.
- The *stabilizer* is `Stab(c) = {σ ∈ G : σ(c) = c}`.
- Orbit-stabilizer: `|orbit(c)| × |Stab(c)| = |G|`.

The orbit size is the number of labelings that are equivalent to `c` under the supercell's full symmetry group — exactly what JuCE wants for weighting (a high-degeneracy structure represents many equivalent atomic arrangements and should weight accordingly).

**Existing `EnumeratedStructure` fields, for context:**

```julia
struct EnumeratedStructure{D,L}
    supercell_id::Int
    labeling::L
    hnf_degeneracy::Int          # "always 1 in chunk 5" placeholder for ConcentrationRange × HNF sharing.
    labeling_degeneracy::Int     # "always 1 in chunk 5" placeholder for label-rotation duplicate collapsing.
end
```

Neither of these is the orbit size R33 wants. They're reserved for different future-feature counts. R33 adds a 5th field with the orbit-size semantics.

> I'm questioning whether we need these two fields. Make a note and bring it up after v0.3.

> OK to add another field for config degeneracy

---

## 2. Naming

R33 offered three candidates. My pick + reasoning:

| Name | Reads | Conflict / overload |
|---|---|---|
| `orbit_size` | descriptive, mathematical | none in Enumlib |
| `degeneracy` | matches JuCE's field name | already two `*_degeneracy` fields exist |
| `multiplicity` | matches HF 2008 wording in places | conflicts with `multiplicities(c, n_total)` for per-species concentration counts |

**Q1.** My lean: **`orbit_size::Int`**. Confirm or override (e.g., `symmetry_orbit_size`, `orbit_cardinality`, ...).

> `orbit_size` for now at least

---

## 3. Implementation sketch

### 3.1 Type extension

Add a 5th field with a default value of 1 (matches the pattern for the other two `*_degeneracy` fields):

```julia
struct EnumeratedStructure{D,L}
    supercell_id::Int
    labeling::L
    hnf_degeneracy::Int
    labeling_degeneracy::Int
    orbit_size::Int

    function EnumeratedStructure{D,L}(supercell_id::Integer, labeling::L,
                                       hnf_degeneracy::Integer = 1,
                                       labeling_degeneracy::Integer = 1,
                                       orbit_size::Integer = 1) where {D,L}
        ...validation...
    end
end
```

Update `Base.:(==)`, `Base.hash`, `Base.show` to include the new field. Same field-by-field pattern as the existing implementations.

### 3.2 Computation

Single internal helper in `src/enumerate.jl`:

```julia
# Orbit size of a labeling under a permutation group. Uses the orbit-stabilizer
# theorem: |orbit| = |G| / |Stab|. Stabilizer membership: σ ∈ Stab(c) iff
# applying σ to c leaves c unchanged.
function _orbit_size(perm_group::AbstractVector, coloring::AbstractVector)
    stab_count = count(σ -> all(coloring[σ[i]] == coloring[i] for i in eachindex(coloring)),
                       perm_group)
    return length(perm_group) ÷ stab_count
end
```

Call sites: each of the three algorithm branches in `src/enumerate.jl` constructs `EnumeratedStructure`s. Compute `orbit_size` from `sc.permutation_group + coloring` just before each push:

```julia
# _enumerate_exhaustive (and the other two)
for coloring in colorings
    osz = _orbit_size(sc.permutation_group, coloring)
    push!(structures, EnumeratedStructure{D, Vector{Int8}}(sc_id, Int8.(coloring), 1, 1, osz))
end
```

### 3.3 Cost

`_orbit_size` is O(|G| × n) per surviving structure. For our chunk-5/6 sizes (|G| ~ 100, n ≤ 12), ~1200 ops per structure. Across the biggest enumeration (n=12 FCC binary, 7140 structures), ~8.5 million ops — negligible vs the enumeration cost. Storage: 8 bytes per `EnumeratedStructure`.

---

## 4. Sanity checks for testing

**Per-structure invariants:**
- `orbit_size ≥ 1` always.
- `orbit_size` divides `length(sc.permutation_group)`.

**Aggregate invariants (per supercell):**
- With `include_superperiodic = true`: `sum(s.orbit_size for s in structures_on_this_supercell) = k^n` (unrestricted) or `multinomial_count(mults)` (fixed concentration). This is the orbit-cardinality identity — every labeling lives in exactly one orbit.
- With `include_superperiodic = false` (default): the same sum, minus the super-periodic contributions. Useful as a cross-check via subtraction.

**Q2.** My lean: add ≥ 2 testset items in `test/test_enumerate.jl`:
- Unrestricted FCC binary n=4 with `include_superperiodic = true`: per-HNF, sum-of-orbit-sizes equals 2^n = 16. (Iterates over the 7 inequivalent HNFs.)
- Fixed-concentration FCC binary 4:4 at n=8: per-HNF, sum-of-orbit-sizes equals `multinomial_count([4, 4]) = 70`.

> Let's do even more than this

---

## 5. Open questions

**Q3 (storage strategy).** Add a 5th `Int` field (8 bytes per structure) vs compute lazily on demand via a method `orbit_size(s, perm_group)`?


- **Field (storage):** O(1) access, +8 bytes/structure, +O(|G|×n) work at enumerate time.
- **Lazy method:** O(|G|×n) per call, 0 bytes overhead, requires the perm_group at call site (so caller must hold the `Enumeration` to access `sc.permutation_group`).

JuCE wants `Configuration.degeneracy` populated once at conversion time — they don't need repeated lookups. Either strategy works for them.

My lean: **field**. Matches the existing pattern of pre-computing per-structure metadata at enumerate-time; downstream consumers (JuCE, future cluster-expansion code) read it as a simple struct field. The +8 bytes is negligible vs the labeling vector itself.


Confirm or override.
> Agreed, but are we always computing the orbit_size? Does that add much to the algorithm's overhead?

**Q4 (computation algorithm).** Orbit-stabilizer counting (proposed in §3.2) vs counting orbit-members during the algorithm's crossing-out step?

- **Orbit-stabilizer (proposed):** computed *after* the canonical labeling is found; one O(|G|×n) sweep per structure. Algorithm-independent — the same helper works for `:exhaustive`, `:multinomial`, `:recursive_stabilizer`.
- **Counting crossings:** computed *during* the crossing-out; the algorithms already iterate over the orbit when marking the bitmap. Slightly faster (~half the cost) but requires touching three algorithm bodies and the per-algorithm bookkeeping diverges.

My lean: **orbit-stabilizer**. Cleaner code, less algorithm-specific. The cost difference is in the noise.

Confirm.
> Agreed

**Q5 (`:recursive_stabilizer` integration).** This algorithm's tree-search machinery already tracks "parent stabilizer" / "residual stabilizer" at each level (the *shrinking* in the name). At a leaf, the parent_stab IS the labeling's stabilizer.

Two options for this algorithm:
- (a) Use the unified `_orbit_size` helper as elsewhere. Marginal extra cost.
- (b) Extract `|Stab(c)|` from the leaf-construction state (zero extra cost). Requires `_descend!` to thread the stabilizer count into the output.

My lean: **(a)** for v0.2.0 — code consistency over a small perf win. Revisit if profiling shows it matters.

Confirm.
> Agreed

**Q6 (backward compatibility / breaking change).** Adding a 5th field to `EnumeratedStructure`:

- Internal Enumlib construction sites (the three `_enumerate_*` functions in `src/enumerate.jl`) need updating to pass the new field. Straightforward.
- The inner constructor's `orbit_size::Integer = 1` default keeps every existing call site (no orbit_size passed) working.
- External code that PATTERN MATCHES on `EnumeratedStructure{D,L}(a, b, c, d)` (4 args) would break. JuCE doesn't do this per the cross-repo doc; users who construct `EnumeratedStructure` manually are rare. **Not a SemVer-breaking change** under the "additive struct field with default" pattern.

The existing `Base.:(==)` and `Base.hash` must extend to the new field for correctness. Doing so changes the equality semantics: two `EnumeratedStructure`s with the same supercell + labeling but different `orbit_size` are now `!=`. This SHOULDN'T happen in practice (`orbit_size` is deterministic given supercell + labeling), but the test suite should confirm.

**Q6.** Confirm "additive field, treat as non-breaking" or override (e.g., bump to a v0.3 milestone if you want to be strict about SemVer).
> Don't worry about SemVer. Agreed

**Q7 (documentation).** Reference docstring on `EnumeratedStructure` gets the new field. Plus:

- (a) **Minimal:** docstring + a jldoctest showing `s.orbit_size` on a small case.
- (b) **A new how-to recipe:** "Use orbit size as a configuration weight" — short page, single jldoctest, points at the use cases from R33 (MC weighting, hull display).
- (c) **Both.**

My lean: **(a) only for v0.2.0** — the field is a JuCE-facing data hook; user-facing usage docs can come once JuCE actually consumes it and we have a real workflow to show. Add the how-to in 13c/13f or a later cycle if user feedback motivates.

Confirm.
> Agreed

**Q8 (return to cross_repo_requests).** When R33 lands, mark §R33 ✅ Resolved on the JuCE side (same pattern as R49) pointing at the Enumlib commit hash. Confirm that's the workflow.
> Agreed

---

## 6. Out of scope for R33

- The other two cross-repo items (R50 multilattice, R6/R21 canonical fingerprint).
- Repurposing the existing `hnf_degeneracy` / `labeling_degeneracy` placeholder fields — they're distinct semantic concepts (per HF 2012 ConcentrationRange × HNF sharing and label-rotation collapsing). R33 adds a new field.
- A `Base.:(==)` for `Sites` — surfaced as a gap during R51 but not blocking; can land as a separate small commit when convenient.

---

## 7. Verification at sign-off

- `include("test/runtests.jl")`: existing tests pass + new R33 testset items pass.
- `doctest(Enumlib)` passes (with new orbit_size jldoctest on EnumeratedStructure).
- `make.jl` with `checkdocs = :exports` builds clean.
- Aggregate invariant verified on at least 2 cases (Q2).
- `git diff` shape: ~25 lines source (type + helper + three call-site updates), ~30 lines docstring, ~50 lines tests. ~100-line commit.

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass.)

---

## 9. Summary

(Filled after sign-off.)
