# Enumlib.jl

A Julia successor to the Fortran `enumlib` derivative-structure enumeration tool, with significant improvements.
Enumlib enumerates symmetry-inequivalent decorations of a parent crystal lattice
across user-chosen supercell volumes, optionally constrained to a fixed
concentration. Outputs are ready for cluster expansion fitting, DFT/MLIP
training-database generation, or to use as inputs to downstream materials-science
workflows.

This site is organized as a [Diátaxis](https://diataxis.fr) four-quadrant
documentation tree:

- **[Tutorials](tutorials/index.md)** — learn by doing. Run your first
  enumeration, generate a DFT training set, work end-to-end.
- **[How-to guides](how-to/index.md)** — task-oriented recipes. "I have X, I
  want Y, what calls do I make?"
- **[Reference](reference/index.md)** — every public function, type, and kwarg.
  Authoritative API.
- **[Explanation](explanation/index.md)** — the why and the math. The primary algorithms, 
  key papers, dispatch logic, super-periodicity, glossary, how finite precision is handled.

!!! note "Status"
    Enumlib.jl is in active development for its v0.2.0 release. The API is
    settling but is not yet declared stable. See the
    [v0.2 plan](https://github.com/glwhart/Enumlib.jl/blob/main/docs/notes/v0.2-plan.md)
    for current scope.

## Install

```julia
using Pkg
Pkg.develop(url = "https://github.com/glwhart/Enumlib.jl")  # while unregistered
# Pkg.add("Enumlib") # After the package is registered
using Enumlib
```

## Quick taste

```julia
using Enumlib

parent = ParentLattice([0.5 0.5 0.0;
                        0.5 0.0 0.5;
                        0.0 0.5 0.5])             # FCC primitive
sites  = Sites([Site([0.0, 0.0, 0.0], [0, 1])])   # binary case, one site

enum = enumerate(parent, sites; supercells = VolumeRange(1:4))
length(enum)
```

For more, head to the [first-enumeration tutorial](tutorials/01-first-enumeration.md).
