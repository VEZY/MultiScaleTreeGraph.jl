
# Mutation of the attributes of a node at the node level, with attributes as MutableNamedTuple:

"""
    append!(node::Node{NodeMTG, <:MutableNamedTuple}, attr)
    append!(node::Node{NodeMTG, <:Dict}, attr)

Append new attributes to a node attributes.
"""
function Base.append!(node::Node{NodeMTG, T}, attr) where T<:MutableNamedTuple
    node.attributes = MutableNamedTuple{(keys(node.attributes)...,keys(attr)...)}((values(node.attributes)...,values(attr)...))
end

function Base.append!(node::Node{NodeMTG, T}, attr) where T<:NamedTuple
    node.attributes = NamedTuple{(keys(node.attributes)...,keys(attr)...)}((values(node.attributes)...,values(attr)...))
end

# [...] or with attributes as Dict:
function Base.append!(node::Node{NodeMTG, T}, attr::T) where T<:AbstractDict
    merge!(node.attributes, attr)
end

# And ensure compatibility between both so a script wouldn't be broken if we just change the
# type of the attributes:
function Base.append!(node::Node{NodeMTG, <:AbstractDict}, attr)
    merge!(node.attributes, Dict(zip(keys(attr),values(attr))))
end



macro format_expr(node, args...)
    arguments = (args...,)
    rewrite_expr!(arguments)
    println(arguments)
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
function rewrite_expr!(arguments::Expr)

    # For the Left-Hand Side (LHS)
    if isa(arguments,Expr) && arguments.head == :(=) && isa(arguments.args[1],Symbol)
        arguments.args[1] = :(node.attributes.$(arguments.args[1]))
        # if !(Symbol(replace(arg,"node."=>"")) in fieldnames(Node))
        # x.args[1] = :(node.attributes)
    end

    # For the RHS:
    for x in arguments.args
        arg = string(x)
        if isa(x,Expr) && x.head == :. && occursin("node.",arg) && !(Symbol(replace(arg,"node."=>"")) in fieldnames(Node))
            x.args[1] = :(node.attributes)
        else
            rewrite_expr!(x)
        end
    end
end

function rewrite_expr!(arguments)
    nothing
end

function rewrite_expr!(arguments::Tuple)
    for x in arguments
        rewrite_expr!(x)
    end
end
