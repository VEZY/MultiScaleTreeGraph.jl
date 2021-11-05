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

The goal of MTG.jl is to read, write, analyse and plot MTG (Multi-scale Tree Graph) files.

The Multi-Scale Tree Graph, or MTG, is a data structure used to encode a plant to describe its topology (*i.e.* structure) and any attributes (*e.g.* geometry, colours, state...). It was developed in the [AMAP lab](https://amap.cirad.fr/) in the 90's to cope with the need of a generic yet scalable structure for plant topology and traits measurement, analysis and modelling.

The format is described in details in the original paper from Godin et al. (1997).

The MTG format helps describe the plant at different scales at the same time. For example we can describe a plant at the scale of the organ (e.g. leaf, internode), the scale of a growth unit, the scale of the axis, the crown or even at the whole plant.

You can find out hw to use the package on the [Getting started](@ref) section.
## References

Godin, C., et Y. Caraglio. 1998. « A Multiscale Model of Plant Topological Structures ». Journal of Theoretical Biology 191 (1): 1‑46. https://doi.org/10.1006/jtbi.1997.0561.

Plant svg original file from Kelvinsong — CC BY-SA 3.0, https://commons.wikimedia.org/w/index.php?curid=27509689
