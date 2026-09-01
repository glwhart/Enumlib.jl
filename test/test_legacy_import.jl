@testset "LegacyImport (chunk 13b.1)" begin
    # The shim wraps each legacy I/O symbol with Base.depwarn at call time.
    # Two assertions: (1) the symbol is reachable through the submodule;
    # (2) calling it through the submodule emits a depwarn.

    @testset "all legacy symbols reachable through Enumlib.LegacyImport" begin
        # v0.3-prep: the radius-based enumeration symbols (radiusEnumHNFs,
        # getHNFColorings, radEnumByXcellRadius, getSymInequivHNFsByCellRadius,
        # estimatedTime) were removed when src/radiusEnumeration.jl was retired
        # in favor of `enumerate_structures(..., supercells = RadiusBound(...))` and the
        # legacy `getPermG(h, fixingOps, LG::Vector{Matrix{Int}})` method was
        # dropped. Only the Fortran-format I/O symbols remain in the shim.
        for fn in (:enumStr, :readStructenumout, :readEnergies, :readStrIn)
            @test isdefined(Enumlib.LegacyImport, fn)
            @test getfield(Enumlib.LegacyImport, fn) isa Function
        end
    end

    @testset "depwarn emitted on call" begin
        # Use readEnergies — fails fast on a nonexistent file but emits the
        # depwarn before the I/O attempt. Run with --depwarn=error so the
        # warning becomes a catchable exception (matches CI's depwarn policy).
        cmd = `$(Base.julia_cmd()) --depwarn=error --project=$(dirname(@__DIR__)) -e "
            using Enumlib
            try
                Enumlib.LegacyImport.readEnergies(\"/nonexistent/file\")
            catch e
                e isa ErrorException && contains(e.msg, \"deprecated\") || rethrow()
                exit(0)
            end
            exit(1)"`
        @test success(cmd)
    end
end
