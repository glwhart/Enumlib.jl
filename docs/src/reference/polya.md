# Pólya counting

Public API for the `Polya` submodule, including the Möbius-inversion helpers.

Most users never call these directly — [`count_inequivalent`](@ref) selects the right
method from the [`Sites`](@ref) and kwargs it is given. Reach for this submodule when you
want an orbit count for a group action Enumlib doesn't build for you.

Which method you want comes down to three questions. Can every position take every label,
or does each one have its own `allowed_labels`? Is the composition fixed, or free? And do you
want the aperiodic count or the raw Burnside count that includes super-periodic orbits? The
first question picks the column, the other two pick the row.

| | labels unrestricted (scalar `k`) | per-position `allowed_labels` |
| --- | --- | --- |
| **any concentration** | `polya_count(G, k)` | `polya_count(G, allowed_labels)` |
| **fixed concentration** | `polya_count(G, multiplicities)` | `polya_count(G, allowed_labels, multiplicities)` |
| **aperiodic, any conc.** | `aperiodic_orbit_count(G, snf, k)` | `aperiodic_orbit_count(G, snf, allowed_labels)` |
| **aperiodic, fixed conc.** | `aperiodic_orbit_count(G, snf, multiplicities)` | `aperiodic_orbit_count(G, snf, allowed_labels, multiplicities)` |

`allowed_labels::AbstractVector{BitSet}` carries one entry per supercell position, in the
dset-blocks layout the permutation group already uses (dset position `i` owns positions
`(i-1)·n + 1 … i·n`). The `aperiodic_*` rows apply the super-periodicity policy
`include_superperiodic = false`; the `polya_count` rows are the raw Burnside counts.

```@docs
Enumlib.Polya
Enumlib.Polya.polya_count
Enumlib.Polya.cycle_structure
Enumlib.Polya.aperiodic_orbit_count
```

## See also

- Explanation: [Pólya counting](../explanation/polya-counting.md) — the Burnside, Möbius,
  and label-restriction math these methods implement.
- How-to: [Count without enumerating](../how-to/count-without-enumerating.md),
  [Count from the command line](../how-to/count-from-the-command-line.md).
