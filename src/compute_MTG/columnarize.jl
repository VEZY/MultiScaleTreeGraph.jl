"""
    columnarize!(mtg::Node)

Bind all node attributes to a single `MTGAttributeStore`.

The store that owns the root node is the schema authority. Its column types,
order, defaults, and row-local absences are preserved. Nodes imported from a
different store keep their current values and receive root-store defaults for
attributes they do not currently have, matching the normal subtree-attachment
semantics.
"""
function columnarize!(mtg::Node)
    root = get_root(mtg)
    nodes = traverse(root, node -> node, type=typeof(root))
    isempty(nodes) && return mtg

    root_attrs = node_attributes(root)
    root_attrs isa ColumnarAttrs ||
        error("columnarize! expects nodes with ColumnarAttrs attributes.")
    root_store = _store_for_node_attrs(root_attrs)
    store = MTGAttributeStore()
    root_store === nothing || _copy_columnar_schema!(store, root_store)
    for n in nodes
        if _maybe_traversal_cache(n) !== nothing
            _register_traversal_cache!(store, n)
        end
        attrs = node_attributes(n)
        attrs isa ColumnarAttrs ||
            error("columnarize! expects nodes with ColumnarAttrs attributes.")
        source_store = _store_for_node_attrs(attrs)
        raw = _isbound(attrs) ? Dict{Symbol,Any}(pairs(attrs)) : attrs.staged
        _add_node_with_attrs!(store, node_id(n), symbol(n), raw)
        if root_store !== nothing && source_store === root_store
            _restore_root_row_absences!(store, root_store, node_id(n))
        end
    end

    for n in nodes
        attrs = node_attributes(n)::ColumnarAttrs
        attrs.ref.store = store
        attrs.ref.node_id = node_id(n)
        empty!(attrs.staged)
    end
    return mtg
end

function _copy_columnar_schema!(target::MTGAttributeStore, source::MTGAttributeStore)
    for source_bucket in source.buckets
        target_bid = _get_or_create_bucket!(target, source_bucket.symbol)
        target_bucket = target.buckets[target_bid]
        @inbounds for i in eachindex(source_bucket.columns)
            source_column = _column(source_bucket, i)
            _copy_column_schema!(target_bucket, source_column)
        end
    end
    return target
end

@inline function _copy_column_schema!(target_bucket::SymbolBucket, source::Column{T}) where {T}
    _add_column_internal!(
        target_bucket,
        source.name,
        T,
        source.default,
        source.default_present,
    )
    return nothing
end

function _restore_root_row_absences!(
    target::MTGAttributeStore,
    source::MTGAttributeStore,
    node_id::Int,
)
    source_bid = source.node_bucket[node_id]
    source_row = source.node_row[node_id]
    target_bid = target.node_bucket[node_id]
    target_row = target.node_row[node_id]
    source_bucket = source.buckets[source_bid]
    target_bucket = target.buckets[target_bid]
    source_bucket.symbol === target_bucket.symbol || return nothing

    @inbounds for i in eachindex(source_bucket.columns)
        source_column = _column(source_bucket, i)
        if !source_column.present[source_row]
            target_column = _column(target_bucket, target_bucket.col_index[source_column.name])
            _mark_row_absent!(target_column, target_row)
        end
    end
    return nothing
end
