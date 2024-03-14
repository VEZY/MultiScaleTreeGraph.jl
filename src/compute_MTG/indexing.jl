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

# For a vector of keys:
unsafe_getindex(node::Node, key::Union{Vector{Symbol},Vector{String}}) = [unsafe_getindex(node, i) for i in key]
function unsafe_getindex(
    node::Node{M,T} where {M<:AbstractNodeMTG,T<:AbstractDict{Symbol,S} where {S}},
    key::Union{Vector{Symbol},Vector{String}}
)
    [unsafe_getindex(node, i) for i in key]
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
