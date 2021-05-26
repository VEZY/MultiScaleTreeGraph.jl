"""
    write_mtg(file, mtg; kwargs...)
    write_mtg(file, mtg, classes, description, features)

Write an mtg file to disk.

# Arguments

- `file::String`: The path to the MTG file to write.
- `mtg`: the mtg
- `classes`: the classes section
- `description`: the description section
- `features`: the features section

# Note

kwargs can be used to give zero, one or two of the classes, description and features
instead of all. In this case the missing ones are recomputed using [`get_classes`](@ref),
[`get_features`](@ref) or [`get_description`](@ref).

# Examples

```julia
file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");
mtg = read_mtg(file);
write_mtg("test.mtg",mtg)
```
"""
function write_mtg(file, mtg; kwargs...)
    kwargs = (;kwargs...)

    if !haskey(kwargs, :classes)
        classes = get_classes(mtg)
    end

    if !haskey(kwargs, :description)
        description = nothing
    end

    if !haskey(kwargs, :features)
        features = get_features(mtg)
    end

    write_mtg(file, mtg, classes, description, features)
end

function write_mtg(file, mtg, classes, description, features)
    @info "Writing mtg to $file"
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

        # Description is optional
        if description !== nothing
            # Reformat the RIGHT column to match how it is written in an MTG
            right = fill("", size(description)[1])

            for i in 1:length(description.RIGHT)
                right = join(description.RIGHT[i], ",")
            end
            description[!,:RIGHT] .= right

            writedlm(io, reshape(names(description), (1, :)))

            writedlm(io, eachrow(description))
        else
            writedlm(io, ["LEFT" "RIGHT" "RELTYPE" "MAX"])
        end

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
    @mutate_mtg!(
        mtg,
        lead = MTG.get_leading_tabs(node),
        mtg_print = MTG.paste_mtg_node(node),
        mtg_refer = MTG.get_reference(node)
    )

    attributes = Dict_attrs(mtg, ["mtg_print",features.NAME...,"lead","mtg_refer"])
    max_tabs = maximum(attributes["lead"])

    # Build the "ENTITY-CODE" column with necessary "^", leading and trailing tabs
    attributes["mtg_print"] = string.(
        # Add the leading tabulations:
        repeat.("\t", attributes["lead"]),
        # Add the "^" keyword before mtg print in case we refer to the column above:
        attributes["mtg_refer"],
        # Add the mtg printing (e.g. "/Axis0"):
        attributes["mtg_print"],
        # Add the trailing tabulations:
        repeat.("\t", max_tabs .- attributes["lead"])
    )
    # Remove the lead and mtg_refer columns now that we used it:
    pop!(attributes, "lead")
    pop!(attributes, "mtg_refer")

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
    index = node.MTG.index === nothing ? "" : string(node.MTG.index)
    node.MTG.link * node.MTG.symbol * index
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
        node.MTG.link == "+" ? node.parent[:lead] + 1 : node.parent[:lead]
    end
end


"""
    get_reference(node)

Get the preceding "^" keyword if needed, *i.e.* in case we refer to the parent node in the
same mtg file column.
"""
function get_reference(node)
    if isroot(node)
        return ""
    else
        node.MTG.link == "+" ? "" : "^"
    end
end

function Dict_attrs(mtg, attrs)
    df = OrderedDict()
    for var in attrs
        push!(df, var => descendants(mtg, var, self = true))
    end
    df
end
