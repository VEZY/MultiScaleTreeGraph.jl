file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

@testset "delete_node!" begin
    # Delete a node:
    mtg = read_mtg(file)
    length_start = length(mtg)
    delete_node!(get_node(mtg, 3))
    @test length(mtg) == length_start - 1

    # Delete a node with two children:
    @test_logs (:warn, "Scale of the child node branched but its deleted parent was decomposing. Keep branching, please check if the decomposition is still correct.") delete_node!(get_node(mtg, 4))
    # There is a warning because we don't know how to properly link the leaf (node 5) to its new parent.

    # Furthermore, the link of the second child (node 6) was modified from following to decomposing:
    @test get_node(mtg, 6).MTG.link == "/"
end

@testset "delete_node! with a user function" begin
    mtg = read_mtg(file)
    delete_node!(get_node(mtg, 4), child_link_fun = node -> node.MTG.link)
    # The link of the children didn't change:
    @test get_node(mtg, 6).MTG.link == "<"

    delete_node!(get_node(mtg, 3), child_link_fun = node -> "+")
    # Both children links changes to branching:
    @test get_node(mtg, 5).MTG.link == "+"
    @test get_node(mtg, 6).MTG.link == "+"
end

@testset "delete_nodes!" begin
    mtg = read_mtg(file)
    length_start = length(mtg)
    delete_nodes!(mtg, scale = 2) # Will remove all nodes of scale 2
    @test get_node(mtg, 3) === nothing
    @test length(mtg) === length_start - 1

    # Delete the leaves:
    mtg = read_mtg(file)
    delete_nodes!(mtg, symbol = "Leaf")
    @test length(mtg) === length_start - 2

    # Delete with a function, here we delete all nodes that have a parent with Length < 5:
    mtg = read_mtg(file)
    delete_nodes!(
        mtg,
        filter_fun = function (node)
            if !isroot(node)
                node.parent[:Length] !== nothing ? node.parent[:Length] < 5 : false
            else
                false
            end
        end
    )
    @test length(mtg) === length_start - 2
end

@testset "prune! a node" begin
    file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

    # Prune a node in the middle:
    mtg = read_mtg(file)
    prune!(get_node(mtg, 6))
    @test length(mtg) == 5

    # Prune a leaf node:
    mtg = read_mtg(file)
    prune!(get_node(mtg, 5))
    @test length(mtg) == 6

    # Prune the root node (we expect an error):
    @test_throws ErrorException prune!(read_mtg(file))
end
