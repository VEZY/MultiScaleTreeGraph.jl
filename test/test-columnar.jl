using Tables

file = joinpath(dirname(@__FILE__), "files", "simple_plant.mtg")
mtg = read_mtg(file)

@test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs

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
@test all_df.node_id == list_nodes(mtg)
@test any(ismissing, all_df.Width)

all_selected = to_table(mtg, vars=[:Width, "Length"])
@test Tables.columnnames(all_selected) == (:node_id, :symbol, :scale, :index, :link, :parent_id, :Width, :Length)

all_selected_kw = to_table(mtg, vars=[:Width, :Length])
@test Tables.columnnames(all_selected_kw) == Tables.columnnames(all_selected)

all_df_sink = to_table(mtg, vars=[:Width, :Length], sink=DataFrame)
@test :Width in Symbol.(names(all_df_sink))

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
