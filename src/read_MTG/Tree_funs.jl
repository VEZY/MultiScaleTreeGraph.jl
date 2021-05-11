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
    isleaf(node) ? () : collect(values(node.children))
end

"""
Add a new child to a parent node, and add the parent node as the parent.
"""
function addchild!(parent::Node,name::String,MTG::NodeMTG,attributes)
  child = Node(name,parent,MTG,attributes)
  addchild!(parent, child)
end

function addchild!(parent::Node,name::String,MTG::NodeMTG)
  child = Node(name,parent,MTG)
  addchild!(parent, child)
end

function addchild!(parent::Node,child::Node;force = false)

    if child.parent === missing || force == true
        child.parent = parent
    elseif child.parent != parent && force == false
        error("The node already has a parent. Hint: use `force=true` if needed.")
    end

    if parent.children === nothing
        parent.children = Dict(child.name => child)
    else
        push!(parent.children, child.name => child)
    end
end


"""
Find the root node of a tree, given any node in the tree.
"""
function getroot(node::Node)
    if isroot(node)
        return(node)
    else
        getroot(node.parent)
    end
end

"""
    siblings(node::Node)

Return the siblings of `node` as a vector of nodes (or `nothing` if non-existant).
"""
function siblings(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent !== nothing || return nothing
    # If the siblings field is not empty, return its value:
    node.siblings !== nothing && return node.siblings
    # Else, compute the siblings:
    all_siblings = children(node.parent)

    all_siblings[findall(x -> x != node, all_siblings)]
end

function nextsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent !== nothing || return nothing
    # If the siblings field is not empty, return its value:
    node.siblings !== nothing && return node.siblings
    # Else, compute the siblings:
    all_siblings = children(node.parent)
    # Get the index of the current node in the siblings:
    node_index = findfirst(x -> x == node, all_siblings)
    if node_index < length(all_siblings)
        all_siblings[node_index + 1]
    else
        nothing
    end
end
