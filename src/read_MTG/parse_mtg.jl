
"""
Parse MTG section

# Arguments
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`
- `classes::Array`: The class section data as returned by `parse_section!`
- `description::Array`: The description section data as returned by `parse_section!`
- `features::Array`: The features section data as returned by `parse_section!`
- `line::Array{Int64,1}`: The current line index (mutated). Must be given as line of `MTG:`
- `l::Array{String,1}`: the current line
- `attr_type::DataType`: the type of the structure used to hold the attributes

# Note

The buffered IO stream (`f`) should start at the line of the section.

# Returns

The parsed MTG section
"""
function parse_mtg!(f, classes, features, line, l, attr_type, mtg_type)
    l[1] = next_line!(f, line)

    if length(l[1]) == 0
        # If there are some blank lines, skip them until we find the "ENTITY-CODE" line
        while length(l[1]) == 0 && !eof(f)
            l[1] = next_line!(f, line)
        end
    end

    l_header = strip.(split(l[1], "\t"))

    if l_header[1] != "ENTITY-CODE" && l_header[1] != "TOPO"
        error("Neither ENTITY-CODE or TOPO were found in the MTG header at line: ", line)
    end

    columns = strip.(l_header[l_header.!=""][2:end]) # Remove leading and trailing whitespaces

    if features !== nothing
        if length(columns) != length(features.NAME)
            error(
                "Number of attributes in the ENTITY-CODE ($(length(columns))) is different than",
                " declared in the FEATURES section ($(length(features.NAME))).",
                " Please check that all columns names are declared in the ENTITY-CODE line (l.$(line[1]))"
            )
        end

        common_features = [i in features.NAME for i in columns]

        if !all(common_features)
            error("Unknown column in the ENTITY-CODE (column names) in MTG: ", join(columns[.!common_features], ", "))
        end

        if features.NAME != columns
            error("FEATURES names should be in the same order as column names in the ENTITY-CODE.")
        end
    end

    if length(columns) > 0
        attr_column_start = findfirst(x -> x == columns[1], l_header)
    else
        attr_column_start = 50
    end

    # Initializing the last column to which MTG was attached to keep track of which column
    # to attach the new MTG line
    max_columns = attr_column_start - 1
    last_node_column = zeros(Integer, max_columns)
    last_node_column[1] = 1
    node_id = [1]

    tree_dict = Dict{Int,Node}()

    # for i in Iterators.drop(eachindex(splitted_MTG), 1)
    # node_attributes(tree_dict[4])
    try
        while !eof(f)
            l[1] = next_line!(f, line; whitespace=false)
            length(l[1]) == 0 && continue # ignore empty line
            parse_line_to_node!(tree_dict, l, line, attr_column_start, last_node_column, node_id, attr_type, mtg_type, features, classes)
        end
    catch e
        error(
            "Error at line $line: ",
            hasproperty(e, :msg) ? e.msg : e,
        )
    end
    tree_dict[1]
end

"""
 # Parse MTG node

 Parse MTG nodes (called from `parse_mtg!()`)

# Arguments

- `l::String`: An MTG node (e.g. "/Individual0")

# Return

A parsed node in the form of a Dict of three:
 - the link
 - the symbol
 - and the index
"""
function parse_MTG_node(l)
    if l in ("^", "<.", "+.")
        return ((l, missing, missing))
    end

    link = string(l[1:1])

    # Match the index at the end of the string:
    stringmatch = match(r"[0-9]+$", l[2:end])
    if stringmatch === nothing
        symbol = string(l[2:end])
        index = -9999
    else
        symbol = l[2:stringmatch.offset]
        index = parse(Int, stringmatch.match)
    end
    # Use the index at which the MTG index was found to retreive the MTG symbol:
    (link, symbol, index)
end


"""

Parse MTG node attributes names, values and type

# Arguments
- `node_data::String`: A splitted mtg node data (attributes)
- `attr_type::DataType`: the type of the structure used to hold the attributes
- `features::DataFrame`: The features data.frame
- `attr_column_start::Integer`: The index of the column of the first attribute
- `line::Integer`: The current line of the mtg file
- `force::Bool`: force data reading even if errors are met during conversion ?

# Return

A list of attributes

"""
function parse_MTG_node_attr(node_data, attr_type, features, attr_column_start, line; force=false)

    if length(node_data) < attr_column_start
        return init_empty_attr(attr_type)
    end

    node_data_attr = node_data[attr_column_start:end]

    if length(node_data_attr) > size(features)[1]
        error("Found more columns for features in MTG than declared in the FEATURE section",
            ". Please check line ", line, " of the MTG:\n", join(node_data, "\t"))
    end

    node_attr = Dict{String,Any}(zip(features.NAME[eachindex(node_data_attr)],
        fill(missing, length(node_data_attr))))

    node_type = features.TYPE

    # node_data_attr is always read in order so names and types correspond to values in features
    for i in eachindex(node_data_attr)
        if node_data_attr[i] == "" || node_data_attr[i] == "NA"
            pop!(node_attr, features.NAME[i])
            continue
        end

        if node_type[i] == "INT"
            try
                node_attr[features.NAME[i]] = parse(Int, node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                        "with value $(node_data_attr[i]) into Integer.",
                        " Please check line ", line, " of the MTG:\n", join(node_data, "\t"))
                end
                pop!(node_attr, features.NAME[i])
            end
        elseif node_type[i] == "BOOLEAN"
            try
                node_attr[features.NAME[i]] = parse(Bool, node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                        "with value $(node_data_attr[i]) into Boolean.",
                        " Please check line ", line, " of the MTG:\n", join(node_data, "\t"))
                end
                pop!(node_attr, features.NAME[i])
            end
        elseif node_type[i] == "DD/MM/YY"
            try
                node_attr[features.NAME[i]] = Date(node_data_attr[i], dateformat"d/m/y")
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                        "with value $(node_data_attr[i]) into a date with format 'day/month/year'.",
                        " Please check line ", line, " of the MTG:\n", join(node_data, "\t"))
                end
                pop!(node_attr, features.NAME[i])
            end
        elseif node_type[i] == "REAL" || (node_type[i] == "ALPHA" && in(features.NAME[i], ("Width", "Length")))
            try
                node_attr[features.NAME[i]] = parse(Float64, node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                        "with value $(node_data_attr[i]) into Floating point number.",
                        " Please check line ", line, " of the MTG:\n", join(node_data, "\t"))
                end
                pop!(node_attr, features.NAME[i])
            end
        else
            node_attr[features.NAME[i]] = node_data_attr[i]
        end
    end

    node_attributes(attr_type, node_attr)
