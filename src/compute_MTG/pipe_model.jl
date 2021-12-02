"""
    pipe_model!(node, root_value)

Computes the cross-section of `node` considering its topological environment and the
cross-section at the root node (`root_value`).

The pipe model helps compute the cross-section of the nodes in an mtg by following
the rule that the sum of the cross-sections of the children of a node is equal to
the node cross-section.

The implementation uses the following algorithm:

First, check how many children a node has.

If it has one child only, the child cross-section is equal to the node cross-section.

If more children, the node cross-section is shared between the children according to the number
of leaf nodes their subtree has, *i.e.* the total number of terminal nodes of their subtree.

Please call [`clean_cache!`](@ref) after using `pipe_model!` because it creates
temporary variables.
"""
function pipe_model!(node, root_value)
    if isroot(node)
        node[:_cache_a7118a60b2a624134bf9eac2d64f2bb32798626a] = root_value
        return root_value
    else
        parent_cross_section = node.parent[:_cache_a7118a60b2a624134bf9eac2d64f2bb32798626a]
        nleaf_node = nleaves(node)

        nleaf_proportion_siblings = nleaf_node / (sum(nleaves_siblings!(node)) + nleaf_node)

        node[:_cache_a7118a60b2a624134bf9eac2d64f2bb32798626a] = parent_cross_section * nleaf_proportion_siblings

        return node[:_cache_a7118a60b2a624134bf9eac2d64f2bb32798626a]
    end
end


# Don't forget to compute :var_name at all scales first!
# You can put all the :var_name values to be recomputed at a value < threshold_value.

"""
    pipe_model!(node, var_name, threshold_value; allow_missing = false)

Same than `pipe_model!` but uses another variable as the reference down until a threshold
value. This is used for example in the case of LiDAR measurements, where we know the
cross-section (`:var_name`) is well measured down to *e.g.* 2-3cm of diameter, but should be
computed below.

This function allows to compute the cross-section using the pipe model **only** for some
sub-trees with values of `:var_name <= threshold_value`.

# Arguments

- `node`: the mtg, or a specific node at which to start from.
- `var_name`: the name of the cross-section attribute name in the nodes
- `threshold_value`: the threshold defining the value below which the cross-section will be
re-computed using the pipe model instead of using `var_name`.
- `allow_missing=false`: Allow missing values for `var_name`, in which case the cross-section is
recomputed using the pipe model. Please use this option only if you know why.

# Details

The node cross-section is partitioned from parent to children according to the number of leaves
(*i.e.* terminal nodes) each child subtree has, unless one or more children has a
`:var_name > threshold_value`. In this case the shared cross-section is the one from the
parent minus the one of these nodes for which we simply use the measured value. The
cross-section of the siblings with `:var_name <= threshold_value` will be shared as usual
using their number of leaves. If `:var_name` of the siblings are higher than the parent value,
the cross-section of the node is computed only using the number of leaves as it should not
be bigger.

# Word of caution

Some tips when using this function:

- User must ensure that `:var_name` has a value for all nodes in the mtg before calling this
version of `pipe_model!`, unless `allow_missing=true`.

- Nodes with untrusted values should be
set to a value below the threshold value to make `pipe_model!` recompute them.
"""
function pipe_model!(node, var_name, threshold_value; allow_missing = false)

    if node[var_name] === nothing && !allow_missing
        error(
            "$var_name not found (`== nothing`) in node `$(node.name)` (id: $(node.id)). ",
            "Please make sure all nodes have a value, or use `allow_missing = true`."
        )
    end

    if isroot(node) || (node[var_name] !== nothing && node[var_name] > threshold_value)
        # The node cross-section is higher thant the threshold, we use its value
        node[:_cache_522f54c893bc239eaf0e590bda58d106f91df45d] = node[var_name]
    else
        # The parent cross-section (to share between children):
        cross_section_to_share = node.parent[:_cache_522f54c893bc239eaf0e590bda58d106f91df45d]

        node_siblings = siblings(node)

        if node_siblings === nothing || length(node_siblings) == 0
            # Test whether there are any siblings first, if not, return the parent value:
            node[:_cache_522f54c893bc239eaf0e590bda58d106f91df45d] = cross_section_to_share
        else

            cross_section_siblings = [i[var_name] for i in node_siblings]
            cross_section_siblings_no_nothing = filter(x -> x !== nothing, cross_section_siblings)

            if length(cross_section_siblings_no_nothing) > 0
                sum_cross_section_siblings = sum(cross_section_siblings_no_nothing)
            else
                sum_cross_section_siblings = 0.0
            end

            nleaf_node = nleaves(node)
            nleaves_sibl = nleaves_siblings!(node)

            # To compute how much cross-section has to be allocated to the current node, we
            # first compute how much remains after removing the measured cross-section from
            # the siblings with a cross-section > threshold_value. Then the remaining
            # cross-section is shared between all other siblings with a cross-section <= threshold_value
            # for which it is allocated respective to their number of terminal nodes (i.e. leaves):
            nleaves_others = 0
            for (i, val) in enumerate(cross_section_siblings)
                if val === nothing
                    if allow_missing
                        val = 0
                    else
                        error(
                            "$var_name not found (`== nothing`) in `$(node_siblings[i].name)`",
                            "(id: $(node_siblings[i].id)). ",
                            "Please make sure all nodes have a value, or use `allow_missing = true`."
                        )
                    end
                end

                if val > threshold_value && cross_section_to_share > val && sum_cross_section_siblings < val
                    # Here we already know the cross-section of the sibling node, so we
                    # remove its cross-section of the shareable pool, unless its cross-section
                    # is bigger than the cross-section of the parent, or also if the sum of the
                    # cross-sections of the siblings is bigger than the parent. In this case
                    # we go back to using the number of leaves because else it would give a
                    # negative value for the current node
                    cross_section_to_share -= val
                else
                    # For the others, we cumulate their number of leaves
                    nleaves_others += nleaves_sibl[i]
                end
            end

            # The cross-section remaining to share between nodes with var <= threshold_value
            # is allocated according to their proportion of leaves:
            nleaf_proportion_siblings = nleaf_node / (nleaves_others + nleaf_node)

            node[:_cache_522f54c893bc239eaf0e590bda58d106f91df45d] = cross_section_to_share * nleaf_proportion_siblings
        end
    end

    return node[:_cache_522f54c893bc239eaf0e590bda58d106f91df45d]
end
