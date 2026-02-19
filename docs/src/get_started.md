# Getting started

## Introduction

This page let's you take a peek at what the package is capable of. If you want a better, more in-depth introduction to the package, take a look at the tutorials, starting from [Read and Write MTGs](@ref). If you don't know what an MTG is, you can read more about starting from [The MTG concept](@ref).

## Installation

You must have a working Julia installation on your computer. The version of Julia should be greater than 1.3.

If you want to install Julia for the first time, you can download it frome [julialang.org](https://julialang.org/downloads/). If you want a little introduction on Julia + VSCode, you can check out [this video](https://youtu.be/oi5dZxPGNlk).

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
```

Read a simple MTG file:

```@example usepkg
using MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
```

Then you can compute new variables in the MTG using [`transform!`](@ref):

```@example usepkg
transform!(mtg, :Length => (x -> isnothing(x) ? nothing : x * 1000.) => :length_mm)
```

The design of [`transform!`](@ref) is heavily inspired from the eponym function from tabular workflows (notably [`DataFrames.jl`](https://dataframes.juliadata.org/stable/)), with little tweaks for MTGs.

You can see the newly-computed attributes using descendants like so:

```@example usepkg
descendants(mtg, :length_mm)
```

Or by getting a tabular view of your MTG:

```@example usepkg
mtg_table(mtg)
```

You can also select only a subset of attributes:

```@example usepkg
mtg_table(mtg, [:Length, :Width])
```

Or directly transforming the MTG into a DataFrame:

```julia
using DataFrames
DataFrame(mtg)
```

Then you can write the MTG back to disk like so:

```julia
write_mtg("test.mtg",mtg)
```

You can also convert your MTG to a [MetaGraph](https://juliagraphs.org/MetaGraphsNext.jl/dev/):

```@example usepkg
MetaGraph(mtg)
```
