"""
    isleaf(node::Node)
Test whether a node is a leaf or not.
"""
isleaf(node::Node) = node.children === nothing


"""
    isroot(node::Node)
Return `true` if `node` is the root node (meaning, it has no parent).
"""
isroot(node::Node) = node.parent === nothing

"""
    lastchild(node::Node)

Get the last child of `node`, or `nothing` if the node is a leaf.

"""
function lastchild(node::Node)
    if isleaf(node)
        return nothing
    else
        allchildren = node.children
        return allchildren[maximum(keys(allchildren))]
    end
end

"""
    addchild!(parent::Node, id::Int, MTG<:AbstractNodeMTG, attributes)
    addchild!(parent::Node, MTG<:AbstractNodeMTG, attributes)
    addchild!(parent::Node, MTG<:AbstractNodeMTG)
    addchild!(parent::Node, child::Node; force=false)

Add a new child to a parent node, and add the parent node as the parent.
Returns the child node.

See also [`insert_child!`](@ref), or directly [`Node`](@ref) where we 
can pass the parent, and it uses `addchild!` under the hood.

# Examples
```julia
# Create a root node:
mtg = MultiScaleTreeGraph.Node(
    NodeMTG("/", "Plant", 1, 1),
    Dict{Symbol,Any}()
)

roots = addchild!(
    mtg, 
    NodeMTG("+", "RootSystem", 1, 2)
)

stem = addchild!(
    mtg, 
    NodeMTG("+", "Stem", 1, 2)
)

phyto = addchild!(
    stem, 
    NodeMTG("/", "Phytomer", 1, 3)
)

mtg
```
"""
function addchild!(parent::Node, id::Int, MTG::M, attributes; type=GenericNode()) where {M<:AbstractNodeMTG}
    child = Node(id, parent, MTG, attributes; type=type)
    return child
end

function addchild!(parent::Node, MTG::M, attributes; type=GenericNode()) where {M<:AbstractNodeMTG}
    child = Node(parent, MTG, attributes; type=type)
    return child
end

function addchild!(parent::Node, MTG::M; type=GenericNode()) where {M<:AbstractNodeMTG}
    child = Node(parent, MTG; type=type)
    return child
end

function addchild!(parent::Node, child::Node; force=false)

    if child.parent === missing || force == true
        child.parent = parent
    elseif child.parent != parent && force == false
        error("The node already has a parent. Hint: use `force=true` if needed.")
    end

    if parent.children === nothing
        parent.children = Node[child]
    else
        # If the new node is branching, we at it before the other children,
        # this is because branching children should be printed and written first
        # in the MTG file, else it would lead to errors in the links:
        if child.MTG.link == "+"
            pushfirst!(parent.children, child)
        else
            push!(parent.children, child)
        end
    end

    return child
end


"""
Find the root node of a tree, given any node in the tree.
"""
function get_root(node::Node)
    if isroot(node)
        return (node)
    else
        get_root(node.parent)
    end
end

"""
    siblings(node::Node)

Return the siblings of `node` as a vector of nodes (or `nothing` if non-existant).
"""
function siblings(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent === nothing && return nothing

    all_siblings = children(node.parent)

    all_siblings[findall(x -> x != node, all_siblings)]
end

"""
    lastsibling(node::Node)

Return the last sibling of `node` (or `nothing` if non-existant).
"""
function lastsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent === nothing && return nothing

    all_siblings = children(node.parent)
    # Get the index of the current node in the siblings:

    all_siblings[maximum(keys(all_siblings))]
end

"""
    new_id(mtg)
    new_id(mtg, max_id)

Make a new unique identifier by incrementing on the maximum node id.
Hint: prefer using `max_id = max_id(mtg)` and then `new_id(mtg, max_is)` for performance
if you do it repeatidely.
"""
function new_id(max_id::Int)
    max_id + 1
end

function new_id(mtg::Node)
    new_id(max_id(mtg))
end
