# Build the standalone `enum.x` / `polya.x` app with PackageCompiler.
#
# This is what produces the pre-compiled binaries attached to a GitHub Release:
# users (and the conda-forge feedstock) download a per-platform tarball instead of
# installing Julia and the package. Driven by .github/workflows/release.yml, which
# runs it on a clean runner per platform.
#
# Usage:
#   julia --project=build build/build_app.jl [dest_dir]
#
# Default dest_dir is "build/app". The three executables are compiled from
# `Enumlib.enum_main` / `Enumlib.polya_main` / `Enumlib.makestr_main` (src/cli.jl) —
# the same functions bin/*.jl call, so the compiled and script paths cannot diverge.
#
# Note on naming: create_app emits `enum` / `polya` / `makestr` (plus `.exe` on
# Windows). The workflow renames them to `enum.x` / `polya.x` / `makestr.x`, the
# names the Fortran enumlib used and that pymatgen's EnumlibAdaptor looks for on
# PATH. Together these are all three executables the conda-forge feedstock ships.

using PackageCompiler

const REPO_ROOT = dirname(@__DIR__)
const DEST = length(ARGS) >= 1 ? ARGS[1] : joinpath(REPO_ROOT, "build", "app")

@info "Building Enumlib.jl app" REPO_ROOT DEST VERSION Sys.MACHINE

isdir(DEST) && rm(DEST; recursive = true)

elapsed = @elapsed create_app(
    REPO_ROOT,
    DEST;
    executables = ["enum" => "enum_main", "polya" => "polya_main",
                   "makestr" => "makestr_main"],
    # Precompilation is driven by the package's own PrecompileTools workload plus
    # the smoke test below; incremental = false keeps the app self-contained.
    incremental = false,
    filter_stdlibs = false,
    # Lazy artifacts pulled in Qt, X11 and GR baggage that nothing in Enumlib's
    # dependency closure actually loads — tens of MB and 79 static libraries in
    # the v0.3.6 package. The smoke test below is what proves the app still runs
    # without them.
    include_lazy_artifacts = false,
    force = true,
)

@info "create_app finished" minutes = round(elapsed / 60; digits = 1)

# --- License text ---------------------------------------------------------------
# create_app bundles third-party artifact licenses under
# share/julia/artifacts/*/share/licenses, but not the app's own. Shipping binaries
# with no copy of their MIT text is a real distribution gap, and conda-forge's
# `license_file` additionally requires the file to exist in the source archive.
cp(joinpath(REPO_ROOT, "LICENSE"), joinpath(DEST, "LICENSE"); force = true)
write(joinpath(DEST, "NOTICE"), """
Enumlib.jl standalone application.

This bundle contains Enumlib.jl (see LICENSE, MIT) together with the Julia runtime
and the third-party libraries Julia depends on. Licenses for the bundled
components are under share/julia/artifacts/*/share/licenses/.

Source: https://github.com/glwhart/Enumlib.jl
""")

# --- Smoke test the freshly built binaries -------------------------------------
# Cheap but load-bearing: proves the app actually launches and that `--version`
# emits the exact token pymatgen's engine detection probes for. A build that
# compiles but cannot print its version is useless to us.
const EXE_SUFFIX = Sys.iswindows() ? ".exe" : ""
const BINDIR = joinpath(DEST, "bin")

# The expected version, straight from Project.toml — the built app must report
# exactly this. v0.3.4 shipped printing "(Enumlib.jl) nothing" because
# `pkgversion` returns `nothing` inside an app and the old smoke test only
# checked for the "Enumlib.jl" token, which was still present. Asserting the
# actual number is what closes that hole.
const EXPECTED_VERSION = let
    m = match(r"(?m)^version\s*=\s*\"([^\"]+)\"",
              read(joinpath(REPO_ROOT, "Project.toml"), String))
    m === nothing && error("could not read version from Project.toml")
    String(m.captures[1])
end

for (exe, label) in (("enum", "enum.x"), ("polya", "polya.x"),
                     ("makestr", "makestr.x"))
    path = joinpath(BINDIR, exe * EXE_SUFFIX)
    isfile(path) || error("expected executable not found: $path")
    out = read(`$path --version`, String)
    println("  $label --version → ", strip(out))
    occursin("Enumlib.jl", out) ||
        error("$label --version output lacks the 'Enumlib.jl' token: $(repr(out))")
    occursin(EXPECTED_VERSION, out) ||
        error("$label reported the wrong version: expected $EXPECTED_VERSION, " *
              "got $(repr(strip(out)))")
end

isfile(joinpath(DEST, "LICENSE")) || error("LICENSE missing from the app bundle")

@info "Smoke test passed" BINDIR
