"""
    DataFrame(mtg::Node,vars::T[,type::Union{Union,DataType}=Any])

Convert an MTG into a DataFrame.

# Arguments

- `mtg::Node`: An mtg node (usually the root node).
- `key`: The key, or attribute name. Used to list the variables that must be added to the
`DataFrame`. It is given either as Symbols (faster) or String, or an Array of (or a Tuple).

# Examples

```julia
# Importing the mtg from the github repo:
mtg = read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

DataFrame(mtg, :Length)
DataFrame(mtg, [:Length, :Width])
```
"""
function DataFrames.DataFrame(mtg::Node, key::T) where T <: Union{AbstractArray,Tuple}

    tree_vars = [:node_id, :node_symbol, :node_scale, :node_index, :parent_id, :node_link]
    # Add the MTG to the attributes:
    @mutate_mtg!(
        mtg,
        node_id = parse(Int, node.name[6:end]),
        node_symbol = node.MTG.symbol,
        node_scale = node.MTG.scale,
        node_index = node.MTG.index,
        parent_id = get_parent_id(node),
        node_link = node.MTG.link
    )

    node_vec = get_printing(mtg)
    df = DataFrame(tree = node_vec)

    append!(tree_vars, key)

    for var in tree_vars
        insertcols!(df, var => [descendants(mtg, var, self = true)...])
    end

    # Replace the nothing values by missing values as it is the standard in DataFrames:
    for i in names(df)
        df[!,i] = replace(df[!,i], nothing => missing)
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

function DataFrames.DataFrame(mtg::Node, key::T) where T <: Symbol
    DataFrame(mtg, [key])
end

function DataFrames.DataFrame(mtg::Node, key::T) where T <: AbstractString
    DataFrame(mtg, Symbol(key))
end

function DataFrames.DataFrame(mtg::Node)
    DataFrame([get_printing(mtg)], [:tree])
end


function get_parent_id(x)
    if !isroot(x)
        return parse(Int, x.parent.name[6:end])
    end
end
