"""
    write_mtg(file, mtg; kwargs...)
    write_mtg(file, mtg, classes, description, features)

Write an mtg file to disk.

# Arguments

- `file::String`: The path to the MTG file to write.
- `mtg`: the mtg
- `classes`: the classes section
- `description`: the description section
- `features`: the features section
- `feature_overrides`: optional mapping from declared feature names (`Symbol`) to
  vectors aligned with MTG preorder; only serialized values are replaced

# Note

kwargs can be used to give zero, one or two of the classes, description and features
instead of all. In this case the missing ones are recomputed using [`get_classes`](@ref),
[`get_features`](@ref) or [`get_description`](@ref).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
write_mtg("test.mtg",mtg)
```
"""
function write_mtg(file, mtg; kwargs...)
    kwargs = (; kwargs...)

    classes = haskey(kwargs, :classes) ? kwargs.classes : get_classes(mtg)
    description = haskey(kwargs, :description) ? kwargs.description : nothing
    features = haskey(kwargs, :features) ? kwargs.features : get_features(mtg)
    feature_overrides = haskey(kwargs, :feature_overrides) ?
                        kwargs.feature_overrides : nothing

    if feature_overrides === nothing
        write_mtg(file, mtg, classes, description, features)
    else
        write_mtg(
            file,
            mtg,
            classes,
            description,
            features;
            feature_overrides=feature_overrides,
        )
    end
end

function write_mtg(
    file,
    mtg,
    classes,
    description,
    features;
    feature_overrides=nothing,
)
    @info "Writing mtg to $file"
    open(file, "w") do io
        # Code section:
        writedlm(io, ["CODE:" "FORM-A"])

        # Classes section:
        writedlm(io, [""])
        writedlm(io, ["CLASSES:"])
        writedlm(io, reshape(String.(names(classes)), (1, :)))
        # Handle special case of Scene class, which is written as "$" in the mtg file:
        classes_scene = copy(classes)
        symbols_ = String.(classes_scene.SYMBOL)
        replace!(symbols_, "Scene" => "\$")
        classes_scene.SYMBOL = symbols_
        _write_table_rows(io, classes_scene)

        # Description section:
        writedlm(io, [""])
        writedlm(io, ["DESCRIPTION:"])

        # Description is optional
        if description !== nothing
            description_print = copy(description)
            # Reformat the RIGHT column to match how it is written in an MTG
            right = Vector{String}(undef, length(description_print.RIGHT))
            @inbounds for i in eachindex(description_print.RIGHT)
                right[i] = join(string.(description_print.RIGHT[i]), ",")
            end
            description_print.RIGHT = right

            writedlm(io, reshape(String.(names(description_print)), (1, :)))
            _write_table_rows(io, description_print)
        else
            writedlm(io, ["LEFT" "RIGHT" "RELTYPE" "MAX"])
        end

        # Features section:
        writedlm(io, [""])
        writedlm(io, ["FEATURES:"])
        writedlm(io, reshape(String.(names(features)), (1, :)))
        _write_table_rows(io, features)

        # MTG section:
        writedlm(io, [""])
        writedlm(io, ["MTG:"])
        layout = _mtg_write_layout(mtg)
        feature_columns = _mtg_write_feature_columns(mtg, features)
        prepared_overrides = _mtg_write_feature_overrides(
            layout,
            feature_columns,
            feature_overrides,
        )
        columnar_context = _mtg_columnar_write_context(layout, feature_columns)
        if columnar_context === nothing
            feature_values = prepared_overrides === nothing ?
                             _mtg_write_feature_values(layout, feature_columns) :
                             _mtg_write_feature_values(
                                 layout,
                                 feature_columns,
                                 prepared_overrides,
                             )
            entity_feature, output_features, mtg_colnames =
                _mtg_write_projection(layout, feature_columns)
            writedlm(io, reshape(mtg_colnames, (1, :)), quotes=false)
            _write_mtg_rows(
                io, layout, feature_values, entity_feature, output_features
            )
        else
            # Date conversion remains before the ENTITY-CODE header so conversion
            # failures preserve the historical partial-file boundary.
            date_values = prepared_overrides === nothing ?
                          _mtg_write_columnar_date_values(
                              feature_columns,
                              columnar_context,
                          ) :
                          _mtg_write_columnar_date_values(
                              feature_columns,
                              columnar_context,
                              prepared_overrides,
                          )
            entity_feature, output_features, mtg_colnames =
                _mtg_write_projection(layout, feature_columns)
            writedlm(io, reshape(mtg_colnames, (1, :)), quotes=false)
            if prepared_overrides === nothing
                _write_mtg_columnar_rows(
                    io,
                    layout,
                    feature_columns,
                    columnar_context,
                    date_values,
                    entity_feature,
                    output_features,
                )
            else
                _write_mtg_columnar_rows(
                    io,
                    layout,
                    feature_columns,
                    columnar_context,
                    date_values,
                    entity_feature,
                    output_features,
                    prepared_overrides,
                )
            end
        end
    end
