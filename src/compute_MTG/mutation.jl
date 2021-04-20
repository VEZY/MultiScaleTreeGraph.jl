
# Mutation of the attributes of a node at the node level, with attributes as MutableNamedTuple:

"""
    append!(node::Node{NodeMTG, <:MutableNamedTuple}, attr)
    append!(node::Node{NodeMTG, <:Dict}, attr)

Append new attributes to a node attributes.
"""
function Base.append!(node::Node{NodeMTG, T}, attr) where T<:Union{MutableNamedTuple,NamedTuple}
    node.attributes = MutableNamedTuple{(keys(node.attributes)...,keys(attr)...)}((values(node.attributes)...,values(attr)...))
end

# [...] or with attributes as Dict:
function Base.append!(node::Node{NodeMTG, T}, attr::T) where T<:AbstractDict
    merge!(node.attributes, attr)
end

# And ensure compatibility between both so a script wouldn't be broken if we just change the
# type of the attributes:
function Base.append!(node::Node{NodeMTG, <:AbstractDict}, attr)
    merge!(node.attributes, Dict(zip(keys(attr),values(attr))))
end
