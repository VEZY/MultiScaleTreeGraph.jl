"""
    ancestors(node::Node,key,<keyword arguments>)

Get attribute values from the ancestors (basipetal).

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name. Make it a `Symbol` for faster computation time.

## Keyword Arguments

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `self = false`: is the value for the current node needed ?
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
- `type::Union{Union,DataType}`: The type of the attribute. Makes the function run much
faster if provided (≈4x faster).

# Note

In most cases, the `type` argument should be given as a union of `Nothing` and the data type
of the attribute to manage missing or inexistant data, e.g. measurements made at one scale
only. See examples for more details.

# Examples

```julia
# Importing the mtg from the github repo:
mtg = read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

# Using a leaf node from the mtg:
leaf_node = mtg.children["node_2"].children["node_3"].children["node_4"].children["node_5"]

ancestors(leaf_node, :Length) # Short to write, but slower to execute

# Fast version, note that we pass a union of Nothing and Float64 because there are some nodes
# without a `Length` attribute:
ancestors(leaf_node, :Length, type = Union{Nothing,Float64})

# Filter by scale:
ancestors(leaf_node, :XX, scale = 1, type = Float64)
ancestors(leaf_node, :Length, scale = 3, type = Float64)

# Filter by symbol:
ancestors(leaf_node, :Length, symbol = "Internode")
ancestors(leaf_node, :Length, symbol = ("Axis","Internode"))
```
"""
function ancestors(
    node,key;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    self = false,
    filter_fun = nothing,
    type::Union{Union,DataType} = Any)

    # Check the filters once, and then compute the ancestors recursively using `ancestors_`
    check_filters(node, scale = scale, symbol = symbol, link = link)

    val = Array{type,1}()
    if self
        keep = is_filtered(node, scale, symbol, link, filter_fun)

        if keep
            push!(val, unsafe_getindex(node, key))
        elseif !all
            # We don't keep the value and we have to stop at the first filtered-out value
            return val
        end
    end

    ancestors_(node, key, scale, symbol, link, all, filter_fun, val)
    return val
end


function ancestors_(node, key, scale, symbol, link, all, filter_fun, val)

    if !isroot(node)
        parent = node.parent

        # Is there any filter happening for the current node? (FALSE if filtered out):
        keep = is_filtered(parent, scale, symbol, link, filter_fun)

        if keep
            push!(val, unsafe_getindex(parent, key))
        end

        # If we want to continue even if the current node is filtered-out
        if all || keep
            ancestors_(parent, key, scale, symbol, link, all, filter_fun, val)
        end
    end
end
