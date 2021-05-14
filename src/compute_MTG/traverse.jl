"""
    traverse!(node::Node, f::Function, args...)

Traverse the nodes of a (sub-)tree, given any starting node in the tree.

# Arguments

- `node::Node`: An MTG node (*e.g.* the whole mtg returned by `read_mtg()`).
- `f::Function`: a function to apply over each node
- `args::Any`: any argument to pass to the function

# Returns

Nothing, mutates the (sub-)tree.

# Examples

```julia
file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");
mtg,classes,description,features = read_mtg(file);
traverse!(mtg, x -> isleaf(x) ? println(x.name," is a leaf") : nothing)
node_5 is a leaf
node_7 is a leaf
```
"""
function traverse!(node::Node, f::Function, args...)

    if !isempty(args)
        f(node, args...)
    else
        f(node)
    end

    if !isleaf(node)
        for (key, chnode) in node.children
            traverse!(chnode, f, args...)
        end
    end
end


function traverse!(node::Node, f::Function)

    f(node)

    if !isleaf(node)
        for (key, chnode) in node.children
            traverse!(chnode, f)
        end
    end
end
