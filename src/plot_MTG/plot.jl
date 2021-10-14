# using MTG
# using Plots
# using ColorSchemes
# plotlyjs()

# file = joinpath(dirname(dirname(pathof(MTG))), "test", "files", "simple_plant.mtg")
# mtg = read_mtg(file)
# plot(mtg)
@recipe function f(h::Node)
    branching_order!(mtg)
    df_coordinates = MTG.mtg_coordinates_df(mtg, force = true)
    df_coordinates[!,:branching_order] = descendants(mtg, :branching_order, self = true)

    x = df_coordinates.XX
    y = df_coordinates.YY

    for i in 2:size(df_coordinates, 1)
        x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
        y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
        @series begin
            label := ""
            seriestype := :line
            seriescolor := :black
            x2, y2
        end
    end

    @series begin
        seriestype := :scatter
        label := ""
        seriescolor := :viridis
        marker_z := df_coordinates.branching_order
        colorbar_entry := false
        hover := string.(
            "name: `node_", df_coordinates.id,
            "`, link: `", df_coordinates.link,
            "`, symbol: `", df_coordinates.symbol,
            "`, index: `", df_coordinates.index, "`"
        )

        x, y
    end
end

# p = plot()
# for i in 2:size(df_coordinates, 1)
#     x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
#     y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
#     plot!(p, x2, y2, label = "", color = :black)
# end
# scatter!(p,x,y, marker_z = df_coordinates.branching_order)
