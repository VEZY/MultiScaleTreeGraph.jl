"""
    topological_order(mtg; ascend = true)

Compute the topological order of an mtg.

# Arguments

- `mtg`: the mtg, *e.g.* output from `read_mtg()`
- `ascend`: If `true`, the order is computed from the base (acropetal), if `false`,
it is computed from the tip (basipetal).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MTG))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
topological_order(mtg)
DataFrame(mtg, :topological_order)
# 7×2 DataFrame
#  Row │ tree                        topological_order
#      │ String                      Int64
# ─────┼───────────────────────────────────────────────
#    1 │ / 1: \$                                      1
#    2 │ └─ / 2: Individual                          1
#    3 │    └─ / 3: Axis                             1
#    4 │       └─ / 4: Internode                     1
#    5 │          ├─ + 5: Leaf                       2
#    6 │          └─ < 6: Internode                  1
#    7 │             └─ + 7: Leaf                    2

topological_order(mtg, ascend = false)
DataFrame(mtg, :topological_order)
# 7×2 DataFrame
#  Row │ tree                        topological_order
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
function topological_order(mtg; ascend = true)
    @mutate_mtg!(mtg, topological_order = topological_order_ascend(node))

    if !ascend
        max_order = maximum(traverse(mtg, x -> x[:topological_order]))
        @mutate_mtg!(mtg, topological_order = topological_order_descend(node, max_order))
    end
end

function topological_order_ascend(node)
    if isroot(node)
        return 1
    else
        if node.MTG.link == "+"
            return parent(node)[:topological_order] + 1
        else
            return parent(node)[:topological_order]
        end
    end
end

function topological_order_descend(node, max_order)
    if isroot(node)
        return max_order
    else
        if node.MTG.link == "+"
            return parent(node)[:topological_order] - 1
        else
            return parent(node)[:topological_order]
        end
    end
end
