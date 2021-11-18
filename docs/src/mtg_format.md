# The MTG

Before doing anything with this package, you have to learn a little bit about the MTG. The format can seem complicated at first, but once you understand it, you'll see it is very powerful.

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
