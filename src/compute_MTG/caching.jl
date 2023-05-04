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