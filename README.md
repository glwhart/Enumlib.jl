# Enumlib.jl

Derivative-structure / superlattice enumeration in Julia. Generates the symmetry-distinct supercells and atomic colorings of a parent lattice — the building blocks for cluster-expansion fits, configuration sampling, and other alloy-modeling workflows that need a complete, deduplicated set of derivative structures.

This package is a Julia successor to the Fortran [`enumlib`](https://github.com/msg-byu/enumlib) by Gus L. W. Hart and Rodney W. Forcade. The algorithms and conventions are the same; the implementation is from-scratch in Julia and integrates with the modern Julia ecosystem (`Pkg`, `Spacey`, `MinkowskiReduction`, `NormalForms`, etc.).

## Installation

```julia
using Pkg
Pkg.add("Enumlib")
```

## Quick start

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
    fixOps = getFixingLatticeOps(h, LG)
    pG     = getPermG(h, fixOps, LG)
    length(getUniqueColorings(2, pG))
end
sum(counts)                        # matches the table in Hart & Forcade 2008
```

`radiusEnumHNFs(A; maxVol=15)` returns HNFs sorted by Minkowski-reduced cell radius if you want enumeration capped by reach instead of volume. `getSymInequivHNFsByCellRadius(A, x)` filters by an explicit radius bound.

For VASP-style structure I/O, the package also provides `enumStr`, `readStructenumout` (reads `struct_enum.out`), `readStrIn` (UNCLE `structures.in`), and `readEnergies`.

## Citing

If you use this package in published work, please cite:

- Gus L. W. Hart and Rodney W. Forcade, "[Algorithm for generating derivative structures](http://msg.byu.edu/docs/papers/GLWHart-enumeration.pdf)," *Phys. Rev. B* **77**, 224115 (2008).
- Gus L. W. Hart and Rodney W. Forcade, "[Generating derivative structures from multilattices: Application to hcp alloys](http://msg.byu.edu/docs/papers/multi.pdf)," *Phys. Rev. B* **80**, 014120 (2009).
- Gus L. W. Hart, Lance J. Nelson, and Rodney W. Forcade, "[Generating derivative structures at a fixed concentration](http://msg.byu.edu/docs/papers/enum3.pdf)," *Comp. Mat. Sci.* **59**, 101–107 (2012).
- Wiley S. Morgan, Gus L. W. Hart, and Rodney W. Forcade, "[Generating derivative superstructures for systems with high configurational freedom](http://msg.byu.edu/docs/papers/recStabEnumeration.pdf)," *Comp. Mat. Sci.* **136**, 144–149 (2017).

## Relationship to the Fortran enumlib

The Fortran [`enumlib`](https://github.com/msg-byu/enumlib) remains the reference implementation and supports features (concentration-restricted enumeration, site restrictions, displacement-direction enumeration) that this Julia package does not yet match. Use the Fortran tool when you need its full feature set or stable command-line workflow; reach for `Enumlib.jl` when you want HNF and coloring enumeration as composable Julia functions inside a larger Julia program.

## License

MIT — see [LICENSE](LICENSE).
