# MTG.jl

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
  - [ ] `ancestors()`
- [ ] Use `sizehint!` in descendants, etc...
- [x] Make `Node` compatible with `AbstractTrees.jl`
- [x] Make `Node` indexable for:
  - [x] children using `Int`
  - [x] attributes using Symbols or anything else
  - [x] node fields using the dot notation
- [x] iterable
- [ ] Work by default at the finer scale. Hence we can make a function to dump the scales ze don't want to work with, which would speed-up the computations. Careful though, we probably have to change the links between nodes then.
- [x] Use MutableNamedTuple for `node.children` by default
- [ ] Tree printing:
  - [x] Tree printing
  - [x] Link + symbol + unique ID
  - [ ] Color for scales
- [ ] Functions to plot the MTG
- [ ] Easy handling of the scales in:
  - [ ]  tree traversal
  - [ ]  Printing
  - [ ]  Plotting
  - [ ]  Get stats for scales:
    - [ ]  nb scales
    - [ ]  min/max scale
    - [ ]  nb nodes in total / for a given scale
- [ ] Add documentation
- [x] Add tests

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).

The first implementations for handling the MTG:

- OpenAlea's Python implementation