end

@inline function _flush_write_buffer!(io, buffer::IOBuffer)
    if position(buffer) > 0
        seekstart(buffer)
        write(io, buffer)
        truncate(buffer, 0)
    end
    return nothing
end

function _write_table_rows(io, table)
    nrows, ncols = size(table)
    rows = ((table[i, j] for j in 1:ncols) for i in 1:nrows)
    writedlm(io, rows)
    return nothing
end

struct _MTGWriteLayout{N}
    nodes::Vector{N}
    leads::Vector{Int}
    parent_refs::BitVector
    max_tabs::Int
end

struct _MTGWriteFeatureColumns
    names::Vector{String}
    keys::Vector{Symbol}
    is_date::BitVector
    plans::Vector{Union{Nothing,ColumnarQueryPlan}}
end

struct _MTGWriteFeatureOverrides
    columns::Vector{Any}
end

@inline _mtg_write_feature_overrides(
    ::_MTGWriteLayout,
    ::_MTGWriteFeatureColumns,
    ::Nothing,
) = nothing

function _mtg_write_feature_overrides(
    layout::_MTGWriteLayout,
    features::_MTGWriteFeatureColumns,
    feature_overrides,
)
    (feature_overrides isa AbstractDict || feature_overrides isa NamedTuple) ||
        throw(ArgumentError(
            "feature_overrides must map Symbol feature names to AbstractVector values",
        ))
    isempty(feature_overrides) && return nothing

    feature_positions = Dict{Symbol,Int}(
        key => index for (index, key) in pairs(features.keys)
    )
    columns = Vector{Any}(undef, length(features.keys))
    fill!(columns, nothing)
    for (key, values) in pairs(feature_overrides)
        key isa Symbol || throw(ArgumentError(
            "feature_overrides keys must be Symbols; got $(repr(key))",
        ))
        values isa AbstractVector || throw(ArgumentError(
            "feature_overrides[$(repr(key))] must be an AbstractVector; got $(typeof(values))",
        ))
        feature_index = get(feature_positions, key, 0)
        iszero(feature_index) && throw(ArgumentError(
            "feature_overrides contains undeclared MTG feature $(repr(key))",
        ))
        length(values) == length(layout.nodes) || throw(ArgumentError(
            "feature_overrides[$(repr(key))] has length $(length(values)); " *
            "expected $(length(layout.nodes)) values aligned with MTG preorder",
        ))
        axes(values, 1) == Base.OneTo(length(layout.nodes)) || throw(ArgumentError(
            "feature_overrides[$(repr(key))] must use one-based axes aligned " *
            "with MTG preorder; got $(axes(values, 1))",
        ))
        columns[feature_index] = values
    end
    return _MTGWriteFeatureOverrides(columns)
end

