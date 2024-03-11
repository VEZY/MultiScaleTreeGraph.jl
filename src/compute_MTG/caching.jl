"""
    cache_name(vars...)

Make a unique name based on the vars names.

# Examples

```julia
cache_name("test","var")
```
"""
function cache_name(vars...)
    "_cache_" * bytes2hex(sha1(join([vars...])))
end

"""
    clean_cache!(mtg)

Clean the cached variables in the mtg, usually added from [`descendants!`](@ref).
"""
function clean_cache!(mtg)
    cached_vars = find_cached_vars(mtg)
    traverse!(
        mtg,
        node -> [pop!(node, attr) for attr in cached_vars]
    )
end

function find_cached_vars(node)
    vars = names(node)
    collect(vars)[findall(x -> occursin("_cache_", x), String.(vars))]
end

"""
    cache_nodes!(node; scale=nothing, symbol=nothing, link=nothing, filter_fun=nothing, overwrite=false)

Cache the nodes of the mtg based on the filters that would be applied to a traversal. This is automatically
usually for traversal then when using [`traverse!`](@ref) or [`transform!`](@ref).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
mtg = read_mtg(file, Dict)

# Cache all leaf nodes:
cache_nodes!(mtg, symbol="Leaf")

# Cached nodes are stored in the traversal_cache field of the mtg (here, the two leaves):
@test mtg.traversal_cache["_cache_c0bffb8cc8a9b075e40d26be9c2cac6349f2a790"] == [get_node(mtg, 5), get_node(mtg, 7)]

# Then you can use the cached nodes in a traversal:
traverse(mtg, x -> x.MTG.symbol, symbol="Leaf") == ["Leaf", "Leaf"]
```
"""
function cache_nodes!(node; scale=nothing, symbol=nothing, link=nothing, filter_fun=nothing, all=true, overwrite=false)
    # The cache is already present:
    if length(node.traversal_cache) != 0 && haskey(node.traversal_cache, cache_name(scale, symbol, link, all, filter_fun))
        if !overwrite
            error("The node already has a cache for this combination of filters. Hint: use `overwrite=true` if needed.")
        else
            # We have to delete the cache first because else it would be used in the traversal below:
            delete!(node.traversal_cache, cache_name(scale, symbol, link, all, filter_fun))
        end
    end

    node.traversal_cache[cache_name(scale, symbol, link, all, filter_fun)] = traverse(
        node,
        node -> node,
        scale=scale, symbol=symbol, link=link, filter_fun=filter_fun, all=all
    )

    return nothing
end