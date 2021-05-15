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
function check_filters(node; scale = nothing, symbol = nothing, link = nothing) where T

    root_node = getroot(node)

    nodeMTG_type = typeof(node.MTG)
    check_filter(nodeMTG_type,:scale,scale,unique(root_node.attributes[:scales]))
    check_filter(nodeMTG_type,:symbol,symbol,unique(root_node.attributes[:symbols]))
    check_filter(nodeMTG_type,:link,link,("/","<","+"))

    return nothing
end

function check_filter(nodetype,type::Symbol,filter,filters)
    if !isnothing(filter)
        filter_type = fieldtype(nodetype,type)
        !(typeof(filter) <: filter_type) &&
            @warn "The $type argument should be of type $filter_type"
        if !(filter in filters)
            @warn "The $type argument should be one of: $filters, and you provided $filter."
        end
    end
end

function check_filter(nodetype,type::Symbol,filter::T,filters) where T<:Union{Tuple,AbstractArray}
    for i in filter
        check_filter(nodetype,type,i,filters)
    end
end


"""
    is_filtered(node, scale, symbol, link, filter_fun)

Is a node filtered in ? Returns `true` if the node is kept, `false` if it is filtered-out.
"""
function is_filtered(node, scale, symbol, link, filter_fun)

    link_keep = is_filtered(link,node.MTG.link)
    symbol_keep = is_filtered(symbol,node.MTG.symbol)
    scale_keep = is_filtered(scale,node.MTG.scale)
    filter_fun_keep = isnothing(filter_fun) || filter_fun(node)

    scale_keep && symbol_keep && link_keep && filter_fun_keep
end


function is_filtered(filter,value)
    isnothing(filter) || value in filter
end

function is_filtered(filter::String,value)
    isnothing(filter) || value in (filter,)
end

function is_filtered(filter,value::T) where T<:Union{Tuple,Array}
    all(map(x -> is_filtered(filter,x), value))
end


"""
    parse_macro_args(args)

Parse filters and arguments given as a collection of expressions. This function is used to
get the filters as keyword arguments in macros.

# Examples

```julia
args = (:(x = length(node.name)), :(y = node.x + 2), :(scale = 2))
MTG.parse_args_filters(args)
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
            push!(args_array,i)
        end
    end
    return (;filters...), (;kwargs...), (args_array...,)
end
