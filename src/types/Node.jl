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
    traversal_cache::Union{Nothing,Dict{String,Vector{Node{N,A}}}}

    function Node{N,A}(
        id,
        parent,
        children,
        MTG,
        attributes,
        ::Nothing,
    ) where {N<:AbstractNodeMTG,A}
        new{N,A}(id, parent, children, MTG, attributes, nothing)
    end

    function Node{N,A}(
        id,
        parent,
        children,
        MTG,
        attributes,
        traversal_cache,
    ) where {N<:AbstractNodeMTG,A}
        node = new{N,A}(id, parent, children, MTG, attributes, traversal_cache)
        getfield(node, :traversal_cache) === nothing ||
            _register_existing_traversal_cache!(node)
        return node
    end
end

function Node(
    id::Int,
    parent::Union{Nothing,Node{N,A}},
    children::Vector{Node{N,A}},
    MTG::N,
    attributes::A,
    traversal_cache::Union{Nothing,Dict{String,Vector{Node{N,A}}}},
) where {N<:AbstractNodeMTG,A}
    Node{N,A}(id, parent, children, MTG, attributes, traversal_cache)
end

# All deprecated methods (the ones with a node name) :
@deprecate Node(name::String, id::Int, parent::Union{Nothing,Node{N,A}}, children::Nothing, MTG::N, attributes::A, traversal_cache::Dict{String,Vector{Node{N,A}}}) where {N<:AbstractNodeMTG,A} Node(id, parent, children, MTG, attributes, traversal_cache)
@deprecate Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple} Node(id, MTG, attributes)
@deprecate Node(name::String, id::Int, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple} Node(id, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::A) where {M<:AbstractNodeMTG,A} Node(id, parent, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:NamedTuple} Node(id, parent, MTG, attributes)
@deprecate Node(name::String, id::Int, parent::Node, MTG::M, attributes::T) where {M<:AbstractNodeMTG,T<:MutableNamedTuple} Node(id, parent, MTG, attributes)

function Node(id::Int, MTG::T, attributes::ColumnarAttrs) where {T<:AbstractNodeMTG}
    node = Node{T,ColumnarAttrs}(
        id, nothing, Vector{Node{T,ColumnarAttrs}}(), MTG, attributes, nothing
    )
    init_columnar_root!(attributes, id, getfield(MTG, :symbol))
    return node
end

# If the id is not given, it is the root node, so we use 1
Node(MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(1, MTG, _to_columnar_attrs(attributes))
Node(id::Int, MTG::T, attributes) where {T<:AbstractNodeMTG} = Node(id, MTG, _to_columnar_attrs(attributes))
Node(id::Int, MTG::T) where {T<:AbstractNodeMTG} = Node(id, MTG, ColumnarAttrs())

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

function _to_columnar_attrs(attributes)
    throw(ArgumentError("Unsupported attribute container type $(typeof(attributes)); use ColumnarAttrs, AbstractDict, or NamedTuple-like values."))
end

function Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes::ColumnarAttrs) where {M<:AbstractNodeMTG}
    node = Node{M,ColumnarAttrs}(
        id, parent, Vector{Node{M,ColumnarAttrs}}(), MTG, attributes, nothing
    )
    push!(children(parent), node)
    _invalidate_traversal_caches!(parent)
    bind_columnar_child!(node_attributes(parent), attributes, id, getfield(MTG, :symbol))
    return node
end

Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M, attributes) where {M<:AbstractNodeMTG} =
    Node(id, parent, MTG, _to_columnar_attrs(attributes))

function Node(id::Int, parent::Node{M,A}, MTG::T, attributes::A) where {M<:AbstractNodeMTG,A,T<:AbstractNodeMTG}
    error(
        "The parent node has an MTG encoding of type `$(M)`, but the MTG encoding you provide is of type `$(T)`,",
        " please make sure they are the same."
    )
end

Node(id::Int, parent::Node{M,ColumnarAttrs}, MTG::M) where {M<:AbstractNodeMTG} =
    Node(id, parent, MTG, ColumnarAttrs())

