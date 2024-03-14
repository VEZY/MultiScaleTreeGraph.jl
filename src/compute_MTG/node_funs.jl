"""
    isleaf(node::Node)
Test whether a node is a leaf or not.
"""
isleaf(node::Node) = length(children(node)) == 0

"""
    isroot(node::Node)
Return `true` if `node` is the root node (meaning, it has no parent).
"""
isroot(node::Node) = parent(node) === nothing

"""
    lastchild(node::Node)

Get the last child of `node`, or `nothing` if the node is a leaf.

"""
function lastchild(node::Node)
    if isleaf(node)
        return nothing
    else
        allchildren = children(node)
        return allchildren[maximum(keys(allchildren))]
    end
end

"""
    addchild!(p::Node, id::Int, MTG<:AbstractNodeMTG, attributes)
    addchild!(p::Node, MTG<:AbstractNodeMTG, attributes)
    addchild!(p::Node, MTG<:AbstractNodeMTG)
    addchild!(p::Node, child::Node; force=false)

Add a new child to a parent node (`p`), and add the parent node as the parent.
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
function addchild!(p::Node, id::Int, MTG::M, attributes) where {M<:AbstractNodeMTG}
    child = Node(id, p, MTG, attributes)
    return child
end

function addchild!(p::Node, MTG::M, attributes) where {M<:AbstractNodeMTG}
    child = Node(p, MTG, attributes)
    return child
end

function addchild!(p::Node, MTG::M) where {M<:AbstractNodeMTG}
    child = Node(p, MTG)
    return child
end

function addchild!(p::Node{N,A}, child::Node; force=false) where {N<:AbstractNodeMTG,A}
    if parent(child) === nothing || force == true
        reparent!(child, p)
    elseif parent(child) != p && force == false
        error("The node already has a parent. Hint: use `force=true` if needed.")
    end

    if children(p) === nothing
        rechildren!(child, Node{N,A}[child])
    else
        push!(children(p), child)
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
        get_root(parent(node))
    end
end

"""
    siblings(node::Node)

Return the siblings of `node` as a vector of nodes (or `nothing` if non-existant).
"""
function siblings(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent(node) === nothing && return nothing

    all_siblings = children(parent(node))

    return all_siblings[findall(x -> x != node, all_siblings)]
end

"""
    lastsibling(node::Node)

Return the last sibling of `node` (or `nothing` if non-existant).
"""
function lastsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent(node) === nothing && return nothing

    all_siblings = children(parent(node))
    # Get the index of the current node in the siblings:

    return all_siblings[maximum(keys(all_siblings))]
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
