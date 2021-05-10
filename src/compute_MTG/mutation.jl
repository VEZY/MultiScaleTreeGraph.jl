"""
    @mutate_mtg!(node, args...,kwargs...)

Mutate the mtg nodes in place.

# Arguments

- `mtg`: the mtg to mutate
- `args...`: The computations to apply to the nodes (see examples)
- `kwargs...`: Optional keyword arguments for traversing and filtering (see details)


# Details

As for [`descendants`](@ref) and [`ancestors`](@ref), kwargs can be any filter from:

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
- `traversal`: The type of tree traversal. By default it is using `AbstractTrees.PreOrderDFS`.


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
    # Get the value of the filters if any:
    flt, kwargs, args = MTG.parse_macro_args(arguments)

    expr = quote
        # Check the filters consistency with the mtg:
        check_filters(mtg,scale = $(flt.scale), symbol = $(flt.symbol), link = $(flt.link))
        # Traverse the mtg:
        traversed_mtg = $(kwargs[:traversal])(mtg)
        for i in traversed_mtg
            if is_filtered(i, $(flt.scale), $(flt.symbol), $(flt.link), $(flt.filter_fun))
                @mutate_node!(i, $(arguments...))
            elseif !$(kwargs[:all])
                # In this case (all == false) we stop as soon as we reached the
                # first filtered-out value. The default behavior is defined in parse_macro_args
                # and is equal to true.
                break
            end
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
        if isa(x,Expr) && x.head == :. && occursin("node.",arg) && !occursin(string(node_name),arg)
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
