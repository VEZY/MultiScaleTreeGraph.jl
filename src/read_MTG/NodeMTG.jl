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
NodeMTG,MutableNodeMTG

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


mutable struct Node{T<:AbstractNodeMTG,A}
    name::String
    parent::Union{Nothing,Node}
    children::Union{Nothing,Dict{String,Node}}
    siblings::Union{Nothing,Dict{String,Node}}
    MTG::T
    attributes::A
end

# Shorter way of instantiating a Node:

# - for the root:
Node(name::String,MTG::T,attributes) where T<:AbstractNodeMTG= Node(name,nothing,nothing,nothing,MTG,attributes)

# Special case for the NamedTuple and MutableNamedTuple, else it overspecializes and we
# can't mutate attributes, i.e. we get somthing like
# Node{NodeMTG,MutableNamedTuple{(:a,), Tuple{Base.RefValue{Int64}}}} instead of just:
# Node{NodeMTG,MutableNamedTuple}
function Node(name::String,MTG::M,attributes::T) where {M<:AbstractNodeMTG, T<:MutableNamedTuple}
    Node{typeof(MTG),MutableNamedTuple}(name,nothing,nothing,nothing,MTG,attributes)
end

function Node(name::String,MTG::M,attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    Node{typeof(MTG),NamedTuple}(name,nothing,nothing,nothing,MTG,attributes)
end

# - for all others:
function Node(name::String,parent::Node,MTG::M,attributes) where M<:AbstractNodeMTG
    Node(name,parent,nothing,nothing,MTG,attributes)
end

# Idem for MutableNamedTuple here:
function Node(name::String,parent::Node,MTG::M,attributes::T) where {M<:AbstractNodeMTG, T<:MutableNamedTuple}
    Node{typeof(MTG),MutableNamedTuple}(name,parent,nothing,nothing,MTG,attributes)
end

"""
Indexing Node attributes from node, e.g. node[:length] or node["length"]
"""
Base.getindex(node::Node, key) = unsafe_getindex(node,Symbol(key))
Base.getindex(node::Node, key::Symbol) = unsafe_getindex(node,key)

"""
Indexing a Node using an integer will index in its children
"""
Base.getindex(n::Node, i::Integer) = n.children[collect(keys(n.children))[i]]
function Base.getindex(n::Node{T, MutableNamedTuple}, i::Integer) where T<:AbstractNodeMTG
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
        getproperty(node.attributes,key)
    catch err
        if err.msg == "type NamedTuple has no field $key" || err.msg == "type Nothing has no field $key"
            nothing
        else
            error(err.msg)
        end
    end
end

unsafe_getindex(node::Node, key) = unsafe_getindex(node,Symbol(key))

function unsafe_getindex(
    node::Node{M, T} where {M<:AbstractNodeMTG, T<: AbstractDict{Symbol, Any}},
    key::Symbol
    )
    get(node.attributes, key, nothing)
end

function unsafe_getindex(node::Node{M, T} where {M<:AbstractNodeMTG, T<: AbstractDict{Symbol, Any}}, key)
    unsafe_getindex(node,Symbol(key))
end

Base.setindex!(node::Node{<:AbstractNodeMTG, <:AbstractDict{Symbol, Any}}, x, key) = setindex!(node, x, Symbol(key))
Base.setindex!(node::Node{<:AbstractNodeMTG, <:AbstractDict{Symbol, Any}}, x, key::Symbol) = node.attributes[key] = x

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
    length_subtree(node::Node,i)
    return i[1]
end

function length_subtree(node::Node,i)
    if !isleaf(node)
        for chnode in ordered_children(node)
            i[1] = i[1] + 1
            length_subtree(chnode,i)
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
function Base.iterate(node::T) where T <: Node
    isleaf(node) ? nothing : (node[1], 1)
end

function Base.iterate(node::T, state::Int) where T <: Node
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
