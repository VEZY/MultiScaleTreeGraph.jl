function DataFrames.DataFrame(node::Node,vars::Array{Symbol,1})
    node_vec = get_printing(node)
    df = DataFrame(tree = node_vec)

    for var in vars
        insertcols!(df, var => [unsafe_getindex(node,var),descendants(node,var)...])
    end
    df
end

function DataFrames.DataFrame(node::Node,vars::Symbol)
    DataFrame([get_printing(node), [unsafe_getindex(node,vars),descendants(node,vars)...]],[:tree,vars])
end