
# Create a node:

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

