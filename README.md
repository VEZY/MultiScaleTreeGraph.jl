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
- [x] Functions to mutate the MTG (`traverse()`)  
- [ ] Easy handling of the scales in tree traversal  
- [ ] Functions to plot the MTG  
- [ ] Add documentation
- [ ] Add tests
- [ ] Better tree printing. See [DataTrees.jl implementation](https://github.com/vh-d/DataTrees.jl/blob/master/src/printing.jl)

## 4. Acknowledgments

Several tree-related functions in use are adapted from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/).