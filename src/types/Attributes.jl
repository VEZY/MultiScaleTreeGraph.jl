"""
Marker type used by `read_mtg` to request the columnar attribute backend.
"""
struct ColumnarStore end

mutable struct SubtreeIndexCache
    dirty::Bool
    built::Bool
    strategy::Symbol
    query_count::Int
    mutation_count::Int
    tin::Vector{Int}
    tout::Vector{Int}
    dfs_order::Vector{Int}
end

SubtreeIndexCache() = SubtreeIndexCache(true, false, :auto, 0, 0, Int[], Int[], Int[])

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
    subtree_index::SubtreeIndexCache
end

struct ColumnarQueryPlan
    key::Symbol
    col_idx_by_bucket::Vector{Int}
end

function MTGAttributeStore()
    MTGAttributeStore(Dict{Symbol,Int}(), SymbolBucket[], Int[], Int[], SubtreeIndexCache())
end

@inline function _validate_descendants_strategy(strategy::Symbol)
    strategy in (:auto, :pointer, :indexed) && return strategy
    error("Unknown descendants strategy $(strategy). Expected :auto, :pointer, or :indexed.")
end

@inline descendants_strategy(store::MTGAttributeStore) = store.subtree_index.strategy

function descendants_strategy!(store::MTGAttributeStore, strategy::Symbol)
    store.subtree_index.strategy = _validate_descendants_strategy(strategy)
    return store
end

@inline function _mark_subtree_index_mutation!(store::MTGAttributeStore)
    idx = store.subtree_index
    idx.dirty = true
    if idx.built
        idx.mutation_count += 1
    end
    return nothing
end

@inline function _can_use_index_without_rebuild(store::MTGAttributeStore)
    idx = store.subtree_index
    idx.built && !idx.dirty
end

@inline function _descendants_should_rebuild_auto(idx::SubtreeIndexCache)
    # Keep pointer traversal for mutation-heavy periods; switch when queries dominate.
    idx.query_count >= max(4, 2 * idx.mutation_count)
end

function _rebuild_subtree_index!(store::MTGAttributeStore, root)
    nmax = length(store.node_bucket)
    tin = Vector{Int}(undef, nmax)
    tout = Vector{Int}(undef, nmax)
    @inbounds for i in 1:nmax
        tin[i] = 0
        tout[i] = 0
    end

    nactive = 0
    @inbounds for i in 1:nmax
        nactive += store.node_bucket[i] == 0 ? 0 : 1
    end
    dfs_order = Int[]
    sizehint!(dfs_order, nactive)

    stack_nodes = Vector{typeof(root)}(undef, 1)
    stack_pos = Vector{Int}(undef, 1)
    stack_nodes[1] = root
    stack_pos[1] = 0
    t = 0

    while !isempty(stack_nodes)
        current = stack_nodes[end]
        pos = stack_pos[end]

        if pos == 0
            nid = node_id(current)
            t += 1
            tin[nid] = t
            push!(dfs_order, nid)
            stack_pos[end] = 1
            pos = 1
        end

        ch = children(current)
        if pos <= length(ch)
            stack_pos[end] = pos + 1
            push!(stack_nodes, ch[pos])
            push!(stack_pos, 0)
        else
            tout[node_id(current)] = t
            pop!(stack_nodes)
            pop!(stack_pos)
        end
    end

    idx = store.subtree_index
    idx.tin = tin
    idx.tout = tout
    idx.dfs_order = dfs_order
    idx.dirty = false
    idx.built = true
    idx.query_count = 0
    idx.mutation_count = 0
    return idx
end

function _prepare_subtree_index!(store::MTGAttributeStore, root)
    idx = store.subtree_index
    strategy = idx.strategy

    if strategy === :pointer
        return false
    elseif strategy === :indexed
        _can_use_index_without_rebuild(store) || _rebuild_subtree_index!(store, root)
        return true
    end

    # :auto
    if _can_use_index_without_rebuild(store)
        return true
    end

    idx.query_count += 1
    if _descendants_should_rebuild_auto(idx)
        _rebuild_subtree_index!(store, root)
        return true
    end

    return false
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

@inline function _bound_store_bid_row(ref::NodeAttrRef)
    store = ref.store::MTGAttributeStore
    node_id = ref.node_id
    @inbounds bid = store.node_bucket[node_id]
    @inbounds row = store.node_row[node_id]
    return store, bid, row
end

function _add_node_with_attrs!(store::MTGAttributeStore, node_id::Int, symbol::Symbol, attrs::AbstractDict)
    _mark_subtree_index_mutation!(store)
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
    _mark_subtree_index_mutation!(store)
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

@inline function _columnar_store(node)
    attrs = node_attributes(node)
    attrs isa ColumnarAttrs || return nothing
    _store_for_node_attrs(attrs)
end

function build_columnar_query_plan(node, key::Symbol)
    store = _columnar_store(node)
    store === nothing && return nothing
    col_idx_by_bucket = Vector{Int}(undef, length(store.buckets))
    @inbounds for i in eachindex(store.buckets)
        col_idx_by_bucket[i] = get(store.buckets[i].col_index, key, 0)
    end
    ColumnarQueryPlan(key, col_idx_by_bucket)
end

