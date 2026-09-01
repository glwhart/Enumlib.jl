# Enumerate at fixed concentration

Restrict [`enumerate`](@ref Base.enumerate) to labelings with a prescribed concentration (e.g., 4 A + 4 B in an 8-cell binary alloy).

## Setup

```jldoctest fixed_conc
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);   # FCC

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);              # binary
```

## Steps

Pass a [`Concentration`](@ref) via the `concentration` kwarg. The constructor of choice depends on what you're holding in your head:

```jldoctest fixed_conc
julia> c = concentration_count([4, 4]; n_total = 8);   # 4 A + 4 B in an 8-cell

julia> e = enumerate_structures(p, sites; supercells = VolumeRange(8:8), concentration = c);

julia> length(e)
94
```

The canonical HF 2012 reference: 94 symmetry-inequivalent labelings of 8-site FCC supercells at 50/50 binary concentration.

## Other constructors

When you care about a *ratio* rather than literal counts at a specific cell size, use [`concentration_ratio`](@ref) — scale-free, reduces the input to lowest terms:

```jldoctest fixed_conc
julia> concentration_ratio([2, 4])     # 2:4 reduces to 1:2; total is 3 so 1/3:2/3
Concentration(1//3, 2//3) 
```

When you already have fractions in hand, the canonical [`Concentration`](@ref) constructor accepts them directly:

```jldoctest fixed_conc
julia> Concentration([1//4, 3//4])
Concentration(1//4, 3//4)
```

## Behavior notes

- **Divisibility:** the concentration's fractions must each multiply by the supercell volume to an integer. For example, `Concentration([1//3, 2//3])` works at volumes that are multiples of 3 (3, 6, 9, …) but not at volume 4. Volumes that don't divide cleanly are silently skipped — `enumerate` returns whatever structures the *compatible* volumes produced.

    **Caveat:** if *every* volume in the range is incompatible, you get back an `Enumeration` of length 0 with no error raised. Calling `multiplicities(c, n)` directly *does* throw an `EmptyEnumerationError` — only the `enumerate(...)` path catches it per-volume.
- `:auto` algorithm dispatch picks `:multinomial` for fixed concentration, or `:recursive_stabilizer` if the multinomial bitmap would exceed `memory_budget × 0.8`. See [Pick an algorithm](pick-an-algorithm.md).
- Super-periodic labelings are dropped by default. See [Handle super-periodicity](handle-super-periodicity.md).

## See also

- Reference: [`Concentration`](@ref), [`concentration_count`](@ref), [`concentration_ratio`](@ref), [`multiplicities`](@ref).
- How-to: [Sweep concentration ranges](sweep-concentration-ranges.md), [Count without enumerating](count-without-enumerating.md), [Pick an algorithm](pick-an-algorithm.md).
- Explanation: [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md).
