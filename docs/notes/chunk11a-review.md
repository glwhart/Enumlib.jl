# Chunk 11a — review and revise round

This file collects review items on chunk 11a (the single-structure POSCAR writer + the `supercell_fractional_positions` helper).

Workflow:
1. Read the chunk-11a files (listed below) and add inline `#gh ...` comments wherever something needs discussion.
2. Tell me you're done; I read your comments and respond inline here under numbered items.
3. We iterate until everything is signed off.
4. I batch any code changes as chunk 11a.1 (one commit) and we move to chunk 11b (`write_enumeration_archive` — bulk tarball write + manifest).

## Files in scope

**New (chunk 11a):**
- `src/io/poscar.jl` (~210 lines, including docstrings) — `to_poscar(io, structure, parent, hnf; ...)` and the internal `supercell_fractional_positions(hnf)` helper. New `src/io/` directory introduced (per phase11-design.md Q6-A: flat file, no submodule).
- `test/test_poscar.jl` (~180 lines) — 13 testsets fanning out to 879 individual tests. Helper-correctness, header-line format, basis-as-VASP-rows verification, species/count grouping, parse-back round-trips.

**Modified:**
- `src/Enumlib.jl` — `include("io/poscar.jl")` after the chunk-7.5/8 includes; export `to_poscar`. (Internal helper `supercell_fractional_positions` is *not* exported; accessible via `Enumlib.supercell_fractional_positions`.)
- `test/runtests.jl` — one new `include("test_poscar.jl")` line.

## Items found by me during chunk 11a implementation (already fixed; flagged for transparency)

### Item A — SNF convention verification

