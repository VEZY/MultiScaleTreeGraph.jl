# MultiScaleTreeGraph.jl functions

Here is a list of all exported functions from MultiScaleTreeGraph.jl. For more details, click on the link and you'll be directed to the function help.

Notable attribute APIs:

- `attribute`, `attribute!`, `attributes`, `attribute_names`
- `attribute_ref` (explicit, live typed references to columnar attributes)
- `AbstractMTGNode`, `add_node!` (interfaces for user-owned node storage)
- `add_column!`, `drop_column!`, `rename_column!`
- `descendants_strategy`, `descendants_strategy!` (choose automatic/direct/indexed descendants retrieval)
- `to_table` (`Tables.jl` source/sink entry-point)

## Share an existing attribute with a model

Use `attribute_ref` when a model should read and write the same value as the MTG.
A reference does not copy the scientific value or confer exclusive ownership.

```julia
root = Node(NodeMTG(:/, :Plant, 1, 1))
leaf = add_node!(root, 2, NodeMTG(:+, :Leaf, 1, 2), (Length=0.1,))
length_ref = attribute_ref(leaf, :Length, Float64)
length_ref[] = 0.2
@assert leaf[:Length] == 0.2
```

The reference follows its logical node through row swaps, subtree attachment and
`columnarize!`. A removed node invalidates it permanently; a missing attribute or
incompatible external value raises an error. Ordinary `Node` references require
the columnar backend. See [`attribute_ref`](@ref) for its type and aliasing rules.

## Provide nodes from another storage backend

A compact backend can subtype [`AbstractMTGNode`](@ref) and implement identity,
encoding, attributes, parent and children. The shared traversal APIs then operate
on its handles. Implement [`add_node!`](@ref) and the required mutation operations
to allow clients to create or remove nodes through that backend. Override `new_id`
when the backend must preserve a high-water ID after deletion.

This interface does not imply that every legacy export, mutation helper or
columnar query supports a custom backend automatically. In particular, the
backend owns handle validity, node identity and mutation atomicity; specialized
`Node` operations retain their existing implementation.

```@index
```

```@autodocs
Modules = [MultiScaleTreeGraph]
```
