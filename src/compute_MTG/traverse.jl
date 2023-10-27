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

# Returns

Nothing for `traverse!` because it mutates the (sub-)tree in-place, or an Array of whatever
the function returns for `traverse`.

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

function traverse!(
    node::Node,
    f::Function,
    args...;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing
)

    if !isempty(args)
        g = node -> f(node, args...)
    else
        g = f
    end

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    if haskey(node.traversal_cache, cache_name(scale, symbol, link, filter_fun))
        for i in node.traversal_cache[cache_name(scale, symbol, link, filter_fun)]
            # NB: node.traversal_cache[cache_name(scale, symbol, link, filter_fun)] is a Vector of nodes corresponding to the traversal filters applied.
            g(i)
        end
        return
    end

    traverse!_(node, g, scale, symbol, link, filter_fun)
end

function traverse!_(node::Node, f::Function, scale, symbol, link, filter_fun)
    if is_filtered(node, scale, symbol, link, filter_fun)
        try
            f(node)
        catch e
            println("Issue in function $f for node #$(node.id).")
            throw(e)
        end
    end

    if !isleaf(node)
        for chnode in children(node)
            traverse!_(chnode, f, scale, symbol, link, filter_fun)
        end
    end
end


# Non-mutating version:
# Set-up array of value and call the workhorse (traverse_)
function traverse(
    node::Node,
    f::Function,
    args...;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing
)

    val = []
    # NB: f has to return someting here, if its a mutating function, use traverse!
    traverse_(
        node,
        f,
        val,
        args...;
        scale=scale, symbol=symbol, link=link, filter_fun=filter_fun
    )
    return val
end

# Actual workhorse:
function traverse_(
    node::Node,
    f::Function,
    val,
    args...;
    scale, symbol, link, filter_fun
)

    # If the node has already a cache of the traversal, we use it instead of traversing the mtg:
    if haskey(node.traversal_cache, cache_name(scale, symbol, link, filter_fun))
        for i in node.traversal_cache[cache_name(scale, symbol, link, filter_fun)]
            # NB: node.traversal_cache[cache_name(scale, symbol, link, filter_fun)] is a Vector of nodes corresponding to the traversal filters applied.
            val_ = try
                f(i, args...)
            catch e
                error("Issue in function $f for node $(node.id).")
            end
            push!(val, val_)
        end
        return
    end

    # Else we traverse the mtg:
    if is_filtered(node, scale, symbol, link, filter_fun)
        val_ = try
            f(node, args...)
        catch e
            println("Issue in function $f for node $(node.id).")
            rethrow(e)
        end

        push!(val, val_)
    end

    if !isleaf(node)
        for chnode in children(node)
            traverse_(
                chnode,
                f,
                val,
                args...;
                scale=scale, symbol=symbol, link=link, filter_fun=filter_fun
            )
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
    filter_fun=nothing
)
    traverse!(node, f, args...; scale=scale, symbol=symbol, link=link, filter_fun=filter_fun)
end

# And with the non-mutating version:
function traverse(
    f::Function,
    node::Node,
    args...;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing
)
    traverse(node, f, args...; scale=scale, symbol=symbol, link=link, filter_fun=filter_fun)
end

# Same here but without arguments
function traverse(
    f::Function,
    node::Node;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    filter_fun=nothing
)
    traverse(node, f; scale=scale, symbol=symbol, link=link, filter_fun=filter_fun)
end