# If the id is not given, it is the root node, so we use 1
function Node(parent::Node, MTG::T, attributes) where {T<:AbstractNodeMTG}
    Node(new_id(get_root(parent)), parent, MTG, attributes)
end

# Only the MTG is given, by default we use ColumnarAttrs as attributes:
Node(MTG::T) where {T<:AbstractNodeMTG} = Node(1, MTG, ColumnarAttrs())

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

@inline function _child_index_by_identity(chnodes, child)
    @inbounds for i in eachindex(chnodes)
        chnodes[i] === child && return i
    end
    return nothing
end

function _detach_child!(p::Node, child::Node)
    chnodes = children(p)
    removed = false
    for i in reverse(eachindex(chnodes))
        if chnodes[i] === child
            deleteat!(chnodes, i)
            removed = true
        end
    end
    removed && _mark_structure_mutation!(p)
    return removed
end

function _attach_child!(p::Node, child::Node)
    chnodes = children(p)
    _child_index_by_identity(chnodes, child) !== nothing && return false
    push!(chnodes, child)
    _mark_structure_mutation!(p)
    return true
end

function _validate_reparent_target(node::Node, new_parent::Node)
    current = new_parent
    while current !== nothing
        current === node && throw(ArgumentError(
            "cannot reparent node $(node_id(node)) below its own descendant $(node_id(new_parent))",
        ))
        current = parent(current)
    end
    return nothing
end

"""
    reparent!(node::N, p::N) where N<:Node{T,A}

Set the parent of the node, removing it from the old parent's children and adding it
to the new parent's children.
"""
function reparent!(node::N, p::N2) where {N<:Node{T,A},N2<:Union{Nothing,Node{T,A}}} where {T,A}
    p === node && error("A node cannot be its own parent.")

    old_parent = parent(node)
    changed = old_parent !== p
    if changed && p !== nothing
        _validate_reparent_target(node, p)
        _validate_columnar_attach!(p, node)
    end
    changed && _maybe_traversal_cache(node) !== nothing && _discard_traversal_cache!(node)
    if old_parent !== nothing && changed
        _detach_child!(old_parent, node)
    end

    setfield!(node, :parent, p)
    attached = p === nothing ? false : _attach_child!(p, node)
    p === nothing || _maybe_recolumnarize_after_attach!(p, node)
    if (changed || attached) && (!attached || _maybe_traversal_cache(node) !== nothing)
        _mark_structure_mutation!(node)
    end
    return p
end

"""
    rechildren!(node::Node{T,A}, chnodes::Vector{Node{T,A}}) where {T,A}

Set the children of the node, detaching removed children and setting this node as the
parent of the new children.
"""
function rechildren!(node::Node{T,A}, chnodes::Vector{Node{T,A}}) where {T,A}
    if length(chnodes) <= 8
        for child_index in eachindex(chnodes)
            child = chnodes[child_index]
            @inbounds for previous_index in firstindex(chnodes):(child_index - 1)
                child === chnodes[previous_index] && throw(ArgumentError(
                    "node $(node_id(child)) cannot occur more than once in the children of node $(node_id(node))",
                ))
            end
        end
    else
        seen_children = Base.IdSet{Node{T,A}}()
        sizehint!(seen_children, length(chnodes))
        for child in chnodes
            child in seen_children && throw(ArgumentError(
                "node $(node_id(child)) cannot occur more than once in the children of node $(node_id(node))",
            ))
            push!(seen_children, child)
        end
    end
    incoming_cross_store_ids = nothing
    for child in chnodes
        _validate_reparent_target(child, node)
        incoming_cross_store_ids =
            _validate_columnar_attach!(node, child, incoming_cross_store_ids)
    end

    old_children = children(node)
    setfield!(node, :children, chnodes)

    for old_child in old_children
        if parent(old_child) === node && _child_index_by_identity(chnodes, old_child) === nothing
            reparent!(old_child, nothing)
        end
    end

    for child in chnodes
        reparent!(child, node)
    end

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
@inline attribute(node::Node, key::Symbol, default) = get(node_attributes(node), key, default)
@inline function attribute(node::Node{<:AbstractNodeMTG,ColumnarAttrs}, key::Symbol, default::T) where {T<:Number}
    _get_typed_numeric(node_attributes(node), key, default)
