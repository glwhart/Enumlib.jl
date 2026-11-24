# Draft issue for brainandforce/NormalForms.jl

Posted 20 Nov 2026 as https://github.com/brainandforce/NormalForms.jl/issues/27. Draft 2, written after the literature reading and the prototype. Posted from Gus's account
(glwhart). Prototype: scratch/normalforms-upstream/hnf_mod_det.jl (278 lines); tests test_mod_det.jl, cross_flint.jl;
measurements overflow.jl, overflow2.jl, growth.jl.

---

**Title:** Int64 overflow in `hnfc` gives wrong Hermite forms, sometimes with no error

While testing the speedups in #26 for my package [Enumlib.jl](https://github.com/glwhart/Enumlib.jl), I compared
`hnfc` on random integer matrices with the same call on `BigInt` copies of them. The comparison turned up the problem
below. It is in the current release (0.1.10) and #26 does not change it.

**The problem**

Intermediate values in `hnf_ma!` overflow `Int64` even when the answer is small. Usually the result is
`AssertionError: U is not unimodular`. For 3×3 matrices with large entries the wrong `H` comes back with no error.

```julia
A = [-2418 -2096 -2389; -1433 2107 -1800; -2007 1321 756]
hnfc(A).H        # [1 0 0; 0 1 0; -17078536264 -16215364689 25023961348]
hnfc(big.(A)).H  # [1 0 0; 0 1 0; -17959973296 -16215364689 25023961348]
```

`H[3,1]` is wrong. The returned `U` passes `isunimodular`, but `A*U != H`.

How often it happens (`hnfc` on random square matrices, compared with `big.(A)`):

| Size | Entries | Wrong `H` | Error raised |
|---|---|---|---|
| 6×6 | −9 to 9 | 9% | yes |
| 7×7 | −9 to 9 | 68% | yes |
| 8×8 | −9 to 9 | 99.5% | yes |
| 3×3 | −1000 to 1000 | 0 of 20,000 | |
| 3×3 | −3000 to 3000 | 22 of 20,000 | no |
| 3×3 | −10⁴ to 10⁴ | 15% | no |
| 3×3 | −10⁵ to 10⁵ | 97% | no |

The answers themselves are small. At 10×10 with entries −9 to 9 the largest entry of the correct `H` or `U` has 12
digits. The largest intermediate entry in `hnf_ma!` has 286 digits. This growth comes from the elimination order.
Clearing one row at a time across all remaining columns is known to give exponential growth in the size of the
intermediate entries (Storjohann's survey talk, slide 20, citing Fang and Havas, ISSAC 1997). The Kannan–Bachem
order keeps the growth polynomial, but in my tests it still passes 18 digits from about 7×7.

This is related to #2 and to your comment on #20. There you preferred not to change the output type, and you noted
that overflow is rare in your own work. I agree on both points. What worries me is the silent case, because a user
has no signal to switch to `BigInt`.

**A possible fix**

For square nonsingular input there is a standard method that removes the problem without changing the output type.
It works modulo the determinant d = |det A| (Domich, Kannan and Trotter 1987). FLINT implements it as
`fmpz_mat_hnf_modular`, citing that paper and Cohen's Algorithm 2.4.8. Every intermediate entry stays below d, so the
sizes are known before any arithmetic starts. No prediction of intermediate growth is needed.

I wrote a prototype in this form:

- The Hadamard bound (the product of the column lengths) bounds d and every minor of A. If it is below 2^30 all
  arithmetic is `Int64`. If it is below 2^62 the products are formed in `Int128`. Otherwise the function declines,
  so it never returns a wrong answer.
- `U` is computed afterwards as `A^-1 H`, which is unique for nonsingular A, using a fraction-free inverse.
- Output is `Matrix{Int}`, the same type as now, in both rounding conventions.

Checks so far:

- 46,746 comparisons with `hnfc` on `BigInt` copies (sizes 1 to 12, 3×3 entries up to 10⁶, matrices with many
  nontrivial diagonal entries, both rounding modes), run with every product and sum checked for overflow. There were
  no wrong answers and no overflows.
- 18,941 matrices compared with FLINT's `hnf` through Nemo.jl, with no disagreements.
- With the Hadamard-bound guarantee, 3×3 matrices with entries up to about 960,000 are covered, 6×6 up to 526, and
  10×10 up to 23. In practice random matrices with entries −9 to 9 fit up to 14×14.

Timings (minimum, ns, Julia 1.12, Intel Xeon W-3245):

| Matrix | `hnfc` now | prototype, H only | prototype, H and U |
|---|---|---|---|
| 3×3, small determinant | 341 | 244 | 409 |
| 3×3, entries −9 to 9 | 391 | 349 | 532 |
| 5×5, entries −9 to 9 | 1140 | 1063 | 1762 |
| 8×8, entries −9 to 9 | fails | 5240 | 9097 |

So `H` alone is faster than now, and `H` with `U` is 1.2 to 1.5 times slower.

The prototype is about 280 lines with comments, and non-square or singular input would still go through `hnf_ma!`.
Before preparing a pull request I wanted to ask whether you would like this in NormalForms.jl, and if so in what
form. It could replace the square nonsingular case inside `hnfc`/`hnfr`, or be a separate function.

I made these measurements and the prototype with assistance from Claude Code. I checked all the results.
