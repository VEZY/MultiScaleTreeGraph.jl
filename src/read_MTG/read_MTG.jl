"""
    read_mtg(file,attr_type::DataType = MutableNamedTuple)

Read an MTG file

# Arguments

- `file::String`: The path to the MTG file.
- `attr_type::DataType`: the type used to hold the attribute values for each node.

# Details

`attr_type` should be:

- `NamedTuple` if you don't plan to modify the attributes of the mtg, *e.g.* to use them for
plotting or computing statistics...
- `MutableNamedTuple` if you plan to modify the attributes values but not adding new attributes
very often, *e.g.* recompute an attribute value...
- `Dict` if you plan to modify heavily the attributes, *e.g.* adding/removing attibutes a lot

# Note

See the documentation for the MTG format from the [OpenAlea webpage](http://openalea.gforge.inria.fr/doc/vplants/newmtg/doc/_build/html/user/intro.html#mtg-a-plant-architecture-databases)
for further details.

# Returns

A named list of four sections: the MTG classes, description, features,
and MTG. The MTG is a [data.tree] data structure.

# Examples

```jldoctest
julia> mtg,classes,description,features = read_mtg(download("https://raw.githubusercontent.com/VEZY/MTG.jl/master/test/files/simple_plant.mtg"))
julia> mtg,classes,description,features = read_mtg(file);
```
"""
function read_mtg(file,attr_type = MutableNamedTuple)

    sections = ("CODE", "CLASSES", "DESCRIPTION", "FEATURES","MTG")

    # read the mtg file
    mtg,classes,description,features =
    open(file, "r") do f
        line = [0]
        l = [""]
        l[1] = next_line!(f,line)

        while !eof(f)
            # Ignore empty lines between sections:
            while !issection(l[1]) & !eof(f)
                l[1] = next_line!(f,line)
            end

            # Parse the mtg CODE section, and then continue to next while loop iteration:
            if issection(l[1],"CODE")
                code = replace(l[1], r"^CODE[[:blank:]]*:[[:blank:]]*" => "")

                # read next line before continuing the while loop
                l[1] = next_line!(f,line)
                continue
            end

            # Parse the mtg CLASSES section, and then continue to next while loop iteration:
            if issection(l[1],"CLASSES")
                classes = parse_section!(f,["SYMBOL","SCALE","DECOMPOSITION","INDEXATION","DEFINITION"],"CLASSES",line,l)
                classes.SCALE = parse.(Int,classes.SCALE)
                continue
            end

            # Parse the mtg DESCRIPTION section:
            if issection(l[1],"DESCRIPTION")
                description = parse_section!(f,["LEFT","RIGHT","RELTYPE","MAX"],"DESCRIPTION",line,l,allow_empty=true)
                if description !== nothing
                    description.RIGHT = split.(description.RIGHT,",")
                    if !all([i in description.RELTYPE for i in ("+","<")])
                        error("Unknown relation type(s) in DESCRITPION section: ",
                                join(unique(description.RELTYPE[occursin.(description.RELTYPE, ("+<")) .== 0]),", "))
                    end
                end
                continue
            end

            # Parse the mtg FEATURES section:
            if issection(l[1],"FEATURES")
                features = parse_section!(f,["NAME","TYPE"],"FEATURES",line,l)
                continue
            end

            # Parse the mtg FEATURES section:
            if issection(l[1],"MTG")
                mtg = parse_mtg!(f,classes,features,line,l,attr_type)
                continue
            end
        end
        (mtg,classes,description,features)
    end

    # Adding overall classes and symbols information to the root node (used for checks):
    append!(mtg, (symbols = classes.SYMBOL, scales = classes.SCALE))

    (mtg,classes,description,features)
end
