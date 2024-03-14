"""
    is_segment(node)

Checks if a node (n) has only one child (n+1). This is usefull to simplify a complex mtg to
become an mtg with nodes only at the branching points, has it is often measured on the field.

The function also takes care of passing the link of the node (n) to its child (n+1) if the
node (n) branches or decompose its parent (n-1). This allows a conservation of the relationships
as they previously were in the mtg.

See [`delete_nodes!`](@ref) for an example of application.
"""
function is_segment!(node::Node{N,A}) where {N<:AbstractNodeMTG,A}
    if !isleaf(node) && !isroot(node) && !isroot(parent(node)) && length(children(node)) == 1
        # We keep the root and the leaves, but want to delete the nodes with no branching.
        # We recognise them because they have only one child. Also we want to keep the very
        # first node even if it has only one child.

        # If there is only one child but it is branching:
        if node_mtg(node[1]).link == "+"
            return false
        end

        # If it's a node that branches, set its unique child as the branching node instead:
        if node_mtg(node).link == "+"
            node_MTG = node_mtg(node[1])
            node_mtg!(node[1], N("+", node_MTG.symbol, node_MTG.index, node_MTG.scale))
        end

        # If it's a node that decompose ("/"), set its unique child as the decomposing node:
        if node_mtg(node).link == "/"
            node_MTG = node_mtg(node[1])
            node_mtg!(node[1], N("/", node_MTG.symbol, node_MTG.index, node_MTG.scale))
        end

        # And return true to delete it:
        return true
    end
    return false
end

"""
    filter_fun_nothing(filter_fun, ignore_nothing, attr_keys)

Returns a new filtering function that adds a filter on the keys value for `nothing` if
`ignore_nothing` is `true`
"""
function filter_fun_nothing(filter_fun, ignore_nothing, attr_keys)
    # Change the filtering function if we also want to remove nodes with nothing values.
    if ignore_nothing
        if filter_fun !== nothing
            filter_fun_ =
                function (node)
                    all([unsafe_getindex(node, i) !== nothing for i in attr_keys]) && filter_fun(node)
                end
        else
            filter_fun_ =
                function (node)
                    all([unsafe_getindex(node, i) !== nothing for i in attr_keys])
                end
        end
    else
        filter_fun_ = filter_fun
    end

    filter_fun_
end


function filter_fun_nothing(filter_fun, ignore_nothing, attr_keys::T) where {T<:Union{Symbol,String}}
    filter_fun_nothing(filter_fun, ignore_nothing, [attr_keys])
end
