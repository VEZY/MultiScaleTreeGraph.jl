function write_mtg(file, mtg, classes, description, features)

    open(file, "w") do io
        # Code section:
        writedlm(io, ["CODE:" "FORM-A"])

        # Classes section:
        writedlm(io, [""])
        writedlm(io, ["CLASSES:"])
        writedlm(io, reshape(names(classes), (1, :)))
        writedlm(io, eachrow(classes))

        # Description section:
        writedlm(io, [""])
        writedlm(io, ["DESCRIPTION:"])
        writedlm(io, reshape(names(description), (1, :)))

        writedlm(io, eachrow(description))

        # Features section:
        writedlm(io, [""])
        writedlm(io, ["FEATURES:"])
        writedlm(io, reshape(names(features), (1, :)))
        writedlm(io, eachrow(features))

        # MTG section:
        writedlm(io, [""])
        writedlm(io, ["MTG:"])
        mtg_df, mtg_colnames = paste_node_mtg(mtg, features)
        writedlm(io, reshape(mtg_colnames, (1, :)), quotes = false)
        for i in 1:length(mtg_df["mtg_print"])
            writedlm(io, reshape([mtg_df[k][i] for k in keys(mtg_df)], (1, :)), quotes = false)
        end
    end
end

function paste_node_mtg(mtg, features)
    @mutate_mtg!(mtg, lead = get_leading_tabs(node), mtg_print = paste_mtg_node(node))
    attributes = Dict_attrs(mtg, ["mtg_print",features.NAME...,"lead"])
    max_tabs = maximum(attributes["lead"])
    attributes["mtg_print"] = string.(
        repeat.("\t", attributes["lead"]),
        attributes["mtg_print"],
        repeat.("\t", max_tabs .- attributes["lead"])
    )
    # Remove the lead column now that we used it:
    pop!(attributes, "lead")

    # Array{Float64,1}()
    # attributes["mtg_print"] =
    # Replacing all nothing values by tabulations:
    for (key, val) in attributes
        replace!(val, nothing => "")
    end
    # Renaming first column and adding tabs:
    mtg_colnames = collect(keys(attributes))
    mtg_colnames[1] = string("ENTITY-CODE", repeat("\t", max_tabs))
    return attributes, mtg_colnames
end

"""
    paste_mtg_node(node)

Parse the mtg node as it should appear in the mtg file.
"""
function paste_mtg_node(node)
    node.MTG.link * node.MTG.symbol * string(node.MTG.index)
end

"""
    get_leading_tabs(node)

Get the number of tabulation the node should have when writting it to a file based on the
topology of its parent.
"""
function get_leading_tabs(node)
    if isroot(node)
        return 0
    else
        node.MTG.link == '+' ? node.parent[:lead] + 1 : node.parent[:lead]
    end
end


function Dict_attrs(mtg, attrs)
    df = OrderedDict()
    for var in attrs
        push!(df, var => descendants(mtg, var, self = true))
    end
    df
end
