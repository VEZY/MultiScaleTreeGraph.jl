"""
    NodeMTG(link::AbstractString, symbol::Union{Missing,AbstractString}, index::Union{Missing,Integer})
    NodeMTG(link::AbstractString)

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
    link::Union{AbstractChar,AbstractString}
    symbol::Union{Missing,AbstractString}
    index::Union{Missing,Integer}
    scale::Union{Missing,Integer}
end

NodeMTG(link) = NodeMTG(link,missing,missing)



mutable struct Node
    MTG::NodeMTG
    attributes
end

Node(MTG) = Node(MTG,missing)
