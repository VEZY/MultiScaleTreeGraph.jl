"""
    get_classes(mtg)

Compute the mtg classes based on its content. Usefull after having mutating the mtg nodes.
"""
function get_classes(mtg)
    attributes = traverse(mtg, node -> (SYMBOL=symbol(node), SCALE=scale(node)), type=@NamedTuple{SYMBOL::Symbol, SCALE::Int64})
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
    attributes = traverse(
        mtg,
        node -> (collect(keys(node_attributes(node))), [typeof(i) for i in values(node_attributes(node))]), type=Tuple{Vector{Symbol},Vector{DataType}}
    ) |> unique

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
        elseif value <: Bool
            # we test booleans before integers because Bool <: Integer
            new_type[index] = "BOOLEAN"
        elseif value <: Integer
            new_type[index] = "INT"
            # elseif df.NAME[i] in () # Put reserved keywords here if needed in the future
            # new_type[index] = "ALPHA"
        elseif value <: Date
            new_type[index] = "DD/MM/YY"
        else
            # All others are parsed as string
            new_type[index] = "STRING"
        end
    end

    df.TYPE = new_type

    # Remove repeated rows again after having changed the type (can have String and SubString for the same variable before): 
    unique!(df)

    return df
end

"""
    scales(mtg)

Get all the scales of an MTG.
"""
function scales(mtg)
    vec = Int[]
    traverse(mtg) do node
        push!(vec, scale(node))
    end

    return unique(vec)
end

function symbols(mtg)
    vec = Symbol[]
    traverse!(mtg) do node
        push!(vec, symbol(node))
    end
    return unique(vec)
end

components = symbols

"""
    symbols(mtg)
    components(mtg)

Get all the symbols names, a.k.a. components of an MTG.
"""
components, symbols

"""
    list_nodes(mtg)

List all nodes IDs in the subtree of `mtg`.
"""
list_nodes(mtg) = traverse(mtg, node -> node_id(node), type=Int)

"""
    max_id(mtg)

Returns the maximum id of the mtg
"""
function max_id(mtg)
    maxid = Ref(0)

    function update_maxname(id, maxid)
        id > maxid[] ? maxid[] = id : nothing
    end

    traverse!(get_root(mtg), x -> update_maxname(node_id(x), maxid))

    return maxid[]
end
