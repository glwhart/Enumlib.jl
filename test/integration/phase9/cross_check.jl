# L1 (count parity) + L3-lite (structure parity via makeStr + StructureMatcher)
# for the drop-in enum.x, against the Fortran enum.x. NOT a CI test — needs the
# external tools below. See README.md.
#
#   ENUM_X=<fortran enum.x> [MAKESTR_PY=<makeStr.py> PMG_PYTHON=<venv python>] \
#     julia --project=<repo> test/integration/phase9/cross_check.jl
using Enumlib, Printf

const HERE = @__DIR__
enum_x  = get(ENV, "ENUM_X", "")
makestr = get(ENV, "MAKESTR_PY", "")
pypath  = get(ENV, "PMG_PYTHON", "")
isempty(enum_x) && error("Set ENUM_X to a built Fortran enum.x (see README.md).")
do_l3 = !isempty(makestr) && !isempty(pypath)

fcc  = [0.5 0.5 0.0; 0.5 0.0 0.5; 0.0 0.5 0.5]
fcc2 = [0.0 0.5 0.5; 0.5 0.0 0.5; 0.5 0.5 0.0]
hcp  = (a = 1.0; c = sqrt(8/3); [a -a/2 0.0; 0.0 a*sqrt(3)/2 0.0; 0.0 0.0 c])
C(name, A, dset, labels, nr, conc, ref) = (; name, A, dset, labels, nr, conc, ref)

# "Clean" cases (all sites active) — directly comparable to the Fortran enum.x.
# Inactive-single-label Regime C (Heusler/perovskite) is covered pure-Julia in
# test/test_struct_enum_io.jl pending the deferred inactive-encoding work.
cases = [
    C("fcc_bin_n4",   fcc,  [[0.,0,0]],                 [[0,1]],       4:4, nothing,            19),
    C("fcc_bin_n8",   fcc,  [[0.,0,0]],                 [[0,1]],       8:8, nothing,            390),
    C("fcc_tern_n4",  fcc,  [[0.,0,0]],                 [[0,1,2]],     4:4, nothing,            96),
    C("fcc_conc_n4",  fcc,  [[0.,0,0]],                 [[0,1]],       4:4, [(2,2,4),(2,2,4)],  5),
    C("fcc_conc_n8",  fcc,  [[0.,0,0]],                 [[0,1]],       8:8, [(4,4,8),(4,4,8)],  94),
    C("hcp_n3",       hcp,  [[0.,0,0],[1/3,2/3,1/2]],   [[0,1],[0,1]], 3:3, nothing,            50),
    C("diamond_n3",   fcc2, [[0.,0,0],[0.25,0.25,0.25]],[[0,1],[0,1]], 3:3, nothing,            33),
    C("zincblende_n3",fcc2, [[0.,0,0],[0.25,0.25,0.25]],[[0,1],[2,3]], 3:3, nothing,            52),
]

function gen_in(io, c)
    println(io, c.name); println(io, "bulk")
    for j in 1:3; @printf(io, "%.12f %.12f %.12f\n", c.A[1,j], c.A[2,j], c.A[3,j]); end
    println(io, maximum(maximum.(c.labels)) + 1, " -nary case")
    println(io, length(c.dset), " # nD")
    for (p, l) in zip(c.dset, c.labels)
        cart = c.A * p; @printf(io, "%.12f %.12f %.12f  %s\n", cart[1], cart[2], cart[3], join(l, "/"))
    end
    println(io, first(c.nr), " ", last(c.nr)); println(io, "1e-6"); println(io, "full")
    c.conc === nothing || for (lo, hi, den) in c.conc; println(io, lo, " ", hi, " ", den); end
end

function fortran_count(dir)
    out = cd(() -> read(pipeline(`$enum_x`), String), dir)
    tot = nothing; started = false
    for l in split(out, '\n')
        s = strip(l); endswith(s, "RunTot") && (started = true; continue)
        started && occursin(r"^\d", s) && (tot = parse(Int, split(s)[end]))
    end
    tot
end

println(rpad("case", 16), rpad("ref", 6), rpad("Fortran", 9), rpad("Julia", 7), rpad("L1", 5), "L3-lite")
nfail = 0
mktempdir() do base
    for c in cases
        jd = joinpath(base, c.name, "J"); fd = joinpath(base, c.name, "F"); mkpath(jd); mkpath(fd)
        open(io -> gen_in(io, c), joinpath(jd, "struct_enum.in"), "w")
        cp(joinpath(jd, "struct_enum.in"), joinpath(fd, "struct_enum.in"))
        inp = Enumlib.read_struct_enum_in(joinpath(jd, "struct_enum.in"))
        e = enumerate(inp.parent, inp.sites; supercells = inp.selection, concentration = inp.concentration,
                      partition_threshold = 1_000_000, skip_resource_check = true)
        open(io -> Enumlib.write_struct_enum_out(io, e; input = inp, stdout_io = devnull),
             joinpath(jd, "struct_enum.out"), "w")
        jc = length(e); fc = fortran_count(fd)
        l1 = (fc == c.ref && jc == c.ref) ? "✓" : "✗"
        l3 = "skip"
        if do_l3
            run(pipeline(Cmd(`$pypath $makestr -input struct_enum.out 1 $jc`, dir = jd), stdout = devnull, stderr = devnull))
            run(pipeline(Cmd(`$pypath $makestr -input struct_enum.out 1 $fc`, dir = fd), stdout = devnull, stderr = devnull))
            r = read(`$pypath $(joinpath(HERE, "compare_structs.py")) $jd $fd`, String)
            l3 = occursin("MATCH", r) ? "✓" : "✗"
        end
        (l1 == "✗" || l3 == "✗") && (nfail += 1)
        println(rpad(c.name, 16), rpad(c.ref, 6), rpad(string(fc), 9), rpad(string(jc), 7), rpad(l1, 5), l3)
    end
end
println("-"^52)
println(nfail == 0 ? "ALL CROSS-CHECKS PASS ✓" : "$nfail case(s) FAILED ✗")
