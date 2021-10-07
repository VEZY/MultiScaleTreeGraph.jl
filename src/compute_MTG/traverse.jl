"""
    traverse!(node::Node, f::Function[, args...])
    traverse(node::Node, f::Function[, args...])

Traverse the nodes of a (sub-)tree, given any starting node in the tree, and apply a function
which is either mutating (use `traverse!`) or not (use `traverse`).


# Arguments

- `node::Node`: An MTG node (*e.g.* the whole mtg returned by `read_mtg()`).
- `f::Function`: a function to apply over each node
- `args::Any`: any argument to pass to the function

# Returns

Nothing for `traverse!` because it mutates the (sub-)tree in-place, or an Array of whatever
the function returns.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MTG))),"test","files","simple_plant.mtg")
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
function traverse!(node::Node, f::Function, args...)

    if !isempty(args)
        f(node, args...)
    else
        f(node)
    end

    if !isleaf(node)
        for chnode in ordered_children(node)
            traverse!(chnode, f, args...)
        end
    end
end

function traverse!(node::Node, f::Function)

    f(node)

    if !isleaf(node)
        for chnode in ordered_children(node)
            traverse!(chnode, f)
        end
    end
end

# Non-mutating version:
# Set-up array of value and call the workhorse (traverse_)
function traverse(node::Node, f::Function, args...)
    val = []
    # NB: f has to return someting here, if its a mutating function, use traverse!
    traverse_(node, f, val, args...)
    return val
end

# Actual workhorse:
function traverse_(node::Node, f::Function, val, args...)
    push!(val, f(node, args...))

    if !isleaf(node)
        for chnode in ordered_children(node)
            traverse_(chnode, f, args...)
        end
    end
end

# Same but with no arguments passed to the function:
function traverse(node::Node, f::Function)
    val = []
    # NB: f has to return someting here, if its a mutating function, use traverse!
    traverse_(node, f, val)
    return val
end

function traverse_(node::Node, f::Function, val)
    push!(val, f(node))

    if !isleaf(node)
        for chnode in ordered_children(node)
            traverse_(chnode, f, val)
        end
    end
end


# Used for the do...end block notation
function traverse!(f::Function, node::Node, args...)
    traverse!(node, f, args...)
end
# Same here but without arguments
function traverse!(f::Function, node::Node)
    traverse!(node, f)
end

# And with the non-mutating version:
function traverse(f::Function, node::Node, args...)
    traverse(node, f, args...)
end
# Same here but without arguments
function traverse(f::Function, node::Node)
    traverse(node, f)
end
