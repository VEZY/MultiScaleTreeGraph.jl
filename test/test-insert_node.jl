mtg = read_mtg("files/simple_plant.mtg");

@testset "test insert_node!" begin

    template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
    max_id = [parse(Int, MultiScaleTreeGraph.max_name(mtg)[6:end])]
    length_before = length(mtg)
    MultiScaleTreeGraph.insert_parent!(mtg[1][1], template, max_id)

    @test length(mtg) == length_before + 1
    @test mtg[1][1].MTG.link == template.link
    @test mtg[1][1].MTG.symbol == template.symbol
    @test mtg[1][1].MTG.index == template.index
    @test mtg[1][1].MTG.scale == template.scale
    @test mtg[1][1].name == join(["node_", max_id[1]])  # max_id is already incremented
end


@testset "test insert_parents!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MutableNodeMTG("/", "Shoot", 0, 1)
    length_before = length(mtg)
    insert_parents!(mtg, template, scale = 2)

    @test length(mtg) == length_before + 1
    @test mtg[1][1].MTG.link == template.link
    @test mtg[1][1].MTG.symbol == template.symbol
    @test mtg[1][1].MTG.index == template.index
    @test mtg[1][1].MTG.scale == template.scale
    @test mtg[1][1].name == "node_8"
end
