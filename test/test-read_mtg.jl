mtg = read_mtg("files/simple_plant.mtg", MutableNamedTuple, NodeMTG);
classes = get_classes(mtg)
features = get_features(mtg)

@testset "test classes" begin
    @test typeof(classes) == DataFrame
    @test size(classes) == (5, 5)
    @test String.(classes.SYMBOL) == ["\$", "Individual", "Axis", "Internode", "Leaf"]
    @test classes.SCALE == [0, 1, 2, 3, 3]
    @test classes.DECOMPOSITION == ["FREE" for i = 1:5]
    @test classes.INDEXATION == ["FREE" for i = 1:5]
    @test classes.DEFINITION == ["IMPLICIT" for i = 1:5]
end

@testset "test description" begin
    @test typeof(mtg[:description]) == DataFrame
    @test size(mtg[:description]) == (2, 4)
    @test mtg[:description].LEFT == ["Internode", "Internode"]
    @test mtg[:description].RELTYPE == ["+", "<"]
    @test mtg[:description].MAX == ["?", "?"]
end

@testset "test features" begin
    @test typeof(features) == DataFrame
    @test size(features) == (7, 2)
    @test features.NAME == [:FileName, :YY, :XX, :ZZ, :Length, :Width, :XEuler]
    @test features.TYPE == ["STRING", "REAL", "REAL", "REAL", "REAL", "REAL", "REAL"]
end

@testset "test mtg content" begin
    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,MutableNamedTuple}
    @test mtg.name == "node_1"
    @test mtg.attributes[:scales] == [0, 1, 2, 3, 3]
    @test mtg.attributes[:symbols] == ["\$", "Individual", "Axis", "Internode", "Leaf"]
    @test mtg.MTG == NodeMTG("/", "\$", 0, 0)
    @test typeof(mtg.children) == Dict{Int,Node}
    @test typeof(mtg[1]) == Node{NodeMTG,MutableNamedTuple}
    @test mtg[1].name == "node_2"
    @test mtg[1].parent === mtg
end

@testset "test mtg mutation" begin
    @test (mtg.name = "first_node") == "first_node"
    @test (mtg.attributes[:scales] .= [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test (mtg.MTG = MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)) == MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)
    @test (mtg[1].parent = nothing) === nothing
    node2 = mtg[1]
    @test (mtg.children = nothing) === nothing
    @test (mtg.children = Dict(2 => node2)) == Dict(2 => node2)
    mtg.attributes = MutableNamedTuple(a = 1)
end

@testset "test mtg with NamedTuples" begin
    mtg = read_mtg("files/simple_plant.mtg", NamedTuple, NodeMTG)

    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,NamedTuple}
    @test mtg.name == "node_1"
    @test mtg.MTG == MultiScaleTreeGraph.NodeMTG("/", "\$", 0, 0)
    @test typeof(mtg.children) == Dict{Int,Node}
    @test mtg[1].name == "node_2"
    @test mtg[1].parent === mtg
end


@testset "test mtg with Dict" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict, NodeMTG)
    @test length(mtg) == 7
    @test typeof(mtg) == Node{MultiScaleTreeGraph.NodeMTG,Dict{Symbol,Any}}
    @test mtg.name == "node_1"
    @test mtg.attributes == Dict(:symbols => ["\$", "Individual", "Axis", "Internode", "Leaf"],
        :scales => [0, 1, 2, 3, 3], :description => mtg[:description])
    @test mtg.MTG == MultiScaleTreeGraph.NodeMTG("/", "\$", 0, 0)
    @test typeof(mtg.children) == Dict{Int,Node}
    @test mtg[1].name == "node_2"
    @test mtg[1].parent === mtg
end


@testset "test mtg with Dict: mutation" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict, NodeMTG)
    @test (mtg.name = "first_node") == "first_node"
    @test (mtg.attributes[:scales] = [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test (mtg.MTG = MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)) == MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)
    @test (mtg[1].parent = nothing) === nothing
    node2 = mtg[1]
    @test (mtg.children = nothing) === nothing
    @test (mtg.children = Dict(2 => node2)) == Dict(2 => node2)
    mtg.attributes = Dict(:a => 3, :b => "test")
end
