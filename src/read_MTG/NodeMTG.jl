"""
    NodeMTG(link, symbol, index, scale)
    NodeMTG(link)

# NodeMTG structure

Builds an MTG node to hold data about the link to the previous node,
the symbol of the node, and its index. 

# Note

- The symbol should match the possible values listed in the `SYMBOL` column of the `CLASSES` section
 in the mtg file if read from a file. 

- The index is totaly free, and can be used as a way to *e.g.* keep track of the branching order.

```jldoctest
julia> NodeMTG("<","Leaf",2)
NodeMTG("<", "Leaf", 2)

julia> NodeMTG("<")
NodeMTG("<", nothing, nothing)
```
"""
struct NodeMTG
    link::Union{String,Char}
    symbol::Union{Nothing,String,SubString,Char}
    index::Union{Nothing,Int}
    scale::Union{Nothing,Int}
end

mutable struct Node{T <: Union{Nothing,MutableNamedTuple}}
    name::String
    parent::Union{Nothing,Node}
    children::Union{Nothing,Dict{String,Node}}
    siblings::Union{Nothing,Dict{String,Node}}
    MTG::NodeMTG
    attributes::T
end

# For the root node:
# - No attributes
Node(name::String,MTG::NodeMTG) = Node(name,nothing,nothing,nothing,MTG,nothing)
# - with attributes
Node(name::String,MTG::NodeMTG,attributes::Union{Nothing,MutableNamedTuple}) = Node(name,nothing,nothing,nothing,MTG,attributes)

# For the others:
# - No attributes
Node(name::String,parent::Node,MTG::NodeMTG) = Node(name,parent,nothing,nothing,MTG,nothing)
# - with attributes
Node(name::String,parent::Node,MTG::NodeMTG,attributes::Union{Nothing,MutableNamedTuple}) = Node(name,parent,nothing,nothing,MTG,attributes)


#  Next lines are adapted from either:
# <https://github.com/JuliaCollections/AbstractTrees.jl>
# <https://github.com/dellison/ConstituencyTrees.jl/blob/master/src/trees.jl>
# <https://github.com/vh-d/DataTrees.jl/blob/master/src/indexing.jl>

# AbstractTrees.children(node::Node) = node
function AbstractTrees.printnode(io::IO, node::Node)
    print(io, join(["Node: ",node.name,", Link: ",node.MTG.link,"Index: ", node.MTG.index]))
end
Base.eltype(::Type{<:TreeIterator{Node{T}}}) where T = Node{T}
Base.IteratorEltype(::Type{<:TreeIterator{Node{T}}}) where T = Base.HasEltype()

# # Implement iteration over the immediate children of a node
function Base.iterate(node::Node)
    isdefined(node, :chilren) && return (node.chilren)
    return nothing
end
Base.IteratorSize(::Type{Node{T}}) where T = Base.SizeUnknown()

## Things we need to define to leverage the native iterator over children
## for the purposes of AbstractTrees.
# Set the traits of this kind of tree
AbstractTrees.parentlinks(::Type{Node{T}}) where T = AbstractTrees.StoredParents()
AbstractTrees.siblinglinks(::Type{Node{T}}) where T = AbstractTrees.StoredSiblings()
# Use the native iteration for the children

Base.parent(node::Node) = isdefined(node, :parent) ? node.parent : nothing

function AbstractTrees.nextsibling(node::Node)
    isdefined(node, :parent) || return nothing
    p = node.parent
    if isdefined(p, :right)
        node === p.right && return nothing
        return p.right
    end
    return nothing
end

# We also need `pairs` to return something sensible.
# If you don't like integer keys, you could do, e.g.,
#   Base.pairs(node::BinaryNode) = BinaryNodePairs(node)
# and have its iteration return, e.g., `:left=>node.left` and `:right=>node.right` when defined.
# But the following is easy:
Base.pairs(node::Node) = enumerate(node)

