@testset "traverse!" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict);
    # Add a new attributes, x based on node field, y based on x and z using a function:
    traverse!(mtg, x -> x[:x] = length(x.name))
    @test mtg[:x] ==  6

    traverse!(mtg) do x
        x[:y] = x[:x] + 2
    end
    @test mtg[:y] ==  mtg[:x] + 2
end

@testset "traverse" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict);
    # Add a new attributes, x based on node field, y based on x and z using a function:
    name_length = traverse(mtg, x -> length(x.name))
    @test name_length == repeat([6], length(mtg))

    name_length_do = traverse(mtg) do x
        length(x.name) + 2
    end

    @test name_length_do == repeat([8], length(mtg))
end
