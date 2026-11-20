# Necklace enumeration and the recursive-stabilizer tree

Notes from a discussion on 19 Nov 2026. The literature in section 1 is from recollection, not from
rereading the papers. Read the papers before citing any of it. Sections 2–4 come from reading the
code and from measurements made that day.

Scripts: `bench/tree-profile/count_checks.jl` and `bench/tree-profile/profile_tree.jl`.

## Bottom line

A "placement" below means the choice the tree makes at one level: which of the still-empty sites
receive the next species, that is, a set of a sites out of the empty ones. For a binary alloy,
placing the first species fixes the whole colouring.

- Necklace algorithms solve the special case of our problem in which the only symmetry is a cyclic
  shift. For supercells with a cyclic translation group, that case sits inside Enumlib's problem.
- The first idea was to make the canonical check cheaper with a least-rotation test. The profile
  rules it out, because the current check already rejects a candidate after comparing it with about
  5 group elements.
- The real cost is that the tree tries every placement of the first species and throws away 97–98%
  of them. A fixed-content necklace generator could cut the number tried by about a factor of n.
  The estimated gain is about 2.5× overall.
- A cheaper first step, with no new theory, is to step through placements one after another instead
  of decoding each from its index. That would save about 1.4×.

## 1. What necklace enumeration is

A necklace is a string of n beads, each one of k colours, where two strings count as the same if one
is a rotation of the other. That means colourings counted up to the cyclic group of order n.
Bracelets also allow reflection, which gives the dihedral group.

- **Lyndon words.** A necklace that isn't a shorter block repeated is a Lyndon word. Counting Lyndon
  words works the same way as Enumlib dropping super-periodic structures. The number of necklaces is
  N = (1/n) Σ_{d|n} φ(d) k^{n/d}, and the Lyndon count uses the Möbius function in place of φ.
- **Generators.** The Fredricksen–Kessler–Maiorana algorithm lists one representative per necklace,
  in lexicographic order, in constant amortized time per output (Ruskey, Savage and Wang, about 1992).
  Sawada later gave constant-amortized-time generators for bracelets (about 2001) and for
  fixed-content necklaces, meaning a fixed number of beads of each colour (about 2003). Fixed content
  is the necklace version of a fixed concentration. I also recall a Sawada–Williams–Wong paper on
  generating necklaces in colex order. That matters because the tree uses colex order.
- **Canonical tests.** These generators never loop over group elements. They test whether a string is
  the smallest of its rotations in time proportional to n, using Duval's Lyndon factorization or
  Booth's least-rotation algorithm.
- **The general framework.** Orderly generation (Read, Faradzev) and canonical augmentation (McKay)
  cover both necklace generation and the recursive-stabilizer tree.

## 2. How this maps onto Enumlib

Following Hart–Forcade 2008, each supercell's translations form ℤ_d₁ × ℤ_d₂ × ℤ_d₃ from the Smith
normal form, with d₁·d₂·d₃ = n.

- **Cyclic case.** When the Smith form is (1, 1, n), translations act as cyclic shifts of the sites.
  Colourings up to translation are then necklaces, and dropping super-periodic ones keeps exactly the
  Lyndon words.
- **When it applies.** If n has no repeated prime factor, the Smith form has to be (1, 1, n). That
  covers n = 2, 3, 5, 6, 7, 10, 11, 13, 14, 15 and so on. Only volumes like 4, 8, 9, 12, 16, 18 and 20
  have some supercells whose translation group isn't cyclic. Those cases give a necklace problem on a
  two- or three-dimensional torus.
- **Multilattices.** Each bead is the n_D sites of one parent cell.
- **Full group.** The full group is translations combined with the parent rotations that keep the
  superlattice fixed. There are at most 48 rotations. Necklace tools handle only the translation part.

## 3. Measurements (MacBook, 19 Nov 2026, Enumlib at commit 7d6e07f)

These runs cover FCC, all concentrations, with `algorithm = :recursive_stabilizer`.

