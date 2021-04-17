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


"""
Indexing Node attributes from node, e.g. node[:length] or node["length"]
"""
Base.getindex(node::Node, key::Symbol) = getproperty(node.attributes,key)
Base.getindex(node::Node, key) = getproperty(node.attributes,Symbol(key))

"""
Indexing a Node using an integer will index in its children
"""
Base.getindex(n::Node, i::Integer) = n.children[collect(keys(n.children))[i]]
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
        for (name, chnode) in node.children
            i[1] = i[1] + 1
            length_subtree(chnode,i)
        end
    end
end


#  Next lines are adapted from either:
# <https://github.com/JuliaCollections/AbstractTrees.jl>
# <https://github.com/dellison/ConstituencyTrees.jl/blob/master/src/trees.jl>
# <https://github.com/vh-d/DataTrees.jl/blob/master/src/indexing.jl>

function AbstractTrees.printnode(io::IO, node::Node)
    print(io, join(["Node: ",node.name,", Link: ",node.MTG.link,"Index: ", node.MTG.index]))
end
# Base.eltype(::Type{<:TreeIterator{Node{T}}}) where T = Node{T}
# Base.IteratorEltype(::Type{<:TreeIterator{Node{T}}}) where T = Base.HasEltype()

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T}}) where T = Node{T}


# Iteartion over the immediate children:
function Base.iterate(node::T) where T <: Node
    isleaf(node) ? nothing : (node[1], 1)
end

function Base.iterate(node::T, state::Int) where T <: Node
    state += 1
    state > length(children(node)) ? nothing : (node[state], state)
end

Base.IteratorSize(::Type{Node{T}}) where T = Base.SizeUnknown()

## Things we need to define to leverage the native iterator from AbstractTrees over children

# Set the traits of this kind of tree
AbstractTrees.parentlinks(::Type{Node{T}}) where T = AbstractTrees.StoredParents()
AbstractTrees.siblinglinks(::Type{Node{T}}) where T = AbstractTrees.StoredSiblings()
AbstractTrees.children(node::Node) = node

Base.parent(node::Node) = isdefined(node, :parent) ? node.parent : nothing
Base.parent(root::Node, node::Node) = isdefined(node, :parent) ? node.parent : nothing

function AbstractTrees.nextsibling(tree::Node, child::Node)
    nextsibling(child)
end

# We also need `pairs` to return something sensible.
# If you don't like integer keys, you could do, e.g.,
#   Base.pairs(node::BinaryNode) = BinaryNodePairs(node)
# and have its iteration return, e.g., `:left=>node.left` and `:right=>node.right` when defined.
# But the following is easy:
Base.pairs(node::Node) = enumerate(node)
