
# This is working but should live in a @recipe instead.
# I am waiting for a more stable version of the recipes in Makie, or at least one
# that doesn't need the full Makie thing as a dependency.
# Needs to do: `using GLMakie, Color, ColorSchemes`
function plot_mtg_Makie(mtg; color_var = :YY)

    df_coordinates = mtg_coordinates_df(mtg)
    colouring_var = df_coordinates[:,color_var]
    color = colouring_var ./ maximum(colouring_var)

    fig, ax, p = scatter(df_coordinates.XX, df_coordinates.YY, df_coordinates.ZZ, color = color, colormap = :viridis)
    # ?Note: could use meshscatter! instead here

    for i in 2:size(df_coordinates, 1)
        lines!(
            [df_coordinates.XX_from[i], df_coordinates.XX[i]],
            [df_coordinates.YY_from[i], df_coordinates.YY[i]],
            [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
            color = get(ColorSchemes.viridis, [color[i - 1],color[i]])
        )
    end
    # DataInspector(fig)
    hidedecorations!(ax);
    hidespines!(ax)
    # ax.aspect = DataAspect()
    # p.nlabels_offset[] = Point2f(0.2, - 0.2)
    # autolimits!(ax)
    fig
end

plot_mtg_Makie(mtg)
