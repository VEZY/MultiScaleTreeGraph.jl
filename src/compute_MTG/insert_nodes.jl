"""
    insert_parents!(node::Node, template, <keyword arguments>)
    insert_generations!(node::Node, template, <keyword arguments>)
    insert_children!(node::Node, template, <keyword arguments>)
    insert_siblings!(node::Node, template, <keyword arguments>)

Insert new nodes in the mtg following filters rules. It is important to note the function
always return the root node, whether it is the old one or a new inserted one, so the user is
encouraged to assign the results to an object.

Insert nodes programmatically in an MTG as:
- new parents of the filtered nodes: `insert_parents!`
- new children of the filtered nodes: `insert_children!`
- new siblings of the filtered node: `insert_siblings!`
- new children of the filtered nodes, but the previous children of the filtered node become
the children of the inserted node: `insert_generations!`

# Arguments

## Mandatory arguments

- `node::Node`: The node to start at.
- `template`:
    - A template [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref) used for the inserted node,
    - A NamedTuple with values for link, symbol, index, and scale
    - Or a function taking the node as input and returning said template
- `attr`: Attributes for the node. Similarly to `template`, can be:
    - An attribute of the same type as of node attributes (*e.g.* a Dict or a NamedTuple)
    - A function to compute new attributes (should also return same type for the attributes)

## Keyword Arguments (filters)

- `scale = nothing`: The scale at which to insert. Usually a Tuple-alike of integers.
- `symbol = nothing`: The symbol at which to insert. Usually a Tuple-alike of Strings.
- `link = nothing`: The link with at which to insert. Usually a Tuple-alike of Char.
- `all::Bool = true`: Continue after the first insertion (`true`), or stop.
- `filter_fun = nothing`: Any function taking a node as input, e.g. [`isleaf`](@ref) to decide
on which node the insertion will be based on.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# Insert new Shoot nodes before all scale 2 nodes:
mtg = insert_parents!(mtg, MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1), scale = 2)

mtg
```
"""
insert_parents!, insert_generations!, insert_children!, insert_siblings!

function insert_parents!(
    node::Node{N,A},
    template,
    attr=A();
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    filter_fun=nothing
) where {N<:AbstractNodeMTG,A}

    insert_nodes!(
        node, template, insert_parent!, attr;
        scale=scale, symbol=symbol, link=link, all=all, filter_fun=filter_fun
    )
end

function insert_generations!(
    node::Node{N,A},
    template,
    attr=A();
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    filter_fun=nothing
) where {N<:AbstractNodeMTG,A}

    insert_nodes!(
        node, template, insert_generation!, attr;
        scale=scale, symbol=symbol, link=link, all=all, filter_fun=filter_fun
    )
end

function insert_children!(
    node::Node{N,A},
    template,
    attr=A();
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    filter_fun=nothing
) where {N<:AbstractNodeMTG,A}
    insert_nodes!(
        node, template, insert_child!, attr;
        scale=scale, symbol=symbol, link=link, all=all, filter_fun=filter_fun
    )
end

function insert_siblings!(
    node::Node{N,A},
    template,
    attr=A();
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true,
    filter_fun=nothing
) where {N<:AbstractNodeMTG,A}
    insert_nodes!(
        node, template, insert_sibling!, attr;
        scale=scale, symbol=symbol, link=link, all=all, filter_fun=filter_fun
    )
end

"""
Actual workhorse of insert_parents!, insert_generations!, insert_children!, insert_siblings!
"""
function insert_nodes!(
    node::Node{N,A},
    template,
    fn,
    attr=A();
    scale=nothing,
    symbol=nothing,
    link=nothing,
    all::Bool=true, # like continue in the R package, but actually the opposite
    filter_fun=nothing
) where {N<:AbstractNodeMTG,A}

    max_node_id = [max_id(node)]
    # # Check the filters once, and then compute the descendants recursively using `descendants_`
    check_filters(node, scale=scale, symbol=symbol, link=link)

    if isempty(methods(attr)) && !isa(attr, Function)
        # Attr is not given as a function, making it a function
        attr_fun = x -> attr
    else
        attr_fun = attr
    end

    insert_nodes!_(node, template, fn, attr_fun, max_node_id, scale, symbol, link, all, filter_fun)

    # Always return the root, whether it is the same one or a new one
    return get_root(node)
end

function insert_nodes!_(node, template, fn, attr_fun, max_node_id, scale, symbol, link, all, filter_fun)

    # Is there any filter happening for the current node? (true is inserted):
    keep = is_filtered(node, scale, symbol, link, filter_fun)

    # Only go to the children if we keep the current node and don't want all values:
    if !isleaf(node) && (all || !keep)
        # First we apply the algorithm recursively on the children:
        chnodes = children(node)
        nchildren = length(chnodes)
        #? Note: we don't use `for chnode in chnodes` because it may grow dynamically during traversal, *e.g.* when inserting siblings
        for chnode in chnodes[1:nchildren]
            insert_nodes!_(chnode, template, fn, attr_fun, max_node_id, scale, symbol, link, all, filter_fun)
        end
    end

    # We apply the function *after* visiting the children to be sure we don't add nodes indefinitely:
    if keep
        node = fn(node, template, attr_fun, max_node_id)
    end

    return node
end


