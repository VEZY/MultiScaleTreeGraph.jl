"""
    ==(a::Node, b::Node)

Test Node equality. The parent, children and siblings are not tested, only their id is.
"""
function Base.:(==)(a::T, b::T) where {T<:Node}
    isequal(a.name, b.name) &&
        isequal(a.id, b.id) &&
        isequal(
            isroot(a) ? nothing : parent(a).id,
            isroot(b) ? nothing : parent(b).id
        ) &&
        isequal(
            a.children !== nothing ? keys(a.children) : nothing,
            a.children !== nothing ? keys(a.children) : nothing
        ) &&
        isequal(
            a.siblings !== nothing ? keys(a.siblings) : nothing,
            a.siblings !== nothing ? keys(a.siblings) : nothing
        ) &&
        isequal(a.MTG, b.MTG) &&
        isequal(a.attributes, b.attributes)
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
