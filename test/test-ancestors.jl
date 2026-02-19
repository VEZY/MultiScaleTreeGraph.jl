@testset "ancestors" begin
    mtg = read_mtg("files/simple_plant.mtg")
    width_all = [nothing, nothing, nothing, 0.02, 0.1, 0.02, 0.1] # from print(descendants(mtg, :Width, self = true))

    # Using a leaf node from the mtg:
    leaf_node = get_node(mtg, 5)

    if Base.JLOptions().depwarn == 0
        @test ancestors(leaf_node, :Width; type=Union{Nothing,Float64}) == reverse(width_all[1:4])
    else
        @test_logs (:warn, r"Keyword argument `type` in `ancestors` is deprecated") ancestors(leaf_node, :Width; type=Union{Nothing,Float64})
    end
    @test ancestors(leaf_node, :Width) == reverse(width_all[1:4])

    d = ancestors(leaf_node, :Width, scale=3)
    @test typeof(d) == Vector{Union{Nothing,Float64}}
    @test length(d) == 1
    @test d[1] == width_all[4]
    @test typeof(ancestors(leaf_node, :Width)) == Vector{Union{Nothing,Float64}}
    d_symbol = ancestors(leaf_node, :Width, symbol=("Leaf", "Internode"))
    @test d_symbol == width_all[[4]]
    @test typeof(d_symbol) == Vector{Union{Nothing,Float64}}
    @test typeof(ancestors(leaf_node, :Width, ignore_nothing=true)) == Vector{Float64}

    @test ancestors(leaf_node, :Width, symbol=("Leaf", "Internode"), self=true) ==
          width_all[end:-1:end-1]

    buf_vals = Union{Nothing,Float64}[]
    @test ancestors!(buf_vals, leaf_node, :Width) == reverse(width_all[1:4])
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
