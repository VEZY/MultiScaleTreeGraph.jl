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

## The MTG

Before doing anything with this package, you have to learn a little bit about the MTG. It can seem complicated at first, but once you understand how it works, you'll feel very powerful and you'll see you can do a lot of things with it.

The Multi-scale Tree Graph -or MTG for short- is a data structure that allows to describe a plant or any tree-alike structure at one or several scales along with some attributes.

For example a tree can be described at the individual scale (see Fig. 1 below). It is just seen as a whole, and we can associate attributes to it such as its species, its spatial coordinates, its total biomass, or leaf area.

If we get closer to the tree, we can see more details. The dominant axes becomes more visible and we can differentiate the biggest branches from each other. This is a new scale of description, let's say the axis scale. At this scale we see the trunk, and several main axes. We can measure attributes at the axis scale such as their volume, biomass, or total leaf area for example.

If we get closer again, each axis can be described with more details using growth units. This is a new scale again. And each growth unit can itself be sub-divided into internodes, yet another scale. Again, attributes can be associated to the internodes, for example its biomass, leaf area or volume.

In the MTG, all scales live together in the same data structure. The elementary object is a node. We use a node for the plant scale, and associate attributed to it. Then we use a new node for the first axis -the trunk- and associate its own attributes to it, then the second axis is a new node, etc...

Each node has a given scale, a symbol, index and attributes to describe it, the type of connection -or link- it has with its parent, and a list of children.

There are three types of links between nodes in an MTG:

- decomposition: this link is used when the node decomposes its parent, meaning it has a different scale. For example the first node describing the tree at the axis scale decomposes the node that describes the tree at the plant scale.
- follow: the node follows its parent node, and has the same scale. For example an internode can follow another one.
- branch: the node branches from its parent.

![www/godin_et_al.1998_fig.18.png]

*Fig 1. A tree described at different scales of perception. Leaves are not taken into account. (a) Tree scale, (b) axis scale, (c) growth unit scale, (d) internode scale, (e) corresponding multiscale tree graph. Adapted from Fig.18 from Godin et al. (1998).*

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
fieldnames(mtg.MTG)
```

We see that it holds the MTG fields: the scale, symbol, index and link to its parent.

We can move in the MTG from node to node because we know its parents and children.
