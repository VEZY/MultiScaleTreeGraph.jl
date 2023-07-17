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
        children::Vector{Node},
        MTG<:AbstractNodeMTG,
        attributes
    )
    Node(
        name::String,
        id::Int,
        parent::Node,
        children::Vector{Node},
        MTG<:AbstractNodeMTG,
        attributes;
        traversal_cache
    )
    

Type that defines an MTG node (*i.e.* an element) with:

- `name`: the name of the node
- `id`: its unique id
- `parent`: the parent node (if not the root node)
- `children`: an optional array of children nodes
- `MTG`: the MTG description, or encoding (see [`NodeMTG`](@ref) or
[`MutableNodeMTG`](@ref))
- `attributes`: the node attributes (see [`Attributes`](@ref)), that can be anything but 
usually a `Dict{String,Any}`
- `traversal_cache`: a cache for the traversal, used by *e.g.* [`traverse`](@ref) to traverse more efficiently particular nodes in the MTG

The node is an entry point to a Mutli-Scale Tree Graph, meaning we can move through the MTG from any
of its node. The root node is the node without parent. A leaf node is a node without any children.
Root and leaf nodes are used with their computer science meaning throughout the package, not in the
biological sense.

Note that it is possible to create a whole MTG using only the `Node` type, because it has methods
to create a node as a child of another node (see example below). 

# Examples

```julia
mtg = Node(NodeMTG("/", "Plant", 1, 1))
internode = Node(
    mtg,
    NodeMTG("/", "Internode", 1, 2)
)
# Note that the node is created with a parent, so it is not necessary to add it as a child of the `mtg ` Node

mtg
```
"""
mutable struct Node{N<:AbstractNodeMTG,A}
    "Name of the node. Should be unique in the MTG"
    name::String
    "Node unique ID"
    id::Int
    "Parent node"
    parent::Union{Nothing,Node}
    "Dictionary of children nodes, or Nothing if no children"
    children::Vector{Node{N,A}}
    "MTG encoding (see [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref))"
    MTG::N
    "Node attributes. Can be anything really"
    attributes::A
    "Cache for mtg nodes traversal"
    traversal_cache::Dict{String,Vector{Node{N,A}}}
end

# Shorter way of instantiating a Node:

function Node(name::String, id::Int, parent::Union{Nothing,Node}, children::Nothing, MTG::N, attributes::A, traversal_cache::Dict{String,Vector{Node}}) where {N<:AbstractNodeMTG,A}
    Node{N,A}(name, id, parent, Vector{Node{N,A}}(), MTG, attributes, traversal_cache)
end

# - for the root:
function Node(name::String, id::Int, MTG::T, attributes::A) where {T<:AbstractNodeMTG,A}
    Node(name, id, nothing, Vector{Node{T,A}}(), MTG, attributes, Dict{String,Vector{Node{T,A}}}())
end

# If the name is not given, we compute one from the id:
function Node(id::Int, MTG::T, attributes) where {T<:AbstractNodeMTG}
    Node(join(["node_", id]), id, MTG, attributes)
end
# If the id is not given, it is the root node, so we use 1
Node(MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(1, MTG, attributes)

# Special case for the NamedTuple and MutableNamedTuple, else it overspecializes and we
# can't mutate attributes, i.e. we get somthing like
# Node{NodeMTG,MutableNamedTuple{(:a,), Tuple{Base.RefValue{Int64}}}} instead of just:
# Node{NodeMTG,MutableNamedTuple}
function Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    Node{M,MutableNamedTuple}(name, id, nothing, Vector{Node{M,MutableNamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
end

function Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    Node{M,NamedTuple}(name, id, nothing, Vector{Node{M,NamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
end

# Add a node as a child of another node:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes::A) where {M<:AbstractNodeMTG,A}
    node = Node(name, id, parent, Vector{Node{M,A}}(), MTG, attributes, Dict{String,Vector{Node{M,A}}}())
    addchild!(parent, node)
    return node
end

# Special case for NamedTuple here:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    node = Node{M,NamedTuple}(name, id, parent, Vector{Node{M,NamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,NamedTuple}}}())
    addchild!(parent, node)
    return node
end

# Idem for MutableNamedTuple here:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    node = Node{M,MutableNamedTuple}(name, id, parent, Vector{Node{M,MutableNamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
    addchild!(parent, node)
    return node
end

# Idem, if the name is not given, we compute one from the id:
function Node(id::Int, parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG}
    Node(join(["node_", id]), id, parent, MTG, attributes)
end
# If the id is not given, it is the root node, so we use 1
function Node(parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG}
    Node(new_id(get_root(parent)), parent, MTG, attributes)
end

# Only the MTG is given, by default we use Dict as attributes:
Node(MTG::T) where {T<:AbstractNodeMTG} = Node(1, MTG, Dict{Symbol,Any}())

# Only the MTG and parent are given, by default we use the parent attribute type:
function Node(parent::Node, MTG::T) where {T<:AbstractNodeMTG}
    Node(parent, MTG, typeof(parent.attributes)())
end

## AbstractTrees compatibility:

# Set the methods for Node:
AbstractTrees.children(node::Node{T,A}) where {T,A} = node.children
AbstractTrees.nodevalue(node::Node{T,A}) where {T,A} = node.attributes
Base.parent(node::Node{T,A}) where {T,A} = isdefined(node, :parent) ? node.parent : nothing
AbstractTrees.parent(node::Node{T,A}) where {T,A} = Base.parent(node)
AbstractTrees.childrentype(node::Node{T,A}) where {T,A} = Vector{Node{T,A}}
AbstractTrees.childtype(::Type{Node{T,A}}) where {T,A} = Node{T,A}
# AbstractTrees.childstatetype(::Type{Node{T,A}}) where {T,A} = Node{T,A}

# Set the traits for Node:
# AbstractTrees.ParentLinks(::Type{<:Node{T}}) where {T} = AbstractTrees.StoredParents()
AbstractTrees.ParentLinks(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = AbstractTrees.StoredParents()
AbstractTrees.SiblingLinks(::Type{Node{T,A}}) where {T,A} = AbstractTrees.ImplicitSiblings()
AbstractTrees.ChildIndexing(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = IndexedChildren()
AbstractTrees.NodeType(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = HasNodeType()
AbstractTrees.nodetype(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = Node{T,A}

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
Base.eltype(::Type{Node{T,A}}) where {T,A} = Node{T,A}
