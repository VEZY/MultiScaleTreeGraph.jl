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
    node_vec = get_printing(mtg)
    df = DataFrame(tree = node_vec)

    for var in key
        insertcols!(df, var => [descendants(mtg, var, self = true)...])
    end

    # Replace the nothing values by missing values as it is the standard in DataFrames:
    for i in names(df)
        df[!,i] = replace(df[!,i], nothing => missing)
    end

    return df
end

function DataFrames.DataFrame(mtg::Node, key::T) where T <: Symbol
    df = DataFrame([get_printing(mtg), [descendants(mtg, key, self = true)...]], [:tree,key])
        # Replace the nothing values by missing values as it is the standard in DataFrames:
    for i in names(df)
        df[!,i] = replace(df[!,i], nothing => missing)
    end

    return df
end

function DataFrames.DataFrame(mtg::Node, key::T) where T <: AbstractString
    DataFrame(mtg, Symbol(key))
end

function DataFrames.DataFrame(mtg::Node)
    DataFrame([get_printing(mtg)], [:tree])
end
