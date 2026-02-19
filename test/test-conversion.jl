mtg = read_mtg("files/simple_plant.mtg")

@testset "Tables/DataFrame interoperability" begin
    df_mtg = DataFrame(mtg)
    @test !(:scales in Symbol.(names(df_mtg)))
    @test !(:symbols in Symbol.(names(df_mtg)))
    @test !(:description in Symbol.(names(df_mtg)))
    @test df_mtg[7, :Length] == 0.2
end

@testset "MetaGraph" begin
    meta_mtg = MetaGraph(mtg)
    @test meta_mtg[1][:scales] == [0, 1, 2, 3, 3]
    @test meta_mtg[7][:Length] == 0.2
end
