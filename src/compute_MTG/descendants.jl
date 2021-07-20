"""
    descendants(node::Node,key,<keyword arguments>)
    descendants!(node::Node,key,<keyword arguments>)

Get attribute values from the descendants (acropetal). The mutating version (`descendants!`)
cache the results in a cached variable named after the hash of the function call. This version
is way faster for large trees, but require to clean the chache sometimes (see [`clean_cache`](@ref)).
It also only works for trees with attributes of subtype of `AbstractDict`.

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name. Make it a `Symbol` for faster computation time.

## Keyword Arguments

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `self = false`: is the value for the current node needed ?
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
- `recursivity_level = -1`: The maximum number of recursions allowed (considering filters).
*E.g.* to get the first level children only: `recursivity_level = 1`, for children +
grand-children: `recursivity_level = 2`. If a negative value is provided (the default), the
function returns all valid values from the node to the leaves.
- `type::Union{Union,DataType}`: The type of the attribute. Makes the function run much
faster if provided (≈4x faster).

# Note

In most cases, the `type` argument should be given as a union of `Nothing` and the data type
of the attribute to manage missing or inexistant data, e.g. measurements made at one scale
only. See examples for more details.

# Examples

```julia
# Importing the mtg from the github repo:
mtg = read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

descendants(mtg, :Length) # Short to write, but slower to execute

# Fast version, note that we pass a union of Nothing and Float64 because there are some nodes
# without a `Length` attribute:
descendants(mtg, :Length, type = Union{Nothing,Float64})

# Filter by scale:
descendants(mtg, :XX, scale = 1, type = Float64)
descendants(mtg, :Length, scale = 3, type = Float64)

# Filter by symbol:
descendants(mtg, :Length, symbol = "Leaf")
descendants(mtg, :Length, symbol = ("Leaf","Internode"))
```
"""
function descendants(
    node,key;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    self = false,
    filter_fun = nothing,
    recursivity_level = -1,
    type::Union{Union,DataType} = Any)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale = scale, symbol = symbol, link = link)

    val = Array{type,1}()

    if self
        keep = is_filtered(node, scale, symbol, link, filter_fun)

        if keep
            push!(val, unsafe_getindex(node, key))
        elseif !all
            # We don't keep the value and we have to stop at the first filtered-out value
            return val
        end
    end

    descendants_(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level)
    return val
end


function descendants_(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level)

    if !isleaf(node) && recursivity_level != 0
        for chnode in ordered_children(node)
            # Is there any filter happening for the current node? (FALSE if filtered out):
            keep = is_filtered(chnode, scale, symbol, link, filter_fun)

            if keep
                push!(val, unsafe_getindex(chnode, key))
            end

            # If we want to continue even if the current node is filtered-out
            if all || keep
                descendants_(chnode, key, scale, symbol, link, all, filter_fun, val, recursivity_level - 1)
            end
        end
    end
end


function descendants!(
    node,key;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    self = false,
    filter_fun = nothing,
    recursivity_level = -1,
    type::Union{Union,DataType} = Any)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale = scale, symbol = symbol, link = link)

    key_cache = "_cache_" * bytes2hex(sha1(join([key, scale, symbol, link, all, self, filter_fun, type])))

    if node[key_cache] === nothing

        val = Array{type,1}()

        if self
            keep = is_filtered(node, scale, symbol, link, filter_fun)

            if keep
                push!(val, unsafe_getindex(node, key))
            elseif !all
                # We don't keep the value and we have to stop at the first filtered-out value
                return val
            end
        end

        descendants_!(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level, key_cache)

        # Caching the result into a cache attribute named after the SHA of the function arguments:
        node[key_cache] = val
    else
        val = node[key_cache]
    end

    return val
end

"""
Fast version of descendants_ that mutates the mtg nodes to cache the information.
"""
function descendants_!(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level, key_cache)

    if !isleaf(node) && recursivity_level != 0
        if node[key_cache] === nothing # Is there any cached value? If so, do not recompute
            for chnode in ordered_children(node)
                # Is there any filter happening for the current node? (FALSE if filtered out):
                keep = is_filtered(chnode, scale, symbol, link, filter_fun)

                if keep
                    push!(val, unsafe_getindex(chnode, key))
                end

                # If we want to continue even if the current node is filtered-out
                if all || keep
                    descendants_!(chnode, key, scale, symbol, link, all, filter_fun, val, recursivity_level - 1, key_cache)
                end
            end
            node[key_cache] = val
        else
            append!(val, node[key_cache])
        end
    end
end

"""
    clean_cache!(mtg)

Clean the cached variables in the mtg, usually added from [`descendants!`](@ref).
"""
function clean_cache!(mtg)
    cached_vars = find_cached_vars(mtg)
    for i in cached_vars
        traverse!(mtg, x -> pop!(x, i))
    end
end


function find_cached_vars(node)
    collect(keys(node.attributes))[findall(x -> occursin("_cache_", x), String.(keys(node.attributes)))]
end
