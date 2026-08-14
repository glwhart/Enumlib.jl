# Phase 9 — cross-code integration checks (drop-in `enum.x`)

These verify the Julia drop-in `enum.x` (`bin/enum.jl`, backed by
`src/io/struct_enum.jl`) against the **Fortran `enum.x`** and the real **pymatgen
`EnumlibAdaptor`**. They are **not** part of the CI suite because they need
external tools that a generic runner won't have. The CI-safe, pure-Julia
regression net for the same I/O lives in `test/test_struct_enum_io.jl`.

## What each layer proves

- **L1 — count parity.** For each case, the Fortran `enum.x`, the Julia
  reader→`enumerate`, and the locked reference count all agree.
- **L3-lite — structure parity.** Both binaries' `struct_enum.out` are expanded by
  `makeStr.py` and compared with pymatgen's `StructureMatcher` (order-insensitive).
  This is the real test of the writer + the SNF-`L`/labeling convention.
- **Full L3 — end-to-end.** The real `EnumlibAdaptor`, driven once by the Fortran
  `enum.x` and once by ours (first on `PATH`), on the same disordered structure —
  the definitive "zero pymatgen changes" proof.

## Setup

1. Build the Fortran enumlib (`enum.x`) — e.g. in a sibling `enumlib/` checkout:
   `git submodule update --init && (cd symlib/src && make F90=gfortran) && (cd src && make F90=gfortran enum.x)`
2. A Python env with pymatgen: `uv venv -p 3.12 venv && uv pip install -p venv/bin/python pymatgen`
   (pymatgen has no wheels for very new Pythons yet — pin 3.11/3.12).

## Run

```bash
export ENUM_X=/path/to/enumlib/src/enum.x
export MAKESTR_PY=/path/to/enumlib/aux_src/makeStr.py
export PMG_PYTHON=/path/to/venv/bin/python

# L1 (+ L3-lite if MAKESTR_PY & PMG_PYTHON are set):
julia --project=../../.. cross_check.jl

# Full L3 (EnumlibAdaptor both ways) — two runs with different PATH, since
# EnumlibAdaptor resolves which("enum.x") at import:
printf '#!/bin/bash\nexec julia --project=%s %s/bin/enum.jl "$@"\n' "$PWD/../../.." "$PWD/../../.." > /tmp/ourbin/enum.x
chmod +x /tmp/ourbin/enum.x; cp "$MAKESTR_PY" /tmp/ourbin/
PATH="$(dirname $ENUM_X):$(dirname $MAKESTR_PY):$PATH" $PMG_PYTHON run_adaptor.py out_fortran
PATH="/tmp/ourbin:$PATH"                               $PMG_PYTHON run_adaptor.py out_ours
$PMG_PYTHON compare_structs.py out_ours out_fortran   # (adjust glob: POSCAR.* vs vasp.*)
```

## Status (2026-07-16)

Last run on the author's machine: **L1 15/15**, **L3-lite 5/5 regimes**, **full L3 ✓**
(FCC 50/50 Cu/Au, 7 structures, identical to Fortran). See `docs/notes/phase9-design.md` §8.
