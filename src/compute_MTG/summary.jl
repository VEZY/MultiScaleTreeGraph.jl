"""
    get_classes(mtg)

Compute the mtg classes based on its content. Usefull after having mutating the mtg nodes.
"""
function get_classes(mtg)
    attributes = traverse(mtg, node -> (SYMBOL=node.MTG.symbol, SCALE=node.MTG.scale))
    attributes = unique(attributes)
    df = DataFrame(attributes)

    # Make everything to default values:
    df[!, :DECOMPOSITION] .= "FREE"
    df[!, :INDEXATION] .= "FREE"
    df[!, :DEFINITION] .= "IMPLICIT"
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

Compute the mtg features section based on its attributes. Usefull after having computed new attributes
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
    filter!(
        x -> !(x.TYPE <: Vector) &&
                 !(x.TYPE <: Nothing) &&
                 !in(x.NAME, [:description, :symbols, :scales]),
        df
    )

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
        elseif value <: Bool
            new_type[index] = "BOOLEAN"
        elseif value <: Date
            new_type[index] = "DD/MM/YY"
        else
            # All others are parsed as string
            new_type[index] = "STRING"
        end
    end

    df.TYPE = new_type

    return df
end

"""
    scales(mtg)

Get all the scales of an MTG.
"""
function scales(mtg)
    unique(traverse(mtg, node -> node.MTG.scale))
end

function symbols(mtg)
    unique(traverse(mtg, node -> node.MTG.symbol))
end

components = symbols

"""
    symbols(mtg)
    components(mtg)

Get all the symbols names, a.k.a. components of an MTG.
"""
components, symbols

"""
    get_attributes(mtg)

Get all attributes names available on the mtg and its children.
"""
get_attributes(mtg) = unique!(vcat(traverse(mtg, node -> collect(keys(node.attributes)))...))

"""
    names(mtg)

Get all attributes names available on the mtg and its children. This is an alias for
[`get_attributes`](@ref).
"""
Base.names(mtg::T) where {T<:MultiScaleTreeGraph.Node} = get_attributes(mtg)

"""
    list_nodes(mtg)

List all nodes IDs in the subtree of `mtg`.
"""
list_nodes(mtg) = traverse(mtg, node -> node.id)

"""
    max_id(mtg)

Returns the maximum id of the mtg
"""
function max_id(mtg)
    maxid = [0]

    function update_maxname(id, maxid)
        id > maxid[1] ? maxid[1] = id : nothing
    end

    traverse!(get_root(mtg), x -> update_maxname(x.id, maxid))

    return maxid[1]
end