struct _MTGColumnarWriteContext
    store::MTGAttributeStore
    bucket_ids::Vector{Int}
    rows::Vector{Int}
end

function _mtg_validate_column_rows(column::Column{T}, rows::Vector{Int}) where {T}
    @inbounds for row in rows
        row <= length(column.data) || return false
        row <= length(column.present) || return false
        isassigned(column.data, row) || return false
    end
    return true
end

function _mtg_write_layout(mtg)
    nodes = Vector{typeof(mtg)}()
    leads = Int[]
    parent_refs = BitVector()

    stack_nodes = Vector{typeof(mtg)}(undef, 1)
    stack_leads = Vector{Int}(undef, 1)
    stack_refs = BitVector(undef, 1)
    stack_nodes[1] = mtg
    stack_leads[1] = 0
    stack_refs[1] = false
    max_tabs = 0

    while !isempty(stack_nodes)
        node = pop!(stack_nodes)
        node_lead = pop!(stack_leads)
        node_ref = pop!(stack_refs)

        push!(nodes, node)
        push!(leads, node_lead)
        push!(parent_refs, node_ref)
        max_tabs = max(max_tabs, node_lead)

        child_nodes = children(node)
        n_children = length(child_nodes)
        @inbounds for i in n_children:-1:1
            changes_column = n_children > 1 && i != n_children
            push!(stack_nodes, child_nodes[i])
            push!(stack_leads, changes_column ? node_lead + 1 : node_lead)
            push!(stack_refs, !changes_column)
        end
    end

    return _MTGWriteLayout(nodes, leads, parent_refs, max_tabs)
end

function _mtg_write_feature_columns(mtg, features)
    names_ = String[]
    keys_ = Symbol[]
    is_date = BitVector()
    name_to_column = Dict{String,Int}()

    @inbounds for i in eachindex(features.NAME)
        name = string(features.NAME[i])
        date_feature = string(features.TYPE[i]) == "DD/MM/YY"
        column = get(name_to_column, name, 0)
        if column == 0
            push!(names_, name)
            push!(keys_, Symbol(name))
            push!(is_date, date_feature)
            name_to_column[name] = length(names_)
        else
            # `paste_node_mtg` historically kept the first column position for a
            # duplicate feature name, while the last type controlled formatting.
            is_date[column] = date_feature
        end
    end

    plans = Vector{Union{Nothing,ColumnarQueryPlan}}(undef, length(keys_))
    @inbounds for i in eachindex(keys_)
        plans[i] = build_columnar_query_plan(mtg, keys_[i])
    end
    return _MTGWriteFeatureColumns(names_, keys_, is_date, plans)
end

