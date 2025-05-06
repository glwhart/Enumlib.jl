using Revise
using LatticeEnumeration2D
using Test

@testset "LE" begin
    A_tri = [1 .5; 0 sqrt(3)/2]
    G_tri =  [[1 0; 0 1],[0 -1; 1 1],[0 1; 1 0],[-1 -1; 1 0],[-1 0; 1 1],[-1 0; 0 -1],[-1 -1; 0 1],[0 1; -1 -1],[0 -1; -1 0],[1 1; -1 0],[1 0; -1 -1],[1 1; 0 -1]]


    @testset "genHNFs" begin
        @test genHNFs(0) == []
        @test genHNFs(1) == [[1 0; 0 1]]
        @test genHNFs(2) == [[1 0; 0 2], [1 0; 1 2], [2 0; 0 1]]
        @test length(genHNFs(100)) == 217
    end

    @testset "isequivbases" begin
        @test isequivbases([1 0; 0 1], [1 0; 0 1], G_tri) #same
        @test !isequivbases([1 0; 0 1], [1 0; 0 2], G_tri) #diff n
        @test isequivbases([1 0; 0 2], [2 0; 0 1], G_tri) #
        @test isequivbases([0 1; 1 0], [1 0; 0 1], G_tri) # Exchange columns
        @test isequivbases([-1 0; 0 -1], [1 0; 0 1], G_tri) #inversion
        @test isequivbases([0 -1; 1 1], [1 0; 0 1], G_tri) #rotation
        @test !isequivbases([1 0; 0 4], [2 0; 0 2], G_tri)
        
    end
    
    @testset "getinequivHNFs" begin
        @test getinequivHNFs(0, G_tri) == []
        @test getinequivHNFs(1, G_tri) == [[1 0; 0 1]]
        @test getinequivHNFs(2, G_tri) == [[1 0; 0 2]]
        @test getinequivHNFs(3, G_tri, false) == [[1 0; 0 3],[1 0 ; 1 3]]
        @test getinequivHNFs(3, G_tri, true) == [[1 0; 0 3],[1 -2 ; 1 1]]
    
    end

    @testset "SuperTile" begin
        HNF = [2 0; 0 2]
        ST = SuperTile(HNF)
        @test ST.HNF == HNF
        @test ST.n == 4
        @test ST.SNF == [2, 2]
        @test ST.gPts == [[0, 0], [0, 1], [1, 0], [1,1]]
    end

    @testset "convertGtoOrd" begin
        ST = SuperTile([2 0; 1 2])
        @test convertGtoOrd([0,0], ST) == 1
        @test convertGtoOrd([0,1], ST) == 2
        @test convertGtoOrd([0,2], ST) == 3
        @test convertGtoOrd([0,3], ST) == 4
        @test convertGtoOrd([0,4], ST) == 1
        @test convertGtoOrd([1,0], ST) == 1
        @test convertGtoOrd([-3,-6], ST) == 3

        ST = SuperTile([1 0; 0 1])
        @test convertGtoOrd([0,0], ST) == 1
        @test convertGtoOrd([0,1], ST) == 1
        @test convertGtoOrd([1,0], ST) == 1
        @test convertGtoOrd([1,1], ST) == 1

        ST = SuperTile([2 0; 0 2])
        @test convertGtoOrd([0,0], ST) == 1
        @test convertGtoOrd([0,1], ST) == 2
        @test convertGtoOrd([1,0], ST) == 3
        @test convertGtoOrd([1,1], ST) == 4
        @test convertGtoOrd([1,2], ST) == 3
        @test convertGtoOrd([-2,0], ST) == 1
    end

    @testset "convertCarttoG" begin
        ST = SuperTile([1 0; 0 1])
        @test convertCarttoG([0,0], ST, A_tri) == [0, 0]
        @test convertCarttoG([0,1], ST, A_tri) == [0, 0]
        @test convertCarttoG([1,0], ST, A_tri) == [0, 0]
        @test convertCarttoG([-1,-1], ST, A_tri) == [0, 0]
    
        ST = SuperTile([2 0; 0 2])
        @test convertCarttoG([0,0], ST, A_tri) == [0, 0]
        @test convertCarttoG([1,0], ST, A_tri) == [1, 0]
        @test convertCarttoG([.5,√3/2], ST, A_tri) == [0, 1]
        @test convertCarttoG([1.5,√3/2], ST, A_tri) == [1, 1]
        @test convertCarttoG([0,-√3], ST, A_tri) == [1, 0]
    
        ST = SuperTile([2 0; 1 2])
        @test convertCarttoG([0,0], ST, A_tri) == [0, 0]
        @test convertCarttoG([1.5,√3/2], ST, A_tri) == [0, 1]
        @test convertCarttoG([3,√3], ST, A_tri) == [0, 2]
        @test convertCarttoG([4/5,3√3/2], ST, A_tri) == [0, 3]
    end


    @testset "gettransgroup" begin
        @test gettransgroup(SuperTile([1 0; 0 1])) == [[1]]
        @test gettransgroup(SuperTile([1 0; 0 2])) == [[1,2],[2,1]]
        @test gettransgroup(SuperTile([1 0; 0 3])) == [[1,2,3],[2,3,1],[3,1,2]]
        @test gettransgroup(SuperTile([2 0; 0 2])) == [[1,2,3,4],[2,1,4,3],[3,4,1,2],[4,3,2,1]]
        @test gettransgroup(SuperTile([2 0; 1 2])) == [[1,2,3,4],[2,3,4,1],[3,4,1,2],[4,1,2,3]]
        @test length(gettransgroup(SuperTile([30 0; 7 50]))) == 1500
    end


    @testset "getrotationgroup" begin
        @test getrotationgroup(SuperTile([1 0; 0 1]),G_tri) == [[1]]
        @test getrotationgroup(SuperTile([1 0; 0 2]),G_tri) == [[1,2]]
        @test getrotationgroup(SuperTile([1 0; 0 3]),G_tri) == [[1,2,3],[1,3,2]]
        @test getrotationgroup(SuperTile([2 0; 0 2]),G_tri) == [[1,2,3,4],[1,4,2,3],[1,3,2,4],[1,3,4,2,],[1,2,4,3],[1,4,3,2]]
        @test getrotationgroup(SuperTile([2 0; 1 2]),G_tri) == [[1,2,3,4],[1,4,3,2]]
    end


    @testset "genallcolorings" begin
        @test genallcolorings(1,1) == [[1]]
        @test genallcolorings(2,1) == [[1, 1]]
        @test genallcolorings(1,2) == [[1], [2]]
        @test genallcolorings(2,2) == [[1, 1], [1, 2], [2, 1], [2, 2]]
        @test genallcolorings(3,2) == [[1, 1, 1], [1, 1, 2], [1, 2, 1], [1, 2, 2], [2, 1, 1], [2, 1, 2], [2, 2, 1], [2, 2, 2]]
        @test genallcolorings(3,3) == [[1, 1, 1], [1, 1, 2], [1, 1, 3], [1, 2, 1], [1, 2, 2], [1, 2, 3], [1, 3, 1], [1, 3, 2], [1, 3, 3], [2, 1, 1], [2, 1, 2], [2, 1, 3], [2, 2, 1], [2, 2, 2], [2, 2, 3], [2, 3, 1], [2, 3, 2], [2, 3, 3], [3, 1, 1], [3, 1, 2], [3, 1, 3], [3, 2, 1], [3, 2, 2], [3, 2, 3], [3, 3, 1], [3, 3 ,2],[3 ,3 ,3]]
        @test length(genallcolorings(5,4)) == 4^5
    end


    @testset "removesuperperiodic" begin
        ST = SuperTile([1 0; 0 1])
        @test removesuperperiodic([[1], [1]], ST) == [[1],[1]]

        ST = SuperTile([1 0; 0 2])
        @test removesuperperiodic([[1,2], [1,1], [2,2], [3,2]], ST) == [[1,2], [3,2]]

        ST = SuperTile([2 0; 0 2])
        @test removesuperperiodic([[1,2,3,4], [1,1,1,1], [2,2,1,1], [1,2,1,2], [1,1,1,2]], ST) == [[1,2,3,4],[1,1,1,2]]
    end


    @testset "reducecolorings" begin
        @test reducecolorings([[1,1],[1,2],[2,1],[1,2]], SuperTile([1 0; 0 2]), G_tri) == [[1,2]]
        @test reducecolorings([[1,1,1,1],[1,2,1,2],[1,1,1,2],[2,1,1,1],[2,1,1,2],[1,1,1,2]], SuperTile([2 0; 0 2]), G_tri) == [[1,1,1,2]]
    end

end