"""
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


#  Next lines are adapted from either:
# <https://github.com/JuliaCollections/AbstractTrees.jl>
# <https://github.com/dellison/ConstituencyTrees.jl/blob/master/src/trees.jl>
# <https://github.com/vh-d/DataTrees.jl/blob/master/src/indexing.jl>

Base.eltype(::Type{<:TreeIterator{Node{T,D}}}) where {T,D} = Node{T,D}
Base.IteratorEltype(::Type{<:TreeIterator{Node{T,D}}}) where {T,D} = Base.HasEltype()

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T,D}}) where {T,D} = Node{T,D}


# Iteration over the immediate children:
function Base.iterate(node::T) where {T<:Node}
    isleaf(node) ? nothing : (node[1], 1)
end

function Base.iterate(node::T, state::Int) where {T<:Node}
    state += 1
    state > length(children(node)) ? nothing : (node[state], state)
end

Base.IteratorSize(::Type{Node{T,D}}) where {T,D} = Base.SizeUnknown()

## Things we need to define to leverage the native iterator from AbstractTrees over children

# Set the traits of this kind of tree
AbstractTrees.parentlinks(::Type{Node{T,D}}) where {T,D} = AbstractTrees.StoredParents()
AbstractTrees.siblinglinks(::Type{Node{T,D}}) where {T,D} = AbstractTrees.StoredSiblings()
AbstractTrees.children(node::Node) = MultiScaleTreeGraph.children(node)
AbstractTrees.nodetype(::Node) = Node

Base.parent(node::Node) = isdefined(node, :parent) ? node.parent : nothing
Base.parent(root::Node, node::Node) = isdefined(node, :parent) ? node.parent : nothing

function AbstractTrees.nextsibling(tree::Node, child::Node)
    MultiScaleTreeGraph.nextsibling(child)
end

# We also need `pairs` to return something sensible.
# If you don't like integer keys, you could do, e.g.,
#   Base.pairs(node::BinaryNode) = BinaryNodePairs(node)
# and have its iteration return, e.g., `:left=>node.left` and `:right=>node.right` when defined.
# But the following is easy:
Base.pairs(node::Node) = enumerate(node)
