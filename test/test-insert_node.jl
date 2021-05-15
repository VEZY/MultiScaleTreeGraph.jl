mtg = read_mtg("files/simple_plant.mtg");



@testset "test classes" begin

    template = MTG.MutableNodeMTG("/", "Shoot", 0, 1)
    max_id = parse(Int, MTG.max_name(mtg)[6:end])
    length_before = length(mtg)
    MTG.insert_node!(mtg[1][1], template, max_id)

    @test length(mtg) == length_before + 1
    @test mtg[1][1].MTG.link == template.link
    @test mtg[1][1].MTG.symbol == template.symbol
    @test mtg[1][1].MTG.index == template.index
    @test mtg[1][1].MTG.scale == template.scale
    @test mtg[1][1].name == join(["node_", max_id + 1])
end
