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

Read a simple MTG file:

```julia
using MTG

file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");

mtg = read_mtg(file);
```

Then you can compute new variables in the MTG like so:

```julia
@mutate!(mtg, length_mm = node.Length * 100.)
```

And then write the mtg back to disk:

```julia
write_mtg("test.mtg",mtg)
```

You can also transform it into a DataFrame as follows:

```julia
DataFrame(mtg, [:length_mm, :XX])
```

You can learn more about MTG.jl in the next page.
