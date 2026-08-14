# High-volume head-to-head COUNT parity, pushed HARD (one-time confidence run):
# Fortran enum.x (full enumeration) vs Julia count_inequivalent (Pólya — no
# materialization), per volume, climbing until the Fortran side exceeds a wall-clock
# budget of several minutes per volume. struct_enum.out is symlinked to /dev/null so
# Fortran's write cost (not the science) never limits us — only CPU time does.
#
# NOT a CI test (needs ENUM_X). Optional ARGS[1] = case-name substring filter (for
# running regimes in parallel processes). See README.md.
#   ENUM_X=<fortran enum.x> julia --project=<repo> test/integration/phase9/high_volume.jl [filter]
using Enumlib, Printf

const enum_x = get(ENV, "ENUM_X", "")
isempty(enum_x) && error("Set ENUM_X to a built Fortran enum.x (see README.md).")
const TBUDGET = parse(Float64, get(ENV, "TBUDGET", "600"))   # s/volume; stop a case once exceeded
const NMAX    = 40                                            # hard safety cap on volume
const FILT    = length(ARGS) >= 1 ? ARGS[1] : ""

fcc  = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
fcc2 = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
bcc  = 0.5 .* [-1.0 1.0 1.0; 1.0 -1.0 1.0; 1.0 1.0 -1.0]
sc   = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
hcp  = (a = 1.0; c = sqrt(8/3); [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c])

# (name, A, dset, labels, heterogeneous?)
allcases = [
    ("A_fcc_binary",   fcc,  [[0.0,0,0]],                                   [[0,1]],        false),
    ("A_fcc_ternary",  fcc,  [[0.0,0,0]],                                   [[0,1,2]],      false),
    ("A_bcc_binary",   bcc,  [[0.0,0,0]],                                   [[0,1]],        false),
    ("A_sc_binary",    sc,   [[0.0,0,0]],                                   [[0,1]],        false),
    ("B_hcp_binary",   hcp,  [[0.0,0,0],[1/3,2/3,1/2]],                     [[0,1],[0,1]],  false),
    ("B_hcp_ternary",  hcp,  [[0.0,0,0],[1/3,2/3,1/2]],                     [[0,1,2],[0,1,2]], false),  # multilattice + multinary
    ("B_diamond",      fcc2, [[0.0,0,0],[0.25,0.25,0.25]],                  [[0,1],[0,1]],  false),
    ("C_zincblende",   fcc2, [[0.0,0,0],[0.25,0.25,0.25]],                  [[0,1],[2,3]],  true),
    ("C_halfHeusler",  fcc2, [[0.0,0,0],[0.25,0.25,0.25],[0.75,0.75,0.75]], [[0,1],[2],[2]],true),
]
cases = isempty(FILT) ? allcases : filter(c -> occursin(FILT, c[1]), allcases)

function gen_in(path, A, dset, labels, n)
    open(path, "w") do io
        println(io, "hv"); println(io, "bulk")
        for j in 1:3; @printf(io, "%.12f %.12f %.12f\n", A[1,j], A[2,j], A[3,j]); end
        println(io, maximum(maximum.(labels)) + 1, " -nary case")
        println(io, length(dset), " # nD")
        for (p, l) in zip(dset, labels)
            c = A * p; @printf(io, "%.12f %.12f %.12f  %s\n", c[1], c[2], c[3], join(l, "/"))
        end
        println(io, n, " ", n); println(io, "1e-6"); println(io, "full")
    end
end

# Run enum.x in `dir` (output → /dev/null), killing it if it exceeds `budget`.
# Returns (count::Union{BigInt,Nothing}, timedout::Bool).
function fort_count(dir, budget)
    p = joinpath(dir, "struct_enum.out")
    ispath(p) && rm(p; force = true); symlink("/dev/null", p)
    proc = open(Cmd(`$enum_x`; dir = dir), "r")
    timedout = Ref(false)
    killer = Timer(budget) do _
        process_running(proc) && (timedout[] = true; kill(proc))
    end
    out = try read(proc, String) finally close(killer) end
    wait(proc)
    timedout[] && return (nothing, true)
    tot = nothing; started = false
    for l in split(out, '\n')
        s = strip(l); endswith(s, "RunTot") && (started = true; continue)
        if started && occursin(r"^\d", s)
            t = tryparse(BigInt, split(s)[end]); t !== nothing && (tot = t)
        end
    end
    return (tot, false)
end

function jl_count(A, dset, labels, hetero, n)
    parent = length(dset) == 1 ? ParentLattice(A) : ParentLattice(A, dset)
    sites  = Sites([Site(dset[j], labels[j]) for j in eachindex(dset)])
    if hetero
        # Regime C: count_inequivalent returns the UNRESTRICTED Pólya upper bound — per-site
        # allowed_labels can't be expressed in a cycle index (by design, not a bug; phase9 §9).
        # Use exhaustive enumerate for the exact restricted count (matches Fortran); it
        # materializes, so Regime C is volume-limited (won't climb as high as A/B).
        conc = ConcentrationRange([(0//1, 1//1) for _ in 1:(maximum(maximum.(labels))+1)])
        return BigInt(length(enumerate(parent, sites; supercells = VolumeRange(n:n),
                     concentration = conc, skip_resource_check = true, partition_threshold = 10^9)))
    else
        # Regime A/B: Pólya count_inequivalent is exact here and scales without materializing.
        return BigInt(count_inequivalent(parent, sites; supercells = VolumeRange(n:n)))
    end
end

@printf("%-16s %-4s %-16s %-11s %-10s %s\n", "case", "n", "count", "Fortran s", "Julia s", "agree")
println("-"^70)
allok = Ref(true)   # Ref so mutation inside the mktempdir do-block reaches this scope
mktempdir() do base
    for (name, A, dset, labels, hetero) in cases
        d = joinpath(base, name); mkpath(d)
        maxn = 0; caseok = true; maxcount = BigInt(0)
        for n in 1:(hetero ? 8 : NMAX)   # Regime C uses enumerate (materializes) — cap at a tractable volume; it can't scale like A/B (no Pólya-fast exact count for site-restricted cases)
            gen_in(joinpath(d, "struct_enum.in"), A, dset, labels, n)
            tf = @elapsed ((fc, timedout) = fort_count(d, TBUDGET))
            if timedout
                @printf("%-16s %-4d Fortran > %.0fs budget — stop\n", name, n, TBUDGET); break
            end
            tj = @elapsed jc = jl_count(A, dset, labels, hetero, n)
            agree = (fc !== nothing && fc == jc)
            @printf("%-16s %-4d %-16s %-11.2f %-10.3f %s\n", name, n,
                    string(fc === nothing ? "?" : fc), tf, tj,
                    agree ? "OK" : "MISMATCH F=$fc J=$jc")
            flush(stdout)   # write each row now — Julia block-buffers stdout when redirected to a file
            maxn = n; fc === nothing || (maxcount = fc)
            if !agree; caseok = false; allok[] = false; break; end
            tf > TBUDGET && (println("   ($name: last volume took $(round(tf))s ≥ budget — stop)"); break)
        end
        println("   => $name: agreed through n=$maxn, largest count = $maxcount  ",
                caseok ? "[ALL AGREE]" : "[MISMATCH]"); flush(stdout)
    end
end
println("="^70)
println(allok[] ? "HIGH-VOLUME HEAD-TO-HEAD: ALL AGREE ✓" : "MISMATCH DETECTED ✗")
