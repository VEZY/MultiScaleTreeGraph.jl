@testset "Plots recipe" begin
    mtg = read_mtg("files/simple_plant.mtg", Dict)

    recipe = RecipesBase.apply_recipe(Dict{Symbol,Any}(), mtg)

    @test length(recipe) == length(mtg)
    # ?NB: both should be equal because 6 lines (all except first point have an edge),
    # and 1 scatter.

    @test recipe[1].plotattributes == Dict{Symbol,Any}(:label => "", :seriescolor => :black, :seriestype => :line)
    @test recipe[1].args == ([0.0, 0.0], [0.0, 0.1]) # coordinates of the two vertex for the edge
    @test recipe[6].args == ([0.0, 0.7071067811865474], [1.3, 2.0071067811865477]) # same, last one

    df_coordinates = MultiScaleTreeGraph.mtg_coordinates_df(mtg, force = true)

    @test recipe[7].args[1] == df_coordinates.XX
    @test recipe[7].plotattributes == Dict{Symbol,Any}(
        :label => "",
        :seriescolor => :viridis,
        :hover => [
            "name: `node_1`, link: `/`, symbol: `\$`, index: `0`",
            "name: `node_2`, link: `/`, symbol: `Individual`, index: `0`",
            "name: `node_3`, link: `/`, symbol: `Axis`, index: `0`",
            "name: `node_4`, link: `/`, symbol: `Internode`, index: `0`",
            "name: `node_5`, link: `+`, symbol: `Leaf`, index: `0`",
            "name: `node_6`, link: `<`, symbol: `Internode`, index: `1`",
            "name: `node_7`, link: `+`, symbol: `Leaf`, index: `0`"
        ],
        :seriestype => :scatter,
        :colorbar_entry => false,
        :marker_z => Any[1, 1, 1, 1, 2, 1, 2]
    )
end
