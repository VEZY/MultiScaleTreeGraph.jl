"""
    GenericNode

A generic node type, does nothing special.
"""
struct GenericNode end

"""
    Node(MTG<:AbstractNodeMTG; type)
    Node(parent::Node, MTG<:AbstractNodeMTG; type)
    Node(id::Int, MTG<:AbstractNodeMTG, attributes; type)
    Node(name::String, id::Int, MTG<:AbstractNodeMTG, attributes; type)
    Node(id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes; type)
    Node(name::String, id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes; type)
    Node(
        name::String,
        id::Int,
        parent::Node,
        children::Union{Nothing,Dict{Int,Node}},
        MTG<:AbstractNodeMTG,
        attributes; 
        type
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
- `type`: the type of the node, by default a `GenericNode` (unexported), but that can be anything. Usually 
used to dispatch computations on node type.

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
mutable struct Node{N<:AbstractNodeMTG,A,T}
    "Name of the node. Should be unique in the MTG"
    name::String
    "Node unique ID"
    id::Int
    "Parent node"
    parent::Union{Nothing,Node}
    "Dictionary of children nodes, or Nothing if no children"
    children::Union{Nothing,Vector{Node}}
    "MTG encoding (see [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref))"
    MTG::N
    "Node attributes. Can be anything really"
    attributes::A
    "Type"
    type::T
end

# Shorter way of instantiating a Node:

# - for the root:
function Node(name::String, id::Int, MTG::T, attributes; type::D=GenericNode()) where {T<:AbstractNodeMTG,D}
    Node(name, id, nothing, nothing, MTG, attributes, type)
end

# If the name is not given, we compute one from the id:
function Node(id::Int, MTG::T, attributes; type::D=GenericNode()) where {T<:AbstractNodeMTG,D}
    Node(join(["node_", id]), id, MTG, attributes; type=type)
end
# If the id is not given, it is the root node, so we use 1
Node(MTG::T, attributes; type::D=GenericNode()) where {T<:AbstractNodeMTG,D} = Node(1, MTG, attributes; type=type)

# Special case for the NamedTuple and MutableNamedTuple, else it overspecializes and we
# can't mutate attributes, i.e. we get somthing like
# Node{NodeMTG,MutableNamedTuple{(:a,), Tuple{Base.RefValue{Int64}}}} instead of just:
# Node{NodeMTG,MutableNamedTuple}
function Node(name::String, id::Int, MTG::M, attributes::T; type::D=GenericNode()) where {M<:AbstractNodeMTG,T<:MutableNamedTuple,D}
    Node{typeof(MTG),MutableNamedTuple,D}(name, id, nothing, nothing, MTG, attributes, type)
end

function Node(name::String, id::Int, MTG::M, attributes::T; type::D=GenericNode()) where {M<:AbstractNodeMTG,T<:NamedTuple,D}
    Node{typeof(MTG),NamedTuple,D}(name, id, nothing, nothing, MTG, attributes, type)
end

# - for all others:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes; type::D=GenericNode()) where {M<:AbstractNodeMTG,D}
    node = Node(name, id, parent, nothing, MTG, attributes, type)
    addchild!(parent, node)
    return node
end

# Idem for MutableNamedTuple here:
function Node(name::String, id::Int, parent::Node, MTG::M, attributes::T; type::D=GenericNode()) where {M<:AbstractNodeMTG,T<:MutableNamedTuple,D}
    node = Node{typeof(MTG),MutableNamedTuple,D}(name, id, parent, nothing, MTG, attributes, type)
    addchild!(parent, node)
    return node
end

# Idem, if the name is not given, we compute one from the id:
function Node(id::Int, parent::Node, MTG::T, attributes; type::D=GenericNode()) where {T<:AbstractNodeMTG,D}
    Node(join(["node_", id]), id, parent, MTG, attributes; type=type)
end
# If the id is not given, it is the root node, so we use 1
function Node(parent::Node, MTG::T, attributes; type::D=GenericNode()) where {T<:AbstractNodeMTG,D}
    Node(new_id(get_root(parent)), parent, MTG, attributes; type=type)
end

# Only the MTG is given, by default we use Dict as attributes:
Node(MTG::T; type::D=GenericNode()) where {T<:AbstractNodeMTG,D} = Node(1, MTG, Dict{Symbol,Any}(); type=type)

# Only the MTG and parent are given, by default we use the parent attribute type:
function Node(parent::Node, MTG::T; type::D=GenericNode()) where {T<:AbstractNodeMTG,D}
    Node(parent, MTG, typeof(parent.attributes)(); type=type)
end

## AbstractTrees compatibility:

# Set the methods for Node:
AbstractTrees.children(node::Node{T,A,D}) where {T,A,D} = isleaf(node) ? Vector{Node{T,A,D}}() : collect(node.children)
AbstractTrees.nodevalue(node::Node{T,A,D}) where {T,A,D} = node.attributes
Base.parent(node::Node{T,A,D}) where {T,A,D} = isdefined(node, :parent) ? node.parent : nothing
AbstractTrees.parent(node::Node{T,A,D}) where {T,A,D} = Base.parent(node)
AbstractTrees.childrentype(node::Node{T,A,D}) where {T,A,D} = Vector{Node{T,A,S<:Any}}
AbstractTrees.childtype(node::Node{T,A,D}) where {T,A,D} = Node{T,A,S<:Any}

# Set the traits for Node:
# AbstractTrees.ParentLinks(::Type{<:Node{T,D}}) where {T,D} = AbstractTrees.StoredParents()
AbstractTrees.ParentLinks(::Type{<:Node{T,A,D}}) where {T<:AbstractNodeMTG,A,D} = AbstractTrees.StoredParents()
AbstractTrees.SiblingLinks(::Type{Node{T,A,D}}) where {T,A,D} = AbstractTrees.ImplicitSiblings()
AbstractTrees.ChildIndexing(::Type{<:Node{T,A,D}}) where {T<:AbstractNodeMTG,A,D} = IndexedChildren()
AbstractTrees.NodeType(::Type{<:Node{T,A,D}}) where {T<:AbstractNodeMTG,A,D} = HasNodeType()
AbstractTrees.nodetype(::Type{<:Node{T,A,D}}) where {T<:AbstractNodeMTG,A,D} = Node{T,A,D}

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

Base.IteratorEltype(::Type{<:TreeIterator{Node{T,A,D}}}) where {T<:AbstractNodeMTG,A,D} = Base.HasEltype()
Base.eltype(::Type{<:TreeIterator{Node{T,A,D}}}) where {T<:AbstractNodeMTG,A,D} = Node{T,A,S<:D}

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T,A,D}}) where {T,A,D} = Node{T,A,S<:Any}
