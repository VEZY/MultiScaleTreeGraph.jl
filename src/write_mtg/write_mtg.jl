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
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
write_mtg("test.mtg",mtg)
```
"""
function write_mtg(file, mtg; kwargs...)
    kwargs = (; kwargs...)

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
        # Handle special case of Scene class, which is written as "$" in the mtg file:
        classes_scene = copy(classes)
        replace!(classes_scene.SYMBOL, "Scene" => "\$")
        writedlm(io, eachrow(classes_scene))

        # Description section:
        writedlm(io, [""])
        writedlm(io, ["DESCRIPTION:"])

        # Description is optional
        if description !== nothing
            # Reformat the RIGHT column to match how it is written in an MTG
            right = fill("", size(description)[1])

            for i in eachindex(description.RIGHT)
                right = join(description.RIGHT[i], ",")
            end
            description[!, :RIGHT] .= right

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
        writedlm(io, reshape(mtg_colnames, (1, :)), quotes=false)
        for i in eachindex(mtg_df["mtg_print"])
            writedlm(io, reshape([mtg_df[k][i] for k in keys(mtg_df)], (1, :)), quotes=false)
        end
    end
end

function paste_node_mtg(mtg, features)

    # Get the leading tabulations for each node (i.e. the column of the node)
    lead = Int[]
    parent_ref = String[]
    print_node = String[]
    get_node_printing!(mtg, lead, parent_ref, print_node)

    max_tabs = maximum(lead)

    # Get the attributes for each node:
    attributes = OrderedDict{String,Vector{Any}}()

    attributes["mtg_print"] = string.(
        # Add the leading tabulations:
        repeat.("\t", lead),
        # Add the "^" keyword before mtg print in case we refer to the column above:
        parent_ref,
        # Add the mtg printing (e.g. "/Axis0"):
        print_node,
        # Add the trailing tabulations:
        repeat.("\t", max_tabs .- lead)
    )

    for var in string.(features.NAME)
        push!(attributes, var => descendants(mtg, var, self=true))
    end

    # Build the "ENTITY-CODE" column with necessary "^", leading and trailing tabs
    for (key, val) in attributes
        # If the attribute is a date, write it in the day/month/year format:
        attr_feature = filter(x -> string(x.NAME) == key, features)

        if size(attr_feature)[1] == 1 && attr_feature[1, 2] == "DD/MM/YY"
            replace!(x -> isnothing(x) ? x : format(x, dateformat"d/m/Y"), val)
        end

        # Replacing all nothing values by an empty string:
        replace!(val, nothing => "")
    end
    # Renaming first column and adding tabs:
    mtg_colnames = collect(keys(attributes))
    mtg_colnames[1] = string("ENTITY-CODE", repeat("\t", max_tabs))
    return attributes, mtg_colnames
end

"""
    get_node_printing!(node, lead, ref, print_node, node_lead=0, node_ref="")

Get the number of tabulation (in `lead`) and the "^" (in `ref`) used as a prefix for the node when writting it to a file, based on the
topology of its parent. Also get the node printing (*e.g.* "/Axis0") in `print_node`.

The function modifies the `lead`, `ref` and `print_node` vectors in place.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
lead = Int[]
ref = String[]
get_node_printing!(mtg, lead, ref)

lead
ref
```
"""
function get_node_printing!(node, lead, ref, print_node, node_lead=0, node_ref="")
    push!(lead, node_lead)
    push!(ref, node_ref)

    index = node_mtg(node).index == -9999 ? "" : string(node_mtg(node).index)
    push!(print_node, node_mtg(node).link * symbol(node) * index)

    if !isleaf(node)
        chnodes = children(node)
        n_children = length(chnodes)
        for (i, chnode) in enumerate(chnodes)
            # If the node has several children, the lead of the children is automatically increased by 1 for all nodes except the last one:
            if length(chnodes) > 1 && i != n_children
                chnode_lead = node_lead + 1
                node_ref = "" # We refer to the parent node in the column on the left in this case
            else
                chnode_lead = node_lead
                node_ref = "^" # We refer to the parent node in the same column in this case
            end

            get_node_printing!(chnode, lead, ref, print_node, chnode_lead, node_ref)
        end
    end
end