end

"""

Instantiate a `attr_type` struct with `node_attr` keys and values

# Arguments

- `attr_type::DataType`: the type of the structure used to hold the attributes
- `node_attr::String`: The node attributes as a `Dict`
"""
function node_attributes(attr_type::Type{T}, node_attr) where {T<:Union{NamedTuple,MutableNamedTuple}}
    attr_type{tuple(Symbol.(keys(node_attr))...)}(tuple(values(node_attr)...))
end

function node_attributes(attr_type::Type{T}, node_attr) where {T<:Union{AbstractDict}}
    Dict{Symbol,Any}(zip(Symbol.(keys(node_attr)), values(node_attr)))
end

# node_attributes for DataFrame
function node_attributes(::Type{DataFrame}, node_attr)
    DataFrame(node_attr)
end

function init_empty_attr(attr_type)
    attr_type()
end

function init_empty_attr(attr_type::Type{T}) where {T<:Union{AbstractDict}}
    attr_type{Symbol,Any}()
end


"""
    parse_line_to_node!(tree_dict, l, line, attr_column_start, node_id, attr_type, mtg_type, features,classes)

Parse a line of the MTG file to a node and add it to the tree dictionary.
It may also add several nodes if the line contains several MTG elements.
"""
function parse_line_to_node!(tree_dict, l, line, attr_column_start, last_node_column, node_id, attr_type, mtg_type, features, classes)

    splitted_MTG = split(l[1], "\t")
    node_column = findfirst(x -> length(x) > 0, splitted_MTG)
    node_data = splitted_MTG[node_column:end]

    if attr_column_start < node_column
        error(
            "Error in MTG at line ",
            line,
            ": Found an MTG node declared at column ",
            node_column, ", but attributes are declared to start at column ",
            attr_column_start, " in the ENTITY-CODE row. \nYou can probably fix the issue by adding",
            " some tabs after ENTITY-CODE (try to add ",
            node_column - attr_column_start + 1, " tabs)."
        )
    end

    node_attr_column_start = attr_column_start - node_column + 1
    node = split_MTG_elements(node_data[1])
    node, shared = expand_node!(node, 1)

    # Get node attributes:
    if features !== nothing
        node_attr = parse_MTG_node_attr(node_data, attr_type, features, node_attr_column_start, line)
    else
        # if there are no attribute in the MTG, we create an empty attribute:
        node_attr = init_empty_attr(attr_type)
    end

    if node[1] == "^"
        # The parent node is the last one built on the same column
        parent_column = last_node_column[node_column]
        if parent_column == 0
            error("Node defined at line ", line,
                " uses the '<' notation but is the first on its column.")
        end
    else
        # The parent node is the last one built on column - 1.
        node_id[1] == 1 ? parent_column = 1 : parent_column = last_node_column[node_column-1]

        if parent_column == 0
            error(
                "Can't find the parent of Node defined at line ",
                line,
                ". You may check the number of leading tabs."
            )
        end
    end

    building_nodes = (eachindex(node))[node.!="^"]

    for k in building_nodes
        node_element = parse_MTG_node(node[k])
        # NB: if several nodes are declared on the same line, the attributes are defined
        # for the last node only, unless "<.<" or "+.+" are used

        # Return an error if the link is not a proper one:
        if node_element[1] ∉ ("/", "<", "+")
            error(
                "Node `$(node[k])` defined at line ",
                line[1],
                " does not have a proper link (i.e. `/`, `<`, `+`), ",
                "please define one."
            )
        end

        symbol = node_element[2]

        if k == length(node) || findfirst(x -> x == k, shared) !== nothing
            node_k_attr = node_attr
        else
            node_k_attr = init_empty_attr(attr_type)
        end

        if k == minimum(building_nodes)
            parent_node = parent_column
        else
            parent_node = node_id[1] - 1
        end

        symbol_in_classes = symbol .== classes.SYMBOL

        if !any(symbol_in_classes)
            error(
                "The symbol of node `$(node[k])` defined at line ",
                line[1],
                " is not declared on the CLASSES section, ",
                "please define it first."
            )
        end

        scale = classes.SCALE[symbol_in_classes][1]

        # Instantiating the current node MTG:
        childMTG = mtg_type(
            node_element[1],
            symbol,
            node_element[3],
            scale
        )

        # Instantiating the current node (mutable):
        if node_id[1] == 1
            node_MTG = Node(
                node_id[1],
                childMTG,
                node_k_attr
            )
        else
            node_MTG = Node(
                node_id[1],
                tree_dict[parent_node],
                childMTG,
                node_k_attr
            )
        end
        # Add the node to tree_dict to be able to access it by id:
        push!(tree_dict, node_id[1] => node_MTG)

        # Keeping track of the last node used in the current MTG column
        last_node_column[node_column] = node_id[1]

        # Increment node unique ID:
        node_id[1] = node_id[1] + 1
    end
end