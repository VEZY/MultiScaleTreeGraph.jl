# using MTG
# using Plots
# using ColorSchemes
# plotlyjs()

# file = joinpath(dirname(dirname(pathof(MTG))), "test", "files", "simple_plant.mtg")
# mtg = read_mtg(file)
# plot(mtg)
@recipe function f(h::Node; mode = "2d")
    branching_order!(mtg)
    df_coordinates = MTG.mtg_coordinates_df(mtg, force = true)
    df_coordinates[!,:branching_order] = descendants(mtg, :branching_order, self = true)

    x = df_coordinates.XX
    y = df_coordinates.YY
    z = df_coordinates.ZZ

    for i in 2:size(df_coordinates, 1)
        x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
        y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
        z2 = [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]]

        @series begin
            label := ""
            seriescolor := :black
            if mode == "2d"
                seriestype := :line
                x2, y2
            else
                seriestype := :line3d
                x2, z2, y2
            end
        end
    end

    @series begin
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

        if mode == "2d"
            seriestype := :scatter
            x, y
        else
            seriestype := :scatter3d
            x, z, y
        end

    end
end

# p = plot()
    # for i in 2:size(df_coordinates, 1)
#     x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
#     y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
#     plot!(p, x2, y2, label = "", color = :black)
# end
# scatter!(p,x,y, marker_z = df_coordinates.branching_order)
