"""
Marker type used by `read_mtg` to request the columnar attribute backend.
"""
struct ColumnarStore end

mutable struct Column{T}
    name::Symbol
    data::Vector{T}
    default::T
end

mutable struct SymbolBucket
    symbol::Symbol
    row_to_node::Vector{Int}
    node_to_row::Dict{Int,Int}
    col_index::Dict{Symbol,Int}
    columns::Vector{Any} # stores Column{T}
    col_types::Vector{Any}
end

function SymbolBucket(symbol::Symbol)
    SymbolBucket(symbol, Int[], Dict{Int,Int}(), Dict{Symbol,Int}(), Any[], Any[])
end

mutable struct MTGAttributeStore
    symbol_to_bucket::Dict{Symbol,Int}
    buckets::Vector{SymbolBucket}
    node_bucket::Vector{Int}
    node_row::Vector{Int}
end

function MTGAttributeStore()
    MTGAttributeStore(Dict{Symbol,Int}(), SymbolBucket[], Int[], Int[])
end

mutable struct NodeAttrRef
    store::Union{Nothing,MTGAttributeStore}
    node_id::Int
end

mutable struct ColumnarAttrs <: AbstractDict{Symbol,Any}
    ref::NodeAttrRef
    staged::Dict{Symbol,Any}
end

ColumnarAttrs() = ColumnarAttrs(NodeAttrRef(nothing, 0), Dict{Symbol,Any}())
function ColumnarAttrs(d::AbstractDict)
    staged = Dict{Symbol,Any}()
    for (k, v) in d
        staged[Symbol(k)] = v
    end
    ColumnarAttrs(NodeAttrRef(nothing, 0), staged)
end

@inline _isbound(attrs::ColumnarAttrs) = attrs.ref.store !== nothing && attrs.ref.node_id > 0

@inline function _ensure_node_capacity!(store::MTGAttributeStore, node_id::Int)
    if node_id > length(store.node_bucket)
        old = length(store.node_bucket)
        resize!(store.node_bucket, node_id)
        resize!(store.node_row, node_id)
        @inbounds for i in old+1:node_id
            store.node_bucket[i] = 0
            store.node_row[i] = 0
        end
    end
    return nothing
end

@inline function _normalize_attr_key(key)
    key isa Symbol ? key : Symbol(key)
end

function _get_or_create_bucket!(store::MTGAttributeStore, symbol::Symbol)
    bid = get(store.symbol_to_bucket, symbol, 0)
    if bid == 0
        push!(store.buckets, SymbolBucket(symbol))
        bid = length(store.buckets)
        store.symbol_to_bucket[symbol] = bid
    end
    return bid
end

@inline function _column(bucket::SymbolBucket, col_idx::Int)
    bucket.columns[col_idx]
end

function _widen_column!(bucket::SymbolBucket, col_idx::Int, ::Type{NewT}) where {NewT}
    old_col = bucket.columns[col_idx]
    old_data = old_col.data
    new_data = Vector{NewT}(undef, length(old_data))
    @inbounds for i in eachindex(old_data)
        new_data[i] = old_data[i]
    end
    new_default = convert(NewT, old_col.default)
    bucket.columns[col_idx] = Column{NewT}(old_col.name, new_data, new_default)
    bucket.col_types[col_idx] = NewT
    return bucket.columns[col_idx]
end

function _ensure_column_type!(bucket::SymbolBucket, col_idx::Int, value)
    T = bucket.col_types[col_idx]
    value_T = typeof(value)
    if value_T <: T
        return _column(bucket, col_idx)
    end
    NewT = Union{T,value_T}
    return _widen_column!(bucket, col_idx, NewT)
end

function _add_column_internal!(bucket::SymbolBucket, key::Symbol, ::Type{T}, default::T) where {T}
    haskey(bucket.col_index, key) && error("Column $(key) already exists for symbol $(bucket.symbol).")
    nrows = length(bucket.row_to_node)
    col = Column{T}(key, fill(default, nrows), default)
    push!(bucket.columns, col)
    push!(bucket.col_types, T)
    bucket.col_index[key] = length(bucket.columns)
    return nothing
end

function _add_nullable_column_internal!(bucket::SymbolBucket, key::Symbol, ::Type{T}) where {T}
    TT = Union{Nothing,T}
    _add_column_internal!(bucket, key, TT, nothing)
end

function _set_value!(bucket::SymbolBucket, row::Int, key::Symbol, value)
    col_idx = get(bucket.col_index, key, 0)
    if col_idx == 0
        if value === nothing
            _add_nullable_column_internal!(bucket, key, Any)
        else
            _add_nullable_column_internal!(bucket, key, typeof(value))
        end
        col_idx = bucket.col_index[key]
    end

    col = _ensure_column_type!(bucket, col_idx, value)
    col.data[row] = value
    return value
