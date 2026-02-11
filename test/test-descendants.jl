@testset "descendants" begin
      mtg = read_mtg("files/simple_plant.mtg")
      width_all = [nothing, nothing, 0.02, 0.1, 0.02, 0.1]
      @test descendants(mtg, :Width; type=Union{Nothing,Float64}) == width_all
      @test descendants(mtg, :Width) == width_all

      d = descendants(mtg, :Width, scale=1)
      @test typeof(d) == Vector{Any}
      @test length(d) == 1
      @test d[1] === width_all[1]
      d_typed = descendants(mtg, :Width, type=Union{Nothing,Float64})
      @test typeof(d_typed) == Vector{Union{Nothing,Float64}}
      @test descendants(mtg, :Width, symbol=(:Leaf, :Internode)) == width_all[3:end]

      mtg2 = mtg[1][1][1][2]
      @test descendants(mtg2, :Width, symbol=:Leaf)[1] == width_all[end]

      @test descendants(mtg2, :Width, symbol=(:Leaf, :Internode), self=true) ==
            width_all[end-1:end]

      out_vals = Union{Nothing,Float64}[]
      @test descendants!(out_vals, mtg, :Width) == width_all
      @test descendants!(out_vals, mtg2, :Width, symbol=(:Leaf, :Internode), self=true) ==
            width_all[end-1:end]

      # Using the mutating version:
      @test descendants!(mtg, :Width) == descendants(mtg, :Width)
      @test descendants!(mtg2, :Width, symbol=(:Leaf, :Internode), self=true) ==
            width_all[end-1:end]

      clean_cache!(mtg)
      # Get the leaves values:
      @test descendants(mtg, :Width; filter_fun=isleaf) == width_all[[end - 2, end]]

      # Using the method that returns the nodes directly:
      @test descendants(mtg) == traverse(mtg[1], x -> x)
      @test descendants(mtg, self=true) == traverse(mtg, x -> x)
      @test descendants(get_node(mtg, 6), self=true) == [get_node(mtg, 6), get_node(mtg, 7)]

      out_nodes = typeof(mtg)[]
      @test descendants!(out_nodes, mtg) == traverse(mtg[1], x -> x)
      @test descendants!(out_nodes, mtg, self=true) == traverse(mtg, x -> x)
      @test descendants!(out_nodes, get_node(mtg, 6), self=true) == [get_node(mtg, 6), get_node(mtg, 7)]
end

# using BenchmarkTools
# @benchmark descendants($mtg, :Width) # 876 ns
# @benchmark descendants!($mtg, :Width) # 5.6 μs
# @benchmark descendants($mtg, :Width; type=Union{Nothing,Float64}) # 7.6 μs
# @benchmark descendants(mtg, :Width)