@inline function _symbol_bucket_ids(store::MTGAttributeStore, symbol_filter)
    if symbol_filter === nothing
        return collect(eachindex(store.buckets))
    elseif symbol_filter isa Symbol
        bid = get(store.symbol_to_bucket, symbol_filter, 0)
        return bid == 0 ? Int[] : Int[bid]
    elseif symbol_filter isa Union{Tuple,AbstractArray}
        out = Int[]
        for sym in symbol_filter
            bid = get(store.symbol_to_bucket, Symbol(sym), 0)
            bid == 0 || push!(out, bid)
        end
        return out
    else
        bid = get(store.symbol_to_bucket, Symbol(symbol_filter), 0)
        return bid == 0 ? Int[] : Int[bid]
    end
end

@inline function _remove_nothing_type(T)
    T === Nothing && return Union{}
    parts = Base.uniontypes(T)
    isempty(parts) && return T
    kept = [p for p in parts if p !== Nothing]
    if isempty(kept)
        return Union{}
    elseif length(kept) == 1
        return kept[1]
    end
    acc = Union{kept[1],kept[2]}
    @inbounds for i in 3:length(kept)
        acc = Union{acc,kept[i]}
    end
    return acc
end

function infer_columnar_attr_type(node, key::Symbol, symbol_filter, ignore_nothing::Bool)
    store = _columnar_store(node)
    store === nothing && return Any
    bucket_ids = _symbol_bucket_ids(store, symbol_filter)
    isempty(bucket_ids) && return Any

    has_any = false
    missing_in_some = false
    T = Union{}

    @inbounds for bid in bucket_ids
        bucket = store.buckets[bid]
        col_idx = get(bucket.col_index, key, 0)
        if col_idx == 0
            missing_in_some = true
            continue
        end
        has_any = true
        col_T = bucket.col_types[col_idx]
        T = T === Union{} ? col_T : typejoin(T, col_T)
    end

    has_any || return Any

    if ignore_nothing
        Tnn = _remove_nothing_type(T)
        return Tnn === Union{} ? Any : Tnn
    end

    if missing_in_some
        return Union{Nothing,T}
    end

    return T
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
    store, bid, _ = _bound_store_bid_row(attrs.ref)
    return length(store.buckets[bid].columns)
end

function Base.keys(attrs::ColumnarAttrs)
    if !_isbound(attrs)
        return collect(keys(attrs.staged))
    end
    store, bid, _ = _bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bid]
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
    store, bid, _ = _bound_store_bid_row(attrs.ref)
    haskey(store.buckets[bid].col_index, key)
end
Base.haskey(attrs::ColumnarAttrs, key) = haskey(attrs, _normalize_attr_key(key))

function Base.getindex(attrs::ColumnarAttrs, key::Symbol)
    if !_isbound(attrs)
        return attrs.staged[key]
    end
    store, bid, row = _bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && throw(KeyError(key))
    return _column(bucket, col_idx).data[row]
end
Base.getindex(attrs::ColumnarAttrs, key) = getindex(attrs, _normalize_attr_key(key))

@inline function _column_matches_exact_type(bucket::SymbolBucket, col_idx::Int, ::Type{T}) where {T}
    bucket.col_types[col_idx] === T
end

@inline function _column_matches_nullable_type(bucket::SymbolBucket, col_idx::Int, ::Type{T}) where {T}
    bucket.col_types[col_idx] === Union{Nothing,T}
end

@inline function _get_typed_numeric(attrs::ColumnarAttrs, key::Symbol, default::T) where {T<:Number}
    if !_isbound(attrs)
        v = get(attrs.staged, key, default)
        v === nothing && return nothing
        return v isa T ? v : (convert(T, v)::T)
    end

    store, bid, row = _bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && return default

    if _column_matches_exact_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{T}
        return @inbounds col.data[row]
    elseif _column_matches_nullable_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{Union{Nothing,T}}
        return @inbounds col.data[row]
    end

    v = _get_value(bucket, row, key, default)
    v === nothing && return nothing
    return v isa T ? v : (convert(T, v)::T)
end

function Base.get(attrs::ColumnarAttrs, key::Symbol, default::T) where {T}
    if !_isbound(attrs)
        return get(attrs.staged, key, default)
    end
    store, bid, row = _bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key, 0)
    col_idx == 0 && return default

    if _column_matches_exact_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{T}
        return @inbounds col.data[row]
    elseif _column_matches_nullable_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{Union{Nothing,T}}
        return @inbounds col.data[row]
    end

    return _get_value(bucket, row, key, default)
end
Base.get(attrs::ColumnarAttrs, key, default) = get(attrs, _normalize_attr_key(key), default)

function Base.setindex!(attrs::ColumnarAttrs, value::T, key::Symbol) where {T}
    if !_isbound(attrs)
        attrs.staged[key] = value
        return value
    end
    store, bid, row = _bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bid]
    col_idx = get(bucket.col_index, key, 0)
    if col_idx == 0
        _set_value!(bucket, row, key, value)
        return value
    end

    if _column_matches_exact_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{T}
        @inbounds col.data[row] = value
    elseif _column_matches_nullable_type(bucket, col_idx, T)
        col = bucket.columns[col_idx]::Column{Union{Nothing,T}}
        @inbounds col.data[row] = value
    else
        _set_value!(bucket, row, key, value)
    end

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

    store, bid, row = _bound_store_bid_row(attrs.ref)
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
    store, bid, _ = _bound_store_bid_row(attrs.ref)
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
