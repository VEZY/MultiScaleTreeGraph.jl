mutable struct ColumnTable
    col_names::Vector{Symbol}
    name_to_idx::Dict{Symbol,Int}
    cols::Vector{AbstractVector}
end

function ColumnTable(col_names::Vector{Symbol}, cols::Vector{AbstractVector})
    length(col_names) == length(cols) || error("Column names and columns must have the same length.")
    nrows = isempty(cols) ? 0 : length(cols[1])
    @inbounds for i in 2:length(cols)
        length(cols[i]) == nrows || error("All columns must have the same number of rows.")
    end
    name_to_idx = Dict{Symbol,Int}()
    @inbounds for i in eachindex(col_names)
        name_to_idx[col_names[i]] = i
    end
    ColumnTable(col_names, name_to_idx, cols)
end

function ColumnTable(; kwargs...)
    names_ = Symbol[]
    cols_ = AbstractVector[]
    for (k, v) in pairs(kwargs)
        push!(names_, k)
        push!(cols_, v)
    end
    ColumnTable(names_, cols_)
end

@inline function _column_idx(table::ColumnTable, name::Symbol)
    idx = get(table.name_to_idx, name, 0)
    idx == 0 && throw(ArgumentError("Unknown column $(name)."))
    return idx
end

Base.names(table::ColumnTable) = copy(table.col_names)
Base.propertynames(table::ColumnTable; private::Bool=false) = private ? tuple(fieldnames(ColumnTable)..., table.col_names...) : Tuple(table.col_names)
Base.size(table::ColumnTable) = (isempty(table.cols) ? 0 : length(table.cols[1]), length(table.cols))
Base.length(table::ColumnTable) = first(size(table))

function Base.getproperty(table::ColumnTable, name::Symbol)
    if name === :col_names || name === :name_to_idx || name === :cols
        return getfield(table, name)
    end
    return table.cols[_column_idx(table, name)]
end

function Base.setproperty!(table::ColumnTable, name::Symbol, values)
    if name === :col_names || name === :name_to_idx || name === :cols
        setfield!(table, name, values)
        return values
    end

    vals = values isa AbstractVector ? values : collect(values)
    nrows = first(size(table))
    if !isempty(table.cols) && length(vals) != nrows
        error("Column $(name) has length $(length(vals)) but table has $(nrows) rows.")
    end

    idx = get(table.name_to_idx, name, 0)
    if idx == 0
        push!(table.col_names, name)
        push!(table.cols, vals)
        table.name_to_idx[name] = length(table.cols)
    else
        table.cols[idx] = vals
    end
    return vals
end

Base.getindex(table::ColumnTable, row::Int, col::Int) = table.cols[col][row]
Base.getindex(table::ColumnTable, row::Int, col::Symbol) = table.cols[_column_idx(table, col)][row]
Base.getindex(table::ColumnTable, ::Colon, col::Symbol) = table.cols[_column_idx(table, col)]
Base.getindex(table::ColumnTable, ::Colon, col::Int) = table.cols[col]

function Base.copy(table::ColumnTable)
    new_cols = AbstractVector[copy(col) for col in table.cols]
    ColumnTable(copy(table.col_names), new_cols)
end

function Base.:(==)(a::ColumnTable, b::ColumnTable)
    a.col_names == b.col_names || return false
    length(a.cols) == length(b.cols) || return false
    @inbounds for i in eachindex(a.cols)
        a.cols[i] == b.cols[i] || return false
    end
    return true
end

function Base.isequal(a::ColumnTable, b::ColumnTable)
    isequal(a.col_names, b.col_names) || return false
    length(a.cols) == length(b.cols) || return false
    @inbounds for i in eachindex(a.cols)
        isequal(a.cols[i], b.cols[i]) || return false
    end
    return true
end

function Base.sort!(table::ColumnTable, by::Symbol; kwargs...)
    idx = _column_idx(table, by)
    perm = sortperm(table.cols[idx]; kwargs...)
    @inbounds for i in eachindex(table.cols)
        table.cols[i] = table.cols[i][perm]
    end
    return table
end

Tables.istable(::Type{ColumnTable}) = true
Tables.columnaccess(::Type{ColumnTable}) = true
Tables.columns(table::ColumnTable) = table
Tables.columnnames(table::ColumnTable) = Tuple(table.col_names)
Tables.getcolumn(table::ColumnTable, i::Int) = table.cols[i]
Tables.getcolumn(table::ColumnTable, name::Symbol) = table.cols[_column_idx(table, name)]
Tables.schema(table::ColumnTable) = Tables.Schema(Tuple(table.col_names), Tuple(eltype.(table.cols)))
