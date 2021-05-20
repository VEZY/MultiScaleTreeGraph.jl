"""
delete_nodes!(mtg::Node,<keyword arguments>)

Delete nodes in mtg following filters rules.

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.

## Keyword Arguments (filters)

- `scale = nothing`: The scale to delete. Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol to delete. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node to delete. Usually a Tuple-alike of Char.
- `all::Bool = true`: Continue after the first deletion (`true`), or stop?
- `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref)
to decide whether to delete a node or not.

# Notes

1. The function is acropetal, meaning it will apply the deletion from leaves to the root to ensure
that one pass is enough and we don't repeat the process of visiting already visited children.
1. The function does not do anything fancy, it let the user take care of its own rules when
deleting nodes. So if you delete a branching node, the whole subtree will be modified and take
the link of the children. This process is left to the user becaue it highly depends on the mtg
structure.
1. The package provides some pre-made functions for filtering. See for example [`is_segment!`](@ref)
to re-compute the mtg at a given scale to have only nodes at branching points. This is often used
to match automatic reconstructions from e.g. LiDAR point cloud with manual measurements.

# Examples

```julia
# Importing the mtg from the github repo:
mtg = read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/A1B1.mtg"))

delete_nodes!(mtg, scale = 2) # Will remove all nodes of scale 2

# Delete the leaves:
delete_nodes!(mtg, symbol = "Leaf")
# Delete the leaves and internodes:
delete_nodes!(mtg, symbol = ("Leaf","Internode"))

# Make the mtg match field measurements made only at branching points for the scales 1 + 2:
mtg = delete_nodes!(mtg, filter_fun = is_segment!, scale = 2)
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
        # First we apply the algorithm recursively on the children:
        for chnode in ordered_children(node)
            delete_nodes!_(chnode, scale, symbol, link, all, filter_fun)
        end
    end

    # Then we work on the node itself. This ensures that its children will not be deleted
    # afterwards (the deletion is acropetal, i.e. from leaves to root)

    # Is there any filter happening for the current node? (true is deleted):
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        node = delete_node!(node)
        # Don't go further if all == false
all ? nothing : return nothing
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
            root_attrs = Dict(
                :symbols => node[:symbols],
                :scales => node[:scales],
                :description => node[:description]
            )

            append!(chnode, root_attrs)

            node_return = chnode
        else
            error("Can't delete the root node if it has several children")
        end
    else
        parent_node = node.parent

        # Delete the node as child of his parent:
        pop!(parent_node.children, node.name)

        if !isleaf(node)
            # We re-parent the children to the parent of the node.
            for chnode in ordered_children(node)
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
