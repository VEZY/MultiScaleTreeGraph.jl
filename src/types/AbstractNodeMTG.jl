"""
Abstract supertype for all types describing the MTG coding
for a node.

See [`NodeMTG`](@ref) and [`MutableNodeMTG`](@ref) for examples
of implementation.
"""
abstract type AbstractNodeMTG end

"""
    NodeMTG(link, symbol, index, scale)
    MutableNodeMTG(link, symbol, index, scale)

# NodeMTG structure

Builds an MTG node to hold data about the link to the previous node,
the symbol of the node, and its index.

# Note

- The symbol should match the possible values listed in the `SYMBOL` column of the `CLASSES` section
 in the mtg file if read from a file.

- The index is totaly free, and can be used as a way to *e.g.* keep track of the branching order.

```julia
NodeMTG("<", "Leaf", 2, 0)
```
"""
NodeMTG, MutableNodeMTG

struct NodeMTG <: AbstractNodeMTG
    link::String
    symbol::String
    index::Int
    scale::Int
end

NodeMTG(link, symbol, index::Nothing, scale) = NodeMTG(link, symbol, -9999, scale)

mutable struct MutableNodeMTG <: AbstractNodeMTG
    link::String
    symbol::String
    index::Int
    scale::Int
end

MutableNodeMTG(link, symbol, index::Nothing, scale) = MutableNodeMTG(link, symbol, -9999, scale)