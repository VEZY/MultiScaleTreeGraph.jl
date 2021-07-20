@testset "descendants" begin
    mtg = read_mtg("files/simple_plant.mtg");
    width_all = [nothing,nothing,1.0,6.0,nothing,7.0]
    @test descendants(mtg, :Width; type = Union{Nothing,Float64}) ==  width_all
    @test descendants(mtg, :Width) ==  width_all

    d = descendants(mtg, :Width, scale = 1)
    @test typeof(d) == Vector{Any}
    @test length(d) == 1
    @test d[1] == width_all[1]
    d_typed = descendants(mtg, :Width, type = Union{Nothing,Float64})
    @test typeof(d_typed) ==  Vector{Union{Nothing,Float64}}
    @test descendants(mtg, :Width, symbol = ("Leaf", "Internode")) == width_all[3:end]

    mtg2 = mtg[1][1][1][2]
    @test descendants(mtg2, :Width, symbol = "Leaf")[1] == width_all[end]

    @test descendants(mtg2, :Width, symbol = ("Leaf", "Internode"), self = true) ==
        width_all[end - 1:end]

    @test descendants!(mtg, :Width) == descendants(mtg, :Width)
    @test descendants!(mtg2, :Width, symbol = ("Leaf", "Internode"), self = true) ==
        width_all[end - 1:end]

    # descendants!(mtg, :Width, symbol = ("Leaf", "Internode"), self = true)
end

# using BenchmarkTools

# @benchmark descendants(mtg, :Width) # 19.000 μs
# @benchmark descendants!(mtg, :Width) # 19.000 μs
# @benchmark descendants(mtg, :Width; type = Union{Nothing,Float64})
# @benchmark descendants(mtg, :Width)
