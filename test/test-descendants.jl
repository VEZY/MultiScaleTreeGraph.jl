@testset "descendants" begin
      mtg = read_mtg("files/simple_plant.mtg")
      width_all = [nothing, nothing, 0.02, 0.1, 0.02, 0.1]
      @test_logs (:warn, r"Keyword argument `type` in `descendants` is deprecated") descendants(mtg, :Width; type=Union{Nothing,Float64})
      @test descendants(mtg, :Width) == width_all

      d = descendants(mtg, :Width, scale=1)
      @test typeof(d) == Vector{Union{Nothing,Float64}}
      @test length(d) == 1
      @test d[1] === width_all[1]
      @test typeof(descendants(mtg, :Width)) == Vector{Union{Nothing,Float64}}
      d_symbol = descendants(mtg, :Width, symbol=(:Leaf, :Internode))
      @test d_symbol == width_all[3:end]
      @test typeof(d_symbol) == Vector{Union{Nothing,Float64}}
      @test typeof(descendants(mtg, :Width, ignore_nothing=true)) == Vector{Float64}

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

      # Multi-key descendants must return grouped rows in key order.
      rows_leaf = descendants(mtg, [:Length, :Width], symbol=:Leaf, ignore_nothing=true)
      @test !isempty(rows_leaf)
      @test all(length(row) == 2 for row in rows_leaf)
      @test all(!isnothing(row[1]) && !isnothing(row[2]) for row in rows_leaf)

      rows_mixed_keep = descendants(mtg, [:Length, :dateDeath], symbol=(:Leaf, :Internode), ignore_nothing=false)
      rows_mixed_drop = descendants(mtg, [:Length, :dateDeath], symbol=(:Leaf, :Internode), ignore_nothing=true)
      @test !isempty(rows_mixed_keep)
      @test all(length(row) == 2 for row in rows_mixed_keep)
      @test any(any(isnothing, row) for row in rows_mixed_keep)
      @test all(!any(isnothing, row) for row in rows_mixed_drop)

      out_rows = Any[]
      @test descendants!(out_rows, mtg, [:Length, :Width], symbol=:Leaf, ignore_nothing=true) == rows_leaf

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
# @benchmark descendants($mtg, :Width) # inferred eltype
# @benchmark descendants(mtg, :Width)
