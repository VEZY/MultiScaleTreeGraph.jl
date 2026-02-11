"""
    Node(MTG<:AbstractNodeMTG)
    Node(parent::Node, MTG<:AbstractNodeMTG)
    Node(id::Int, MTG<:AbstractNodeMTG, attributes)
    Node(id::Int, parent::Node, MTG<:AbstractNodeMTG, attributes)
    Node(id::Int, parent::Node, children::Vector{Node}, MTG<:AbstractNodeMTG, attributes)
    Node(
        id::Int,
        parent::Node,
        children::Vector{Node},
        MTG<:AbstractNodeMTG,
        attributes;
        traversal_cache
    )
    

Type that defines an MTG node (*i.e.* an element) with:

- `id`: The unique id of node (unique in the whole MTG)
- `parent`: the parent node (if not the root node)
- `children`: an optional array of children nodes
- `MTG`: the MTG description, or encoding (see [`NodeMTG`](@ref) or
[`MutableNodeMTG`](@ref))
- `attributes`: the node attributes, that can be anything but 
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
internode = Node(mtg, NodeMTG("/", "Internode", 1, 2))
# Note that the node is created with a parent, so it is not necessary to add it as a child of the `mtg ` Node

mtg
```
"""
mutable struct Node{N<:AbstractNodeMTG,A}
    "Node unique ID"
    id::Int
    "Parent node"
    parent::Union{Nothing,Node{N,A}}
    "Dictionary of children nodes, or Nothing if no children"
    children::Vector{Node{N,A}}
    "MTG encoding (see [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref))"
    MTG::N
    "Node attributes. Can be anything really"
    attributes::A
    "Cache for mtg nodes traversal"
    traversal_cache::Dict{String,Vector{Node{N,A}}}
end

# All deprecated methods (the ones with a node name) :
@deprecate Node(name::String, id::Int, parent::Union{Nothing,Node{N,A}}, children::Nothing, MTG::N, attributes::A, traversal_cache::Dict{String,Vector{Node{N,A}}}) where {N<:AbstractNodeMTG,A} Node(id, parent, children, MTG, attributes, traversal_cache)
@deprecate Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple} Node(id, MTG, attributes)
@deprecate Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple} Node(id, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::A) where {M<:AbstractNodeMTG,A} Node(id, parent, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple} Node(id, parent, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple} Node(id, parent, MTG, attributes)

# For the root:
function Node(id::Int, MTG::T, attributes::A) where {T<:AbstractNodeMTG,A}
    Node(id, nothing, Vector{Node{T,A}}(), MTG, attributes, Dict{String,Vector{Node{T,A}}}())
end

function Node(id::Int, MTG::T, attributes::ColumnarAttrs) where {T<:AbstractNodeMTG}
    node = Node{T,ColumnarAttrs}(
        id, nothing, Vector{Node{T,ColumnarAttrs}}(), MTG, attributes, Dict{String,Vector{Node{T,ColumnarAttrs}}}()
    )
    init_columnar_root!(attributes, id, getfield(MTG, :symbol))
    return node
end

