"""
    get_classes(mtg)

Compute the mtg classes based on its content. Usefull after having mutating the mtg nodes.
"""
function get_classes(mtg)
    attributes = traverse(mtg, node -> (SYMBOL=symbol(node), SCALE=scale(node)), type=@NamedTuple{SYMBOL::Symbol, SCALE::Int64})
    attributes = unique(attributes)
    n = length(attributes)
    symbols_ = Vector{Symbol}(undef, n)
    scales_ = Vector{Int}(undef, n)
    @inbounds for i in eachindex(attributes)
        symbols_[i] = attributes[i].SYMBOL
        scales_[i] = attributes[i].SCALE
    end

    ColumnTable(
        Symbol[:SYMBOL, :SCALE, :DECOMPOSITION, :INDEXATION, :DEFINITION],
        AbstractVector[
            symbols_,
            scales_,
            fill("FREE", n),
            fill("FREE", n),
            fill("IMPLICIT", n)
        ]
    )
end

"""
    get_description(mtg)

Returns `nothing`, because we can't really predict the description section from an mtg.
"""
function get_description(mtg)
    return nothing
end

@inline function _mtg_feature_type(value)
    T = typeof(value)
    if T <: AbstractFloat
        return "REAL"
    elseif T <: Bool
        return "BOOLEAN"
    elseif T <: Integer
        return "INT"
    elseif T <: Date
        return "DD/MM/YY"
    end
    return "STRING"
end

function _get_features_legacy(mtg)
    names_ = Symbol[]
    types_ = String[]
    seen = Set{Tuple{Symbol,String}}()

    traverse!(mtg) do node
        for (name, value) in pairs(node_attributes(node))
            T = typeof(value)
            if (T <: AbstractVector) || (T <: Nothing) || (name in (:description, :symbols, :scales))
                continue
            end

            typ = _mtg_feature_type(value)

            row = (Symbol(name), typ)
            if !(row in seen)
                push!(seen, row)
                push!(names_, row[1])
                push!(types_, row[2])
            end
        end
    end

    ColumnTable(Symbol[:NAME, :TYPE], AbstractVector[names_, types_])
end

function _record_column_features!(
    first_positions::Dict{Tuple{Symbol,String},Tuple{Int,Int}},
    positions::Dict{Int,Int},
    store::MTGAttributeStore,
    bid::Int,
    bucket::SymbolBucket,
    col_idx::Int,
    column::Column{T},
) where {T}
    @inbounds for row in eachindex(bucket.row_to_node)
        nodeid = bucket.row_to_node[row]
        position = get(positions, nodeid, 0)
        position == 0 && continue

        # A duplicated or stale reverse mapping could otherwise expose a value
        # that `pairs(node_attributes(node))` would never visit.
        nodeid <= length(store.node_bucket) || return false
        nodeid <= length(store.node_row) || return false
        store.node_bucket[nodeid] == bid || return false
        store.node_row[nodeid] == row || return false
        get(bucket.node_to_row, nodeid, 0) == row || return false
        isassigned(column.data, row) || return false

        value = column.data[row]
        value_type = typeof(value)
        ((value_type <: AbstractVector) || (value_type <: Nothing)) && continue
        feature = (column.name, _mtg_feature_type(value))
        candidate = (position, col_idx)
        previous = get(first_positions, feature, nothing)
        if previous === nothing || candidate < previous
            first_positions[feature] = candidate
        end
    end
    return true
end

