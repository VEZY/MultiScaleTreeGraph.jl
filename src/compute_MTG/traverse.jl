"""
    traverse!(node::Node, f::Function[, args...], <keyword arguments>)
    traverse(node::Node, f::Function[, args...], <keyword arguments>)

Traverse the nodes of a (sub-)tree, given any starting node in the tree, and apply a function
which is either mutating (use `traverse!`) or not (use `traverse`).


# Arguments

- `node::Node`: An MTG node (*e.g.* the whole mtg returned by `read_mtg()`).
- `f::Function`: a function to apply over each node
- `args::Any`: any argument to pass to the function
- <keyword arguments>:

    - `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
    - `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
    - `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
    - `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
    - `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that is filtered out (`false`).
    - `type::Type = Any`: The elements type of the returned array. This can speed-up things. Only available for the non-mutating version.
    - `recursivity_level::Int = Inf`: The maximum depth of the traversal. Default is `Inf` (*i.e.* no limit).

# Returns

`nothing` for `traverse!` because it mutates the (sub-)tree in-place, or an `Array{type}` (or `Array{Any}` if `type` is not given) for `traverse`.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
traverse!(mtg, node -> isleaf(node) ? println(node_id(node)," is a leaf") : nothing)
node_5 is a leaf
node_7 is a leaf

# We can also use the `do...end` block notation when we have a complex set of instructions:
traverse!(mtg) do node
    if isleaf(node)
         println(node_id(x)," is a leaf")
    end
end
```
"""
traverse!, traverse

function traverse_no_filter!(node::Node, f::Function, recursivity_level)
    nodes = Vector{typeof(node)}(undef, 1)
    levels = Vector{typeof(recursivity_level)}(undef, 1)
    nodes[1] = node
    levels[1] = recursivity_level

    while !isempty(nodes)
        current = pop!(nodes)
        current_level = pop!(levels)
        current_level == 0 && continue
        next_level = current_level - 1

        try
            f(current)
        catch e
            println("Issue in function $f for node #$(node_id(current)).")
            rethrow(e)
        end

        all_children = children(current)
        @inbounds for i in lastindex(all_children):-1:firstindex(all_children)
            push!(nodes, all_children[i])
            push!(levels, next_level)
        end
    end

    return nothing
end

function traverse_no_filter(node::Node, f::Function, val, recursivity_level)
    nodes = Vector{typeof(node)}(undef, 1)
    levels = Vector{typeof(recursivity_level)}(undef, 1)
    nodes[1] = node
    levels[1] = recursivity_level

    while !isempty(nodes)
        current = pop!(nodes)
        current_level = pop!(levels)
        current_level == 0 && continue
        next_level = current_level - 1

        val_ = try
            f(current)
        catch e
            println("Issue in function $f for node $(node_id(current)).")
            rethrow(e)
        end
        push!(val, val_)

        all_children = children(current)
        @inbounds for i in lastindex(all_children):-1:firstindex(all_children)
            push!(nodes, all_children[i])
            push!(levels, next_level)
        end
    end

    return val
end

function traverse!(node::Node, f::Function, args...; scale=nothing, symbol=nothing, link=nothing, filter_fun=nothing, all=true, recursivity_level=Inf)
    if !isempty(args)
        g = node -> f(node, args...)
    else
        g = f
    end
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    cache = node_traversal_cache(node)
    if !isempty(cache)
        cache_key = cache_name(scale, symbol, link, all, filter_fun)
        cached_nodes = get(cache, cache_key, nothing)
        if cached_nodes !== nothing
            for i in cached_nodes
                # NB: node_traversal_cache(node)[cache_name(scale, symbol, link, filter_fun)] is a Vector of nodes corresponding to the traversal filters applied.
                g(i)
            end
            return
        end
    end

    if no_node_filters(scale, symbol, link, filter_fun)
        traverse_no_filter!(node, g, recursivity_level)
        return
    end

    traverse!_(node, g, scale, symbol, link, filter_fun, all, recursivity_level)
end

function traverse!_(node::Node, f::Function, scale, symbol, link, filter_fun, all, recursivity_level)
    recursivity_level == 0 && return
    recursivity_level -= 1

    if is_filtered(node, scale, symbol, link, filter_fun)
        try
            f(node)
        catch e
            println("Issue in function $f for node #$(node_id(node)).")
            rethrow(e)
        end
    elseif !all
        return # When `all=false`, we have to stop when a node is filtered out
    end

    if !isleaf(node)
        for chnode in children(node)
            traverse!_(chnode, f, scale, symbol, link, filter_fun, all, recursivity_level)
        end
    end
end


# Non-mutating version:
# Set-up array of value and call the workhorse (traverse_)
function traverse(node::Node, f::Function, args...; scale=nothing, symbol=nothing, link=nothing, filter_fun=nothing, all=true, type=Any, recursivity_level=Inf)
    if !isempty(args)
        g = node -> f(node, args...)
    else
        g = f
    end
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)

    val = Array{type,1}()
    # NB: f has to return someting here, if its a mutating function, use traverse!

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    cache = node_traversal_cache(node)
    if !isempty(cache)
        cache_key = cache_name(scale, symbol, link, all, filter_fun)
        cached_nodes = get(cache, cache_key, nothing)

        if cached_nodes !== nothing
            for i in cached_nodes
                # NB: node_traversal_cache(node)[cache_name(scale, symbol, link, filter_fun)] is a Vector of nodes corresponding to the traversal filters applied.
                val_ = try
                    g(i)
                catch e
                    error("Issue in function $f for node $(node_id(node)).")
                    rethrow(e)
                end
                push!(val, val_)
            end
            return val
        end
    end

    if no_node_filters(scale, symbol, link, filter_fun)
        traverse_no_filter(node, g, val, recursivity_level)
        return val
    end

    traverse_(node, g, val, scale, symbol, link, filter_fun, all, recursivity_level)

    return val
end

# Actual workhorse:
function traverse_(node::Node, f::Function, val, scale, symbol, link, filter_fun, all, recursivity_level)
    if recursivity_level == 0
        return
    else
        recursivity_level -= 1
    end

    # Else we traverse the mtg:
    if is_filtered(node, scale, symbol, link, filter_fun)
        val_ = try
            f(node)
        catch e
            println("Issue in function $f for node $(node_id(node)).")
            rethrow(e)
        end

        push!(val, val_)
    elseif !all
        return val # When `all=false`, we have to stop when a node is filtered out
    end

    if !isleaf(node)
        for chnode in children(node)
            traverse_(chnode, f, val, scale, symbol, link, filter_fun, all, recursivity_level)
        end
    end
end

# Used for the do...end block notation
function traverse!(
    f::Function,
    node::Node,
    args...;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing,
    all=true,
    recursivity_level=Inf,
)
    traverse!(node, f, args...; scale=scale, symbol=symbol, link=link, filter_fun=filter_fun, all=all, recursivity_level=recursivity_level)
end

# And with the non-mutating version:
function traverse(
    f::Function,
    node::Node,
    args...;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing,
    all=true, type=Any,
    recursivity_level=Inf,
)
    traverse(node, f, args...; scale=scale, symbol=symbol, link=link, filter_fun=filter_fun, all=all, type=type, recursivity_level=recursivity_level)
end
