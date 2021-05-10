"""
    @mutate_mtg!(node, args...)

Mutate the mtg nodes in place.

# Arguments

- `mtg`: the mtg to mutate
- `args...`: The computations to apply to the nodes (see examples)

# Examples

```julia
# Importing the mtg from the github repo:
mtg,classes,description,features =
    read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

# Compute a new attribute with the scales and add 2 to its values:
@mutate_mtg!(mtg, scaling = node.scales .+ 2)

# Compute several new attributes, some based on others:
@mutate_mtg!(mtg, x = length(node.name), y = node.x + 2, z = sum(node.y))

# We can also use it without parenthesis:

@mutate_mtg! mtg x = length(node.name)
```
"""
macro mutate_mtg!(mtg, args...)
    arguments = (args...,)
    expr = quote
        traversed_mtg = PreOrderDFS(mtg)
        for i in traversed_mtg
            @mutate_node!(i, x = length(node.name), y = node.x + 2, z = sum(node.y))
        end
    end
    esc(expr)
end


"""
    @mutate_node!(node, args...)

Mutate a single node in place.

# Arguments

- `node`: the node to mutate
- `args...`: The computations to apply to the node (see examples)

# See also

[`@mutate_mtg!`](@ref) to mutate all nodes of an mtg.

# Examples

```julia
# Importing the mtg from the github repo:
mtg,classes,description,features =
    read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

# Compute a new attribute with the scales and add 2 to its values:
@mutate_node!(mtg, scaling = node.scales .+ 2)

# The computation is only applied to the root node. To apply it to all nodes,
# see @mutate_mtg!

# Compute several new attributes, some based on others:
@mutate_node!(mtg, x = length(node.name), y = node.x + 2, z = sum(node.y))

# We can also use it without parenthesis:

@mutate_node! mtg x = length(node.name)
```
"""
macro mutate_node!(node, args...)
    arguments = (args...,)
    rewrite_expr!(:($node),arguments)
    expr = quote $(arguments...); nothing end
    esc(expr)
end

"""
    rewrite_expr!(arguments)

Re-write the call to the variables of a node in an expression to match their location: leave
it as it is if the variable is a node field, or add `attributes` after the node if it is
an attribute.

# Examples

```
>julia test = :(x = node.name)
>julia MTG.rewrite_expr!(:mtg,test)
>julia test
:(mtg.attributes[:x] = mtg.name)

>julia test = :(x = node.foo)
>julia MTG.rewrite_expr!(:mtg,test)
>julia test
:(mtg.attributes[:x] = mtg.attributes[:foo])
```
"""
function rewrite_expr!(node_name,arguments::Expr)

    # For the Left-Hand Side (LHS)
    if isa(arguments,Expr) && arguments.head == :(=) && isa(arguments.args[1],Symbol)
        arguments.args[1] = :($(node_name).attributes[$(QuoteNode(arguments.args[1]))])
        # if !(Symbol(replace(arg,"node."=>"")) in fieldnames(Node))
        # x.args[1] = :(node.attributes)
    end

    # For the RHS:
    for x in arguments.args
        arg = string(x)
        if isa(x,Expr) && x.head == :. && occursin("node.",arg)
            if !(Symbol(replace(arg,"node."=>"")) in fieldnames(Node))
                x.args[1] = :($(node_name).attributes)
                x.head = :ref
            else
                x.args[1] = :($(node_name))
            end
        else
            rewrite_expr!(node_name,x)
        end
    end
end

function rewrite_expr!(node_name,arguments)
    nothing
end

function rewrite_expr!(node_name,arguments::Tuple)
    for x in arguments
        rewrite_expr!(node_name,x)
    end
end
