using Test
using Enumlib

# v0.2-polish #1 (landed v0.3.1, 2026-05-23): broad Pólya reference table.
# Each row in `test/data/polya_reference.csv` locks an (aperiodic, total)
# orbit-count pair for one (lattice, volume, k, concentration) input. The
# testset below loads the CSV and asserts the current `count_inequivalent`
# matches every row.
#
# Why: the chunk-7 testset and the HF-2012 anchors cover specific cases.
# This file adds breadth — every BCC/FCC/HCP/Diamond reference row from
# HF 2008 / HF 2012 plus include_superperiodic = true companions. Any
# silent drift in the Pólya math (cycle structure, Burnside averaging,
# Möbius correction) will trip a row here even if the algorithm-side tests
# happen to compensate.

const REF_CSV = joinpath(@__DIR__, "data", "polya_reference.csv")

# Lattice constructors keyed by case name.
function _parent_sites(case::AbstractString, k::Integer)
    if case == "FCC"
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0])
        return p, Sites(p, collect(0:k-1))
    elseif case == "BCC"
        p = ParentLattice([0.5 0.5 -0.5; 0.5 -0.5 0.5; -0.5 0.5 0.5])
        return p, Sites(p, collect(0:k-1))
    elseif case == "HCP"
        a = 1.0; c = sqrt(8/3)
        p = ParentLattice([a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c],
                          [[0.0, 0.0, 0.0], [1/3, 2/3, 1/2]])
        return p, Sites(p, collect(0:k-1))
    elseif case == "Diamond"
        p = ParentLattice([0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0],
                          [[0.0, 0.0, 0.0], [0.25, 0.25, 0.25]])
        return p, Sites(p, collect(0:k-1))
    else
        error("unknown case: $case")
    end
end

# Concentration parser: "all" → nothing; "a:b[:c...]" → concentration_count.
function _parse_concentration(s::AbstractString, n::Integer, n_D::Integer)
    s == "all" && return nothing
    counts = parse.(Int, split(s, ':'))
    sum(counts) == n_D * n || error("counts $counts don't sum to n_D*n = $(n_D*n)")
    return concentration_count(counts; n_total = n_D * n)
end

# Read the CSV (skipping comment and header lines), return Vector of NamedTuples.
function _load_reference()
    rows = NamedTuple[]
    for line in eachline(REF_CSV)
        startswith(line, '#') && continue
        startswith(line, "case,") && continue
        isempty(strip(line)) && continue
        parts = split(line, ',')
        push!(rows, (case = String(parts[1]),
                     n = parse(Int, parts[2]),
                     k = parse(Int, parts[3]),
                     concentration = String(parts[4]),
                     aperiodic = parse(BigInt, parts[5]),
                     total = parse(BigInt, parts[6])))
    end
    return rows
end

@testset "Polya reference table (v0.2-polish #1)" begin
    rows = _load_reference()
    @test length(rows) > 30   # sanity: CSV loaded reasonably

    @testset "$(row.case) n=$(row.n) k=$(row.k) $(row.concentration)" for row in rows
        parent, sites = _parent_sites(row.case, row.k)
        n_D = length(parent.dset)
        c = _parse_concentration(row.concentration, row.n, n_D)
        kw = c === nothing ? (;) : (; concentration = c)

        ap = count_inequivalent(parent, sites; supercells = VolumeRange(row.n:row.n), kw...)
        tot = count_inequivalent(parent, sites; supercells = VolumeRange(row.n:row.n),
                                  kw..., include_superperiodic = true)
        @test ap == row.aperiodic
        @test tot == row.total
    end
end