end
attribute(node::Node, key, default) = attribute(node, Symbol(key), default)
attribute(node::Node, key::Symbol; default=nothing) = attribute(node, key, default)
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

function _register_traversal_cache!(store::MTGAttributeStore, node::Node)
    registry = store.subtree_index.traversal_cache_nodes
    if registry === nothing
        store.subtree_index.traversal_cache_nodes = WeakRef(node)
    elseif registry isa WeakRef
        existing = registry.value
        existing === node && return nothing
        if existing === nothing
            store.subtree_index.traversal_cache_nodes = WeakRef(node)
        else
            store.subtree_index.traversal_cache_nodes = WeakRef[registry, WeakRef(node)]
        end
    else
        write_index = firstindex(registry)
        found = false
        @inbounds for read_index in eachindex(registry)
            entry = registry[read_index]
            existing = entry.value
            existing === nothing && continue
            found |= existing === node
            registry[write_index] = entry
            write_index += 1
        end
        resize!(registry, write_index - 1)
        found || push!(registry, WeakRef(node))
    end
    return nothing
end

function _traversal_cache_registered(store::MTGAttributeStore, node::Node)
    registry = store.subtree_index.traversal_cache_nodes
    registry === nothing && return false
    registry isa WeakRef && return registry.value === node
    @inbounds for entry in registry
        entry.value === node && return true
    end
    return false
end

@inline function _traversal_cache_registry_active!(store::MTGAttributeStore)
    registry = store.subtree_index.traversal_cache_nodes
    registry === nothing && return false
    if registry isa WeakRef
        existing = registry.value
        (existing === nothing || _maybe_traversal_cache(existing::Node) === nothing) || return true
    else
        write_index = firstindex(registry)
        @inbounds for read_index in eachindex(registry)
            entry = registry[read_index]
            existing = entry.value
            (existing === nothing || _maybe_traversal_cache(existing::Node) === nothing) && continue
            registry[write_index] = entry
            write_index += 1
        end
        resize!(registry, write_index - 1)
        if length(registry) == 1
            store.subtree_index.traversal_cache_nodes = only(registry)
            return true
        end
        isempty(registry) || return true
    end
    store.subtree_index.traversal_cache_nodes = nothing
    return false
end

@inline function _traversal_cache_store(node::Node)
    attrs = node_attributes(node)
    store = attrs isa ColumnarAttrs ? _store_for_node_attrs(attrs) : nothing
    if store === nothing
        parent_node = parent(node)
        if parent_node !== nothing
            parent_attrs = node_attributes(parent_node)
            store = parent_attrs isa ColumnarAttrs ? _store_for_node_attrs(parent_attrs) : nothing
        end
    end
    return store
end

function _register_existing_traversal_cache!(node::Node)
    store = _traversal_cache_store(node)
    store === nothing || _register_traversal_cache!(store, node)
    return nothing
end

@inline function _unregister_traversal_cache!(store::MTGAttributeStore, node::Node)
    registry = store.subtree_index.traversal_cache_nodes
    registry === nothing && return nothing
    if registry isa WeakRef
        existing = registry.value
        (existing === nothing || existing === node) &&
            (store.subtree_index.traversal_cache_nodes = nothing)
    else
        write_index = firstindex(registry)
        @inbounds for read_index in eachindex(registry)
            entry = registry[read_index]
            existing = entry.value
            (existing === nothing || existing === node) && continue
            registry[write_index] = entry
            write_index += 1
        end
        resize!(registry, write_index - 1)
        if isempty(registry)
            store.subtree_index.traversal_cache_nodes = nothing
        elseif length(registry) == 1
            store.subtree_index.traversal_cache_nodes = only(registry)
        end
    end
    return nothing
