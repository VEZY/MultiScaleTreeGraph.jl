@testset "mutate_node!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    # Using a leaf node from the mtg:
    leaf_node = get_node(mtg, 5)
    # Add a new attributes, x based on node field, y based on x and z using a function:
    @mutate_node!(mtg, x = node_id(node), y = node.x + 2, z = sum(node.y))
    @test mtg[:x] == 1
    @test mtg[:y] == mtg[:x] + 2
    @test mtg[:z] == sum(mtg[:y])

    # Same on a leaf:
    @mutate_node!(leaf_node, x = node_id(node), y = node.x + 3, z = sum(node.y))
    @test leaf_node[:x] == 5
    @test leaf_node[:y] == leaf_node[:x] + 3
    @test leaf_node[:z] == sum(leaf_node[:y])

    # Test by using node[:variable] format:
    @mutate_node!(leaf_node, node[:test] = node[:y])
    @test leaf_node[:test] == leaf_node[:y]
end


@testset "mutate_mtg!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    # Using a leaf node from the mtg:
    leaf_node = get_node(mtg, 5)

    # Add a new attribute based on the id:
    @mutate_mtg!(mtg, nametest = string("node_", node_id(node), "_test"))
    @test mtg[:nametest] == "node_1_test"
    @test leaf_node[:nametest] == "node_5_test"

    # Mutate with a filter:
    @mutate_mtg!(mtg, nametest = string("node_", node_id(node), "_test2"), scale = 3)
    @macroexpand @mutate_mtg!(mtg, nametest = string("node_", node_id(node), "_test2"), scale = 3) # Only for nodes of scale = 3

    @test mtg[:nametest] == "node_1_test"
    @test leaf_node[:nametest] == "node_5_test2"
end

@testset "append!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    append!(mtg, (test=3,))

    @test haskey(mtg, :test)
    @test mtg[:test] == 3
end

@testset "pop!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    pop!(mtg, :symbols)
    @test !haskey(mtg, :symbols)
end
