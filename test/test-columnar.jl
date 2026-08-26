using Tables

file = joinpath(dirname(@__FILE__), "files", "simple_plant.mtg")
mtg = read_mtg(file)

@test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs

@testset "ColumnarAttrs iteration" begin
    root = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 1),
        (root_value=1,),
    )
    first_leaf = MultiScaleTreeGraph.Node(
        root,
        MultiScaleTreeGraph.NodeMTG(:/, :Leaf, 1, 2),
        (first_only=11, shared="first"),
    )
    second_leaf = MultiScaleTreeGraph.Node(
        root,
        MultiScaleTreeGraph.NodeMTG(:+, :Leaf, 2, 2),
        (second_only=22, shared="second"),
    )

    first_attrs = node_attributes(first_leaf)
    second_attrs = node_attributes(second_leaf)
    first_pairs = collect(pairs(first_attrs))
    second_pairs = collect(pairs(second_attrs))

    @test first.(first_pairs) == collect(keys(first_attrs))
    @test last.(first_pairs) == [
        get(first_attrs, key, nothing) for key in keys(first_attrs)
    ]
    @test first.(second_pairs) == collect(keys(second_attrs))
    @test last.(second_pairs) == [
        get(second_attrs, key, nothing) for key in keys(second_attrs)
    ]
    @test first_attrs[:first_only] == 11
    @test !haskey(first_attrs, :second_only)
    @test !haskey(second_attrs, :first_only)
    @test get(first_attrs, :second_only, nothing) === nothing
    @test get(second_attrs, :first_only, nothing) === nothing
    @test_throws KeyError first_attrs[:second_only]
    @test_throws KeyError second_attrs[:first_only]
    @test second_attrs[:second_only] == 22

    second_attrs[:shared] = 2
    @test Dict(pairs(first_attrs))[:shared] == "first"
    @test Dict(pairs(second_attrs))[:shared] == 2

    add_column!(root, :Leaf, :temperature, Float64, default=20.0)
    @test last(collect(keys(first_attrs))) == :temperature
    @test last(collect(pairs(first_attrs))) == (:temperature => 20.0)

    rename_column!(root, :Leaf, :temperature, :renamed_temperature)
    @test :temperature ∉ keys(first_attrs)
    @test last(collect(keys(first_attrs))) == :renamed_temperature
    @test last(collect(pairs(first_attrs))) == (:renamed_temperature => 20.0)

    drop_column!(root, :Leaf, :renamed_temperature)
    @test :renamed_temperature ∉ keys(first_attrs)
    @test first.(collect(pairs(first_attrs))) == collect(keys(first_attrs))

    unbound = MultiScaleTreeGraph.ColumnarAttrs(
        Dict{Symbol,Any}(:unbound_first => 1, :unbound_second => "two"),
    )
    @test collect(pairs(unbound)) == collect(pairs(unbound.staged))
    @test first.(collect(pairs(unbound))) == collect(keys(unbound))
end

@testset "ColumnarAttrs mutations are row-local" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    first_leaf = Node(root, NodeMTG(:/, :Leaf, 1, 2), (x=10, shared="first"))
    second_leaf = Node(root, NodeMTG(:+, :Leaf, 2, 2), (x=20, shared="second"))

    store = MultiScaleTreeGraph._node_store(root)
    leaf_bucket = store.buckets[store.symbol_to_bucket[:Leaf]]
    x_column = leaf_bucket.columns[leaf_bucket.col_index[:x]]
    @test eltype(x_column.data) == Union{Nothing,Int}
    @test eltype(x_column.data) !== Any

    @test pop!(first_leaf, :x) == 10
    @test !haskey(first_leaf, :x)
    @test attribute(first_leaf, :x, :absent) === :absent
    @test first_leaf[:x] === nothing
    @test_throws KeyError node_attributes(first_leaf)[:x]
    @test_throws KeyError pop!(first_leaf, :x)
    @test pop!(first_leaf, :x, :absent) === :absent
    @test haskey(second_leaf, :x)
    @test second_leaf[:x] == 20

    first_leaf[:nullable] = nothing
    @test haskey(first_leaf, :nullable)
    @test first_leaf[:nullable] === nothing
    @test !haskey(second_leaf, :nullable)

    @test delete!(second_leaf, :shared) === second_leaf
    @test !haskey(second_leaf, :shared)
    @test first_leaf[:shared] == "first"

    empty!(node_attributes(first_leaf))
    @test isempty(node_attributes(first_leaf))
    @test haskey(second_leaf, :x)
    @test second_leaf[:x] == 20

    drop_column!(root, :Leaf, :x)
    @test !haskey(second_leaf, :x)
    @test !haskey(leaf_bucket.col_index, :x)
end

