mtg = read_mtg("files/simple_plant.mtg");

@testset "getting scales" begin
    @test scales(mtg) == [0, 1, 2, 3]
    @test symbols(mtg) == components(mtg) == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
end

@testset "test classes" begin
    classes = get_classes(mtg)
    @test typeof(classes) == DataFrame
    @test size(classes) == (5, 5)
    @test String.(classes.SYMBOL) == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test classes.SCALE == [0, 1, 2, 3, 3]
    @test classes.DECOMPOSITION == ["FREE" for i = 1:5]
    @test classes.INDEXATION == ["FREE" for i = 1:5]
    @test classes.DEFINITION == ["IMPLICIT" for i = 1:5]
end

@testset "test description" begin
    @test get_description(mtg) === nothing
    @test typeof(mtg[:description]) == DataFrame
    @test size(mtg[:description]) == (2, 4)
    @test mtg[:description].LEFT == ["Internode", "Internode"]
    @test mtg[:description].RELTYPE == ["+", "<"]
    @test mtg[:description].MAX == ["?", "?"]
end

@testset "test features" begin
    features = sort!(get_features(mtg), :NAME)
    @test typeof(features) == DataFrame
    @test size(features) == (5, 2)
    @test features.NAME == [:Length, :Width, :XEuler, :dateDeath, :isAlive]
    @test features.TYPE == ["REAL", "REAL", "REAL", "DD/MM/YY", "BOOLEAN"]
end

@testset "get attributes/names" begin
    @test get_attributes(mtg) == names(mtg) == [:scales, :description, :symbols, :XEuler, :Length, :Width, :dateDeath, :isAlive]
end

@testset "list nodes" begin
    @test list_nodes(mtg) == Any[1, 2, 3, 4, 5, 6, 7]
end

@testset "Maximum id" begin
    @test max_id(mtg) == 7
end