file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

@testset "caching" begin
    mtg = read_mtg(file, Dict)

    # Cache all leaf nodes:
    cache_nodes!(mtg, symbol="Leaf")

    # Cached nodes are stored in the traversal_cache field of the mtg (here, the two leaves):
    @test mtg.traversal_cache["_cache_c0bffb8cc8a9b075e40d26be9c2cac6349f2a790"] == [get_node(mtg, 5), get_node(mtg, 7)]
    # cache_nodes!(mtg, is_leaf)
    @test traverse(mtg, x -> x.MTG.symbol, symbol="Leaf") == ["Leaf", "Leaf"]

    # Modifying the mtg via the cache:
    traverse!(mtg, symbol="Leaf") do x
        x[:x] = x.id
    end
    @test [get_node(mtg, 5)[:x], get_node(mtg, 7)[:x]] == [5, 7]

    # Cache based on another symbol:
    cache_nodes!(mtg, symbol="Internode")
    @test length(mtg.traversal_cache) == 2
    @test length(mtg.traversal_cache["_cache_33a9899b1adef0158fa8f2ffa2f898013767bd79"]) == 2
    @test mtg.traversal_cache["_cache_33a9899b1adef0158fa8f2ffa2f898013767bd79"] == [get_node(mtg, 4), get_node(mtg, 6)]

    # Cache all nodes:
    cache_nodes!(mtg)
    @test length(mtg.traversal_cache) == 3
    @test length(mtg.traversal_cache["_cache_b47facf6c998e6f1b7dc7c83eebde8b80e39506d"]) == length(mtg)

    # Cache with 2 filters:
    cache_nodes!(mtg, symbol="Internode", link="<")
    @test length(mtg.traversal_cache) == 4
    @test length(mtg.traversal_cache["_cache_4b683925f7df64387dff8c1af7aaec36c5fd3d35"]) == 1
    @test mtg.traversal_cache["_cache_4b683925f7df64387dff8c1af7aaec36c5fd3d35"] == [get_node(mtg, 6)]

    traverse!(mtg, symbol="Internode", link="<") do x
        x[:x] = x.id + 2
    end
    @test get_node(mtg, 6)[:x] == get_node(mtg, 6).id + 2
    @test get_node(mtg, 6)[:x] == 8

    # Re-setting the :x attribute to the node id:
    traverse!(mtg) do x
        x[:x] = x.id
    end
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]

    # Manually put a node in the cache and use it for computation:
    # Carefull, this is just for testing purpose, it is not recommended to do this in a real case.
    no_filter_cache_name = MultiScaleTreeGraph.cache_name(nothing, nothing, nothing, nothing)
    mtg.traversal_cache[no_filter_cache_name] = [MultiScaleTreeGraph.Node(NodeMTG("/", "Test", 1, 0), Dict(:a => 1))]

    # Test if the cache is used:
    traverse!(mtg) do x
        x[:x] = x.id + 4
    end
    # NB: if the cache is used here, it will only compute for the node we just created instead
    # of all the nodes in the mtg.

    # Check that the node in the cache was modified:
    @test mtg.traversal_cache[no_filter_cache_name][1][:x] == mtg.traversal_cache[no_filter_cache_name][1].id + 4

    # Check that the nodes of the MTG where not modified:
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]
end