# Draft pull request for brainandforce/NormalForms.jl

Posted 20 Nov 2026 as https://github.com/brainandforce/NormalForms.jl/pull/26. Branch `perf/loops-and-copies` in ~/Library/Caches/enumlib-bench/NormalForms.jl on Gus-Mac-Pro
(patch also in scratch/normalforms-upstream/perf.patch). Posted from Gus's account (glwhart).

---

**Title:** Fewer allocations in hnfc, hnfr and snf (about 2× faster on Int matrices)

I have been working on speeding up [Enumlib.jl](https://github.com/glwhart/Enumlib.jl), my package for
enumerating derivative superstructures of a parent lattice. It uses NormalForms.jl for every Hermite and Smith
normal form it computes, often thousands of times in one enumeration, so these calls show up in its timings.
While profiling, I saw that a 3×3 `hnfc` call made 45 allocations, and that most of them came from copies of
rows and columns inside the reduction loops.

This pull request removes most of those allocations. The results are unchanged, and the calls are about twice as
fast on `Int` matrices. The changes to your code are small, 45 lines added and 13 removed in three files. Most of
the added lines come from writing each one-line broadcast as a three-line loop.

**Changes**

- In `reduce_cols_off_diagonal!` and `zero_row_and_col!`, the row and column updates are written as loops
  instead of broadcasts like `A[:,j] .-= mul .* A[:,k]`. A slice on the right-hand side of a broadcast copies
  the row or column every time. This agrees with what you found in #8, that loops beat `@.` here.
- `is_row_zero_after` and `is_col_zero_after` use a view instead of copying the slice.
- `eye(M::Matrix, dim)` builds the identity matrix in one allocation.
- `hnfc`, `hnfr` and `snf` copied their input with `deepcopy`. They now call a small helper, `copy_input`, which
  uses `copy` for a `Matrix` of integers. For a `Transpose` or `Adjoint` of such a matrix, it copies the
  underlying array and wraps it again, so the type of the result is unchanged. Other types still use `deepcopy`.

**Timings** (minimum time from `@benchmark`, Julia 1.12.7 on an Intel Xeon W-3245, random entries from −9 to 9)

| Call | main | this branch | Speedup | Allocations, main → branch |
|---|---|---|---|---|
| `hnfc`, 3×3 | 825 ns | 367 ns | 2.2× | 45 → 6 |
| `hnfr`, 3×3 | 745 ns | 389 ns | 1.9× | 35 → 8 |
| `snf`, 3×3 | 1549 ns | 764 ns | 2.0× | 75 → 10 |
| `hnfc`, 5×5 | 1986 ns | 1091 ns | 1.8× | 93 → 6 |
| `snf`, 5×5 | 4047 ns | 2188 ns | 1.8× | 193 → 10 |
| `hnfc`, 3×3 `Transpose` | 806 ns | 414 ns | 1.9× | 37 → 8 |
| `snf`, 5×5 `BigInt` | 166 µs | 147 µs | 1.1× | 5366 → 5004 |
| `hnfc`, 3×3 `SMatrix` | 259 ns | 266 ns | none | 7 → 7 |

In Enumlib.jl, listing the inequivalent supercells of the fcc lattice at volumes 8, 12 and 16 became 1.5× faster
with this branch (2.68 ms → 1.75 ms at volume 16).

**Checks**

- The package's own tests pass.
- I ran 17,400 calls on both main and this branch and compared the output as text. The calls were `hnfc`,
  `hnfr`, `snf` and `hnfc!(A, PositiveOffDiagonal)` on random matrices from 1×1 to 6×6 (a third of them with
  a zero row), and `hnfc`, `hnfr` and `snf` on 3×3 inputs of type `Transpose`, `Adjoint`, `BigInt`, `Int32`,
  `SMatrix` and `Float64`. Every result is identical, including the type of the returned factorization, and
  the calls that raise an error on main raise the same error on this branch.

I made these changes with assistance from Claude Code. I checked all the changes in the code.
