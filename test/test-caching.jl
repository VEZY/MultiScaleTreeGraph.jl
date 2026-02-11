file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

@testset "caching" begin
    mtg = read_mtg(file)

    # Cache all leaf nodes:
    cache_nodes!(mtg, symbol=:Leaf)

    # Cached nodes are stored in the traversal_cache field of the mtg (here, the two leaves):
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_78a6583f9e4f630383e9f8bdcd9d1bc5d1a6e540"] == [get_node(mtg, 5), get_node(mtg, 7)]
    # cache_nodes!(mtg, is_leaf)
    @test traverse(mtg, symbol, symbol=:Leaf) == [:Leaf, :Leaf]

    # Modifying the mtg via the cache:
    traverse!(mtg, symbol=:Leaf) do x
        x[:x] = node_id(x)
    end
    @test [get_node(mtg, 5)[:x], get_node(mtg, 7)[:x]] == [5, 7]

    # Cache based on another symbol:
    cache_nodes!(mtg, symbol=:Internode)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 2
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_8b5413ba4d893f432a65c83e5bd53e5839e22a5d"]) == 2
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_8b5413ba4d893f432a65c83e5bd53e5839e22a5d"] == [get_node(mtg, 4), get_node(mtg, 6)]

    # Cache all nodes:
    cache_nodes!(mtg)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 3
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ab6319555fc952f43d7d80401e3f1f6124fd6644"]) == length(mtg)

    # Cache with 2 filters:
    cache_nodes!(mtg, symbol=:Internode, link=:<)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 4
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ede6d4d594437acaca56712d385c03e014ff1b4b"]) == 1
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ede6d4d594437acaca56712d385c03e014ff1b4b"] == [get_node(mtg, 6)]

    traverse!(mtg, symbol=:Internode, link=:<) do x
        x[:x] = node_id(x) + 2
    end
    @test get_node(mtg, 6)[:x] == (get_node(mtg, 6) |> node_id) + 2
    @test get_node(mtg, 6)[:x] == 8

    # Re-setting the :x attribute to the node id:
    traverse!(mtg) do x
        x[:x] = node_id(x)
    end
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]

    # Manually put a node in the cache and use it for computation:
    # Carefull, this is just for testing purpose, it is not recommended to do this in a real case.
    no_filter_cache_name = MultiScaleTreeGraph.cache_name(nothing, nothing, nothing, true, nothing)
    MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name] = [MultiScaleTreeGraph.Node(MutableNodeMTG(:/, :Test, 1, 0), Dict{Symbol,Any}(:a => 1))]

    # Test if the cache is used:
    traverse!(mtg) do x
        x[:x] = node_id(x) + 4
    end
    # NB: if the cache is used here, it will only compute for the node we just created instead
    # of all the nodes in the mtg.

    # Check that the node in the cache was modified:
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name][1][:x] == node_id(MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name][1]) + 4

    # Check that the nodes of the MTG where not modified:
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]
end
