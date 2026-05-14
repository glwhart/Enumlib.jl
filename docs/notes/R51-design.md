# R51 — `Sites` convenience constructors from a `ParentLattice` (design)

Pre-implementation design doc for cross-repo request R51 (JuCE → Enumlib). Edit any section directly; I'll sweep `git diff` for your changes when you're done.

**Ticket reference:** `/Users/glh43/Library/CloudStorage/GoogleDrive-gus.hart@gmail.com/My Drive/Work/codes/JuCE.jl/cross_repo_requests.md` §R51 (surfaced by the dryrun.jl HCP example, 2026-05-14).

**Goal.** Add three convenience methods on `Sites` that take a `ParentLattice` and produce a fully-populated `Sites` without forcing the user to repeat the dset positions or wrap each label set in `BitSet(...)`.

Today (verbose):
```julia
parent = ParentLattice(Ahcp, [[0,0,0], [2/3, 1/3, 1/2]])
sites  = Sites([Site([0,0,0],       BitSet([0,1])),
                Site([2/3,1/3,1/2], BitSet([0,1]))])
```

After R51 (one line):
```julia
parent = ParentLattice(Ahcp, [[0,0,0], [2/3, 1/3, 1/2]])
sites  = Sites(parent, [0,1])
```

---

## 1. Scope

**In scope:**
- Three new constructor methods on `Sites` in `src/types/sites.jl`.
- Tests in `test/test_sites.jl` covering the dispatch matrix + error paths.
- Update to the [Describe substitution sites](../docs/src/how-to/describe-substitution-sites.md) how-to recipe — currently shows the verbose form; should show the new convenience form as the preferred path.
- Update the `Sites` reference docstring to mention the new constructors.

**Out of scope:**
- R50 (multilattice `enumerate` regime B). R51 lands the *builder* methods. The constructed `Sites` for multilattice cases will still be rejected by `enumerate(...)` until R50 ships — that's a separate item. R51 is a pure ergonomics improvement; no algorithmic gating.
- Renaming any existing constructor or the underlying field representation.
- Changes to `ParentLattice` itself.

---

## 2. Proposed method matrix

| Form | Signature | Semantics |
|---|---|---|
| **Uniform** (BitSet) | `Sites(parent::ParentLattice, labels::BitSet)` | every dset position gets `labels`. |
| **Uniform** (integer vector) | `Sites(parent::ParentLattice, labels::AbstractVector{<:Integer})` | as above; auto-wraps `labels` into `BitSet(labels)`. |
| **Uniform** (range) | `Sites(parent::ParentLattice, labels::AbstractRange{<:Integer})` | as above; idiomatic Julian `0:1`, `0:k-1`. |
| **Per-position** | `Sites(parent::ParentLattice, labels::AbstractVector{<:Union{BitSet, AbstractVector{<:Integer}}})` | `labels[i]` for dset position `i`. Length-checked against `ndset(parent)`. |
| **k-species shorthand** | `Sites(parent::ParentLattice; k::Integer)` | shorthand for `Sites(parent, 0:k-1)`. |

The first three are mutually exclusive by Julia dispatch (different argument types). The per-position form is unambiguous because its element type is `BitSet`/`Vector{<:Integer}`, distinct from a bare `Vector{<:Integer}` (uniform).

**Examples after R51:**

```julia
# Single-site binary
sites = Sites(parent, [0,1])           # uniform with integer vector
sites = Sites(parent; k=2)             # kwarg shorthand

# HCP binary (two sublattices, uniform labels)
sites = Sites(parent, [0,1])           # one line; auto-applies to all dset positions

# Heterogeneous (perovskite-style — gated on R50 regime C for enumerate)
sites = Sites(parent, [[0,1,2], [0]])  # ternary on first dset position, fixed on second

# k-species shorthand on a multi-site parent
sites = Sites(parent; k=3)             # ternary on every dset position
```

---

## 3. Dispatch corner cases

**Q1 (single-site parent, per-position form).** `Sites(parent_single_site, [[0,1]])` — `parent.dset` has length 1, the per-position vector has length 1. Length matches. Treated as per-position with one entry. Semantically equivalent to `Sites(parent_single_site, [0,1])`. Both work, both produce the same `Sites`. My lean: this is fine; no special handling needed.

Confirm or override.
> Fine, at least for now.

**Q2 (mismatched per-position length).** `Sites(parent_hcp, [[0,1]])` — `parent.dset` has length 2, per-position vector has length 1. Throws `ArgumentError` with a clear message: `"per-position labels has length 1 but ndset(parent) = 2"`. My lean: clear error, no fallback. Confirm.
>Agreed

**Q3 (`Vector{Any}` from mixed input).** `Sites(parent, [BitSet([0,1]), [0]])` — Julia infers `Vector{Any}` (or `Vector{Union{BitSet,Vector{Int}}}`, version-dependent). My dispatch needs `AbstractVector{<:Union{BitSet,AbstractVector{<:Integer}}}` to match. Should be fine on Julia 1.10+ but might surprise on edge cases. My lean: add a test exercising this exact mixed-eltype case; if Julia's inference returns `Vector{Any}` and dispatch fails, fall back to a `Sites(parent, labels::AbstractVector)` catch-all that detects per-position-ness at the element level.

Confirm or override (the catch-all method adds complexity; only worth it if real users hit this).
> Agreed

