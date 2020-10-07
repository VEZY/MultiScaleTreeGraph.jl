"""
    NodeMTG(link, symbol, index, scale)
    NodeMTG(link)

# NodeMTG structure

Builds an MTG node to hold data about the link to the previous node,
the symbol of the node, and its index. 

# Note

- The symbol should match the possible values listed in the `SYMBOL` column of the `CLASSES` section
 in the mtg file if read from a file. 

- The index is totaly free, and can be used as a way to *e.g.* keep track of the branching order.

```jldoctest
julia> NodeMTG("<","Leaf",2)
NodeMTG("<", "Leaf", 2)

julia> NodeMTG("<")
NodeMTG("<", missing, missing)
```
"""
struct NodeMTG
    link::Union{String,Char}
    symbol::Union{Nothing,String,Char}
    index::Union{Nothing,Int}
    scale::Union{Nothing,Int}
end

NodeMTG(link) = NodeMTG(link,missing,missing)

mutable struct Node{T <: MutableNamedTuple}
    MTG::NodeMTG
    attributes::T
end

Node(MTG) = Node(MTG,MutableNamedTuple())
