function DataFrames.DataFrame(node::Node,vars::Array{Symbol,1}; leading::AbstractString = "")
    node_vec = get_printing(node; leading = leading)
    df = DataFrame(tree = node_vec[2:end])

    for var in vars
        insertcols!(df, var => [unsafe_getindex(node,var),descendants(node,var)...])
    end
    df
end

function DataFrames.DataFrame(node::Node,vars::Symbol; leading::AbstractString = "")
    DataFrame([get_printing(node; leading = leading)[2:end], [unsafe_getindex(node,vars),descendants(node,vars)...]],
                 [:tree,vars])
end