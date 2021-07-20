# MTG

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/MTG.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/MTG.jl/dev)
[![Build Status](https://github.com/VEZY/MTG.jl/workflows/CI/badge.svg)](https://github.com/VEZY/MTG.jl/actions)
[![Coverage](https://codecov.io/gh/VEZY/MTG.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/VEZY/MTG.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


The goal of MTG.jl is to read, write, analyze and plot MTG (Multi-scale Tree Graph) files. These files describe the plant topology (i.e. structure) along with some attributes for each node (e.g. geometry, colors, state...).

> The package is under intensive development and is in a very early version. The functions may heavily change from one version to another until a more stable version is released.

## 1. Installation

You can install the development version of MTG.jl from [GitHub](https://github.com/) using Pkg:

```julia
using Pkg
Pkg.add(url="https://github.com/VEZY/MTG.jl", rev="master")
```

## 2. Example

Read a simple MTG file:

```julia
using MTG

file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");

mtg,classes,description,features = read_mtg(file);
```

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
  - [ ] `add_nodes!()` to add new nodes in the tree (e.g. a new scale). Use `new_name()` for naming them.
  - [ ] Add possibility to mutate a node using an anonymous function, e.g. `@mutate_mtg!(mtg, x -> x*2)`
- [ ] Use `sizehint!` in descendants, etc...
- [x] Make `Node` compatible with `AbstractTrees.jl`
- [x] Make `Node` indexable for:
  - [x] children using `Int`
  - [x] attributes using Symbols or anything else
  - [x] node fields using the dot notation
- [x] iterable
- [ ] Work by default at the finer scale. Hence we can make a function to dump the scales ze don't want to work with, which would speed-up the computations. Careful though, we probably have to change the links between nodes then.
- [x] Use MutableNamedTuple for `node.children` by default -> rolled back to Dict instead
- [ ] Tree printing:
  - [x] Tree printing
  - [x] Link + symbol + unique ID
  - [ ] Color for scales
- [ ] Functions to plot the MTG
- [ ] Easy handling of the scales in:
  - [x]  tree traversal
  - [ ]  Printing
  - [ ]  Plotting
  - [ ]  Get stats for scales:
    - [ ]  nb scales
    - [ ]  min/max scale
    - [ ]  nb nodes in total / for a given scale
- [ ] Add documentation
- [x] Add tests
  - [ ] Add test on the row at which the columns are declared (at ENTITY-CODE!)
  - [ ] Add test when there's a missing link at a given line
  - [ ] Add test for when the scale of the element is not found in the classes (see line 59 and 141 of parse_mtg.jl, i.e. `classes.SCALE[node_element[2] .== classes.SYMBOL][1]`
  - [ ] Add test in parse_section! for empty lines in section (such as a while loop to ignore it).

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

The first implementations for handling the MTG:

- OpenAlea's Python implementation
