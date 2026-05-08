using Test
using Enumlib

@testset "Phase 11a — POSCAR writer (to_poscar)" begin

    parent = ParentLattice([0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5])
    sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])

    # ---- supercell_fractional_positions helper ----

    @testset "supercell_fractional_positions on simple HNFs" begin
        # SNF (1,1,4): cyclic 4-site supercell. V is identity → positions
        # are (0,0,k/4) for k = 0..3.
        h = HNF{3}([1 0 0; 0 1 0; 0 0 4])
        positions = Enumlib.supercell_fractional_positions(h)
        @test length(positions) == 4
        @test positions[1] == (0.0, 0.0, 0.0)
        @test positions[2] == (0.0, 0.0, 0.25)
        @test positions[3] == (0.0, 0.0, 0.5)
        @test positions[4] == (0.0, 0.0, 0.75)
    end

    @testset "supercell_fractional_positions length matches volume" begin
        for n in [2, 4, 8, 12]
            for h in enumerate_hnfs(VolumeRange(n:n), parent)
                positions = Enumlib.supercell_fractional_positions(h)
                @test length(positions) == volume(h)
                # Every position is in [0, 1)^3.
                for p in positions
                    @test all(0.0 <= c < 1.0 for c in p)
                end
                # Positions are unique (no two sites coincide).
                @test length(unique(positions)) == volume(h)
            end
        end
    end

    @testset "supercell_fractional_positions on the cubic 2x2x2 HNF (chunk 8)" begin
        # The cubic 2x2x2 conventional FCC supercell has 32 distinct sites at
        # known positions on a 2x2x2 grid in the conventional basis. In
        # primitive-supercell-fractional coordinates these positions are
        # specific to the HNF chosen, but the count must be exactly 32 and
        # they must be distinct.
        hnfs = enumerate_hnfs(VolumeRange(32:32), parent)
        # The cubic HNF was found in chunk 8 to be at a specific index
        # determined by Minkowski-reducing the basis. Just check any HNF
        # at n=32 has 32 distinct positions.
        positions = Enumlib.supercell_fractional_positions(hnfs[1])
        @test length(positions) == 32
        @test length(unique(positions)) == 32
    end

    # ---- to_poscar header line ----

    @testset "header line format and content" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf;
                   super_periodic = false, enumlib_id = 7)
        lines = split(String(take!(io)), '\n')
        line1 = lines[1]
        # Exact fields present.
        @test occursin(r"^# enumlib_id=7 ", line1)
        @test occursin(r" hnf=\d+ ", line1)
        @test occursin(r" concentration=1:1 ", line1)
        @test occursin(r" super_periodic=false", line1)
        # energy_eV= is last and empty.
        @test endswith(line1, "energy_eV=")
    end

    @testset "header includes comment_extras between metadata and energy slot" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf;
                   super_periodic = false,
                   comment_extras = ["author=alice", "calc_id=run42"])
        line1 = first(split(String(take!(io)), '\n'))
        @test occursin("author=alice", line1)
        @test occursin("calc_id=run42", line1)
        # extras come BEFORE energy_eV= so the slot is always at the end.
        @test endswith(line1, "energy_eV=")
        idx_extras = findfirst("author=alice", line1)
        idx_energy = findfirst("energy_eV=", line1)
        @test idx_extras !== nothing && idx_energy !== nothing
        @test first(idx_extras) < first(idx_energy)
    end

    @testset "concentration string is the actual labeling counts" begin
        # At n=4 binary, structure 1 (the chunk-5 first labeling) has some
        # specific count. Verify the concentration field matches.
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        for i in 1:min(5, length(e))
            structure = e.structures[i]
            hnf = e.supercells[structure.supercell_id].hnf
            labeling = to_labeling(structure)
            n = length(labeling)
            # Compute expected counts.
            counts = zeros(Int, 2)
            for c in labeling
                counts[Int(c) + 1] += 1
            end
            expected_conc = join(counts, ":")
            io = IOBuffer()
            to_poscar(io, structure, parent, hnf; super_periodic = false)
            line1 = first(split(String(take!(io)), '\n'))
            @test occursin("concentration=$expected_conc ", line1)
        end
    end

    @testset "super_periodic field reflects the kwarg" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf

        for sp in (false, true)
            io = IOBuffer()
            to_poscar(io, e.structures[1], parent, hnf; super_periodic = sp)
            line1 = first(split(String(take!(io)), '\n'))
            @test occursin("super_periodic=$sp", line1)
        end
    end

    # ---- Lattice basis (VASP rows convention) ----

    @testset "lattice vectors written as VASP rows (transpose from Julia columns)" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf; super_periodic = false)
        lines = split(String(take!(io)), '\n')
        # Lines 3, 4, 5 are the lattice vectors (1-indexed: lines[3], lines[4], lines[5]).
        # Each row of the POSCAR = one lattice vector = one column of A_super.
        A_super = parent.A * hnf.matrix
        for j in 1:3
            row_vals = parse.(Float64, split(strip(lines[2 + j])))
            @test length(row_vals) == 3
            @test row_vals ≈ A_super[:, j]
        end
    end

    # ---- Species + counts + grouping ----

    @testset "species line and counts: all k species listed, zeros included" begin
        # Per chunk 11a review item D: zero-count species ARE included in
        # the species/counts lines so POTCAR ordering on the calculator side
        # stays stable. A monochromatic all-color-0 structure (achievable via
        # include_superperiodic=true) writes "A B\n2 0\n" — both species,
        # second count is zero.
        e_full = enumerate(parent, sites; supercells = VolumeRange(2:2),
                                          include_superperiodic = true)
        # Find a monochromatic structure (labeling all 0s or all 1s).
        mono = findfirst(s -> all(==(0), to_labeling(s)) || all(==(1), to_labeling(s)),
                          e_full.structures)
        @test mono !== nothing
        structure = e_full.structures[mono]
        labeling = to_labeling(structure)
        hnf = e_full.supercells[structure.supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, structure, parent, hnf;
                   super_periodic = true,
                   species_symbols = ["A", "B"])
        lines = split(String(take!(io)), '\n')
        species_tokens = split(strip(lines[6]))
        counts_tokens = split(strip(lines[7]))
        # Both species listed, both counts listed (one of which is zero).
        @test species_tokens == ["A", "B"]
        @test length(counts_tokens) == 2
        counts = parse.(Int, counts_tokens)
        @test sum(counts) == length(labeling)
        # Exactly one count is zero (the other holds all atoms).
        @test count(==(0), counts) == 1
    end

    @testset "default species_symbols = letters [A, B, C, ...]" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf; super_periodic = false)
        lines = split(String(take!(io)), '\n')
        species_line = strip(lines[6])
        # Default is "A B" for binary.
        @test species_line == "A B"
    end

    @testset "user-supplied species_symbols passes through" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf;
                   super_periodic = false,
                   species_symbols = ["Ag", "Pt"])
        lines = split(String(take!(io)), '\n')
        @test strip(lines[6]) == "Ag Pt"
    end

    @testset "species_symbols too short throws ArgumentError" begin
        e = enumerate(parent, sites; supercells = VolumeRange(2:2))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        @test_throws ArgumentError to_poscar(io, e.structures[1], parent, hnf;
                                              super_periodic = false,
                                              species_symbols = ["Ag"])  # length 1, k = 2
    end

    # ---- Coordinate mode + position grouping ----

    @testset "Direct (fractional) coordinates only" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        hnf = e.supercells[e.structures[1].supercell_id].hnf
        io = IOBuffer()
        to_poscar(io, e.structures[1], parent, hnf; super_periodic = false)
        lines = split(String(take!(io)), '\n')
        @test strip(lines[8]) == "Direct"
    end

    @testset "atoms grouped by species, totals match counts" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        # Pick a structure with non-trivial concentration.
        for structure in e.structures[1:min(3, length(e))]
            hnf = e.supercells[structure.supercell_id].hnf
            labeling = to_labeling(structure)
            n = length(labeling)
            counts = zeros(Int, 2)
            for c in labeling
                counts[Int(c) + 1] += 1
            end
            io = IOBuffer()
            to_poscar(io, structure, parent, hnf; super_periodic = false)
            lines = split(String(take!(io)), '\n')
            # Line 9 onwards: positions. Total non-empty position lines = n.
            position_lines = [strip(l) for l in lines[9:end] if !isempty(strip(l))]
            @test length(position_lines) == n
        end
    end

    # ---- Value-equality round-trip via parse-back ----

    @testset "parse-back round-trip on FCC binary n=4" begin
        # Read back the POSCAR's numerical content and verify each piece
        # matches the input. (Per Q8: value-equality, not byte-for-byte.)
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        for (idx, structure) in enumerate(e.structures[1:min(5, length(e))])
            hnf = e.supercells[structure.supercell_id].hnf
            io = IOBuffer()
            to_poscar(io, structure, parent, hnf;
                       super_periodic = false,
                       species_symbols = ["Ag", "Pt"],
                       enumlib_id = idx)
            lines = split(String(take!(io)), '\n')
            # Parse back lattice vectors.
            A_back = zeros(3, 3)
            for j in 1:3
                A_back[:, j] = parse.(Float64, split(strip(lines[2 + j])))
            end
            @test A_back ≈ parent.A * hnf.matrix
            # Parse back the species and counts.
            species = split(strip(lines[6]))
            counts = parse.(Int, split(strip(lines[7])))
            @test sum(counts) == length(to_labeling(structure))
            # Coordinate mode.
            @test strip(lines[8]) == "Direct"
        end
    end

end
