mtg = read_mtg("files/simple_plant.mtg");

function _legacy_get_features_for_test(mtg)
    names_ = Symbol[]
    types_ = String[]
    seen = Set{Tuple{Symbol,String}}()
    traverse!(mtg) do node
        for (name, value) in pairs(node_attributes(node))
            T = typeof(value)
            if T <: AbstractVector || T <: Nothing ||
               name in (:description, :symbols, :scales)
                continue
            end
            typ = if T <: AbstractFloat
                "REAL"
            elseif T <: Bool
                "BOOLEAN"
            elseif T <: Integer
                "INT"
            elseif T <: Date
                "DD/MM/YY"
            else
                "STRING"
            end
            feature = (Symbol(name), typ)
            if !(feature in seen)
                push!(seen, feature)
                push!(names_, feature[1])
                push!(types_, feature[2])
            end
        end
    end
    return MultiScaleTreeGraph.ColumnTable(
        Symbol[:NAME, :TYPE], AbstractVector[names_, types_]
    )
end

@testset "getting scales" begin
    @test scales(mtg) == [0, 1, 2, 3]
    @test symbols(mtg) == components(mtg) == [:Scene, :Individual, :Axis, :Internode, :Leaf]
end

@testset "test classes" begin
    classes = get_classes(mtg)
    @test classes isa MultiScaleTreeGraph.ColumnTable
    @test size(classes) == (5, 5)
    @test classes.SYMBOL == [:Scene, :Individual, :Axis, :Internode, :Leaf]
    @test classes.SCALE == [0, 1, 2, 3, 3]
    @test classes.DECOMPOSITION == ["FREE" for i = 1:5]
    @test classes.INDEXATION == ["FREE" for i = 1:5]
    @test classes.DEFINITION == ["IMPLICIT" for i = 1:5]
end

@testset "test description" begin
    @test get_description(mtg) === nothing
    @test mtg[:description] isa MultiScaleTreeGraph.ColumnTable
    @test size(mtg[:description]) == (2, 4)
    @test mtg[:description].LEFT == ["Internode", "Internode"]
    @test mtg[:description].RELTYPE == ["+", "<"]
    @test mtg[:description].MAX == ["?", "?"]
end

@testset "test features" begin
    features = sort!(get_features(mtg), :NAME)
    @test features isa MultiScaleTreeGraph.ColumnTable
    @test size(features) == (5, 2)
    @test features.NAME == [:Length, :Width, :XEuler, :dateDeath, :isAlive]
    @test features.TYPE == ["REAL", "REAL", "REAL", "DD/MM/YY", "BOOLEAN"]
end