function _mtg_columnar_write_context(
    layout::_MTGWriteLayout, features::_MTGWriteFeatureColumns
)
    isempty(layout.nodes) && return nothing
    isempty(features.keys) && return nothing
    nfeatures = length(features.keys)
    length(features.names) == nfeatures || return nothing
    length(features.is_date) == nfeatures || return nothing
    length(features.plans) == nfeatures || return nothing

    first_attrs = node_attributes(first(layout.nodes))
    first_attrs isa ColumnarAttrs && _isbound(first_attrs) || return nothing
    store = first_attrs.ref.store::MTGAttributeStore
    nbuckets = length(store.buckets)

    @inbounds for j in eachindex(features.keys)
        plan = features.plans[j]
        plan isa ColumnarQueryPlan || return nothing
        plan.store === store || return nothing
        plan.key == features.keys[j] || return nothing
        length(plan.col_idx_by_bucket) == nbuckets || return nothing
    end

    bucket_ids = Vector{Int}(undef, length(layout.nodes))
    rows = Vector{Int}(undef, length(layout.nodes))
    rows_by_bucket = [Int[] for _ in 1:nbuckets]
    @inbounds for i in eachindex(layout.nodes)
        node = layout.nodes[i]
        attrs = node_attributes(node)
        attrs isa ColumnarAttrs && _isbound(attrs) || return nothing
        attrs.ref.store === store || return nothing

        nodeid = node_id(node)
        nodeid > 0 || return nothing
        attrs.ref.node_id == nodeid || return nothing
        nodeid <= length(store.node_bucket) || return nothing
        nodeid <= length(store.node_row) || return nothing
        bid = store.node_bucket[nodeid]
        row = store.node_row[nodeid]
        1 <= bid <= nbuckets || return nothing
        bucket = store.buckets[bid]
        1 <= row <= length(bucket.row_to_node) || return nothing
        bucket.row_to_node[row] == nodeid || return nothing
        get(bucket.node_to_row, nodeid, 0) == row || return nothing

        bucket_ids[i] = bid
        rows[i] = row
        push!(rows_by_bucket[bid], row)
    end

    @inbounds for bid in eachindex(rows_by_bucket)
        bucket_rows = rows_by_bucket[bid]
        isempty(bucket_rows) && continue
        bucket = store.buckets[bid]
        length(bucket.columns) == length(bucket.col_types) || return nothing

        for j in eachindex(features.keys)
            plan = features.plans[j]::ColumnarQueryPlan
            col_idx = plan.col_idx_by_bucket[bid]
            get(bucket.col_index, features.keys[j], 0) == col_idx || return nothing
            col_idx == 0 && continue
            1 <= col_idx <= length(bucket.columns) || return nothing
            column = _column(bucket, col_idx)
            column isa Column || return nothing
            column.name == features.keys[j] || return nothing
            _mtg_validate_column_rows(column, bucket_rows) || return nothing
        end
    end

    return _MTGColumnarWriteContext(store, bucket_ids, rows)
end

@inline function _mtg_column_value(column::Column{T}, row::Int) where {T}
    _row_has_value(column, row) || return nothing
    return @inbounds column.data[row]
end

@inline function _mtg_override_value(values::AbstractVector{T}, row::Int) where {T}
    return @inbounds values[row]
end

@inline function _mtg_columnar_feature_value(
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    feature_index::Int,
    node_index::Int,
)
    plan = features.plans[feature_index]::ColumnarQueryPlan
    bid = @inbounds context.bucket_ids[node_index]
    col_idx = @inbounds plan.col_idx_by_bucket[bid]
    col_idx == 0 && return nothing
    row = @inbounds context.rows[node_index]
    column = @inbounds context.store.buckets[bid].columns[col_idx]
    return _mtg_column_value(column, row)
end

function _mtg_write_columnar_date_values(
    features::_MTGWriteFeatureColumns, context::_MTGColumnarWriteContext
)
    values = Vector{Union{Nothing,Vector{String}}}(undef, length(features.keys))
    fill!(values, nothing)

    # Match the legacy conversion order exactly: feature-major, then node-major.
    @inbounds for j in eachindex(features.keys)
        features.is_date[j] || continue
        column = Vector{String}(undef, length(context.rows))
        for i in eachindex(context.rows)
            value = _mtg_columnar_feature_value(features, context, j, i)
            column[i] = value === nothing ? "" : format(value, dateformat"d/m/Y")
        end
        values[j] = column
    end
    return values
end

function _mtg_write_columnar_date_values(
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    overrides::_MTGWriteFeatureOverrides,
)
    values = Vector{Union{Nothing,Vector{String}}}(undef, length(features.keys))
    fill!(values, nothing)

    # Match the legacy conversion order exactly: feature-major, then node-major.
    @inbounds for j in eachindex(features.keys)
        features.is_date[j] || continue
        override = overrides.columns[j]
        column = Vector{String}(undef, length(context.rows))
        if override === nothing
            for i in eachindex(context.rows)
                value = _mtg_columnar_feature_value(features, context, j, i)
                column[i] = value === nothing ? "" : format(value, dateformat"d/m/Y")
            end
        else
            for i in eachindex(context.rows)
                value = _mtg_override_value(override, i)
                column[i] = value === nothing ? "" : format(value, dateformat"d/m/Y")
            end
        end
        values[j] = column
    end
    return values
