@inline function _maybe_depwarn_traversal_type_kw(fname::Symbol, type)
    type === Any && return nothing
    Base.depwarn(
        "Keyword argument `type` in `$fname` is deprecated and will be removed in a future release. " *
        "Return types are inferred automatically from the columnar attribute store; remove `type` " *
        "and use `ignore_nothing=true` when you want `nothing` values filtered out.",
        fname,
    )
    return nothing
end

@inline function _descendants_index_compatible(scale, link, all::Bool, filter_fun, recursivity_level)
    scale === nothing || return false
    link === nothing || return false
    all || return false
    filter_fun === nothing || return false
    return isinf(recursivity_level) || recursivity_level < 0
end

@inline function _bucket_allow_mask(store::MTGAttributeStore, symbol_filter)
    symbol_filter === nothing && return nothing
    mask = falses(length(store.buckets))
    for bid in _symbol_bucket_ids(store, symbol_filter)
        mask[bid] = true
    end
    return mask
end

function _collect_descendant_values_indexed!(
    out::AbstractVector,
    node,
    key::Symbol,
    key_plan::ColumnarQueryPlan,
    symbol_filter,
    self::Bool,
    ignore_nothing::Bool,
)
    store = _columnar_store(node)
    store === nothing && return false
    _prepare_subtree_index!(store, get_root(node)) || return false
    idx = store.subtree_index

    nid0 = node_id(node)
    nid0 > length(idx.tin) && return false
    left = idx.tin[nid0]
    right = idx.tout[nid0]
    left == 0 && return false
    self || (left += 1)
    left > right && return true

    allow_mask = _bucket_allow_mask(store, symbol_filter)

    @inbounds for i in left:right
        nid = idx.dfs_order[i]
        bid = store.node_bucket[nid]
        bid == 0 && continue
        allow_mask === nothing || allow_mask[bid] || continue

        col_idx = key_plan.col_idx_by_bucket[bid]
        if col_idx == 0
            ignore_nothing && continue
            push!(out, nothing)
            continue
        end

        row = store.node_row[nid]
        v = store.buckets[bid].columns[col_idx].data[row]
        ignore_nothing && v === nothing && continue
        push!(out, v)
    end

    return true
end

function collect_descendant_values!(node, key, scale, symbol, link, filter_fun, all, val, recursivity_level, key_plan=nothing)
    recursivity_level == 0 && return val
    recursivity_level -= 1

    keep = is_filtered(node, scale, symbol, link, filter_fun)
    if keep
        push!(val, unsafe_getindex(node, key, key_plan))
    elseif !all
        return val
    end

    @inbounds for chnode in children(node)
        collect_descendant_values!(chnode, key, scale, symbol, link, filter_fun, all, val, recursivity_level, key_plan)
    end
    return val
end

function collect_descendant_values_no_filter!(node, key, val, recursivity_level, key_plan=nothing)
    recursivity_level == 0 && return val
    recursivity_level -= 1

    push!(val, unsafe_getindex(node, key, key_plan))
    @inbounds for chnode in children(node)
        collect_descendant_values_no_filter!(chnode, key, val, recursivity_level, key_plan)
    end
    return val
end

function collect_descendant_nodes!(node, scale, symbol, link, filter_fun, all, val, recursivity_level)
    recursivity_level == 0 && return val
    recursivity_level -= 1

    keep = is_filtered(node, scale, symbol, link, filter_fun)
    if keep
        push!(val, node)
    elseif !all
        return val
    end

    @inbounds for chnode in children(node)
        collect_descendant_nodes!(chnode, scale, symbol, link, filter_fun, all, val, recursivity_level)
    end
    return val
end

function collect_descendant_nodes_no_filter!(node, val, recursivity_level)
    recursivity_level == 0 && return val
    recursivity_level -= 1

    push!(val, node)
    @inbounds for chnode in children(node)
        collect_descendant_nodes_no_filter!(chnode, val, recursivity_level)
    end
    return val
end

