# Enumlib.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://glwhart.github.io/Enumlib.jl/dev)
[![CI](https://github.com/glwhart/Enumlib.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/glwhart/Enumlib.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/glwhart/Enumlib.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/glwhart/Enumlib.jl)

Derivative-structure / superlattice enumeration in Julia. Generates the symmetry-distinct supercells and atomic colorings of a parent lattice — the building blocks for cluster-expansion fits, configuration sampling, and other alloy-modeling workflows that need a complete, deduplicated set of derivative structures.

This package is a Julia successor to the Fortran [`enumlib`](https://github.com/msg-byu/enumlib) by Gus L. W. Hart and Rodney W. Forcade. The algorithms and conventions are the same; the implementation is from-scratch in Julia and integrates with the modern Julia ecosystem (`Pkg`, `Spacey`, `MinkowskiReduction`, `NormalForms`, etc.).

> **Status: 0.x.** The public API is settled enough to use and is covered by tests and docs, but minor releases may still make breaking changes. The full API reference lives at the [documentation site](https://glwhart.github.io/Enumlib.jl/dev).

## Installation

```julia
using Pkg
Pkg.add("Enumlib")
```

### Standalone binaries (no Julia required)

Each release attaches a per-platform tarball containing `enum.x`, `polya.x`, and
`makestr.x` — the same three executables the Fortran enumlib provided — with the
Julia runtime bundled in, so nothing else needs installing:

```bash
VER=$(curl -fsSL https://api.github.com/repos/glwhart/Enumlib.jl/releases/latest \
      | grep -o '"tag_name": *"v[^"]*"' | cut -d'"' -f4 | tr -d v)
curl -fsSL "https://github.com/glwhart/Enumlib.jl/releases/download/v${VER}/enumlib-jl-${VER}-linux-x86_64.tar.gz" | tar xz
export PATH="$PWD/enumlib-jl-${VER}-linux-x86_64/bin:$PATH"
enum.x --version
```

Built for `linux-x86_64`, `macos-aarch64`, and `windows-x86_64`; each asset has a
matching `.sha256`. The executables locate their bundled libraries relative to
their own path, so no `LD_LIBRARY_PATH` / `DYLD_*` variable needs setting — keep
`bin/` and `lib/` together and invoke `bin/enum.x` from anywhere.

**macOS note.** The binaries are not code-signed or notarized. If you download
through a browser, Gatekeeper quarantines the bundled `.dylib`s and the app will
refuse to start. Clear the flag on the extracted tree once:

```bash
xattr -dr com.apple.quarantine enumlib-jl-*-macos-aarch64
```

Downloading with `curl` or `wget` avoids the quarantine flag entirely.

## Quick start

Enumerate the symmetry-distinct binary decorations of FCC up to four atoms per cell:

```julia
using Enumlib

parent = ParentLattice([0.5 0.5 0.0;
                        0.5 0.0 0.5;
                        0.0 0.5 0.5])              # FCC primitive cell
sites  = Sites([Site([0.0, 0.0, 0.0], [0, 1])])    # one site, two species

e = enumerate_structures(parent, sites; supercells = VolumeRange(1:4))
length(e)                                          # 29
```

Count without enumerating — the same number, without building the structures:

```julia
count_inequivalent(parent, sites; supercells = VolumeRange(1:4))   # 29
```

Restrict to a fixed concentration (equal parts, at volume 4):

```julia
c  = Concentration([1//2, 1//2])
e2 = enumerate_structures(parent, sites; supercells = VolumeRange(4:4), concentration = c)
length(e2)                                         # 5
```

Write one of them as a VASP POSCAR:

```julia
s = e2[1]
open("POSCAR.1", "w") do io
    to_poscar(io, s, parent, e2.supercells[s.supercell_id].hnf;
              super_periodic = false, species_symbols = ["Ag", "Au"])
end
```

Before launching something large, ask what it will cost:

```julia
estimate_cost(parent, sites; supercells = VolumeRange(1:4))
```

For multilattices (HCP, perovskite, Heusler), per-sublattice concentrations, algorithm
selection, and the DFT/MLIP round-trip workflow, see the
[documentation](https://glwhart.github.io/Enumlib.jl/dev).

## Citing

If you use this package in published work, please cite the algorithm papers:

- Gus L. W. Hart and Rodney W. Forcade, "Algorithm for generating derivative structures," *Phys. Rev. B* **77**, 224115 (2008). [doi:10.1103/PhysRevB.77.224115](https://doi.org/10.1103/PhysRevB.77.224115) · [PDF](https://bsg.byu.edu/docs/papers/GLWHart-enumeration.pdf)
- Gus L. W. Hart and Rodney W. Forcade, "Generating derivative structures from multilattices: Application to hcp alloys," *Phys. Rev. B* **80**, 014120 (2009). [doi:10.1103/PhysRevB.80.014120](https://doi.org/10.1103/PhysRevB.80.014120) · [PDF](https://bsg.byu.edu/docs/papers/multi.pdf)
- Gus L. W. Hart, Lance J. Nelson, and Rodney W. Forcade, "Generating derivative structures at a fixed concentration," *Comp. Mat. Sci.* **59**, 101–107 (2012). [doi:10.1016/j.commatsci.2012.02.015](https://doi.org/10.1016/j.commatsci.2012.02.015) · [PDF](https://bsg.byu.edu/docs/papers/enum3.pdf)
- Wiley S. Morgan, Gus L. W. Hart, and Rodney W. Forcade, "Generating derivative superstructures for systems with high configurational freedom," *Comp. Mat. Sci.* **136**, 144–149 (2017). [doi:10.1016/j.commatsci.2017.04.015](https://doi.org/10.1016/j.commatsci.2017.04.015) · [PDF](https://bsg.byu.edu/docs/papers/recStabEnumeration.pdf)

The Pólya counting path additionally draws on Conrad W. Rosenbrock, Wiley S. Morgan, Gus L. W. Hart, Stefano Curtarolo, and Rodney W. Forcade, "Numerical algorithm for Pólya enumeration theorem," *ACM J. Exp. Algorithmics* **21**, 1.11 (2016). [doi:10.1145/2955094](https://doi.org/10.1145/2955094)

## Relationship to the Fortran enumlib

The Fortran [`enumlib`](https://github.com/msg-byu/enumlib) is the original implementation, and `Enumlib.jl` is checked against counts harvested from it. Covered here:

- HNF / SNF / supercell enumeration and Pólya counting (Hart-Forcade 2008).
- Multilattices — HCP, diamond, zinc-blende, half- and full-Heusler, perovskite (Hart-Forcade 2009).
- Site-restricted enumeration with per-site `allowed_labels` (heterogeneous sublattices).
- Concentration-restricted enumeration via the multinomial-hash algorithm (Hart-Nelson-Forcade 2012), including per-sublattice concentrations.
- Recursive-stabilizer tree enumeration for high-configurational-freedom cases (Morgan-Hart-Forcade 2017).
- A pre-flight cost estimator + memory-budget gate.
- Drop-in `enum.x`, `polya.x` and `makestr.x` command-line tools that read and write the Fortran `struct_enum.in` / `struct_enum.out` formats, available as standalone binaries (see [Installation](#standalone-binaries-no-julia-required)). pymatgen's `EnumlibAdaptor` drives them unchanged.

Not covered:

- Displacement-direction ("arrow") enumeration.
- Two-dimensional / surface enumeration (`surf` mode in `struct_enum.in`) — the reader rejects it with a clear error rather than guessing.

One deliberate difference in results: for symmetry-equivalent sublattices with overlapping label sets, `Enumlib.jl` keeps symmetry operations that the Fortran drops, so the two can report different counts. The wurtzite case is worked through in `docs/notes/chunk6.5-design.md` §11.4.

Reach for the Fortran tool if you need arrow or 2D enumeration; otherwise `Enumlib.jl` covers the same ground, either as composable Julia functions or through the drop-in executables.

## Contributing and releasing

Release procedure — register first, tag second — is documented in [RELEASING.md](RELEASING.md).

## License

MIT — see [LICENSE](LICENSE).