end

function _mtg_write_feature_values(
    layout::_MTGWriteLayout, features::_MTGWriteFeatureColumns
)
    values = [Vector{Any}(undef, length(layout.nodes)) for _ in eachindex(features.keys)]

    # Column-major lookup matches the physical layout of `ColumnarAttrs` and avoids
    # repeating a full tree traversal for every feature.
    @inbounds for j in eachindex(features.keys)
        column = values[j]
        key = features.keys[j]
        plan = features.plans[j]
        for i in eachindex(layout.nodes)
            column[i] = unsafe_getindex(layout.nodes[i], key, plan)
        end
    end

    # Keep the historical conversion order: all values are collected before date
    # formatting is attempted, and `nothing` is represented by an empty field.
    @inbounds for j in eachindex(values)
        column = values[j]
        if features.is_date[j]
            for i in eachindex(column)
                value = column[i]
                column[i] = value === nothing ? "" : format(value, dateformat"d/m/Y")
            end
        else
            replace!(column, nothing => "")
        end
    end
    return values
end

function _mtg_write_feature_values(
    layout::_MTGWriteLayout,
    features::_MTGWriteFeatureColumns,
    overrides::_MTGWriteFeatureOverrides,
)
    values = [Vector{Any}(undef, length(layout.nodes)) for _ in eachindex(features.keys)]

    # Preserve the fallback lookup and error order for every feature before
    # replacing selected values with vectors aligned to this exact layout.
    @inbounds for j in eachindex(features.keys)
        column = values[j]
        key = features.keys[j]
        plan = features.plans[j]
        for i in eachindex(layout.nodes)
            column[i] = unsafe_getindex(layout.nodes[i], key, plan)
        end
        override = overrides.columns[j]
        if override !== nothing
            for i in eachindex(layout.nodes)
                column[i] = _mtg_override_value(override, i)
            end
        end
    end

    # Keep the historical conversion order: all values are collected before date
    # formatting is attempted, and `nothing` is represented by an empty field.
    @inbounds for j in eachindex(values)
        column = values[j]
        if features.is_date[j]
            for i in eachindex(column)
                value = column[i]
                column[i] = value === nothing ? "" : format(value, dateformat"d/m/Y")
            end
        else
            replace!(column, nothing => "")
        end
    end
    return values
end

function _mtg_write_projection(
    layout::_MTGWriteLayout, features::_MTGWriteFeatureColumns
)
    # `paste_node_mtg` has always used `mtg_print` as its internal topology key.
    # A feature with that name therefore replaces the entity-code values instead
    # of adding a column; retain that unusual but observable behavior.
    entity_feature = findfirst(==("mtg_print"), features.names)
    output_features = Int[]
    mtg_colnames = String[string("ENTITY-CODE", repeat("\t", layout.max_tabs))]
    @inbounds for j in eachindex(features.names)
        j == entity_feature && continue
        push!(output_features, j)
        push!(mtg_colnames, features.names[j])
    end
    return entity_feature, output_features, mtg_colnames
end

@inline function _write_mtg_node_code(io, node)
    print(io, String(link(node)), String(symbol(node)))
    node_index = index(node)
    node_index == -9999 || print(io, node_index)
    return nothing
end