function descendants(
    node, key;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    self=false,
    filter_fun=nothing,
    recursivity_level=Inf,
    ignore_nothing::Bool=false,
    type::Union{Union,DataType}=Any)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    _maybe_depwarn_traversal_type_kw(:descendants, type)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    key_ = Symbol(key)
    out_type = type === Any ? infer_columnar_attr_type(node, key_, symbol, ignore_nothing) : type
    val = Array{out_type,1}()
    key_plan = build_columnar_query_plan(node, key_)

    if key_plan isa ColumnarQueryPlan &&
       _descendants_index_compatible(scale, link, all, filter_fun, recursivity_level) &&
       _collect_descendant_values_indexed!(val, node, key_, key_plan, symbol, self, ignore_nothing)
        return val
    end

    # Change the filtering function if we also want to remove nodes with nothing values:
    filter_fun_ = filter_fun_nothing(filter_fun, ignore_nothing, key_)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun_)

    if self
        if use_no_filter
            collect_descendant_values_no_filter!(node, key_, val, recursivity_level, key_plan)
        else
            collect_descendant_values!(node, key_, scale, symbol, link, filter_fun_, all, val, recursivity_level, key_plan)
        end
    else
        # If we don't want to include the value of the current node, we apply the traversal to its children directly:
        for chnode in children(node)
            if use_no_filter
                collect_descendant_values_no_filter!(chnode, key_, val, recursivity_level, key_plan)
            else
                collect_descendant_values!(chnode, key_, scale, symbol, link, filter_fun_, all, val, recursivity_level, key_plan)
            end
        end
    end

    return val
end

# Same as above, but without the `key` argument (we want the nodes themselves):
function descendants(
    node;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    self=false,
    filter_fun=nothing,
    recursivity_level=Inf,
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    val = Array{typeof(node),1}()
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun)

    if self
        if use_no_filter
            collect_descendant_nodes_no_filter!(node, val, recursivity_level)
        else
            collect_descendant_nodes!(node, scale, symbol, link, filter_fun, all, val, recursivity_level)
        end
    else
        # If we don't want to include the value of the current node, we apply the traversal to its children directly:
        for chnode in children(node)
            if use_no_filter
                collect_descendant_nodes_no_filter!(chnode, val, recursivity_level)
            else
                collect_descendant_nodes!(chnode, scale, symbol, link, filter_fun, all, val, recursivity_level)
            end
        end
    end

    return val
end

function descendants!(
    out::AbstractVector,
    node, key;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    self=false,
    filter_fun=nothing,
    recursivity_level=Inf,
    ignore_nothing::Bool=false,
    type::Union{Union,DataType}=Any,
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    _maybe_depwarn_traversal_type_kw(:descendants!, type)
    check_filters(node, scale=scale, symbol=symbol, link=link)
    key_ = Symbol(key)
    key_plan = build_columnar_query_plan(node, key_)

    empty!(out)
    if key_plan isa ColumnarQueryPlan &&
       _descendants_index_compatible(scale, link, all, filter_fun, recursivity_level) &&
       _collect_descendant_values_indexed!(out, node, key_, key_plan, symbol, self, ignore_nothing)
        return out
    end

    filter_fun_ = filter_fun_nothing(filter_fun, ignore_nothing, key_)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun_)

    if self
        if use_no_filter
            collect_descendant_values_no_filter!(node, key_, out, recursivity_level, key_plan)
        else
            collect_descendant_values!(node, key_, scale, symbol, link, filter_fun_, all, out, recursivity_level, key_plan)
        end
    else
        for chnode in children(node)
            if use_no_filter
                collect_descendant_values_no_filter!(chnode, key_, out, recursivity_level, key_plan)
            else
                collect_descendant_values!(chnode, key_, scale, symbol, link, filter_fun_, all, out, recursivity_level, key_plan)
            end
        end
    end
    return out
end

function descendants!(
    out::AbstractVector,
    node;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    self=false,
    filter_fun=nothing,
    recursivity_level=Inf,
)
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    check_filters(node, scale=scale, symbol=symbol, link=link)
    use_no_filter = no_node_filters(scale, symbol, link, filter_fun)

    empty!(out)
    if self
        if use_no_filter
            collect_descendant_nodes_no_filter!(node, out, recursivity_level)
        else
            collect_descendant_nodes!(node, scale, symbol, link, filter_fun, all, out, recursivity_level)
        end
    else
        for chnode in children(node)
            if use_no_filter
                collect_descendant_nodes_no_filter!(chnode, out, recursivity_level)
            else
                collect_descendant_nodes!(chnode, scale, symbol, link, filter_fun, all, out, recursivity_level)
            end
        end
    end
    return out
end

#Note: The mutating version is more complicated, so we don't use `traverse!` but make another implementation.
function descendants!(
    node::Node{N,A}, key;
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    self=false,
    filter_fun=nothing,
    recursivity_level=Inf,
    ignore_nothing=false,
    type::Union{Union,DataType}=Any) where {N,A<:AbstractDict}
    symbol = normalize_symbol_filter(symbol)
    link = normalize_link_filter(link)
    _maybe_depwarn_traversal_type_kw(:descendants!, type)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    key_cache = cache_name(key, scale, symbol, link, all, self, filter_fun, type)
    val = Array{type,1}()

    # Change the filtering function if we also want to remove nodes with nothing values:
    filter_fun_ = filter_fun_nothing(filter_fun, ignore_nothing, key)

    if self
        keep = is_filtered(node, scale, symbol, link, filter_fun_)

        if keep
            val_ = unsafe_getindex(node, key)
            push!(val, val_)
        elseif !all
            # We don't keep the value and we have to stop at the first filtered-out value
            return val
        end
    end

    if node[key_cache] === nothing
        descendants_!(node, key, scale, symbol, link, all, filter_fun_, val, recursivity_level, key_cache)

        # Caching the result into a cache attribute named after the SHA of the function arguments:
        node[key_cache] = val
    else
        append!(val, node[key_cache])
    end

    return val
