```@meta
CurrentModule = MultiScaleTreeGraph
```

# MultiScaleTreeGraph.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/MultiScaleTreeGraph.jl/dev)
[![Build Status](https://github.com/VEZY/MultiScaleTreeGraph.jl/workflows/CI/badge.svg)](https://github.com/VEZY/MultiScaleTreeGraph.jl/actions)
[![Coverage](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/VEZY/MultiScaleTreeGraph.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Documentation for [MultiScaleTreeGraph.jl](https://github.com/VEZY/MultiScaleTreeGraph.jl).

## Overview

The goal of MultiScaleTreeGraph.jl is to read, write, analyse and plot MTG (Multi-scale Tree Graph) files.

The Multi-Scale Tree Graph (MTG) is a format used to describe plant structure (topology) and associated attributes (*e.g.* geometry, colours, state). It was developed in the [AMAP lab](https://amap.cirad.fr/) in the 90's to provide a generic and scalable way to represent plant topology and measurements.

The format is described in details in the original paper from Godin et Caraglio (1998).

The MTG format helps describe the plant at different scales at the same time. For example we can describe a plant at the scale of the organ (e.g. leaf, internode), the scale of a growth unit, the scale of the axis, the crown or even at the whole plant.

You can find out how to use the package on the [Getting started](@ref) section, or more about the MTG format in the [The MTG concept](@ref).

If your immediate goal is querying MTGs (descendants, ancestors, filters), go to [Traversal, descendants, ancestors and filters](@ref).

## References

Godin, C., et Y. Caraglio. 1998. « A Multiscale Model of Plant Topological Structures ». Journal of Theoretical Biology 191 (1): 1‑46. https://doi.org/10.1006/jtbi.1997.0561.
