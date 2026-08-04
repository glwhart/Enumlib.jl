"""Order-insensitive structure-set comparison of two dirs of enumerated POSCARs.
Handles both makeStr `vasp.N` output (with pymatgen's EnumlibAdaptor fixups) and
plain `POSCAR.N`. Usage: python compare_structs.py <dirA> <dirB>."""
import sys, glob, re
from pymatgen.io.vasp.inputs import Poscar
from pymatgen.analysis.structure_matcher import StructureMatcher

def load(d):
    out = []
    for f in sorted(glob.glob(f"{d}/vasp.*") + glob.glob(f"{d}/POSCAR.*")):
        data = open(f).read()
        data = re.sub("scale factor", "1", data)
        data = re.sub(r"(\d+)-(\d+)", r"\1 -\2", data)   # EnumlibAdaptor fixups
        try:
            out.append(Poscar.from_str(data).structure)
        except Exception as e:
            print(f"  load fail {f}: {e}")
    return out

a, b = load(sys.argv[1]), load(sys.argv[2])
print(f"loaded: {sys.argv[1]}={len(a)}  {sys.argv[2]}={len(b)}")
sm = StructureMatcher()
used = [False] * len(b); un = 0
for s in a:
    h = next((i for i, x in enumerate(b) if not used[i] and sm.fit(s, x)), None)
    if h is None: un += 1
    else: used[h] = True
ok = un == 0 and all(used) and len(a) == len(b) and len(a) > 0
print("RESULT:", "MATCH" if ok else f"MISMATCH (unmatched_a={un}, unmatched_b={used.count(False)})")
