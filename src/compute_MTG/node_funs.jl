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
    children(node::Node)

Return the immediate children of `node`.
"""
function children(node::Node)
    isleaf(node) ? Vector{Node}() : collect(values(node.children))
end

"""
    ordered_children(node)

Return the children as an array, ordered first by "+"
"""
function ordered_children(node)
    links_chnodes = Array{Node,1}()
    for (name, chnode) in node.children
        if chnode.MTG.link == "+"
            pushfirst!(links_chnodes, chnode)
        else
            push!(links_chnodes, chnode)
        end
    end
    return links_chnodes
end

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
Add a new child to a parent node, and add the parent node as the parent.

See also [`insert_child!`](@ref) for a more user-friendly approach.
"""
function addchild!(parent::Node, id::Int, MTG::M, attributes) where {M<:AbstractNodeMTG}
    child = Node(id, parent, MTG, attributes)
    addchild!(parent, child)
end

function addchild!(parent::Node, id::Int, MTG::M) where {M<:AbstractNodeMTG}
    child = Node(id, parent, MTG)
    addchild!(parent, child)
end

function addchild!(parent::Node, child::Node; force = false)

    if child.parent === missing || force == true
        child.parent = parent
    elseif child.parent != parent && force == false
        error("The node already has a parent. Hint: use `force=true` if needed.")
    end

    if parent.children === nothing
        parent.children = Dict{Int,Node}(child.id => child)
    else
        push!(parent.children, child.id => child)
    end
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
    nextsibling(node::Node)

Return the next sibling of `node` (or `nothing` if non-existant).
"""
function nextsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent === nothing && return nothing

    all_siblings = children(node.parent)
    # Get the index of the current node in the siblings:
    node_index = findfirst(x -> x == node, all_siblings)
    if node_index < length(all_siblings)
        all_siblings[node_index+1]
    else
        nothing
    end
end

"""
    prevsibling(node::Node)

Return the previous sibling of `node` (or `nothing` if non-existant).
"""
function prevsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent === nothing && return nothing

    all_siblings = children(node.parent)
    # Get the index of the current node in the siblings:
    node_index = findfirst(x -> x == node, all_siblings)
    if node_index > 0
        all_siblings[node_index-1]
    else
        nothing
    end
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
