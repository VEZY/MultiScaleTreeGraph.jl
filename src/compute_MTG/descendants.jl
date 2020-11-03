"""
    descendants(node::Node,key[,type])

Get attribute values from the descendants (acropetal).

# Arguments

- `node::Node`: The node to start at.
- `key`: The key, or attribute name. Make it a `Symbol` for faster computation time.
- `type::DataType`: The type of the attribute. Makes the function run much faster if provided.

[`eigvals`](@ref)
"""
function descendants(node::Node,key,type)
    val = Array{type,1}()
    if !isleaf(node)
        for (name, chnode) in node.children
            push!(val, unsafe_getindex(chnode,key))
            append!(val, descendants(chnode,key,type))
        end
    end
    val
end

function descendants(node::Node,key)
    val = Array{Any,1}()
    if !isleaf(node)
        for (name, chnode) in node.children
            push!(val, unsafe_getindex(chnode,key))
            append!(val, descendants(chnode,key))
        end
    end
    val
end