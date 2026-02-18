"""
    prune!(node)

Prune a tree at `node`, *i.e.* delete the entire sub-tree starting at `node` (including it).

Returns an error if the node is a root, or the parent node of the (deleted) node.

# Examples

```julia
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

prune!(get_node(mtg, 6))

mtg
```
"""
function prune!(node)
    if isroot(node)
        error("Cannot prune the root node. You can delete an MTG by setting it to `nothing` instead.")
    else
        parent_node = parent(node)

        stack = Node[node]
        while !isempty(stack)
            n = pop!(stack)
            attrs = node_attributes(n)
            attrs isa ColumnarAttrs && remove_columnar_node!(attrs)
            ch = children(n)
            @inbounds for i in eachindex(ch)
                push!(stack, ch[i])
            end
        end

        # Delete the node as child of his parent:
        parent_children = children(parent_node)
        idx = _child_index_by_id(parent_children, node_id(node))
        idx === nothing || deleteat!(parent_children, idx)
    end

    # Delete the links to the parent:
    reparent!(node, nothing)
    node = nothing

    return parent_node
end
