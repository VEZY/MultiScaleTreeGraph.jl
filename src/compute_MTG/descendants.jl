"""
descendants(node::Node,key[,type])

Get attribute values from the descendants (acropetal).

# Arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name. Make it a `Symbol` for faster computation time.
- `type::Union{Union,DataType}`: The type of the attribute. Makes the function run much faster if provided.

# Note

In most cases, the `type` argument should be given as a union of `Nothing` and the data type
of the attribute to manage missing or inexistant data, e.g. measurements made at one scale
only. See examples for more details.

# Examples

```julia
descendants(mtg, :Length, type = Union{Nothing,Float64})

descendants(mtg, :XX, scale = 1)

descendants(mtg, :Length, scale = 3)
```
"""
function descendants(node,key;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all = true, # like continue in the R package, but actually the opposite
    # self = FALSE,
    filter_fun = nothing,
    type::Union{Union,DataType} = Any)

    val = Array{type,1}()

    if !isleaf(node)
        for (name, chnode) in node.children

            check_filters(chnode, scale, symbol, link)

            # Is there any filter happening for the current node? (FALSE if filtered out):
            link_keep = isnothing(link) || chnode.MTG.link in link
            symbol_keep = isnothing(symbol) || chnode.MTG.symbol in symbol
            scale_keep = isnothing(scale) || chnode.MTG.scale in scale
            filter_fun_keep = isnothing(filter_fun) || filter_fun(node)

            keep = scale_keep && symbol_keep && link_keep && filter_fun_keep

            if keep
                push!(val, unsafe_getindex(chnode,key))
            end

            # If we want to continue even if the current node is filtered-out
            if all || keep
                append!(val, descendants(chnode,key;
                            scale = scale,
                            symbol = symbol,
                            link = link,
                            all = true,
                            filter_fun = filter_fun,
                            type = type))
            end
        end
    end
    return val
end


function check_filters(node::Node{T}, scale = nothing, symbol = nothing, link = nothing) where T

    root_node = getroot(node)
    if !isnothing(scale)
        !(typeof(scale) <: fieldtype(NodeMTG,:scale)) &&
            error("The scale argument should be of type $(fieldtype(NodeMTG,:scale))")
        scales = unique(root_node.attributes.scales)
        if !all(scale in scales)
            error("The scale argument should be one of: $scales")
        end
    end

    if !isnothing(symbol)
        !(typeof(symbol) <: fieldtype(NodeMTG,:symbol)) &&
            error("The symbol argument should be of type $(fieldtype(NodeMTG,:symbol))")
        symbols = root_node.attributes.symbols
        if !all(symbol in symbols)
            error("The symbol argument should be one of: $symbols")
        end
    end

    if !isnothing(link)
        !(typeof(link) <: fieldtype(NodeMTG,:link)) &&
            error("The scale argument should be of type $(fieldtype(NodeMTG,:link)))")
        if !all(link in ("/","<","+"))
            error("The symbol argument should be one of: /, < or +")
        end
    end
end