@testset "Sparse columnar attributes survive growth, merge, and MTG I/O" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    first_leaf = Node(root, NodeMTG(:/, :Leaf, 1, 2), (local_value=1,))
    second_leaf = Node(root, NodeMTG(:+, :Leaf, 2, 2))
    @test !haskey(second_leaf, :local_value)

    third_leaf = Node(root, NodeMTG(:+, :Leaf, 3, 2))
    @test !haskey(third_leaf, :local_value)
    append!(third_leaf, (local_value=3, appended="yes"))
    @test third_leaf[:local_value] == 3
    @test !haskey(first_leaf, :appended)

    add_column!(root, :Leaf, :temperature, Float64, default=20.0)
    fourth_leaf = Node(root, NodeMTG(:+, :Leaf, 4, 2))
    @test fourth_leaf[:temperature] == 20.0
    @test first_leaf[:temperature] == 20.0

    detached = Node(10, NodeMTG(:+, :Leaf, 10, 2), (detached_only=10,))
    addchild!(root, detached)
    @test detached[:detached_only] == 10
    @test !haskey(first_leaf, :detached_only)
    @test first_leaf[:local_value] == 1

    pop!(first_leaf, :local_value)
    roundtrip = mktemp() do path, io
        write_mtg(path, root)
        read_mtg(path)
    end
    @test !haskey(get_node(roundtrip, 2), :local_value)
    @test get_node(roundtrip, 4)[:local_value] == 3
    roundtrip_leaves = descendants(roundtrip; symbol=:Leaf)
    @test last(roundtrip_leaves)[:detached_only] == 10
end

@testset "Node copy rejects topology aliasing" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    @test_throws ArgumentError copy(root)
    copied = deepcopy(root)
    @test copied !== root
    @test node_id(copied) == node_id(root)
end

leaf = traverse(mtg, node -> node, symbol=:Leaf, type=typeof(mtg))[1]

leaf_width = attribute(leaf, :Width, default=nothing)
@test leaf_width !== nothing
@test attribute(mtg, :Width, default=nothing) === nothing

attribute!(leaf, :new_attr, 42.0)
@test attribute(leaf, :new_attr) == 42.0
@test :new_attr in attribute_names(leaf)

attrs_named = attributes(leaf, format=:namedtuple)
attrs_dict = attributes(leaf, format=:dict)
@test attrs_named.Width == leaf_width
@test attrs_dict[:Width] == leaf_width

add_column!(mtg, :Leaf, :temperature, Float64, default=20.0)
@test attribute(leaf, :temperature) == 20.0
drop_column!(mtg, :Leaf, :temperature)
@test attribute(leaf, :temperature, default=nothing) === nothing

add_column!(mtg, :Leaf, :tmpcol, Float64, default=1.0)
rename_column!(mtg, :Leaf, :tmpcol, :tmpcol2)
@test attribute(leaf, :tmpcol2) == 1.0

leaf_table = to_table(mtg, symbol=:Leaf)
leaf_df = DataFrame(leaf_table)
@test :node_id in Symbol.(names(leaf_df))
@test :Width in Symbol.(names(leaf_df))
@test nrow(leaf_df) > 0

leaf_selected = to_table(mtg, symbol=:Leaf, vars=[:Width, "Length"])
@test Tables.columnnames(leaf_selected) == (:node_id, :Width, :Length)
@test length(Tables.getcolumn(leaf_selected, :Width)) == nrow(leaf_df)

all_table = to_table(mtg)
all_df = DataFrame(all_table)
@test :node_id in Symbol.(names(all_df))
@test :symbol in Symbol.(names(all_df))
@test !(:symbols in Symbol.(names(all_df)))
@test !(:scales in Symbol.(names(all_df)))
@test !(:description in Symbol.(names(all_df)))
@test all_df.node_id == list_nodes(mtg)
@test any(ismissing, all_df.Width)

all_selected = to_table(mtg, vars=[:Width, "Length"])
@test Tables.columnnames(all_selected) == (:node_id, :symbol, :scale, :index, :link, :parent_id, :Width, :Length)

all_selected_kw = to_table(mtg, vars=[:Width, :Length])
@test Tables.columnnames(all_selected_kw) == Tables.columnnames(all_selected)

all_df_sink = to_table(mtg, vars=[:Width, :Length], sink=DataFrame)
@test :Width in Symbol.(names(all_df_sink))

all_table_str = sprint(show, MIME("text/plain"), all_selected_kw)
@test occursin("Attributes Table", all_table_str)
@test occursin("node_id", all_table_str)
@test occursin("Width", all_table_str)
@test occursin("Symbols:", all_table_str)
@test occursin("Scales:", all_table_str)

# Hybrid descendants traversal strategy.
@test descendants_strategy(mtg) == :auto
descendants_strategy!(mtg, :indexed)
@test descendants_strategy(mtg) == :indexed

store = MultiScaleTreeGraph._node_store(mtg)
@test store.subtree_index.dirty
leaf_widths_before = descendants(mtg, :Width, symbol=:Leaf, ignore_nothing=true)
@test !store.subtree_index.dirty
@test store.subtree_index.built

insert_child!(
    mtg[1],
    MutableNodeMTG(:+, :Leaf, 0, 3),
    _ -> Dict{Symbol,Any}(:Width => 9.99, :Area => 0.01, :mass => 0.1),
)
@test store.subtree_index.dirty
leaf_widths_after = descendants(mtg, :Width, symbol=:Leaf, ignore_nothing=true)
@test !store.subtree_index.dirty
@test length(leaf_widths_after) == length(leaf_widths_before) + 1
@test leaf_widths_after[end] == 9.99

descendants_strategy!(mtg, :pointer)
@test descendants_strategy(mtg) == :pointer
@test descendants(mtg, :Width, symbol=:Leaf, ignore_nothing=true) == leaf_widths_after
