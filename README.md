# Enumlib.jl

Derivative-structure / superlattice enumeration in Julia. Generates the symmetry-distinct supercells and atomic colorings of a parent lattice — the building blocks for cluster-expansion fits, configuration sampling, and other alloy-modeling workflows that need a complete, deduplicated set of derivative structures.

This package is a Julia successor to the Fortran [`enumlib`](https://github.com/msg-byu/enumlib) by Gus L. W. Hart and Rodney W. Forcade. The algorithms and conventions are the same; the implementation is from-scratch in Julia and integrates with the modern Julia ecosystem (`Pkg`, `Spacey`, `MinkowskiReduction`, `NormalForms`, etc.).

> **Status: v0.2 pre-release (in active development).** The user-facing API has changed substantially across chunks 1–11. This README will be rewritten at the v0.2.0 release (Phase 12 of `docs/notes/v0.2-plan.md`); until then, the snippet below shows the legacy lattice-coordinate API. The new public API surface — `enumerate(parent, sites; supercells, concentration, …)`, `count_inequivalent`, `estimate_cost`, plus `Concentration`/`ConcentrationRange` types — is documented in source docstrings and in `docs/notes/v0.2-plan.md`.

## Installation

While the package is unregistered, install via dev path:

```julia
using Pkg
Pkg.develop(path = "https://github.com/glwhart/Enumlib.jl")
```

`Pkg.add("Enumlib")` will work after JuliaRegistrator publishes v0.2.0.

## Quick start (legacy lattice-coordinate API; pre-v0.2.0)

Enumerate symmetry-inequivalent superlattices of FCC up to 8 sites, count the binary colorings per supercell:

```julia
using Enumlib
using Spacey: pointGroup

# FCC parent lattice (columns are basis vectors)
A = [0.0 0.5 0.5;
     0.5 0.0 0.5;
     0.5 0.5 0.0]

LG, _ = pointGroup(A)              # lattice-coordinate point group

# All symmetry-distinct HNFs up to volume 8
hnfs = vcat([getSymInequivHNFs(n, LG) for n in 1:8]...)
@show length(hnfs)                 # 55

# Count symmetry-distinct binary colorings per supercell
counts = map(hnfs) do h
    fixOps = getFixingOps(h, LG)   # renamed from getFixingLatticeOps in chunk 3
    pG     = getPermG(h, fixOps, LG)
    length(getUniqueColorings(2, pG))
end
sum(counts)                        # matches the table in Hart & Forcade 2008
```

`radiusEnumHNFs(A; maxVol=15)` returns HNFs sorted by Minkowski-reduced cell radius if you want enumeration capped by reach instead of volume. `getSymInequivHNFsByCellRadius(A, x)` filters by an explicit radius bound.

For VASP-style structure I/O, the package also provides `enumStr`, `readStructenumout` (reads `struct_enum.out`), `readStrIn` (UNCLE `structures.in`), and `readEnergies`. These legacy I/O functions will move to `Enumlib.LegacyImport.foo(...)` at v0.2.0; the new POSCAR-based DFT/MLIP roundtrip workflow is in chunk 11 (`to_poscar`, `write_enumeration_archive`, `read_results`).

## Citing

If you use this package in published work, please cite:

- Gus L. W. Hart and Rodney W. Forcade, "[Algorithm for generating derivative structures](http://msg.byu.edu/docs/papers/GLWHart-enumeration.pdf)," *Phys. Rev. B* **77**, 224115 (2008).
- Gus L. W. Hart and Rodney W. Forcade, "[Generating derivative structures from multilattices: Application to hcp alloys](http://msg.byu.edu/docs/papers/multi.pdf)," *Phys. Rev. B* **80**, 014120 (2009).
- Gus L. W. Hart, Lance J. Nelson, and Rodney W. Forcade, "[Generating derivative structures at a fixed concentration](http://msg.byu.edu/docs/papers/enum3.pdf)," *Comp. Mat. Sci.* **59**, 101–107 (2012).
- Wiley S. Morgan, Gus L. W. Hart, and Rodney W. Forcade, "[Generating derivative superstructures for systems with high configurational freedom](http://msg.byu.edu/docs/papers/recStabEnumeration.pdf)," *Comp. Mat. Sci.* **136**, 144–149 (2017).

## Relationship to the Fortran enumlib

The Fortran [`enumlib`](https://github.com/msg-byu/enumlib) remains the reference implementation. As of the v0.2 pre-release, `Enumlib.jl` covers:

- HNF / SNF / supercell enumeration and Pólya counting (Hart-Forcade 2008).
- Concentration-restricted enumeration via the multinomial-hash algorithm (Hart-Nelson-Forcade 2012).
- Recursive-stabilizer tree enumeration for high-configurational-freedom cases (Morgan-Hart-Forcade 2017).
- A pre-flight cost estimator + memory-budget gate.

Not yet covered (deferred to v0.3+):

- Multi-lattice / multi-site `Sites` (perovskite, half-Heusler, slab geometries).
- Site-restricted (per-site `allowed_labels`) enumeration.
- Displacement-direction ("arrow") enumeration.

Use the Fortran tool when you need those features or its stable command-line workflow; reach for `Enumlib.jl` when you want HNF, Pólya counting, and concentration-restricted enumeration as composable Julia functions inside a larger Julia program.

## License

MIT — see [LICENSE](LICENSE).