| FCC | time | structures | candidates tried | kept | group elements compared per check |
|---|---|---|---|---|---|
| binary n=13 | 0.10 s | 5,248 | 122,865 | 4.3% | 4.9 |
| binary n=16 | 0.67 s | 95,837 | 3.8 M | 2.6% | 5.6 |
| binary n=17 | 0.47 s | 84,270 | 2.75 M | 3.1% | 5.0 |
| binary n=18 | 2.5 s | 417,268 | 15.7 M | 2.7% | 5.2 |
| binary n=19 | 2.1 s | 348,208 | 13.1 M | 2.7% | 5.1 |
| binary n=20 | 12.6 s | 1.72 M | 80.7 M | 2.1% | 5.4 |
| ternary n=10 | 0.09 s | 55,461 | 210,117 | 30% | 3.5 |
| ternary n=12 | 0.82 s | 734,567 | 2.5 M | 32% (5% at the first level) | 3.7 |

In binary runs every check happens at the first level, where the first species is placed. The tree
enumerates all C(n, a) placements there and keeps only those that no group element maps to a smaller
placement.

The sampling profile of binary n=18 (2.7 s) splits the time this way:

- **Tree, 73%.**
  - About 30% goes to turning each candidate's index back into positions (`_inverse_colex_rank!`,
    mostly binomial-table lookups, `recursive_stabilizer.jl:165`).
  - About 25% goes to the canonical check (`_is_canonical`).
  - About 4% goes to updating the stabilizer.
- **Outside the tree.**
  - About 10% goes to reducing the HNFs by symmetry (`basesAreEquiv`).
  - About 9% goes to the super-periodicity filter (`_is_super_periodic`).

**A trap.** Julia's sampler records every thread, including idle ones, so per-function totals across
all samples overstate the time outside the tree. Read the tree view of the main thread instead
(`profile_tree.jl`).

## 4. Options, roughly in order of cost

1. **Step through placements one after another.** Build each placement from the previous one in
   constant average time instead of decoding every index from scratch through the binomial table.
   The output is unchanged. Expected gain is about 1.4×, from removing most of the 30% decoding share.
   Tested in memory on 19 Nov 2026 with identical output and 1.3–1.6× faster runs (section 5),
   then adopted in `src/algorithms/recursive_stabilizer.jl` the same day.
   - The rule for the next set in colex order, with sites written s₁ < … < s_a: find the first j
     where sⱼ + 1 is free (not equal to sⱼ₊₁, or within range if j = a). Increase sⱼ by one and
     reset s₁, …, sⱼ₋₁ to 0, …, j−2. For example, 2 of 5 runs {0,1} → {0,2} → {1,2} → {0,3} →
     {1,3} → {2,3} → {0,4} → … → {3,4}.
   - Each step touches one or two entries on average, so the cost per set is constant.
   - The order is identical to the current one, so the existing tests still apply. Only the sites
     that changed need their species rewritten.
2. **Fixed-content necklace generator for cyclic supercells.** At the first level, generate only
   placements that are already smallest under translation (about 1/n of them), then check those
   against the rotations.
   - Points to settle:
     - Enumlib's canonical order is colour by colour in colex, not plain lexicographic order. Either
       use a colex necklace generator, or make sure a different order still gives the property the
       pruning relies on. That property is that a partial colouring which isn't canonical never
       extends to a canonical one.
     - Deeper levels of the tree work with a smaller stabilizer, which is no longer a plain cyclic
       group.
   - Expected gain is about 2.5× overall at n≈18–20, limited by the HNF and super-periodicity steps.
3. **Least-rotation canonical check.** Rejected. It costs up to 48 least-rotation computations of
   length n per candidate, against about 5 cheap comparisons now.
4. **Super-periodicity filter.** It costs 9% at n=18. It copies an array per check (`getindex` →
   `similar` in the profile). Avoiding that copy is probably easy.
5. **Counting.** Nothing to gain. Pólya counting already takes milliseconds.

## 5. Option 1, tested in memory and then adopted (19 Nov 2026)

