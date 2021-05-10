"""
    @mutate_node!(node, exprs...)

Mutate a node in place.

# Arguments

# Examples

```julia
# Importing the mtg from the github repo:
mtg,classes,description,features =
    read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

# Compute a new attribute with the scales and add 2 to its values:
@mutate_node!(mtg, scaling = node.scales .+ 2)

# Compute several new attributes, some based on others:
@mutate_node!(mtg, x = length(node.name), y = node.x + 2, z = sum(node.y))
```
"""
macro mutate_node!(node, exprs...)
    arguments = (exprs...,)
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
>julia rewrite_expr!(test)
>julia test
:(node.attributes.x = node.name)

>julia test = :(x = node.foo)
>julia rewrite_expr!(test)
>julia test
:(node.attributes.x = node.attributes.foo)
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
