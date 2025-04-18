export readStructenumout, readEnergies

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

""" Structure type for enumerated configurations """
struct enumStr
    basis::Matrix{Float64} # Basis vectors of the superstructure in Cartesian coordinates
    n::Int # Number of atoms in the structure
    atomPos::Matrix{Float64} # Atomic positions (columns) in Cartesian coordinates
    HNF::Matrix{Int} # Not necessarily in HNF form, but an integer matrix, A*HNF=SL
    SNF::Vector{Int} # SNF form of HNF (diagonal entries only)
    L::Matrix{Int}  # Left transformation matrix for converting HNF to SNF
    coloring::String # Atomic type of each lattice point 
    concentration::Vector{Float64} # Concentration of each atom type 
    energy::Float64 # Energy of the structure
    enthalpy::Float64 # Enthalpy of the structure
end

""" Extract structure information from struct_enum.out-formatted file. Attach an energy to each structure. << Warning >> This assumes that the order of structures and the order of the energies match up. 

    readStructenumout(filename,energies)"""
function readStructenumout(filename,en)
lines=readlines(filename) # Skip the lattice info at the head
println("Reading in: ",filename)
print("Description:",lines[1])
print(lines[2])
# Get basis vectors (read in 3 vectors, make them columns)
A = stack([[parse(Float64,i) for i ∈ split(j)[1:3]] for j ∈ lines[3:5]],dims=2)
print("Basis vectors:")
display(A)
k = parse(Int,lines[8][1:2]) # Get number of species in this file
# Get pointgroup operations in lattice coordinates and Cartesian
LG,G = pointGroup(A)
# Parse structure information and store in a vector of enumStr types
str = Vector{enumStr}();
for (i,iline) ∈ enumerate(lines[16:end])
    atomPos = zeros(3,3)
    d = parse.(Int,split(iline))
    labeling = String(split(iline)[end])    
    n = d[7]
    snf = d[9:11]
    hnf = [d[12] 0 0; d[13] d[14] 0; d[15] d[16] d[17]]
    L = [d[18] 0 0; d[19] d[20] 0; d[21] d[22] d[23]]
    energy = en[i]/n
    concentration = [count(string(i),labeling) for i ∈ 0:k-1]./n
    # Enthalpy calculation assumes first k entries are the pure species
    enthalpy = energy - sum([concentration[i]*en[i] for i ∈ 1:k])
    push!(str,enumStr(A*hnf,n,atomPos,hnf,snf,L,labeling,concentration,energy,enthalpy))
end
return str
end



