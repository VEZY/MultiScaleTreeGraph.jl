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
@inline no_node_filters(scale, symbol, link, filter_fun=nothing) =
    isnothing(scale) && isnothing(symbol) && isnothing(link) && isnothing(filter_fun)

@inline normalize_symbol_filter(filter::Nothing) = nothing
@inline normalize_symbol_filter(filter::Symbol) = filter
@inline normalize_symbol_filter(filter::AbstractString) = Symbol(filter)
@inline normalize_symbol_filter(filter::Char) = Symbol(filter)
@inline function normalize_symbol_filter(filter::T) where {T<:Union{Tuple,AbstractArray}}
    map(normalize_symbol_filter, filter)
end

@inline normalize_link_filter(filter::Nothing) = nothing
@inline normalize_link_filter(filter::Symbol) = filter
@inline normalize_link_filter(filter::AbstractString) = Symbol(filter)
@inline normalize_link_filter(filter::Char) = Symbol(filter)
@inline function normalize_link_filter(filter::T) where {T<:Union{Tuple,AbstractArray}}
    map(normalize_link_filter, filter)
end

@inline normalize_symbol_allowed(filters::Nothing) = nothing
@inline function normalize_symbol_allowed(filters::T) where {T<:Union{Tuple,AbstractArray}}
    map(normalize_symbol_filter, filters)
end

function check_filters(node::Node{N,A}; scale=nothing, symbol=nothing, link=nothing) where {N<:AbstractNodeMTG,A}
    no_node_filters(scale, symbol, link) && return nothing

    root_node = get_root(node)

    if root_node[:scales] !== nothing
        check_filter(N, :scale, scale, unique(root_node[:scales]))
    end

    if root_node[:symbols] !== nothing
        check_filter(N, :symbol, normalize_symbol_filter(symbol), unique(normalize_symbol_allowed(root_node[:symbols])))
    end

    if root_node[:link] !== nothing
        check_filter(N, :link, normalize_link_filter(link), (:/, :<, :+))
    end

    return nothing
end

function check_filter(nodetype, type::Symbol, filter, filters)
    if !isnothing(filter)
        filter_type = fieldtype(nodetype, type)
        filter_ok = typeof(filter) <: filter_type
        if type == :symbol || type == :link
            filter_ok = filter_ok || typeof(filter) <: Union{Symbol,AbstractString,Char}
        end
        !filter_ok &&
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
    node_mtg_ = node_mtg(node)
    link_keep = isnothing(mtg_link) || is_filtered(mtg_link, getfield(node_mtg_, :link))
    symbol_keep = isnothing(mtg_symbol) || is_filtered(mtg_symbol, getfield(node_mtg_, :symbol))
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

@inline function is_filtered(filter::AbstractString, value::Symbol)
    Symbol(filter) === value
end

@inline function is_filtered(filter::AbstractString, value::AbstractString)
    filter == value
end

@inline function is_filtered(filter::AbstractString, value)
    filter == value
end

@inline function is_filtered(filter::Symbol, value::AbstractString)
    filter === Symbol(value)
end

@inline function is_filtered(filter::Symbol, value::Symbol)
    filter === value
end

@inline function is_filtered(filter::Symbol, value)
    filter === value
end

@inline function is_filtered(filter::T, value::Symbol) where {T<:Union{Tuple,AbstractArray}}
    for f in filter
        is_filtered(f, value) && return true
    end
    return false
end

@inline function is_filtered(filter::T, value::AbstractString) where {T<:Union{Tuple,AbstractArray}}
    for f in filter
        is_filtered(f, value) && return true
    end
    return false
end

@inline function is_filtered(filter, value::T) where {T<:Union{Tuple,Array}}
    for x in value
        is_filtered(filter, x) || return false
    end
    return true
end


"""
    parse_macro_args(args)

Parse filters and arguments given as a collection of expressions. This function is used to
get the filters as keyword arguments in macros.

# Examples

```julia
args = (:(x = node_id(node)), :(y = node.x + 2), :(scale = 2))
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
