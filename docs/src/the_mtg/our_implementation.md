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

- `name`: The name of the node. It is completely free, but is usually computing automatically when reading the MTG. The automatic name is based on the index of the node in the MTG, *e.g.* "node_1" for the first node.
- `parent`: The parent node of the curent node. If the curent node is the root node, it will return `nothing`. You can test whether a node is a root node sing the [`isroot`](@ref) function.
- `children`: A dictionary with the children of the current node as values, and their name as keys.
- `siblings`: A dictionary with the siblings of the current node as values, and their name as keys.
- `MTG`: The MTG description of the node (see below)
- `attributes`: the node attributes, usually of the form of a dictionary, but the type is optional (can be a vector, a tuple...).


The MTG field of a node describes the topology of the node (see [Node MTG and attributes](@ref) and [The MTG section](@ref) for more details). It is a data structure called [`NodeMTG`](@ref), which has four fields:

```@example usepkg
fieldnames(NodeMTG)
```

These fields correspond to the topology encoding of the node: the type of link with the parent node (decompose: `/`, follow: `<`, and branch: `+`), the symbol of the node, its index, and its description scale.

!!! note
    [`NodeMTG`](@ref) is the immutable data type, meaning that information cannot be changed once read. By default the package the mutable equivalent called [`MutableNodeMTG`](@ref). Accessing the information of a mutable data structure is slower, but it is more convenient if we need to change its values.

## Learning by example

### Read an MTG

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

### Accessing a node

The first node of the whole MTG is all we need to access every other nodes in the MTG, because they are all linked together. For example we can access the data of its child either using its name:

```@example usepkg
mtg.children["node_2"]
```

Or directly by indexing the node with an integer:

```@example usepkg
mtg[1]
```

We can iteratively index into the nodes to access the descendants of a node. For example if we need to access the 6th node (the 2nd Internode), we would do:

```@example usepkg
node_6 = mtg[1][1][1][2]
```

Or more simply, we can use the [`get_node`](@ref) function with the name of the node:

```@example usepkg
node_6 = get_node(mtg, "node_6")
```

To access the parent of a node, we would do:

```@example usepkg
node_6.parent
```

### Accessing node data

We can access the data of a node using the dot notation. For example to get its MTG data:

```@example usepkg
mtg.MTG
```

Or its attributes:

```@example usepkg
mtg.attributes
```

!!! note
    The attributes of the root node always include the data from the header sections of an MTG file: the scales of the MTG, the description and the symbols. You can learn more in [The MTG sections](@ref) if you want.

We can also access the attributes of a node by indexing the node with a Symbol:

```@example usepkg
node_6[:Length]
```

... or a String:

```@example usepkg
node_6["Length"]
```

Which are both equivalent to:

```@example usepkg
node_6.attributes[:Length]
```

You'll find more information on how to make computations over the MTG, how to transform it into a DataFrame, how to write it back to disk, or how to delete and insert new nodes in the tutorials.
