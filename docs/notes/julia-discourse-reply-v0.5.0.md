Reply to Julia Discourse topic 139475 ([ANN] Enumlib.jl), draft for v0.5.0

---

An update since the announcement. Enumlib.jl is now at v0.5.0, and most of the work since September has gone into speed. Compared with v0.4.2, enumerations run 1.5 to 5 times faster. The main gains are in the symmetry reduction of supercells (5–370× faster), the recursive-stabilizer tree (1.3–1.6×), the `estimate_cost` check before an enumeration (about 2×) and the `struct_enum.out` writer (about 4×).

Here is how it compares with the Fortran enumlib on the same inputs and the same machine. The Julia column is a call from a running session (enumerate and write `struct_enum.out`). The standalone column is the compiled `enum.x`, including its start-up.

| Case (supercell volumes) | Structures | Fortran `enum.x` | standalone `enum.x` | Enumlib.jl from Julia |
|---|---|---|---|---|
| fcc binary (1–12) | 10,850 | 1.8 s | 1.4 s | 0.17 s |
| fcc binary (1–16) | 163,373 | 6.4 s | 2.6 s | 1.6 s |
| fcc ternary (1–10) | 79,260 | 1.1 s | 1.6 s | 0.25 s |
| hcp ternary (1–6) | 584,531 | 4.5 s | 3.2 s | 1.3 s |

From Julia, Enumlib.jl is 3 to 12 times faster than the Fortran on every case we timed, and the two codes produced the same structures, checked one by one up to symmetry.

The standalone executables changed too. Earlier builds compiled the enumeration code every time they ran, which took 7 to 9 s even for small inputs. From v0.5.0 the code is compiled ahead of time (PackageCompiler with an example run), so a run takes about 1 to 3 s, of which about 0.85 s is starting the Julia runtime. They are also on conda-forge for Linux (x86_64) and Intel macOS, so Python users can get them without installing Julia:

```
conda install -c conda-forge enumlib.jl
```

For Apple silicon and Windows, the binaries are on the [releases page](https://github.com/glwhart/Enumlib.jl/releases). The [changelog](https://github.com/glwhart/Enumlib.jl/blob/main/CHANGELOG.md) has the details.
