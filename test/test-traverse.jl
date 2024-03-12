@testset "traverse!" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    # Add a new attributes, x based on node field, y based on x and z using a function:
    traverse!(mtg, x -> x[:x] = length(x.name))
    @test mtg[:x] == 6

    traverse!(mtg) do x
        x[:y] = x[:x] + 2
    end
    @test mtg[:y] == mtg[:x] + 2
end

@testset "traverse" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    # Add a new attributes, x based on node field, y based on x and z using a function:
    name_length = traverse(mtg, x -> length(x.name))
    @test name_length == repeat([6], length(mtg))

    name_length_do = traverse(mtg) do x
        length(x.name) + 2
    end

    @test name_length_do == repeat([8], length(mtg))
end

@testset "traverse + filters" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)
    # Add a new attributes, x based on node field, y based on x and z using a function:
    @test traverse(mtg, x -> x, symbol="Internode") == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, scale=3) == [get_node(mtg, 4), get_node(mtg, 5), get_node(mtg, 6), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, scale=3) == traverse(mtg, x -> x, symbol=["Internode", "Leaf"])
    @test traverse(mtg, x -> x, link="+") == [get_node(mtg, 5), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, link="<") == [get_node(mtg, 6)]
    @test traverse(mtg, x -> x, link=["<", "+"]) == [get_node(mtg, 5), get_node(mtg, 6), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, filter_fun=node -> node[:Length] !== nothing && node[:Length] == 0.1) == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, symbol="Internode", filter_fun=node -> node[:Length] !== nothing) == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, filter_fun=node -> node.MTG.symbol != "Internode", all=false) == [get_node(mtg, i) for i in 1:3]
    @test traverse(mtg, x -> x, symbol="Internode", all=false) == Any[] # No internode in the first level, all=false -> iteration stops before the first node
    @test traverse(mtg, node -> node[:Length]) == Any[nothing, nothing, nothing, 0.1, 0.2, 0.1, 0.2]
    @test traverse(mtg, node -> node[:Length], type=Union{Nothing,Float64}) == Union{Nothing,Float64}[nothing, nothing, nothing, 0.1, 0.2, 0.1, 0.2]
end