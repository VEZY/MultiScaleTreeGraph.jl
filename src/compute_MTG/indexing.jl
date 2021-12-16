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