# Count from the command line

`polya.x` answers "how many symmetrically inequivalent derivative superstructures does this
input describe?" from a Fortran-enumlib `struct_enum.in` file, without a Julia session and
without generating anything. It reads one file, prints a table, and exits — nothing is
written to disk and no structures are built. This is the job the Fortran `polya.x`
(`driver_polya.f90`) did; the functionality is carried forward, the output layout is not a
copy of it.

Use it when the input you already have is a `struct_enum.in` — from a Fortran workflow, from
pymatgen's `EnumlibAdaptor`, or from a conda-forge `enumlib` installation. If you are working
inside Julia, call [`count_inequivalent`](@ref) directly instead; see
[Count without enumerating](count-without-enumerating.md). Both go through exactly the same
Pólya/Burnside code path.

## Run it

Three ways to get a `polya.x`, in order of least setup:

1. **Pre-compiled binary.** Each tagged release attaches a per-platform tarball containing
   standalone `enum.x` and `polya.x` executables. No Julia installation required; unpack and
   run. This is the fastest path per invocation — it does not pay Julia's package-load time.
2. **From a source checkout**, via the thin wrapper script:

   ```console
   $ julia --project=/path/to/Enumlib.jl /path/to/Enumlib.jl/bin/polya.jl
   ```

3. **Build it yourself** from the checkout with `build/build_app.jl`, which produces the same
   `polya.x` the release tarballs ship.

All three run identical code — the implementation is `Enumlib.polya_main` in `src/cli.jl`,
and `bin/polya.jl` is a wrapper around it — so examples below apply verbatim to any of them.

## A first run

`polya.x` reads `struct_enum.in` from the current directory by default. Here is a zinc-blende
input: an FCC parent with a cation sublattice mixing two species and an anion sublattice
mixing two others (think `(Ga,In)(As,P)`), swept over supercell volumes 1 through 4.

```
zinc-blende: binary cation sublattice + binary anion sublattice
bulk
0.0 0.5 0.5
0.5 0.0 0.5
0.5 0.5 0.0
4 -nary case
2 # number of points in the multilattice
0.0 0.0 0.0   0/1
0.25 0.25 0.25   2/3
1 4   # starting and ending cell sizes
1e-6  # epsilon (finite precision parameter)
full
```

```console
$ polya.x
polya.x (Enumlib.jl) X.Y.Z
Counting aperiodic labelings only (what enum.x reports).
Concentration restriction from struct_enum.in applied.

    volume            count
         1                4
         2               11
         3               52
         4              290

     total              357
```

Reading the output:

- The **first line** identifies the engine and its version — the same string `polya.x -V`
  prints. `X.Y.Z` above stands in for the package version.
- The **second line** states the super-periodicity policy in force. The default counts
  aperiodic labelings only, which is what `enum.x` writes to `struct_enum.out`.
- The **third line** appears only when the input constrains composition. It also appears for
  a heterogeneous multilattice like this one, where the reader supplies a full-range
  concentration because Enumlib refuses unrestricted enumeration on heterogeneous
  sublattices — the constraint is present but vacuous.
- The **table** gives one row per supercell volume in the input's `Nmin Nmax` range, then the
  total across the range.

Every count here is the number of structures `enum.x` would actually write for the same
input — not an upper bound. Each sublattice's `allowed_labels` are honored: this input has four species
overall, but the cation positions can only take two of them and the anion positions the other
two, and the count reflects that. See
[Pólya counting](../explanation/polya-counting.md) for why that distinction is worth orders
of magnitude.

## Options

| Flag | Effect |
| --- | --- |
| *(positional)* `input_file` | Read this file instead of `struct_enum.in`. Matches the Fortran driver's first argument. |
| `--include-superperiodic` | Also count labelings that are periodic replicas of smaller supercells. |
| `-h`, `--help` | Print usage and exit. |
| `-V`, `--version` | Print `polya.x (Enumlib.jl) <version>` and exit, without reading any input. |