function _write_mtg_rows(
    io,
    layout::_MTGWriteLayout,
    feature_values::Vector{Vector{Any}},
    entity_feature::Union{Nothing,Int},
    output_features::Vector{Int},
)
    buffer = IOBuffer(; sizehint=64 * 1024)
    @inbounds for i in eachindex(layout.nodes)
        node = layout.nodes[i]
        node_lead = layout.leads[i]

        if entity_feature === nothing
            for _ in 1:node_lead
                print(buffer, '\t')
            end
            layout.parent_refs[i] && print(buffer, '^')
            _write_mtg_node_code(buffer, node)
            for _ in 1:(layout.max_tabs - node_lead)
                print(buffer, '\t')
            end
        else
            print(buffer, feature_values[entity_feature][i])
        end

        for j in output_features
            print(buffer, '\t')
            print(buffer, feature_values[j][i])
        end
        print(buffer, '\n')
        position(buffer) > 16 * 1024 && _flush_write_buffer!(io, buffer)
    end
    _flush_write_buffer!(io, buffer)
    return nothing
end

@inline function _write_mtg_column_value(io, column::Column{T}, row::Int) where {T}
    _row_has_value(column, row) || return nothing
    value = @inbounds column.data[row]
    value === nothing || print(io, value)
    return nothing
end

@inline function _write_mtg_columnar_feature(
    io,
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    date_values::Vector{Union{Nothing,Vector{String}}},
    feature_index::Int,
    node_index::Int,
)
    if features.is_date[feature_index]
        column = date_values[feature_index]::Vector{String}
        print(io, column[node_index])
        return nothing
    end

    plan = features.plans[feature_index]::ColumnarQueryPlan
    bid = @inbounds context.bucket_ids[node_index]
    col_idx = @inbounds plan.col_idx_by_bucket[bid]
    col_idx == 0 && return nothing
    row = @inbounds context.rows[node_index]
    column = @inbounds context.store.buckets[bid].columns[col_idx]
    _write_mtg_column_value(io, column, row)
    return nothing
end

@inline function _write_mtg_columnar_feature(
    io,
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    date_values::Vector{Union{Nothing,Vector{String}}},
    feature_index::Int,
    node_index::Int,
    overrides::_MTGWriteFeatureOverrides,
)
    if features.is_date[feature_index]
        column = date_values[feature_index]::Vector{String}
        print(io, column[node_index])
        return nothing
    end

    override = @inbounds overrides.columns[feature_index]
    if override === nothing
        plan = features.plans[feature_index]::ColumnarQueryPlan
        bid = @inbounds context.bucket_ids[node_index]
        col_idx = @inbounds plan.col_idx_by_bucket[bid]
        col_idx == 0 && return nothing
        row = @inbounds context.rows[node_index]
        column = @inbounds context.store.buckets[bid].columns[col_idx]
        _write_mtg_column_value(io, column, row)
    else
        value = _mtg_override_value(override, node_index)
        value === nothing || print(io, value)
    end
    return nothing
end

function _write_mtg_columnar_rows(
    io,
    layout::_MTGWriteLayout,
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    date_values::Vector{Union{Nothing,Vector{String}}},
    entity_feature::Union{Nothing,Int},
    output_features::Vector{Int},
)
    buffer = IOBuffer(; sizehint=16 * 1024)
    @inbounds for i in eachindex(layout.nodes)
        node = layout.nodes[i]
        node_lead = layout.leads[i]

        if entity_feature === nothing
            for _ in 1:node_lead
                print(buffer, '\t')
            end
            layout.parent_refs[i] && print(buffer, '^')
            _write_mtg_node_code(buffer, node)
            for _ in 1:(layout.max_tabs - node_lead)
                print(buffer, '\t')
            end
        else
            _write_mtg_columnar_feature(
                buffer, features, context, date_values, entity_feature, i
            )
        end

        for j in output_features
            print(buffer, '\t')
            _write_mtg_columnar_feature(
                buffer, features, context, date_values, j, i
            )
        end
        print(buffer, '\n')
        position(buffer) > 16 * 1024 && _flush_write_buffer!(io, buffer)
    end
    _flush_write_buffer!(io, buffer)
    return nothing
end

