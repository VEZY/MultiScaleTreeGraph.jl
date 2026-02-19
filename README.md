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

You can expose an MTG as a `Tables.jl` source:

```julia
mtg_table(mtg)
symbol_table(mtg, :Leaf)
```

If you use `DataFrames.jl`, `DataFrame(mtg)` works out of the box through the `Tables.jl` interface.

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

## 3. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

This package is heavily inspired by [OpenAlea's MTG](https://github.com/openalea/mtg) implementation in Python.

## 4. Similar packages

- [MultiScaleArrays.jl](https://github.com/SciML/MultiScaleArrays.jl)
- [MultilayerGraphs.jl](https://github.com/JuliaGraphs/MultilayerGraphs.jl)