end

"""
Fast version of descendants_ that mutates the mtg nodes to cache the information.
"""
function descendants_!(node, key, scale, symbol, link, all, filter_fun, val, recursivity_level, key_cache)
    val_i = Array{eltype(val),1}()
    if !isleaf(node) && recursivity_level != 0
        if node[key_cache] === nothing # Is there any cached value? If so, do not recompute
            for chnode in children(node)
                # Is there any filter happening for the current node? (FALSE if filtered out):
                keep = is_filtered(chnode, scale, symbol, link, filter_fun)

                if keep
                    val_key = unsafe_getindex(chnode, key)
                    push!(val_i, val_key)
                    # Only decrement the recursivity level when the current node is not filtered-out
                    recursivity_level -= 1
                end
                # If we want to continue even if the current node is filtered-out
                if all || keep
                    descendants_!(chnode, key, scale, symbol, link, all, filter_fun, val_i, recursivity_level, key_cache)
                end
            end
            node[key_cache] = val_i
            append!(val, val_i)
        else
            append!(val, copy(node[key_cache]))
        end
    end
end

"""
    descendants(node::Node,key;<keyword arguments>)
    descendants(node::Node;<keyword arguments>)
    descendants!(node::Node,key;<keyword arguments>)
    descendants!(out::AbstractVector,node::Node,key;<keyword arguments>)

Get attribute values from the descendants of the node (acropetal).
The first method returns an array of values, the second an array of nodes that respect the filters, and the third the mutating version of the 
first one that caches the results in the mtg.

The mutating version (`descendants!`) cache the results in a cached variable named after the hash of the function call. This version
is way faster when `descendants` is called repeateadly for the same computation on large trees, but require to clean the chache sometimes 
(see [`clean_cache!`](@ref)).

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name (only mandatory for the first and third methods). Make it a `Symbol` for faster computation time.

## Keyword Arguments

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Symbols.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Symbols.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `self = false`: is the value for the current node needed ?
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).
- `recursivity_level = Inf`: The maximum number of recursions allowed (considering filters).
*E.g.* to get the first level children only: `recursivity_level = 1`, for children +
grand-children: `recursivity_level = 2`. If `Inf` (the default) or a negative value is provided, there is no 
recursion limitation.
- `ignore_nothing = false`: filter-out the nodes with `nothing` values for the given `key`
- `type::Union{Union,DataType}`: Deprecated. Return types are inferred automatically.


# Tips

To get the values of the leaves use [`isleaf`](@ref) as the filtering function, e.g.:
`descendants(mtg, :Width; filter_fun = isleaf)`.

# Examples

```julia
# Importing the mtg from the github repo:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

descendants(mtg, :Length)

# Filter by scale:
descendants(mtg, :XEuler, scale = 3)
descendants(mtg, :Length, scale = 3, ignore_nothing=true) # No `nothing` in output

# Filter by symbol:
descendants(mtg, :Length, symbol = :Leaf)
descendants(mtg, :Length, symbol = (:Leaf,:Internode))

# Filter by function, e.g. get the values for the leaves only:
descendants(mtg, :Width; filter_fun = isleaf)

# You can also ask for different attributes by passing them as a vector:
descendants(mtg, [:Width, :Length]; filter_fun = isleaf)
# The output is an array of arrays of length of the attributes you asked for.

# It is possible to cache the results in the mtg using the mutating version `descendants!` (note the `!` 
# at the end of the function name):
transform!(mtg, node -> sum(descendants!(node, :Length)) => :subtree_length, symbol = :Internode)

# Or using `@mutate_mtg!` instead of `transform!`:
@mutate_mtg!(mtg, subtree_length = sum(descendants!(node, :Length)), symbol = :Internode)

# The cache is stored in a temporary variable with a name that starts with `_cache_` followed by the SHA
# of the function call, *e.g.*: `:_cache_5c1e97a3af343ce623cbe83befc851092ca61c8d`:
node_attributes(mtg[1][1][1])

# You can then clean the cache to avoid using too much memory:
clean_cache!(mtg)
node_attributes(mtg[1][1][1])
```
"""
descendants!, descendants
