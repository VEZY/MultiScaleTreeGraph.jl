"""
    isleaf(node::Node)
Test whether a node is a leaf or not.
"""
isleaf(node::Node) = isempty(node.children)


"""
    isroot(node::Node)
Return `true` if `node` is the root node (meaning, it has no parent).
"""
isroot(node::Node) = !isdefined(node, :parent)

"""
    children(node::Node)

Return the immediate children of `node`.
"""
AbstractTrees.children(node::Node) = node.children
