@testset "ancestors" begin
    mtg = read_mtg("files/simple_plant.mtg")
    width_all = [nothing, nothing, nothing, 0.02, 0.1, 0.02, 0.1] # from print(descendants(mtg, :Width, self = true))

    # Using a leaf node from the mtg:
    leaf_node = get_node(mtg, 5)

    @test ancestors(leaf_node, :Width; type=Union{Nothing,Float64}) == reverse(width_all[1:4])
    @test ancestors(leaf_node, :Width) == reverse(width_all[1:4])

    d = ancestors(leaf_node, :Width, scale=3)
    @test typeof(d) == Vector{Any}
    @test length(d) == 1
    @test d[1] == width_all[4]
    d_typed = ancestors(leaf_node, :Width, type=Union{Nothing,Float64})
    @test typeof(d_typed) == Vector{Union{Nothing,Float64}}
    @test ancestors(leaf_node, :Width, symbol=("Leaf", "Internode")) == width_all[[4]]

    @test ancestors(leaf_node, :Width, symbol=("Leaf", "Internode"), self=true) ==
          width_all[end:-1:end-1]

    buf_vals = Union{Nothing,Float64}[]
    @test ancestors!(buf_vals, leaf_node, :Width; type=Union{Nothing,Float64}) ==
          reverse(width_all[1:4])
    @test ancestors!(buf_vals, leaf_node, :Width, symbol=("Leaf", "Internode"), self=true) ==
          width_all[end:-1:end-1]

    # Using the method that returns the nodes directly:
    @test ancestors(leaf_node) == [leaf_node |> parent, leaf_node |> parent |> parent, leaf_node |> parent |> parent |> parent, leaf_node |> parent |> parent |> parent |> parent]
    @test ancestors(leaf_node, self=true) == [leaf_node, leaf_node |> parent, leaf_node |> parent |> parent, leaf_node |> parent |> parent |> parent, leaf_node |> parent |> parent |> parent |> parent]

    buf_nodes = typeof(leaf_node)[]
    @test ancestors!(buf_nodes, leaf_node) ==
          [leaf_node |> parent, leaf_node |> parent |> parent, leaf_node |> parent |> parent |> parent, leaf_node |> parent |> parent |> parent |> parent]
    @test ancestors!(buf_nodes, leaf_node, self=true) ==
          [leaf_node, leaf_node |> parent, leaf_node |> parent |> parent, leaf_node |> parent |> parent |> parent, leaf_node |> parent |> parent |> parent |> parent]
end
