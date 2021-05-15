function insert_nodes!(
    node,
    template;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    all::Bool = true, # like continue in the R package, but actually the opposite
    filter_fun = nothing
    )

    # max_id = parse(Int, max_name(mtg)[6:end])
    # # Check the filters once, and then compute the descendants recursively using `descendants_`
    # check_filters(node, scale = scale, symbol = symbol, link = link)
    # filtered = is_filtered(node, scale, symbol, link, filter_fun)

    # if filtered
    #     node = add_node!(node)
    #     # Don't go further if all == false
    #     all ? nothing : return nothing
    # end

    # insert_nodes!_(node, scale, symbol, link, all, filter_fun, template, max_id)

    return node
end

# Add a new node as a parent of the given node
function insert_node!(node, template, max_id)

    if !isroot(node)

        # Using the template MTG to create the new one (except for the name that we increment):
        new_node_MTG = typeof(node.MTG)(template.link, template.symbol, template.index, template.scale)

        new_node = Node(
            join(["node_", max_id + 1]),
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

        return new_node
    end

end
