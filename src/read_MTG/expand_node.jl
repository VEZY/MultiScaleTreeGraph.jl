"""
# Expand MTG line

Expand the elements denoted by the syntactic sugar "<<", "<.<", "++" or "+.+"

# Arguments

- `x::Array{String}`: A split MTG line (e.g. c("/P1","/A1"))
- `line::Integer`: The current line number, used in error messages.

# Returns

A Tuple of:
- the split MTG line with all nodes explicitly
- the positions of nodes that get the row's attributes (when using `<.<` or `+.+`)

# Examples

```julia
x = MultiScaleTreeGraph.split_MTG_elements("/A1/U87<.<U89<U90")
nodes, shared = MultiScaleTreeGraph.expand_node!(x, 1)
# nodes: ["/A1", "/U87", "<U88", "<U89", "<U90"]
# shared: positions 2 through 4
```
"""
function expand_node!(x, line)

    node_to_expand = findall(y -> y in ("<", "<.", "+", "+."), x)
    relative_index = 0
    shared = BitSet()
    for i in node_to_expand
        j = i + relative_index
        operator = x[j]
        link = first(operator)
        node_before = parse_MTG_node(x[j - 1])
        node_after = parse_MTG_node(x[j + 1])

        if node_before[2] != node_after[2]
            error("Found nodes to expand at line $line but ",
            "the symbols of the nodes before and after syntactic ",
            "sugar ($operator) do not match.")
        end

        expanded_index = (node_before[3] + 1):(node_after[3] - 1)
        expanded_nodes = string.(link, node_before[2], expanded_index)

        if operator in ("<.", "+.")
            # Include both endpoints, using their positions after expansion.
            union!(shared, (j - 1):(j + length(expanded_nodes)))
        end

        x = [x[1:(j - 1)]; expanded_nodes; x[(j + 1):end]]
        relative_index = relative_index + length(expanded_nodes) - 1
    end

    (x, shared)
end
