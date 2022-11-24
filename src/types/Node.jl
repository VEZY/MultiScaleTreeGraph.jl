"""
    Node(MTG<:AbstractNodeMTG)
    Node(parent::Node, MTG<:AbstractNodeMTG)
    Node(id::Int, MTG<:AbstractNodeMTG, attributes)
    Node(name::String, id::Int, MTG<:AbstractNodeMTG, attributes)
    Node(id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes)
    Node(name::String, id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes)
    Node(
        name::String,
        id::Int,
        parent::Node,
        children::Union{Nothing,Dict{Int,Node}},
        siblings::Union{Nothing,Dict{Int,Node}},
        MTG<:AbstractNodeMTG,
        attributes
    )

Type that defines an MTG node (*i.e.* an element) with the name of the node, its unique id,
its parent (only if its not the root node), children, MTG encoding (see [`NodeMTG`](@ref) or
[`MutableNodeMTG`](@ref)) and attributes.

The node is an entry point to a Mutli-Scale Tree Graph, meaning we can move through the MTG from any
of its node. The root node is the node without parent. A leaf node is a node without any children.
Root and leaf nodes are used with their computer science meaning throughout the package, not in the
biological sense.

# Examples

```julia
mtg = Node(NodeMTG("/", "Plant", 1, 1))
internode = Node(
    mtg,
    NodeMTG("/", "Internode", 1, 2)
)
mtg
```
"""
mutable struct Node{T<:AbstractNodeMTG,A}
    "Name of the node. Should be unique in the MTG."
    name::String
    "Node unique ID"
    id::Int
    "Parent node."
    parent::Union{Nothing,Node}
    "Dictionary of children nodes, or Nothing if no children."
    children::Union{Nothing,Dict{Int,Node}}
    "Dictionary of sibling(s) nodes if any, or else Nothing. Can be Nothing if not computed too."
    siblings::Union{Nothing,Dict{Int,Node}}
    "MTG encoding (see [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref))."
    MTG::T
    "Node attributes. Can be anything really."
    attributes::A
end

# Shorter way of instantiating a Node:

# - for the root:
Node(name::String, id::Int, MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(name, id, nothing, nothing, nothing, MTG, attributes)

# If the name is not given, we compute one from the id:
Node(id::Int, MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(join(["node_", id]), id, MTG, attributes)
# If the id is not given, it is the root node, so we use 1
Node(MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(1, MTG, attributes)

# Special case for the NamedTuple and MutableNamedTuple, else it overspecializes and we
# can't mutate attributes, i.e. we get somthing like
# Node{NodeMTG,MutableNamedTuple{(:a,), Tuple{Base.RefValue{Int64}}}} instead of just:
# Node{NodeMTG,MutableNamedTuple}
function Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    Node{typeof(MTG),MutableNamedTuple}(name, id, nothing, nothing, nothing, MTG, attributes)
end

function Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    Node{typeof(MTG),NamedTuple}(name, id, nothing, nothing, nothing, MTG, attributes)
end

# - for all others:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes) where {M<:AbstractNodeMTG}
    node = Node(name, id, parent, nothing, nothing, MTG, attributes)
    addchild!(parent, node)
    return node
end

# Idem for MutableNamedTuple here:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    node = Node{typeof(MTG),MutableNamedTuple}(name, id, parent, nothing, nothing, MTG, attributes)
    addchild!(parent, node)
    return node
end

# Idem, if the name is not given, we compute one from the id:
Node(id::Int, parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(join(["node_", id]), id, parent, MTG, attributes)
# If the id is not given, it is the root node, so we use 1
Node(parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(new_id(get_root(parent)), parent, MTG, attributes)

# Only the MTG is given, by default we use Dict as attributes:
Node(MTG::T) where {T<:AbstractNodeMTG} = Node(1, MTG, Dict{Symbol,Any}())

# Only the MTG and parent are given, by default we use the parent attribute type:
function Node(parent::Node, MTG::T) where {T<:AbstractNodeMTG}
    Node(parent, MTG, typeof(parent.attributes)())
end

## AbstractTrees compatibility:

# Set the methods for Node:
AbstractTrees.children(node::Node{T,A}) where {T,A} = isleaf(node) ? Vector{Node{T,A}}() : collect(values(node.children))
AbstractTrees.nodevalue(node::Node{T,A}) where {T,A} = node.attributes
Base.parent(node::Node{T,A}) where {T,A} = isdefined(node, :parent) ? node.parent : nothing
AbstractTrees.parent(node::Node{T,A}) where {T,A} = Base.parent(node)
AbstractTrees.childrentype(node::Node{T,A}) where {T,A} = Vector{Node{T,A}}
AbstractTrees.childtype(node::Node{T,A}) where {T,A} = Node{T,A}

# Set the traits for Node:
# AbstractTrees.ParentLinks(::Type{<:Node{T,D}}) where {T,D} = AbstractTrees.StoredParents()
AbstractTrees.ParentLinks(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = AbstractTrees.StoredParents()
AbstractTrees.SiblingLinks(::Type{Node{T,D}}) where {T,D} = AbstractTrees.StoredSiblings()
AbstractTrees.ChildIndexing(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = IndexedChildren()
AbstractTrees.NodeType(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = HasNodeType()
AbstractTrees.nodetype(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = Node{T,A}
# AbstractTrees.parentlinks(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = AbstractTrees.StoredParents()
# AbstractTrees.siblinglinks(::Type{Node{T,D}}) where {T,D} = AbstractTrees.StoredSiblings()

function AbstractTrees.nextsibling(node::Node)
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

function AbstractTrees.prevsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    node.parent === nothing && return nothing

    all_siblings = children(node.parent)
    # Get the index of the current node in the siblings:
    node_index = findfirst(x -> x == node, all_siblings)
    if node_index > 1
        all_siblings[node_index-1]
    else
        nothing
    end
end

# Iterations

Base.IteratorEltype(::Type{<:TreeIterator{Node{T,A}}}) where {T<:AbstractNodeMTG,A} = Base.HasEltype()
Base.eltype(::Type{<:TreeIterator{Node{T,A}}}) where {T<:AbstractNodeMTG,A} = Node{T,A}

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T,D}}) where {T,D} = Node{T,D}
