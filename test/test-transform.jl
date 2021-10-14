@testset "transform!" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict);

    # Test `function` form:
    transform!(mtg, x -> x[:x] = parse(Int, x.name[6]))
    @test descendants(mtg, :x, self = true) == collect(1:7)

    # Test `:var_name => function => :new_var_name` form:
    transform!(mtg, :x => (x -> x + 2) => :y)
    @test descendants(mtg, :y, self = true) == collect(1:7) .+ 2

    # Test `function => :new_var_name` form:
    transform!(mtg, (x -> x[:x] + 3) => :y2)
    @test descendants(mtg, :y2, self = true) == collect(1:7) .+ 3

    # Test `:var_name => function` form:
    transform!(mtg, :x => log)
    @test descendants(mtg, :x_log, self = true) == log.(1:7)

    # Test `:var_name => function` form:
    transform!(mtg, :x_log => :log_x)
    @test :log_x in get_features(mtg).NAME
end
