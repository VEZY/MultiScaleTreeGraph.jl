
"""
Parse MTG section

# Arguments
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`.
- `classes::Array`: The class section data as returned by `parse_section!`.
- `description::Array`: The description section data as returned by `parse_section!`.
- `features::Array`: The features section data as returned by `parse_section!`.
- `line::Array{Int64,1}`: The line number at which f is at the start of the funtion (mutated).
- `l::Array{String,1}`: the current line

# Note

The buffered IO stream (`f`) should start at the line of the section.

# Returns

The parsed MTG section
"""
function parse_mtg!(f,classes,description,features,line,l)
    l[1] = next_line!(f,line)

    if length(l[1]) == 0 
        error("No header was found for MTG section `MTG`. Did you put an empty line in-between ",
        "the section name and its header?")
    end
    l_header = split(l[1], "\t")

    if l_header[1] != "ENTITY-CODE" && l_header[1] != "TOPO"
        error("Neither ENTITY-CODE or TOPO were found in the MTG header at line: ",line)
    end

    columns = l_header[l_header .!= ""][2:end]
    common_features = occursin.(columns, features.NAME)


    

    if !all(common_features)
     error("Unknown column in the ENTITY-CODE (column names) in MTG: ",join(columns[.!common_features],", "))
    end

    if features.NAME != columns
     error("FEATURES names should be in the same order as column names in the ENTITY-CODE.")
    end

    attr_column_start = findfirst(x -> x == columns[1], l_header)

    l[1] = next_line!(f,line)
    splitted_MTG = split(l[1], "\t")
    node_1_node = split_MTG_elements(splitted_MTG[1])
    node_1_element = parse_MTG_node.(node_1_node)

    # node_data = splitted_MTG[1] ; 
    attrs = parse_MTG_node_attr(splitted_MTG,features,attr_column_start,line)
    node_1_attr
    # Continue here !!!
end

"""
 # Parse MTG node

 Parse MTG nodes (called from `parse_mtg!()`)

# Arguments  

- `l::String`: An MTG node (e.g. "/Individual0")

# Return  

A parsed node in the form of a list of three:
 - the link
 - the symbol
 - and the index
"""
function parse_MTG_node(l)
    if any(l .== ("^","<.","+."))
        return(NodeMTG(l))
    end

    link = l[1]

    # Match the index at the end of the string:
    stringmatch = match(r"[^[:alpha:]]+$",l[2:end])

    # Use the index at which the MTG index was found to retreive the MTG symbol: 
    symbol = l[2:stringmatch.offset]
    index = parse(Int,stringmatch.match)
    NodeMTG(link, symbol, index)
end


"""

Parse MTG node attributes names, values and type

# Arguments
- `l::String`: An MTG node (e.g. "/Individual0")
- `features::DataFrame`: The features data.frame
- `attr_column_start::DataFrame`: The index of the column of the first attribute
- `line::Integer`: The line of the mtg file
- `force::Bool`: force data reading even if errors are met during conversion ?

# Return

A list of attributes

"""
function parse_MTG_node_attr(node_data,features,attr_column_start,line;force = false)

    node_attr = Dict{String,Any}(zip(features.NAME, fill(missing, size(features)[1])))
    # node_attr = fill(missing, size(features)[1])

    if length(node_data) < attr_column_start
        return node_attr
    end

    node_data_attr = node_data[attr_column_start:end]
    if length(node_data_attr) > size(features)[1]
        error("Found more columns for features in MTG than declared in the FEATURE section",
        ". Please check line ",line, " of the MTG:\n",join(node_data, "\t"))
    end
    
    node_type = features.TYPE

    for i in 1:length(node_data_attr)
        if node_data_attr[i] == "" || node_data_attr[i] == "NA"
            node_attr[features.NAME[i]] = missing
            continue
        end

        if node_type[i] == "INT"
            node_attr[features.NAME[i]] = try
                parse(Int,node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                    "with value $(node_data_attr[i]) into integer.",
                    " Please check line ",line," of the MTG:\n",join(node_data, "\t"))
                end
                missing
            end 
        elseif node_type[i] == "REAL" || (node_type[i] == "ALPHA" && in(features.NAME[i],("Width","Length")))
            node_attr[features.NAME[i]] = try
                parse(Float64,node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                    "with value $(node_data_attr[i]) into Float64.",
                    " Please check line ",line," of the MTG:\n",join(node_data, "\t"))
                end
                missing
            end 
        else
            node_attr[features.NAME[i]] = node_data_attr[i]
        end
    end

    node_attr
end