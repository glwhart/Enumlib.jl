using Test
using LinearAlgebra
using Enumlib

# Cartesian (cell, positions) of an enumerated structure, in the raw HNF basis.
function _cartesian(parent, hnf, labeling)
    B = parent.A * hnf.matrix
    X = reduce(hcat, [B * collect(s) for s in Enumlib.supercell_fractional_positions(hnf, parent)])
    return B, X, Int.(labeling)
end

@testset "Reading structures back (from_poscar, EnumeratedStructure(e, …), structure_lookup)" begin
    fcc = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])

    @testset "_lower_hnf matches Enumlib's HNF convention" begin
        for h in enumerate_hnfs(VolumeRange(1:8), fcc)
            U = [1 2 0; 0 1 0; -1 0 1]                 # unimodular
            @test Enumlib._lower_hnf(h.matrix * U) == h.matrix
            @test Enumlib._lower_hnf(-h.matrix) == h.matrix
        end
    end

    @testset "round trip on every FCC structure, 4 species, up to 6 sites" begin
        e = enumerate_structures(fcc, Sites([Site([0.0, 0.0, 0.0], [0, 1, 2, 3])]);
                                 supercells = VolumeRange(1:6))
        for s in e.structures
            h = e.supercells[s.supercell_id].hnf
            r = Enumlib.supercell_and_labeling(fcc, _cartesian(fcc, h, to_labeling(s))...)
            @test r.hnf == h
            @test r.labeling == to_labeling(s)
        end
    end

    @testset "symmetry images and other bases find the enumerated structure" begin
        e = enumerate_structures(fcc, Sites([Site([0.0, 0.0, 0.0], [0, 1, 2])]);
                                 supercells = VolumeRange(1:5))
        lookup = structure_lookup(e)
        @test length(lookup) == length(e.structures)
        unimodular = [[1 0 0; 0 1 0; 0 0 1], [1 1 0; 0 1 0; 0 0 1], [0 1 0; 1 0 0; 0 0 1],
                      [1 0 -1; 0 1 0; 0 1 1]]
        for (i, s) in enumerate(e.structures)
            h = e.supercells[s.supercell_id].hnf
            B, X, lab = _cartesian(fcc, h, to_labeling(s))
            # Image under a space-group op, a lattice translation, another basis of the
            # superlattice, and a reordering of the atoms, all cycled through by structure index.
            op = fcc.space_group[mod1(7i, length(fcc.space_group))]
            Rc = fcc.A * op.R * inv(fcc.A)                 # Cartesian rotation
            shift = fcc.A * [mod(i, 5) - 2, mod(3i, 5) - 2, mod(7i, 5) - 2]
            B2 = Rc * B * unimodular[mod1(i, length(unimodular))]
            X2 = Rc * X .+ shift
            p = circshift(reverse(1:length(lab)), i)
            r = Enumlib.supercell_and_labeling(fcc, B2, X2[:, p], lab[p])
            @test get(lookup, Enumlib.canonical_form(fcc, r.hnf, r.labeling), 0) == i
        end
    end

    @testset "from_poscar inverts to_poscar" begin
        e = enumerate_structures(fcc, Sites([Site([0.0, 0.0, 0.0], [0, 1, 2])]);
                                 supercells = VolumeRange(1:6))
        lookup = structure_lookup(e)
        for s in e.structures[1:13:end]
            io = IOBuffer()
            to_poscar(io, s, fcc, e.supercells[s.supercell_id].hnf; super_periodic = false,
                      species_symbols = ["Ni", "Fe", "Cr"])
            @test from_poscar(seekstart(io), e; lookup) === s
        end
    end

    @testset "from_poscar: species mapping, VASP 4, Cartesian, scale, Selective dynamics" begin
        e = enumerate_structures(fcc, Sites([Site([0.0, 0.0, 0.0], [0, 1])]);
                                 supercells = VolumeRange(1:4))
        # The (001) superlattice of A and B, in a doubled cell with lattice constant 2.
        cell = "0.0 1.0 1.0\n1.0 0.0 1.0\n2.0 2.0 0.0"
        target = EnumeratedStructure(e, [0.0 0.5 1.0; 0.5 0.0 1.0; 0.5 0.5 0.0],
                                     [0.0 0.5; 0.0 0.5; 0.0 0.0], [0, 1])
        vasp5 = "AB\n0.5\n$cell\nA B\n1 1\nDirect\n0 0 0\n0 0 0.5\n"
        @test from_poscar(IOBuffer(vasp5), e) === target
        # Species listed in the other order, mapped by symbol.
        swapped = "BA\n0.5\n$cell\nB A\n1 1\nDirect\n0 0 0.5\n0 0 0\n"
        @test from_poscar(IOBuffer(swapped), e; species_symbols = ["A", "B"]) === target
        vasp4 = "AB\n0.5\n$cell\n1 1\nCartesian\n0 0 0\n1 1 0\n"
        @test from_poscar(IOBuffer(vasp4), e) === target
        negscale = "AB\n-0.5\n$cell\nA B\n1 1\nSelective dynamics\nDirect\n0 0 0 T T T\n0 0 0.5 T T T\n"
        @test from_poscar(IOBuffer(negscale), e) === target       # volume 0.5 = two cells of 1/4
        path = tempname()
        write(path, vasp5)
        @test from_poscar(path, e) === target
        @test_throws ArgumentError from_poscar(IOBuffer(vasp5), e; species_symbols = ["A", "C"])
    end

    @testset "EnumeratedStructure(e, …) rejects structures outside the enumeration" begin
        e = enumerate_structures(fcc, Sites([Site([0.0, 0.0, 0.0], [0, 1])]);
                                 supercells = VolumeRange(1:2))
        h = HNF{3}([1 0 0; 0 1 0; 0 0 3])
        @test_throws ArgumentError EnumeratedStructure(e, _cartesian(fcc, h, [0, 0, 1])...)  # volume 3
        h2 = HNF{3}([1 0 0; 0 1 0; 0 1 2])
        @test_throws ArgumentError EnumeratedStructure(e, _cartesian(fcc, h2, [1, 1])...)     # super-periodic
    end

    @testset "HCP multilattice round trip" begin
        hcp = ParentLattice([1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)],
                            [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        e = enumerate_structures(hcp, Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                                             Site([1/3, 2/3, 1/2], [0, 1])]);
                                 supercells = VolumeRange(1:3))
        lookup = structure_lookup(e)
        for (i, s) in enumerate(e.structures)
            h = e.supercells[s.supercell_id].hnf
            r = Enumlib.supercell_and_labeling(hcp, _cartesian(hcp, h, to_labeling(s))...)
            @test r.hnf == h && r.labeling == to_labeling(s)
            @test lookup[Enumlib.canonical_form(hcp, r.hnf, r.labeling)] == i
        end
    end

    @testset "errors" begin
        h = HNF{3}([1 0 0; 0 1 0; 0 1 2])
        B, X, lab = _cartesian(fcc, h, [0, 1])
        @test_throws ArgumentError Enumlib.supercell_and_labeling(fcc, 1.05 .* B, X, lab)      # wrong lattice constant
        @test_throws ArgumentError Enumlib.supercell_and_labeling(fcc, B, X[:, 1:1], lab[1:1]) # missing atom
        @test_throws ArgumentError Enumlib.supercell_and_labeling(fcc, B, hcat(X[:, 1], X[:, 1]), lab) # same site twice
        @test_throws ArgumentError Enumlib.supercell_and_labeling(fcc, B, X .+ [0.1, 0, 0], lab)  # off-lattice
    end
end
