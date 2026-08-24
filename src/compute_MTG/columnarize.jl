"""
    columnarize!(mtg::Node)

Bind all node attributes to a single `MTGAttributeStore`.
"""
function columnarize!(mtg::Node)
    root = get_root(mtg)
    nodes = traverse(root, node -> node, type=typeof(root))
    isempty(nodes) && return mtg

    store = MTGAttributeStore()
    for n in nodes
        if _maybe_traversal_cache(n) !== nothing
            _register_traversal_cache!(store, n)
        end
        attrs = node_attributes(n)
        attrs isa ColumnarAttrs || error("columnarize! expects nodes with ColumnarAttrs attributes.")
        raw = _isbound(attrs) ? Dict{Symbol,Any}(pairs(attrs)) : attrs.staged
        _add_node_with_attrs!(store, node_id(n), symbol(n), raw)
    end

    for n in nodes
        attrs = node_attributes(n)::ColumnarAttrs
        attrs.ref.store = store
        attrs.ref.node_id = node_id(n)
        empty!(attrs.staged)
    end
    return mtg
end
