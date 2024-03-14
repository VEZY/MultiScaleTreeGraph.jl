
# Mutation of the attributes of a node at the node level, with attributes as MutableNamedTuple:

"""
    append!(node::Node{M<:AbstractNodeMTG, <:MutableNamedTuple, GenericNode}, attr)
    append!(node::Node{M<:AbstractNodeMTG, <:Dict, GenericNode}, attr)

Append new attributes to a node attributes.
"""
function Base.append!(node::Node{M,T}, attr) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    node_attributes!(node, MutableNamedTuple{(keys(node_attributes(node))..., keys(attr)...)}((values(node_attributes(node))..., values(attr)...)))
end

function Base.append!(node::Node{M,T}, attr) where {M<:AbstractNodeMTG,T<:NamedTuple}
    node_attributes!(node, NamedTuple{(keys(node_attributes(node))..., keys(attr)...)}((values(node_attributes(node))..., values(attr)...)))
end

# [...] or with attributes as Dict:
function Base.append!(node::Node{M,T}, attr::T) where {M<:AbstractNodeMTG,T<:AbstractDict}
    merge!(node_attributes(node), attr)
end

# And ensure compatibility between both so a script wouldn't be broken if we just change the
# type of the attributes:
function Base.append!(node::Node{<:AbstractNodeMTG,<:AbstractDict}, attr)
    merge!(node_attributes(node), Dict(zip(keys(attr), values(attr))))
end

function Base.pop!(node::Node{M,T}, key) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    attr_keys = keys(node_attributes(node))
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node_attributes!(node, MutableNamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node_attributes(node))[setdiff(1:end, i_drop)]...,)))
end

function Base.pop!(node::Node{M,T}, key) where {M<:AbstractNodeMTG,T<:NamedTuple}
    attr_keys = keys(node_attributes(node))
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node_attributes!(node, NamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node_attributes(node))[setdiff(1:end, i_drop)]...,)))
end

function Base.pop!(node::Node{<:AbstractNodeMTG,<:AbstractDict}, key)
    poped_value = pop!(node_attributes(node), key, nothing)

    return poped_value
end

# Renaming attributes:
function rename!(node::Node{M,T}, old_new) where {M<:AbstractNodeMTG,T<:MutableNamedTuple}
    attr_keys = replace([i for i in keys(node_attributes(node))], old_new)
    node_attributes!(node, MutableNamedTuple{attr_keys}(values(node_attributes(node))))
end

function rename!(node::Node{M,T}, old_new) where {M<:AbstractNodeMTG,T<:NamedTuple}
    attr_keys = replace([i for i in keys(node_attributes(node))], old_new)
    node_attributes!(node, NamedTuple{attr_keys}(values(node_attributes(node))))
end

function rename!(node::Node{<:AbstractNodeMTG,<:AbstractDict}, old_new)
    attrs = node_attributes(node)
    replace!(attrs) do kv
        first(kv) == first(old_new) ? last(old_new) => last(kv) : kv
    end
end