"""
    new_node_MTG(node, template<:Union{NodeMTG,MutableNodeMTG,NamedTuple,MutableNamedTuple})
    new_node_MTG(node, fn)

Returns a new NodeMTG matching the one used in node (either `NodeMTG` or `MutableNodeMTG`)
based on a template, or on a function that takes a node as input and return said template.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# using a NodeMTG as a template:
MultiScaleTreeGraph.new_node_MTG(mtg, NodeMTG("/", "Leaf", 1, 2))
# Note that it returns a MutableNodeMTG because `mtg` is using this type instead of a `NodeMTG`

# using a NamedTuple as a template:
MultiScaleTreeGraph.new_node_MTG(mtg, (link = "/", symbol = "Leaf", index = 1, scale = 2))

# using a function that returns a template based on the first child of the node:
MultiScaleTreeGraph.new_node_MTG(
    mtg,
    x -> (
            link = link(x[1]),
            symbol = symbol(x[1]),
            index = index(x[1]),
            scale = scale(x[1]))
        )
```
"""
function new_node_MTG(node, fn)
    new_node_MTG(node, fn(node))
end

function new_node_MTG(node::Node{N,A}, template::T) where {N<:AbstractNodeMTG,A,T<:Union{NodeMTG,MutableNodeMTG,NamedTuple,MutableNamedTuple}}
    t = deepcopy(template)
    N(t.link, t.symbol, t.index, t.scale)
end

"""
    insert_parent!(node, template, attr_fun = node -> typeof(node_attributes(node))(), max_id = [max_id(node)])
    insert_generation!(node, template, attr_fun = node -> typeof(node_attributes(node))(), max_id = [max_id(node)])
    insert_child!(node, template, attr_fun = node -> typeof(node_attributes(node))(), max_id = [max_id(node)])
    insert_sibling!(node, template, attr_fun = node -> typeof(node_attributes(node))(), max_id = [max_id(node)])

Insert a node in an MTG as:

- a new parent of node: `insert_parent!`
- a new child of node: `insert_child!`
- a new sibling of node: `insert_sibling!`
- a new child of node, but the children of node become the children of the inserted node:
`insert_generation!`

# Arguments

- `node::Node`: The node from which to insert a node (as its parent, child or sibling).
- `template`:
    - A template [`NodeMTG`](@ref) or [`MutableNodeMTG`](@ref) used for the inserted node,
    - A NamedTuple with values for link, symbol, index, and scale
    - Or a function taking the node as input and returning said template
- `attr_fun`: A function to compute new attributes based on the filtered node. Must return
attribute values of the same type as the one used in other nodes from the MTG (*e.g.* Dict or
NamedTuple). If you just need to pass attributes values to a node use `x -> your_values`.
- `max_id::Vector{Int64}`: The maximum id of the nodes in the MTG as a vector of length one.
Used to compute the name of the inserted node. It is incremented in the function, and use by
default the value from [`max_id`](@ref).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
insert_parent!(mtg[1][1], template)
mtg

# The template can be a function that returns the template. For example a dummy example would
# be a function that uses the NodeMTG of the first child of the node:

insert_parent!(
    mtg[1][1],
    node -> (
        link = link(node[1]),
        symbol = symbol(node[1]),
        index = index(node[1]),
        scale = scale(node[1]))
    )
)
```
"""
insert_parent!, insert_generation!, insert_child!, insert_sibling!

function insert_parent!(node::Node{N,A}, template, attr_fun=node -> A(), maxid=[max_id(node)]) where {N<:AbstractNodeMTG,A}

    maxid[1] += 1

    if isroot(node)

        new_node = Node(
            join(["node_", maxid[1]]),
            maxid[1],
            nothing,
            Node{N,A}[node],
            new_node_MTG(node, template),
            copy(attr_fun(node)),
            Dict{String,Vector{Node{N,A}}}()
        )

        # Add to the new root the mandatory root attributes:
        root_attrs = Dict(
            :symbols => node[:symbols],
            :scales => node[:scales],
            :description => node[:description]
        )

        append!(new_node, root_attrs)

        # Add the new root node as the parent of the previous one:
        reparent!(node, new_node)
    else
        new_node = Node(
            join(["node_", maxid[1]]),
            maxid[1],
            parent(node),
            Node{N,A}[node],
            new_node_MTG(node, template),
            copy(attr_fun(node)),
            Dict{String,Vector{Node{N,A}}}()
        )

        # Add the new node to the parent:
        deleteat!(children(parent(node)), findfirst(x -> node_id(x) == node_id(node), children(parent(node))))
        #? There is also popat! that is equivalent in computation time (I benchmarked it) but 
        #? it requires julia >= v1.5

        push!(children(parent(node)), new_node)

        # Add the new node as the parent of the previous one:
        reparent!(node, new_node)
    end

    return node
end


function insert_child!(node::Node{N,A}, template, attr_fun=node -> A(), maxid=[max_id(node)]) where {N<:AbstractNodeMTG,A}

    maxid[1] += 1

    addchild!(node, maxid[1], new_node_MTG(node, template), attr_fun(node))

    return node
end


function insert_sibling!(node::Node{N,A}, template, attr_fun=node -> A(), maxid=[max_id(node)]) where {N<:AbstractNodeMTG,A}

    maxid[1] += 1

    new_node = Node(
        join(["node_", maxid[1]]),
        maxid[1],
        parent(node),
        Vector{Node{N,A}}(),
        new_node_MTG(node, template),
        copy(attr_fun(node)),
        Dict{String,Vector{Node{N,A}}}()
    )

    # Add the new node to the children of the parent node:
    push!(children(parent(node)), new_node)

    return node
end

function insert_generation!(node::Node{N,A}, template, attr_fun=node -> A(), maxid=[max_id(node)]) where {N<:AbstractNodeMTG,A}

    maxid[1] += 1

    new_node = Node(
        join(["node_", maxid[1]]),
        maxid[1],
        node,
        children(node),
        new_node_MTG(node, template),
        copy(attr_fun(node)),
        Dict{String,Vector{Node{N,A}}}()
    )

    # Add the new node as the only child of the node:
    rechildren!(node, Node{N,A}[new_node])

    return node
end

@deprecate insert_node!(node, template, maxid) insert_parent!(node, template, maxid)
