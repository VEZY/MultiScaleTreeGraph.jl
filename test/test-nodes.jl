
# Create a node:

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    @test get_attributes(mtg) == []
    @test mtg.attributes == Dict{Symbol,Any}()
    @test mtg.id == 1
    @test mtg.parent === nothing
    @test mtg.MTG == mtg_code
end

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    internode = MultiScaleTreeGraph.Node(
        mtg,
        MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2)
    )
    @test internode.parent == mtg
    @test internode.id == 2
    @test internode.MTG == MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2)
    @test internode.attributes == Dict{Symbol,Any}()
    @test mtg.children == [internode]
end

# From a file:
mtg = read_mtg("files/simple_plant.mtg")

@testset "names" begin
    @test sort!(get_attributes(mtg)) == [:Length, :Width, :XEuler, :dateDeath, :description, :isAlive, :scales, :symbols]
    @test names(mtg) == get_attributes(mtg)
    @test names(DataFrame(mtg))[8:end] == string.(names(mtg))
end


@testset "get attribute value" begin
    @test mtg[1][1][1][:Width] == 0.02
    @test mtg[1][1][1].attributes[:Width] == 0.02
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