end

function _get_value(bucket::SymbolBucket, row::Int, key::Symbol, default=nothing)
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && return default
    _column(bucket, col_idx).data[row]
end

function _bucket_row(ref::NodeAttrRef)
    store = ref.store
    store === nothing && error("Columnar attributes are not bound to a store.")
    node_id = ref.node_id
    node_id <= 0 && error("Invalid node id for columnar attributes: $(node_id)")
    node_id > length(store.node_bucket) && error("Node id $(node_id) is outside of store bounds.")
    bid = store.node_bucket[node_id]
    row = store.node_row[node_id]
    bid == 0 && error("Node id $(node_id) is no longer attached to the attribute store.")
    return store, bid, row
end

function _add_node_with_attrs!(store::MTGAttributeStore, node_id::Int, symbol::Symbol, attrs::AbstractDict)
    _ensure_node_capacity!(store, node_id)
    bid = _get_or_create_bucket!(store, symbol)
    bucket = store.buckets[bid]

    row = length(bucket.row_to_node) + 1
    push!(bucket.row_to_node, node_id)
    bucket.node_to_row[node_id] = row

    @inbounds for i in eachindex(bucket.columns)
        col = bucket.columns[i]
        push!(col.data, col.default)
    end

    store.node_bucket[node_id] = bid
    store.node_row[node_id] = row

    for (k, v) in attrs
        _set_value!(bucket, row, _normalize_attr_key(k), v)
    end

    return nothing
end

function _remove_node!(store::MTGAttributeStore, node_id::Int)
    node_id > length(store.node_bucket) && return nothing
    bid = store.node_bucket[node_id]
    bid == 0 && return nothing

    bucket = store.buckets[bid]
    row = bucket.node_to_row[node_id]
    last_row = length(bucket.row_to_node)
    moved_node = 0

    if row != last_row
        moved_node = bucket.row_to_node[last_row]
        bucket.row_to_node[row] = moved_node
        bucket.node_to_row[moved_node] = row
    end
    pop!(bucket.row_to_node)
    delete!(bucket.node_to_row, node_id)

    @inbounds for i in eachindex(bucket.columns)
        col = bucket.columns[i]
        if row != last_row
            col.data[row] = col.data[last_row]
        end
        pop!(col.data)
    end

    if moved_node != 0
        store.node_row[moved_node] = row
    end
    store.node_bucket[node_id] = 0
    store.node_row[node_id] = 0
    return nothing
end

function _drop_column_internal!(bucket::SymbolBucket, key::Symbol)
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && return false
    delete!(bucket.col_index, key)
    deleteat!(bucket.columns, col_idx)
    deleteat!(bucket.col_types, col_idx)
    for i in col_idx:length(bucket.columns)
        bucket.col_index[_column(bucket, i).name] = i
    end
    return true
end

function _rename_column_internal!(bucket::SymbolBucket, from::Symbol, to::Symbol)
    from_idx = get(bucket.col_index, from, 0)
    from_idx == 0 && return false
    haskey(bucket.col_index, to) && error("Column $(to) already exists for symbol $(bucket.symbol).")
    delete!(bucket.col_index, from)
    bucket.col_index[to] = from_idx
    _column(bucket, from_idx).name = to
    return true
end

function _store_for_node_attrs(attrs::ColumnarAttrs)
    _isbound(attrs) || return nothing
    attrs.ref.store
end

function init_columnar_root!(attrs::ColumnarAttrs, node_id::Int, symbol::Symbol)
    _isbound(attrs) && return attrs
    store = MTGAttributeStore()
    _add_node_with_attrs!(store, node_id, symbol, attrs.staged)
    attrs.ref.store = store
    attrs.ref.node_id = node_id
    empty!(attrs.staged)
    return attrs
end

function bind_columnar_child!(parent_attrs::ColumnarAttrs, child_attrs::ColumnarAttrs, node_id::Int, symbol::Symbol)
    if _isbound(child_attrs)
        child_attrs.ref.node_id = node_id
        return child_attrs
    end

    store = _store_for_node_attrs(parent_attrs)
    store === nothing && error("Parent node is not attached to a columnar attribute store.")
    _add_node_with_attrs!(store, node_id, symbol, child_attrs.staged)
    child_attrs.ref.store = store
    child_attrs.ref.node_id = node_id
    empty!(child_attrs.staged)
    return child_attrs
end

function remove_columnar_node!(attrs::ColumnarAttrs)
    store = _store_for_node_attrs(attrs)
    store === nothing && return nothing
    _remove_node!(store, attrs.ref.node_id)
    attrs.ref.node_id = 0
    return nothing
