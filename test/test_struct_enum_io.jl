# Phase 9 — Fortran-compatible struct_enum.in reader + struct_enum.out writer
# (the drop-in enum.x I/O). Pure Julia — no external binaries. The Fortran/pymatgen
# cross-checks (needing a built enum.x + a pymatgen venv) live in
# test/integration/phase9/.
#
# Reference counts are harvested from the existing suite's Fortran-anchored corpora
# (test_enumerate.jl, test_concentration.jl) so this file re-uses the same locked
# numbers rather than inventing new ones.

using Test
using Enumlib

# Build a current-format struct_enum.in string for a case.
function _sen(; A, dset, labels, nmin, nmax, conc)
    io = IOBuffer()
    println(io, "case"); println(io, "bulk")
    for j in 1:3; println(io, join(A[:, j], " ")); end
    println(io, maximum(maximum.(labels)) + 1, " -nary case")
    println(io, length(dset), " # nD")
    for (p, l) in zip(dset, labels)
        println(io, join(A * p, " "), "  ", join(l, "/"))
    end
    println(io, nmin, " ", nmax); println(io, "1e-6"); println(io, "full")
    conc === nothing || for (lo, hi, den) in conc; println(io, lo, " ", hi, " ", den); end
    return String(take!(io))
end

_readsen(s) = Enumlib.read_struct_enum_in(IOBuffer(s))
_count(inp) = length(enumerate(inp.parent, inp.sites; supercells = inp.selection,
                     concentration = inp.concentration,
                     partition_threshold = 1_000_000, skip_resource_check = true))

# The counting-only path behind `bin/polya.jl` (the Fortran polya.x's job): the
# Pólya/Burnside count must equal the number of structures enum.x actually writes.
_polya(inp) = count_inequivalent(inp.parent, inp.sites; supercells = inp.selection,
                     concentration = inp.concentration)

const FCC  = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]     # test_enumerate / test_concentration
const FCC2 = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]     # test_enumerate regime-C / diamond
const SC   = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
const HCP  = (a = 1.0; c = sqrt(8/3); [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c])