The positional filename is load-bearing rather than cosmetic: conda-forge's `enumlib`
feedstock tests the package with `enum.x struct_enum.in.fcc`, so both executables accept it.
The Fortran drivers' legacy *second* positional argument (a switch between two
implementations of the same enumeration) is accepted, warned about, and ignored — Enumlib
picks its algorithm automatically and no answer changes.

Unknown flags are rejected with usage text and a non-zero exit; a bare word is always treated
as the input filename.

## Counting a specific volume range or composition

Everything `polya.x` counts comes from the input file — there are no flags for volume or
composition. To change either, change the file.

The `Nmin Nmax` line sets the volume range. The optional trailing concentration block sets
per-species bounds, one `num_low num_high denom` line per species. Pinning FCC binary to
exactly 50/50 over volumes 1–8:

```
FCC binary 50/50 band
bulk
0.0 0.5 0.5
0.5 0.0 0.5
0.5 0.5 0.0
2 -nary case
1 # number of points in the multilattice
0.0 0.0 0.0   0/1
1 8   # starting and ending cell sizes
1e-6  # epsilon
full
2 2 4
2 2 4
```

```console
$ polya.x sen.fcc50
polya.x (Enumlib.jl) X.Y.Z
Counting aperiodic labelings only (what enum.x reports).
Concentration restriction from struct_enum.in applied.

    volume            count
         2                2
         4                5
         6               20
         8               94

     total              121
```

Odd volumes are absent from the table, not zero-valued: a 50/50 split needs an even site
count, so those volumes admit no integer multiplicities and are skipped. That is the same
divisibility rule [`enumerate`](@ref) follows — see
[Concentration and multiplicity](../explanation/concentration-and-multiplicity.md).

## Including super-periodic labelings

The default drops labelings whose true period divides the supercell volume, because a volume
sweep would otherwise report the same physical structure once per multiple of its period.
`--include-superperiodic` reports the raw Burnside orbit count instead. On FCC binary over
volumes 1–6:

```console
$ polya.x struct_enum.in.fcc
...
    volume            count
         1                2
         2                2
         3                6
         4               19
         5               28
         6               80

     total              137

$ polya.x struct_enum.in.fcc --include-superperiodic
...
    volume            count
         1                2
         2                6
         3               12
         4               41
         5               38
         6              130

     total              229
```

The default column is the one that matches `enum.x`. See
[Handle super-periodicity](handle-super-periodicity.md) for which policy a given workflow
wants.

## Errors and exit codes

`polya.x` exits `0` on success and `1` on failure, printing a single-line diagnostic to
standard error:

```console
$ polya.x nope.in
polya.x: SystemError: opening file "nope.in": No such file or directory
$ echo $?
1
```

The input reader covers `bulk` lattices in `full` mode, single- and multilattice parents with
per-d-vector label sets, and the optional concentration block. Inputs outside that — `surf`
2D lattices, `part` mode, explicit equivalency lists, and the legacy encoding of an inactive
site as a label `≥ k` — are rejected with a message naming the unsupported feature rather
than silently mis-counting.

## The enumerating sibling

`enum.x` is the executable that reads the same `struct_enum.in` and actually enumerates,
writing `struct_enum.out` plus the Fortran-style progress table. It is a drop-in for the
Fortran `enum.x`, which is why pymatgen's `EnumlibAdaptor` drives it unchanged. `polya.x`
counts what `enum.x` would write; running `polya.x` first is the cheap way to find out
whether running `enum.x` is a good idea.

## See also

- How-to: [Count without enumerating](count-without-enumerating.md) — the same count from
  Julia, with per-volume, per-HNF, and per-concentration breakdowns.
  [Estimate the cost of an enumeration](estimate-cost.md),
  [Handle super-periodicity](handle-super-periodicity.md).
- Explanation: [Pólya counting](../explanation/polya-counting.md),
  [Super-periodicity](../explanation/super-periodicity.md).
- Reference: [`count_inequivalent`](@ref), [`InequivalentCount`](@ref).
