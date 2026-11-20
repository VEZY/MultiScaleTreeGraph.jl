# MultiScaleTreeGraph.jl functions

Here is a list of all exported functions from MultiScaleTreeGraph.jl. For more details, click on the link and you'll be directed to the function help.

Notable attribute APIs:

- `attribute`, `attribute!`, `attributes`, `attribute_names`
- `add_column!`, `drop_column!`, `rename_column!`
- `descendants_strategy`, `descendants_strategy!` (choose automatic/direct/indexed descendants retrieval)
- `to_table` (`Tables.jl` source/sink entry-point)

```@index
```

```@autodocs
Modules = [MultiScaleTreeGraph]
```

## Repeated edits on a growing tree

Prepare the tree once, then use the same plan for each birth. An organ can
start with just its place in the topology.

```julia
plant = Node(1, NodeMTG(:/, :Plant, 1, 1), (;))
plan = prepare_node_edits(plant)
leaf = addchild!(plan, plant, 2, NodeMTG(:+, :Leaf, 1, 2))
delete_node!(plan, leaf)
```

The optional final named tuple of `addchild!` supplies **tree attributes**.
In a coupled simulation, variables held by the simulation can stay in its
own status. Removing a node promotes its children according to the ordinary
`delete_node!` rules. It only changes the tree.
