"""
Indexing a Node using an integer will index in its children
"""
Base.getindex(n::Node, i::Integer) = children(n)[i]
Base.setindex!(n::Node, x::Node, i::Integer) = children(n)[i] = x

"""
Indexing Node attributes from node, e.g. node[:length] or node["length"],
but in an unsafe way, meaning it returns `nothing` when the key is not found
instead of returning an error. It is primarily used when traversing the tree,
so if a node does not have a field, it does not return an error.
"""
function unsafe_getindex(node::Node, key::Symbol)
    try
        getproperty(node_attributes(node), key)
    catch err
        if err.msg == "type NamedTuple has no field $key" || err.msg == "type Nothing has no field $key"
            nothing
        else
            error(err.msg)
        end
    end
end

unsafe_getindex(node::Node, key) = unsafe_getindex(node, Symbol(key))

@inline function unsafe_getindex(node::Node{<:AbstractNodeMTG,ColumnarAttrs}, key::Symbol)
    get(node_attributes(node), key, nothing)
end

@inline function unsafe_getindex(node::Node{M,NamedTuple}, key::Symbol) where {M<:AbstractNodeMTG}
    attrs = node_attributes(node)
    hasproperty(attrs, key) ? getproperty(attrs, key) : nothing
end

@inline function unsafe_getindex(node::Node{M,MutableNamedTuple}, key::Symbol) where {M<:AbstractNodeMTG}
    attrs = node_attributes(node)
    hasproperty(attrs, key) ? getproperty(attrs, key) : nothing
end

# For a vector of keys:
function unsafe_getindex(node::Node, key::Union{Vector{Symbol},Vector{String}})
    vals = Vector{Any}(undef, length(key))
    @inbounds for i in eachindex(key)
        vals[i] = unsafe_getindex(node, key[i])
    end
    vals
end
function unsafe_getindex(
    node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict},
    key::Vector{Symbol}
)
    vals = Vector{Any}(undef, length(key))
    @inbounds for i in eachindex(key)
        vals[i] = unsafe_getindex(node, key[i])
    end
    vals
end

function unsafe_getindex(
    node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict},
    key::Union{Vector{String},Vector{Symbol}}
)
    unsafe_getindex(node, Symbol.(key))
end

function unsafe_getindex(
    node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict},
    key::Symbol
)
    get(node_attributes(node), key, nothing)
end

function unsafe_getindex(node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict}, key)
    unsafe_getindex(node, Symbol(key))
end

@inline function unsafe_getindex(node::Node{<:AbstractNodeMTG,ColumnarAttrs}, key::Symbol, plan::ColumnarQueryPlan)
    attrs = node_attributes(node)
    store = attrs.ref.store
    store === nothing && return nothing
    nodeid = node_id(node)
    nodeid > length(store.node_bucket) && return nothing
    bid = store.node_bucket[nodeid]
    bid == 0 && return nothing
    col_idx = plan.col_idx_by_bucket[bid]
    col_idx == 0 && return nothing
    row = store.node_row[nodeid]
    col = store.buckets[bid].columns[col_idx]
    return col.data[row]
end

@inline unsafe_getindex(node::Node, key::Symbol, plan) = unsafe_getindex(node, key)
@inline unsafe_getindex(node::Node, key, plan) = unsafe_getindex(node, Symbol(key), plan)

@inline function unsafe_setindex!(node::Node{<:AbstractNodeMTG,ColumnarAttrs}, key::Symbol, value)
    attrs = node_attributes(node)
    attrs[key] = value
    return value
end

@inline function unsafe_setindex!(node::Node, key::Symbol, value)
    node[key] = value
    return value
end

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
        for chnode in children(node)
            i[1] = i[1] + 1
            length_subtree(chnode, i)
        end
    end
end
