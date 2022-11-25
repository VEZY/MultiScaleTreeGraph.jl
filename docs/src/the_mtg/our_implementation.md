# MTG implementation

## Introduction

```@setup usepkg
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
node_6 = get_node(mtg, "node_6")
```

In this package, the MTG is represented as a [tree data structure](https://en.wikipedia.org/wiki/Tree_%28data_structure%29).

The tree is built from a series of nodes with different fields that describe the topology (*i.e.* how nodes are connected together) and the attributes of the node.

!!! note
    The package use terms from computer science rather than plant biology. So we use words such as "root" in an MTG, which is not the plant root, but the first node in the tree, *i.e.* the one without any parent. Similarly a leaf node is not a leaf from a plant but a node without any children.

## Data types

The nodes have their own data type called [`Node`](@ref). A [`Node`](@ref) has several fields:

```@example usepkg
fieldnames(Node)
```

Here is a little description of each field:

- `name`: The name of the node. It is completely free, but is usually set automatically when reading the MTG. The automatic name is based on the id of the node in the MTG, *e.g.* "node_1" for the first node.
- `id`: The unique integer identifier of the node. It can be set by the user but is usually set automatically.
- `parent`: The parent node of the curent node. If the curent node is the root node, it will return `nothing`. You can test whether a node is a root node sing the [`isroot`](@ref) function.
- children: a dictionary of the children nodes with their `id` as key, or `nothing` if none;
- `MTG`: The MTG encoding of the node (see below, or [`NodeMTG`](@ref))
- `attributes`: the node attributes. Usually a `NamedTuple`, a `MutableNamedTuple` or a `Dict` or similar (e.g. `OrderedDict`), but the type is optional. The choice of the data structure depends mainly on how much you plan to change the attributes and their values. Attributes include for example the length or diameter of a node, its colour, 3d position...

The MTG field of a node describes the topology encoding of the node: its type of link with its parent (decompose: `/`, follow: `<`, and branch: `+`), its symbol, index, and scale (see [Node MTG and attributes](@ref) and [The MTG section](@ref) for more details). The MTG field must be encoded in a data structure called [`NodeMTG`](@ref) or in a [`MutableNodeMTG`](@ref). They have four fields corresponding to the topology encoding:

```@example usepkg
fieldnames(NodeMTG)
```

Creating a [`NodeMTG`](@ref) is very simple, just pass the arguments by position. For example if we have an Axis that decomposes its parent node ("/"), with an index 0 and a scale of 1, we would declare it as follows:

```@example usepkg
axis_mtg_encoding = NodeMTG("/", "Axis", 0, 1)
```

The we can access the data using the dot syntax:

```@example usepkg
axis_mtg_encoding.symbol
```

!!! note
    [`NodeMTG`](@ref) is the immutable data type, meaning that information cannot be changed once read. By default the package the mutable equivalent called [`MutableNodeMTG`](@ref). Accessing the information of a mutable data structure is slower, but it is more convenient if we need to change its values.

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

[`read_mtg`](@ref) returns the first node of the MTG, of type [`Node`](@ref)

```@example usepkg
typeof(mtg)
```

!!! note
    The [`Node`](@ref) is a parametric type, that's why `typeof(mtg)` also returns the type used for the MTG data in the node (`MutableNodeMTG`) and the type used for the attributes (`Dict{Symbol, Any}`). But this is not important here.
