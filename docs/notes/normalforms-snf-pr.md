# Draft pull request for brainandforce/NormalForms.jl: snf zero pivot

Posted 20 Nov 2026 as https://github.com/brainandforce/NormalForms.jl/pull/28. Branch fix/snf-zero-pivot (commit 6b8a61f, from upstream main) in ~/Library/Caches/enumlib-bench/NormalForms-snf.
Patch and scripts: scratch/normalforms-upstream/snf-fix/. Posted from Gus's account (glwhart).

---

**Title:** Fix DivideError in `snf` when row and column k are zero at step k

`snf` throws `DivideError` on some matrices with zero determinant, including a diagonal one:

```julia
snf([0 0; 0 9])               # DivideError (expected diagonal [9, 0])
snf([0 0 0; 0 2 0; 0 0 3])    # DivideError (expected diagonal [1, 6, 0])
snf([0 0; 9 0])               # works
```

I ran into this while testing other changes (#26, #27).

**Cause**

In `snf_ma!`, when row k to the right of the diagonal and column k below it are all zero, step k is skipped with
`continue`. That leaves a zero at `A[k,k]`. At step k+1, `enforce_divisibility!` computes `A[k+1,k+1] % A[k,k]`,
which divides by zero. A zero left in front would also be in the wrong place, since the Smith form puts the zero
invariant factors last.

**Change**

When step k finds no pivot, the code now looks for any nonzero entry of `A[k:end, k:end]` and swaps its column
into position k (recording the swap in `V`). The row swap that follows in the existing code moves it to `A[k,k]`. If
the whole remaining submatrix is zero, the matrix is finished. This is 11 lines added and 2 removed in
`src/smith.jl`.

**Tests**

- I added 7 matrices to the "Known problematic matrices" testset, checking the diagonal and `U*M*V == S`. They
  include the two examples above, `diagm([0, 0, 5, 0, 3])`, the 3×3 zero matrix, and non-square cases. Six of the
  7 throw `DivideError` on main (the zero matrix already works). The full test suite passes (113 tests).
- I compared the invariant factors with FLINT's Smith form (through Nemo.jl) on 4,000 matrices, most of them with
  zero determinant: products B*C of lower rank, matrices with zeroed rows and columns, random m×n for m, n up to 6,
  and diagonal matrices with zeros. Apart from the two older problems described below (a sign, and the order of the
  factors), the invariant factors agreed with FLINT on every matrix. `U*A*V == S` held with `U` and `V` unimodular,
  and none threw. Main threw `DivideError` on 540 of them.
- On 4,990 random full-rank matrices, `S`, `U` and `V` are identical to main.

**Not addressed here**

The comparison with FLINT also showed two older problems that this change does not touch. They occur on main as
well, for full-rank input too:

- The first invariant factor can come out negative, for example `snf([-5 0 0 0])` gives -5. The sign is fixed
  only inside `enforce_divisibility!`, which returns early for the first entry.
- The divisibility chain is not always complete. `snf(diagm([-12, 6, -6, -7]))` gives the diagonal `[6, 6, 1, 84]`:
  the right values, but in the wrong order (`[1, 6, 6, 84]` is expected). Each step makes `A[k,k]` a multiple of `A[k-1,k-1]`, and that is
  not carried back to earlier entries.

I can look at these separately if that would help.

I made these changes with assistance from Claude Code but I had my brain on the whole time and was carefully monitoring what was going on.
