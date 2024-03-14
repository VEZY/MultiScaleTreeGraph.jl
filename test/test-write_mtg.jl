file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
mtg = read_mtg(file)

# Removing the description because we don't write it anyway:
mtg[:description] = nothing

@testset "Test write / read again: simple plant" begin
    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end


mtg = read_mtg("files/simple_plant.mtg", NamedTuple, NodeMTG)

@testset "Test write / read again: simple plant + NamedTuple" begin
    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f, NamedTuple, NodeMTG)
        return mtg2
    end

    # Check that all nodes are the same (not testing node 1 as it has description that is not written):
    for i in 2:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end

@testset "Test write / read again: simple plant P1U1" begin
    mtg = read_mtg("files/simple_plant-P1U1.mtg")
    mtg[:description] = nothing

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end

@testset "Test write / read again: palm" begin
    mtg = read_mtg("files/palm.mtg")
    mtg[:description] = nothing

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end


file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant-follow.mtg")
mtg = read_mtg(file)

@testset "Test write / read again: simple plant with GU follow" begin

    @test length(mtg) == 35
    @test length(children(mtg[1][1])) == 2
    @test children(mtg[1][1])[1] |> symbol == "N"
    @test children(mtg[1][1])[2] |> symbol == "GU"

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    @test length(mtg2) == length(mtg)
    @test descendants(mtg, :diameter_mm) == descendants(mtg2, :diameter_mm)
    @test descendants(mtg, :length_cm) == descendants(mtg2, :length_cm)
    @test descendants(mtg, :azimuth) == descendants(mtg2, :azimuth)
    @test traverse(mtg, symbol) == traverse(mtg2, symbol)
    @test traverse(mtg, index) == traverse(mtg2, index)
end