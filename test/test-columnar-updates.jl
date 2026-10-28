using Test
using MultiScaleTreeGraph

@testset "NamedTuple updates preserve scalar attribute semantics" begin
    function scalar_updates!(attrs, updates)
        for (key, value) in pairs(updates)
            attrs[key] = value
        end
        return attrs
    end

    function compare_attributes(actual, expected)
        @test keys(actual) == keys(expected)
        @test isequal(Dict(pairs(actual)), Dict(pairs(expected)))
    end

    function compare_stores(actual_root, expected_root)
        actual_store = MultiScaleTreeGraph._node_store(actual_root)
        expected_store = MultiScaleTreeGraph._node_store(expected_root)
        @test actual_store.symbol_to_bucket == expected_store.symbol_to_bucket
        @test actual_store.node_bucket == expected_store.node_bucket
        @test actual_store.node_row == expected_store.node_row
        for (actual_bucket, expected_bucket) in zip(actual_store.buckets, expected_store.buckets)
            @test actual_bucket.col_index == expected_bucket.col_index
            @test actual_bucket.col_types == expected_bucket.col_types
            for (actual_column, expected_column) in zip(actual_bucket.columns, expected_bucket.columns)
                @test isequal(actual_column.data, expected_column.data)
                @test actual_column.present == expected_column.present
                @test actual_column.n_present == expected_column.n_present
                @test isequal(actual_column.default, expected_column.default)
                @test actual_column.default_present == expected_column.default_present
            end
        end
    end

    payload = [1.0, 2.0]
    reference = Ref(3)
    updates = (
        (value=1, nullable=nothing, missing_value=missing, payload=payload, reference=reference),
        (value=Float32(2.5), new_numeric=Int16(3)),
        (value=3 // 2, new_numeric=4.0),
        (value="widened", nullable=missing),
        (value=nothing, nullable=nothing),
        NamedTuple(),
    )

    staged = MultiScaleTreeGraph.ColumnarAttrs(Dict(:existing => 5))
    scalar_staged = MultiScaleTreeGraph.ColumnarAttrs(copy(staged))
    for update in updates
        @test merge!(staged, update) === staged
        scalar_updates!(scalar_staged, update)
        compare_attributes(staged, scalar_staged)
    end
    @test staged[:payload] === payload
    @test staged[:reference] === reference

    actual_root = Node(1, NodeMTG(:/, :Plant, 1, 1))
    expected_root = Node(1, NodeMTG(:/, :Plant, 1, 1))
    actual = Node(2, actual_root, NodeMTG(:/, :Leaf, 1, 2), (value=0,))
    expected = Node(2, expected_root, NodeMTG(:/, :Leaf, 1, 2), (value=0,))
    actual_sibling = Node(3, actual_root, NodeMTG(:+, :Leaf, 2, 2), (value=7,))
    expected_sibling = Node(3, expected_root, NodeMTG(:+, :Leaf, 2, 2), (value=7,))
    for root in (actual_root, expected_root)
        add_column!(root, :Leaf, :typed_numeric, Float32, default=Float32(0))
        add_column!(root, :Leaf, :union_value, Union{Nothing,Int,String}, default=nothing)
    end

    for (i, update) in enumerate(updates)
        if isodd(i)
            @test merge!(node_attributes(actual), update) === node_attributes(actual)
        else
            @test append!(actual, update) === actual
        end
        scalar_updates!(node_attributes(expected), update)
        compare_attributes(node_attributes(actual), node_attributes(expected))
        compare_attributes(node_attributes(actual_sibling), node_attributes(expected_sibling))
        compare_stores(actual_root, expected_root)
    end
    for update in ((typed_numeric=Float32(1.5), union_value=1),
                   (typed_numeric=Float64(2.5), union_value="text"))
        append!(actual, update)
        scalar_updates!(node_attributes(expected), update)
        compare_stores(actual_root, expected_root)
    end
    @test actual[:typed_numeric] === Float64(2.5)
    @test actual_sibling[:typed_numeric] === Float32(0)
    @test actual[:payload] === payload
    @test actual[:reference] === reference
    @test haskey(actual, :nullable)
    @test actual[:nullable] === nothing
    @test actual[:missing_value] === missing
    @test !haskey(actual_sibling, :nullable)
    @test !haskey(actual_sibling, :missing_value)
    push!(payload, 4.0)
    reference[] = 8
    @test actual[:payload] == [1.0, 2.0, 4.0]
    @test actual[:reference][] == 8

    # A prior write must not retain the row that deletion swaps out underneath it.
    actual_attrs = node_attributes(actual_sibling)
    expected_attrs = node_attributes(expected_sibling)
    append!(actual_sibling, (before_move=true,))
    scalar_updates!(expected_attrs, (before_move=true,))
    delete_node!(actual)
    delete_node!(expected)
    @test merge!(actual_attrs, (after_move=9, value=Float32(10))) === actual_attrs
    scalar_updates!(expected_attrs, (after_move=9, value=Float32(10)))
    compare_attributes(actual_attrs, expected_attrs)
    compare_stores(actual_root, expected_root)

    # Attribute references also survive encoding changes and a rebuilt store.
    symbol!(actual_sibling, :RenamedLeaf)
    symbol!(expected_sibling, :RenamedLeaf)
    columnarize!(actual_root)
    columnarize!(expected_root)
    @test append!(actual_sibling, (after_rebuild=11,)) === actual_sibling
    scalar_updates!(expected_attrs, (after_rebuild=11,))
    compare_attributes(actual_attrs, expected_attrs)
    compare_stores(actual_root, expected_root)

    # Deleted nodes return to staged attributes rather than addressing a reused row.
    deleted_attrs = node_attributes(actual)
    @test merge!(deleted_attrs, (detached_only=12,)) === deleted_attrs
    @test deleted_attrs[:detached_only] == 12
    @test !haskey(actual_attrs, :detached_only)
end
