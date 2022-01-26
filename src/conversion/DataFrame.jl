"""
    DataFrame(mtg::Node)
    DataFrame(mtg::Node, key)

Convert an MTG into a DataFrame.

# Arguments

- `mtg::Node`: An mtg node (usually the root node).
- `key`: The attribute(s) name(s). Select a list of variables given either as a Symbol
(faster), a String, or an Array of (or a Tuple).

# Examples

```julia
# Importing an mtg from the package:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# Full DataFrame:
DataFrame(mtg)

# Select just :Length:
DataFrame(mtg, :Length)

# Select just :Length and :Width:
DataFrame(mtg, [:Length, :Width])
```
"""
function DataFrame(mtg::Node, key::T) where {T<:Union{AbstractArray,Tuple}}

    tree_vars = [:node_id, :node_symbol, :node_scale, :node_index, :parent_id, :node_link] ∪ key

    # Extract the MTG info:
    nodes_info =
        traverse(
            mtg,
            node -> (
                node_id = node.id,
                node_symbol = node.MTG.symbol,
                node_scale = node.MTG.scale,
                node_index = node.MTG.index,
                parent_id = MultiScaleTreeGraph.get_parent_id(node),
                node_link = node.MTG.link
            )
        )

    # Build the DataFrame:
    df = DataFrame(nodes_info)
    insertcols!(df, 1, :tree => get_printing(mtg))

    for var in key
        insertcols!(df, var => [descendants(mtg, var, self = true)...])
    end

    # Replace the nothing values by missing values as it is the standard in DataFrames:
    for i in names(df)
        df[!, i] = replace(df[!, i], nothing => missing)
    end

    rename!(
        df,
        Dict(
            :node_id => "id",
            :node_symbol => "symbol",
            :node_scale => "scale",
            :node_index => "index",
            :node_link => "link"
        )
    )

    return df
end

function DataFrame(mtg::Node, key::T) where {T<:Symbol}
    DataFrame(mtg, [key])
end

function DataFrame(mtg::Node, key::T) where {T<:AbstractString}
    DataFrame(mtg, Symbol(key))
end

function DataFrame(mtg::Node)
    DataFrame(mtg, get_attributes(mtg))
end


function get_parent_id(x)
    if !isroot(x)
        return x.parent.id
    end
end
