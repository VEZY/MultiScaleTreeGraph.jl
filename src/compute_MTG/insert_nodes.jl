"""
insert_nodes!(mtg::Node,template,<keyword arguments>)

Insert new nodes in the mtg following filters rules. It is important to note that it always
return the root node, whether it is the old one or a new inserted one, so the user is
encouraged to assign the results to an object.

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `template::Node`: A template node used for all inserted nodes.

## Keyword Arguments (filters)

- `scale = nothing`: The scale at which to insert. Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol at which to insert. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with the previous node at which to insert. Usually a Tuple-alike of Char.
- `all::Bool = true`: Continue after the first insertion (`true`), or stop.
- `filter_fun = nothing`: Any function taking a node as input, e.g. [`isleaf`](@ref) to decide
where to insert.

# Notes

1. The nodes are always inserted before a filtered node because we can't decide if a new node would
be considered a new child or a new parent of the children otherwise.
1. The function does not do anything fancy, it let the user take care of its own rules when
inserting nodes. So if you insert a branching node, the whole subtree will be branched.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","A1B1.mtg")
mtg = read_mtg(file)

mtg = insert_nodes!(mtg, MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1), scale = 2) # Will insert new nodes before all scale 2
mtg
```
"""
function insert_nodes!(
    node,
    template;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    filter_fun = nothing
    )

    max_id = [parse(Int, max_name(node)[6:end])]
    # # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale = scale, symbol = symbol, link = link)
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        node = insert_node!(node, template, max_id)
        # Don't go further if all == false
        all ? nothing : return nothing
    end

    insert_nodes!_(node, template, max_id, scale, symbol, link, all, filter_fun)

    # Always return the root, whether it is the same one or a new one
    return getroot(node)
end

function insert_nodes!_(node, template, max_id, scale, symbol, link, all, filter_fun)

    # Is there any filter happening for the current node? (true is inserted):
    filtered = is_filtered(node, scale, symbol, link, filter_fun)

    if filtered
        node = insert_node!(node, template, max_id)
        # Don't go further if all == false
        all ? true : return node
    end

    if !isleaf(node)
        # First we apply the algorithm recursively on the children:
        for chnode in ordered_children(node)
            insert_nodes!_(chnode, template, max_id, scale, symbol, link, all, filter_fun)
        end
    end
    return node
end

"""
    insert_node!(node, template, max_id)

Insert a node as the new parent of node.

# Arguments

- `node::Node`: The node at which to insert a node as a parent.
- `template::Node`: A template node used as the inserted nodes.
- `max_id::Vector{Int64}`: The maximum id of the mtg as a vector of 1 value, used to compute
the name of the inserted node. It is incremented in the function.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","A1B1.mtg")
mtg = read_mtg(file)

template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
max_id = parse(Int, MultiScaleTreeGraph.max_name(mtg)[6:end])
mtg = insert_node!(mtg[1][1], template, max_id)
mtg
```
"""
function insert_node!(node, template, max_id)

    # Using the template MTG to create the new one (except for the name that we increment):
    new_node_MTG = typeof(node.MTG)(template.link, template.symbol, template.index, template.scale)

    max_id[1] += 1

    if isroot(node)

        new_node = Node(
            join(["node_", max_id[1]]),
            nothing,
            Dict{String,Node}(node.name => node),
            nothing,
            new_node_MTG,
            typeof(node.attributes)() # No attributes at the moment
        )

        # Add to the new root the mandatory root attributes:
        root_attrs = Dict(
            :symbols => node[:symbols],
            :scales => node[:scales],
            :description => node[:description]
        )

        append!(new_node, root_attrs)

        # Add the new root node as the parent of the previous one:
        node.parent = new_node
    else
        new_node = Node(
            join(["node_", max_id[1]]),
            node.parent,
            Dict{String,Node}(node.name => node),
            nothing,
            new_node_MTG,
            typeof(node.attributes)() # No attributes at the moment
        )

        # Add the new node to the parent:
        pop!(node.parent.children, node.name)
        push!(node.parent.children, new_node.name => new_node)

        # Add the new node as the parent of the previous one:
        node.parent = new_node
    end

    return node
end