**Q4 (kwarg `k` validation).** `Sites(parent; k=0)` and `Sites(parent; k=-1)`: the underlying `Site` constructor will reject `BitSet()` (empty) with `ArgumentError("allowed_labels must be non-empty")`. My lean: rely on the existing validation cascade — no extra check needed at the kwarg layer. Confirm.
> Agreed

**Q5 (no-class equivalences).** The new constructors create a `Sites` with every site in its own equivalence class (the incremental-construction default). If the user wants upfront equivalence classes, they can chain: `equate!(Sites(parent, [0,1]), 1, 2)` or use the existing `Sites(list, classes)` form. My lean: not worth adding `Sites(parent, labels, classes)` as a 4th convenience method — too many overloads, the chain pattern is clear.

Confirm or override.
> Agreed

---

## 4. Implementation sketch

```julia
# In src/types/sites.jl, after the existing constructors:

"""
    Sites(parent::ParentLattice{D}, labels) where D
    Sites(parent::ParentLattice{D}; k::Integer) where D

Convenience constructors that take a `ParentLattice` and produce a `Sites`
without forcing the user to repeat the dset positions in `Site` constructor
calls.

[... rest of docstring ...]
"""

# Uniform forms — all route through BitSet
function Sites(parent::ParentLattice{D}, labels::BitSet) where D
    list = [Site{D}(pos, labels) for pos in parent.dset]
    return Sites{D}(list)
end

Sites(parent::ParentLattice, labels::AbstractVector{<:Integer}) =
    Sites(parent, BitSet(labels))
Sites(parent::ParentLattice, labels::AbstractRange{<:Integer}) =
    Sites(parent, BitSet(labels))

# Per-position form — labels[i] for dset position i.
function Sites(parent::ParentLattice{D},
               labels_per_position::AbstractVector{<:Union{BitSet, AbstractVector{<:Integer}}}) where D
    n = length(parent.dset)
    length(labels_per_position) == n ||
        throw(ArgumentError(
            "per-position labels has length $(length(labels_per_position)) " *
            "but ndset(parent) = $n"))
    list = [Site{D}(pos, BitSet(lbl)) for (pos, lbl) in zip(parent.dset, labels_per_position)]
    return Sites{D}(list)
end

# k-species shorthand.
Sites(parent::ParentLattice; k::Integer) = Sites(parent, 0:k-1)
```

Approximate delta: ~30 lines of new code + ~40 lines of docstring + ~80 lines of tests = ~150-line commit.

---

## 5. Test plan

New testset in `test/test_sites.jl`:

| Case | Expected |
|---|---|
| Single-site parent, `Sites(parent, [0,1])` | `Sites{3}` with 1 site, labels {0,1}, active. |
| Single-site parent, `Sites(parent, BitSet([0,1]))` | same as above. |
| Single-site parent, `Sites(parent, 0:1)` | same as above. |
| Single-site parent, `Sites(parent; k=2)` | same as above. |
| Single-site parent, `Sites(parent; k=3)` | `Sites{3}` with 1 site, labels {0,1,2}. |
| Multi-site (HCP) parent, `Sites(parent, [0,1])` | `Sites{3}` with 2 sites, both labels {0,1}. |
| Multi-site (HCP) parent, `Sites(parent; k=2)` | same as above. |
| Multi-site (HCP) parent, `Sites(parent, [[0,1,2], [0]])` | `Sites{3}` with 2 sites, labels {0,1,2} and {0}. |
| Multi-site (HCP) parent, `Sites(parent, [BitSet([0,1,2]), BitSet([0])])` | same as above. |
| Multi-site parent, `Sites(parent, [[0,1]])` (length mismatch) | `ArgumentError`. |
| Single-site parent, `Sites(parent, [[0,1]])` (length matches) | per-position form, one site with labels {0,1}. |
| `Sites(parent; k=0)` | `ArgumentError` (empty allowed_labels). |
| `Sites(parent; k=-1)` | `ArgumentError` (negative k → empty range → empty BitSet). |

---

## 6. How-to documentation update

The current `describe-substitution-sites.md` recipe shows the verbose pre-R51 form. Update to:
1. Lead with the new convenience constructor as the primary pattern.
2. Keep the verbose `Sites([Site(...), Site(...)])` form as the fallback / advanced section.
3. Show the heterogeneous (per-position) form as a separate worked example — flagged that `enumerate` will reject it until R50 regime C ships, but the *builder* works today.

**Q6 (how-to update scope).** Bundle the how-to rewrite into the R51 commit, or land R51 first and do the how-to update as a follow-up? My lean: **bundle** — the how-to without the new constructors is now slightly stale, and updating it is mechanical once the constructors land. Confirm.

> Bundle

---

## 7. Verification at sign-off

- `Pkg.test()` (via `include("test/runtests.jl")`): all existing tests pass + the new testset passes.
- `julia --project=docs docs/make.jl` builds clean with `checkdocs = :exports` + doctest on, zero warnings.
- `doctest(Enumlib)` passes — including any doctest blocks added in the `Sites` docstring for the new constructors.
- `git diff` shows: ~30 lines source, ~40 lines docstring, ~80 lines test, ~30 lines how-to rewrite. ~180-line commit.

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass. Same flow as the 13b/13c design pads.)

---

## 9. Summary

(Filled after sign-off.)
