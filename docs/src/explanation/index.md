# Explanation

The "why" of Enumlib. Conceptual scaffolding for the underlying math, the algorithms drawn from the Hart-Forcade-Nelson papers, and the dispatch logic that picks the right one for your problem. Read these for mental-model purposes; for "how do I run X" see the [How-to guides](../how-to/index.md), and for "what's the API of Y" see the [Reference](../reference/index.md).

## Start here

- [Algorithm overview](algorithm-overview.md) — bird's-eye view of the four enumeration algorithms and the Pólya counter.
- [Glossary](glossary.md) — compact term reference for the rest of these pages.

## The four algorithms

- [Exhaustive enumeration (HF 2008)](exhaustive-2008.md) — the original algorithm. Iterate every coloring; canonicalize each. The reference implementation; not `:auto`'s default.
- [Multinomial mixed-radix hash (HF 2012)](multinomial-2012.md) — iterate only colorings at the target concentration. Includes the §A.1 site-mask variant (`:multinomial_restricted`) for [Regime C](glossary.md#Regime-A-/-B-/-C) (heterogeneous sublattices).
- [Recursive stabilizer (Morgan-Hart 2017)](recursive-stabilizer-2017.md) — the tree. Doesn't need a [bitmap](glossary.md#Bitmap); `:auto`'s default for almost everything.

## Counting and the resource check

- [Pólya counting](polya-counting.md) — Burnside on coloring spaces, plus the Möbius-inversion correction for aperiodic orbits.
- [Dispatch and the resource check](dispatch-and-cost-gate.md) — how `algorithm = :auto` picks; how the enumeration resource check refuses oversized requests.

## Policy

- [Super-periodicity](super-periodicity.md) — why colorings periodic on a smaller supercell are dropped by default.
- [Concentration and multiplicity](concentration-and-multiplicity.md) — the type layer above HF 2012, plus the divisibility-skip semantics.
