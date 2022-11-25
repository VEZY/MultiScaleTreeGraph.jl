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
- `child_link_fun = new_child_link`: a function that takes the child node of a deleted node
as input and returns its new link (see details).

# Notes

1. The function is acropetal, meaning it will apply the deletion from leaves to the root to ensure
that one pass is enough and we don't repeat the process of visiting already visited children.
2. The function does not do anything fancy, it let the user take care of its own rules when
deleting nodes. So if you delete a branching node, the whole subtree will be modified and take
the link of the children. This process is left to the user becaue it highly depends on the mtg
structure.
3. The package provides some pre-made functions for filtering. See for example [`is_segment!`](@ref)
to re-compute the mtg at a given scale to have only nodes at branching points. This is often used
to match automatic reconstructions from e.g. LiDAR point cloud with manual measurements.
4. The default function used for `child_link_fun` is [`new_child_link`](@ref), which tries to be
clever considering the parent and child links. See its help page for more information. If the
link shouldn't be modified, use the following function instead:
```julia
node -> node.MTG.link
```

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","A1B1.mtg")
mtg = read_mtg(file)

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
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    filter_fun=nothing,
    child_link_fun=new_child_link
)

    # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale=scale, symbol=symbol, link=link)
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        node = delete_node!(node)
        # Don't go further if all == false
        all ? nothing : return nothing
    end

    delete_nodes!_(node, scale, symbol, link, all, filter_fun, child_link_fun)

    return node
end


function delete_nodes!_(node, scale, symbol, link, all, filter_fun, child_link_fun)
    if !isleaf(node)
        # First we apply the algorithm recursively on the children:
        for chnode in children(node)
            delete_nodes!_(chnode, scale, symbol, link, all, filter_fun, child_link_fun)
        end
    end

    # Then we work on the node itself. This ensures that its children will not be deleted
    # afterwards (the deletion is acropetal, i.e. from leaves to root)

    # Is there any filter happening for the current node? (true is deleted):
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        delete_node!(node, child_link_fun=child_link_fun)
    end
end

"""
delete_node!(node; child_link_fun = new_child_link)

Delete a node and re-parent the children to its own parent.

If the node is a root and it has only one child, the child becomes the root, if it has
several children, it returns an error.

`child_link_fun` is a function that takes the child node of a deleted node as input and
returns its new link. The default function is [`new_child_link`](@ref), which tries to be
clever considering the parent and child links. See its help page for more information. If the
link shouldn't be modified, use the following function instead:

```julia
node -> node.MTG.link
```

The function returns the parent node (or the new root if the node is a root)
"""
function delete_node!(node; child_link_fun=new_child_link)
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

            chnode.MTG.link = child_link_fun(chnode)

            node_return = chnode
        else
            error("Can't delete the root node if it has several children")
        end
    else
        parent_node = parent(node)

        if !isleaf(node)
            # We re-parent the children to the parent of the node.
            for chnode in children(node)
                # Updating the link of the children:
                chnode.MTG.link = child_link_fun(chnode)
                addchild!(parent_node, chnode; force=true)
            end
        end

        # Delete the node as child of his parent:
        deleteat!(parent_node.children, findfirst(x -> x.id == node.id, parent_node.children))
        node_return = parent_node
    end

    node.parent = nothing
    node.children = nothing
    node = nothing

    return node_return
end

"""
    new_child_link(node)

Compute the new link of the child node when deleting a parent node. The rule is to give the child
node link of its parent node that is deleted, except when the parent was following its own
parent.

The node given as input is the child node here.

The rule is summarized in the following table:

|Deleted node link|Child node link|New child node link|warning|
|:---------------:|:-------------:|:-----------------:|:-----:|
|/                |/              |/                  |       |
|/                |+              |+                  |yes (1)|
|/                |<              |/                  |       |
|+                |/              |/                  |yes (2)|
|+                |+              |+                  |       |
|+                |<              |+                  |       |
|<                |/              |/                  |       |
|<                |+              |+                  |       |
|<                |<              |<                  |       |

The warnings happens when there is no satisfactory way to handle the new link, *i.e.* when
mixing branching and change in scale.

Note that in the case (1) of the warning the first child only takes the "/" link, the others
keep their links.
"""
function new_child_link(node)

    deleted_link = parent(node).MTG.link
    child_link = node.MTG.link

    if deleted_link == "+" && child_link == "/"
        new_child_link = child_link
        @warn join(
            [
            "Scale of the child node decomposed but its deleted parent was branching.",
            " Keep decomposition, please check if the branching is still correct."
        ]
        ) deleted_link child_link new_child_link
    elseif deleted_link == "+" && child_link == "<"
        new_child_link = deleted_link
    elseif deleted_link == "/" && child_link == "+"
        new_child_link = child_link
        @warn join(
            [
            "Scale of the child node branched but its deleted parent was decomposing.",
            " Keep branching, please check if the decomposition is still correct."
        ]
        ) deleted_link child_link new_child_link
    elseif deleted_link == "/" && child_link == "<"
        new_child_link = deleted_link
    else
        new_child_link = child_link
    end

    return new_child_link
end
