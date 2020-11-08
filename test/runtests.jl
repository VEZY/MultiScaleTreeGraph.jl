using MTG
using DataFrames
using Test

@testset "read_mtg" begin
    mtg,classes,description,features = read_mtg("files/simple_plant.mtg");
    @test length(mtg) == 7

    @testset "test classes" begin
        @test typeof(classes) == DataFrame
        @test size(classes) == (5,5)
        @test String.(classes.SYMBOL) == ["\$","Individual","Axis","Internode","Leaf"]
        @test classes.SCALE == [0,1,2,3,3]
        @test classes.DECOMPOSITION == ["FREE" for i in 1:5]
        @test classes.INDEXATION == ["FREE" for i in 1:5]
        @test classes.DEFINITION == ["IMPLICIT" for i in 1:5]
    end
    
    @testset "test description" begin
        @test typeof(description) == DataFrame
        @test size(description) == (2,4)
        @test description.LEFT == ["Internode","Internode"]
        @test description.RELTYPE == ["+","<"]
        @test description.MAX == ["?","?"]
    end

    @testset "test features" begin
        @test typeof(features) == DataFrame
        @test size(features) == (7,2)
        @test features.NAME == ["XX","YY","ZZ","FileName","Length","Width","XEuler"]
        @test features.TYPE == ["REAL","REAL","REAL","ALPHA","ALPHA","ALPHA","REAL"]
    end
end

@testset "descendants" begin
    mtg,classes,description,features = read_mtg("files/simple_plant.mtg");
    @test descendants(mtg, :Width, Union{Nothing,Float64}) ==  [nothing,nothing,1.0,6.0,nothing,7.0]
end
