mtg = read_mtg("files/simple_plant.mtg", Dict);

@testset "DataFrame" begin
    df_mtg = DataFrame(mtg, [:scales, :Length])
    @test df_mtg[1,:scales] == [0, 1, 2, 3, 3]
    @test df_mtg[7, :Length] == 12.0
end


@testset "MetaGraph" begin
    meta_mtg = MetaGraph(mtg)
    @test meta_mtg["node_1"][:scales] == [0, 1, 2, 3, 3]
    @test meta_mtg["node_7"][:Length] == 12.0
end
