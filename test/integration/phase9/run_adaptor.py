"""Drive pymatgen's EnumlibAdaptor on a 50/50 disordered FCC and dump the
resulting structures as POSCAR.N. The enum.x it uses is whatever `which("enum.x")`
finds at import, so run this with the desired binary first on PATH (see README).
Usage: python run_adaptor.py <outdir>."""
import sys, os
from pymatgen.core import Structure, Lattice
from pymatgen.command_line.enumlib_caller import EnumlibAdaptor  # resolves enum.x at import

latt = Lattice([[0.0, 2.0, 2.0], [2.0, 0.0, 2.0], [2.0, 2.0, 0.0]])   # FCC primitive
s = Structure(latt, [{"Cu": 0.5, "Au": 0.5}], [[0.0, 0.0, 0.0]])
ad = EnumlibAdaptor(s, min_cell_size=1, max_cell_size=4)
ad.run()
outdir = sys.argv[1]; os.makedirs(outdir, exist_ok=True)
for i, st in enumerate(ad.structures):
    st.to(filename=f"{outdir}/POSCAR.{i}", fmt="poscar")
print(f"wrote {len(ad.structures)} structures to {outdir}")
