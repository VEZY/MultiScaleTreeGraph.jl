struct PreparedNodeEdits{S}
    store::MTGAttributeStore
    schema::S
end

"""
    prepare_node_edits(node)

Prepare repeated edits on the columnar tree containing `node`. The returned
plan borrows the tree's attribute store and records its column types.
Use `addchild!(plan, parent, id, encoding[, attributes])` to insert a child,
`attribute(plan, node, key[, default])` to read a tree attribute, and
`delete_node!(plan, node)` to remove a node using the usual child-promotion rules.

An empty attribute tuple is the default. New nodes and attribute names may
appear at any time. Each resulting column type must belong to the prepared
family. To introduce another type, declare its column with [`add_column!`](@ref)
and prepare a fresh plan. The plan is specific to this store.
"""
function prepare_node_edits(node::Node{M,ColumnarAttrs}) where {M}
    store = _store_for_node_attrs(node_attributes(node))
    isnothing(store) && throw(ArgumentError("Prepare edits on an attached node."))
    return PreparedNodeEdits(store, _column_row_schema(store))
end

function _check_edit_store(plan::PreparedNodeEdits, node)
    _store_for_node_attrs(node_attributes(node)) === plan.store ||
        throw(ArgumentError("The node does not belong to the prepared tree."))
    return nothing
end

function addchild!(plan::PreparedNodeEdits, parent::Node{M,ColumnarAttrs},
    id::Int, encoding::M, attributes::NamedTuple=(;)) where {M<:AbstractNodeMTG}
    _check_edit_store(plan, parent)
    return _node_with_columnar_attrs(id, parent, encoding, ColumnarAttrs(), attributes, plan.schema)
end

function delete_node!(plan::PreparedNodeEdits, node::Node{M,ColumnarAttrs}) where {M}
    _check_edit_store(plan, node)
    return _delete_node!(node, new_child_link, plan.schema)
end

function attribute(plan::PreparedNodeEdits, node::Node{M,ColumnarAttrs}, key::Symbol, default=nothing) where {M}
    _check_edit_store(plan, node)
    store, bid, row = _bucket_row(getfield(node_attributes(node), :ref))
    bucket = store.buckets[bid]
    slot = get(bucket.col_index, key, 0)
    iszero(slot) && return default
    column = _column(bucket, slot)
    _check_row_column_type(plan.schema, typeof(column))
    return _get_column_value(_row_column(plan.schema, column), row, default)
end
