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
        Label = String,
        VertexMeta = typeof(mtg.attributes),
        EdgeMeta = String,
        gprops = "MTG"
    )

    traverse!(g, to_MetaGraph, meta_mtg)
    return meta_mtg
end


function to_MetaGraph(node, meta_mtg)
    meta_mtg[node.name] = node.attributes

    if !isroot(node)
        code_node = code_for(meta_mtg, node.name)
        code_parent = code_for(meta_mtg, parent(node).name)
        add_edge!(meta_mtg, code_parent, code_node, node.MTG.link)
    end
end
