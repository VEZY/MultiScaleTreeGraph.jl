"""
    get_node(node::Node, name)

Get a node in an mtg by name.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MTG))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
traverse!(mtg, x -> isleaf(x) ? println(x.name," is a leaf") : nothing)
node_5 is a leaf
node_7 is a leaf
```
"""
function get_node(node::Node, name)
    if node.name == name
        return node
    else
        if !isleaf(node)
            for chnode in ordered_children(node)
                rnode = get_node(chnode, name)
                if rnode !== nothing
                    return rnode
                end
            end
        end
    end
end