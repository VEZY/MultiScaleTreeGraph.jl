

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
