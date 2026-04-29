using CodecZlib

export readStructenumout, readEnergies, readStrIn

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
# Get basis vectors (read in 3 vectors, make them columns)
A = stack([[parse(Float64,i) for i ∈ split(j)[1:3]] for j ∈ lines[3:5]],dims=2)
k = parse(Int,lines[8][1:2]) # Get number of species in this file
# Get pointgroup operations in lattice coordinates and Cartesian
LG = pointGroup(A)
G = toCartesian(LG, A)
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

""" Read an UNCLE-type structures.in file and return a vector of configurations as enumStr types.

    readStrIn(filename)
"""
function readStrIn(filename)
    if (endswith(filename,".gz"))
        gzfile = GzipDecompressorStream(open(filename))
        try
            lines = collect(eachline(gzfile))
            close(gzfile)
            lines = lines[5:end]
        catch e
            close(gzfile)
            rethrow(e)
        end
    else
        lines=readlines(filename)[5:end]
    end
    k = length(split(lines[6]))
    nStr = count(x->contains(x,"Direct"),lines)
    str = Vector{enumStr}(undef,nStr)
    en = zeros(Float64,nStr) # Need the first k energies to compute enthalpy 
    A = hcat([parse.(Float64,split(lines[i])) for i ∈ 3:5]...)
    iStr = 0
    while !isempty(lines)
        iStr += 1
        #println("\nstructure:" ,popfirst!(lines))
        popfirst!(lines) # Skip over structure name
        popfirst!(lines) # Throw away lattice parameter. Maybe we should keep it but don't need it for standard CE
        sv = hcat([parse.(Float64,split(popfirst!(lines))) for i ∈ 1:3]...)
        sl = round.(Int,inv(A)*sv) # Convert to lattice coordinates
        #println("Lattice vectors: ",sv)
        iconc =  parse.(Int,split(popfirst!(lines))[1:k]) # Integer concentration vector
        #println("Concentration: ",iconc)
        n = sum(iconc)
        popfirst!(lines) # Throw away "Direct" label
        dcPts = hcat([parse.(Float64,split(popfirst!(lines))[1:3]) for i ∈ 1:n]...)
        #println(dcPts)
        #L = convert(Matrix{Int},smith(sl).Sinv)
        L = snf(sl).U
        #SNF = convert(Vector{Int},smith(sl).SNF)
        SNF = diag(snf(sl).S)
        # Get ordinals from gCoords
        gCoords = mod.(round.(L*sl*dcPts,digits=8),SNF)
        idx = sortperm(gCoordsToOrdinals(gCoords,SNF))
        lab = vcat([fill(i-1,j) for (i,j) ∈ enumerate(iconc)]...)
        lab = join(lab[idx]) # Reindex the labeling and convert to a string
        popfirst!(lines) # Throw away "Energy" comment
        en[iStr] = parse(Float64,popfirst!(lines))/n # Get energy per atom of this structure
    
        # compute enthalpy
        enthalpy = en[iStr] - sum([iconc[i]*en[i] for i ∈ 1:k])./n
        conc = [count(i->i==j,lab) for j ∈ 0:k-1]./n

        popfirst!(lines) # Throw away ###### divider
        #println("Str. #: ",iStr," Energy: ",en[iStr]," Enthalpy: ",enthalpy)
        str[iStr] = enumStr(sv,n,sl*dcPts,sl,SNF,L,lab,conc,en[iStr],enthalpy)
    end
    println("Read ",nStr," structures from: ",filename)
    return str
end