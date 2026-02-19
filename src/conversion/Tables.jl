struct MTGAttrColumnView{N,T} <: AbstractVector{T}
    nodes::Vector{N}
    key::Symbol
end

Base.IndexStyle(::Type{<:MTGAttrColumnView}) = IndexLinear()
Base.size(col::MTGAttrColumnView) = (length(col.nodes),)
Base.length(col::MTGAttrColumnView) = length(col.nodes)

@inline function Base.getindex(col::MTGAttrColumnView{N,T}, i::Int) where {N,T}
    v = attribute(col.nodes[i], col.key, nothing)
    return v === nothing ? (missing::T) : (v::T)
end

@inline _to_table_key(key::Symbol) = key
@inline _to_table_key(key) = Symbol(key)

@inline _to_table_vars(vars::Nothing) = nothing
@inline _to_table_vars(var::Symbol) = Symbol[var]
@inline _to_table_vars(var::AbstractString) = Symbol[Symbol(var)]
@inline function _to_table_vars(vars::Union{Tuple,AbstractVector})
    out = Vector{Symbol}(undef, length(vars))
    @inbounds for i in eachindex(vars)
        out[i] = _to_table_key(vars[i])
    end
    out
end

@inline function _table_attr_type_from_store(store::MTGAttributeStore, key::Symbol)
    has_any = false
    has_missing = false
    T = Union{}

    @inbounds for bucket in store.buckets
        col_idx = get(bucket.col_index, key, 0)
        if col_idx == 0
            has_missing = true
            continue
        end

        has_any = true
        col_T = bucket.col_types[col_idx]
        col_T_no_nothing = _remove_nothing_type(col_T)
        if col_T_no_nothing === Union{}
            has_missing = true
        else
            if col_T_no_nothing !== col_T
                has_missing = true
            end
            T = T === Union{} ? col_T_no_nothing : typejoin(T, col_T_no_nothing)
        end
    end

    has_any || return Missing
    has_missing ? Union{Missing,T} : T
end

function _collect_attr_names_from_store(store::MTGAttributeStore)
    out = Symbol[]
    seen = Set{Symbol}()
    for bucket in store.buckets
        for col in bucket.columns
            name = col.name
            if !(name in seen)
                push!(seen, name)
                push!(out, name)
            end
        end
    end
    return out
end

function _collect_attr_names_from_nodes(nodes)
    out = Symbol[]
    seen = Set{Symbol}()
    for n in nodes
        for key in attribute_names(n)
            if !(key in seen)
                push!(seen, key)
                push!(out, key)
            end
        end
    end
    out
end

function _build_attr_columns(nodes, attr_names)
    cols = AbstractVector[]
    for key in attr_names
        values = Vector{Any}(undef, length(nodes))
        @inbounds for i in eachindex(nodes)
            v = attribute(nodes[i], key, default=nothing)
            values[i] = v === nothing ? missing : v
        end
        T = _value_type_or_missing(values)
        typed = Vector{T}(undef, length(values))
        @inbounds for i in eachindex(values)
            typed[i] = values[i]
        end
        push!(cols, typed)
    end
    cols
end

@inline function _value_type_or_missing(values::Vector{Any})
    T = Union{}
    has_missing = false
    @inbounds for v in values
        if v === missing
            has_missing = true
        else
            T = T === Union{} ? typeof(v) : typejoin(T, typeof(v))
        end
    end

    if T === Union{}
        return Missing
    end
    return has_missing ? Union{Missing,T} : T
end

