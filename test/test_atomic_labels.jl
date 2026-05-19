using Test
using Enumlib

@testset "Atomic-label convenience for Sites" begin

    # ---- SymbolSite type and Site dispatch ----

    @testset "SymbolSite construction" begin
        ss = SymbolSite([0.0, 0.0, 0.0], [:Al, :Ga])
        @test ss isa SymbolSite{3}
        @test ss.position == [0.0, 0.0, 0.0]
        @test ss.allowed_symbols == [:Al, :Ga]
    end

    @testset "SymbolSite validation errors" begin
        @test_throws ArgumentError SymbolSite{3}([0.0, 0.0], [:Al])    # wrong-length position
        @test_throws ArgumentError SymbolSite([0.0, 0.0, 0.0], Symbol[])  # empty symbols
    end

    @testset "Site(pos, [:Al, :Ga]) returns SymbolSite" begin
        x = Site([0.0, 0.0, 0.0], [:Al, :Ga])
        @test x isa SymbolSite{3}
        @test !(x isa Site)
    end

    @testset "Site(pos, [0, 1]) still returns integer Site" begin
        y = Site([0.0, 0.0, 0.0], [0, 1])
        @test y isa Enumlib.Site{3}
        @test y.allowed_labels == BitSet([0, 1])
    end

    # ---- Sites from SymbolSites ----

    @testset "Sites from SymbolSites: first-seen ordering" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0],     [:Al, :Ga]),
            Site([0.25, 0.25, 0.25],  [:As]),
        ])
        @test species_symbols(sites) == [:Al, :Ga, :As]
        @test sites.list[1].allowed_labels == BitSet([0, 1])
        @test sites.list[2].allowed_labels == BitSet([2])
    end

    @testset "Sites first-seen preserves declaration order" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0], [:Ga, :Al]),   # Ga first
        ])
        @test species_symbols(sites) == [:Ga, :Al]
        @test sites.list[1].allowed_labels == BitSet([0, 1])
    end

    @testset "Sites with SymbolSites + upfront equivalence classes" begin
        sites = Sites(
            [
                Site([0.0, 0.0, 0.0], [:Al, :Ga]),
                Site([0.5, 0.5, 0.5], [:Al, :Ga]),
            ],
            [[1, 2]],
        )
        @test species_symbols(sites) == [:Al, :Ga]
        @test canonical(sites, 1) == canonical(sites, 2)
    end

    # ---- Parent-based convenience constructors with symbols ----

    @testset "Sites(parent, [:Al, :Ga]) uniform on monatomic parent" begin
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        sites = Sites(p, [:Al, :Ga])
        @test species_symbols(sites) == [:Al, :Ga]
    end

    @testset "Sites(parent, [:Al, :Ga]) uniform on multilattice parent" begin
        A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
        p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        sites = Sites(p, [:Al, :Ga])
        @test species_symbols(sites) == [:Al, :Ga]
        @test length(sites.list) == 2
    end

    @testset "Sites(parent, [[:Al, :Ga], [:As]]) per-position on multilattice" begin
        A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
        p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        sites = Sites(p, [[:Al, :Ga], [:As]])
        @test species_symbols(sites) == [:Al, :Ga, :As]
        @test sites.list[1].allowed_labels == BitSet([0, 1])
        @test sites.list[2].allowed_labels == BitSet([2])
    end

    @testset "Sites(parent, [[symbols]]) length mismatch errors" begin
        A_hcp = [1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)]
        p = ParentLattice(A_hcp, [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        @test_throws ArgumentError Sites(p, [[:Al, :Ga]])  # length 1, ndset = 2
    end

    # ---- Explicit species_symbols= kwarg with integer Sites ----

    @testset "Explicit species_symbols= with integer Sites" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])]; species_symbols = [:Al, :Ga])
        @test species_symbols(sites) == [:Al, :Ga]
    end

    @testset "species_symbols= too short throws" begin
        @test_throws ArgumentError Sites(
            [Site([0.0, 0.0, 0.0], [0, 1, 2])];
            species_symbols = [:Al, :Ga],
        )
    end

    @testset "species_symbols= too long throws (dense length required)" begin
        @test_throws ArgumentError Sites(
            [Site([0.0, 0.0, 0.0], [0, 1])];
            species_symbols = [:Al, :Ga, :As],
        )
    end

    # ---- Mixed-type rejection ----

    @testset "Mixed Site + SymbolSite in one Sites errors" begin
        @test_throws ArgumentError Sites([
            Site([0.0, 0.0, 0.0], [0, 1]),
            Site([0.25, 0.25, 0.25], [:As]),
        ])
    end

    # ---- Accessors ----

    @testset "species_symbols(sites) returns nothing for integer Sites" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        @test species_symbols(sites) === nothing
    end

    @testset "species_symbols(sites) returns Vector{Symbol} for symbol Sites" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [:Al, :Ga])])
        @test species_symbols(sites) == [:Al, :Ga]
        @test species_symbols(sites) isa Vector{Symbol}
    end

    @testset "to_atom_labeling translates integer to symbol labeling" begin
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        sites = Sites(p, [:Al, :Ga])
        e = Enumlib.enumerate(p, sites; supercells = VolumeRange(2:2))
        for struc in e.structures
            int_lbl = to_labeling(struc)
            sym_lbl = to_atom_labeling(struc, sites)
            @test length(sym_lbl) == length(int_lbl)
            @test all(sym_lbl[i] in (:Al, :Ga) for i in eachindex(sym_lbl))
            # Each int label maps to its symbol.
            for (i, l) in enumerate(int_lbl)
                @test sym_lbl[i] == (l == 0 ? :Al : :Ga)
            end
        end
    end

    @testset "to_atom_labeling on integer-only Sites throws" begin
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        sites = Sites(p, [0, 1])
        e = Enumlib.enumerate(p, sites; supercells = VolumeRange(1:1))
        @test_throws ArgumentError to_atom_labeling(e[1], sites)
    end

    # ---- Base.show ----

    @testset "Base.show renders symbols when present" begin
        sites = Sites([
            Site([0.0, 0.0, 0.0],     [:Al, :Ga]),
            Site([0.25, 0.25, 0.25],  [:As]),
        ])
        s = sprint(show, sites)
        @test occursin(":Al", s)
        @test occursin(":Ga", s)
        @test occursin(":As", s)
        @test !occursin("{0,", s)
    end

    @testset "Base.show renders integers when no mapping" begin
        sites = Sites([Site([0.0, 0.0, 0.0], [0, 1])])
        s = sprint(show, sites)
        @test occursin("{0, 1}", s)
        @test !occursin(":Al", s)
    end

    # ---- End-to-end: write_enumeration_archive uses Sites mapping ----

    @testset "write_enumeration_archive defaults species_symbols from Sites" begin
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        sites = Sites(p, [:Al, :Ga])
        e = Enumlib.enumerate(p, sites; supercells = VolumeRange(2:2))
        mktempdir() do tmp
            out = Enumlib.write_enumeration_archive(
                tmp, e; super_periodic = false, keep_directory = true,
            )
            kept = replace(out, r"\.tar\.gz$" => "")
            poscars = sort(filter(f -> endswith(f, ".POSCAR"), readdir(kept)))
            @test !isempty(poscars)
            lines = readlines(joinpath(kept, first(poscars)))
            @test occursin("Al", lines[6]) && occursin("Ga", lines[6])
        end
    end

    @testset "write_enumeration_archive: explicit species_symbols= wins" begin
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        sites = Sites(p, [:Al, :Ga])
        e = Enumlib.enumerate(p, sites; supercells = VolumeRange(2:2))
        mktempdir() do tmp
            out = Enumlib.write_enumeration_archive(
                tmp, e;
                super_periodic = false,
                species_symbols = ["X", "Y"],
                keep_directory = true,
            )
            kept = replace(out, r"\.tar\.gz$" => "")
            poscars = sort(filter(f -> endswith(f, ".POSCAR"), readdir(kept)))
            lines = readlines(joinpath(kept, first(poscars)))
            @test occursin("X", lines[6]) && occursin("Y", lines[6])
            @test !occursin("Al", lines[6])
        end
    end

    @testset "End-to-end Regime C: heterogeneous symbols + concentration" begin
        # Zincblende-style AlGaAs setup with three distinct labels.
        fcc = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
        p = ParentLattice(fcc, [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
        sites = Sites([
            Site([0.0,  0.0,  0.0 ], [:Al, :Ga]),
            Site([0.25, 0.25, 0.25], [:As]),
        ])
        @test species_symbols(sites) == [:Al, :Ga, :As]
        c = concentration_count([1, 1, 2]; n_total = 4)
        e = Enumlib.enumerate(p, sites; supercells = VolumeRange(2:2), concentration = c)
        @test length(e) == 2

        # Every structure's atom labeling has 1 Al, 1 Ga, 2 As.
        for struc in e.structures
            atoms = to_atom_labeling(struc, sites)
            @test count(==(:Al), atoms) == 1
            @test count(==(:Ga), atoms) == 1
            @test count(==(:As), atoms) == 2
        end
    end
end
