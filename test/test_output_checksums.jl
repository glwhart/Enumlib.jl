using Test
using Enumlib

# Exact enumeration output locked by checksum, not just counts.
#
# Most enumeration tests check how many structures come out. Those pass even if an
# algorithm returns different structures, or the same ones in a different order.
# Each case below locks the exact output list: every structure's supercell id,
# orbit size and labeling, in output order, folded into a 64-bit FNV-1a checksum.
# The checksum is written out here instead of using `hash`, whose values may change
# between Julia versions.
#
# These are regression locks, not independent references. The values were recorded
# on 2026-11-19 from the code at that date. The two FCC tree cases also match the
# tree as it was before subsets were stepped instead of decoded
# (docs/notes/necklace-enumeration.md §5). The counts are cross-checked against
# other algorithms and Pólya counting elsewhere in the suite.
#
# If a change alters the output on purpose (a new order, a different canonical
# representative), confirm the counts are unchanged, then record the new checksums
# and say why in the commit message.

function output_checksum(e)
    h = UInt64(14695981039346656037)
    mix(h, v) = (h ⊻ UInt64(v)) * UInt64(1099511628211)
    for s in e
        h = mix(h, s.supercell_id)
        h = mix(h, s.orbit_size)
        for x in s.labeling
            h = mix(h, x)
        end
    end
    return h
end

@testset "Enumeration output locked by checksum" begin
    full(k) = ConcentrationRange([(0//1, 1//1) for _ in 1:k])
    big = (partition_threshold = 10^9, skip_resource_check = true)

    fcc = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    bcc = ParentLattice([-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5])
    hcp = ParentLattice([1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)],
                        [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
    # Two-site FCC parent with a different pair of species allowed on each site
    # (the site-restricted case).
    zb = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                       [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
    zb_sites = Sites([Site([0.0, 0.0, 0.0], [0, 1]),
                      Site([0.25, 0.25, 0.25], [2, 3])])

    # (description, () -> enumeration, expected count, expected checksum)
    cases = [
        ("FCC binary n=12, tree, all concentrations",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(12:12),
                   concentration = full(2), algorithm = :recursive_stabilizer, big...),
         7140, 0xebc1df578b5b4b15),
        ("FCC ternary n=10, tree, all concentrations",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1, 2]); supercells = VolumeRange(10:10),
                   concentration = full(3), algorithm = :recursive_stabilizer, big...),
         55461, 0x3ace19001e37c517),
        ("FCC binary n=8, tree, super-periodic structures kept",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(8:8),
                   concentration = full(2), algorithm = :recursive_stabilizer,
                   include_superperiodic = true, big...),
         544, 0x51aa1572853ffec9),
        ("BCC binary n=12, tree, all concentrations",
         () -> enumerate_structures(bcc, Sites(bcc, [0, 1]); supercells = VolumeRange(12:12),
                   concentration = full(2), algorithm = :recursive_stabilizer, big...),
         7140, 0x84f2e52239813899),
        ("HCP binary n=5, tree, all concentrations",
         () -> enumerate_structures(hcp, Sites(hcp, [0, 1]); supercells = VolumeRange(5:5),
                   concentration = full(2), algorithm = :recursive_stabilizer, big...),
         651, 0x7a22c5da823ab5bc),
        ("site-restricted two-site FCC n=3, tree",
         () -> enumerate_structures(zb, zb_sites; supercells = VolumeRange(3:3),
                   concentration = full(4), algorithm = :recursive_stabilizer, big...),
         52, 0xb0bb848c24005d73),
        ("FCC binary n=10, exhaustive",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(10:10)),
         1211, 0x9ac0824a36727c37),
        ("FCC ternary n=7, exhaustive",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1, 2]); supercells = VolumeRange(7:7)),
         1245, 0x03e8c3d270e4a6e6),
        ("HCP binary n=5, exhaustive",
         () -> enumerate_structures(hcp, Sites(hcp, [0, 1]); supercells = VolumeRange(5:5)),
         651, 0x7a22c5da823ab5bc),
        ("FCC binary n=12 at 6:6, multinomial",
         () -> enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(12:12),
                   concentration = concentration_count([6, 6]; n_total = 12),
                   algorithm = :multinomial),
         1552, 0x5f7262b490706b39),
        ("site-restricted two-site FCC n=3, multinomial_restricted",
         () -> enumerate_structures(zb, zb_sites; supercells = VolumeRange(3:3),
                   concentration = full(4), algorithm = :multinomial_restricted, big...),
         52, 0x3fecc60fa316ac3b),
    ]

    for (description, run, count, checksum) in cases
        @testset "$description" begin
            e = run()
            @test length(e) == count
            @test output_checksum(e) == checksum
        end
    end
end

# ---- Second batch: outputs other than the structure list ----
#
# Supercell (HNF) lists, enumerations spanning several volumes, partial
# concentration ranges, and POSCAR text. Recorded 2026-11-20. Every case names its
# algorithm explicitly, because `:auto` chooses by a cost estimate and memory
# budget that can differ between machines, which would change the output order.