"""
    symbol_table(mtg::Node, symbol, vars=nothing)

Return a per-symbol column table view (Tables.jl-compatible).
If `vars` is provided (`Symbol`/`String`/vector/tuple), only these attributes are included.
"""
function symbol_table(mtg::Node, symbol, vars=nothing)
    symbol_ = _to_table_key(symbol)
    vars_ = _to_table_vars(vars)
    attrs = node_attributes(get_root(mtg))
    if attrs isa ColumnarAttrs
        store = _store_for_node_attrs(attrs)
        if store !== nothing
            bid = get(store.symbol_to_bucket, symbol_, 0)
            if bid == 0
                names_ = Symbol[:node_id]
                cols_ = AbstractVector[Int[]]
                if vars_ !== nothing
                    for key in vars_
                        push!(names_, key)
                        push!(cols_, Missing[])
                    end
                end
                return ColumnTable(names_, cols_)
            end
            bucket = store.buckets[bid]
            names_ = Symbol[:node_id]
            cols_ = AbstractVector[bucket.row_to_node]
            if vars_ === nothing
                for col in bucket.columns
                    push!(names_, col.name)
                    push!(cols_, col.data)
                end
            else
                for key in vars_
                    col_idx = get(bucket.col_index, key, 0)
                    push!(names_, key)
                    if col_idx == 0
                        push!(cols_, fill(missing, length(bucket.row_to_node)))
                    else
                        push!(cols_, bucket.columns[col_idx].data)
                    end
                end
            end
            return ColumnTable(names_, cols_)
        end
    end

    nodes = traverse(mtg, node -> node, symbol=symbol_, type=typeof(mtg))
    attr_names = _collect_attr_names_from_nodes(nodes)
    attr_names = vars_ === nothing ? attr_names : vars_
    attr_cols = _build_attr_columns(nodes, attr_names)

    names_ = Symbol[:node_id]
    cols_ = AbstractVector[[node_id(n) for n in nodes]]
    @inbounds for i in eachindex(attr_names)
        push!(names_, attr_names[i])
        push!(cols_, attr_cols[i])
    end
    ColumnTable(names_, cols_)
end

"""
    mtg_table(mtg::Node, vars=nothing)

Return a unified traversal-ordered table view of an MTG (Tables.jl-compatible).
Absent attributes are represented as `missing`.
If `vars` is provided (`Symbol`/`String`/vector/tuple), only these attributes are included.
"""
function mtg_table(mtg::Node, vars=nothing)
    nodes = traverse(mtg, node -> node, type=typeof(mtg))
    vars_ = _to_table_vars(vars)

    names_ = Symbol[:node_id, :symbol, :scale, :index, :link, :parent_id]
    cols_ = AbstractVector[
        [node_id(n) for n in nodes],
        [symbol(n) for n in nodes],
        [scale(n) for n in nodes],
        [index(n) for n in nodes],
        [link(n) for n in nodes],
        [isroot(n) ? missing : node_id(parent(n)) for n in nodes]
    ]

    attrs = node_attributes(get_root(mtg))
    if attrs isa ColumnarAttrs
        store = _store_for_node_attrs(attrs)
        if store !== nothing
            attr_names = vars_ === nothing ? _collect_attr_names_from_store(store) : vars_
            for key in attr_names
                push!(names_, key)
                T = _table_attr_type_from_store(store, key)
                push!(cols_, MTGAttrColumnView{typeof(nodes[1]),T}(nodes, key))
            end
            return ColumnTable(names_, cols_)
        end
    end

    attr_names = _collect_attr_names_from_nodes(nodes)
    attr_names = vars_ === nothing ? attr_names : vars_
    attr_cols = _build_attr_columns(nodes, attr_names)
    @inbounds for i in eachindex(attr_names)
        push!(names_, attr_names[i])
        push!(cols_, attr_cols[i])
    end

    ColumnTable(names_, cols_)
end

@inline function _materialize_table(source, sink)
    sink === nothing && return source

    # Preferred path for Tables-compatible sinks (e.g. DataFrame type/instance).
    materializer = try
        Tables.materializer(sink)
    catch
        try
            Tables.materializer(typeof(sink))
        catch
            nothing
        end
    end
    materializer !== nothing && return materializer(source)

    # Generic fallback for callable sinks, e.g. sink = x -> MyType(x)
    applicable(sink, source) && return sink(source)

    error(
        "Unsupported sink $(sink). ",
        "Provide a Tables.jl sink (type or instance, e.g. DataFrame) or a callable that accepts a table."
    )
end

"""
    to_table(mtg::Node; symbol=nothing, vars=nothing, sink=nothing)

Generic table conversion entry-point.

- `symbol=nothing`: unified traversal-ordered table
- `symbol=<symbol>`: per-symbol table
- `vars`: optional attribute selection (`Symbol`/`String`/vector/tuple)
- `sink`: optional sink materialization (e.g. `sink=DataFrame` if `DataFrames.jl` is loaded)
"""
function to_table(mtg::Node; symbol=nothing, vars=nothing, sink=nothing)
    source = symbol === nothing ? mtg_table(mtg, vars) : symbol_table(mtg, symbol, vars)
    _materialize_table(source, sink)
end

Tables.istable(::Type{<:Node}) = true
Tables.columnaccess(::Type{<:Node}) = true
Tables.columns(mtg::Node) = to_table(mtg)
