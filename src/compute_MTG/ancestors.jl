"""
    ancestors(node::Node,key,<keyword arguments>)
    ancestors(node::Node,<keyword arguments>)

Get attribute values from the ancestors (basipetal), or the ancestor nodes that are not filtered-out.

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name. It is only mandatory for the first method that search for attributes values. The second method returns the node directly. 
Make it a `Symbol` for faster computation time.

## Keyword Arguments

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Symbols.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `self = false`: is the value for the current node needed ?
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
- `recursivity_level = -1`: The maximum number of recursions allowed (considering filters).
*E.g.* to get the parent only: `recursivity_level = 1`, for parent + grand-parent:
`recursivity_level = 2`. If a negative value is provided (the default), the function returns
all valid values from the node to the root.
- `ignore_nothing = false`: filter-out the nodes with `nothing` values for the given `key`
- `type::Union{Union,DataType}`: The type of the attribute. Makes the function run much
faster if provided (≈4x faster).

# Note

In most cases, the `type` argument should be given as a union of `Nothing` and the data type
of the attribute to manage missing or inexistant data, e.g. measurements made at one scale
only. See examples for more details.

# Examples

```julia
# Importing an example mtg from the package:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# Using a leaf node from the mtg:
leaf_node = get_node(mtg, 5)

ancestors(leaf_node, :Length) # Short to write, but slower to execute

# Fast version, note that we pass a union of Nothing and Float64 because there are some nodes
# without a `Length` attribute:
ancestors(leaf_node, :Length, type = Union{Nothing,Float64})

# Filter by scale:
ancestors(leaf_node, :XX, scale = 1, type = Float64)
ancestors(leaf_node, :Length, scale = 3, type = Float64)

# Filter by symbol:
ancestors(leaf_node, :Length, symbol = :Internode)
ancestors(leaf_node, :Length, symbol = (:Axis,:Internode))
```
"""
function ancestors(
    node, key;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    self=false,
    filter_fun=nothing,
    recursivity_level=-1,
    ignore_nothing=false,
    type::Union{Union,DataType}=Any)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)

    # Check the filters once, and then compute the ancestors recursively using `ancestors_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    # Change the filtering function if we also want to remove nodes with nothing values.
    filter_fun_ = filter_fun_nothing(filter_fun, ignore_nothing, key)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun_)

    val = Array{type,1}()
    # Put the recursivity level into an array so it is mutable in-place:

    if self
        if use_no_filter || is_filtered(node, scale, symbol, link, filter_fun_)
            val_ = unsafe_getindex(node, key)
            push!(val, val_)
        elseif !all
            # We don't keep the value and we have to stop at the first filtered-out value
            return val
        end
    end

    if use_no_filter
        ancestors_values_no_filter!(node, key, val, recursivity_level)
    else
        ancestors_values!(node, key, scale, symbol, link, all, filter_fun_, val, recursivity_level)
    end
    return val
end


function ancestors_values!(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level)
    current = node
    remaining = recursivity_level

    while !isroot(current) && remaining != 0
        parent_ = parent(current)
        keep = is_filtered(parent_, scale, symbol, link, filter_fun)

        if keep
            push!(val, unsafe_getindex(parent_, key))
            # Only decrement the recursivity level when the current node is not filtered-out
            remaining -= 1
        end

        # If we want to continue even if the current node is filtered-out
        (all || keep) || break
        current = parent_
    end
    return val
end

function ancestors_values_no_filter!(node, key, val, recursivity_level)
    current = node
    remaining = recursivity_level

    while !isroot(current) && remaining != 0
        parent_ = parent(current)
        push!(val, unsafe_getindex(parent_, key))
        remaining -= 1
        current = parent_
    end
    return val
end

# Version that returns the nodes instead of the values:
function ancestors(
    node;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    self=false,
    filter_fun=nothing,
    recursivity_level=-1
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)

    # Check the filters once, and then compute the ancestors recursively using `ancestors_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    use_no_filter = no_node_filters(scale, symbol, link, filter_fun)
    val = Array{typeof(node),1}()
    # Put the recursivity level into an array so it is mutable in-place:

    if self
        if use_no_filter || is_filtered(node, scale, symbol, link, filter_fun)
            push!(val, node)
        elseif !all
            # We don't keep the value and we have to stop at the first filtered-out value
            return val
        end
    end

    if use_no_filter
        ancestors_nodes_no_filter!(node, val, recursivity_level)
    else
        ancestors_nodes!(node, scale, symbol, link, all, filter_fun, val, recursivity_level)
    end
    return val
end


function ancestors_nodes!(node, scale, symbol, link, all, filter_fun, val, recursivity_level)
    current = node
    remaining = recursivity_level

    while !isroot(current) && remaining != 0
        parent_ = parent(current)
        keep = is_filtered(parent_, scale, symbol, link, filter_fun)

        if keep
            push!(val, parent_)
            # Only decrement the recursivity level when the current node is not filtered-out
            remaining -= 1
        end

        # If we want to continue even if the current node is filtered-out
        (all || keep) || break
        current = parent_
    end
    return val
end

function ancestors_nodes_no_filter!(node, val, recursivity_level)
    current = node
    remaining = recursivity_level

    while !isroot(current) && remaining != 0
        parent_ = parent(current)
        push!(val, parent_)
        remaining -= 1
        current = parent_
    end
    return val
end

function ancestors!(
    out::AbstractVector,
    node, key;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    self=false,
    filter_fun=nothing,
    recursivity_level=-1,
    ignore_nothing=false,
    type::Union{Union,DataType}=Any,
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    check_filters(node, scale=scale, symbol=symbol, link=link)
    filter_fun_ = filter_fun_nothing(filter_fun, ignore_nothing, key)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun_)

    empty!(out)
    if self
        if use_no_filter || is_filtered(node, scale, symbol, link, filter_fun_)
            push!(out, unsafe_getindex(node, key))
        elseif !all
            return out
        end
    end

    if use_no_filter
        ancestors_values_no_filter!(node, key, out, recursivity_level)
    else
        ancestors_values!(node, key, scale, symbol, link, all, filter_fun_, out, recursivity_level)
    end
    return out
end

function ancestors!(
    out::AbstractVector,
    node;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    self=false,
    filter_fun=nothing,
    recursivity_level=-1,
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    check_filters(node, scale=scale, symbol=symbol, link=link)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun)

    empty!(out)
    if self
        if use_no_filter || is_filtered(node, scale, symbol, link, filter_fun)
            push!(out, node)
        elseif !all
            return out
        end
    end

    if use_no_filter
        ancestors_nodes_no_filter!(node, out, recursivity_level)
    else
        ancestors_nodes!(node, scale, symbol, link, all, filter_fun, out, recursivity_level)
    end
    return out
end
