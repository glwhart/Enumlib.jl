# Chunk 13b.3 — Algorithm + I/O docstring sweep + doctests (design)

Pre-implementation design doc. Edit any section directly — wording, restructuring, code, prose; I'll sweep `git diff` for your changes when you're done.

**Design references:** `docs/notes/documentation_plan.md` §3.4, §5.4 (locked 2026-05-08); `docs/notes/chunk13b-design.md` §3 (sub-chunk split), §4 (reference-page → symbol mapping); `docs/notes/chunk13b2-design.md` (the type-catalog precedent — same shape, same Q11 locks).

**Goal of 13b.3.** Same policy as 13b.2, applied to the algorithm and POSCAR-I/O surfaces. After 13b.3, the reference pages `concentrations.md` (multinomial primitives), `polya.md` (Pólya submodule), and `poscar-io.md` (POSCAR functions) all carry enough docstring content that 13b.4 can populate them via `@docs` blocks and raise `checkdocs = :none → :exports` cleanly.

`src/types/*.jl` was 13b.2; `docs/src/reference/*.md` `@docs` blocks + `checkdocs` raise are 13b.4.

---

## 1. Current state, by the numbers (audit 2026-05-13)

Scope: every symbol exported from `src/Enumlib.jl` whose definition lives in `src/algorithms/*.jl` or `src/io/*.jl`. Plus `getUniqueColorings_recursive_stabilizer` (in `algorithms/recursive_stabilizer.jl`) — un-exported per 13b.1 but worth polish since it's the internal driver and may surface in error messages.

- **12 public symbols total.** Algorithms: 3 multinomial primitives + 1 Polya submodule + 3 Polya functions (4 if you count `polya_count`'s and `aperiodic_orbit_count`'s two-method dispatches separately) = 8. I/O: 4 functions. Total: 12.
- **100% docstring coverage.** No gaps. All 12 already have a docstring block.
- **2/12 already use `jldoctest`.** `to_poscar` and `supercell_fractional_positions` (the latter is internal but co-documents the public `to_poscar`).
- **7/12 have prose-only examples.** Need conversion or expansion.
- **3/12 have no example at all.** `multinomial_unhash`, `polya_count`, `aperiodic_orbit_count`. Need fresh examples written.
- **3 "pre-flight" occurrences** in `src/algorithms/multinomial.jl` (×2) and `src/algorithms/polya.jl` (×1). Need the same wording sweep as 13b.2 (→ "enumeration resource check").

---

## 2. Scope & exclusions

**In scope (Reference pages: concentrations, polya, poscar-io):**

- `src/algorithms/multinomial.jl` — `multinomial_count`, `multinomial_hash`, `multinomial_unhash` (public). `getUniqueColorings_multinomial` is internal but commonly referenced in error messages — polish its docstring too, no doctest needed.
- `src/algorithms/polya.jl` — `module Polya` (submodule-level docstring), `polya_count` (2 methods), `cycle_structure`, `aperiodic_orbit_count` (2 methods).
- `src/algorithms/recursive_stabilizer.jl` — `getUniqueColorings_recursive_stabilizer` (internal post-13b.1). Polish docstring; no jldoctest required (not on a reference page).
- `src/io/poscar.jl` — `to_poscar`, `write_enumeration_archive`, `read_results`, `attach_results`. Plus the queued "pre-flight" terminology sweep doesn't apply here (this file doesn't mention it per the audit).

**Out of scope (deferred to 13b.4):**

- Reference page `@docs` blocks in `docs/src/reference/*.md` — that's the 13b.4 job; 13b.3 produces the docstring + doctest content those `@docs` blocks will inject.
- `checkdocs = :none → :exports` raise — 13b.4.

---

## 3. Approach: four categories of work

**(a) Add examples to the three example-less docstrings.**
- `multinomial_unhash`: small round-trip case with `multinomial_hash` (e.g., `mults = [2, 2]`, all 6 valid colorings round-trip).
- `polya_count` (both methods): pick a hand-verifiable small case. Identity-only group on 4 elements with `k = 2` gives `2^4 = 16`; cyclic $C_4$ on 4 elements with `k = 2` gives `(2^4 + 2^1 + 2^2 + 2^1) / 4 = 6` (the chunk-7 hand-computed reference).
- `aperiodic_orbit_count` (both methods): contrast with `polya_count` on the same cyclic $C_4$ case: aperiodic = 3 (drops the 1 fully-periodic orbit and the 2 period-2 orbits, keeping the 3 length-4 orbits). Locked chunk-7 reference.

