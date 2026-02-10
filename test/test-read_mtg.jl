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
    @test typeof(mtg) == Node{NodeMTG,MutableNamedTuple}
    @test node_id(mtg) == 1
    @test node_attributes(mtg)[:scales] == [0, 1, 2, 3, 3]
    @test node_attributes(mtg)[:symbols] == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test node_mtg(mtg) == NodeMTG("/", "Scene", 0, 0)
    @test typeof(children(mtg)) <: Vector{Node{NodeMTG,MutableNamedTuple}}
    @test typeof(mtg[1]) == Node{NodeMTG,MutableNamedTuple}
    @test node_id(mtg[1]) == 2
    @test parent(mtg[1]) === mtg

    leaf_1 = get_node(mtg, 5)
    @test leaf_1[:Length] == 0.2
    @test leaf_1[:Width] == 0.1
    @test leaf_1[:isAlive] == false
    @test leaf_1[:dateDeath] == Date("2022-08-24")

    leaf_2 = get_node(mtg, 7)
    @test leaf_2[:Length] == 0.2
    @test leaf_2[:Width] == 0.1
    @test leaf_2[:isAlive] == true

    Internode_2 = get_node(mtg, 6)
    @test Internode_2[:Length] == 0.1
    @test Internode_2[:Width] == 0.02
    @test Internode_2[:isAlive] == true
end

@testset "test mtg mutation" begin
    @test (node_attributes(mtg)[:scales] .= [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test MultiScaleTreeGraph.node_mtg!(mtg, MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)) == MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)
    reparent!(mtg[1], nothing)
    @test parent(mtg[1]) === nothing
    node2 = mtg[1]
    rechildren!(mtg, [node2])
    @test children(mtg) == [node2]
end

@testset "test mtg with NamedTuples" begin
    mtg = read_mtg("files/simple_plant.mtg", NamedTuple, NodeMTG)

    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,NamedTuple}
    @test node_id(mtg) == 1
    @test node_mtg(mtg) == MultiScaleTreeGraph.NodeMTG(:/, :Scene, 0, 0)
    @test typeof(children(mtg)) == Vector{Node{NodeMTG,NamedTuple}}
    @test node_id(mtg[1]) == 2
    @test parent(mtg[1]) === mtg
end

@testset "test mtg with Dict" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict, NodeMTG)
    @test length(mtg) == 7
    @test typeof(mtg) == Node{MultiScaleTreeGraph.NodeMTG,Dict{Symbol,Any}}
    @test node_id(mtg) == 1
    @test node_attributes(mtg) == Dict(:symbols => ["Scene", "Individual", "Axis", "Internode", "Leaf"],
        :scales => [0, 1, 2, 3, 3], :description => mtg[:description])
    @test node_mtg(mtg) == MultiScaleTreeGraph.NodeMTG(:/, :Scene, 0, 0)
    @test typeof(children(mtg)) == Vector{Node{NodeMTG,Dict{Symbol,Any}}}
    @test node_id(mtg[1]) == 2
    @test parent(mtg[1]) === mtg
end

@testset "test mtg with Dict: mutation" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict, NodeMTG)
    @test (node_attributes(mtg)[:scales] = [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test MultiScaleTreeGraph.node_mtg!(mtg, MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)) == MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)
    reparent!(mtg[1], nothing)
    @test parent(mtg[1]) === nothing
    node2 = mtg[1]
    rechildren!(mtg, [node2])
    @test children(mtg) == [node2]
end


@testset "test mtg with empty lines" begin
    mtg = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-blanks.mtg")

    MTG1 = traverse(mtg) do x
        (node_mtg(x), node_attributes(x))
    end

    MTG2 = traverse(mtg2) do x
        (node_mtg(x), node_attributes(x))
    end

    @test MTG1 == MTG2
end

@testset "mtg with several nodes in the same line" begin
    mtg = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-P1U1.mtg")

    MTG1 = traverse(mtg) do x
        (node_mtg(x), node_attributes(x))
    end

    MTG2 = traverse(mtg2) do x
        (node_mtg(x), node_attributes(x))
    end

    @test MTG1 == MTG2
end


@testset "mtg with no attributes" begin
    mtg = read_mtg("files/palm.mtg")

    @test names(mtg) == [:scales, :description, :symbols]

    traverse(mtg) do x
        !MultiScaleTreeGraph.isroot(x) && @test node_attributes(x) == Dict{Symbol,Any}()
    end
end
