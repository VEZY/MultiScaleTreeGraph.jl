function descendants(node::Node,key;type=Any)
    val = Array{type,1}()
    if !isleaf(node)
        for (name, chnode) in node.children
            push!(val, unsafe_getindex(chnode,key))
            append!(val, descendants(chnode,key;type=Any))
        end
    end
    val
end