function _get_features_columnar(mtg)
    ordered_nodes = Vector{typeof(mtg)}()
    traverse!(mtg) do node
        push!(ordered_nodes, node)
    end

    if isempty(ordered_nodes)
        return ColumnTable(
            Symbol[:NAME, :TYPE], AbstractVector[Symbol[], String[]]
        )
    end

    first_attrs = node_attributes(first(ordered_nodes))
    first_attrs isa ColumnarAttrs && _isbound(first_attrs) || return nothing
    store = first_attrs.ref.store::MTGAttributeStore
    positions = Dict{Int,Int}()
    sizehint!(positions, length(ordered_nodes))
    used_buckets = falses(length(store.buckets))

    # The traversal sequence is authoritative: `traverse!` may use a public,
    # user-supplied no-filter cache. Validate every reference before touching the
    # store directly; malformed or mixed stores retain the legacy behavior.
    @inbounds for position in eachindex(ordered_nodes)
        node = ordered_nodes[position]
        attrs = node_attributes(node)
        attrs isa ColumnarAttrs && _isbound(attrs) || return nothing
        attrs.ref.store === store || return nothing

        nodeid = node_id(node)
        nodeid > 0 || return nothing
        attrs.ref.node_id == nodeid || return nothing
        nodeid <= length(store.node_bucket) || return nothing
        nodeid <= length(store.node_row) || return nothing
        haskey(positions, nodeid) && return nothing

        bid = store.node_bucket[nodeid]
        row = store.node_row[nodeid]
        1 <= bid <= length(store.buckets) || return nothing
        bucket = store.buckets[bid]
        1 <= row <= length(bucket.row_to_node) || return nothing
        bucket.row_to_node[row] == nodeid || return nothing
        get(bucket.node_to_row, nodeid, 0) == row || return nothing
        positions[nodeid] = position
        used_buckets[bid] = true
    end

    first_positions = Dict{Tuple{Symbol,String},Tuple{Int,Int}}()
    for (bid, bucket) in pairs(store.buckets)
        used_buckets[bid] || continue
        nrows = length(bucket.row_to_node)
        length(bucket.columns) == length(bucket.col_types) || return nothing
        @inbounds for col_idx in eachindex(bucket.columns)
            column = _column(bucket, col_idx)
            column isa Column || return nothing
            get(bucket.col_index, column.name, 0) == col_idx || return nothing
            length(column.data) == nrows || return nothing
            column.name in (:description, :symbols, :scales) && continue
            _record_column_features!(
                first_positions,
                positions,
                store,
                bid,
                bucket,
                col_idx,
                column,
            ) || return nothing
        end
    end

    features = collect(keys(first_positions))
    sort!(features; by=feature -> first_positions[feature])
    names_ = Vector{Symbol}(undef, length(features))
    types_ = Vector{String}(undef, length(features))
    @inbounds for i in eachindex(features)
        names_[i], types_[i] = features[i]
    end
    return ColumnTable(Symbol[:NAME, :TYPE], AbstractVector[names_, types_])
end

"""
    get_features(mtg)

Compute the mtg features section based on its attributes. Usefull after having computed new attributes
in the mtg.
"""
function get_features(mtg)
    features = _get_features_columnar(mtg)
    return features === nothing ? _get_features_legacy(mtg) : features
end

"""
    scales(mtg)

Get all the scales of an MTG.
"""
function scales(mtg)
    vec = Int[]
    traverse(mtg) do node
        push!(vec, scale(node))
    end

    return unique(vec)
end

function symbols(mtg)
    vec = Symbol[]
    traverse!(mtg) do node
        push!(vec, symbol(node))
    end
    return unique(vec)
end

components = symbols

"""
    symbols(mtg)
    components(mtg)

Get all the symbols names, a.k.a. components of an MTG.
"""
components, symbols

"""
    list_nodes(mtg)

List all nodes IDs in the subtree of `mtg`.
"""
list_nodes(mtg) = traverse(mtg, node -> node_id(node), type=Int)

"""
    max_id(mtg)

Returns the maximum id of the mtg
"""
function max_id(mtg)
    maxid = Ref(0)

    function update_maxname(id, maxid)
        id > maxid[] ? maxid[] = id : nothing
    end

    traverse!(get_root(mtg), x -> update_maxname(node_id(x), maxid))

    return maxid[]
end