Adopted in `src/algorithms/recursive_stabilizer.jl`, with a test in
`test/test_recursive_stabilizer.jl` that `_next_colex!` visits subsets in the same order as
`_inverse_colex_rank!`. After adoption the full test suite passed and the five output hashes below
matched the original code exactly. `successor_patch.jl` is now only a record of the test, and
`compare_successor.jl original` now runs the adopted code.

The stepping version was tested without editing `src/`. The file
`bench/tree-profile/successor_patch.jl` holds a copy of `_descend!` with the new loop, plus one new
helper, `_next_colex!`. After `using Enumlib`, including the file replaces `_descend!` in that Julia
session's memory only.

### Results

- **Same order.** For every m ≤ 14 and every a, stepping gives exactly the same sequence of sets as
  `_inverse_colex_rank!`. The patch file checks this each time it loads.
- **Same output.** FCC binary at n = 16, 18 and 20 and ternary at n = 10 and 12 gave identical
  structure lists with and without the patch, compared by a hash of each full list.
- **Tests.** The full test suite passed with the patch loaded.
- **Speed.** `bench/tree-profile/compare_successor.jl original|patched` reproduces this table. Times
  are the best of three runs of a full enumeration of one volume, all concentrations, MacBook.

| FCC | original | stepping version | speedup |
|---|---|---|---|
| binary n=16 | 0.77 s | 0.50 s | 1.5× |
| binary n=18 | 2.53 s | 1.68 s | 1.5× |
| binary n=20 | 12.86 s | 7.83 s | 1.6× |
| ternary n=10 | 0.07 s | 0.05 s | 1.4× |
| ternary n=12 | 0.82 s | 0.63 s | 1.3× |

### How the improvement works

**What the tree does at each level.** Say m sites are still empty and the next species needs a of
them. The tree must try every set of a sites out of the m, which is C(m, a) sets. For each one it
writes the species into those sites and runs the canonical check. If the check passes it goes
deeper, and either way it then erases the species again.

The sets are tried in colex order. To compare two sets, compare their largest elements, and the set
with the smaller one comes first. If those tie, compare the next largest, and so on. In this table
the top row is the position in the order and the bottom row is the set of empty-site indices, for 2
sites out of 5:

| step | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|
| set | {0,1} | {0,2} | {1,2} | {0,3} | {1,3} | {2,3} | {0,4} | {1,4} | {2,4} | {3,4} |

**What the original code does.** It loops x = 0, 1, …, C(m, a) − 1, and for each x it rebuilds the
set with that position number (`_inverse_colex_rank!`), working from the largest element down.

1. The largest element is the biggest c with C(c, a) ≤ x. The code finds it by starting at
   c = a − 1 and stepping c upward, reading one binomial coefficient per step.
2. It then subtracts C(c, a) from x and repeats with a − 1 for the next element down.

So every set costs a walk up the binomial table for each of its a elements, and each read also
checks bounds.

**What the new code does.** It keeps the current set as a sorted list s₁ < s₂ < … < s_a and changes
it into the next set.

1. Starting from the smallest element, find the first one, sⱼ, that can move up by one without
   landing on sⱼ₊₁. For the largest element the condition is instead sⱼ + 1 < m.
2. Increase that element by one.
3. Reset the elements below it to 0, 1, …, j − 2.

For example, in {2,3} → {0,4} the 2 is blocked by the 3, so the 3 becomes 4 and the 2 resets to 0.
If no element can move, the set was the last one.

**Why this gives the same order.** Colex order compares sets from the largest element down. So the
next set keeps the large elements and changes the smallest element that can change. Raising sⱼ by
one is the smallest possible increase there, and 0, 1, 2, … below it is the earliest set with that
value. The machine check above confirms it.

**Why it is cheaper.** Usually the smallest element can move, so a step changes one number. Longer
resets happen less often. The table below gives exact counts. The middle column is the average
number of binomial-table reads that `_inverse_colex_rank!` makes to rebuild one set. The right column
is the average number of list entries `_next_colex!` changes per step.

