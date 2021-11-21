# Introductory Tutorial

In this tutorial you'll learn everything about the MTG and how to use the basic functionalities of the package.

## Installation

You can install the latest stable version of MultiScaleTreeGraph.jl using this command:

```julia
]add MultiScaleTreeGraph
```

!!! note
    Note the `]` that is used to enter the package mode in the REPL.

```@setup usepkg
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
```

## Read an MTG file

Let's read a simple MTG file to start with the package:

```@example usepkg
using MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
```

[`read_mtg`](@ref) returns a [`Node`](@ref) object.

```@example usepkg
typeof(mtg)
```

This node is the root node of the MTG, meaning the first node of the MTG, the one without any parent.

!!! note
    Root node and leaf node mean a node without any parent or children respectively. These terms are used in the sense of a tree [data structure](https://en.wikipedia.org/wiki/Tree_(data_structure)) in computer science, not in plant biology.

## The Node type

### What's a node?

As we learned in the previous section, the node is used as the elementary object to build the MTG. In this package, a node is a data structure used to hold these informations (*i.e.* fields):

- name: the name of the node. It is usually generated when read from a file and unique in the MTG;
- parent: the parent node;
- children: a dictionary of the children nodes, or Nothing if no children;
- siblings: a dictionary of sibling(s) node(s) if any, or else Nothing. Can be Nothing if not computed too;
- MTG: the MTG encoding of the node (see below, or [`NodeMTG`](@ref));
- attributes: the node attributes. Can be anything really, such as the length, diameter of a segment, its colour, 3d position...

To get a field of a node, you can use the dot notation, *e.g.*:

```@example usepkg
mtg.attributes
```

The `MTG` field from the node helps us describe the node within the MTG. Let's see what's in it:

```@example usepkg
fieldnames(typeof(mtg.MTG))
```

We see that it holds the MTG fields: the scale, symbol, index and link to its parent.

We can move in the MTG from node to node because we know its parents and children.
