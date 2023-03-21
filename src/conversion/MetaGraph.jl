"""
    MetaGraph(g::Node)

Convert an MTG into a [MetaGraph](https://juliagraphs.org/MetaGraphsNext.jl/dev/).

# Examples

```julia
# Importing an mtg from the package:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

MetaGraph(mtg)
```
"""
function MetaGraph(g::Node)
    meta_mtg =
        MetaGraph(
            DiGraph(),
            label_type=Dict{Int64,Int64}(),
            vertex_data_type=Dict{Int64,Tuple{Int64,typeof(g.attributes)}}(),
            edge_data_type=Dict{Tuple{Int64,Int64},String}(),
            graph_data="MTG",
            weight_function=edata -> 1.0,
            default_weight=1.0,
        )
    traverse!(g, to_MetaGraph, meta_mtg)
    return meta_mtg
end


function to_MetaGraph(node, meta_mtg)
    meta_mtg[node.id] = node.attributes

    if !isroot(node)
        code_node = code_for(meta_mtg, node.id)
        code_parent = code_for(meta_mtg, parent(node).id)
        add_edge!(meta_mtg, code_parent, code_node, node.MTG.link)
    end
end
