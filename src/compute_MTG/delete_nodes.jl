"""
delete_nodes!(mtg::Node,<keyword arguments>)

Delete nodes in mtg following filters rules.

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.

## Keyword Arguments (filters)

- `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
- `all::Bool = true`: Return all filtered-in nodes (`true`), or stop at the first node that
is filtered out (`false`).
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).

# Examples

```julia
# Importing the mtg from the github repo:
mtg,classes,description,features =
read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))

delete_nodes!(mtg,  scale = 2) # Will remove all nodes of scale 2

# Delete the leaves:
descendants(mtg, :Length, symbol = "Leaf")
# Delete the and internodes:
descendants(mtg, :Length, symbol = ("Leaf","Internode"))
```
"""
function delete_nodes!(
    node;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    filter_fun = nothing
    )

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale = scale, symbol = symbol, link = link)
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        node = delete_node!(node)
        # Don't go further if all == false
        all ? nothing : return nothing
    end

    delete_nodes!_(node, scale, symbol, link, all, filter_fun)

    return node
end


function delete_nodes!_(node, scale, symbol, link, all, filter_fun)
    if !isleaf(node)
        for (name, chnode) in node.children
            # Is there any filter happening for the current node? (true is deleted):
            filtered = is_filtered(chnode, scale, symbol, link, filter_fun)

            if filtered
                chnode = delete_node!(chnode)
                # Don't go further if all == false
                all ? nothing : return nothing
            end
            delete_nodes!_(chnode, scale, symbol, link, all, filter_fun)
        end
    end
end

"""
delete_node!(node)

Delete a node and re-parent the children to its own parent. If the node is a root and it has
only one child, the child becomes the root, if it has several children, it returns an error.

The function returns the parent node (or the new root if the node is a root)
"""
function delete_node!(node)
    if isroot(node)
        if length(node.children) == 1
            # If it has only one child, make it the new root:
            chnode = children(node)[1]
            chnode.parent = nothing
            # Add to the new root the mandatory root attributes:
            root_attrs = Dict(:symbols => node[:symbols], :scales => node[:scales])
            append!(chnode, root_attrs)

            node_return = chnode
        else
            error("Can't delete the root node if it has several children")
        end
    else
        parent_node = node.parent

        # Delete the node as child of his parent:
        pop!(node.parent.children, node.name)

        if !isleaf(node)
            # We re-parent the children to the parent of the node.
            for (name, chnode) in node.children
                addchild!(parent_node, chnode; force = true)
            end
        end
        node_return = parent_node
    end

    node.parent = nothing
    node.children = nothing
    node = nothing

    return node_return
end
