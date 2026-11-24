# Announcement drafts — Enumlib.jl

Venues, in the order I would use them:

1. **matsci.org** (Materials Science Community Discourse) — where the pymatgen /
   atomate / Materials Project users are, i.e. the people actually running the
   Fortran enumlib today. Primary audience. Draft A below.
2. **discourse.julialang.org**, package announcements — different audience,
   different emphasis (registered package, API, algorithms rather than drop-in
   compatibility). Draft B below, shorter.
3. **A pointer in msg-byu/enumlib's own README.** Lowest effort, possibly the
   highest yield: anyone who finds the Fortran repo is exactly the reader we want,
   and right now nothing there says a successor exists. Not drafted here—one
   paragraph, whenever you want it.

Status: **drafts—not posted** (posting needs your account; I cannot post to
Discourse)

---

# Draft A — matsci.org

**Title:** Enumlib.jl: a Julia reimplementation of enumlib, with drop-in `enum.x`,
`polya.x` and `makestr.x`

Enumlib.jl is a from-scratch Julia reimplementation of
[enumlib](https://github.com/msg-byu/enumlib), the derivative-structure
enumeration code.  This new implementation contains some important improvements over the original (see below).
I am the author of the original Fortran, and this is
meant to be its successor rather than a fork or a wrapper.

**It is a drop-in replacement at the file level.** It ships `enum.x`, `polya.x`
and `makestr.x`, reads and writes the same `struct_enum.in` / `struct_enum.out`
formats, and takes the same positional arguments. pymatgen's `EnumlibAdaptor`
drives it unchanged—pymatgen now documents Enumlib.jl as a source for `enum.x` and
`makestr.x`, and detects which engine is installed via `enum.x --version`.

**Three ways to install it:**

- Julia: `Pkg.add("Enumlib")` (registered in General, currently v0.4.0)
- Standalone binaries, no Julia installation required, on the
  [releases page](https://github.com/glwhart/Enumlib.jl/releases): linux-x86_64,
  macOS arm64 and Windows, each with a `.sha256`. The Linux build runs on glibc
  2.17+, so it works on RHEL/Rocky and typical HPC nodes.
- conda-forge: in review
  ([staged-recipes#34550](https://github.com/conda-forge/staged-recipes/pull/34550)),
  not yet available.

**The algorithms are the same ones:** HNF/SNF supercell enumeration and Pólya
counting (HF 2008); multilattices (HF 2009); concentration-restricted enumeration
by multinomial hashing (HNF 2012); the recursive-stabilizer tree for high
configurational freedom (MHF 2017).

**What is actually new, beyond being in Julia:**

**You can find out how big an enumeration is before committing to it.**
`count_inequivalent` returns the exact number of symmetry-distinct structures by
Pólya/Burnside counting *without generating any of them*, broken down per supercell
volume and per concentration. Counting is not itself new—the Fortran shipped a
`polya.x`, and so does this—but three things about it are. The count is correct
when sites are restricted, which the Fortran's is not (see the divergence below).
It is an ordinary function you can call in the middle of a program, not a separate
executable you shell out to. And `estimate_cost` turns it into a predicted peak
memory, so an enumeration that could never finish is refused up front, with the
numbers, instead of dying three hours in—there is no equivalent of that gate in
the Fortran.

For scale, from a head-to-head against the Fortran on an hcp ternary case: at
n=8 the Fortran took about 9.3 minutes to enumerate 49,947,870 structures, and
`count_inequivalent` returns that same number in about 0.1 s. At n=9 the answer
is 335,918,026, which the Fortran run could not reach inside its time budget at
all. Counts agreed exactly at every volume from 1 to 8. That is counting versus
enumerating, not a like-for-like speed comparison. The point is not that one is
faster than the other: it is that "how big is this?" stopped being a question you
have to run the job to answer.

```julia
using Enumlib
parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
sites  = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

count_inequivalent(parent, sites; supercells = VolumeRange(1:12))  # answer in ms
estimate_cost(parent, sites; supercells = VolumeRange(1:12))       # and what it would cost
e = enumerate_structures(parent, sites; supercells = VolumeRange(1:8))
```

**The algorithm is chosen for you.** `:auto` dispatches between the 2012
multinomial-hash and the 2017 recursive-stabilizer tree based on the case in front
of it, rather than leaving you to flip `origCrossOutAlgorithm` and hope. You can
still name one explicitly.

**Site restrictions are first class.** Per-site `allowed_labels` mean
zinc-blende, half- and full-Heusler, perovskite and spinel-type problems are
stated directly rather than encoded around. Per-sublattice concentrations go with
them: `Concentration(sites, per_sublattice)` lets you say "1:1 on the A site, 1:1
on B, O fixed" instead of hand-computing a global composition vector. This is also
the area where the counting differs from the Fortran—see below.

**There is a DFT round trip, not just structure files.** `to_poscar` writes VASP-5 (gh: isthere a difference between vasp5 and vasp6 files? If not we should list both.)
POSCARs that carry their own provenance in the comment line;
`write_enumeration_archive` packages a whole enumeration with a manifest; and
`read_results` / `attach_results` bring computed energies back and attach them to
the structures they came from. The "Build a DFT training database" tutorial walks
the whole loop, which is the part I most wanted for cluster-expansion work and
never had in the Fortran.

**It is a library, not only a program.** Structures are Julia values you compose
with—no temp files, no parsing `struct_enum.out`, no shelling out. The `.x`
executables exist for interoperability with existing Python workflows, not because
that is the intended way to use it.

**It is documented and anchored.** Tutorials, how-to pages and explanations of each
algorithm with citations, and the examples in them are executed as doctests in CI
rather than being aspirational. Counts are locked in the test suite against
Fortran-generated references across fcc, hcp, diamond, zinc-blende, both Heuslers
and perovskite.

**One deliberate difference in results, which you should know about if you compare
outputs.** For symmetry-equivalent sublattices with overlapping label sets,
Enumlib.jl keeps symmetry operations that the Fortran drops, so the two can report
different counts. It shows up whenever two symmetry-equivalent sublattices carry different or
overlapping species sets: diamond with `[0,1,2]` on one and `[0,1]` on the other
gives 6 / 27 / 170 at n=1,2,3 where the Fortran gives 5 / 23 / 151, and the
wurtzite 3-vs-4 case has the same root cause. My claim is that the Fortran is
wrong there—a parent operation that swaps two sublattices carrying different
species is not a symmetry of the labeled configuration, and the Fortran predates
per-site `allowed_labels` support. Everything else we have run head-to-head
matches exactly.

Docs: https://glwhart.github.io/Enumlib.jl
Source: https://github.com/glwhart/Enumlib.jl
Source: https://github.com/glwhart/Enumlib.jl

---

# Draft B — Julia Discourse (package announcements)

**Title:** Enumlib.jl v0.4.0 — derivative-structure enumeration for alloy theory

Most users of my original [enumlib](https://github.com/msg-byu/enumlib) will go on
calling it from inside Python, obliviously—so this probably appeals only to a
handful of computational materials scientists here. But it is the culmination of a
couple of years of careful work, and I would rather it be findable than not.

Enumlib.jl generates the symmetry-distinct supercells and atomic decorations of a
parent lattice—the building blocks for cluster-expansion fits and configuration
sampling in alloy theory. It is a from-scratch Julia reimplementation of the
Fortran [enumlib](https://github.com/msg-byu/enumlib) (which I also wrote, years ago), and it is
now registered: `Pkg.add("Enumlib")`.

The public API is a few composable functions rather than a file-driven program:

```julia
using Enumlib
parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
sites  = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

count_inequivalent(parent, sites; supercells = VolumeRange(1:6))   # how many, without enumerating
e = enumerate_structures(parent, sites; supercells = VolumeRange(1:4))
```

`count_inequivalent` is the part I would point a Julia audience at: it answers
"how big is this going to be" by Pólya/Burnside counting, without generating
anything. `estimate_cost` turns that into a memory prediction and refuses an
enumeration that could never finish—a gotcha the original code had no defence
against, and one I have walked into myself.

Algorithms: HNF/SNF enumeration and Pólya counting (Hart & Forcade 2008),
multilattices (2009), fixed concentration via multinomial hashing (2012), and the
recursive-stabilizer tree (Morgan, Hart & Forcade 2017). Multilattices,
site-restricted sublattices and per-sublattice concentrations are all supported.

Two things that did not exist in the Fortran and may be the reason to care:
per-site `allowed_labels` with per-sublattice concentrations, so zinc-blende,
Heusler and perovskite problems are stated directly rather than encoded around;
and a POSCAR round trip—`write_enumeration_archive` out, `read_results` /
`attach_results` back—for assembling cluster-expansion training sets without
hand-rolling the bookkeeping.

For interoperability there are also standalone `enum.x` / `polya.x` / `makestr.x`
executables built with PackageCompiler, so Python workflows (pymatgen's
`EnumlibAdaptor`) can use it without a Julia installation.

Docs: https://glwhart.github.io/Enumlib.jl
Source: https://github.com/glwhart/Enumlib.jl
