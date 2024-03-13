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

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")

mtg = read_mtg(file)
```

Then you can compute new variables in the MTG using a `DataFrame.jl`'s alike syntax:

```julia
transform!(mtg, :Length => (x -> x * 1000.) => :length_mm)
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
- [x] Make the children field a vector of children by default instead of a Dict
- [x] Add OPF parser (moved to PlantGeom.jl)
- [x] Add possibility to prune from a node: add it to the docs
- [x] Add tests for delete_node! and delete_nodes!
- [ ] Add prune!, delete_node! and delete_nodes! to the docs
- [x] Add possibility to insert a sub_tree
- [x] Export plotting to PlantGeom.jl so we remove one more dependency away.
- [ ] Make transform! parallel. Look into <https://github.com/JuliaFolds/FLoops.jl>.
- [x] Delete siblings field from Node
- [ ] Add option to visit only some scales without the need to visit all nodes in-between: implemented using traversal cache
- [ ] Add Tables.jl interface ? So we can iterate over the MTG as rows of a Table. 
- [x] Add possibility to add a node "type" as a parametric type so we can dispatch on this ? E.g. Internode, Leaf... It would be a field of node with default value of e.g. `AnyNode`

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

This package is heavily inspired by [OpenAlea's MTG](https://github.com/openalea/mtg) implementation in Python.

## 5. Similar packages

- [MultiScaleArrays.jl](https://github.com/SciML/MultiScaleArrays.jl)
- [MultilayerGraphs.jl](https://github.com/JuliaGraphs/MultilayerGraphs.jl)
