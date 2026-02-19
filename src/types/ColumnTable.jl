mutable struct ColumnTable
    col_names::Vector{Symbol}
    name_to_idx::Dict{Symbol,Int}
    cols::Vector{AbstractVector}
    metadata::Dict{Symbol,Any}
end

function ColumnTable(col_names::Vector{Symbol}, cols::Vector{AbstractVector}; metadata=Dict{Symbol,Any}())
    length(col_names) == length(cols) || error("Column names and columns must have the same length.")
    nrows = isempty(cols) ? 0 : length(cols[1])
    @inbounds for i in 2:length(cols)
        length(cols[i]) == nrows || error("All columns must have the same number of rows.")
    end
    name_to_idx = Dict{Symbol,Int}()
    @inbounds for i in eachindex(col_names)
        name_to_idx[col_names[i]] = i
    end
    ColumnTable(col_names, name_to_idx, cols, Dict{Symbol,Any}(pairs(metadata)))
end

function ColumnTable(; metadata=Dict{Symbol,Any}(), kwargs...)
    names_ = Symbol[]
    cols_ = AbstractVector[]
    for (k, v) in pairs(kwargs)
        push!(names_, k)
        push!(cols_, v)
    end
    ColumnTable(names_, cols_; metadata=metadata)
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
    if name === :col_names || name === :name_to_idx || name === :cols || name === :metadata
        return getfield(table, name)
    end
    return table.cols[_column_idx(table, name)]
end

function Base.setproperty!(table::ColumnTable, name::Symbol, values)
    if name === :col_names || name === :name_to_idx || name === :cols || name === :metadata
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
    ColumnTable(copy(table.col_names), new_cols; metadata=copy(table.metadata))
end

function Base.:(==)(a::ColumnTable, b::ColumnTable)
    a.col_names == b.col_names || return false
    length(a.cols) == length(b.cols) || return false
    @inbounds for i in eachindex(a.cols)
        a.cols[i] == b.cols[i] || return false
    end
    a.metadata == b.metadata || return false
    true
end

function Base.isequal(a::ColumnTable, b::ColumnTable)
    isequal(a.col_names, b.col_names) || return false
    length(a.cols) == length(b.cols) || return false
    @inbounds for i in eachindex(a.cols)
        isequal(a.cols[i], b.cols[i]) || return false
    end
    isequal(a.metadata, b.metadata) || return false
    true
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

@inline function _pad_display_text(text::AbstractString, width::Int)
    pad = width - textwidth(text)
    return pad > 0 ? text * repeat(" ", pad) : String(text)
end

@inline function _as_display_vector(x)
    if x isa AbstractVector
        return x
    elseif x isa Tuple
        return collect(x)
    else
        return nothing
    end
end

function _print_symbols_scales(io::IO, symbols_meta, scales_meta)
    if symbols_meta === nothing && scales_meta === nothing
        return
    end

    syms = _as_display_vector(symbols_meta)
    scales = _as_display_vector(scales_meta)

    if syms !== nothing && scales !== nothing && !isempty(syms) && length(syms) == length(scales)
        n = length(syms)
        sym_cells = Vector{String}(undef, n)
        scale_cells = Vector{String}(undef, n)
        widths = Vector{Int}(undef, n)

        @inbounds for i in eachindex(syms)
            sym_i = string(syms[i])
            scale_i = string(scales[i])
            sym_cells[i] = sym_i
            scale_cells[i] = scale_i
            widths[i] = max(textwidth(sym_i), textwidth(scale_i))
        end

        @inbounds for i in eachindex(widths)
            sym_cells[i] = _pad_display_text(sym_cells[i], widths[i])
            scale_cells[i] = _pad_display_text(scale_cells[i], widths[i])
        end

        label_w = max(textwidth("Symbols:"), textwidth("Scales:"))
        print(io, _pad_display_text("Symbols:", label_w), " ", join(sym_cells, "  "), "\n")
        print(io, _pad_display_text("Scales:", label_w), " ", join(scale_cells, "  "), "\n")
        return
    end

    symbols_meta === nothing || print(io, "Symbols: ", symbols_meta, "\n")
    scales_meta === nothing || print(io, "Scales: ", scales_meta, "\n")
end

function Base.show(io::IO, ::MIME"text/plain", table::ColumnTable)
    nrows, ncols = size(table)
    title = "Attributes Table ($(nrows) x $(ncols))"

    syms = get(table.metadata, :symbols, nothing)
    scales = get(table.metadata, :scales, nothing)
    _print_symbols_scales(io, syms, scales)

    if ncols == 0
        print(io, title)
        return
    end

    t_format = PrettyTables.TextTableFormat(
        borders=PrettyTables.text_table_borders__unicode_rounded
    )

    PrettyTables.pretty_table(
        io,
        table;
        backend=:text,
        title=title,
        table_format=t_format,
        row_number_column_label="Row",
        row_labels=1:nrows,
        vertical_crop_mode=:middle,
    )
end
