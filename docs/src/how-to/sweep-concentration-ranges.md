# Sweep concentration ranges

Enumerate across a *band* of concentrations in a single call using [`ConcentrationRange`](@ref). Internally, the range decomposes at each supercell volume into a list of integer-multiplicity "partitions" (possible stoichiometries consistent with the concentration range); `enumerate` runs the fixed-concentration algorithm once per partition.

## Setup

```jldoctest range_recipe
julia> using Enumlib

julia> p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]);    # FCC primitive

julia> sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]);               # binary
```

## A bounded range

Specify per-species `(min, max)` fractional bounds. The example below restricts each species to the 40–60% range — a typical "near-equiatomic" sweep (say, for high-entropy alloys):

```jldoctest range_recipe
julia> cr = ConcentrationRange([(2//5, 3//5), (2//5, 3//5)]);     # 40%-60% on each species

julia> e = enumerate(p, sites; supercells = VolumeRange(8:8), concentration = cr);

julia> length(e)
94
```

At n=8 with bounds 40–60%, only `(4, 4)` fits (counts must be integers); `(3, 5)` and `(5, 3)` are outside the range. So the result equals the chunk-6 reference for 50/50 FCC at n=8: 94 structures.

## A sparse / dilute regime

Restrict the first species to 1 or 2 of 12 atoms — this is where `ConcentrationRange` shines, because the unrestricted enumeration at n=12 would visit 7140 structures across all concentrations, while this dilute band visits only 216 across 2 partitions:

```jldoctest range_recipe
julia> cr_dilute = ConcentrationRange([(1//12, 2//12), (10//12, 11//12)]);

julia> e = enumerate(p, sites; supercells = VolumeRange(12:12), concentration = cr_dilute);

julia> length(e)
216
```

## The partition-count limit

If a `ConcentrationRange` decomposes into many partitions per supercell, the cost can balloon. The default limit refuses the request when the partition count exceeds **100** at any single volume:

```jldoctest range_recipe
julia> cr_wide = ConcentrationRange([(0//1, 1//1), (0//1, 1//1)]);   # totally unrestricted

julia> try
           enumerate(p, sites; supercells = VolumeRange(12:12),
                     concentration = cr_wide, partition_threshold = 5)
       catch e
           e isa PartitionExplosionError ? :refused : rethrow()
       end
:refused
```

In the example above we drop the threshold to 5 to trigger the limit on a small case. To override at production scale, pass `on_partition_overflow = :warn` (warns but proceeds) or `:ignore` (silent), or raise `partition_threshold` explicitly. See [`PartitionExplosionError`](@ref) for the full message text and mitigation list.

## See also

- Reference: [`ConcentrationRange`](@ref), [`concentrations_in_range`](@ref), [`n_species`](@ref), [`PartitionExplosionError`](@ref).
- How-to: [Enumerate at fixed concentration](enumerate-at-fixed-concentration.md), [Count without enumerating](count-without-enumerating.md), [Estimate the cost of an enumeration](estimate-cost.md).
- Explanation: [Concentration and multiplicity](../explanation/concentration-and-multiplicity.md).
