# These fallbacks depend only on the public node interface. Legacy Node methods
# remain more specific and retain their store/cache-aware implementations.

symbol(node::AbstractMTGNode) = getfield(node_mtg(node), :symbol)
scale(node::AbstractMTGNode) = getfield(node_mtg(node), :scale)
index(node::AbstractMTGNode) = getfield(node_mtg(node), :index)
link(node::AbstractMTGNode) = getfield(node_mtg(node), :link)

AbstractTrees.parent(node::AbstractMTGNode) = Base.parent(node)
isroot(node::AbstractMTGNode) = parent(node) === nothing
isleaf(node::AbstractMTGNode) = isempty(children(node))
lastchild(node::AbstractMTGNode) = isleaf(node) ? nothing : last(children(node))
_maybe_traversal_cache(::AbstractMTGNode) = nothing

function get_root(node::AbstractMTGNode)
    current = node
    while !isroot(current)
        current = parent(current)
    end
    return current
end

function get_node(node::AbstractMTGNode, id::Int)
    stack = typeof(node)[node]
    while !isempty(stack)
        current = pop!(stack)
        node_id(current) == id && return current
        ch = children(current)
        for i in lastindex(ch):-1:firstindex(ch)
            push!(stack, ch[i])
        end
    end
    return nothing
end

new_id(node::AbstractMTGNode) = new_id(max_id(node))

function Base.length(node::AbstractMTGNode)
    count = Ref(0)
    traverse!(node, _ -> (count[] += 1))
    return count[]
end

@inline unsafe_getindex(node::AbstractMTGNode, key::Symbol) = get(node_attributes(node), key, nothing)
unsafe_getindex(node::AbstractMTGNode, key) = unsafe_getindex(node, Symbol(key))
unsafe_getindex(node::AbstractMTGNode, key, plan) = unsafe_getindex(node, key)
Base.getindex(node::AbstractMTGNode, key::Symbol) = unsafe_getindex(node, key)
Base.getindex(node::AbstractMTGNode, key) = unsafe_getindex(node, Symbol(key))
Base.getindex(node::AbstractMTGNode, i::Integer) = children(node)[i]
Base.setindex!(node::AbstractMTGNode, value, key::Symbol) = setindex!(node_attributes(node), value, key)
Base.setindex!(node::AbstractMTGNode, value, key) = setindex!(node, value, Symbol(key))
Base.haskey(node::AbstractMTGNode, key) = haskey(node_attributes(node), Symbol(key))
Base.keys(node::AbstractMTGNode) = keys(node_attributes(node))

attribute(node::AbstractMTGNode, key::Symbol, default) = get(node_attributes(node), key, default)
attribute(node::AbstractMTGNode, key, default) = attribute(node, Symbol(key), default)
attribute(node::AbstractMTGNode, key; default=nothing) = attribute(node, key, default)
attribute!(node::AbstractMTGNode, key, value) = setindex!(node, value, Symbol(key))
attribute_names(node::AbstractMTGNode) = collect(keys(node_attributes(node)))

function attributes(node::AbstractMTGNode; format=:namedtuple)
    attrs = node_attributes(node)
    format === :dict && return Dict{Symbol,Any}(pairs(attrs))
    format === :namedtuple || throw(ArgumentError("Unknown format $(format). Expected :namedtuple or :dict."))
    names = Tuple(keys(attrs))
    return NamedTuple{names}(Tuple(attrs[key] for key in names))
end

"""
    add_node!(parent, id::Int, encoding, attributes)

Create and attach one child using the parent's storage backend. The default
`Node` method delegates to the existing constructor. Custom [`AbstractMTGNode`](@ref)
backends implement this method to allow source-backed clients to create organs
without requiring a materialized `Node` graph. ID validation, attachment order,
attribute ownership and rollback are the backend's responsibility.
"""
function add_node! end
add_node!(parent::Node, id::Int, encoding::AbstractNodeMTG, attrs) =
    Node(id, parent, encoding, attrs)
