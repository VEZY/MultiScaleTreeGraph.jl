"""
    branching_order!(mtg; ascend = true)

Compute the topological branching order of the nodes in an mtg.

# Arguments

- `mtg`: the mtg, *e.g.* output from `read_mtg()`
- `ascend`: If `true`, the order is computed from the base (acropetal), if `false`,
it is computed from the tip (basipetal).

# Notes

The order of a node is computed from the maximum order of their children when using the
basipetal computation.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
branching_order!(mtg)
DataFrame(mtg, :branching_order)
# 7×2 DataFrame
#  Row │ tree                        branching_order
#      │ String                      Int64
# ─────┼───────────────────────────────────────────────
#    1 │ / 1: \$                                      1
#    2 │ └─ / 2: Individual                          1
#    3 │    └─ / 3: Axis                             1
#    4 │       └─ / 4: Internode                     1
#    5 │          ├─ + 5: Leaf                       2
#    6 │          └─ < 6: Internode                  1
#    7 │             └─ + 7: Leaf                    2

branching_order!(mtg, ascend = false)
DataFrame(mtg, :branching_order)
# 7×2 DataFrame
#  Row │ tree                        branching_order
#      │ String                      Int64
# ─────┼───────────────────────────────────────────────
#    1 │ / 1: \$                                      2
#    2 │ └─ / 2: Individual                          2
#    3 │    └─ / 3: Axis                             2
#    4 │       └─ / 4: Internode                     2
#    5 │          ├─ + 5: Leaf                       1
#    6 │          └─ < 6: Internode                  2
#    7 │             └─ + 7: Leaf                    1
```
"""
function branching_order!(mtg; ascend = true)

    if ascend
        @mutate_mtg!(mtg, branching_order = branching_order_ascend!(node))
    else
        branching_order_descend!(mtg)
    end
end

function branching_order_ascend!(node)
        if isroot(node)
        return 1
    else
        if node.MTG.link == "+"
            return parent(node)[:branching_order] + 1
        else
            return parent(node)[:branching_order]
        end
    end
end


function branching_order_descend!(node)

    if isleaf(node)
        val = 1
    else
        val_child = Int[]
        for chnode in ordered_children(node)
            push!(val_child, branching_order_descend!(chnode))
        end
        val = maximum(val_child)

        if node.MTG.link == "+"
            val += 1
        end
    end

    node[:branching_order] = val

    return val
end
