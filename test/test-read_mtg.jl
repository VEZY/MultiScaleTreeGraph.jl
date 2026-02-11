mtg = read_mtg("files/simple_plant.mtg", NodeMTG)
classes = get_classes(mtg)
features = get_features(mtg)

@testset "test classes" begin
    @test typeof(classes) == DataFrame
    @test size(classes) == (5, 5)
    @test String.(classes.SYMBOL) == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test classes.SCALE == [0, 1, 2, 3, 3]
end

@testset "test features" begin
    @test typeof(features) == DataFrame
    @test size(features) == (5, 2)
    @test sort(collect(features.NAME)) == sort([:Length, :Width, :XEuler, :dateDeath, :isAlive])
end

@testset "test mtg content" begin
    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,MultiScaleTreeGraph.ColumnarAttrs}
    @test node_id(mtg) == 1
    @test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs
    @test mtg[:scales] == [0, 1, 2, 3, 3]
    @test mtg[:symbols] == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test node_mtg(mtg) == NodeMTG("/", "Scene", 0, 0)
    @test typeof(children(mtg)) <: Vector{Node{NodeMTG,MultiScaleTreeGraph.ColumnarAttrs}}

    leaf_1 = get_node(mtg, 5)
    @test leaf_1[:Length] == 0.2
    @test leaf_1[:Width] == 0.1
    @test leaf_1[:isAlive] == false
    @test leaf_1[:dateDeath] == Date("2022-08-24")
end

@testset "test mtg mutation" begin
    @test (mtg[:scales] .= [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test MultiScaleTreeGraph.node_mtg!(mtg, MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)) == MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)
    reparent!(mtg[1], nothing)
    @test parent(mtg[1]) === nothing
end

@testset "test mtg with empty lines" begin
    mtg1 = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-blanks.mtg")
    @test traverse(mtg1, node_mtg) == traverse(mtg2, node_mtg)
    @test traverse(mtg1, n -> Dict(pairs(node_attributes(n)))) == traverse(mtg2, n -> Dict(pairs(node_attributes(n))))
end

@testset "mtg with several nodes in the same line" begin
    mtg1 = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-P1U1.mtg")
    @test traverse(mtg1, node_mtg) == traverse(mtg2, node_mtg)
    @test traverse(mtg1, n -> Dict(pairs(node_attributes(n)))) == traverse(mtg2, n -> Dict(pairs(node_attributes(n))))
end

@testset "mtg with no attributes" begin
    mtg = read_mtg("files/palm.mtg")
    @test names(mtg) == [:scales, :description, :symbols]
    traverse(mtg) do x
        !MultiScaleTreeGraph.isroot(x) && @test isempty(node_attributes(x))
    end
end
