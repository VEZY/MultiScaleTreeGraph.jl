function AbstractTrees.printnode(io::IO, node::Node)
    print(io, join(["Node: ",node.name,", Link: ",node.MTG.link,"Index: ", node.MTG.index]))
end

"""
Print a node to io using an UTF-8 formatted representation of the `tree`.
Most of the code from [DataTrees.jl](https://github.com/vh-d/DataTrees.jl/blob/master/src/printing.jl)

# Examples
```jldoctest
julia> file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");
julia> mtg,classes,description,features = read_mtg(file);
julia> mtg
node_1
└─ node_2
   └─ node_3
      └─ node_4
         ├─ node_5
         └─ node_6
            └─ node_7

```
"""
function Base.print(node::Node; leading::AbstractString = "", io::IO = stdout, limit = true)
    node_vec = get_printing(node; leading = leading)

    for (i,j) in enumerate(node_vec)
        print(io,j*"\n")
        limit && i >= displaysize(io)[1] && (print(io, "…"); break)
    end
end

function Base.print(node::Node,vars; leading::AbstractString = "", io::IO = stdout)
    DataFrame(node,vars)
end

function Base.show(io::IO, node::Node)
    print(node;io=io)
end

"""
    get_printing(node::Node; leading::AbstractString = "")

Format the printing of the tree according to link: follow or branching
"""
function get_printing(node::Node; leading::AbstractString = "")
    node_vec = [node.MTG.link * " " * node.name[6:end] * ": " * node.MTG.symbol]
    print_below = get_printing_(node; leading = "")
    if print_below !== nothing
        append!(node_vec,print_below)
    else
        node_vec
    end
end


function get_printing_(node::Node; leading::AbstractString = "")
    child_vec = Array{String,1}()
    if !isleaf(node)
        last = length(node.children)
        i = 0
        for (key, chnode) in node.children
            i += 1
            if i != last
                to_print    = leading * "\u251C\u2500 " * chnode.MTG.link * " " * key[6:end] * ": " * chnode.MTG.symbol
                new_leading = leading * "\u2502  "
            else
                to_print    = leading * "\u2514\u2500 " * chnode.MTG.link * " " * key[6:end] * ": " * chnode.MTG.symbol
                new_leading = leading * "   "
            end
            append!(child_vec,[to_print])
            if children(chnode) !== ()
                children_vec = get_printing_(chnode; leading = new_leading)
                append!(child_vec,children_vec)
            end
        end
        return child_vec
    end
end