**(b) Convert the seven prose-only docstrings to `jldoctest` where output is reproducible.**
- `multinomial_count`: prose says "negligible …"; convert to a `jldoctest` showing `multinomial_count([2, 2])` → `6`, `multinomial_count([3, 5])` → `56`.
- `multinomial_hash`: jldoctest with a small `mults` and a specific coloring showing the rank.
- `getUniqueColorings_multinomial`: internal helper; skip jldoctest (called only via `enumerate`).
- `cycle_structure`: prose example `[2, 1, 4, 3, 5]` → `[2, 2, 1]` is trivially convertible. Convert.
- `write_enumeration_archive`, `read_results`, `attach_results`: file-I/O; jldoctest would need `mktempdir` and timestamp filters. **Skip jldoctest; keep prose** (per 13b.2 Q11-equivalent: prose is right when output isn't safely reproducible). The existing prose examples are good.

**(c) Polya submodule overview docstring.**
- Add a brief module-level docstring at `module Polya` in `algorithms/polya.jl`. 5–10 lines: what the submodule contains, what it's for (Pólya counting math primitives, independently usable), reference to `count_inequivalent` as the public top-level. This is what 13b.4's `@docs Enumlib.Polya` block will inject onto `polya.md`.

**(d) Terminology sweep ("pre-flight" → "enumeration resource check").**
- `src/algorithms/multinomial.jl:24` — "during pre-flight, never in an inner loop" → "during the enumeration resource check, never in an inner loop"
- `src/algorithms/multinomial.jl:173` — "pre-flight cost gate" → "enumeration resource check"
- `src/algorithms/polya.jl:14` — "pre-flight count without enumerating" → "enumeration resource check (count without enumerating)"

Mechanical; matches the 13b.2 sweep exactly.

---

## 4. Sub-chunk split

Same as 13b.2: bounded enough to land as a single commit. Rough deltas:
- 3 new example blocks added (multinomial_unhash, polya_count, aperiodic_orbit_count): ~30 lines.
- 4 prose → jldoctest conversions (multinomial_count, multinomial_hash, cycle_structure): ~20 lines.
- Polya submodule overview docstring: ~10 lines.
- Terminology sweep (3 line edits): ~3 lines.
- Total: ~60 lines of docstring delta. No behavior change.

**Q1 (split or one commit).** My lean: one commit, like 13b.2. Confirm or split.
One commit

---

## 5. Open questions

**Q2 (polya_count two methods: separate docstrings or umbrella?).** Currently `polya_count(perm_group, k::Integer)` (unrestricted) and `polya_count(perm_group, multiplicities::AbstractVector)` (fixed multiplicity) each have their own docstring. Each is short. Option A: keep separate + 1 jldoctest each. Option B: merge into one umbrella docstring on the first method, with both call signatures shown. My lean: **A** — separate dispatch paths deserve separate docstrings, and `@docs` blocks in 13b.4 will display them in dispatch order. Confirm.
Keep separate

**Q3 (aperiodic_orbit_count two methods).** Same shape as Q2. My lean: A (separate). Confirm.
Confirm

**Q4 (polya_count doctest case picks).**
- Unrestricted: `polya_count([[1,2,3,4]], 2)` (identity-only group, k=2 colors) → `BigInt(16)`. Hand-verifiable: $2^4 = 16$ unrestricted colorings, all in their own orbits under the trivial group.
This seems to trivial to be useful; need a better example. Push back if you  disagree.

- Fixed-multiplicity: same group with `mults = [2, 2]` → `BigInt(6)`. Hand-verifiable: $\binom{4}{2} = 6$ colorings of 2-of-each on 4 positions, all distinct under the trivial group.
Same comment

Confirm, or want a less trivial example (e.g., the cyclic $C_4$ case showing the group actually folding orbits — at the cost of needing to construct the cycle perm group manually in the doctest)?
I want a less trivial example

**Q5 (aperiodic_orbit_count doctest case pick).** Same cyclic $C_4$ on 4 elements with `k = 2`: `polya_count` gives `6`, `aperiodic_orbit_count` gives `3` (drops the 1 fully-periodic + 2 period-2 orbits). The contrast is the *point* of the function — primitive vs Burnside. But the doctest needs `T_factors = (1, 1, 4)` (the SNF diagonal for $C_4$) supplied, which is a chunk-7-internal data structure. My lean: include the doctest with a brief inline comment explaining `T_factors`. Confirm, or skip the doctest and leave prose-only?
Confirmed.

**Q6 (multinomial_unhash doctest).** Round-trip case: `c = [0, 0, 1, 1]`, `mults = [2, 2]`, `n = 4`; `idx = multinomial_hash(mults, c)`; `multinomial_unhash(idx, length(mults), n) == c`. The doctest shows the round-trip in 4 lines. My lean: yes, this round-trip is the right shape — it documents the *inverse* relationship visibly. Confirm.
Yes

**Q7 (Polya submodule overview docstring content).** Proposed text:
```julia
"""
    module Polya

Pólya / Burnside math primitives used by Enumlib's [`count_inequivalent`](@ref).
Independently usable for general group-action orbit counting.

Exports:
- `polya_count(perm_group, k_or_mults)` — Burnside-averaged orbit count.
- `cycle_structure(permutation)` — cycle lengths of a single permutation.
- `aperiodic_orbit_count(perm_group, T_factors, k_or_mults)` — Möbius-corrected
  primitive (aperiodic) orbit count.

See `research.md` §4.6 (Rosenbrock 2016) for the algorithm digest and
research.md §5.2.1 for the super-periodicity policy that motivates the
aperiodic variant.
"""
module Polya
```

Confirm, or want different shape (more / less detail)?
Fine for now

**Q8 (I/O docstrings: try harder on jldoctest?).** `write_enumeration_archive`, `read_results`, `attach_results` are file-I/O. Doctesting them safely requires `mktempdir`, suppressing timestamped output, and accepting that the doctest is a small integration test inline in a docstring. The existing prose examples in `to_poscar` (which has a jldoctest) work; the other three's prose examples are likewise readable. My lean: **keep prose**. The 13b.2 precedent for non-doctestable output (default_memory_budget, format_bytes-of-platform-memory) was to keep prose. Confirm.
keep prose

**Q9 (recursive_stabilizer.jl docstring polish).** `getUniqueColorings_recursive_stabilizer` is now internal (13b.1 un-export). Should we still polish its docstring? My lean: yes — even internal-but-referenced functions benefit from solid docstrings, and the function shows up in error messages. No jldoctest required; just confirm the body is clean and references are current. Confirm.
yes, polish

**Q10 (terminology sweep extent).** The audit found 3 "pre-flight" mentions in algorithm files. I'll apply the same sweep as 13b.2 ("enumeration resource check" — Q9 lock there). Anywhere else worth checking — e.g., is there "pre-flight" in `docs/src/*.md` or `docs/notes/*.md`?

My lean for v0.2.0: sweep `src/` and `docs/src/` (user-facing), leave `docs/notes/*.md` historical scrapbook untouched (same precedent as 13b.1 item F). Confirm.
Yes, confirmed.

---

## 6. Out of scope for chunk 13b.3

- Reference page `@docs` blocks in `docs/src/reference/*.md` — that's 13b.4 (after this).
- `checkdocs = :none → :exports` raise — also 13b.4.
- Tutorial / how-to / explanation content (13c–13e).
- Internal rename of `getUniqueColorings_recursive_stabilizer` to snake_case (`recursive_stabilizer_enumeration` or similar) — non-breaking internal refactor; can land as a separate small commit any time.

---

## 7. Verification at sign-off

- `Pkg.test()` (or `include("test/runtests.jl")` per local-Manifest workaround): 1644+ tests still pass.
- `julia --project=docs -e 'using Documenter; doctest(Enumlib)'` passes — same CI step landed in 13b.2.
- `julia --project=docs docs/make.jl` builds clean.
- `git diff` of `src/algorithms/*.jl` + `src/io/poscar.jl` shows only docstring deltas + terminology rewrites (no executable-code change).

---

## 8. Numbered responses to your review pass

(I'll fill this in after your review pass on this design pad. Same flow as 13b.2.)

---

## 9. Summary

(Filled after sign-off.)
