mtg = read_mtg("files/simple_plant.mtg", MutableNamedTuple, NodeMTG);
classes = get_classes(mtg)
features = get_features(mtg)

@testset "test classes" begin
    @test typeof(classes) == DataFrame
    @test size(classes) == (5, 5)
    @test String.(classes.SYMBOL) == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
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
    @test size(features) == (5, 2)
    @test features.NAME == [:Length, :Width, :XEuler, :dateDeath, :isAlive]
    @test features.TYPE == ["REAL", "REAL", "REAL", "DD/MM/YY", "BOOLEAN"]
end

@testset "test mtg content" begin
    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,MutableNamedTuple,MultiScaleTreeGraph.GenericNode}
    @test mtg.name == "node_1"
    @test mtg.attributes[:scales] == [0, 1, 2, 3, 3]
    @test mtg.attributes[:symbols] == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test mtg.MTG == NodeMTG("/", "Scene", 0, 0)
    @test typeof(mtg.children) == Vector{Node}
    @test typeof(mtg[1]) == Node{NodeMTG,MutableNamedTuple,MultiScaleTreeGraph.GenericNode}
    @test mtg[1].name == "node_2"
    @test mtg[1].parent === mtg

    leaf_1 = get_node(mtg, 5)
    @test leaf_1[:Length] === 0.2
    @test leaf_1[:Width] === 0.1
    @test leaf_1[:isAlive] === false
    @test leaf_1[:dateDeath] === Date("2022-08-24")

    leaf_2 = get_node(mtg, 7)
    @test leaf_2[:Length] === 0.2
    @test leaf_2[:Width] === 0.1
    @test leaf_2[:isAlive] === true

    Internode_2 = get_node(mtg, 6)
    @test Internode_2[:Length] === 0.1
    @test Internode_2[:Width] === 0.02
    @test Internode_2[:isAlive] === true
end

@testset "test mtg mutation" begin
    @test (mtg.name = "first_node") == "first_node"
    @test (mtg.attributes[:scales] .= [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test (mtg.MTG = MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)) == MultiScaleTreeGraph.NodeMTG("<", "Leaf", 2, 0)
    @test (mtg[1].parent = nothing) === nothing
    node2 = mtg[1]
    @test (mtg.children = nothing) === nothing
    @test (mtg.children = [node2]) == [node2]
    mtg.attributes = MutableNamedTuple(a=1)
end

@testset "test mtg with NamedTuples" begin
    mtg = read_mtg("files/simple_plant.mtg", NamedTuple, NodeMTG)

    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,NamedTuple,MultiScaleTreeGraph.GenericNode}
    @test mtg.name == "node_1"
    @test mtg.MTG == MultiScaleTreeGraph.NodeMTG("/", "Scene", 0, 0)
    @test typeof(mtg.children) == Vector{Node}
    @test mtg[1].name == "node_2"
    @test mtg[1].parent === mtg
end


@testset "test mtg with Dict" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict, NodeMTG)
    @test length(mtg) == 7
    @test typeof(mtg) == Node{MultiScaleTreeGraph.NodeMTG,Dict{Symbol,Any},MultiScaleTreeGraph.GenericNode}
    @test mtg.name == "node_1"
    @test mtg.attributes == Dict(:symbols => ["Scene", "Individual", "Axis", "Internode", "Leaf"],
        :scales => [0, 1, 2, 3, 3], :description => mtg[:description])
    @test mtg.MTG == MultiScaleTreeGraph.NodeMTG("/", "Scene", 0, 0)
    @test typeof(mtg.children) == Vector{Node}
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
    @test (mtg.children = [node2]) == [node2]
    mtg.attributes = Dict(:a => 3, :b => "test")
end


@testset "test mtg with empty lines" begin
    mtg = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-blanks.mtg")

    MTG1 = traverse(mtg) do x
        (x.MTG, x.attributes)
    end

    MTG2 = traverse(mtg2) do x
        (x.MTG, x.attributes)
    end

    @test MTG1 == MTG2
end

@testset "mtg with several nodes in the same line" begin
    mtg = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-P1U1.mtg")

    MTG1 = traverse(mtg) do x
        (x.MTG, x.attributes)
    end

    MTG2 = traverse(mtg2) do x
        (x.MTG, x.attributes)
    end

    @test MTG1 == MTG2
end


@testset "mtg with no attributes" begin
    mtg = read_mtg("files/palm.mtg")

    @test names(mtg) == [:scales, :description, :symbols]

    traverse(mtg) do x
        !MultiScaleTreeGraph.isroot(x) && @test x.attributes == Dict{Symbol,Any}()
    end
end
