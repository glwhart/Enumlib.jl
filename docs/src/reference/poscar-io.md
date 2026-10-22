# POSCAR I/O and result attachment

Public API for `to_poscar`, `write_enumeration_archive`, `read_results`, and `attach_results`.

```@docs
to_poscar
write_enumeration_archive
read_results
attach_results
```

## Reading structures back

The converse direction. `from_poscar` reads a POSCAR, and the `EnumeratedStructure`
constructor takes a structure already in memory (from an extxyz file, an ASE database or a DFT
code); both return the enumerated structure it is equivalent to, whatever cell, basis or
symmetry image it was given in.

```@docs
from_poscar
EnumeratedStructure(::Enumeration{3}, ::AbstractMatrix, ::AbstractMatrix, ::AbstractVector{<:Integer})
structure_lookup
```