# If the id is not given, it is the root node, so we use 1
Node(MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(1, MTG, attributes)
# Not attributes given, by default we use Dict:
Node(id::Int, MTG::T) where {T<:AbstractNodeMTG} = Node(id, MTG, Dict{Symbol,Any}())

# Special case for the NamedTuple and MutableNamedTuple, else it overspecializes and we
# can't mutate attributes, i.e. we get somthing like
# Node{NodeMTG,MutableNamedTuple{(:a,), Tuple{Base.RefValue{Int64}}}} instead of just:
# Node{NodeMTG,MutableNamedTuple}
function Node(id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    Node{M,MutableNamedTuple}(id, nothing, Vector{Node{M,MutableNamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
end

function Node(id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    Node{M,NamedTuple}(id, nothing, Vector{Node{M,NamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
end

# Add a node as a child of another node:
function Node(id::Int, parent::Node{M,A}, MTG::M, attributes::A) where {M<:AbstractNodeMTG,A}
    node = Node(id, parent, Vector{Node{M,A}}(), MTG, attributes, Dict{String,Vector{Node{M,A}}}())
    addchild!(parent, node)
    return node
end

function _to_columnar_attrs(attributes::ColumnarAttrs)
    attributes
end

function _to_columnar_attrs(attributes::AbstractDict)
    ColumnarAttrs(attributes)
end

function _to_columnar_attrs(attributes::NamedTuple)
    ColumnarAttrs(Dict{Symbol,Any}(pairs(attributes)))
end

function _to_columnar_attrs(attributes::MutableNamedTuple)
    ColumnarAttrs(Dict{Symbol,Any}(pairs(attributes)))
end

function Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes::ColumnarAttrs) where {M<:AbstractNodeMTG}
    node = Node{M,ColumnarAttrs}(
        id, parent, Vector{Node{M,ColumnarAttrs}}(), MTG, attributes, Dict{String,Vector{Node{M,ColumnarAttrs}}}()
    )
    addchild!(parent, node)
    bind_columnar_child!(node_attributes(parent), attributes, id, getfield(MTG, :symbol))
    return node
end

function Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes::AbstractDict) where {M<:AbstractNodeMTG}
    Node(id, parent, MTG, _to_columnar_attrs(attributes))
end

function Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes::NamedTuple) where {M<:AbstractNodeMTG}
    Node(id, parent, MTG, _to_columnar_attrs(attributes))
end

function Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes::MutableNamedTuple) where {M<:AbstractNodeMTG}
    Node(id, parent, MTG, _to_columnar_attrs(attributes))
end

function Node(id::Int, parent::Node{M,A}, MTG::T, attributes::A) where {M<:AbstractNodeMTG,A,T<:AbstractNodeMTG}
    error(
        "The parent node has an MTG encoding of type `$(M)`, but the MTG encoding you provide is of type `$(T)`,",
        " please make sure they are the same."
    )
end

# Special case for NamedTuple here:
function Node(id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple}
    node = Node{M,NamedTuple}(id, parent, Vector{Node{M,NamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,NamedTuple}}}())
    addchild!(parent, node)
    return node
end

# Idem for MutableNamedTuple here:
function Node(id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    node = Node{M,MutableNamedTuple}(id, parent, Vector{Node{M,MutableNamedTuple}}(), MTG, attributes, Dict{String,Vector{Node{M,MutableNamedTuple}}}())
    addchild!(parent, node)
    return node
end

# If the id is not given, it is the root node, so we use 1
function Node(parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG}
    Node(new_id(get_root(parent)), parent, MTG, attributes)
end

# Only the MTG is given, by default we use Dict as attributes:
Node(MTG::T) where {T<:AbstractNodeMTG} = Node(1, MTG, Dict{Symbol,Any}())

# Only the ID, MTG and parent are given, by default we use the parent attribute type:
function Node(id::Int, parent::Node{N,A}, MTG::T) where {N<:AbstractNodeMTG,A,T<:AbstractNodeMTG}
    Node(id, parent, MTG, A())
end

# Same but without the id:
function Node(parent::Node{N,A}, MTG::T) where {N<:AbstractNodeMTG,A,T<:AbstractNodeMTG}
    Node(new_id(get_root(parent)), parent, MTG, A())
end

# Copying a node returns the node:
Base.copy(node::Node) = node

## AbstractTrees compatibility:

# Set the methods for Node:

"""
    AbstractTrees.children(node::Node{T,A}) where {T,A}

Get the children of a MultiScaleTreeGraph node.
"""
AbstractTrees.children(node::Node{T,A}) where {T,A} = getfield(node, :children)
AbstractTrees.nodevalue(node::Node{T,A}) where {T,A} = getfield(node, :attributes)::A


"""
    Base.parent(node::Node{T,A})

Get the parent of a MultiScaleTreeGraph node. If the node is the root, it returns nothing.

See also [`reparent!`](@ref) to update the parent of a node.
"""
Base.parent(node::Node{T,A}) where {T,A} = getfield(node, :parent)

"""
    AbstractTrees.parent(node::Node{T,A})

Get the parent of a MultiScaleTreeGraph node. If the node is the root, it returns nothing.

See also [`reparent!`](@ref) to update the parent of a node.
"""
AbstractTrees.parent(node::Node{T,A}) where {T,A} = Base.parent(node)
AbstractTrees.childrentype(node::Node{T,A}) where {T,A} = Vector{Node{T,A}}
AbstractTrees.childtype(::Type{Node{T,A}}) where {T,A} = Node{T,A}

"""
    reparent!(node::N, p::N) where N<:Node{T,A}

Set the parent of the node.
"""
function reparent!(node::N, p::N2) where {N<:Node{T,A},N2<:Union{Nothing,Node{T,A}}} where {T,A}
    setfield!(node, :parent, p)
    _mark_structure_mutation!(node)
    p === nothing || _mark_structure_mutation!(p)
    return p
end

"""
    rechildren!(node::Node{T,A}, chnodes::Vector{Node{T,A}}) where {T,A}

Set the children of the node.
"""
function rechildren!(node::Node{T,A}, chnodes::Vector{Node{T,A}}) where {T,A}
    setfield!(node, :children, chnodes)
    _mark_structure_mutation!(node)
    return chnodes
end
# AbstractTrees.childstatetype(::Type{Node{T,A}}) where {T,A} = Node{T,A}

# Set the traits for Node:
# AbstractTrees.ParentLinks(::Type{<:Node{T}}) where {T} = AbstractTrees.StoredParents()
AbstractTrees.ParentLinks(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = AbstractTrees.StoredParents()
AbstractTrees.SiblingLinks(::Type{Node{T,A}}) where {T,A} = AbstractTrees.ImplicitSiblings()
AbstractTrees.ChildIndexing(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = IndexedChildren()
AbstractTrees.NodeType(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = HasNodeType()
AbstractTrees.nodetype(::Type{<:Node{T,A}}) where {T<:AbstractNodeMTG,A} = Node{T,A}

@inline function sibling_index(all_siblings, node)
    @inbounds for i in eachindex(all_siblings)
        all_siblings[i] === node && return i
    end
    return nothing
end

function AbstractTrees.nextsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent_ = parent(node)
    parent_ === nothing && return nothing

    all_siblings = children(parent_)
    # Get the index of the current node in the siblings:
    node_index = sibling_index(all_siblings, node)
    if node_index === nothing || node_index >= lastindex(all_siblings)
        nothing
    else
        all_siblings[node_index+1]
    end
end

function AbstractTrees.prevsibling(node::Node)
    # If there is no parent, no siblings, return nothing:
    parent_ = parent(node)
    parent_ === nothing && return nothing

    all_siblings = children(parent_)
    # Get the index of the current node in the siblings:
    node_index = sibling_index(all_siblings, node)
    if node_index === nothing || node_index <= firstindex(all_siblings)
        nothing
    else
        all_siblings[node_index-1]
    end
end

# Iterations
Base.IteratorEltype(::Type{<:TreeIterator{Node{T,A}}}) where {T<:AbstractNodeMTG,A} = Base.HasEltype()
Base.eltype(::Type{<:TreeIterator{Node{T,A}}}) where {T<:AbstractNodeMTG,A} = Node{T,A}

# Help Julia infer what's inside a Node when doing iteration (another node)
Base.eltype(::Type{Node{T,A}}) where {T,A} = Node{T,A}

"""
    node_id(node::Node)

Get the unique id of the node in the MTG.
"""
node_id(node::Node) = getfield(node, :id)

"""
    node_mtg(node::Node)

Get the MTG encoding of the node, *i.e.* the MTG description (see
[`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref)):

- `scale`: the scale of the node (*e.g.* 1)
- `symbol`: the symbol of the node (*e.g.* "Axis")
- `index`: the index of the node (*e.g.* 1, this is free)
- `link`: the link of the node ("/", "+" or "<")

"""
node_mtg(node::Node) = getfield(node, :MTG)
node_mtg!(node::Node{T,A}, mtg_encoding::T) where {T,A} = setfield!(node, :MTG, mtg_encoding)

"""
    symbol(node::Node)

Get the symbol from the MTG encoding of the node.
"""
symbol(node::Node) = getfield(node_mtg(node), :symbol)

"""
    scale(node::Node)

Get the scale from the MTG encoding of the node.
"""
scale(node::Node) = getfield(node_mtg(node), :scale)


"""
    index(node::Node)

Get the index from the MTG encoding of the node.
"""
index(node::Node) = getfield(node_mtg(node), :index)

"""
    link(node::Node)

Get the link from the MTG encoding of the node.
"""
link(node::Node) = getfield(node_mtg(node), :link)

"""
    symbol!(node::Node, symbol)

Set the symbol of the MTG encoding node.
"""
symbol!(node::Node{T,A}, symbol) where {T<:MutableNodeMTG,A} = setfield!(node_mtg(node), :symbol, to_mtg_symbol(symbol))
function symbol!(node::Node{T,A}, new_symbol) where {T<:NodeMTG,A}
    current_node_mtg = node_mtg(node)
    node_mtg!(node, NodeMTG(current_node_mtg.link, new_symbol, current_node_mtg.index, current_node_mtg.scale))
end

"""
    scale!(node::Node, new_scale)

Set the scale of the MTG encoding of the node. The scale should be some kind of integer.
"""
scale!(node::Node{T,A}, new_scale) where {T<:MutableNodeMTG,A} = setfield!(node_mtg(node), :scale, new_scale)
function scale!(node::Node{T,A}, new_scale) where {T<:NodeMTG,A}
    current_node_mtg = node_mtg(node)
    node_mtg!(node, NodeMTG(current_node_mtg.link, current_node_mtg.symbol, current_node_mtg.index, new_scale))
end

"""
    index!(node::Node, new_index)

Set the index of the MTG encoding of the node. The index should be some kind of integer.
"""
index!(node::Node{T,A}, new_index) where {T<:MutableNodeMTG,A} = setfield!(node_mtg(node), :index, new_index)
function index!(node::Node{T,A}, new_index) where {T<:NodeMTG,A}
    current_node_mtg = node_mtg(node)
    node_mtg!(node, NodeMTG(current_node_mtg.link, current_node_mtg.symbol, new_index, current_node_mtg.scale))
end

"""
    link!(node::Node, new_link)

Set the link of the MTG encoding of the node. It can be one of "/", "<", or "+".
"""
link!(node::Node{T,A}, new_link) where {T<:MutableNodeMTG,A} = setfield!(node_mtg(node), :link, to_mtg_link(new_link))
function link!(node::Node{T,A}, new_link) where {T<:NodeMTG,A}
    current_node_mtg = node_mtg(node)
    node_mtg!(node, NodeMTG(new_link, current_node_mtg.symbol, current_node_mtg.index, current_node_mtg.scale))
end

"""
    node_attributes(node::Node)

Get the attributes of a node.
"""
node_attributes(node::Node{T,A}) where {T,A} = getfield(node, :attributes)::A

"""
    node_attributes!(node::Node)

Set the attributes of a node, *i.e.* replace the whole structure by another. This function is internal, 
and should not be used directly. Use *e.g.* `node.key = value` to set a single attribute of the node.
"""
node_attributes!(node::Node{T,A}, attributes::A) where {T,A} = setfield!(node, :attributes, attributes)

"""
    attribute(node::Node, key::Symbol; default=nothing)

Get one attribute from a node.
"""
attribute(node::Node, key::Symbol; default=nothing) = get(node_attributes(node), key, default)
attribute(node::Node, key; default=nothing) = attribute(node, Symbol(key), default=default)

"""
    attribute!(node::Node, key::Symbol, value)

Set one attribute on a node.
"""
function attribute!(node::Node, key::Symbol, value)
    node_attributes(node)[key] = value
    return value
end
attribute!(node::Node, key, value) = attribute!(node, Symbol(key), value)

"""
    attributes(node::Node; format=:namedtuple)

Get all attributes from a node as a snapshot.
"""
function attributes(node::Node; format=:namedtuple)
    attrs = node_attributes(node)
    if format == :dict
        return Dict{Symbol,Any}(pairs(attrs))
    elseif format == :namedtuple
        k = collect(keys(attrs))
        vals = map(key -> get(attrs, key, nothing), k)
        return NamedTuple{Tuple(k)}(Tuple(vals))
    else
        error("Unknown format $(format). Expected :namedtuple or :dict.")
    end
end

"""
    attribute_names(node::Node)

Return the attribute names available for this node.
"""
attribute_names(node::Node) = collect(keys(node_attributes(node)))

function _node_store(node::Node)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || error("This operation requires a columnar attribute backend.")
    store = _store_for_node_attrs(attrs)
    store === nothing && error("Node is not bound to a columnar attribute store.")
    return store
end

@inline function _mark_structure_mutation!(node::Node)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || return nothing
    store = _store_for_node_attrs(attrs)
    store === nothing && return nothing
    _mark_subtree_index_mutation!(store)
    return nothing
end

function add_column!(node::Node, symbol::Symbol, key::Symbol, ::Type{T}; default::T) where {T}
    add_column!(_node_store(node), symbol, key, T, default=default)
end

function add_column!(node::Node, symbols::AbstractVector{Symbol}, key::Symbol, ::Type{T}; default::T) where {T}
    store = _node_store(node)
    for sym in symbols
        add_column!(store, sym, key, T, default=default)
    end
    return node
end

function drop_column!(node::Node, symbol::Symbol, key::Symbol)
    drop_column!(_node_store(node), symbol, key)
end

function drop_column!(node::Node, symbols::AbstractVector{Symbol}, key::Symbol)
    store = _node_store(node)
    for sym in symbols
        drop_column!(store, sym, key)
    end
    return node
end

function rename_column!(node::Node, symbol::Symbol, from::Symbol, to::Symbol)
    rename_column!(_node_store(node), symbol, from, to)
end

function rename_column!(node::Node, symbols::AbstractVector{Symbol}, from::Symbol, to::Symbol)
    store = _node_store(node)
    for sym in symbols
        rename_column!(store, sym, from, to)
    end
    return node
end

"""
    descendants_strategy(node::Node)
    descendants_strategy!(node::Node, strategy::Symbol)

Get or set how `descendants(node, key, ...)` is computed for columnar MTGs.

- `:auto` (default): choose automatically based on workload.
- `:pointer`: always follow parent/children links directly in the graph.
- `:indexed`: use a precomputed index for descendant lookups.

The index is based on a Depth-First Search (DFS) visit order (visit a branch deeply, then the
next branch). It can speed up repeated descendant requests on mostly stable trees, while
`:pointer` is often better when the tree structure changes very frequently.
"""
function descendants_strategy(node::Node)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || return :pointer
    store = _store_for_node_attrs(attrs)
    store === nothing && return :pointer
    return descendants_strategy(store)
end

function descendants_strategy!(node::Node, strategy::Symbol)
    descendants_strategy!(_node_store(node), strategy)
    return node
end

"""
    get_attributes(mtg)

Get all attributes names available on the mtg and its children.
"""
function get_attributes(mtg)
    attrs = Set{Symbol}()
    traverse!(mtg) do node
        union!(attrs, keys(node_attributes(node)))
    end

    return collect(attrs)
end

"""
    names(mtg)

Get all attributes names available on the mtg and its children. This is an alias for
[`get_attributes`](@ref).
"""
Base.names(mtg::T) where {T<:MultiScaleTreeGraph.Node} = get_attributes(mtg)

"""
    node_traversal_cache(node::Node)

Get the traversal cache of the node if any.
"""
node_traversal_cache(node::Node) = getfield(node, :traversal_cache)

Base.getproperty(node::Node, key::Symbol) = unsafe_getindex(node, key)
Base.hasproperty(node::Node, key::Symbol) = haskey(node_attributes(node), key)
Base.haskey(node::Node, key::Symbol) = haskey(node_attributes(node), key)
Base.haskey(node::Node{T,A}, key::Symbol) where {T<:AbstractNodeMTG,A<:MutableNamedTuple} = hasproperty(node_attributes(node), key)
Base.setproperty!(node::Node{T,A}, key::Symbol, value) where {T<:AbstractNodeMTG,A} = setproperty!(node_attributes(node), key, value)
Base.setproperty!(node::Node{T,A}, key::Symbol, value) where {T<:AbstractNodeMTG,A<:AbstractDict} = setindex!(node_attributes(node), value, key)
Base.keys(node::Node) = keys(node_attributes(node))
Base.propertynames(node::Node) = keys(node)

"""
Indexing Node attributes from node, e.g. node[:length] or node["length"]
"""
Base.getindex(node::Node, key) = unsafe_getindex(node, Symbol(key))
Base.getindex(node::Node, key::Symbol) = unsafe_getindex(node, key)
Base.setindex!(node::Node{<:AbstractNodeMTG,<:AbstractDict}, x, key) = setindex!(node, x, Symbol(key))
Base.setindex!(node::Node{<:AbstractNodeMTG,<:AbstractDict}, x, key::Symbol) = node_attributes(node)[key] = x
