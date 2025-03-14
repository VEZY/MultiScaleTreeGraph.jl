# Create a node:

@testset "NodeMTG and MutableNodeMTG" begin
    # Test NodeMTG constructor with all arguments
    node_mtg = MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 2)
    @test node_mtg.link == "/"
    @test node_mtg.symbol == "Plant"
    @test node_mtg.index == 1
    @test node_mtg.scale == 2

    # Test NodeMTG constructor with nothing as index
    node_mtg_nothing = MultiScaleTreeGraph.NodeMTG("/", "Internode", nothing, 3)
    @test node_mtg_nothing.link == "/"
    @test node_mtg_nothing.symbol == "Internode"
    @test node_mtg_nothing.index == -9999
    @test node_mtg_nothing.scale == 3

    # Test MutableNodeMTG constructor with all arguments
    mutable_node_mtg = MultiScaleTreeGraph.MutableNodeMTG("+", "Leaf", 2, 4)
    @test mutable_node_mtg.link == "+"
    @test mutable_node_mtg.symbol == "Leaf"
    @test mutable_node_mtg.index == 2
    @test mutable_node_mtg.scale == 4

    # Test MutableNodeMTG constructor with nothing as index
    mutable_node_mtg_nothing = MultiScaleTreeGraph.MutableNodeMTG("<", "Apex", nothing, 5)
    @test mutable_node_mtg_nothing.link == "<"
    @test mutable_node_mtg_nothing.symbol == "Apex"
    @test mutable_node_mtg_nothing.index == -9999
    @test mutable_node_mtg_nothing.scale == 5

    # Test mutability of MutableNodeMTG
    mutable_node_mtg.link = "<"
    mutable_node_mtg.symbol = "Flower"
    mutable_node_mtg.index = 3
    mutable_node_mtg.scale = 6
    @test mutable_node_mtg.link == "<"
    @test mutable_node_mtg.symbol == "Flower"
    @test mutable_node_mtg.index == 3
    @test mutable_node_mtg.scale == 6

    # Test assertions
    @test_throws AssertionError MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, -1)  # scale < 0
    @test_throws AssertionError MultiScaleTreeGraph.NodeMTG("invalid", "Plant", 1, 1)  # invalid link
    @test_throws AssertionError MultiScaleTreeGraph.MutableNodeMTG("/", "Plant", 1, -1)  # scale < 0
    @test_throws AssertionError MultiScaleTreeGraph.MutableNodeMTG("invalid", "Plant", 1, 1)  # invalid link
end

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    @test get_attributes(mtg) == []
    @test node_attributes(mtg) == Dict{Symbol,Any}()
    @test node_id(mtg) == 1
    @test parent(mtg) === nothing
    @test node_mtg(mtg) == mtg_code
end

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    internode = MultiScaleTreeGraph.Node(
        mtg,
        MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2)
    )
    @test parent(internode) == mtg
    @test node_id(internode) == 2
    @test node_mtg(internode) == MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2)
    @test node_attributes(internode) == Dict{Symbol,Any}()
    @test children(mtg) == [internode]
end

# From a file:
file = "files/simple_plant.mtg"
mtg = read_mtg(file)

@testset "names" begin
    @test sort!(get_attributes(mtg)) == [:Length, :Width, :XEuler, :dateDeath, :description, :isAlive, :scales, :symbols]
    @test names(mtg) == get_attributes(mtg)
    @test names(DataFrame(mtg))[8:end] == string.(names(mtg))
end


@testset "get attribute value" begin
    @test mtg[1][1][1][:Width] == 0.02
    @test node_attributes(mtg[1][1][1])[:Width] == 0.02
end

@testset "set attribute value" begin
    mtg[1][1][1][:Width] = 1.0
    @test mtg[1][1][1][:Width] == 1.0
end

@testset "siblings" begin
    node = get_node(mtg, 5)
    @test nextsibling(node) == get_node(mtg, 6)
    @test prevsibling(nextsibling(node)) == node
end

@testset "getdescendant" begin
    # This is the function from AbstractTrees.jl
    AbstractTrees.getdescendant(mtg, (1, 1, 1, 2)) == get_node(mtg, 6)
end


@testset "Adding a child with a different MTG encoding type" begin
    mtg = read_mtg(file, Dict, MutableNodeMTG)
    VERSION >= v"1.7" && @test_throws "The parent node has an MTG encoding of type `MutableNodeMTG`, but the MTG encoding you provide is of type `NodeMTG`, please make sure they are the same." Node(mtg, NodeMTG("/", "Branch", 1, 2))
end

