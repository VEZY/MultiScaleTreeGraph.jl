"""
# Expand MTG line

Expand the elements denoted by the syntactic sugar "<<", "<.<", "++" or "+.+"

# Arguments

- `x::Array{String}`: A split MTG line (e.g. c("/P1","/A1"))
- `line::Array{Int64,1}`: The current line index (mutated) in the file. Only
used as information when erroring.

# Returns

A Tuple of:  
- the split MTG line with all nodes explicitly  
- the nodes with common attributes (when using `<.<` or `+.+`)

# Examples

```jldoctest
julia> x = split("/A1+U85/U86<U87<.<U93<U94<.<U96<U97+.+U100",r"(?<=.)(?=[</+])");
julia> nodes, shared = expand_node!(x,1)
(AbstractString["/A1", "+U85", "/U86", "<U87", "<U88", "<U89", "<U90", "<U91", "<U92", "<U93", "<U94", "<U95", "<U96", "<U97", "+U98", "+U99", "+U100"], Any[87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100])
```
"""
function expand_node!(x,line)
    
    node_to_expand = findall(y -> any(occursin.(y,("<","<.","+","+."))),x)
    relative_index = 0
    shared = []
    for i in node_to_expand
        j = i + relative_index
        link = replace(parse_MTG_node(x[j])[1],"." => "")
        node_before = parse_MTG_node(x[j-1])
        node_after = parse_MTG_node(x[j+1])
        expanded_index = collect((node_before[3]+1):(node_after[3]-1))
        
        if node_before[2] != node_after[2]
            error("Found nodes to expand at line $line but ",
            "the symbols of the nodes before and after syntactic ",
            "sugar ($(x[i])) do not match.")
        end
        
        expanded_nodes = join([link, node_before[2]]) .* string.(expanded_index)
        
        if occursin(x[j], "<.") || occursin(x[j],"+.")
            append!(shared, collect((node_before[3]):(node_after[3])))
        end
        
        x = [x[1:(j-1)]; expanded_nodes; x[(j+1):end]]
        relative_index = relative_index + length(expanded_nodes) - 1
        shared
    end
    
    (x,shared)
end