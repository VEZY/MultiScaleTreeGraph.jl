"""
    is_segment(node)

Checks if a node (n) has only one child (n+1). This is usefull to simplify a complex mtg to
become an mtg with nodes only at the branching points, has it is often measured on the field.

The function also takes care of passing the link of the node (n) to its child (n+1) if the
node (n) branches or decompose its parent (n-1). This allows a conservation of the relationships
as they previously were in the mtg.

See [`delete_nodes!`](@ref) for an example of application.
"""
function is_segment!(node)
    if !isleaf(node) && !isroot(node) && length(node.children) == 1
        # We keep the root and the leaves, but want to delete the nodes with no branching.
        # We recognise them because they have only one child.

        # If it's a node that branches, set its unique child as the branching node instead:
        if node.MTG.link == "+"
            node_MTG = node[1].MTG
            node[1].MTG = typeof(node_MTG)("+", node_MTG.symbol, node_MTG.index, node_MTG.scale)
        end

        # If it's a node that decompose ("/"), set its unique child as the decomposing node:
        if node.MTG.link == "/"
            node_MTG = node[1].MTG
            node[1].MTG = typeof(node_MTG)("/", node_MTG.symbol, node_MTG.index, node_MTG.scale)
        end

        # And return true to delete it:
        return true
    end
    return false
end
