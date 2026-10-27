# Logical attribute references retain a node/row identity, never a physical row.
struct NodeAttributeRef{T,N<:AbstractMTGNode} <: Ref{T}
    node::N
    key::Symbol
end

struct ColumnarAttributeRef{T} <: Ref{T}
    attrs::ColumnarAttrs
    key::Symbol
    generation::UInt64
end

Base.eltype(::Type{NodeAttributeRef{T,N}}) where {T,N} = T
Base.eltype(::Type{ColumnarAttributeRef{T}}) where {T} = T

@inline function _checked_attribute_value(value, ::Type{T}, key) where {T}
    value isa T || throw(TypeError(:attribute_ref, "attribute $(key)", T, value))
    return value::T
end

@inline function _attribute_ref_location(reference::ColumnarAttributeRef)
    attrs = reference.attrs
    attrs.ref.generation == reference.generation || throw(ArgumentError(
        "attribute reference belongs to a removed or rebound node",
    ))
    return _bucket_row(attrs.ref)
end

@inline function _typed_attribute_ref_value(bucket::SymbolBucket, row::Int, key::Symbol, ::Type{T}) where {T}
    column_index = get(bucket.col_index, key, 0)
    column_index == 0 && throw(KeyError(key))
    if bucket.col_types[column_index] === T
        column = bucket.columns[column_index]::Column{T}
        _row_has_value(column, row) || throw(KeyError(key))
        return @inbounds column.data[row]
    elseif bucket.col_types[column_index] === Union{Nothing,T}
        column = bucket.columns[column_index]::Column{Union{Nothing,T}}
        _row_has_value(column, row) || throw(KeyError(key))
        value = @inbounds column.data[row]
        return _checked_attribute_value(value, T, key)
    end
    column = bucket.columns[column_index]
    _row_has_value(column, row) || throw(KeyError(key))
    return _checked_attribute_value(column.data[row], T, key)
end

@inline function Base.getindex(reference::ColumnarAttributeRef{T}) where {T}
    store, bid, row = _attribute_ref_location(reference)
    return _typed_attribute_ref_value(store.buckets[bid], row, reference.key, T)
end

@inline function Base.setindex!(reference::ColumnarAttributeRef{T}, value) where {T}
    store, bid, row = _attribute_ref_location(reference)
    converted = convert(T, value)::T
    # A reference denotes an existing variable, not an instruction to recreate
    # a column which another client removed or renamed.
    _typed_attribute_ref_value(store.buckets[bid], row, reference.key, T)
    _set_value_bound!(store.buckets[bid], row, reference.key, converted)
    return converted
end

@inline function Base.getindex(reference::NodeAttributeRef{T}) where {T}
    return _checked_attribute_value(node_attributes(reference.node)[reference.key], T, reference.key)
end

@inline function Base.setindex!(reference::NodeAttributeRef{T}, value) where {T}
    attrs = node_attributes(reference.node)
    _checked_attribute_value(attrs[reference.key], T, reference.key)
    converted = convert(T, value)::T
    attrs[reference.key] = converted
    return converted
end

"""
    attribute_ref(node, key, ::Type{T}) -> Ref{T}
    attribute_ref(node, key) -> Ref

Return a live, typed reference to an existing attribute. Reads and writes use
its logical node identity; they do not cache a physical row or column pointer.
Values must remain instances of `T`, and assignments use ordinary `Ref{T}`
conversion rules. A missing attribute raises `KeyError`; an incompatible value
raises `TypeError`. Scientific mutable values retain their shallow aliases.

References on ordinary `Node`s require the columnar attribute backend. They
survive row compaction, schema widening,
subtree migration and `columnarize!`. Removing or rebinding the owning row
invalidates it permanently, even if its numeric ID is later reused. The default
custom-node implementation delegates to `node_attributes`; its backend must
reject removed handles. This is explicit shared storage: it does not create an
independent simulation state or claim exclusive ownership of the attribute.
These are logical scalar cells, not stable memory addresses for pointer-based FFI.
"""
function attribute_ref(node::AbstractMTGNode, key, ::Type{T}) where {T}
    normalized_key = Symbol(key)
    _checked_attribute_value(node_attributes(node)[normalized_key], T, normalized_key)
    return NodeAttributeRef{T,typeof(node)}(node, normalized_key)
end

function attribute_ref(node::Node{N,ColumnarAttrs}, key, ::Type{T}) where {N<:AbstractNodeMTG,T}
    normalized_key = Symbol(key)
    attrs = node_attributes(node)
    _bucket_row(attrs.ref)
    _checked_attribute_value(attrs[normalized_key], T, normalized_key)
    return ColumnarAttributeRef{T}(attrs, normalized_key, attrs.ref.generation)
end

function attribute_ref(node::Node, key, ::Type{T}) where {T}
    throw(ArgumentError("attribute_ref for Node requires the columnar attribute backend"))
end

attribute_ref(node::AbstractMTGNode, key) = attribute_ref(node, key, typeof(node_attributes(node)[Symbol(key)]))
