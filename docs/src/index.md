```@meta
CurrentModule = MTG
```

# MTG.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/MTG.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/MTG.jl/dev)
[![Build Status](https://github.com/VEZY/MTG.jl/workflows/CI/badge.svg)](https://github.com/VEZY/MTG.jl/actions)
[![Coverage](https://codecov.io/gh/VEZY/MTG.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/VEZY/MTG.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Documentation for [MTG.jl](https://github.com/VEZY/MTG.jl).

## Overview

The goal of MTG.jl is to read, write, analyse and plot MTG (Multi-scale Tree Graph) files. These files describe a plant topology (*i.e.* structure) along with some attributes for each node (*e.g.* geometry, colours, state...).

> The package is under intensive development and is in a very early version. The functions may heavily change from one version to another until a more stable version is released.

## 1. Installation

You can install the development version of MTG.jl from [GitHub](https://github.com/) using Pkg:

```julia
using Pkg
Pkg.add(url="https://github.com/VEZY/MTG.jl", rev="master")
```

## 2. Example

```@setup usepkg
using MTG
file = joinpath(dirname(dirname(pathof(MTG))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
transform!(mtg, :Length => (x -> isnothing(x) ? nothing : x * 100.) => :length_mm)
```

Read a simple MTG file:

```@example usepkg
using MTG

file = joinpath(dirname(dirname(pathof(MTG))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
```

Then you can compute new variables in the MTG using [`transform!`](@ref):

```@example usepkg
transform!(mtg, :Length => (x -> isnothing(x) ? nothing : x * 100.) => :length_mm)
```

The design of [`transform!`](@ref) is heavily inspired from the eponym function from [`DataFrame.jl`](https://dataframes.juliadata.org/stable/), with little tweaks for MTGs.

If you prefer a more R-like design, you can use [`@mutate_mtg!`](@ref) instead:

```@example usepkg
@mutate_mtg!(mtg, length_mm = node.Length * 100., filter_fun = x -> !isnothing(x[:Length]))
```

Then you can write the MTG back to disk like so:

```julia
write_mtg("test.mtg",mtg)
```

You can also transform it into a DataFrame while selecting the variables you want:

```@example usepkg
DataFrame(mtg, [:length_mm, :XX])
```

Or convert it to a [MetaGraph](https://juliagraphs.org/MetaGraphsNext.jl/dev/):

```@example usepkg
MetaGraph(mtg)
```

Finally, we can plot the MTG using any backends from `Plots`, *e.g.* Plotly for the 3d:

```@example usepkg
using Plots
# import Pkg; Pkg.add("PlotlyJS")
plotlyjs()

plot(mtg, mode = "3d") # use mode = "2d" for a 2d plot
savefig("mtgplot3d.html"); nothing # hide
```

```@raw html
<object type="text/html" data="mtgplot3d.html" style="width:100%;height:2100px;"></object>
```

```@raw html
<object type="text/html" data="mtgplot.html" style="width:100%;height:2100px;"></object>
```

You can learn more about MTG.jl in the next pages.
