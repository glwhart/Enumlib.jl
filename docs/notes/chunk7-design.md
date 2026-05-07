# Chunk 7 — `Enumlib.Polya` submodule + `count_inequivalent` (design)

Pre-implementation design doc per the working agreement. Sign off (or revise) before I write code.

**Design references:** `research.md` §4.6 (Rosenbrock 2016 numerical Pólya), §5.2 (`count_inequivalent` API), §6.9 (`InequivalentCount` type), §7.2 (cost estimator), `papers/RosenbrockEtAl_2016_NumericalPolyaEnumerationTheorem.pdf`. Plus `docs/notes/v0.2-plan.md` "Chunks 7–8" section.

**Goal:** ship a Pólya counter that gives users a true *count of inequivalent structures* without enumerating them. This is independently useful (cheap pre-flight: "how many would I get?"), and it's also the math engine behind chunk 7.5's `estimate_cost` / memory-budget gate.

**Decided up front: split chunk 7 in two.** The original v0.2-plan.md scoped chunk 7 as "Pólya submodule + `count_inequivalent` + `estimate_cost`." That's three workstreams in one. Reading the design more carefully, the natural cut is:

- **Chunk 7** (this doc): Pólya submodule + `count_inequivalent`. Math, numerics, and a public counting top-level. Self-contained; no changes to `enumerate(...)`. Adds the load-bearing reference test (Ag–Pt 15:17 → 1003 *count*, computable in seconds since we don't enumerate).
- **Chunk 7.5** (separate design doc, after this lands): `EnumerationCostEstimate`, `estimate_cost`, `EnumerationTooLargeError`, wire `enumerate(...)`'s pre-flight to actually use `estimate_cost`. Touches `enumerate.jl`; needs its own design pass.

If you want one bigger chunk instead, see Q1 below.

---

## Background — what Pólya gives us

Phase-7 §7.2 promised the user "ask first, run second": a function that returns the predicted structure count *without* generating any structures. The Pólya enumeration theorem (and its fixed-concentration extension) makes this possible in $O(|G|)$ time per supercell, where $|G|$ is the permutation-group size — milliseconds even for 100+ supercells.

**Two cases.** Both reduce to averaging "the number of colorings fixed by each group element" (Burnside's lemma):

1. **Unrestricted (no concentration).** For each permutation $\rho \in G$ acting on $n$ positions, the number of colorings fixed by $\rho$ is $k^{c(\rho)}$, where $c(\rho)$ = number of cycles in $\rho$. Sum over the group, divide by $|G|$ → orbit count. (Standard Pólya / Burnside.)

2. **Fixed concentration $a_1, \ldots, a_k$.** A coloring fixed by $\rho$ must be constant on each cycle. So we need to assign each cycle of $\rho$ a single color, such that the total cycle-length assigned to color $i$ equals $a_i$. The number of such assignments is the coefficient of $x_1^{a_1} \cdots x_k^{a_k}$ in the polynomial $\prod_j (x_1^{c_j} + \cdots + x_k^{c_j})$, where $c_j$ are $\rho$'s cycle lengths. Computable by dynamic programming (DP — fill a table indexed by partial-multiplicity vector, one cycle at a time, summing contributions). (Hart–Forcade 2012 §A.2; Rosenbrock 2016 implements this efficiently.)

**Why this is cheap.** A permutation's cycle structure is computed in $O(n)$. The polynomial-coefficient DP for case 2 has state $\prod_i (a_i + 1)$ and runs once per cycle of $\rho$. For our worst v0.2 case (Ag–Pt at $n=32$, $k=2$, $a = [15, 17]$): state $= 16 \times 18 = 288$; cycles per permutation $\le 32$; group size $|G| \approx 4896$; over 102 HNFs: ~$10^7$ DP-cell updates. Sub-second.

Compare: actually *enumerating* Ag–Pt 1003 is $\sim 10^{14}$ ops (chunk 6's identity-test rationale). Counting is 7 orders of magnitude cheaper.

---

## What lives in chunk 7

> **Note (Round 4 — post chunk 6.2 land).** This section originally sketched `polya_count` and `count_inequivalent` with no super-periodicity awareness. The integrated plan below threads the `include_superperiodic` kwarg (now live on `enumerate(...)` from chunk 6.2 — commit `013fa7f`) through `count_inequivalent`, and adds the Möbius-correction helper for the `false` branch.

### 1. `src/algorithms/polya.jl` — the math primitives + Möbius helper (~250 lines)

Wrapped in a submodule for namespacing (Q2-A):

```julia
module Polya

using ..Enumlib: ParentLattice, Sites, Supercell, HNF, Concentration, ConcentrationRange,
                 SupercellSelection, enumerate_hnfs, multiplicities, concentrations_in_range,
                 EmptyEnumerationError

export polya_count, cycle_structure, aperiodic_orbit_count

"""
    cycle_structure(perm) :: Vector{Int}

Cycle-length multiset of a permutation, sorted descending.
"""
function cycle_structure(perm::AbstractVector{<:Integer}) :: Vector{Int} ... end

"""
    polya_count(perm_group, k::Integer) :: BigInt
    polya_count(perm_group, multiplicities) :: BigInt

**Math primitive — always raw Burnside orbit count.** For a permutation `ρ` with `c` cycles, the number of k-colorings fixed by `ρ` is `k^c`; with fixed multiplicities, it's the polynomial-coefficient described below. Sum over the group, divide by `|G|`.

This is the *full* orbit count including super-periodic orbits. The aperiodic version is `aperiodic_orbit_count` (which calls this internally with Möbius signs).

Cost: O(|G| · n) for the unrestricted case; O(|G| · t · ∏(a_i + 1) · k) for fixed concentration where `t` is the cycle count.
"""
function polya_count(perm_group, k::Integer) :: BigInt ... end
function polya_count(perm_group, multiplicities::AbstractVector{<:Integer}) :: BigInt ... end

"""
    aperiodic_orbit_count(perm_group, snf_diagonal::NTuple{3,Int}, k_or_mults) :: BigInt

**Aperiodic orbit count** — orbits whose stabilizer in the supercell's translation subgroup is trivial. Computed via Möbius inversion over the subgroup lattice of T = Z/d_1 × Z/d_2 × Z/d_3 (the SNF diagonal):

    N_aperiodic = Σ_{H ⊆ T} μ(H, T) · ξ(H)

where ξ(H) is the orbit count of the induced (G/H)-action on the H-orbits of supercell positions (an `n/|H|`-position perm-group, computed via `polya_count` on the induced perm-group).

For T cyclic (SNF (1, 1, n)) the Möbius factors are number-theoretic μ; for non-cyclic T (e.g., SNF (1, 2, 4)) we enumerate subgroups of T directly. See implementation note 2 below.
"""
function aperiodic_orbit_count(perm_group, snf_diagonal, k_or_mults) :: BigInt ... end

# Internal: the DP that computes a single permutation's fixed-coloring count.
function _fixed_colorings_at_concentration(cycle_lengths, multiplicities) :: BigInt ... end

# Internal: subgroup enumeration of T given by SNF diagonal, plus Möbius coefficient.
function _subgroups_with_mobius(snf_diagonal::NTuple{3,Int}) ... end

# Internal: induced perm-group on H-orbits of supercell positions.
function _induced_perm_group(perm_group, snf_diagonal, H) ... end

end  # module Polya
```

**Implementation note 1 — `_fixed_colorings_at_concentration` (DP):**

Per Q4-B, dense `Array{BigInt, k}` indexed by partial-multiplicity vector. Trip-wire comment at the allocation site (memory grows as $\prod_i (a_i + 1)$; crosses 1 MB at k=5 with all $a_i=10$, 100 MB at k=6 with all $a_i=13$).

```julia
function _fixed_colorings_at_concentration(cycle_lengths, multiplicities) :: BigInt
    k = length(multiplicities)
    a = multiplicities
    # Trip-wire: dense storage scales as ∏(a_i+1). 1 MB at k=5 a_i=10; 100 MB at k=6 a_i=13.
    dims = ntuple(i -> a[i] + 1, k)
    state = zeros(BigInt, dims...)
    state[ntuple(_ -> 1, k)...] = BigInt(1)   # the (0,0,...,0) state
    for c in cycle_lengths
        new_state = zeros(BigInt, dims...)
        for I in CartesianIndices(state)
            count = state[I]
            iszero(count) && continue
            for color in 1:k
                new_idx = I[color] + c           # 1-indexed
                new_idx > a[color] + 1 && continue
                J = CartesianIndex(ntuple(j -> j == color ? new_idx : I[j], k))
                new_state[J] += count
            end
        end
        state = new_state
    end
    return state[ntuple(i -> a[i] + 1, k)...]
end
```

**Implementation note 2 — `_subgroups_with_mobius` (Möbius on subgroup lattice of T):**

T = Z/d_1 × Z/d_2 × Z/d_3 (with d_1 | d_2 | d_3 from SNF). For our chunk-7 sizes (n ≤ 32, |T| ≤ 32), `|T|` is small enough to enumerate all subgroups directly. Strategy:

1. Decompose T into Sylow p-subgroups (each is an abelian p-group; their structure is given by the p-adic valuation of d_1, d_2, d_3).
2. Subgroups of T factor as products of subgroups of the Sylow components — Möbius factors over primes.
3. For each Sylow component (an abelian p-group of type (a_1, a_2, a_3) with a_1 ≤ a_2 ≤ a_3 in p-power exponents), enumerate subgroups via the standard combinatorial recipe (Birkhoff 1935 / the partition lattice).
4. The subgroup-lattice Möbius for an abelian p-group has known closed-form values; we compute them up front per supercell and cache for the duration of one `count_inequivalent` call.

**For the v0.2 cases we'll encounter, |T| ≤ 32 and the typical SNFs are (1,1,n), (1,2,n/2), (1,4,n/4), (2,2,n/4), etc. Subgroup count is < 50 in all cases.** Per-supercell cost is negligible compared to the per-permutation Pólya count.

**Implementation note 3 — `_induced_perm_group`:**

Given the original supercell's perm-group on `n` positions and a subgroup H ⊆ T, build the perm-group on the `n/|H|` H-orbits. For each `g` in the original perm-group, its action on positions descends to an action on H-orbits because H is normal in G (T is normal; H ⊆ T). One `Vector{Vector{Int}}` allocation per H. Cheap.

### 2. `src/types/inequivalent_count.jl` — the structured-count return type

Per Phase 6.9. Returned by `count_inequivalent(...; breakdown=true)`:

```julia
"""
    InequivalentCount

Structured return of `count_inequivalent(...; breakdown=true)`. Total count plus per-supercell breakdown so the user can see "where my structures come from."

Fields:
- `total::BigInt` — sum across the request.
- `by_volume::Vector{Tuple{Int, BigInt}}` — `(n, count_at_n)` pairs.
- `by_concentration::Vector{Tuple{Concentration, BigInt}}` — populated when `concentration` was a `ConcentrationRange`; one entry per partition.
- `by_hnf::Vector{Tuple{HNF{D}, BigInt}}` — per-HNF count (one entry per symmetry-inequivalent HNF in the request). Useful for diagnosing which HNFs dominate.

The Phase 6.9 design used `by_hnf_class::Dict{HNFClass{D}, BigInt}`, but `HNFClass` doesn't exist yet (chunks 1–6 didn't need it). Switching the field to a flat per-HNF list defers `HNFClass` until we genuinely need a quotient view. See Q3.
"""
struct InequivalentCount{D}
    total::BigInt
    by_volume::Vector{Tuple{Int, BigInt}}
    by_concentration::Vector{Tuple{Concentration, BigInt}}
    by_hnf::Vector{Tuple{HNF{D}, BigInt}}
end
```

### 3. Public top-level `count_inequivalent(...)` — extends `src/enumerate.jl`

Argument shape mirrors `enumerate(...)`. **Includes the `include_superperiodic` kwarg** (chunk 6.2) — same name, same semantics, default `false`. Honoring the kwarg means the count and the enumeration agree by construction.

```julia
"""
    count_inequivalent(parent::ParentLattice{D}, sites::Sites{D};
                       supercells::SupercellSelection,
                       concentration = nothing,
                       include_superperiodic::Bool = false,
                       breakdown::Bool = false) -> BigInt or InequivalentCount{D}

Count symmetry-inequivalent derivative structures *without enumerating them*. Pólya / Burnside.

- `include_superperiodic = false` (default) — primitive (aperiodic) count via Möbius inversion. Matches `length(enumerate(parent, sites; ..., include_superperiodic = false))`.
- `include_superperiodic = true` — full Burnside orbit count. Matches `length(enumerate(parent, sites; ..., include_superperiodic = true))`.
- `breakdown = false` (default) returns just the `BigInt` total.
- `breakdown = true` returns `InequivalentCount{D}` with per-volume / per-concentration / per-HNF breakdowns.

Cost: O(|G| · n) per supercell for the unrestricted case; with Möbius correction add the cost of subgroup enumeration of T (cheap for |T| ≤ ~100). Sub-second across the chunk-6 corpus.
"""
function count_inequivalent(parent, sites; supercells,
                            concentration = nothing,
                            include_superperiodic::Bool = false,
                            breakdown::Bool = false)
    # Same setup as enumerate(...): single-lattice / single-site / dense-zero-indexed gates.
    # For each HNF: build Supercell → either polya_count (true) or aperiodic_orbit_count (false).
    # Sum. If breakdown, accumulate per-volume / per-concentration / per-HNF along the way.
    ...
end
```

Lives in `src/enumerate.jl` (alongside `enumerate(...)`) since it shares all the input validation. The math lives in `src/algorithms/polya.jl`.

**Validation note.** The input gates (single-lattice, single-site, dense-zero-indexed) duplicate `enumerate(...)`'s. Two options: (i) factor into `_validate_inputs(parent, sites, ...)` helper; (ii) duplicate inline. My lean: (i) for the chunk-7 implementation since the duplication would be ~30 lines of inputs gates — worth one helper.

### 4. Module wiring + exports

- `src/Enumlib.jl`: `include("algorithms/polya.jl")` (defines submodule `Enumlib.Polya`); `include("types/inequivalent_count.jl")`; export `count_inequivalent`, `InequivalentCount`. Re-export `Polya.polya_count` and `Polya.cycle_structure` from the top level for convenience (so users can write `Enumlib.polya_count(...)` without importing the submodule).

### 5. `test/test_polya.jl` — new test file

See "Tests planned" below.

---

## What's deliberately NOT in chunk 7

- **`EnumerationCostEstimate` and `estimate_cost(...)`** — chunk 7.5. The cost-estimate type and the public `estimate_cost` function pull together Pólya counts + per-algorithm memory predictions + the `notes::Vector{String}` advisory channel. They're a thin layer on top of `count_inequivalent`, but they touch the `enumerate(...)` pre-flight gate, which deserves its own design pass.
- **`EnumerationTooLargeError`** — chunk 7.5. The error type fires when `peak_memory_bytes > memory_budget`; it needs the cost estimate as its payload.
- **Wiring `enumerate(...)` to use the real estimator** — chunk 7.5. Through chunk 7, `enumerate(...)` still treats `memory_budget` / `on_overflow` / `skip_preflight` as accepted-but-largely-ignored kwargs.
- **Site-restricted Pólya** (per-site `allowed_labels`) — depends on the chunk-6.5 `:multinomial_restricted` algorithm landing first. The Pólya extension to handle site restrictions involves intersecting cycle-structures with the per-site allowed-label sets; conceptually clean but requires the multi-site machinery from 6.5.
- **Multilattice Pólya** — depends on the multilattice extension (v0.3).
- **`HNFClass{D}` quotient type** — Phase 6.9 had it as the key of `by_hnf_class::Dict{HNFClass{D}, BigInt}`. Through chunk 7, we report `by_hnf::Vector{Tuple{HNF{D}, BigInt}}` (flat list, one entry per inequivalent HNF). Quotient view defers until we need it. See Q3.
- **`estimated_walltime_seconds`** — Phase 7 §7.9 Q2 deferred this to v0.3 unconditionally (hardware variance too high without a calibration pass). Not in chunk 7.5 either.

---

## Tests planned (`test/test_polya.jl`)

### Pólya math primitives
1. **`cycle_structure` on small permutations.** Identity on 5 → `[1,1,1,1,1]`; `[2,1,4,3,5]` → `[2,2,1]`; `[3,1,2]` → `[3]`.
2. **`polya_count(group, k)` (raw Burnside) against tiny hand-verified cases.**
   - Identity-only on n=3, k=2 → `2^3 = 8`.
   - Cyclic $C_3$ on n=3, k=2 → 4 (Burnside: (8+2+2)/3).
   - Symmetric $S_3$ on n=3, k=2 → 4.
   - Cyclic $C_4$ on n=4, k=2 → 6 (matches the chunk 6.2 hand-verified value).
3. **`polya_count(group, multiplicities)` against tiny hand-verified cases.**
   - $C_3$ on n=3 with `[1,2]` → 1 orbit.
   - $S_4$ on n=4 with `[2,2]`, `[1,3]`, `[4,0]` → 1 each.

### Identity / consistency tests
4. **Sum-over-multiplicities recovers unrestricted (raw Burnside layer).** `sum_a polya_count(G, [a_1,...,a_k]) == polya_count(G, k)` for the chunk-6 identity test, now at the Pólya layer.

### `aperiodic_orbit_count` and Möbius helper
5. **Cyclic n=4 binary aperiodic.** `aperiodic_orbit_count(C_4_perm_group, (1,1,4), 2) == 3` (matches the chunk 6.2 locked value; Möbius collapses to (1/4)(2^4 − 2^2) = 3).
6. **Non-cyclic SNF.** Construct a small case where SNF is (1, 2, 2) and verify `aperiodic_orbit_count` matches the corresponding `length(enumerate(...; include_superperiodic=false))` count.

### `count_inequivalent` against the chunk 6.2 locked counts (both kwarg branches)

These re-use the FCC binary reference values now present in `test/test_enumerate.jl` and `test/test_concentration.jl`, asserting that the count primitive matches the enumeration primitive at every locked case.

7. **FCC binary unrestricted, `include_superperiodic=false` (default).** Matches `length(enumerate(...))` for n ∈ {4, 8, 12}: 19, 390, 7140.
8. **FCC binary unrestricted, `include_superperiodic=true`.** Matches the chunk 6.2 locked reference: n=4 → 41, n=8 → 544, n=12 → 7885.
9. **FCC ternary unrestricted at n=4 with default kwarg.** Matches the chunk-5 reference: 96.
10. **FCC binary at fixed concentration, `include_superperiodic=false`.** Matches chunk-6 locked: n=4 50%=5, n=8 50%=94, n=8 3:5=86, n=12 50%=1552.
11. **FCC binary at fixed concentration, `include_superperiodic=true`.** Matches chunk 6.2 locked: n=4 2:2 → 13, n=8 4:4 → 146, n=12 6:6 → 1739, n=8 3:5 → 86 (asymmetric trip-wire — same as `=false`).

### HF 2012 paper reference (per Q8-A: just the canonical Ag–Pt 1003 in chunk 7)
12. **Ag–Pt at 15:17 in 32-cell, `include_superperiodic=false`.** HF 2012 §4 reference: **1003 inequivalent structures**. Counting (not enumerating) takes seconds. **Load-bearing chunk-7 correctness check.** Additional HF-2012 Table-1 references queued for v0.2.0 polish.

13. **Ag–Pt at 15:17 in 32-cell, `include_superperiodic=true`.** Same number — 1003 — because 15:17 is asymmetric and admits no super-periodic structures (number-theory). Second trip-wire test against the §5.2.1 spec.

### `InequivalentCount` (breakdown)
14. **Structure of the breakdown** when `breakdown=true`: `total == sum(by_volume) == sum(by_concentration when applicable) == sum(by_hnf)`.

### Backwards-compat
15. **Chunk-1 through chunk-6.2 tests still pass.** No regression. Expected total after chunk 7: 426 + ~30 new = ~456.

---

## Open questions for you

### Q1 — Split chunk 7 into 7 + 7.5 as proposed, or land everything together?

**A.** Split as proposed. Chunk 7 = Pólya submodule + `count_inequivalent`. Chunk 7.5 = `estimate_cost` + memory-budget gate + `EnumerationTooLargeError` + `enumerate(...)` wiring. Each is a focused diff (~200 lines + tests); each has its own milestone. Chunk 7 closes with "users can count without enumerating, and we can drop the slow Ag–Pt enumerate test in favor of a fast count test."

**B.** Land it all in one chunk 7. Bigger diff (~500 lines + tests), more cross-cutting. The advantage: `enumerate(...)`'s pre-flight gate is finally real at chunk-7-close instead of waiting another chunk.

**My lean: A.** The Pólya math and the cost-gate plumbing are conceptually distinct; chunk 7 wants careful numerical validation against the Rosenbrock reference and Ag–Pt 1003; chunk 7.5 wants careful API plumbing. Mixing them dilutes the review focus. And the chunk 7 close is genuinely useful on its own (users get `count_inequivalent`).

> Split. Smaller chunks are easier to review without the human becoming lazy or complacent.

**Locked: A (split).** Same observation from the chunks 5–6 cadence — focused review on a smaller diff catches more than a sweeping pass over a big one. Chunk 7 = math + counting; chunk 7.5 = cost-gate plumbing + `enumerate(...)` wiring.

### Q2 — Submodule (`module Polya`) or flat namespace?

**A.** True submodule `Enumlib.Polya`. Qualified access from inside Enumlib (`Polya.polya_count(...)`); re-export `polya_count`, `cycle_structure` from the top level for users. Cleaner encapsulation; if we ever extract `Enumlib.Polya` to its own `Polya.jl` package (per research.md §5.3 review), the submodule structure is exactly the extraction shape.

**B.** Flat — just put `polya_count`, `cycle_structure` in `Enumlib`'s top level. Smaller wiring; one fewer concept.

**My lean: A.** The submodule choice is recorded in research.md §5.3 review as the explicit extraction-ready pattern. The cost is one `module Polya ... end` block plus the top-level re-export — minor. Pays off if/when we extract.

> In general I don't understand what a submodule is and the pros and cons. You gave two choices, but the question is specific to this codebase. I'd like to understand the choice *generally*.

**Claude (Julia submodules — general teaching):** Fair — let me back up and explain the construct itself before tying it to chunk 7.

**What a module is.** In Julia, a `module Foo ... end` is the unit of namespace + scope. Every package's top level is a module (`Enumlib` is a module; `LinearAlgebra` is a module; `Base` is a module). Inside a module:
- Names defined inside (`function`, `struct`, `const`) are local to that module unless `export`ed.
- `using OtherPackage` and `import OtherPackage.foo` only affect *this* module's namespace.
- Two modules can define functions with the same name without conflict (they're `Foo.bar` and `Baz.bar`; only ambiguous when both are `using`'d unqualified).

**What a *submodule* is.** Just a module nested inside another module:

```julia
module Outer
    module Inner
        function helper() ... end
        export helper
    end
    using .Inner: helper        # bring helper into Outer's namespace
end
```

The dot in `using .Inner` is a *relative import* — "look for `Inner` as a child of the module I'm currently in." From outside, the qualified name is `Outer.Inner.helper`.

**Why submodules exist (general).** Three reasons, in order of how much they tend to matter:

1. **Namespace separation.** If `Inner` defines a function called `count`, it doesn't collide with `Outer.count` or `Base.count`. You can have a self-contained vocabulary inside a bigger package without polluting the outer namespace.

2. **Sharp public/internal API line.** Things in `Inner` that aren't exported aren't part of the user-facing API. A user typing `Outer.foo` gets the documented surface; `Outer.Inner._helper` is "I'm reaching past the public API and I know it." Useful for libraries with substantial implementation machinery you want kept inside.

3. **Future package extraction.** A submodule can be lifted out into its own package with minimal restructuring — it already has its own `using`s, exports, and internal vocabulary. The dependency on the parent is explicit (`using ..Outer: foo, bar`), which makes the extraction a search-and-replace rather than a redesign.

**When submodules pay off (general):**
- The code has a coherent, self-contained vocabulary (think `LinearAlgebra.LAPACK`, `Base.Threads`, `Distributions.MixtureModels`). One concept, many functions.
- The code is plausibly extractable later (or you want to signal "this is its own thing").
- The code has a real internal/external API split — lots of helpers you don't want users typing into the REPL.

**When they're overkill (general):**
- A handful of utility functions with no shared vocabulary — submodule overhead exceeds benefit. Just put them in the parent module.
- Heavy bidirectional coupling — if your "submodule" has to call back into half of the parent module, the boundary isn't real. The qualified-name overhead becomes pure tax with no clarity benefit.
- Code you're never going to extract and that has no public/internal asymmetry.

**The costs.** Honest tally:
- **Qualified names.** From outside the submodule you write `Outer.Inner.foo` (or `using Outer.Inner: foo` and then `foo`). Re-exporting from `Outer` (i.e., `export foo` in `Outer` after pulling it in via `using .Inner: foo`) makes this transparent for users — they just see `Outer.foo`.
- **`using ..Parent: foo` syntax.** Submodules use `..` to refer to their parent (one dot per level up). `using ..Enumlib: ParentLattice` reads as "from one level up, bring in `ParentLattice`." Mildly unfamiliar at first; standard once you've seen it twice.
- **Compile time.** Each module is its own compilation unit, so a heavily-fragmented codebase has marginally higher precompile cost. Negligible at our scale.
- **Conceptual overhead for readers.** Anyone reading the code has to know what `..` and `module` do. Once they do, it's free.

**Concrete chunk-7 reasoning, given the above:** Polya passes every "when to use" criterion:
- **Coherent vocabulary.** Cycle structures, Burnside averages, polynomial-coefficient DP. Self-contained group-theory-on-permutations module.
- **Public/internal split.** `polya_count` and `cycle_structure` are user-facing; `_fixed_colorings_at_concentration` is internal DP machinery. The submodule keeps the internal name out of `Enumlib`'s namespace.
- **Plausibly extractable.** research.md §5.3 review explicitly anticipates this: "once Enumlib v0.2+ is stable, do a small extraction PR: move `Enumlib.Polya` → `Polya.jl`, add it as a dep of Enumlib." A submodule structure makes that PR a one-day job; a flat-namespace structure makes it a refactor.

So the chunk-7 choice (A) isn't an arbitrary preference — it's submodule-shaped code that we've also flagged as extraction-eligible. **If neither of those were true (e.g., it was just two free functions with no extraction plan), I'd recommend B.**

**Locked: A (`module Enumlib.Polya`).** With the teaching above, the chunk-7 fit is concrete: Polya is the textbook submodule case (vocabulary + API split + extraction plan).

### Q3 — `by_hnf::Vector{Tuple{HNF, BigInt}}` (flat) or `by_hnf_class::Dict{HNFClass, BigInt}` (Phase 6.9 design)?

The Phase 6.9 design had `by_hnf_class::Dict{HNFClass{D}, BigInt}` — keyed by *symmetry-equivalence class* of HNFs. But (a) `HNFClass` isn't a type yet (chunks 1–6 never needed it; symmetry reduction is just `getSymInequivHNFs` returning the representative list), and (b) `enumerate_hnfs(...)` already returns one HNF per class by construction.

**A.** Flat per-HNF list: `by_hnf::Vector{Tuple{HNF{D}, BigInt}}`. One entry per HNF returned by `enumerate_hnfs(...)`. Each entry is the count attributable to that HNF's representative.

**B.** Promote to a quotient view: introduce `HNFClass{D}` now, populate a `Dict{HNFClass{D}, BigInt}`. More Phase 6.9-faithful but pulls a new type into chunk 7's scope.

**My lean: A.** Keeps the chunk-7 type system small. The flat list is what users actually want for diagnostics ("which HNFs produce most structures?"). If a quotient view becomes useful later we add `HNFClass{D}` then. Phase 6.9's `HNFClass` design carries forward as a documented v0.3 candidate.

> A

**Locked: A (flat `by_hnf::Vector{Tuple{HNF{D}, BigInt}}`).** `HNFClass{D}` stays on the v0.3 shopping list.

### Q4 — DP storage for fixed-concentration: `Dict{NTuple{k,Int}, BigInt}` or dense `Array{BigInt, k}`?

For the fixed-concentration count's DP (state = partial multiplicity vector):

**A.** `Dict{NTuple{k,Int}, BigInt}`. Sparse — only stores reachable states. Allocation cost per cycle. k-agnostic at the type level.
**B.** Dense `Array{BigInt, k}` of shape `(a_1+1, a_2+1, ..., a_k+1)`. All states allocated upfront; access is index arithmetic (fast). For typical sizes (k=2 or 3, $a_i \le n \le 50$) the array fits in tens of KB.
**C.** Pick based on heuristic: dense for small $k$ and small $\prod (a_i+1)$, sparse otherwise.

**My lean: B (dense), unconditionally for v0.2.** Our worst case at v0.2 is k=4 in a chunk-6.5 multi-site test — at $n=20$, even uniform multiplicities give $\prod(a_i+1) = 6^4 = 1296$ entries, each a BigInt (~50 bytes) — 65 KB. Trivial. Dense is faster (no hashing) and simpler. Switch to sparse only if a future use case (k≥6 with imbalanced multiplicities) actually hurts.

> B for now, but lets keep our eyes open

**Locked: B (dense `Array{BigInt, k}`).** Concrete trip-wire to watch: dense memory grows as $\prod_i (a_i + 1)$. Crosses 1 MB at k=5 with all $a_i = 10$ (or k=6 with all $a_i = 6$), 100 MB at k=6 with all $a_i = 13$. If a chunk-9+ user case hits anything in that range we revisit; until then dense is the simpler, faster choice. I'll add a one-line comment at the DP allocation site noting the trip-wire so a future reader has the number handy.

### Q5 — Test against the Rosenbrock Python reference?

The Rosenbrock 2016 reference implementation is on GitHub (`<https://github.com/rosenbrockc/polya>`). We could vendor a couple of its test outputs into `test/data/` and assert that our Pólya counts match across a handful of non-trivial cases (small-but-not-tiny groups where the answer is a 5-to-10-digit number we couldn't easily hand-check).

**A.** Yes — vendor Rosenbrock's outputs into `test/data/polya_rosenbrock_reference.jld2`. Cite the source. Adds a 3rd-party-validated correctness check.
**B.** No — rely on the FCC + Ag–Pt locked counts. The Pólya math is small enough to validate against hand-computed cases; the literature comparison is enough.

**My lean: B for chunk 7, A as a v0.2.0 polish task.** For chunk 7 the FCC counts (chunk-5 + chunk-6 locked) and the Ag–Pt 1003 reference give us strong validation. Vendoring Rosenbrock outputs is nice-to-have but not load-bearing for the chunk milestone. Add to the v0.2 polish checklist alongside the file-organization pass.

> B for now, but definitly vendor Rosenbrock later.

**Locked: B for chunk 7; vendor Rosenbrock as v0.2.0 polish.** I'll add this to the "v0.2 polish (after chunk 5 lands; before v0.2.0 release)" section of `docs/notes/v0.2-plan.md` when chunk 7 lands so it's not forgotten. The vendor-and-cross-check task: clone the Rosenbrock Python repo, run a handful of cases (small group + small/moderate `n`), record the BigInt outputs into `test/data/polya_rosenbrock_reference.jld2` with provenance comments, add an `@testset "Rosenbrock 2016 reference cases"` to `test/test_polya.jl`. Probably a half-day of work; lands cleanly without touching production code.

### Q6 — Does `count_inequivalent(...)` accept the same `algorithm = ...` kwarg as `enumerate(...)`?

The Pólya counter doesn't *care* which downstream enumeration algorithm would run — counting is closed-form. But for user ergonomics:

**A.** No `algorithm` kwarg. `count_inequivalent` is purely Pólya; users don't pick an algorithm because there's only one (counting math).
**B.** Accept `algorithm = ...` and ignore it (or use it only for `notes::Vector{String}` advisory: "if you enumerate this, the chosen algorithm would be `:multinomial`"). Symmetric with `enumerate(...)` for muscle-memory.

**My lean: A.** Counts are algorithm-agnostic; pretending otherwise is mistruthful. Chunk 7.5's `estimate_cost(...)` *will* expose `chosen_algorithm` (because cost depends on which algorithm runs), but that's the right place for it. `count_inequivalent` stays minimal.

> A

**Locked: A (no `algorithm` kwarg on `count_inequivalent`).**

### Q7 — Where does `polya.jl` live: `src/algorithms/polya.jl` or `src/polya/...`?

The submodule choice (Q2-A) implies the file layout is somewhat free. Two patterns:

**A.** Single file: `src/algorithms/polya.jl` containing `module Polya ... end`. Sits next to `multinomial.jl` (chunk 6's home for an algorithm-shaped block).
**B.** Subdirectory: `src/polya/Polya.jl` (the submodule's main file) + `src/polya/cycle_structure.jl` + `src/polya/fixed_concentration.jl`. More separation; matches the "this could become its own package" framing.

**My lean: A.** ~150 lines doesn't justify a subdirectory. If/when extraction happens, lifting one file to a new package is cleaner than reorganizing during extraction. Keep `src/algorithms/` as the "algorithm-side" home through v0.2.

> A

**Locked: A (single `src/algorithms/polya.jl`).** Sits next to `multinomial.jl`. If/when Polya outgrows ~400 lines we revisit the subdirectory split.

### Q8 — Reference test for chunk 7: just Ag–Pt 1003, or pull more 2012 paper references?

The HF 2012 paper has multiple Table-1 references. Ag–Pt 15:17 → 1003 is the canonical one. Other tabulated counts in the paper (e.g., Cu–Au at various supercells) could give us additional reference points.

**A.** Just Ag–Pt 1003. Single canonical reference; minimum maintenance burden.
**B.** Pull 2–4 references from the HF 2012 paper's tables for chunk 7 testing. More confidence in correctness.

**My lean: A for chunk 7, more in v0.2.0 polish.** Ag–Pt 1003 is the load-bearing test. Adding 2–3 more is good v0.2.0-polish work. For chunk 7 the FCC corpus + Ag–Pt is enough for the milestone; we can grow the Pólya regression set over time.

> Again B, but definitely add the other tests later.

> What I meant was go with A, the minimal path, but let's make sure to add the other cases later.

**Locked: A (just Ag–Pt 1003 in chunk 7).** Per your clarification — minimal-now, add-later pattern (parallel to Q5). Additional HF-2012 Table-1 reference counts queued for v0.2.0 polish alongside the Rosenbrock-vendoring task from Q5.

---

## Implementation plan (Round 4 — integrated with chunk 6.2 kwarg)

1. Write `src/algorithms/polya.jl`:
   - `module Polya` (Q2-A).
   - `cycle_structure(perm)`.
   - Both `polya_count` methods (raw Burnside) — math primitives.
   - `_fixed_colorings_at_concentration` DP using dense `Array{BigInt, k}` (Q4-B) with a one-line trip-wire comment at the allocation site.
   - `_subgroups_with_mobius(snf_diagonal)` — enumerate subgroups of T = Z/d_1 × Z/d_2 × Z/d_3 with their Möbius coefficients. Sylow-decomposition + standard abelian-p-group subgroup enumeration. Cached per supercell.
   - `_induced_perm_group(perm_group, snf_diagonal, H)` — perm-group on H-orbits.
   - `aperiodic_orbit_count(perm_group, snf_diagonal, k_or_mults)` — Möbius sum of induced `polya_count` calls.
2. Write `src/types/inequivalent_count.jl` — `InequivalentCount{D}` with `total`, `by_volume`, `by_concentration`, `by_hnf` (flat per-HNF list, Q3-A). Pretty-print + equality.
3. Update `src/enumerate.jl`:
   - Factor the input-validation block of `enumerate(...)` into a helper `_validate_enumerate_inputs(parent, sites, concentration)` that returns `(allowed, k)`. Both `enumerate(...)` and the new `count_inequivalent(...)` call it.
   - Add `count_inequivalent(parent, sites; supercells, concentration=nothing, include_superperiodic::Bool=false, breakdown::Bool=false)` top-level (no `algorithm` kwarg, Q6-A). For each HNF: build Supercell, then call `polya_count` (when `include_superperiodic=true`) or `aperiodic_orbit_count` (when `include_superperiodic=false`). Sum.
4. Update `src/Enumlib.jl` — `include`s for the new files; `using .Polya: polya_count, cycle_structure, aperiodic_orbit_count` to re-export from the top level; exports for `count_inequivalent`, `InequivalentCount`, `polya_count`, `cycle_structure`, `aperiodic_orbit_count`.
5. Write `test/test_polya.jl` — the 15 testsets above. The HF-2012 reference is Ag–Pt 1003 only (Q8-A); additional Table-1 references deferred to v0.2.0 polish.
6. Update `test/runtests.jl` — one new `include("test_polya.jl")` line.
7. Update `docs/notes/v0.2-plan.md` — chunk 7 → done; chunk 7.5 added as a follow-up entry; Ag–Pt 1003 reference marked as covered (count, not enumerate); v0.2-polish list gets two new entries (vendor Rosenbrock outputs; expand HF-2012 Table-1 reference set).
8. Run all tests. Expect 426 + ~30 = **~456 passing**.

**Estimated effort:** one focused session, possibly two. The Möbius helper (`_subgroups_with_mobius` + `_induced_perm_group`) is the only genuinely new math relative to the original chunk-7 sketch — adds maybe 80 lines and a unit test set. Everything else is mostly reusing chunk 6.2's locked reference values.

---

## After your sign-off

- Implementation lands as `Chunk 7: Polya submodule + count_inequivalent`.
- `docs/notes/chunk7-review.md` opened for the review pass.
- Land chunk 7.1 with revisions if needed.
- Then chunk 7.5 (`estimate_cost` + memory-budget gate + `EnumerationTooLargeError` + `enumerate(...)` wiring).
- Then chunk 8 (recursive-stabilizer, Morgan 2017) toward v0.2.0.

**Sign-off status (Round 4):** all eight Qs locked. `include_superperiodic` kwarg now live on `enumerate(...)` (chunk 6.2, commit `013fa7f`); chunk 7 inherits it on `count_inequivalent(...)`. Möbius helper added to chunk 7 scope (~80 lines, ~6 new tests).

---

## Round 3 — pre-implementation issue found (super-periodicity)

I was on the way to writing code when I realized the design above is internally inconsistent. Surfacing now rather than barreling through.

### The problem

The design says `count_inequivalent` is the standard Pólya / Burnside orbit count, AND it asserts the test at n=4 binary will match `length(enumerate(...)) == 19`. **Both can't be true.**

**Why.** Standard Pólya / Burnside counts the *full* orbit space — including super-periodic orbits. `enumerate(...)` drops super-periodic structures (HF 2008 step 5d, ported into chunk 6 §A): a labeling fixed by any non-identity supercell-translation is already enumerated as a smaller-supercell derivative and must be discarded.

So Pólya orbit count ≥ `length(enumerate(...))`, with equality only when there are no super-periodic orbits at this supercell (rare). Concrete:

| n | k | full Pólya orbits | `length(enumerate)` | super-periodic dropped |
|---|---|---|---|---|
| 4 | 2 (cyclic n=4) | 6 | 3 | 3 (two monochromatic + one period-2 alternating) |
| FCC n=4 binary | 2 | (some number > 19) | 19 | the difference |
| Ag–Pt n=32 at 15:17 | 2 | (some number > 1003) | 1003 (HF 2012 §4 reference) | the difference |

The literature reference 1003 is the *aperiodic* (primitive) count — the number of structures that are intrinsic to the n=32 supercell, not realizations of smaller supercells. To be a meaningful pre-flight predictor and to match HF 2012 Table 1, `count_inequivalent` must report this *aperiodic* count, not the raw Pólya orbit count.

### Fix: Möbius inversion over the translation subgroup

For a supercell with SNF diagonal $(d_1, d_2, d_3)$, the translation subgroup $T$ is $\mathbb{Z}/d_1 \times \mathbb{Z}/d_2 \times \mathbb{Z}/d_3$. Subgroups of $T$ form a lattice ordered by inclusion. Standard Möbius inversion:

$$N_{\text{aperiodic}}(\text{supercell}) = \sum_{H \subseteq T} \mu(H, T) \cdot N_{\text{orbits with stabilizer} \supseteq H}$$

The Möbius function $\mu$ on the divisor lattice factors over coordinates: $\mu((e_1, e_2, e_3), (d_1, d_2, d_3)) = \mu(d_1/e_1) \cdot \mu(d_2/e_2) \cdot \mu(d_3/e_3)$ (number-theoretic Möbius on each).

The "orbits with stabilizer ⊇ $H$" count is itself a Pólya count — applied to the action of $G$ on the labelings *fixed by every element of $H$*. Concretely: such labelings are constant on each $H$-orbit of the supercell positions, so they're equivalent to colorings of a *smaller* supercell whose perm-group is induced by $G/H$.

For 1D cyclic case (sanity check above): n=4 binary, $\mu(1)\cdot N_{\text{orbits}}(C_4) + \mu(2)\cdot N_{\text{orbits at period 2}} + \mu(4)\cdot N_{\text{orbits at period 1}}$. Works out to the aperiodic count.

### What this changes in chunk 7's scope

- **`polya_count` (the math primitive)** stays as I designed it — the standard Burnside orbit count. This is the *correct* mathematical primitive; aperiodic counting is a derived computation built on top.
- **A new internal helper `_aperiodic_orbit_count(perm_group, snf_diagonal, mults_or_k)`** does the Möbius sum over subgroups of the translation subgroup. ~50 additional lines. Uses `polya_count` as a black box at each subgroup level (after restricting to the H-fixed labelings).
- **`count_inequivalent(parent, sites; ...)`** uses `_aperiodic_orbit_count` per supercell, sums across the HNF list. The tests in §"Tests planned" against `length(enumerate(...))` then *do* match.

Total chunk-7 size grows from ~150 lines (Pólya math alone) to ~250 lines (Pólya + Möbius correction + count_inequivalent). Still well within "single-chunk" scope.

### The decision I want to confirm before proceeding

**Recommendation: implement the Möbius correction in chunk 7** (so `count_inequivalent` matches `enumerate(...)`, the FCC and Ag–Pt 1003 reference tests work as designed, and the user gets an honest pre-flight count). The math is standard; the implementation is contained; the alternative (pure Pólya orbit count) fails the load-bearing reference test.

**Alternative: defer to chunk 7.5.** Ship `polya_count` (pure orbit count) in chunk 7, document that it ≠ enumerate count, defer Möbius to 7.5 alongside the cost-gate plumbing. Smaller chunk, but the chunk-7 milestone is "users can count without enumerating" — and the count being unrelated to `enumerate(...)`'s output makes it materially less useful.

**My strong lean: implement Möbius in chunk 7.** Reach goal: `count_inequivalent(fcc, sites; supercells=VolumeRange(32:32), concentration=Concentration_count([15,17]; n_total=32)) == 1003`.

> What you've uncovered is an inconsistency of sorts in the original enumeration code specification. Some of the algorithms remove superperiodic cases and some did not. This was normally consistent though with what users wanted. What I'm seeing now is a missing requirement in our specification. I think we want to be able to (based on a kwarg) eliminate or keep superperiodic configurations. What you have proposed is also good---it gives us a solid way to count the number of configurations (without generating them) in both scenarios. That is useful. So your suggestion is on point, thank you for noticing, but we also need to rethink a bit here before going on. We need to updated the code specification, and the implementation we have already, so that we can do both cases, and count them. Can you give me a concrete plan for that? Update the research.md accordingly as well. That is the document where our specs and planning live. It should reflect questions like this and what we decided.

### Resolution: super-periodicity becomes a first-class kwarg + chunk 6.2

You're right — the gap was in the original Fortran enumlib's spec, not just my chunk-7 sketch. We turn it into an explicit user choice.

**The kwarg (lands on both `enumerate(...)` and `count_inequivalent(...)`):**

```julia
include_superperiodic::Bool = false
```

- `false` (default) — primitive structures only. Matches HF 2008 step 5d, HF 2012 Table 1, and what chunks 5–6 already do. No existing test breaks.
- `true` — full orbit space.

Naming alternatives considered (`primitive::Bool = true`, `superperiodicity::Symbol = :drop`); `include_superperiodic::Bool = false` chosen because the boolean is simpler than a symbol enum and "superperiodic" is the established codebase vocabulary. Open to `primitive` if you prefer — single rename.

**Spec captured.** New subsection **§5.2.1 Super-periodicity policy** added to `research.md`, immediately after §5.2 (the public API). Captures: the original Fortran gap, the kwarg as resolution, the default reasoning, the math (raw Burnside vs Möbius inversion), and the implementation home (chunk 6.2 retrofit + chunk 7 integration). Cross-referenced from §4.1, §4.3, §6.2, §7.2.

> I want to add to our understanding here before we go on. It wasn't really the case that the fortran code was "wrong". It's that the users had different use cases. The different use cases needed different treatment of superperiodic cases. But the different use cases were also boundaries between the four different algorithms. So there is a coincidence between these two different things. Fundamentally, the idea was always *enumerate symmetrically distinct configurations only*. But when enumerating across different volume sizes, this meant superperiodic configurations at size 2n had already been generated at size n, so keeping them resulted in a duplicate in the list. In contrast, generating structures at a stoichiometry of 15:17 superperiodic cells were NOT redundant. There were only two: all A or all B. So the principle that is more fundamental than user choice is "don't enumerate duplicates". I'm not 100% sure we want to delegate this to the user to know when to set this flag. But maybe leave it in for now and we can sort things out more as we go. Do you have any more thoughts about this issue?

**Claude (synthesis).** This reframing is sharper than mine — promoting it as the spec.

**Your principle, restated.** The contract is "enumerate symmetrically distinct configurations only" — *no duplicates*. That principle is invariant. The "drop or keep super-periodic" question is downstream of the principle: the answer depends on what the result set is and what counts as a duplicate inside it.

**Two well-defined queries, both honoring the principle.**
1. **Intrinsic-to-$n$ structures** (the typical materials use case). Across a volume sweep, super-periodic structures at $n$ are duplicates of primitive structures at smaller divisors of $n$ — drop them. Within a single-volume single-concentration query, this maps to "configurations that don't reduce to a smaller supercell" — also a clean, well-defined set.
2. **Full orbit space at $n$**. Every orbit of the labeling action, whether or not it reduces. Useful when the user is *not* sweeping volumes and explicitly wants the full Burnside picture (theoretical comparisons; isolated-volume queries).

The kwarg picks *which question*; both honor the no-duplicates principle, just on different result sets.

**One technical correction on your example, for the spec record.** "Stoichiometry of 15:17 superperiodic cells were NOT redundant. There were only two: all A or all B." For 15:17 in $n=32$ specifically, super-periodic structures *don't exist* — divisors of 32 are 1, 2, 4, 8, 16, 32; for period $d$ to admit a 15:17 split, both 15 and 17 must be divisible by $32/d$, and the only $d$ that works is 32 itself (so the structure is its own period — primitive). The "all A / all B" case is for the symmetric or limit cases (concentrations $n:0$ or $0:n$ at any volume). So the example you gave actually reinforces the principle even more cleanly than stated: at 15:17 the question is moot — no super-periodic structures exist; the kwarg is a no-op. The genuinely-interesting cases are symmetric concentrations like 16:16 in $n=32$ (super-periodic structures exist) or no-concentration-restriction queries like FCC binary at $n=4$ (full Burnside orbit count = 6, intrinsic count = 3).
> You are absolutely right here. I made a mistake. But so why were the old Pt-Cu example and the new implementation not agreeing? The superperiodic case should not have been an issue on that one.

**Claude.** Honest answer first: **I don't have a Pt–Cu disagreement in this conversation's history.** I searched: no Pt–Cu test data in the repo, no Pt–Cu in git log, the `data/Pt-Cu_formation_enthalpy.png` that appeared in the chunk-6 `git status` as untracked is no longer present. What I have on record from chunk 6:
- Identity test passed at FCC binary n=4, 8, 12 and ternary n=4 (all exact).
- Locked FCC binary at fixed-concentration counts (n=4 50%=5, n=8 50%=94, n=8 3:5=86, n=12 50%=1552 — all exact).
- Ag–Pt 15:17 in 32-cell → 1003 was *deferred for being slow* (~10¹⁴ ops to enumerate), never tested. No Julia number was generated to compare.

So either (a) you're thinking of Ag–Pt (both Pt-binary FCC systems, often discussed together — and Ag–Pt was deferred, not disagreed) or (b) you're remembering an experiment outside this conversation (JuCE.jl, an old Fortran debug session) that I don't have in context.

Whichever case you're remembering, point me at it and I'll run the corresponding Julia call under chunk-6 code now. Takes seconds; we resolve it before chunk 6.2.

**Debugging checklist for the spec record — what *could* cause a count mismatch that isn't super-periodicity, in case the Pt–Cu (or any future) example surfaces.** At asymmetric concentrations (where super-periodic is provably empty), a Julia↔Fortran count disagreement is one of:

1. **Parent lattice convention.** Primitive vs conventional FCC (4× volume) or left-handed vs right-handed basis. `getSymInequivHNFs` counts depend on the parent's point group; mismatched parents produce different per-volume HNF lists.
2. **Volume interpretation.** "Volume 32" could mean 32 primitive cells or 32 conventional cells; an off-by-4× factor is easy with FCC.
3. **Label-exchange convention.** HF 2008 step 5c factors out species relabelings. *At asymmetric concentrations like 15:17 this is also empty* — relabeling 0↔1 changes 15:17 to 17:15, which is a different concentration. So at 15:17 it can't be the cause; at 16:16 it could.
4. **Concentration encoding.** Exact-multiplicity (15:17 means exactly 15 of color 0 and 17 of color 1) vs proportion (concentration $\tfrac{15}{32}$ at multiple volumes).
5. **Site activity.** If the two implementations disagree on which sites are inactive (single allowed label), the labeling space size differs.
6. **`getPermG` translation-group construction.** Off-by-one, wrong SNF ordering, or incorrect $L^{-1}$ rounding can produce a wrong-sized perm group and bias all counts.
7. **Algorithm bug.** After ruling out 1–6, an actual bug in chunk 5 or chunk 6.

For 15:17 specifically: ruling out 3 and the super-periodicity case, the most likely candidates are 1, 2, or 6 — parent / volume / `getPermG`. If we ever see a 15:17 disagreement, those are the first things to check.

**Pragmatic suggestion: if you can't quickly retrieve the Pt–Cu case, that's fine — we proceed with chunk 6.2 under the kwarg plan, and if a count disagreement surfaces during chunk 6.2 testing or anywhere else, we use this checklist as the diagnostic map.**

**On "should we delegate to the user" vs "smart default."** I think the right answer for v0.2 is: keep the kwarg, default `false`, *don't* try to be smart. Two reasons:

- **The "no duplicates" principle is about across-call composition, not within-call.** A user calling `enumerate(...; VolumeRange(32:32))` and then later `enumerate(...; VolumeRange(16:16))` and unioning the results expects no overlap. A within-call smart default (e.g., "single-volume → keep super-periodic") can't see the second call. Default-drop everywhere makes across-call composition automatically correct.
- **Smart defaults hide behavior.** "Why does my n=32 query at 16:16 give different counts depending on whether I also passed n=16?" is a debugging nightmare. An explicit kwarg keeps the policy visible at the call site.

But I do think we should revisit at v0.3 with usage data. Possible smart-default refinements logged in research.md §5.2.1:
- For asymmetric concentrations where super-periodic is provably empty, log `@info` (or just no-op silently) if the kwarg was passed but is moot.
- For multi-volume sweeps with `include_superperiodic = true`, *warn* — that's almost always a mistake.
- We don't have to commit to any of these now. The kwarg is the foundation; smart layers can be added later without breaking calls.

**Updated research.md §5.2.1.** I rewrote the section to lead with your principle ("enumerate symmetrically distinct configurations only, i.e., no duplicates"), reframed Fortran's behavior as "principle-driven, context-varying" rather than "inconsistent," explained the two well-defined queries, and recorded the v0.3 smart-default candidates for future revisit. The math and implementation guidance are unchanged.

> Sign off / redirect:
**New chunk 6.2 (small) lands first.**

- Add `include_superperiodic::Bool = false` to `enumerate(parent, sites; ...)`.
- Plumb through `_enumerate_exhaustive` and `_enumerate_multinomial`.
- `getUniqueColorings(k, perm_group; include_superperiodic = false)` — chunk 5's body. The existing super-periodicity check (`test == i && ig < n` clause) becomes conditional on the kwarg.
- `getUniqueColorings_multinomial(perm_group, mults; include_superperiodic = false)` — chunk 6's body. The explicit `is_super_periodic` loop becomes conditional.
- Tests: existing 406 still pass at default. New tests verify `include_superperiodic = true` returns more than the default. Concrete reference values to lock:
  - FCC binary n=4 with `include_superperiodic = true`: known full count (verified via the chunk-6 identity-test arithmetic plus the count of super-periodic structures we drop).
  - Cyclic n=4 binary on a single 4-site cyclic perm-group: 6 with `=true`, 3 with `=false` (hand-computed).
- ~30 lines of source + ~10 tests.
- Lands as commit `Chunk 6.2: include_superperiodic kwarg on enumerate(...)`.

**Chunk 7 then implements both branches of `count_inequivalent`.**

- `polya_count(perm_group, k)` and `polya_count(perm_group, mults)` — math primitives, always raw Burnside.
- `count_inequivalent(...; include_superperiodic = false)` — Möbius inversion over supercell translation subgroup.
- `count_inequivalent(...; include_superperiodic = true)` — sum of `polya_count` across the HNF list.
- Both branches tested. Reference test at `false`: Ag–Pt 1003. Reference test at `true`: cyclic n=4 binary = 6.

**Chunk 7.5** unchanged.

### Order of operations

1. Sign-off on this plan (you confirm the kwarg name + chunk 6.2 ordering).
2. I write `docs/notes/chunk6.2-design.md` (small — kwarg API + the two algorithm-body changes + test list).
3. You sign off on chunk 6.2.
4. Implement chunk 6.2; review; land.
5. Update `docs/notes/chunk7-design.md` to integrate the kwarg into the chunk-7 plan (the "Resolution" above is a sketch; the integrated version updates §"What lives in chunk 7", §"Tests planned", and §"Implementation plan").
6. Sign-off on the integrated chunk-7 plan.
7. Implement chunk 7.

> Read my notes, update research.md again, respond to my comment, and let's iterate at least one more time before we implement chunk 7.

---

## Round 4 sign-off block

**Status:** chunk 6.2 has landed (commit `013fa7f`). The `include_superperiodic` kwarg is live on `enumerate(...)`. Chunk 7's design is now fully integrated above:

- §"What lives in chunk 7" updated — Pólya math primitives + Möbius helper (`aperiodic_orbit_count`) + `count_inequivalent` honoring the kwarg.
- §"Tests planned" expanded — both kwarg branches tested at every chunk-6.2 locked reference value, plus the Möbius helper has its own unit tests, plus Ag–Pt 1003 at both kwarg values (the `=true` value is also 1003 — second trip-wire on the §5.2.1 number-theory argument).
- §"Implementation plan" integrated — adds `_subgroups_with_mobius` + `_induced_perm_group` + `aperiodic_orbit_count` to the polya.jl manifest; factors `_validate_enumerate_inputs` for shared use.

Chunk 7 grows from ~250 lines (Round 3 estimate) to ~330 (~80 added for the Möbius helper), still well within single-chunk scope.

**Sign off here, push back on the Möbius approach, or request a different test plan, and I'll proceed to implementation:**

Your response: 
