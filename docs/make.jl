using Documenter
using Enumlib

DocMeta.setdocmeta!(Enumlib, :DocTestSetup, :(using Enumlib, LinearAlgebra); recursive = true)

makedocs(
    sitename = "Enumlib.jl",
    authors  = "Gus Hart and contributors",
    repo     = Remotes.GitHub("glwhart", "Enumlib.jl"),
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical  = "https://glwhart.github.io/Enumlib.jl",
        assets     = ["assets/strip_index_prefix.js"],
    ),
    modules  = [Enumlib],
    # Chunk 13b.4 raised checkdocs from :none to :exports — every public
    # symbol must appear in some `@docs` block on a reference page, and
    # every docstring's cross-references must resolve. Failures fail the
    # build (and CI), so reference-side drift can't reach production.
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "tutorials/index.md",
            "tutorials/01-first-enumeration.md",
            "tutorials/02-fixed-concentration.md",
            "tutorials/03-dft-training-database.md",
            "tutorials/04-multilattice-per-sublattice.md",
        ],
        "How-to guides" => [
            "how-to/index.md",
            "how-to/construct-a-parent-lattice.md",
            "how-to/describe-substitution-sites.md",
            "how-to/select-supercells.md",
            "how-to/enumerate-at-fixed-concentration.md",
            "how-to/sweep-concentration-ranges.md",
            "how-to/enumerate-multilattice.md",
            "how-to/specify-per-sublattice-concentration.md",
            "how-to/pick-an-algorithm.md",
            "how-to/count-without-enumerating.md",
            "how-to/estimate-cost.md",
            "how-to/handle-super-periodicity.md",
            "how-to/write-poscars-for-dft.md",
        ],
        "Reference" => [
            "reference/index.md",
            "reference/parent-and-sites.md",
            "reference/supercells.md",
            "reference/concentrations.md",
            "reference/enumerate-and-count.md",
            "reference/cost-estimator.md",
            "reference/polya.md",
            "reference/poscar-io.md",
        ],
        "Explanation" => [
            "explanation/index.md",
            "explanation/algorithm-overview.md",
            "explanation/exhaustive-2008.md",
            "explanation/multinomial-2012.md",
            "explanation/recursive-stabilizer-2017.md",
            "explanation/polya-counting.md",
            "explanation/dispatch-and-cost-gate.md",
            "explanation/super-periodicity.md",
            "explanation/concentration-and-multiplicity.md",
            "explanation/glossary.md",
        ],
    ],
)

deploydocs(
    repo      = "github.com/glwhart/Enumlib.jl",
    devbranch = "main",
    devurl    = "dev",
    target    = "build",
    branch    = "gh-pages",
    versions  = ["stable" => "v^"],
)