end

function add_column!(store::MTGAttributeStore, symbol::Symbol, key::Symbol, ::Type{T}; default::T) where {T}
    bid = _get_or_create_bucket!(store, symbol)
    _add_column_internal!(store.buckets[bid], key, T, default)
    return store
end

function drop_column!(store::MTGAttributeStore, symbol::Symbol, key::Symbol)
    bid = get(store.symbol_to_bucket, symbol, 0)
    bid == 0 && return store
    _drop_column_internal!(store.buckets[bid], key)
    return store
end

function rename_column!(store::MTGAttributeStore, symbol::Symbol, from::Symbol, to::Symbol)
    bid = get(store.symbol_to_bucket, symbol, 0)
    bid == 0 && return store
    _rename_column_internal!(store.buckets[bid], from, to)
    return store
end

function Base.length(attrs::ColumnarAttrs)
    if !_isbound(attrs)
        return length(attrs.staged)
    end
    _, bid, _ = _bucket_row(attrs.ref)
    return length(attrs.ref.store.buckets[bid].columns)
end

function Base.keys(attrs::ColumnarAttrs)
    if !_isbound(attrs)
        return collect(keys(attrs.staged))
    end
    _, bid, _ = _bucket_row(attrs.ref)
    bucket = attrs.ref.store.buckets[bid]
    out = Vector{Symbol}(undef, length(bucket.columns))
    @inbounds for i in eachindex(bucket.columns)
        out[i] = _column(bucket, i).name
    end
    out
end

function Base.haskey(attrs::ColumnarAttrs, key::Symbol)
    if !_isbound(attrs)
        return haskey(attrs.staged, key)
    end
    _, bid, _ = _bucket_row(attrs.ref)
    haskey(attrs.ref.store.buckets[bid].col_index, key)
end
Base.haskey(attrs::ColumnarAttrs, key) = haskey(attrs, _normalize_attr_key(key))

function Base.getindex(attrs::ColumnarAttrs, key::Symbol)
    if !_isbound(attrs)
        return attrs.staged[key]
    end
    store, bid, row = _bucket_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && throw(KeyError(key))
    return _column(bucket, col_idx).data[row]
end
Base.getindex(attrs::ColumnarAttrs, key) = getindex(attrs, _normalize_attr_key(key))

function Base.get(attrs::ColumnarAttrs, key::Symbol, default)
    if !_isbound(attrs)
        return get(attrs.staged, key, default)
    end
    store, bid, row = _bucket_row(attrs.ref)
    return _get_value(store.buckets[bid], row, key, default)
end
Base.get(attrs::ColumnarAttrs, key, default) = get(attrs, _normalize_attr_key(key), default)

function Base.setindex!(attrs::ColumnarAttrs, value, key::Symbol)
    if !_isbound(attrs)
        attrs.staged[key] = value
        return value
    end
    store, bid, row = _bucket_row(attrs.ref)
    _set_value!(store.buckets[bid], row, key, value)
    return value
end
Base.setindex!(attrs::ColumnarAttrs, value, key) = setindex!(attrs, value, _normalize_attr_key(key))

function Base.iterate(attrs::ColumnarAttrs, state=nothing)
    if !_isbound(attrs)
        return state === nothing ? iterate(attrs.staged) : iterate(attrs.staged, state)
    end
    k = keys(attrs)
    i = state === nothing ? 1 : state
    i > length(k) && return nothing
    key = k[i]
    return (key => get(attrs, key, nothing), i + 1)
end

function Base.pop!(attrs::ColumnarAttrs, key, default=nothing)
    key_ = _normalize_attr_key(key)
    if !_isbound(attrs)
        return pop!(attrs.staged, key_, default)
    end

    store, bid, row = _bucket_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key_, 0)
    col_idx == 0 && return default
    old = _column(bucket, col_idx).data[row]
    _drop_column_internal!(bucket, key_)
    return old
end

function Base.delete!(attrs::ColumnarAttrs, key)
    pop!(attrs, key, nothing)
    return attrs
end

function Base.empty!(attrs::ColumnarAttrs)
    if !_isbound(attrs)
        empty!(attrs.staged)
        return attrs
    end
    store, bid, _ = _bucket_row(attrs.ref)
    bucket = store.buckets[bid]
    empty!(bucket.col_index)
    empty!(bucket.columns)
    empty!(bucket.col_types)
    return attrs
end

Base.copy(attrs::ColumnarAttrs) = Dict{Symbol,Any}(pairs(attrs))

function Base.show(io::IO, attrs::ColumnarAttrs)
    print(io, "ColumnarAttrs(", Dict{Symbol,Any}(pairs(attrs)), ")")
end
