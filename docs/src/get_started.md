# Getting started

## Introduction

This page let's you take a peek at what the package is capable of. If you want a better, more in-depth introduction to the package, take a look at the tutorials, starting from [Read and Write MTGs](@ref). If you don't know what an MTG is, you can read more about starting from [The MTG concept](@ref).

## Installation

You can install the latest stable version of MultiScaleTreeGraph.jl using this command:

```julia
]add MultiScaleTreeGraph
```

!!! note
    The `]` is used to enter the package mode in the REPL.

## Example

```@setup usepkg
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
transform!(mtg, :Length => (x -> isnothing(x) ? nothing : x * 100.) => :length_mm)
```

Read a simple MTG file:

```@example usepkg
using MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
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
