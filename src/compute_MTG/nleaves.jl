nleaves!(node) = length(descendants!(node, :xxx; filter_fun = isleaf)) + 1
nleaves(node) = length(descendants(node, :xxx; filter_fun = isleaf)) + 1

"""
    nleaves(node)
    nleaves!(node)

Get the total number of leaves a node is bearing, *i.e.* the number of terminal nodes.
`nleaves!` is faster than `nleaves` but cache the results in a variable so it uses more
memory. Please use [`clean_cache!`](@ref) after calling `nleaves!` to clean the temporary
variables.

# Examples

```julia
# Importing the mtg from the github repo:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

nleaves!(mtg)

clean_cache!(mtg)
```
"""
nleaves, nleaves!


"""
    nleaves_siblings!(x)

Compute how many leaves the siblings of node x bear.

Please call [`clean_cache!`](@ref) after using `nleaves_siblings!` because it creates
temporary variables.
"""
function nleaves_siblings!(x)

    node_siblings = siblings(x)

    if node_siblings === nothing || length(node_siblings) == 0
        # Test whether there are any siblings first:
        return 0
    end

    n_leaf_siblings = [nleaves!(i) for i in node_siblings]
    # NB: `:xxx` can be replaced by anything else, it does not matter if the variable exist or not
    return n_leaf_siblings
end
