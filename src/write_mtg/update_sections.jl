"""
    get_classes(mtg)

Compute the mtg classes based on its content. Usefull after having mutating the mtg nodes.
"""
function get_classes(mtg)
    attributes = traverse(mtg, node -> (SYMBOL = node.MTG.symbol, SCALE = node.MTG.scale))
    attributes = unique(attributes)
    df = DataFrame(attributes)

    # Make everything to default values:
    df[!,:DECOMPOSITION] .= "FREE"
    df[!,:INDEXATION] .= "FREE"
    df[!,:DEFINITION] .= "IMPLICIT"
    return df
end

"""
    get_description(mtg)

Returns `nothing`, because we can't really predict the description section from an mtg.
"""
function get_description(mtg)
    return nothing
end

"""
    get_features(mtg)

Compute the mtg features based on its attributes. Usefull after having computed new attributes
in the mtg.
"""
function get_features(mtg)
    attributes = traverse(mtg, node -> (collect(keys(node.attributes)), [typeof(i) for i in values(node.attributes)]))

    df = DataFrame(
        :NAME => vcat([i[1] for i in attributes]...),
        :TYPE => vcat([i[2] for i in attributes]...)
    )

    # filter-out the attributes that have more than one value inside them (not compatible with
    # the mtg format yet):
    filter!(x -> x.TYPE <: Number || x.TYPE <: AbstractString, df)

    # Remove repeated rows:
    unique!(df)

    new_type = fill("", size(df)[1])
    for (index, value) in enumerate(df.TYPE)
        if value <: AbstractFloat
            new_type[index] = "REAL"
        elseif value <: Int
            new_type[index] = "INT"
        # elseif df.NAME[i] in () # Put reserved keywords here if needed in the future
            # new_type[index] = "ALPHA"
        else
            # All others are parsed as string
            new_type[index] = "STRING"
        end
    end

    df.TYPE = new_type

    return df
end
