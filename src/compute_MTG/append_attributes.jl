
# Mutation of the attributes of a node at the node level, with attributes as MutableNamedTuple:

"""
    append!(node::Node{M<:AbstractNodeMTG, <:MutableNamedTuple, GenericNode}, attr)
    append!(node::Node{M<:AbstractNodeMTG, <:Dict, GenericNode}, attr)

Append new attributes to a node attributes.
"""
function Base.append!(node::Node{M,T,D}, attr) where {M<:AbstractNodeMTG,T<:MutableNamedTuple,D}
    node.attributes = MutableNamedTuple{(keys(node.attributes)..., keys(attr)...)}((values(node.attributes)..., values(attr)...))
end

function Base.append!(node::Node{M,T,D}, attr) where {M<:AbstractNodeMTG,T<:NamedTuple,D}
    node.attributes = NamedTuple{(keys(node.attributes)..., keys(attr)...)}((values(node.attributes)..., values(attr)...))
end

# [...] or with attributes as Dict:
function Base.append!(node::Node{M,T,D}, attr::T) where {M<:AbstractNodeMTG,T<:AbstractDict,D}
    merge!(node.attributes, attr)
end

# And ensure compatibility between both so a script wouldn't be broken if we just change the
# type of the attributes:
function Base.append!(node::Node{<:AbstractNodeMTG,<:AbstractDict,D}, attr) where {D}
    merge!(node.attributes, Dict(zip(keys(attr), values(attr))))
end

function Base.pop!(node::Node{M,T,D}, key) where {M<:AbstractNodeMTG,T<:MutableNamedTuple,D}
    attr_keys = keys(node.attributes)
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node.attributes = MutableNamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node.attributes)[setdiff(1:end, i_drop)]...,))
end

function Base.pop!(node::Node{M,T,D}, key) where {M<:AbstractNodeMTG,T<:NamedTuple,D}
    attr_keys = keys(node.attributes)
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node.attributes = NamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node.attributes)[setdiff(1:end, i_drop)]...,))
end

function Base.pop!(node::Node{<:AbstractNodeMTG,<:AbstractDict,D}, key) where {D}
    pop!(node.attributes, key, nothing)

    return nothing
end

# Renaming attributes:
function rename!(node::Node{M,T,D}, old_new) where {M<:AbstractNodeMTG,T<:MutableNamedTuple,D}
    attr_keys = replace([i for i in keys(node.attributes)], old_new)
    node.attributes = MutableNamedTuple{attr_keys}(values(node.attributes))
end

function rename!(node::Node{M,T,D}, old_new) where {M<:AbstractNodeMTG,T<:NamedTuple,D}
    attr_keys = replace([i for i in keys(node.attributes)], old_new)
    node.attributes = NamedTuple{attr_keys}(values(node.attributes))
end

function rename!(node::Node{<:AbstractNodeMTG,<:AbstractDict,D}, old_new) where {D}
    replace!(node.attributes) do kv
        first(kv) == first(old_new) ? last(old_new) => last(kv) : kv
    end
end