@testset "columnar feature discovery preserves legacy order and fallback" begin
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(
            :root_real => 1.5,
            :root_bool => true,
            :root_missing => missing,
            :ignored_nothing => nothing,
            :ignored_vector => [1, 2],
            :description => "metadata",
        ),
    )
    first_leaf = Node(
        41,
        root,
        MutableNodeMTG(:/, :Leaf, 1, 2),
        Dict{Symbol,Any}(:mixed_type => "text", :first_only => 1),
    )
    second_leaf = Node(
        105,
        root,
        MutableNodeMTG(:+, :Leaf, 2, 2),
        Dict{Symbol,Any}(
            :mixed_type => Date(2026, 8, 24),
            :second_only => DateTime(2026, 8, 24, 12),
        ),
    )

    @test MultiScaleTreeGraph._get_features_columnar(root) ==
          _legacy_get_features_for_test(root)
    @test get_features(root) == _legacy_get_features_for_test(root)
    @test get_features(first_leaf) == _legacy_get_features_for_test(first_leaf)
    features = get_features(root)
    @test (:root_missing, "STRING") in collect(zip(features.NAME, features.TYPE))
    @test (:root_bool, "BOOLEAN") in collect(zip(features.NAME, features.TYPE))
    @test (:second_only, "STRING") in collect(zip(features.NAME, features.TYPE))
    @test !(:ignored_nothing in features.NAME)
    @test !(:ignored_vector in features.NAME)
    @test !(:description in features.NAME)

    # Changing a botanical symbol does not migrate its physical attribute bucket.
    symbol!(first_leaf, :RenamedLeaf)
    @test MultiScaleTreeGraph._get_features_columnar(root) ==
          _legacy_get_features_for_test(root)

    # The public traversal cache is authoritative, including its node order.
    no_filter_cache = MultiScaleTreeGraph.cache_name(
        nothing, nothing, nothing, true, nothing
    )
    MultiScaleTreeGraph.node_traversal_cache(root)[no_filter_cache] =
        typeof(root)[second_leaf, root, first_leaf]
    @test MultiScaleTreeGraph._get_features_columnar(root) ==
          _legacy_get_features_for_test(root)
    @test get_features(root) == _legacy_get_features_for_test(root)

    # Removing a row swaps the bucket's last physical row into its place. Feature
    # order must nevertheless remain traversal order, not storage-row order.
    swap_root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(),
    )
    removed = Node(
        2,
        swap_root,
        MutableNodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:mixed => 1),
    )
    string_leaf = Node(
        3,
        swap_root,
        MutableNodeMTG(:+, :Leaf, 2, 2),
        Dict{Symbol,Any}(:mixed => "second"),
    )
    date_leaf = Node(
        4,
        swap_root,
        MutableNodeMTG(:+, :Leaf, 3, 2),
        Dict{Symbol,Any}(:mixed => Date(2026, 8, 24)),
    )
    delete_node!(removed)
    @test children(swap_root) == [string_leaf, date_leaf]
    @test get_features(swap_root) == _legacy_get_features_for_test(swap_root)
    swap_features = get_features(swap_root)
    mixed_rows = [
        (name, typ) for (name, typ) in zip(swap_features.NAME, swap_features.TYPE)
        if name == :mixed
    ]
    @test mixed_rows == [(:mixed, "STRING"), (:mixed, "DD/MM/YY")]

    # Directly malformed mixed stores retain the old per-node traversal behavior.
    mixed_root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:root_value => 1),
    )
    external = Node(
        20,
        MutableNodeMTG(:/, :External, 1, 1),
        Dict{Symbol,Any}(:external_value => 2),
    )
    push!(children(mixed_root), external)
    @test MultiScaleTreeGraph._get_features_columnar(mixed_root) === nothing
    @test get_features(mixed_root) == _legacy_get_features_for_test(mixed_root)

    # Raw unbound attributes also use the original staged-dictionary path.
    raw_attrs = MultiScaleTreeGraph.ColumnarAttrs(
        Dict{Symbol,Any}(:staged_value => 3)
    )
    RawNode = typeof(mixed_root)
    raw = RawNode(
        30,
        nothing,
        RawNode[],
        MutableNodeMTG(:/, :Raw, 1, 1),
        raw_attrs,
        nothing,
    )
    @test MultiScaleTreeGraph._get_features_columnar(raw) === nothing
    @test get_features(raw) == _legacy_get_features_for_test(raw)

    # A missing physical cell must reject the typed fast path before it is read.
    corrupt_root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:corrupt_value => "root"),
    )
    corrupt_child = Node(
        2,
        corrupt_root,
        MutableNodeMTG(:<, :Plant, 2, 1),
        Dict{Symbol,Any}(:corrupt_value => "child"),
    )
    corrupt_attrs = node_attributes(corrupt_child)
    corrupt_store = corrupt_attrs.ref.store
    corrupt_bid = corrupt_store.node_bucket[node_id(corrupt_child)]
    corrupt_row = corrupt_store.node_row[node_id(corrupt_child)]
    corrupt_bucket = corrupt_store.buckets[corrupt_bid]
    corrupt_column = corrupt_bucket.columns[
        corrupt_bucket.col_index[:corrupt_value]
    ]
    resize!(corrupt_column.data, corrupt_row - 1)
    resize!(corrupt_column.data, corrupt_row)
    @test !isassigned(corrupt_column.data, corrupt_row)
    @test MultiScaleTreeGraph._get_features_columnar(corrupt_root) === nothing
    @test_throws UndefRefError get_features(corrupt_root)
end

@testset "get attributes/names" begin
    @test sort!(get_attributes(mtg)) == sort!(names(mtg)) == [:Length, :Width, :XEuler, :dateDeath, :description, :isAlive, :scales, :symbols]
end

@testset "list nodes" begin
    @test list_nodes(mtg) == Any[1, 2, 3, 4, 5, 6, 7]
end

@testset "Maximum id" begin
    @test max_id(mtg) == 7
end