function _write_mtg_columnar_rows(
    io,
    layout::_MTGWriteLayout,
    features::_MTGWriteFeatureColumns,
    context::_MTGColumnarWriteContext,
    date_values::Vector{Union{Nothing,Vector{String}}},
    entity_feature::Union{Nothing,Int},
    output_features::Vector{Int},
    overrides::_MTGWriteFeatureOverrides,
)
    buffer = IOBuffer(; sizehint=16 * 1024)
    @inbounds for i in eachindex(layout.nodes)
        node = layout.nodes[i]
        node_lead = layout.leads[i]

        if entity_feature === nothing
            for _ in 1:node_lead
                print(buffer, '\t')
            end
            layout.parent_refs[i] && print(buffer, '^')
            _write_mtg_node_code(buffer, node)
            for _ in 1:(layout.max_tabs - node_lead)
                print(buffer, '\t')
            end
        else
            _write_mtg_columnar_feature(
                buffer,
                features,
                context,
                date_values,
                entity_feature,
                i,
                overrides,
            )
        end

        for j in output_features
            print(buffer, '\t')
            _write_mtg_columnar_feature(
                buffer,
                features,
                context,
                date_values,
                j,
                i,
                overrides,
            )
        end
        print(buffer, '\n')
        position(buffer) > 16 * 1024 && _flush_write_buffer!(io, buffer)
    end
    _flush_write_buffer!(io, buffer)
    return nothing
end

function paste_node_mtg(mtg, features)
    layout = _mtg_write_layout(mtg)
    feature_columns = _mtg_write_feature_columns(mtg, features)
    feature_values = _mtg_write_feature_values(layout, feature_columns)

    attributes = OrderedDict{String,Vector{Any}}()
    mtg_print = Vector{Any}(undef, length(layout.nodes))
    @inbounds for i in eachindex(layout.nodes)
        node_buffer = IOBuffer()
        for _ in 1:layout.leads[i]
            print(node_buffer, '\t')
        end
        layout.parent_refs[i] && print(node_buffer, '^')
        _write_mtg_node_code(node_buffer, layout.nodes[i])
        for _ in 1:(layout.max_tabs - layout.leads[i])
            print(node_buffer, '\t')
        end
        mtg_print[i] = String(take!(node_buffer))
    end
    attributes["mtg_print"] = mtg_print

    @inbounds for j in eachindex(feature_columns.keys)
        attributes[feature_columns.names[j]] = feature_values[j]
    end

    mtg_colnames = collect(keys(attributes))
    mtg_colnames[1] = string("ENTITY-CODE", repeat("\t", layout.max_tabs))
    return attributes, mtg_colnames
end

"""
    get_node_printing!(node, lead, ref, print_node, node_lead=0, node_ref="")

Get the number of tabulation (in `lead`) and the "^" (in `ref`) used as a prefix for the node when writting it to a file, based on the
topology of its parent. Also get the node printing (*e.g.* "/Axis0") in `print_node`.

The function modifies the `lead`, `ref` and `print_node` vectors in place.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
lead = Int[]
ref = String[]
get_node_printing!(mtg, lead, ref)

lead
ref
```
"""
function get_node_printing!(node, lead, ref, print_node, node_lead=0, node_ref="")
    push!(lead, node_lead)
    push!(ref, node_ref)

    index = node_mtg(node).index == -9999 ? "" : string(node_mtg(node).index)
    push!(print_node, String(link(node)) * String(symbol(node)) * index)

    if !isleaf(node)
        chnodes = children(node)
        n_children = length(chnodes)
        for (i, chnode) in enumerate(chnodes)
            # If the node has several children, the lead of the children is automatically increased by 1 for all nodes except the last one:
            if length(chnodes) > 1 && i != n_children
                chnode_lead = node_lead + 1
                node_ref = "" # We refer to the parent node in the column on the left in this case
            else
                chnode_lead = node_lead
                node_ref = "^" # We refer to the parent node in the same column in this case
            end

            get_node_printing!(chnode, lead, ref, print_node, chnode_lead, node_ref)
        end
    end
end
