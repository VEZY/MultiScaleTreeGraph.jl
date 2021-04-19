function DataFrames.DataFrame(node::Node,vars::T) where T <: Union{AbstractArray, Tuple}
    node_vec = get_printing(node)
    df = DataFrame(tree = node_vec)

    for var in vars
        insertcols!(df, var => [descendants(node,var,self=true)...])
    end
    df
end

function DataFrames.DataFrame(node::Node,vars::T) where T <: Symbol
    DataFrame([get_printing(node), [descendants(node,vars,self=true)...]],[:tree,vars])
end

function DataFrames.DataFrame(node::Node,vars::T) where T <: AbstractString
    vars = Symbol(vars)
    DataFrame([get_printing(node), [descendants(node,vars,self=true)...]],[:tree,vars])
end
