using Test
using MultiScaleTreeGraph

@testset "Columnar reads preserve historical values, types, and errors" begin
    # Keep the pre-optimization implementation as an oracle. In particular,
    # generic get does not apply the numeric conversion used by attribute.
    function historical_get_value(bucket, row, key, default)
        col_idx = get(bucket.col_index, key, 0)
        col_idx == 0 && return default
        column = bucket.columns[col_idx]
        column.present[row] || return default
        return column.data[row]
    end

    function historical_get(attrs, key::Symbol, default::T) where {T}
        if !MultiScaleTreeGraph._isbound(attrs)
            return get(attrs.staged, key, default)
        end
        store, bid, row = MultiScaleTreeGraph._bound_store_bid_row(attrs.ref)
        bucket = store.buckets[bid]
        col_idx = get(bucket.col_index, key, 0)
        col_idx == 0 && return default
        column = bucket.columns[col_idx]
        column.present[row] || return default
        if bucket.col_types[col_idx] === T
            return (column::MultiScaleTreeGraph.Column{T}).data[row]
        elseif bucket.col_types[col_idx] === Union{Nothing,T}
            return (column::MultiScaleTreeGraph.Column{Union{Nothing,T}}).data[row]
        end
        return historical_get_value(bucket, row, key, default)
    end
    historical_get(attrs, key, default) = historical_get(attrs, Symbol(key), default)

    function historical_numeric_get(attrs, key::Symbol, default::T) where {T<:Number}
        if !MultiScaleTreeGraph._isbound(attrs)
            value = get(attrs.staged, key, default)
            value === nothing && return nothing
            return value isa T ? value : (convert(T, value)::T)
        end
        store, bid, row = MultiScaleTreeGraph._bound_store_bid_row(attrs.ref)
        bucket = store.buckets[bid]
        col_idx = get(bucket.col_index, key, 0)
        col_idx == 0 && return default
        column = bucket.columns[col_idx]
        column.present[row] || return default
        if bucket.col_types[col_idx] === T
            return (column::MultiScaleTreeGraph.Column{T}).data[row]
        elseif bucket.col_types[col_idx] === Union{Nothing,T}
            return (column::MultiScaleTreeGraph.Column{Union{Nothing,T}}).data[row]
        end
        value = historical_get_value(bucket, row, key, default)
        value === nothing && return nothing
        return value isa T ? value : (convert(T, value)::T)
    end

    function read_result(read)
        try
            value = read()
            return (value=value, type=typeof(value))
        catch err
            return (error=typeof(err), message=sprint(showerror, err))
        end
    end

    function compare_reads(attrs)
        snapshot = Dict{Symbol,Any}(pairs(attrs))
        names = union(collect(keys(snapshot)), [
            :unknown, :exact_float, :exact_int, :exact_nothing, :nullable,
            :value, :fractional, :missing_value, :shared, :scientific_ref, :text,
        ])
        defaults = (nothing, missing, false, 0, Float32(-1), -1.0, :fallback, "fallback", Ref(-1))
        for name in names
            @test haskey(attrs, name) == haskey(snapshot, name)
            @test haskey(attrs, String(name)) == haskey(snapshot, name)
            for default in defaults
                expected = read_result(() -> historical_get(attrs, name, default))
                @test isequal(read_result(() -> get(attrs, name, default)), expected)
                @test isequal(read_result(() -> get(attrs, String(name), default)), expected)
                @test get(attrs, name, default) === get(snapshot, name, default)
            end
            if haskey(snapshot, name)
                @test attrs[name] === snapshot[name]
                @test attrs[String(name)] === snapshot[name]
            else
                @test_throws KeyError attrs[name]
                @test_throws KeyError attrs[String(name)]
                caught = try
                    attrs[String(name)]
                catch err
                    err
                end
                @test caught.key === name
            end
            for default in (false, 0, Float32(-1), -1.0, -1 // 2, -1.0 + 0im)
                expected = read_result(() -> historical_numeric_get(attrs, name, default))
                @test isequal(
                    read_result(() -> MultiScaleTreeGraph._get_typed_numeric(attrs, name, default)),
                    expected,
                )
            end
        end
        @test isequal(
            read_result(() -> get(attrs, [], nothing)),
            read_result(() -> historical_get(attrs, [], nothing)),
        )
    end

    shared = [1.0, 2.0]
    scientific_ref = Ref(3.0)
    staged = MultiScaleTreeGraph.ColumnarAttrs(Dict{Symbol,Any}(
        :value => Float32(2.5), :nullable => nothing, :missing_value => missing,
        :shared => shared, :scientific_ref => scientific_ref, :text => "staged",
    ))
    compare_reads(staged)
    compare_reads(MultiScaleTreeGraph.ColumnarAttrs())

    root = Node(1, NodeMTG(:/, :Scene, 1, 0))
    add_column!(root, :Leaf, :exact_float, Float64, default=20.0)
    add_column!(root, :Leaf, :exact_int, Int, default=4)
    add_column!(root, :Leaf, :exact_nothing, Nothing, default=nothing)
    first_leaf = Node(2, root, NodeMTG(:+, :Leaf, 1, 1), (
        value=1, nullable=nothing, shared=shared, scientific_ref=scientific_ref,
        fractional=1.5, text="first",
    ))
    middle_leaf = Node(3, root, NodeMTG(:+, :Leaf, 2, 1), (
        value=Float32(2.5), nullable=Float32(3), missing_value=missing, text="middle",
    ))
    moved_leaf = Node(4, root, NodeMTG(:+, :Leaf, 3, 1), (value=3 // 2, shared=shared))
    for node in (first_leaf, middle_leaf, moved_leaf)
        compare_reads(node_attributes(node))
    end

    first_attrs = node_attributes(first_leaf)
    @test get(first_attrs, :fractional, 0) === 1.5
    @test_throws InexactError attribute(first_leaf, :fractional, 0)
    @test attribute(first_leaf, :value, 0.0) === 1.0
    @test attribute(middle_leaf, :nullable, 0.0) === 3.0
    @test attribute(first_leaf, :nullable, 0.0) === nothing
    @test attribute(moved_leaf, :nullable, 0.0) === 0.0
    @test get(first_attrs, :shared, nothing) === shared
    @test get(first_attrs, :scientific_ref, nothing) === scientific_ref

    # Existing readers must observe a replacement Column after widening, and
    # deleting an attribute must remain distinct from storing nothing/missing.
    first_leaf[:value] = "widened"
    delete!(first_attrs, :exact_float)
    first_leaf[:missing_value] = missing
    for node in (first_leaf, middle_leaf, moved_leaf)
        compare_reads(node_attributes(node))
    end
    @test get(first_attrs, :exact_float, -1.0) === -1.0
    @test get(first_attrs, :exact_nothing, -1.0) === nothing
    @test get(first_attrs, :missing_value, -1.0) === missing
    @test !haskey(first_attrs, :exact_float)
    @test haskey(first_attrs, :exact_nothing)
    @test haskey(first_attrs, :missing_value)

    # The last row moves into the removed row's slot. A saved attributes view
    # must resolve its current row, while the deleted view becomes unbound.
    moved_attrs = node_attributes(moved_leaf)
    store = moved_attrs.ref.store
    previous_row = store.node_row[node_id(moved_leaf)]
    delete_node!(first_leaf)
    @test store.node_row[node_id(moved_leaf)] != previous_row
    compare_reads(moved_attrs)
    compare_reads(node_attributes(middle_leaf))
    compare_reads(first_attrs)
    @test get(moved_attrs, :shared, nothing) === shared
    @test get(first_attrs, :value, :deleted) === :deleted
    first_attrs[:value] = Float32(7.5)
    first_attrs[:shared] = scientific_ref
    compare_reads(first_attrs)
    @test get(first_attrs, :shared, nothing) === scientific_ref
    @test get(moved_attrs, :shared, nothing) === shared
end
