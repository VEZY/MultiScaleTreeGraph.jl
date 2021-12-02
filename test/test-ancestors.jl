@testset "ancestors" begin
    mtg = read_mtg("files/simple_plant.mtg")
    width_all = [nothing, nothing, nothing, 1.0, 6.0, nothing, 7.0]

    # Using a leaf node from the mtg:
    leaf_node = mtg.children[2].children[3].children[4].children[5]

    @test ancestors(leaf_node, :Width; type = Union{Nothing,Float64}) == reverse(width_all[1:4])
    @test ancestors(leaf_node, :Width) == reverse(width_all[1:4])

    d = ancestors(leaf_node, :Width, scale = 3)
    @test typeof(d) == Vector{Any}
    @test length(d) == 1
    @test d[1] == width_all[4]
    d_typed = ancestors(leaf_node, :Width, type = Union{Nothing,Float64})
    @test typeof(d_typed) == Vector{Union{Nothing,Float64}}
    @test ancestors(leaf_node, :Width, symbol = ("Leaf", "Internode")) == width_all[[4]]

    @test ancestors(leaf_node, :Width, symbol = ("Leaf", "Internode"), self = true) ==
          width_all[5:-1:4]
end
