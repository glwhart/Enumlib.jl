export readStructEnum, readEnergies

""" Extract energies from concatenated vasp results. Output is sorted by structure number.   

    readEnergies(filename)
"""
function readEnergies(filename)
lines=readlines(filename) # readlines more convenient than readdlm
rx = r"dir_POSCAR(\d+)"
id=[parse(Int,match(rx,i).captures[1]) for i ∈ filter(x->occursin("dir_POSCAR",x),lines)]
energies=[parse(Float64,split(i)[5]) for i ∈ filter(x->occursin("free",x),lines)][sortperm(id)]
return energies
end

struct enumStr
    basis::Matrix{Float64} # Basis vectors of the superstructure in Cartesian coordinates 
    atomTypes::Vector{Int} # Not sure what I intended here...
    n::Int # Number of atoms in the structure
    atomPos::Matrix{Float64} # Atomic positions (columns) in Cartesian coordinates
    HNF::Matrix{Int} # Not necessarily in HNF form, but an integer matrix
    SNF::Matrix{Int} # SNF form of HNF (diagonal entries only)
    L::Matrix{Int}  # Left transformation matrix for converting HNF to SNF
    coloring::String # Atomic type of each lattice point 
    energy::Float64 # Energy of the structure
end

""" Extract structure information from struct_enum.out-formatted file. Attach energies to each structure. 

    readStructEnum(filename,energies)"""
function readStructEnum(filename,en)
#filename = "data/struct_enum.out.1-10_fcc_binary"
lines=readlines(filename) # Skip the lattice info at the head
println("Reading in: ",filename)
print("Description:",lines[1])
print(lines[2])
# Get basis vectors (read in 3 vectors, make them columns)
A = stack([[parse(Float64,i) for i ∈ split(j)[1:3]] for j ∈ lines[3:5]],dims=2)
print("Basis vectors:")
display(A)
# Get pointgroup operations in lattice coordinates and Cartesian
LG,G = pointGroup(A)
# Parse structure information and store in a vector of enumStr types
str = Vector{enumStr}();
for (i,iline) ∈ enumerate(lines[16:end])
    atomPos = zeros(3,3)
    d = parse.(Int,split(iline))
    labeling = String(split(iline)[end])    
    n = d[7]
    snf = diagm(d[9:11])
    hnf = [d[12] 0 0; d[13] d[14] 0; d[15] d[16] d[17]]
    L = [d[18] 0 0; d[19] d[20] 0; d[21] d[22] d[23]]
    energy = en[i]/n
    push!(str,enumStr(A*hnf,[0,1],n,atomPos,hnf,snf,L,labeling,energy))
end
return str
end
