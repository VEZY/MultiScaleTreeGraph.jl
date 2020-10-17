
"""
Parse MTG section

# Arguments
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`
- `classes::Array`: The class section data as returned by `parse_section!`
- `description::Array`: The description section data as returned by `parse_section!`
- `features::Array`: The features section data as returned by `parse_section!`
- `line::Array{Int64,1}`: The current line index (mutated). Must be given as line of `MTG:`
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
    # node_1_element = parse_MTG_node(node_1_node[1])
    link, symbol, index = parse_MTG_node(node_1_node[1])
    
    # Handling special case of the scene node:
    if symbol == "Scene"
         symbol = "\$"
    end

    scale = classes.SCALE[symbol .== classes.SYMBOL][1]
    attrs = parse_MTG_node_attr(splitted_MTG,features,attr_column_start,line)

    root_node = Node(join([symbol,"1"],"_"), NodeMTG(link,symbol,index,scale), attrs)

    # Initializing the last column to which MTG was attached to keep track of which column
    # to attach the new MTG line 
    max_columns = attr_column_start - 1
    last_node_column = repeat([1], max_columns)

    node_id = 2

    # for i in Iterators.drop(1:length(splitted_MTG), 1)
    while !eof(f)
        node_name = join(["node_",node_id])
        l[1] = next_line!(f,line)
        splitted_MTG = split(l[1], "\t")
        
        node_column = findfirst(x -> length(x) > 0, splitted_MTG)
        # node_data= splitted_MTG[[i]]
        node_data = splitted_MTG[node_column:end]
        
        if attr_column_start < node_column
            error("Error in MTG at line ",line,": Found an MTG node declared at column ",
                node_column,", but attributes are declared to start at column ",
                attr_column_start," in the ENTITY-CODE row. \nYou can probably fix the issue by adding",
                " some tabs after ENTITY-CODE (try to add ",
                node_column-attr_column_start+1," tabs).")
        end
        node_attr_column_start = attr_column_start - node_column + 1
        node = split_MTG_elements(node_data[1])
        node, shared = expand_node!(node,1)
        
        ####### Continuer ici !!!!!!!!

        # Get node attributes:
        node_attr = parse_MTG_node_attr(node_data,features,node_attr_column_start,i+first_line+1)
        
        # Declare a new node as object (because the methods associated to nodes are OO):
        # assign(node_name, data.tree::Node$new(node_name))
        
        if node[1] == "^"
            # The parent node is the last one built on the same column
            parent_column = last_node_column[node_column]
            if (is.na(parent_column))
                stop("Node defined at line ",i+first_line+1,
                " uses the '<' notation but is the first on its column")
            end
        else
            # The parent node is the last one built on column - 1.
            parent_column = last_node_column[node_column - 1]
            
            if is.na(parent_column)
                stop("Can't find the parent of Node defined at line ",i+first_line+1,
                ". It may be defined on a column that is too far right.")
            end
        end
        
        # building_nodes = seq_along(node)[node != "^"]
        # for k in building_nodes
        #     node_element = parse_MTG_node(node[k])
            
        #     # NB: if several nodes are declared on the same line, the attributes are defined
        #     # for the last node only, unless "<.<" or "+.+" are used
        #     if k == length(node) || k %in% attr(node,"shared")
        #         node_k_attr= c(node_attr,
        #         .link = node_element$link,
        #         .symbol = node_element$symbol,
        #         .index = node_element$index,
        #         .scale = classes$SCALE[node_element$symbol == classes$SYMBOL])
        #     else
        #         node_k_attr= (.link = node_element$link,
        #         .symbol = node_element$symbol,
        #         .index = node_element$index,
        #         .scale = classes$SCALE[node_element$symbol == classes$SYMBOL])
        #     end
        #     if k == min(building_nodes)
        #         parent_node = paste0("node_",parent_column)
        #     else 
        #         parent_node = paste0("node_",node_id-1)
        #     end
        #     node_name = paste0("node_",node_id)
            
        #     # Call the "AddChild" method from the parent to add our new node as its child:
        #     # eval(parse(text=parent_node))[["AddChild"]](node_name)
        #     assign(node_name,eval(parse(text=parent_node))[["AddChild"]](node_name))
        #     # Assign the attributes to the current node :
        #     for j in names(node_k_attr)
        #         assign(j, node_k_attr[[j]], j, eval(parse(text=node_name)))
        #     end
            
        #     last_node_column[node_column] = node_id
        #     node_id = node_id + 1
        # end
    end

  root_node
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
    if any(l .== ("^","<.","+."))
        return((l,missing,missing))
    end

    link = l[1]

    # Match the index at the end of the string:
    stringmatch = match(r"[^[:alpha:]]+$",l[2:end])

    # Use the index at which the MTG index was found to retreive the MTG symbol: 
    symbol = l[2:stringmatch.offset]
    index = parse(Int,stringmatch.match)
    (link, symbol, index)
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

    
    if length(node_data) < attr_column_start
        return missing
    end

    node_data_attr = node_data[attr_column_start:end]
    
    if length(node_data_attr) > size(features)[1]
        error("Found more columns for features in MTG than declared in the FEATURE section",
        ". Please check line ",line, " of the MTG:\n",join(node_data, "\t"))
    end
    
    node_attr = Dict{String,Any}(zip(features.NAME[1:length(node_data_attr)],
                                 fill(missing, length(node_data_attr))))
 
    node_type = features.TYPE

    # node_data_attr is always read in order so names and types correspond to values in features
    for i in 1:length(node_data_attr)
        if node_data_attr[i] == "" || node_data_attr[i] == "NA"
            pop!(node_attr,features.NAME[i])
            continue
        end

        if node_type[i] == "INT"
            try
               node_attr[features.NAME[i]] = parse(Int,node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                    "with value $(node_data_attr[i]) into integer.",
                    " Please check line ",line," of the MTG:\n",join(node_data, "\t"))
                end
                pop!(node_attr,features.NAME[i])

            end
        elseif node_type[i] == "REAL" || (node_type[i] == "ALPHA" && in(features.NAME[i],("Width","Length")))
            try
                node_attr[features.NAME[i]] = parse(Float64,node_data_attr[i])
            catch e
                if !force
                    error("Found issue in the MTG when converting column $(features[i,1]) ",
                    "with value $(node_data_attr[i]) into Float64.",
                    " Please check line ",line," of the MTG:\n",join(node_data, "\t"))
                end
                pop!(node_attr,features.NAME[i])
            end 
        else
            node_attr[features.NAME[i]] = node_data_attr[i]
        end
    end

    MutableNamedTuple{tuple(Symbol.(keys(node_attr))...)}(tuple(values(node_attr)...))
end


    # Dict{String,Any}(zip(features.NAME, fill(missing, size(features)[1])))
    # # node_attr = fill(missing, size(features)[1])
    
    # test = MutableNamedTuple(;zip(Symbol.(features.NAME), fill(missing, size(features)[1]))...)
    # typeof(test)
    # test.YY = 1

    # NamedTuple{tuple(Symbol.(features.NAME)...)}(fill(missing, size(features)[1]))
    # MutableNamedTuple{tuple(Symbol.(features.NAME)...)}(fill(missing, size(features)[1]))
