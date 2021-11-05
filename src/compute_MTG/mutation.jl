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
# Importing an mtg from the package:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

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
    flt, kwargs, args = MultiScaleTreeGraph.parse_macro_args(arguments)

    expr = quote
        # Check the filters consistency with the mtg:
        check_filters($(mtg), scale = $(flt.scale), symbol = $(flt.symbol), link = $(flt.link))
        # Traverse the mtg:
        traversed_mtg = $(kwargs[:traversal])($(mtg))
        for i00000000 in traversed_mtg
            # NB: using i00000000 to avoid naming clash with variables when using rewrite_expr!(i,...)
            if is_filtered(i00000000, $(flt.scale), $(flt.symbol), $(flt.link), $(flt.filter_fun))
                @mutate_node!(i00000000, $(args...))
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
# Importing an mtg from the package:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

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
    rewrite_expr!(:($node), arguments)
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
test = :(x = node.name)
MultiScaleTreeGraph.rewrite_expr!(:mtg,test)
test
# :(mtg.attributes[:x] = mtg.name)

test = :(x = node.foo)
MultiScaleTreeGraph.rewrite_expr!(:mtg,test)
test
# :(mtg.attributes[:x] = mtg.attributes[:foo])

test = :(x = node.MTG.symbol)
MultiScaleTreeGraph.rewrite_expr!(:mtg,test)
test
# :(mtg.attributes[:x] = mtg.MTG.symbol)
```
"""
function rewrite_expr!(node_name, arguments::Expr)

    # For the Left-Hand Side (LHS) when using the form `x = RHS`. The LHS is treated
    # differently here because `x` must be treated as a field or an attribute of the node,
    # and never as an object from another module.
    # On the contrary the RHS can use variables from elsewhere, e.g. a constant defined in
    # the REPL
    if isa(arguments, Expr) && arguments.head == :(=) && isa(arguments.args[1], Symbol)
        arguments.args[1] = :($(node_name).attributes[$(QuoteNode(arguments.args[1]))])
        # if !(Symbol(replace(arg,"node."=>"")) in fieldnames(Node))
        # x.args[1] = :(node.attributes)
    end

    # For the RHS:
    for x in arguments.args
        arg = string(x)
        if isa(x, Expr) &&
            (x.head == :. || x.head == :ref) &&
            occursin(r"^node", arg) &&
            !occursin(string(node_name), arg)
            # x here is defined either as node.variable or node[:variable], we must replace
            # by node_name[:variable]
            if !(Symbol(replace(arg, "node." => "")) in fieldnames(Node))
                if any(match.(Regex.("\\." .* string.(fieldnames(Node))), arg) .!= nothing)
                    # If the expression contains node attributes, only replace the node name
                    # because they are reserved keywords, e.g.: node.MTG.scale becomes
                    # node_name.MTG.scale
                    x.args[1].args[1] = :($(node_name))
                else
                    x.args[1] = :($(node_name))
                    x.head = :ref
                end
            else
                x.args[1] = :($(node_name))
            end
        elseif isa(x, Expr) && x.head == :call && occursin("node", arg)
            # Call to a function, and we pass node as argument
            for i in 1:length(x.args)
                # The node is given as is to the function, e.g. fn(node):
                x.args[i] == :node ? x.args[i] = :($(node_name)) : nothing
            end
            rewrite_expr!(node_name, x)
        else
            rewrite_expr!(node_name, x)
        end
    end
end

function rewrite_expr!(node_name, arguments)
    nothing
end

function rewrite_expr!(node_name, arguments::Tuple)
    for x in arguments
        rewrite_expr!(node_name, x)
    end
end
