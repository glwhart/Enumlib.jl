# Example run that create_app executes while building the standalone app
# (precompile_execution_file in build_app.jl). Every method it compiles is saved
# in the app, so enum.x, polya.x and makestr.x start without compiling the
# enumeration. Without it the conda build, which turns off the package's own
# precompile workload, spent about 6.5 s compiling on every enum.x call.
#
# Small inputs, a second or two in all: a single lattice with all concentrations,
# a multilattice with a concentration range, and a site-restricted multilattice.

using Enumlib

const INPUTS = [
    """
    FCC
    bulk
    0.5 0.5 0
    0 0.5 0.5
    0.5 0 0.5
    2 # number of labels
    1 # number of points in the multilattice
    0 0 0    0/1
       1 6    # starting and ending cell sizes
    0.001    # eps
    full list of labelings (including incomplete labelings) is used
    """,
    """
    HCP
    bulk
    1 0 0
    0.5 0.86602540378 0
    0 0 1.63299316186
    3 # number of labels
    2 # number of points in the multilattice
    0 0 0    0/1/2
    0.5 0.28867513459 0.81649658093    0/1/2
       1 3    # starting and ending cell sizes
    0.001    # eps
    full list of labelings (including incomplete labelings) is used
    1 4 6
    1 4 6
    1 4 6
    """,
    """
    Half-Heusler
    bulk
    0.5 0.5 0
    0 0.5 0.5
    0.5 0 0.5
    4 # number of labels
    3 # number of points in the multilattice
    0 0 0    0/1
    0.25 0.25 0.25    2
    0.75 0.75 0.75    3
       1 4    # starting and ending cell sizes
    0.001    # eps
    full list of labelings (including incomplete labelings) is used
    """,
]

function run_main(f, args...)
    empty!(ARGS)
    append!(ARGS, args)
    f() == 0 || error("$(f) failed in the precompile run")
end

mktempdir() do dir
    cd(dir) do
        for text in INPUTS
            write("struct_enum.in", text)
            run_main(Enumlib.enum_main)
            run_main(Enumlib.polya_main)
            run_main(Enumlib.makestr_main, "struct_enum.out", "1", "3")
        end
    end
end
empty!(ARGS)
