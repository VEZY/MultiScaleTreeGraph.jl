"""
    ==(a::Node, b::Node)

Test Node equality. The parent, children and siblings are not tested, only their id is.
"""
function Base.:(==)(a::T, b::T) where {T<:Node}
    isequal(node_id(a), node_id(b)) &&
        isequal(
            isroot(a) ? nothing : node_id(parent(a)),
            isroot(b) ? nothing : node_id(parent(b))
        ) &&
        isequal(
            children(a) !== nothing ? keys(children(a)) : nothing,
            children(a) !== nothing ? keys(children(a)) : nothing
        ) &&
        isequal(node_mtg(a), node_mtg(b)) &&
        isequal(node_attributes(a), node_attributes(b))
end

"""
    ==(a::Node, b::Node)

Test AbstractNodeMTG equality.
"""
function Base.:(==)(a::T, b::T) where {T<:AbstractNodeMTG}
    isequal(a.link, b.link) &&
        isequal(a.symbol, b.symbol) &&
        isequal(a.index, b.index) &&
        isequal(a.scale, b.scale)
end