| a sites out of m | number of sets | original: table reads per set | new: entries changed per set |
|---|---|---|---|
| m=12, a=4 | 495 | 24.0 | 1.44 |
| m=18, a=9 | 48,620 | 58.5 | 1.90 |
| m=20, a=10 | 184,756 | 70.0 | 1.91 |

**Why the gain is 1.5× and not more.** The tree still tries all C(m, a) sets, and every one still
goes through the canonical check. Decoding was about a third of the run time at binary n=18, and that
third is what goes away (2.53 s → 1.68 s).

**Why the output is guaranteed to be the same.** The same sets reach the canonical check in the same
order, against the same stabilizer. So every keep or prune decision is the same, and the structures
come out in the same order.

### The code change

Only the loop over candidate sets differs. The other lines of `_descend!` are copied unchanged.
Comments and blank lines are left out of this diff.

```diff
-    chosen_slot_idxs = Vector{Int}(undef, a_here)
-    for x in 0:branching-1
-        _inverse_colex_rank!(chosen_slot_idxs, x, a_here, binom)
+    chosen_slot_idxs = collect(0:a_here-1)          # first subset in colex order
+    while true
         for i in chosen_slot_idxs
             partial[unfilled_positions[i + 1]] = Int8(depth)
         end
         if _is_canonical(partial, parent_stab, depth + 1)
             new_stab = _stabilize_partial(parent_stab, partial)
             _descend!(output, partial, new_stab, multiplicities, depth + 1, n, k,
                       site_mask, binom)
         end
         for i in chosen_slot_idxs
             partial[unfilled_positions[i + 1]] = Int8(-1)
         end
+        _next_colex!(chosen_slot_idxs, n_unfilled) || break
     end
```

The new helper:

```julia
function _next_colex!(idx::Vector{Int}, m::Int)
    a = length(idx)
    j = 1
    while j < a && idx[j] + 1 == idx[j + 1]
        j += 1
    end
    if j == a && idx[a] + 1 >= m
        return false
    end
    idx[j] += 1
    for i in 1:j-1
        idx[i] = i - 1
    end
    return true
end
```

If adopted, `_inverse_colex_rank!` would no longer be called from the tree. The binomial table would
still be needed only if something else uses it.

## 6. Can the tree avoid trying all C(m, a) sets?

**For binary alloys the tree does no pruning at all.** All of a binary structure is decided at the
first level, where the stabilizer is the whole group. So the tree reduces to trying every set of the
right size and checking each one, and 97–98% are rejected (section 3). The tree's pruning helps only
from the second species on, and that is why ternary keeps 32% of its checks against 2–3% for binary.

**With the current generator, every set must be checked.** The generator ignores symmetry, so it
has no way to know a set is a duplicate without checking it. Each check is cheap (about 5 group
elements), but there are C(m, a) of them.

There are two ways to try fewer sets. Both are recollection about the literature, not tested ideas.

1. **Generate only sets that are already smallest under translation.** This is option 2 above. For a
   supercell with a cyclic translation group, a fixed-content necklace generator (Sawada) produces
   only those sets, about C(m, a)/n of them. It needs no translation check, because the generator
   builds that property in. The rotation check still runs on each one. At binary n=18 it would keep
   roughly half of them (2.7% kept now against about 1/18 ≈ 5.5% produced). This only covers the
   first level, where the stabilizer is the whole group, and only cyclic supercells.
2. **Place one site per level instead of one species per level, and prune partial sets.** Then
   rejecting a partial set would discard every completion of it at once. The difficulty is that
   with colex order, being smallest is not decided by the sites chosen so far. Suppose the sites are
   added from the largest down. A group element can map a site added later above the ones already
   chosen, so a partial set that looks beaten can still complete to a canonical set. Pruning on
   partial sets would then lose structures. The standard general fix is McKay's canonical
   augmentation, which accepts a child according to how the new site was added, not by comparing
   whole sets. That would be a redesign of the tree, not a local change.

## Open questions

- How do the shares in section 3 change at n = 22–24, and for HCP or other multilattices?
- What fraction of the time goes to supercells whose translation group isn't cyclic?
- Read the Sawada fixed-content and colex papers properly before committing to option 2.
