"""
    get_node(node::Node, name::String)
    get_node(node::Node, id::Int)

Get a node in an mtg by name or id. If names are not unique in the MTG, the function
will return the first it finds.



# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
node_6 = get_node(mtg, "node_6")
node_6_2 = get_node(mtg, 6)
```
"""
function get_node(node::Node, name::String)
    if node.name == name
        return node
    else
        if !isleaf(node)
            for chnode in children(node)
                rnode = get_node(chnode, name)
                if rnode !== nothing
                    return rnode
                end
            end
        end
    end
end

function get_node(node::Node, id::Int)
    if node.id == id
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