end

@inline function _discard_traversal_cache!(node::Node, store::MTGAttributeStore)
    cache = _maybe_traversal_cache(node)
    cache === nothing && return nothing
    empty!(cache)
    setfield!(node, :traversal_cache, nothing)
    _unregister_traversal_cache!(store, node)
    return nothing
end

@inline function _discard_traversal_cache!(node::Node)
    cache = _maybe_traversal_cache(node)
    cache === nothing && return nothing
    empty!(cache)
    setfield!(node, :traversal_cache, nothing)
    store = _traversal_cache_store(node)
    store === nothing || _unregister_traversal_cache!(store, node)
    return nothing
end

@inline function _traversal_cache_mutation_store(node::Node)
    attrs = node_attributes(node)
    store = attrs isa ColumnarAttrs ? _store_for_node_attrs(attrs) : nothing
    if store === nothing && attrs isa ColumnarAttrs
        parent_node = parent(node)
        if parent_node !== nothing
            parent_attrs = node_attributes(parent_node)
            store = parent_attrs isa ColumnarAttrs ? _store_for_node_attrs(parent_attrs) : nothing
        end
    end
    return store
end

@noinline function _invalidate_traversal_caches_slow!(
    node::Node,
    store::Union{Nothing,MTGAttributeStore},
)
    # Traversal caches are local to their starting node. A structural mutation in
    # this subtree therefore invalidates the cache on `node` and on every
    # ancestor whose traversal can include it. Descendant caches remain valid.
    # The common columnar path stays O(1) until a traversal cache has actually
    # been requested for that store.
    registry = store === nothing ? nothing : store.subtree_index.traversal_cache_nodes
    registry_active = store === nothing
    registry_entry_count = 0
    if registry isa WeakRef
        existing = registry.value
        if existing === nothing || _maybe_traversal_cache(existing::Node) === nothing
            store.subtree_index.traversal_cache_nodes = nothing
        else
            registry_active = true
            registry_entry_count = 1
        end
    elseif registry !== nothing
        registry_active = true
        registry_entry_count = length(registry)
    end
    if registry_active
        cleared_count = 0
        current = node
        while current !== nothing
            if store === nothing
                _discard_traversal_cache!(current)
            else
                cache = _maybe_traversal_cache(current)
                if cache !== nothing
                    empty!(cache)
                    setfield!(current, :traversal_cache, nothing)
                    cleared_count += 1
                end
            end
            current = parent(current)
        end
        if store !== nothing && store.subtree_index.traversal_cache_nodes !== nothing
            if cleared_count == registry_entry_count
                store.subtree_index.traversal_cache_nodes = nothing
            else
                _traversal_cache_registry_active!(store)
            end
        end
    end
    return nothing
end

@inline function _invalidate_traversal_caches!(
    node::Node,
    store::Union{Nothing,MTGAttributeStore},
)
    if store !== nothing && store.subtree_index.traversal_cache_nodes === nothing
        return nothing
    end
    _invalidate_traversal_caches_slow!(node, store)
end

@inline function _invalidate_traversal_caches!(node::Node)
    _invalidate_traversal_caches!(node, _traversal_cache_mutation_store(node))
end

@inline function _mark_structure_mutation!(node::Node)
    store = _traversal_cache_mutation_store(node)
    _invalidate_traversal_caches!(node, store)
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
@inline _maybe_traversal_cache(node::Node) = getfield(node, :traversal_cache)

function node_traversal_cache(node::Node{T,A}) where {T,A}
    attrs = node_attributes(node)
    if attrs isa ColumnarAttrs
        store = _store_for_node_attrs(attrs)
        store === nothing || _register_traversal_cache!(store, node)
    end
    cache = getfield(node, :traversal_cache)
    if cache === nothing
        cache = Dict{String,Vector{Node{T,A}}}()
        setfield!(node, :traversal_cache, cache)
    end
    return cache
end

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
