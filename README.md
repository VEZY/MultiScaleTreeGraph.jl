# MultiScaleTreeGraph

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/dev)
[![Build Status](https://github.com/VEZY/MultiScaleTreeGraph.jl/workflows/CI/badge.svg)](https://github.com/VEZY/MultiScaleTreeGraph.jl/actions)
[![Coverage](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.5654676.svg)](https://doi.org/10.5281/zenodo.5654676)

The goal of MultiScaleTreeGraph.jl is to read, write, analyse and plot MTG (Multi-scale Tree Graph) files. These files describe the plant topology (*i.e.* structure) along with some attributes for each node (*e.g.* geometry, colors, state...).

> The package is under intensive development and is in a very early version. The functions may heavily change from one version to another until a more stable version is released.

## 1. Installation

You can install the latest stable version of MultiScaleTreeGraph.jl using this command:

```julia
] add MultiScaleTreeGraph
```

Or if you prefer the development version:

```julia
using Pkg
Pkg.add(url="https://github.com/VEZY/MultiScaleTreeGraph.jl", rev="master")
```

## 2. Example

Read a simple MTG file:

```julia
using MultiScaleTreeGraph

file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");

mtg = read_mtg(file);
```

Then you can compute new variables in the MTG like so:

```julia
@mutate_mtg!(mtg, length_mm = node.Length * 100.)
```

Or using the more Julian way inspired by `DataFrame.jl`:

```julia
transform!(mtg, :Length => (x -> x * 100.) => :length_mm)
```

And then write the MTG back to disk:

```julia
write_mtg("test.mtg",mtg)
```

## 3. Conversion

You can convert an MTG into a DataFrame and select the variables you need:

```julia
DataFrame(mtg, [:length_mm, :XX])
```

Or convert it to a [MetaGraph](https://juliagraphs.org/MetaGraphsNext.jl/dev/):

```julia
MetaGraph(mtg)
```

## 4. Compatibility

We can plot the MTG using the companion package [`PlantGeom.jl`](https://github.com/VEZY/PlantGeom.jl).

`MultiScaleTreeGraph.jl` trees are compatible with the [AbstractTrees.jl](https://github.com/JuliaCollections/AbstractTrees.jl) package, which means you can use all functions from that package, *e.g.*:

```julia
using AbstractTrees

node = get_node(mtg, 4)

nodevalue(node)
parent(node)
nextsibling(node)
prevsibling(nextsibling(node))
childrentype(node)
childtype(node)
childstatetype(node)
getdescendant(mtg, (1, 1, 1, 2))
collect(PreOrderDFS(mtg))
collect(PostOrderDFS(mtg))
collect(Leaves(mtg))
collect(nodevalues(PreOrderDFS(mtg)))
print_tree(mtg)
```

You can learn more about `MultiScaleTreeGraph.jl` in the [documentation of the package](https://vezy.github.io/MultiScaleTreeGraph.jl/dev/).

## 3. Roadmap

To do before v1:

- [x] Functions to read the MTG (`read_mtg()`)
- [x] Helpers to mutate the MTG:
  - [x] `traverse!()`
  - [x] `descendants()`
  - [x] `ancestors()`
  - [x] `@mutate_mtg!()`
  - [x] `traverse!()` for a more julian way
  - [x] `delete_nodes!()` to delete nodes in the tree based on filters
  - [x] `insert_nodes!()` to add new nodes in the tree (e.g. a new scale). Use `new_id()` for id them.
  - [x] Use DataFrame-like API?
    - [x] select!
    - [x] transform!
    - [x] filter! -> cannot implement this one, we cannot predict before-hand how to link the nodes of other scales when deleting all nodes of a given scale. It really depends on the MTG itself.
    - [x] names (return feature names)
- [ ] Use `sizehint!` in descendants, etc...
- [x] Make `Node` compatible with `AbstractTrees.jl`
- [x] Make `Node` indexable for:
  - [x] children using `Int`
  - [x] attributes using Symbols or anything else
  - [x] node fields using the dot notation
- [x] iterable
- [x] Use MutableNamedTuple for `node.children` by default -> rolled back to Dict instead
- [ ] Tree printing:
  - [x] Tree printing
  - [x] Link + symbol + unique ID
  - [ ] Color for scales
- [x] Functions to plot the MTG
- [x] Easy handling of the scales in tree traversal
- [ ]  Get stats for scales:
  - [ ]  nb scales
  - [ ]  min/max scale
  - [ ]  nb nodes in total / for a given scale
- [x] Add documentation
  - [x] Add tutorials
  - [x] Add documentation on helper functions, e.g. get_features, get_node...
- [x] Add tests
  - [x] Add test on the row at which the columns are declared (at ENTITY-CODE!)
  - [x] Add test when there's a missing link at a given line
  - [x] Add test for when the scale of the element is not found in the classes (see line 59 and 141 of parse_mtg.jl, i.e. `classes.SCALE[node_element[2] .== classes.SYMBOL][1]`
  - [x] Add test in parse_section! for empty lines in section (such as a while loop to ignore it).
- [x] Add tests for insert_parent!, insert_generation!, insert_child!, insert_sibling!
- [x] Add tests for insert_parents!, insert_generations!, insert_children!, insert_siblings!
- [ ] Add conversion from DataFrame and from MetaGraph
- [ ] Make the children field a vector of children by default instead of a Dict
- [x] Add OPF parser (moved to PlantGeom.jl)
- [x] Add possibility to prune from a node: add it to the docs
- [x] Add tests for delete_node! and delete_nodes!
- [ ] Add prune!, delete_node! and delete_nodes! to the docs
- [x] Add possibility to insert a sub_tree
- [x] Export plotting to PlantGeom.jl so we remove one more dependency away.
- [ ] Make transform! parallel. Look into <https://github.com/JuliaFolds/FLoops.jl>.
- [ ] Delete siblings field from Node
- [ ] Add option to visit only some scales without the need to visit all nodes in-between
  - [ ] Add complex + components in Node.
  - [ ] Update names: children are nodes of the same scale, components of a scale with higher number
  - [ ] Update `traverse` and `traverse!` to visit children (same scale) if e.g. only the first or second scale is needed, avoid visiting scale 3. For that we need to visit only the components of the first node of scale 1, and then it will visit scale 1 + scale 2 and never scale 3 that is a component of scale 2. To implement this, we can remove the scale arg from the filter, and pass it to an equivalent to `ordered_children` that would test if:
    - the scale we want include a scale that is above the scale of the node, return the component,
    - the scale we want is equal, it would return the children
    - the scale is below, return an error because we shouldn't visit this node
    We have 2 ideas at the time:
    - check that a scale is connected to all nodes of that scale (e.g. a leaf in a tree is not connected to others, but all axes are). If a scale is connected we can safely visit all nodes by visiting their children (same scale, all connected). If a scale is not connected we cannot do the same because we would miss some nodes by just visiting the children. So we need to visit all nodes of its complex to make sure we visited every node with our chosen scale. Iteratively if the complex is not connected we have to do the same for this one too and its complex etc until finding a connected complex. A scale is connected if all nodes with a lower scale decompose to the node scale. So to keep track of if a scale is connected, we can put a counter for each scale on the root node, and increment it each time we add a new node of a lower scale, and decrement it each time it is decomposed. Then if a scale has a value of 0, it is connected, and if it has a value > 0, it may not (we dont know). If it is, we can visit just using the children, if it is not, we have to visit all nodes of the upper scale to be sure to visit all.
    - we could also add a function e.g. `cache_scale()` that would allow a user to cache a dictionary into the root node with keys being the node name and the values the nodes at that scale. So if users regularly visit a scale they can traverse the dictionary instead of the full MTG. It would work for non-connected scales too. But this idea is not concurrent to the previous one because it does not deal with `descendants` and `ancestors` alone (need to avoid visiting all nodes in the tree).
  - [ ] Update `ancestors` and `descendants` accordingly. See if we can re-use traverse or some functions for descendants to avoid a maintenance nightmare. For `ancestors`, we need a function that checks if we want the same scale (= parent) or a scale with a smaller value (= complex).

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

This package is heavily inspired by [OpenAlea's MTG](https://github.com/openalea/mtg) implementation in Python.
