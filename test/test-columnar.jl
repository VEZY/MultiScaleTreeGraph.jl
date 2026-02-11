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

leaf_table = symbol_table(mtg, :Leaf)
leaf_df = DataFrame(leaf_table)
@test :node_id in Symbol.(names(leaf_df))
@test :Width in Symbol.(names(leaf_df))
@test nrow(leaf_df) > 0

all_table = mtg_table(mtg)
all_df = DataFrame(all_table)
@test :node_id in Symbol.(names(all_df))
@test :symbol in Symbol.(names(all_df))
@test all_df.node_id == list_nodes(mtg)
@test any(ismissing, all_df.Width)
