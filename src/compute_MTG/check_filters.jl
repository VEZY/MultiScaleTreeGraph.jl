"""
    check_filters(node; scale = nothing, symbol = nothing, link = nothing)

Check if the filters are consistant with the mtg onto which they are applied

# Examples

```julia
check_filters(mtg, scale = 1)
check_filters(mtg, scale = (1,2))
check_filters(mtg, scale = (1,2), symbol = "Leaf", link = "<")
```
"""
function check_filters(node::Node{N,A}; scale=nothing, symbol=nothing, link=nothing) where {N<:AbstractNodeMTG,A}

    root_node = get_root(node)

    if root_node[:scales] !== nothing
        check_filter(N, :scale, scale, unique(root_node[:scales]))
    end

    if root_node[:symbols] !== nothing
        check_filter(N, :symbol, symbol, unique(root_node[:symbols]))
    end

    if root_node[:link] !== nothing
        check_filter(N, :link, link, ("/", "<", "+"))
    end

    return nothing
end

function check_filter(nodetype, type::Symbol, filter, filters)
    if !isnothing(filter)
        filter_type = fieldtype(nodetype, type)
        !(typeof(filter) <: filter_type) &&
            @warn "The $type argument should be of type $filter_type"
        if !(filter in filters)
            @warn "The $type argument should be one of: $filters, and you provided $filter."
        end
    end
end

function check_filter(nodetype, type::Symbol, filter::T, filters) where {T<:Union{Tuple,AbstractArray}}
    for i in filter
        check_filter(nodetype, type, i, filters)
    end
end


"""
    is_filtered(node, scale, symbol, link, filter_fun)

Is a node filtered in ? Returns `true` if the node is kept, `false` if it is filtered-out.
"""
@inline function is_filtered(node, mtg_scale, mtg_symbol, mtg_link, filter_fun)

    link_keep = isnothing(mtg_link) || is_filtered(mtg_link, link(node))
    symbol_keep = isnothing(mtg_symbol) || is_filtered(mtg_symbol, symbol(node))
    scale_keep = isnothing(mtg_scale) || is_filtered(mtg_scale, scale(node))
    filter_fun_keep = isnothing(filter_fun) || filter_fun(node)

    scale_keep && symbol_keep && link_keep && filter_fun_keep
end

@inline function is_filtered(filter::Nothing, value)
    true
end

@inline function is_filtered(filter, value)
    value in filter
end

@inline function is_filtered(filter::String, value)
    value in (filter,)
end

@inline function is_filtered(filter, value::T) where {T<:Union{Tuple,Array}}
    all(map(x -> is_filtered(filter, x), value))
end


"""
    parse_macro_args(args)

Parse filters and arguments given as a collection of expressions. This function is used to
get the filters as keyword arguments in macros.

# Examples

```julia
args = (:(x = length(node.name)), :(y = node.x + 2), :(scale = 2))
MultiScaleTreeGraph.parse_macro_args(args)
```
"""
function parse_macro_args(args)
    filters = Dict{Symbol,Any}(
        :scale => nothing,
        :symbol => nothing,
        :link => nothing,
        :filter_fun => nothing
    )

    kwargs = Dict{Symbol,Any}(
        :all => true,
        :traversal => AbstractTrees.PreOrderDFS,
    )

    args_array = []

    for i in args
        if i.head == :(=) && i.args[1] in keys(filters)
            filters[i.args[1]] = i.args[2]
        elseif i.head == :(=) && i.args[1] in keys(kwargs)
            kwargs[i.args[1]] = i.args[2]
        else
            push!(args_array, i)
        end
    end
    return (; filters...), (; kwargs...), (args_array...,)
end
