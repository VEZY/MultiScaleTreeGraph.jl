"""
    get_node(node::Node, id::Int)

Get a node in an mtg by id.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
node_6_2 = get_node(mtg, 6)
```
"""
function get_node(node::Node, id::Int)
    if node_id(node) == id
        return node
    else
        if !isleaf(node)
            for chnode in children(node)
                rnode = get_node(chnode, id)
                if rnode !== nothing
                    return rnode
                end
            end
        end
    end
end
