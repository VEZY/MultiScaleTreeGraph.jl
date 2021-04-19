"""
    check_filters(node::Node{T}; scale = nothing, symbol = nothing, link = nothing)

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

    check_filter(NodeMTG,:scale,scale,unique(root_node.attributes.scales))
    check_filter(NodeMTG,:symbol,symbol,unique(root_node.attributes.symbols))
    check_filter(NodeMTG,:link,link,("/","<","+"))

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
