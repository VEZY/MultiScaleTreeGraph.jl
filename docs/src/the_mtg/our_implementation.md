# MTG implementation

## Introduction

```@setup usepkg
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
node_6 = get_node(mtg, 6)
```

In this package, the MTG is represented as a tree (nodes linked by parent/children relationships).

The tree is built from nodes. Each node stores:

- how it is connected to other nodes (its topology)
- its own measured or computed attributes

!!! note
    The package use terms from computer science rather than plant biology. So we use words such as "root" in an MTG, which is not the plant root, but the first node in the tree, *i.e.* the one without any parent. Similarly a leaf node is not a leaf from a plant but a node without any children.

## Data types

The nodes have their own data type called [`Node`](@ref). A [`Node`](@ref) has several fields:

```@example usepkg
fieldnames(Node)
```

Here is a simple description of each field:

- `id`: The unique integer identifier of the node. It can be set by the user but is usually set automatically.
- `parent`: The parent node of the curent node. If the curent node is the root node, it will return `nothing`. You can test whether a node is a root node sing the [`isroot`](@ref) function.
- `children`: the child nodes.
- `MTG`: The MTG encoding of the node (see below, or [`NodeMTG`](@ref))
- `attributes`: node values (for example length, diameter, color, 3D position).
- `traversal_cache`: saved traversal results used to speed up repeated operations.

The values of these fields are accessed with helper functions such as [`node_id`](@ref), [`parent`](@ref), [`children`](@ref), [`node_mtg`](@ref), and [`node_attributes`](@ref).

The MTG field of a node describes how the node is positioned in the graph: link with parent (`/`, `<`, `+`), symbol, index, and scale (see [Node MTG and attributes](@ref) and [The MTG section](@ref) for more details). It is stored as [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref). These types have four fields:

```@example usepkg
fieldnames(NodeMTG)
```

Creating a [`NodeMTG`](@ref) is simple: pass the four values in order. For example, an Axis that decomposes its parent (`"/"`), with index `0` and scale `1`:

```@example usepkg
axis_mtg_encoding = NodeMTG("/", "Axis", 0, 1)
```

Then we can access data using dot syntax:

```@example usepkg
axis_mtg_encoding.symbol
```

!!! note
    [`NodeMTG`](@ref) is immutable (cannot be changed after creation).  
    [`MutableNodeMTG`](@ref) can be changed.  
    Use mutable if you plan to edit node topology fields.

## Learning by example

Let's print again the example MTG from the previous section:

```@example usepkg
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
println(read(file, String))
```

We can use [`read_mtg`](@ref) from `MultiScaleTreeGraph.jl` to read this MTG:

```@example usepkg
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
```

[`read_mtg`](@ref) returns the first node of the MTG, of type [`Node`](@ref):

```@example usepkg
typeof(mtg)
```

!!! note
    `typeof(mtg)` shows extra type details (including MTG encoding type and attribute container type). You usually do not need to worry about these details to use the package.

We can access the fields of the node using the accessor functions:

```@example usepkg
node_id(mtg)
```

```@example usepkg
parent(mtg)
```

This one returns `nothing` because the node is the root node, it has no parent, but we could use it on its child, and it would return the root again:

```@example usepkg
mtg_child = mtg[1]
parent(mtg_child) == mtg
```

```@example usepkg
children(mtg)
```

```@example usepkg
node_mtg(mtg)
```

```@example usepkg
node_attributes(mtg)
```

The package also provide helper functions to access the MTG encoding of the node directly:

```@example usepkg
symbol(mtg)
```

```@example usepkg
index(mtg)
```

```@example usepkg
scale(mtg)
```
