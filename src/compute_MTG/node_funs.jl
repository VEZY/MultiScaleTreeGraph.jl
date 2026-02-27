"""
    isleaf(node::Node)
Test whether a node is a leaf or not.
"""
isleaf(node::Node) = isempty(children(node))

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
        return last(children(node))
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

@inline function _columnar_store_or_nothing(node::Node)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || return nothing
    return _store_for_node_attrs(attrs)
end

function _subtree_has_node_id_conflict(node::Node, store::MTGAttributeStore)
    nid = node_id(node)
    if nid <= length(store.node_bucket) && store.node_bucket[nid] != 0
        return true
    end
    for ch in children(node)
        _subtree_has_node_id_conflict(ch, store) && return true
    end
    return false
end

function _merge_columnar_subtree_into_store!(node::Node, target_store::MTGAttributeStore)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || return false
    snapshot = Dict{Symbol,Any}(pairs(attrs))
    _add_node_with_attrs!(target_store, node_id(node), symbol(node), snapshot)
    attrs.ref.store = target_store
    attrs.ref.node_id = node_id(node)
    empty!(attrs.staged)
    for ch in children(node)
        _merge_columnar_subtree_into_store!(ch, target_store) || return false
    end
    return true
end

function _try_merge_root_subtree_store!(child::Node, parent_store::MTGAttributeStore, child_store::MTGAttributeStore)
    parent_store === child_store && return true
    _subtree_has_node_id_conflict(child, parent_store) && return false
    return _merge_columnar_subtree_into_store!(child, parent_store)
end

@inline function _maybe_recolumnarize_after_attach!(p::Node, child::Node, child_was_root::Bool)
    child_was_root || return nothing
    p_store = _columnar_store_or_nothing(p)
    c_store = _columnar_store_or_nothing(child)
    if p_store !== nothing && c_store !== nothing && p_store !== c_store
        # Fast path: re-bind only the attached subtree into the parent store.
        # Fallback to full re-columnarization when IDs collide.
        _try_merge_root_subtree_store!(child, p_store, c_store) || columnarize!(get_root(p))
    end
    return nothing
end

function addchild!(p::Node{N,A}, child::Node; force=false) where {N<:AbstractNodeMTG,A}
    child_was_root = parent(child) === nothing

    if child_was_root || force == true
        reparent!(child, p)
    elseif parent(child) != p && force == false
        error("The node already has a parent. Hint: use `force=true` if needed.")
    end

    push!(children(p), child)
    _maybe_recolumnarize_after_attach!(p, child, child_was_root)

    return child
end


"""
Find the root node of a tree, given any node in the tree.
"""
function get_root(node::Node)
    root = node
    while !isroot(root)
        root = parent(root)
    end
    return root
end

"""
    siblings(node::Node)

Return the siblings of `node` as a vector of nodes (or `nothing` if non-existant).
"""
function siblings(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent_ = parent(node)
    parent_ === nothing && return nothing

    all_siblings = children(parent_)
    nsiblings = length(all_siblings)
    nsiblings <= 1 && return similar(all_siblings, 0)

    out = Vector{eltype(all_siblings)}(undef, nsiblings - 1)
    j = 1
    @inbounds for sibling in all_siblings
        if sibling !== node
            out[j] = sibling
            j += 1
        end
    end
    resize!(out, j - 1)
    return out
end

"""
    lastsibling(node::Node)

Return the last sibling of `node` (or `nothing` if non-existant).
"""
function lastsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent_ = parent(node)
    parent_ === nothing && return nothing
    return last(children(parent_))
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
