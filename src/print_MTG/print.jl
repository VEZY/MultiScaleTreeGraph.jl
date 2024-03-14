function AbstractTrees.printnode(io::IO, node::Node)
    print(io, join(["Node -> ID:", node_id(node), "Name: node_", node_id(node), ", Link: ", node_mtg(node).link, "Index: ", node_mtg(node).index == -9999 ? "" : node_mtg(node).index]))
end

"""
Print a node to io using an UTF-8 formatted representation of the `tree`.
Most of the code from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/blob/master/src/printing.jl)

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
mtg
# / 1: \$
# └─ / 2: Individual
#    └─ / 3: Axis
#       └─ / 4: Internode
#          ├─ + 5: Leaf
#          └─ < 6: Internode
#             └─ + 7: Leaf
```
"""
function Base.print(node::Node; leading::AbstractString="", io::IO=stdout, limit=true)
    node_vec = get_printing(node; leading=leading)

    for (i, j) in enumerate(node_vec)
        print(io, j * "\n")
        limit && i >= displaysize(io)[1] && (print(io, "…"); break)
    end
end

function Base.print(node::Node, vars; leading::AbstractString="", io::IO=stdout)
    DataFrame(node, vars)
end

function Base.show(io::IO, node::Node)
    print(node; io=io)
end

"""
    get_printing(node::Node; leading::AbstractString = "")

Format the printing of the tree according to link: follow or branching
"""
function get_printing(node::Node; leading::AbstractString="")
    node_vec = [link(node) * " " * string(node_id(node)) * ": " * symbol(node)]
    print_below = get_printing_(node; leading="")
    if print_below !== nothing
        append!(node_vec, print_below)
    else
        node_vec
    end
end


function get_printing_(node::Node; leading::AbstractString="")
    child_vec = Array{String,1}()
    if !isleaf(node)
        last = length(children(node))
        i = 0
        for chnode in children(node)
            mtg_encoding = node_mtg(chnode)
            id = node_id(chnode)
            i += 1
            if i != last
                to_print = leading * "\u251C\u2500 " * mtg_encoding.link * " " * string(id) * ": " * mtg_encoding.symbol
                new_leading = leading * "\u2502  "
            else
                to_print = leading * "\u2514\u2500 " * mtg_encoding.link * " " * string(id) * ": " * mtg_encoding.symbol
                new_leading = leading * "   "
            end
            append!(child_vec, [to_print])
            if length(children(chnode)) != 0
                children_vec = get_printing_(chnode; leading=new_leading)
                append!(child_vec, children_vec)
            end
        end
        return child_vec
    end
end
