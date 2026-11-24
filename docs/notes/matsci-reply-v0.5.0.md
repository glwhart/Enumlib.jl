Reply to matsci.org topic 67509 ([ANN] Enumlib.jl), draft for v0.5.0

---

An update since the announcement. Enumlib.jl is now at v0.5.0, and it is on conda-forge:

```
conda install -c conda-forge enumlib.jl
```

That gives you `enum.x`, `polya.x` and `makestr.x` on Linux (x86_64) and Intel macOS, with no separate Julia installation. For Apple silicon and Windows, use the standalone binaries on the [releases page](https://github.com/glwhart/Enumlib.jl/releases).

The standalone `enum.x` is also much faster than it was in September. Earlier builds compiled the enumeration code every time they ran, which took 7 to 9 s even for small inputs. From v0.5.0 the code is compiled ahead of time, so a run takes about 1 to 3 s, of which about 0.85 s is starting the Julia runtime. On the same inputs and the same machine:

| Case (supercell volumes) | Structures | Fortran `enum.x` | standalone `enum.x` | Enumlib.jl from Julia |
|---|---|---|---|---|
| fcc binary (1–12) | 10,850 | 1.8 s | 1.4 s | 0.17 s |
| fcc binary (1–16) | 163,373 | 6.4 s | 2.6 s | 1.6 s |
| fcc ternary (1–10) | 79,260 | 1.1 s | 1.6 s | 0.25 s |
| hcp ternary (1–6) | 584,531 | 4.5 s | 3.2 s | 1.3 s |

So the standalone `enum.x` beats the Fortran on the larger cases and loses on runs the Fortran finishes in about a second. Called from Julia, without the start-up cost, Enumlib.jl is 3 to 12 times faster than the Fortran on every case we timed. In every case the two codes produced the same structures, checked one by one up to symmetry.

The rest of the release is speedups inside the library: the symmetry reduction of supercells (5–370× faster), the recursive-stabilizer tree (1.3–1.6×), the resource check before an enumeration (about 2×) and the `struct_enum.out` writer (about 4×). The [changelog](https://github.com/glwhart/Enumlib.jl/blob/main/CHANGELOG.md) has the details.