Before writing `supercell_fractional_positions`, I needed to confirm the NormalForms.jl SNF convention. Probed at the REPL: `NormalForms.snf(h)` returns a `Smith` struct with fields `S`, `U`, `V` such that **`U * H * V == S`**. Tuple-unpack returns `(S, U, V)` (chunk 3's `getPermG` uses `S, L, _ = snf(h)`, so its `L` is `U`).

The fractional-coordinate formula (derived from `U H V = S`):
- Site `(i_1, ..., i_D)` in SNF coords (`i_k ∈ 0..d_k-1`, with `d_k = S[k,k]`) corresponds to primitive-lattice integer position `U^{-1}·(i_1, ..., i_D)`.
- Its supercell-fractional position is `h^{-1}·U^{-1}·(i_1, ..., i_D) = V·(i_1/d_1, ..., i_D/d_D)` (mod 1).

So `supercell_fractional_positions` just iterates `(i, j, k)` in `getPermG`'s order, computes `V * (i/d_1, j/d_2, k/d_3)`, mod-1's the result.

Verified by hand on:
- HNF (1,1,4): S = diag(1,1,4), V = I, positions = (0,0,k/4) for k = 0..3. ✓
- HNF (1,2,2) at FCC n=4: positions (0,0,0), (0,0,0.5), (0,0.5,0), (0,0.5,0.5). ✓ (Visually matches the geometry of a 2×2×1 FCC primitive supercell.)
- 32-site cubic 2×2×2 (chunk 8 reference): 32 distinct positions in [0,1)^3. ✓

### Item B — VASP rows convention

Per your line-100 confirmation in the design review, VASP reads lattice vectors as rows of the POSCAR file. Julia stores basis with columns = lattice vectors (so `A_p[:, j]` is the j-th lattice vector). The writer transposes: row j of the POSCAR is column j of `A_super = parent.A * hnf.matrix`.

In code:

```julia
for j in 1:D
    for i in 1:D
        print(io, @sprintf("%22.12f", A_super[i, j]))
    end
    println(io)
end
```

A test case reads back the lattice vectors and confirms they match `A_super[:, j]` for each j (parse-back via `parse.(Float64, split(strip(lines[2 + j])))`).

### Item C — Header `energy_eV=` slot is *always last*

The `comment_extras` kwarg passes through additional `key=value` pairs (e.g., `["author=alice"]`). I deliberately insert them **before** the `energy_eV=` slot so the slot is always the last token on line 1. This makes calculator-side `sed`-style fills trivially target-able with a regex like `s/energy_eV=$/energy_eV=-123.45/`.

A test verifies `findfirst("author=alice", line1) < findfirst("energy_eV=", line1)`.

### Item D — Species line lists *only species present in this labeling*

Some structures may use a subset of the available colors (e.g., a monochromatic super-periodic structure with all atoms color 0). Writing `Ag Pt\n4 0\n` — listing both species but with one count zero — is valid POSCAR but some VASP versions choke on zero-count entries. The writer skips zero-count species:
> I think you need to list the zero count species explicitly. If you don't, then the user has to change the potcar files, dropping the elements that have count zero. That's really inconvenient for the user. It's better to just assume the user has the latest version of VASP and zeros are okay. 
```julia
present = [i for i in 1:k if counts[i] > 0]
println(io, join((species[i] for i in present), " "))
println(io, join((string(counts[i]) for i in present), " "))
```

Test coverage includes a monochromatic structure (verified that line 6 has just one species symbol).

### Item E — `species_symbols` default is letters, not numbers

Per Q3-B (your override of my lean): default is `["A", "B", "C", ...]` rather than required-with-real-chemistry. Implementation:

```julia
species = isempty(species_symbols) ?
    [string(Char(Int('A') + (i - 1))) for i in 1:k] :
    species_symbols
```

Test verifies the default line for a binary is exactly `"A B"`.
> But chemical symbols are okay too, right? 
### Item F — JuCE.jl R33 question (cross-repo): orbit-degeneracy field

While reading `EnumeratedStructure` for chunk 11a, I confirmed the type carries `hnf_degeneracy::Int` and `labeling_degeneracy::Int`. This is what JuCE's R33 (cross-repo request) was asking about. I haven't touched the cross-repo file in this chunk; it's just a note for whenever you reply to JuCE-side R33 — the answer is "yes, it carries these fields with these names." Not a chunk-11a action item; just surfacing.

## Items awaiting your review

You added two inline comments — one substantive, one confirmation. Numbered responses:

### 1. Item D — list zero-count species explicitly (substantive change)

Your call: list every species the supercell *could* hold, including counts of zero. Reason: stable POTCAR ordering on the calculator side. Dropping zero-count species would force them to also drop matching POTCAR sections by hand — annoying.

**Code change landed in chunk 11a.1.** The species + counts lines now always emit all `k` entries:

```julia
println(io, join(species[1:k], " "))
println(io, join((string(counts[i]) for i in 1:k), " "))
```

Position-writing loop is unchanged in shape — it still iterates `for color in 1:k`, and zero-count colors naturally emit zero position lines.

**One subtlety surfaced during the fix:** if `species_symbols` is *not* supplied, the writer falls back to inferring `k = maximum(coloring) + 1`. For a monochromatic all-color-0 structure that gives `k = 1`, undercounting the actual species count. The fix: when `species_symbols` is provided, use `length(species_symbols)` as the authoritative k. Bulk callers (chunk 11b's `write_enumeration_archive`) will always pass `species_symbols` of the correct length, so the inference path only matters for ad-hoc single-call users. Documented inline at the inference site.

Test "species line and counts: only species present" rewritten to check the new behavior — both species listed, both counts listed (one of which is zero) for monochromatic structures. 1454/1454 tests pass after the fix.

### 2. Item E — chemical symbols are okay too?

**Yes** — fully supported via the same kwarg. `species_symbols=["Ag", "Pt"]` (or any `Vector{String}` of correct length) passes through as-is to lines 6–7 of the POSCAR. The default `["A", "B", ...]` is just the fallback when no symbols are supplied. The existing test "user-supplied species_symbols passes through" already covers this case (verifies the species line is exactly `"Ag Pt"` when the kwarg is supplied with those values).

No code change for E.

---

## Summary

**Chunk 11a.1 lands as a focused fix-up commit:**

1. Code change to `to_poscar` (~5 lines): emit all k species + counts (including zeros) per Item 1; use `length(species_symbols)` as authoritative k when supplied.
2. Test update (~10 lines): "species line and counts" testset now expects all-k entries.
3. 1454/1454 tests pass after the fix.

Item 2 (E) is a no-op confirmation; no code change.

Plus a separate **README staleness commit**: replaced the broken `getFixingLatticeOps` reference (renamed to `getFixingOps` in chunk 3) with the current name; corrected the "Relationship to Fortran" paragraph to reflect concentration-restricted enumeration *is* supported now (chunks 6–8); added a "v0.2 pre-release; README will be rewritten at v0.2.0 release" status banner; pointed at chunk 11's POSCAR API.

**Next:** chunk 11b (`write_enumeration_archive` — bulk tarball write + manifest).
