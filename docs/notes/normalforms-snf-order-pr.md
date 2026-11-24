Title: snf: Make sure each entry on the diagonal actually divides the entries following it (not the case right now). Only 9 lines are added.

This fixes the two older problems I mentioned at the end of #28. Both occur on main for full-rank input, and they are independent of the zero-pivot change in #28, so either PR can be merged first. At first I figured I could live with it because at this point it doesn't make any of my answers wrong. But for unit testing it can mess things up and a routine that relies on the correct ordering could get tripped up by this.

In Enumlib.jl I use the Smith form of each supercell matrix to order the sites of the supercell and print its diagonal in the output files that other codes read. For one hcp supercell, `snf([2 0 0; 0 2 0; 0 0 1])` gives the diagonal `[2, 1, 2]`, where the Smith form has `[1, 2, 2]`. I'd feel better if the library gave the standard form than if I reordered it myself in every place I call `snf`. (There are at least 6 places. I'd like to avoid the code bloat of adding checks in all these places.)

**The two problems**

- The divisibility chain is not always complete. `snf(diagm([-12, 6, -6, -7]))` gives `[6, 6, 1, 84]` instead of `[1, 6, 6, 84]`. At step k, `enforce_divisibility!` makes `A[k,k]` a multiple of `A[k-1,k-1]`, but in doing so it can replace `A[k-1,k-1]` by a smaller value that no longer is a multiple of `A[k-2,k-2]`.
- The first invariant factor can be negative. `snf([-5 0 0 0])` gives `-5`. The sign is fixed only inside `enforce_divisibility!`, which returns early for the first entry.

**Change**

In `snf_ma!`, after the existing call to `enforce_divisibility!` at step k, the same step is repeated on the earlier adjacent pairs, moving back along the diagonal. It stops at the first pair that already divides, since everything before it is then a chain. After the loop, any negative diagonal entry is negated together with the matching row of `U`. This is 9 lines added to `src/smith.jl`, and it reuses the existing function.

**Tests**

- I added 5 matrices to the "Known problematic matrices" testset, checking the diagonal and `U*M*V == S`: the two examples above, the `[2 0 0; 0 2 0; 0 0 1]` case, a non-diagonal 3×3 (`[4 -4 2; 4 -2 -2; -3 -1 2]`, which main gives as `[2, 1, 18]`), and `[-5 0; 0 0]`. All 5 fail on main. The full suite passes.
- I compared the diagonal with FLINT's Smith form (through Nemo.jl) on 3,000 matrices up to 6×6 with `BigInt` entries: random full-rank, random, and diagonal with random signs. With this change every diagonal agrees with FLINT, against 980, 983 and 613 of 1,000 on main. `U` and `V` were unimodular and `U*M*V == S` in every case. With #28 applied as well, the same holds for rank-deficient matrices.
- On random full-rank matrices, the 19,610 that main already gets right have exactly the same `S`, `U` and `V` with this change, and the 359 that main gets wrong are now correct.
- On the 2,961 lower-triangular 3×3 Hermite forms with determinant up to 16, the time per call goes from about 730 ns to about 740 ns.

I made these changes with assistance from Claude Code but I didn't turn all my thinking over to Claude. Pretty sure this is all right and that no regressions have been introduced. I ran Enumlib.jl's full test suite with the updated library and it passes.
