mtg = read_mtg("files/simple_plant.mtg")

@testset "names" begin
    @test get_attributes(mtg) == [:scales, :description, :symbols, :FileName, :YY, :ZZ, :XX, :Length, :Width, :XEuler]
    @test names(mtg) == get_attributes(mtg)
    @test names(DataFrame(mtg))[8:end] == string.(names(mtg))
end


@testset "get attribute value" begin
    @test mtg[1][:YY] == 0.0
    @test mtg[1].attributes[:YY] == 0.0
end

@testset "set attribute value" begin
    mtg[1][:YY] = 1.0
    @test mtg[1][:YY] == 1.0
end
