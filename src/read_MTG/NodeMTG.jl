"""
Abstract supertype for all types describing the MTG coding
for a node.

See [`NodeMTG`](@ref) and [`MutableNodeMTG`](@ref) for examples
of implementation.
"""
abstract type AbstractNodeMTG end

"""
    NodeMTG(link, symbol, index, scale)
    MutableNodeMTG(link, symbol, index, scale)

# NodeMTG structure

Builds an MTG node to hold data about the link to the previous node,
the symbol of the node, and its index.

# Note

- The symbol should match the possible values listed in the `SYMBOL` column of the `CLASSES` section
 in the mtg file if read from a file.

- The index is totaly free, and can be used as a way to *e.g.* keep track of the branching order.

```julia
NodeMTG("<", "Leaf", 2, 0)
```
"""
NodeMTG, MutableNodeMTG

struct NodeMTG <: AbstractNodeMTG
    link::String
    symbol::Union{String,SubString,Char}
    index::Union{Int,Nothing}
    scale::Int
end

mutable struct MutableNodeMTG <: AbstractNodeMTG
    link::String
    symbol::Union{String,SubString,Char}
    index::Union{Int,Nothing}
    scale::Int
end

"""
    Node(id::Int, MTG<:AbstractNodeMTG, attributes)
    Node(name::String, id::Int, MTG<:AbstractNodeMTG, attributes)
    Node(id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes)
    Node(name::String, id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes)
    Node(
        name::String,
        id::Int,
        parent::Node,
        children::Union{Nothing,Dict{String,Node}},
        siblings::Union{Nothing,Dict{String,Node}},
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
    children::Union{Nothing,Dict{String,Node}}
    "Dictionary of sibling(s) nodes if any, or else Nothing. Can be Nothing if not computed too."
    siblings::Union{Nothing,Dict{String,Node}}
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


"""
Indexing Node attributes from node, e.g. node[:length] or node["length"]
"""
Base.getindex(node::Node, key) = unsafe_getindex(node, Symbol(key))
Base.getindex(node::Node, key::Symbol) = unsafe_getindex(node, key)

"""
Indexing a Node using an integer will index in its children
"""
Base.getindex(n::Node, i::Integer) = n.children[collect(keys(n.children))[i]]
function Base.getindex(n::Node{T,MutableNamedTuple}, i::Integer) where {T<:AbstractNodeMTG}
    n.children[collect(keys(n.children))[i]]
end

Base.setindex!(n::Node, x::Node, i::Integer) = n.children[i] = x
Base.getindex(x::Node, ::AbstractTrees.ImplicitRootState) = x

"""
Indexing Node attributes from node, e.g. node[:length] or node["length"],
but in an unsafe way, meaning it returns `nothing` when the key is not found
instead of returning an error. It is primarily used when traversing the tree,
so if a node does not have a field, it does not return an error.
"""
function unsafe_getindex(node::Node, key::Symbol)
    try
        getproperty(node.attributes, key)
    catch err
        if err.msg == "type NamedTuple has no field $key" || err.msg == "type Nothing has no field $key"
            nothing
        else
            error(err.msg)
        end
    end
end

unsafe_getindex(node::Node, key) = unsafe_getindex(node, Symbol(key))

function unsafe_getindex(
    node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict{Symbol,S} where {S}},
    key::Symbol
)
    get(node.attributes, key, nothing)
end

function unsafe_getindex(node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict{Symbol,S} where {S}}, key)
    unsafe_getindex(node, Symbol(key))
end

Base.setindex!(node::Node{<:AbstractNodeMTG,<:AbstractDict{Symbol,S} where {S}}, x, key) = setindex!(node, x, Symbol(key))
Base.setindex!(node::Node{<:AbstractNodeMTG,<:AbstractDict{Symbol,S} where {S}}, x, key::Symbol) = node.attributes[key] = x

# function setindex(node::Node{M<:AbstractNodeMTG, Dict{Symbol, Any}}, key::Symbol)
#     try
#         getindex(node.attributes,key)
#     catch err
#         if typeof(err) == KeyError
#             nothing
#         else
#             error(err.msg)
#         end
#     end
# end

# getindex(node::Node{M<:AbstractNodeMTG, Dict{Symbol, Any}}, key) = getindex(node,Symbol(key))

"""
Returns the length of the subtree below the node (including it)
"""
function Base.length(node::Node)
    i = [1]
    length_subtree(node::Node, i)
    return i[1]
end

function length_subtree(node::Node, i)
    if !isleaf(node)
        for chnode in ordered_children(node)
            i[1] = i[1] + 1
            length_subtree(chnode, i)
        end
    end
end


#  Next lines are adapted from either:
# <https://github.com/JuliaCollections/AbstractTrees.jl>
# <https://github.com/dellison/ConstituencyTrees.jl/blob/master/src/trees.jl>
# <https://github.com/vh-d/DataTrees.jl/blob/master/src/indexing.jl>

Base.eltype(::Type{<:TreeIterator{Node{T,D}}}) where {T,D} = Node{T,D}
Base.IteratorEltype(::Type{<:TreeIterator{Node{T,D}}}) where {T,D} = Base.HasEltype()

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T,D}}) where {T,D} = Node{T,D}


# Iteartion over the immediate children:
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
