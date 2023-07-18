@testset "mutate_node!" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    # Using a leaf node from the mtg:
    leaf_node = mtg.children[1].children[1].children[1].children[1]
    # Add a new attributes, x based on node field, y based on x and z using a function:
    @mutate_node!(mtg, x = length(node.name), y = node.x + 2, z = sum(node.y))
    @test mtg[:x] == 6
    @test mtg[:y] == mtg[:x] + 2
    @test mtg[:z] == sum(mtg[:y])

    # Same on a leaf:
    @mutate_node!(leaf_node, x = length(node.name), y = node.x + 3, z = sum(node.y))
    @test leaf_node[:x] == 6
    @test leaf_node[:y] == leaf_node[:x] + 3
    @test leaf_node[:z] == sum(leaf_node[:y])

    # Test by using node[:variable] format:
    @mutate_node!(leaf_node, node[:test] = node[:y])
    @test leaf_node[:test] == leaf_node[:y]

    # Test by using node fields instead of attributes:
    @mutate_node!(leaf_node, node.MTG.scale = 4)
    @test leaf_node.MTG.scale == 4
end


@testset "mutate_mtg!" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    # Using a leaf node from the mtg:
    leaf_node = mtg.children[1].children[1].children[1].children[1]

    # Add a new attribute based on the name:
    @mutate_mtg!(mtg, nametest = node.name * "_test")
    @test mtg[:nametest] == "node_1_test"
    @test leaf_node[:nametest] == "node_5_test"

    # Mutate with a filter:
    @mutate_mtg!(mtg, nametest = node.name * "_test2", scale = 3)
    @test mtg[:nametest] == "node_1_test"
    @test leaf_node[:nametest] == "node_5_test2"
end

@testset "append!" begin
    # On Dict attributes
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    append!(mtg, (test=3,))

    @test haskey(mtg.attributes, :test)
    @test mtg[:test] == 3

    # On MutableNamedTuple attributes
    mtg = read_mtg("files/simple_plant.mtg", MutableNamedTuple)
    # Using a leaf node from the mtg:
    append!(mtg, (test=3,))
    @test :test in keys(mtg.attributes)
    @test mtg[:test] == 3

    # On NamedTuple attributes
    mtg = read_mtg("files/simple_plant.mtg", NamedTuple)
    # Using a leaf node from the mtg:
    append!(mtg, (test=3,))
    @test :test in keys(mtg.attributes)
    @test mtg[:test] == 3
end

@testset "pop!" begin
    # On Dict attributes
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    pop!(mtg, :symbols)
    @test !haskey(mtg.attributes, :symbols)

    # On MutableNamedTuple attributes
    mtg = read_mtg("files/simple_plant.mtg", MutableNamedTuple)
    # Using a leaf node from the mtg:
    pop!(mtg, :symbols)
    @test !(:symbols in keys(mtg.attributes))

    # On NamedTuple attributes
    mtg = read_mtg("files/simple_plant.mtg", NamedTuple)
    # Using a leaf node from the mtg:
    pop!(mtg, :symbols)
    @test !(:symbols in keys(mtg.attributes))
end
