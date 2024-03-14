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
traverse!(mtg, x -> isleaf(x) ? println(x.name," is a leaf") : nothing)
node_5 is a leaf
node_7 is a leaf

# We can also use the `do...end` block notation when we have a complex set of instructions:
traverse!(mtg) do x
    if isleaf(x)
         println(x.name," is a leaf")
    end
end
```
"""
traverse!, traverse

function traverse!(node::Node, f::Function, args...; scale=nothing, symbol=nothing, link=nothing, filter_fun=nothing, all=true, recursivity_level=Inf)
    if !isempty(args)
        g = node -> f(node, args...)
    else
        g = f
    end

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    if haskey(node_traversal_cache(node), cache_name(scale, symbol, link, all, filter_fun))
        for i in node_traversal_cache(node)[cache_name(scale, symbol, link, all, filter_fun)]
            # NB: node_traversal_cache(node)[cache_name(scale, symbol, link, filter_fun)] is a Vector of nodes corresponding to the traversal filters applied.
            g(i)
        end
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

    val = Array{type,1}()
    # NB: f has to return someting here, if its a mutating function, use traverse!

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    if haskey(node_traversal_cache(node), cache_name(scale, symbol, link, all, filter_fun))
        for i in node_traversal_cache(node)[cache_name(scale, symbol, link, all, filter_fun)]
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