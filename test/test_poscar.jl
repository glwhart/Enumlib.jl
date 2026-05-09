using Test
using TOML
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

    # ============================================================================
    # Phase 11b — write_enumeration_archive (bulk tarball + manifest)
    # ============================================================================

    @testset "write_enumeration_archive produces a valid tarball" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e;
                                              super_periodic = false,
                                              species_symbols = ["Ag", "Pt"],
                                              label = "test_n4")
            @test isfile(out)
            @test endswith(out, ".tar.gz")
            @test occursin("test_n4", out)
            @test filesize(out) > 0
        end
    end

    @testset "tarball contains one POSCAR per structure + manifest" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        n = length(e)
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e;
                                              super_periodic = false,
                                              species_symbols = ["Ag", "Pt"])
            mktempdir() do extract_dir
                run(pipeline(`tar -xzf $out -C $extract_dir`; stdout = devnull))
                files = readdir(extract_dir)
                @test "enumeration.toml" in files
                poscar_files = filter(f -> startswith(f, "POSCAR."), files)
                @test length(poscar_files) == n
                # Filenames are zero-padded with width=2 (since 19 < 100).
                @test "POSCAR.01" in poscar_files
                @test "POSCAR.$(lpad(n, 2, '0'))" in poscar_files
            end
        end
    end

    @testset "manifest TOML is well-formed and has [enumeration] + [structure.N]" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e;
                                              super_periodic = false,
                                              species_symbols = ["Ag", "Pt"],
                                              label = "manifest_test")
            mktempdir() do extract_dir
                run(pipeline(`tar -xzf $out -C $extract_dir`; stdout = devnull))
                manifest = TOML.parsefile(joinpath(extract_dir, "enumeration.toml"))
                # Top-level [enumeration] section.
                @test haskey(manifest, "enumeration")
                enum_section = manifest["enumeration"]
                @test enum_section["n_structures"] == length(e)
                @test enum_section["n_supercells"] == length(e.supercells)
                @test enum_section["super_periodic"] == false
                @test enum_section["species_symbols"] == ["Ag", "Pt"]
                @test enum_section["k"] == 2
                @test haskey(enum_section, "created_at")
                @test haskey(enum_section, "parent_basis_columns")

                # Per-structure sections.
                @test haskey(manifest, "structure")
                structures_section = manifest["structure"]
                @test length(structures_section) == length(e)
                @test haskey(structures_section, "1")
                first_struct = structures_section["1"]
                @test haskey(first_struct, "concentration")
                @test haskey(first_struct, "hnf_idx")
                @test haskey(first_struct, "poscar_filename")
                @test haskey(first_struct, "hnf_matrix_columns")
                @test first_struct["poscar_filename"] == "POSCAR.01"
            end
        end
    end

    @testset "manifest concentration matches POSCAR header concentration" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e;
                                              super_periodic = false,
                                              species_symbols = ["Ag", "Pt"])
            mktempdir() do extract_dir
                run(pipeline(`tar -xzf $out -C $extract_dir`; stdout = devnull))
                manifest = TOML.parsefile(joinpath(extract_dir, "enumeration.toml"))
                # For each structure: open the POSCAR; verify the header
                # concentration matches the manifest entry.
                for (id_str, info) in manifest["structure"]
                    fname = info["poscar_filename"]
                    poscar_path = joinpath(extract_dir, fname)
                    line1 = open(readline, poscar_path)
                    expected_conc = info["concentration"]
                    @test occursin("concentration=$expected_conc ", line1)
                end
            end
        end
    end

    @testset "explicit .tar.gz path is honored verbatim" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            explicit_path = joinpath(tmp, "my_specific_name.tar.gz")
            out = write_enumeration_archive(explicit_path, e;
                                              super_periodic = false)
            @test out == explicit_path
            @test isfile(explicit_path)
        end
    end

    @testset "auto-naming includes timestamp + label" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e;
                                              super_periodic = false,
                                              label = "MyLabel")
            base = basename(out)
            @test startswith(base, "enumlib_MyLabel_")
            @test endswith(base, ".tar.gz")
            # Timestamp format: yyyy-mm-ddTHH-MM-SS
            @test occursin(r"\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}", base)
        end
    end

    @testset "default label is 'enum'" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(tmp, e; super_periodic = false)
            @test startswith(basename(out), "enumlib_enum_")
        end
    end

    @testset "keep_directory leaves the assembled directory next to tarball" begin
        e = enumerate(parent, sites; supercells = VolumeRange(4:4))
        mktempdir() do tmp
            out = write_enumeration_archive(joinpath(tmp, "kd_test.tar.gz"), e;
                                              super_periodic = false,
                                              keep_directory = true)
            @test isfile(out)
            kept_dir = joinpath(tmp, "kd_test")
            @test isdir(kept_dir)
            @test "enumeration.toml" in readdir(kept_dir)
            poscar_files = filter(f -> startswith(f, "POSCAR."), readdir(kept_dir))
            @test length(poscar_files) == length(e)
        end
    end

    @testset "empty enumeration throws" begin
        e_empty = Enumeration{3, Vector{Int8}}(parent, sites,
                                                 Enumlib.Supercell{3}[],
                                                 Enumlib.EnumeratedStructure{3, Vector{Int8}}[])
        mktempdir() do tmp
            @test_throws ArgumentError write_enumeration_archive(tmp, e_empty;
                                                                   super_periodic = false)
        end
    end

end
