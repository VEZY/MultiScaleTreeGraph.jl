@testset "traverse!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    # Add a new attributes, x based on node field, y based on x and z using a function:
    traverse!(mtg, x -> x[:x] = length(node_id(x)))
    @test mtg[:x] == 1

    traverse!(mtg) do x
        x[:y] = x[:x] + 2
    end
    @test mtg[:y] == mtg[:x] + 2
end

@testset "traverse" begin
    mtg = read_mtg("files/simple_plant.mtg")
    # Add a new attributes, x based on node field, y based on x and z using a function:
    node_ids = traverse(mtg, x -> node_id(x))
    @test node_ids == collect(1:length(mtg))

    node_ids_do = traverse(mtg) do x
        node_id(x) + 2
    end

    @test node_ids_do == collect(1:length(mtg)) .+ 2
end

@testset "traverse + filters" begin
    mtg = read_mtg("files/simple_plant.mtg")
    # Add a new attributes, x based on node field, y based on x and z using a function:
    @test traverse(mtg, x -> x, symbol="Internode") == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, symbol=:Internode) == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, scale=3) == [get_node(mtg, 4), get_node(mtg, 5), get_node(mtg, 6), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, scale=3) == traverse(mtg, x -> x, symbol=["Internode", "Leaf"])
    @test traverse(mtg, x -> x, scale=3) == traverse(mtg, x -> x, symbol=[:Internode, :Leaf])
    @test traverse(mtg, x -> x, link="+") == [get_node(mtg, 5), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, link=:+) == [get_node(mtg, 5), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, link="<") == [get_node(mtg, 6)]
    @test traverse(mtg, x -> x, link=:<) == [get_node(mtg, 6)]
    @test traverse(mtg, x -> x, link=["<", "+"]) == [get_node(mtg, 5), get_node(mtg, 6), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, link=[:<, :+]) == [get_node(mtg, 5), get_node(mtg, 6), get_node(mtg, 7)]
    @test traverse(mtg, x -> x, filter_fun=node -> node[:Length] !== nothing && node[:Length] == 0.1) == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, symbol=:Internode, filter_fun=node -> node[:Length] !== nothing) == [get_node(mtg, 4), get_node(mtg, 6)]
    @test traverse(mtg, x -> x, filter_fun=node -> symbol(node) != :Internode, all=false) == [get_node(mtg, i) for i in 1:3]
    @test traverse(mtg, x -> x, symbol=:Internode, all=false) == Any[] # No internode in the first level, all=false -> iteration stops before the first node
    @test traverse(mtg, node -> node[:Length]) == Any[nothing, nothing, nothing, 0.1, 0.2, 0.1, 0.2]
    @test traverse(mtg, node -> node[:Length], type=Union{Nothing,Float64}) == Union{Nothing,Float64}[nothing, nothing, nothing, 0.1, 0.2, 0.1, 0.2]
end

@testset "traverse deep no-filter path" begin
    root = Node(1, NodeMTG(:/, :Plant, 1, 1))
    current = root
    for i in 1:5000
        current = Node(i + 1, current, NodeMTG(:<, :Segment, i, 2))
    end

    out = traverse(root, node -> node_id(node), type=Int)
    @test length(out) == 5001
    @test out[1] == 1
    @test out[end] == 5001

    n = Ref(0)
    traverse!(root, _ -> n[] += 1)
    @test n[] == 5001
end