@testset "struct_enum I/O (Phase 9 drop-in)" begin

    @testset "reader → enumerate / Pólya count parity (suite corpora)" begin
        # (name, A, dset, labels, [(nmin, nmax, conc, ref) ...])
        cases = [
            ("fcc binary", FCC, [[0.0,0,0]], [[0,1]], [
                (4,4,nothing,19), (8,8,nothing,390),
                (4,4,[(2,2,4),(2,2,4)],5), (8,8,[(4,4,8),(4,4,8)],94), (8,8,[(3,3,8),(5,5,8)],86)]),
            ("fcc ternary", FCC, [[0.0,0,0]], [[0,1,2]], [(4,4,nothing,96)]),
            ("hcp binary", HCP, [[0.0,0,0],[1/3,2/3,1/2]], [[0,1],[0,1]],
                [(n,n,nothing,[3,10,50,270,651,4793][n]) for n in 1:6]),
            ("diamond", FCC2, [[0.0,0,0],[0.25,0.25,0.25]], [[0,1],[0,1]],
                [(n,n,nothing,[3,7,33,171][n]) for n in 1:4]),
            ("zinc-blende", FCC2, [[0.0,0,0],[0.25,0.25,0.25]], [[0,1],[2,3]],
                [(n,n,nothing,[4,11,52,290][n]) for n in 1:4]),
            ("half-Heusler", FCC2, [[0.0,0,0],[0.25,0.25,0.25],[0.75,0.75,0.75]], [[0,1],[2],[2]],
                [(n,n,nothing,[2,2,6,19,28][n]) for n in 1:5]),
            ("full-Heusler", FCC2, [[0.0,0,0],[0.25,0.25,0.25],[0.5,0.5,0.5],[0.75,0.75,0.75]],
                [[2],[0,1],[2],[0,1]], [(n,n,nothing,[3,7,30,156][n]) for n in 1:4]),
            ("perovskite", SC, [[0.0,0,0],[0.5,0.5,0.5],[0.5,0.5,0.0],[0.5,0.0,0.5],[0.0,0.5,0.5]],
                [[0,1],[2,3],[4],[4],[4]], [(n,n,nothing,[4,15,48,301][n]) for n in 1:4]),
            # Multilattice AND multinary (>2 species) — closes the coverage gap probed
            # 2026-08. Both are head-to-head-verified against the Fortran enum.x.
            #   • hcp ternary: uniform multilattice (Regime B) with a genuinely ternary
            #     sublattice — the prime "multilattice + multinary" case.
            #   • diamond [0,1,2,3]&[4,5]: heterogeneous (Regime C) with DISJOINT label
            #     sets, one quaternary sublattice. (Overlapping label sets across
            #     symmetry-equivalent sublattices deliberately diverge from Fortran —
            #     see phase9-design.md §9d — so that case is intentionally NOT asserted here.)
            ("hcp ternary", HCP, [[0.0,0,0],[1/3,2/3,1/2]], [[0,1,2],[0,1,2]],
                [(n,n,nothing,[6,51,450,5568][n]) for n in 1:4]),
            ("diamond quaternary+binary (disjoint)", FCC2, [[0.0,0,0],[0.25,0.25,0.25]],
                [[0,1,2,3],[4,5]], [(1,1,nothing,8),(2,2,nothing,50)]),
        ]
        for (name, A, dset, labels, rows) in cases
            @testset "$name" begin
                for (nmin, nmax, conc, ref) in rows
                    inp = _readsen(_sen(; A, dset, labels, nmin, nmax, conc))
                    @test _count(inp) == ref
                    @test _polya(inp) == ref     # bin/polya.jl path
                end
            end
        end
    end

    @testset "writer well-formedness (27-token rows, labeling length, RunTot)" begin
        for (A, dset, labels, n) in [
                (FCC,  [[0.0,0,0]],                   [[0,1]],       4),
                (HCP,  [[0.0,0,0],[1/3,2/3,1/2]],     [[0,1],[0,1]], 3),
                (FCC2, [[0.0,0,0],[0.25,0.25,0.25]],  [[0,1],[2,3]], 2)]
            inp = _readsen(_sen(; A, dset, labels, nmin = n, nmax = n, conc = nothing))
            e = enumerate(inp.parent, inp.sites; supercells = inp.selection,
                          concentration = inp.concentration,
                          partition_threshold = 1_000_000, skip_resource_check = true)
            fbuf = IOBuffer(); sbuf = IOBuffer()
            Enumlib.write_struct_enum_out(fbuf, e; input = inp, stdout_io = sbuf)
            lines = split(strip(String(take!(fbuf))), '\n')
            hdr = findfirst(l -> startswith(l, "start   #tot"), lines)
            @test hdr !== nothing
            @test any(l -> occursin("full list of labelings", l), lines)
            data = lines[hdr+1:end]
            @test length(data) == length(e)                       # one row per structure
            nD = length(dset)
            for row in data
                toks = split(row)
                @test length(toks) == 27                          # 27-token makeStr contract
                @test length(last(toks)) == n * nD                # labeling length = n·nD
                @test all(c -> c in '0':'9', last(toks))          # labeling is digits
            end
            # stdout RunTot table: final data row's last token == structure count
            trows = [split(l) for l in split(strip(String(take!(sbuf))), '\n') if occursin(r"^\s*\d", l)]
            @test parse(Int, last(last(trows))) == length(e)
        end
    end

    @testset "CLI positional input file (Fortran driver contract)" begin
        # driver.f90 / driver_polya.f90: arg 1 is an optional input filename
        # defaulting to struct_enum.in, arg 2 a legacy algorithm switch we ignore.
        # conda-forge's enumlib feedstock tests with `enum.x struct_enum.in.fcc`,
        # so dropping the filename argument would fail that package's own test.
        @test Enumlib._cli_input_file("enum.x", String[]) == "struct_enum.in"
        @test Enumlib._cli_input_file("enum.x", ["mine.in"]) == "mine.in"
        @test Enumlib._cli_input_file("polya.x", ["struct_enum.in.fcc"]) == "struct_enum.in.fcc"
        # Flags are not filenames, whichever side of the positional they sit on.
        @test Enumlib._cli_input_file("polya.x",
                                      ["--include-superperiodic", "x.in"]) == "x.in"
        @test Enumlib._cli_input_file("enum.x", ["-V"]) == "struct_enum.in"
        # The legacy second positional is accepted, warned about, and ignored.
        @test (@test_logs (:warn, r"origCrossOutAlgorithm") Enumlib._cli_input_file(
            "enum.x", ["a.in", "F"])) == "a.in"
    end

    @testset "reader rejects out-of-scope inputs (clear errors, not wrong answers)" begin
        base(; kw...) = _sen(; A = FCC, dset = [[0.0,0,0]], labels = [[0,1]],
                             nmin = 1, nmax = 2, conc = nothing, kw...)
        @test_throws ArgumentError _readsen(replace(base(), "bulk" => "surf"))   # 2D deferred
        @test_throws ArgumentError _readsen(replace(base(), "full" => "part"))   # part sunset
        @test_throws ArgumentError _readsen(replace(base(), "0/1" => "0/1/5"))   # label ≥ k marker
    end
end
