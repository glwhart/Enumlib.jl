using clusterExpansion
using LinearAlgebra
using Spacey
using DelimitedFiles
using NormalForms
using MinkowskiReduction

function matrixToString(matrix)
    rows = [join(matrix[i, :], " ") for i in 1:size(matrix, 1)]
    return join(rows, "\n")
end

A = [0.5 0.0 0.5; 0.5 0.5 0.0; 0.0 0.5 0.5] # FCC lattice
# A = [.5 -.5 .5; .5 .5 -.5; -.5 .5 .5] # BCC lattice
LG,G=pointGroup(A)

n = 20
@time rhnfs = vcat([getSymInequivHNFs(i,A,G) for i ∈ 1:n]...)
rhnfs2 = []
for hnf in rhnfs
    hnf = round.(Int, inv(A)*minkReduce(A*hnf))
    if det(hnf) < 0
        hnf[:,1], hnf[:,2] = hnf[:,2], hnf[:,1]
    end
    push!(rhnfs2, hnf)
end
r = [cellRadius(A*i) for i in rhnfs2]
hnfs = [h for (h,radius) in zip(rhnfs2,r) if radius < 1.23]

#fcc binary 1.51 (16450)
#fcc ternary 1.29 (17195)
#fcc ternary 1.23 (2977)
#bcc binary 1.88 (15239)
#bcc ternary 1.66 (31719)

k = 3
rcolorings = Vector{Vector{Vector{Int64}}}()
for iH ∈ hnfs
    fixingOps = getFixingOps(iH,A,G)
    permG = getPermG(iH,fixingOps,A,G)
    push!(rcolorings,getUniqueColorings(k,permG))
end
println("rcolorings: ", sum(length.(rcolorings)))


dirpath= "poscars/fcc_ternary_r123"
atoms = ["a", "b", "c"]
natoms = length(atoms)
counter = 0
for h in eachindex(hnfs)
    hnf = hnfs[h]
    
    SNF = snf(hnf)
    size_num = abs(det(hnf))
    rad = cellRadius(A*hnf)
    
    for k in 1:length(rcolorings[h])
        counter += 1
        atom_indices = [findall(==(i-1), rcolorings[h][k]) for i in 1:natoms]
        counts = [length(atom_indices[i]) for i in 1:natoms]

        
        fname = "POSCAR." * lpad(string(counter),5,'0')
        fpath = joinpath(dirpath, fname)
        open(fpath, "w") do f
            write(f, string(rad))
            write(f, " ")
            write(f, join([string(counts[i]/size_num) for i in 1:natoms], " "))
            #Write radius before concentration
            write(f, "\n")
            write(f, "LP")
            write(f, "\n")
            write(f, matrixToString(transpose(A*hnf)))
            write(f, "\n")
            write(f, join([atoms[i] for i in 1:natoms], " "))
            write(f, "\n")
            write(f, join([counts[i] for i in 1:natoms], " "))
            write(f, "\n")
            write(f, "Direct\n")
            for i in 1:natoms
                for j in atom_indices[i]
                        # Convert the g-space coordinates to lattice coordinates
                        lattice_coord = mod.(inv(hnf) * inv(SNF.U) * ordinalToGcoords(j, diag(SNF.S)),1)
                        write(f, join(round.(lattice_coord, digits=15), " "))
                        write(f, "\n")
                end
            end
        end
    end
end




function compare_directories(dir1, dir2)
    files1 = sort(readdir(dir1))
    files2 = sort(readdir(dir2))

    # Only compare files that exist in both directories
    common_files = intersect(files1, files2)
    all_match = true

    for fname in common_files
        fpath1 = joinpath(dir1, fname)
        fpath2 = joinpath(dir2, fname)
        content1 = read(fpath1, String)
        content2 = read(fpath2, String)
        if content1 != content2
            println("Files differ: ", fname)
            all_match = false
        end
    end

    if all_match
        println("All files match.")
    end
end

compare_directories("poscars/fcc_ternary_r123", "poscars/fcc_ternary_r123 2")