const _FNV_OFFSET = UInt64(14695981039346656037)
_fnv(h::UInt64, v::Integer) = (h ⊻ UInt64(v)) * UInt64(1099511628211)
_fnv(h::UInt64, s::AbstractString) = foldl(_fnv, codeunits(s); init = h)

# Every HNF matrix entry, in list order.
hnf_list_checksum(hnfs) = foldl((h, H) -> foldl(_fnv, H.matrix; init = h), hnfs;
                                init = _FNV_OFFSET)

# POSCAR text with every number rounded to 6 decimals, so the last printed digits
# (12 decimals in the file) cannot differ between machines. Fractional positions
# are wrapped into [0, 1) after rounding, so 0.9999999999 and 0.0 agree, and -0.0
# becomes 0.0. The radius in the header line is dropped for the same reason.
function poscar_normalized(text)
    out = String[]
    direct = false
    for line in split(text, '\n')
        if startswith(line, "#")
            push!(out, replace(line, r"radius=\S+" => "radius="))
            continue
        end
        if line == "Direct"
            direct = true
            push!(out, line)
            continue
        end
        toks = split(line)
        if !isempty(toks) && occursin('.', line) &&
           all(t -> tryparse(Float64, t) !== nothing, toks)
            vals = parse.(Float64, toks)
            if direct
                vals = mod.(round.(mod.(vals, 1.0); digits = 6), 1.0)
            end
            vals = round.(vals; digits = 6) .+ 0.0
            push!(out, join(string.(vals), " "))
        else
            push!(out, line)
        end
    end
    return join(out, "\n")
end

function poscar_checksum(e)
    io = IOBuffer()
    for s in e.structures
        to_poscar(io, s, e.parent, e.supercells[s.supercell_id].hnf; super_periodic = false)
    end
    return _fnv(_FNV_OFFSET, poscar_normalized(String(take!(io))))
end

@testset "Supercells, volume ranges, partial concentrations and POSCAR locked by checksum" begin
    big = (partition_threshold = 10^9, skip_resource_check = true)
    fcc = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
    bcc = ParentLattice([-0.5 0.5 0.5; 0.5 -0.5 0.5; 0.5 0.5 -0.5])
    sc  = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0])
    tet = ParentLattice([1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.3])
    hcp = ParentLattice([1.0 -0.5 0.0; 0.0 sqrt(3)/2 0.0; 0.0 0.0 sqrt(8/3)],
                        [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])

    @testset "symmetry-distinct supercells (HNF lists)" begin
        for (name, parent, volumes, count, checksum) in [
                ("FCC",        fcc, 1:12, 139, 0x878bfbf5c17c2b59),
                ("BCC",        bcc, 1:12, 139, 0x70f4458170d4c1d8),
                ("simple cubic", sc, 1:12, 162, 0x1ab0b7c120a9f7cc),
                ("tetragonal", tet, 1:8,  130, 0x7aebec19d4b35f22),
                ("HCP",        hcp, 1:8,   91, 0xd56324e36163b6ee)]
            @testset "$name, volumes $volumes" begin
                hnfs = enumerate_hnfs(VolumeRange(volumes), parent)
                @test length(hnfs) == count
                @test hnf_list_checksum(hnfs) == checksum
            end
        end
    end

    @testset "structure numbering across several volumes" begin
        e = enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(1:8))
        @test length(e) == 631
        @test length(e.supercells) == 55
        @test output_checksum(e) == 0x4c8c2941af0566c3
        e = enumerate_structures(hcp, Sites(hcp, [0, 1, 2]); supercells = VolumeRange(1:3))
        @test length(e) == 507
        @test output_checksum(e) == 0x7bf4b4880cdcc84d
    end

    @testset "partial concentration ranges" begin
        b_third = ConcentrationRange([(0//1, 1//3), (2//3, 1//1)])
        for alg in (:multinomial, :recursive_stabilizer)
            e = enumerate_structures(fcc, Sites(fcc, [0, 1]); supercells = VolumeRange(6:10),
                                     concentration = b_third, algorithm = alg, big...)
            @test length(e) == 478
            @test output_checksum(e) == 0x4304c3f7ba2fef12
        end
        ab_half = ConcentrationRange([(0//1, 1//2), (0//1, 1//2), (0//1, 1//1)])
        e = enumerate_structures(fcc, Sites(fcc, [0, 1, 2]); supercells = VolumeRange(4:7),
                                 concentration = ab_half, algorithm = :recursive_stabilizer, big...)
        @test length(e) == 1540
        @test output_checksum(e) == 0x89a2f12e29a90c8e
    end

    @testset "POSCAR text" begin
        e = enumerate_structures(fcc, Sites(fcc, [0, 1, 2]); supercells = VolumeRange(1:4))
        @test length(e) == 126
        @test poscar_checksum(e) == 0x7fb3c8a5d58fd9d3
        e = enumerate_structures(hcp, Sites(hcp, [0, 1]); supercells = VolumeRange(1:3))
        @test length(e) == 63
        @test poscar_checksum(e) == 0xb175283986b2cddc
    end
end
