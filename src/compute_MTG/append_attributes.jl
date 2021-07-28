
# Mutation of the attributes of a node at the node level, with attributes as MutableNamedTuple:

"""
    append!(node::Node{M<:AbstractNodeMTG, <:MutableNamedTuple}, attr)
    append!(node::Node{M<:AbstractNodeMTG, <:Dict}, attr)

Append new attributes to a node attributes.
"""
function Base.append!(node::Node{M,T}, attr) where {M <: AbstractNodeMTG,T <: MutableNamedTuple}
    node.attributes = MutableNamedTuple{(keys(node.attributes)..., keys(attr)...)}((values(node.attributes)..., values(attr)...))
end

function Base.append!(node::Node{M,T}, attr) where {M <: AbstractNodeMTG,T <: NamedTuple}
    node.attributes = NamedTuple{(keys(node.attributes)..., keys(attr)...)}((values(node.attributes)..., values(attr)...))
end

# [...] or with attributes as Dict:
function Base.append!(node::Node{M,T}, attr::T) where {M <: AbstractNodeMTG,T <: AbstractDict}
    merge!(node.attributes, attr)
end

# And ensure compatibility between both so a script wouldn't be broken if we just change the
# type of the attributes:
function Base.append!(node::Node{<: AbstractNodeMTG,<:AbstractDict}, attr)
    merge!(node.attributes, Dict(zip(keys(attr), values(attr))))
end



function Base.pop!(node::Node{M,T}, key) where {M <: AbstractNodeMTG,T <: MutableNamedTuple}
    attr_keys = keys(node.attributes)
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node.attributes = MutableNamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node.attributes)[setdiff(1:end, i_drop)]...,))
end

function Base.pop!(node::Node{M,T}, key) where {M <: AbstractNodeMTG,T <: NamedTuple}
    attr_keys = keys(node.attributes)
    i_drop = findfirst(x -> x == key, attr_keys)
    i_drop === nothing && return nothing
    node.attributes = NamedTuple{(attr_keys[setdiff(1:end, i_drop)]...,)}((values(node.attributes)[setdiff(1:end, i_drop)]...,))
end

function Base.pop!(node::Node{<: AbstractNodeMTG,<:AbstractDict}, key)
    pop!(node.attributes, key, nothing)

    return nothing
end
