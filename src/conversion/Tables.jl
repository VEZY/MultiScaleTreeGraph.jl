struct MTGTableView
    names::Vector{Symbol}
    name_to_idx::Dict{Symbol,Int}
    cols::Vector{AbstractVector}
end

function MTGTableView(names::Vector{Symbol}, cols::Vector{AbstractVector})
    idx = Dict{Symbol,Int}()
    @inbounds for i in eachindex(names)
        idx[names[i]] = i
    end
    MTGTableView(names, idx, cols)
end

Tables.istable(::Type{MTGTableView}) = true
Tables.columnaccess(::Type{MTGTableView}) = true
Tables.columns(t::MTGTableView) = t
Tables.columnnames(t::MTGTableView) = Tuple(t.names)
Tables.getcolumn(t::MTGTableView, i::Int) = t.cols[i]
Tables.getcolumn(t::MTGTableView, name::Symbol) = t.cols[t.name_to_idx[name]]
Tables.schema(t::MTGTableView) = Tables.Schema(Tuple(t.names), Tuple(eltype.(t.cols)))

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

function _typed_column(values::Vector{Any})
    T = _value_type_or_missing(values)
    out = Vector{T}(undef, length(values))
    @inbounds for i in eachindex(values)
        out[i] = values[i]
    end
    out
end

function _collect_attr_names(nodes)
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
    cols = Vector{AbstractVector}(undef, length(attr_names))
    @inbounds for i in eachindex(attr_names)
        key = attr_names[i]
        values = Vector{Any}(undef, length(nodes))
        for j in eachindex(nodes)
            v = attribute(nodes[j], key, default=nothing)
            values[j] = v === nothing ? missing : v
        end
        cols[i] = _typed_column(values)
    end
    cols
end

function symbol_table(mtg::Node, symbol::Symbol)
    nodes = traverse(mtg, node -> node, symbol=symbol, type=typeof(mtg))
    attr_names = _collect_attr_names(nodes)
    attr_cols = _build_attr_columns(nodes, attr_names)

    names = Symbol[:node_id]
    cols = Vector{AbstractVector}(undef, 1 + length(attr_cols))
    cols[1] = [node_id(n) for n in nodes]

    @inbounds for i in eachindex(attr_names)
        push!(names, attr_names[i])
        cols[i+1] = attr_cols[i]
    end

    MTGTableView(names, cols)
end

function mtg_table(mtg::Node)
    nodes = traverse(mtg, node -> node, type=typeof(mtg))
    attr_names = _collect_attr_names(nodes)
    attr_cols = _build_attr_columns(nodes, attr_names)

    names = Symbol[:node_id, :symbol, :scale, :index, :link, :parent_id]
    cols = Vector{AbstractVector}(undef, 6 + length(attr_cols))
    cols[1] = [node_id(n) for n in nodes]
    cols[2] = [symbol(n) for n in nodes]
    cols[3] = [scale(n) for n in nodes]
    cols[4] = [index(n) for n in nodes]
    cols[5] = [link(n) for n in nodes]
    cols[6] = [isroot(n) ? missing : node_id(parent(n)) for n in nodes]

    @inbounds for i in eachindex(attr_names)
        push!(names, attr_names[i])
        cols[i+6] = attr_cols[i]
    end

    MTGTableView(names, cols)
end
