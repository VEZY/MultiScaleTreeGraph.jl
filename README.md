# MultiScaleTreeGraph

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/dev)
[![Build Status](https://github.com/VEZY/MultiScaleTreeGraph.jl/workflows/CI/badge.svg)](https://github.com/VEZY/MultiScaleTreeGraph.jl/actions)
[![Coverage](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


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

Or using the more `DataFrame.jl` way:

```julia
transform!(mtg, :Length => (x -> x * 100.) => :length_mm)
```

And then write the MTG back to disk:

```julia
write_mtg("test.mtg",mtg)
```

You can also transform it into a DataFrame like so, while selecting the variables you want:

```julia
DataFrame(mtg, [:length_mm, :XX])
```

Or convert it to a [MetaGraph](https://juliagraphs.org/MetaGraphsNext.jl/dev/):

```julia
MetaGraph(mtg)
```

Finally, we can plot the MTG using any backends from `Plots`, *e.g.* Plotly:

```julia
using Plots
# import Pkg; Pkg.add("PlotlyJS")
plotlyjs()

plot(mtg)
```

You can learn more about MultiScaleTreeGraph.jl in the [documentation of the package](https://vezy.github.io/MultiScaleTreeGraph.jl/dev/).

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
  - [x] `insert_nodes!()` to add new nodes in the tree (e.g. a new scale). Use `new_name()` for naming them.
  - [ ] Add possibility to mutate a node using an anonymous function, e.g. `@mutate_mtg!(mtg, x -> x*2)`. NB: there's `traverse()` for that.
  - [ ] Use DataFrame-like API?
    - [ ] select!
    - [x] transform!
    - [ ] filter!
    - [ ] names (return feature names)
- [ ] Use `sizehint!` in descendants, etc...
- [x] Make `Node` compatible with `AbstractTrees.jl`
- [x] Make `Node` indexable for:
  - [x] children using `Int`
  - [x] attributes using Symbols or anything else
  - [x] node fields using the dot notation
- [x] iterable
- [ ] Work by default at the finer scale. Hence we can make a function to dump the scales we don't want to work with, which would speed-up the computations. Careful though, we probably have to change the links between nodes then.
- [x] Use MutableNamedTuple for `node.children` by default -> rolled back to Dict instead
- [ ] Tree printing:
  - [x] Tree printing
  - [x] Link + symbol + unique ID
  - [ ] Color for scales
- [x] Functions to plot the MTG
- [ ] Easy handling of the scales in:
  - [x]  tree traversal
  - [ ]  Printing
  - [ ]  Plotting
  - [ ]  Get stats for scales:
    - [ ]  nb scales
    - [ ]  min/max scale
    - [ ]  nb nodes in total / for a given scale
- [ ] Add documentation
  - [ ] Add tutorial
  - [ ] Add documentation on helper functions, e.g. get_features, get_node...
- [x] Add tests
  - [x] Add test on the row at which the columns are declared (at ENTITY-CODE!)
  - [x] Add test when there's a missing link at a given line
  - [x] Add test for when the scale of the element is not found in the classes (see line 59 and 141 of parse_mtg.jl, i.e. `classes.SCALE[node_element[2] .== classes.SYMBOL][1]`
  - [x] Add test in parse_section! for empty lines in section (such as a while loop to ignore it).

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

This package is heavily inspired by [OpenAlea's MTG](https://github.com/openalea/mtg) implementation in Python.
