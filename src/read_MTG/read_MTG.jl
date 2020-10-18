"""
Read an MTG file

# Arguments
- `file::String`: The path to the MTG file.

# Note

See the documentation for the MTG format from the [OpenAlea webpage](http://openalea.gforge.inria.fr/doc/vplants/newmtg/doc/_build/html/user/intro.html#mtg-a-plant-architecture-databases) 
for further details.

# Returns
A named list of four sections: the MTG classes, description, features,
and MTG. The MTG is a [data.tree] data structure.

# Examples

```jldoctest
julia> file = download("https://raw.githubusercontent.com/VEZY/XploRer/master/inst/extdata/simple_plant.mtg");
julia> mtg,classes,description,features = read_mtg(file);
```
"""
function read_mtg(file)

    sections = ("CODE", "CLASSES", "DESCRIPTION", "FEATURES","MTG")

    # file = "test/files/simple_plant.mtg"
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
                    if !all(occursin.(description.RELTYPE, ("+","<")))
                        error("Unknown relation type(s) in DESCRITPION section: ",
                                join(unique(description.RELTYPE[occursin.(description.RELTYPE, ("+","<")) .== 0]),", "))
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
                mtg = parse_mtg!(f,classes,features,line,l)
                # mtg = next_line!(f,line)
                continue
            end

            # next_line!(f,line)
        end
        (mtg,classes,description,features)
    end
        
        # Ignoring all commented lines in the header:
        # l = ""
        # while !issection(l)
        #     l = strip_comments(readline(f))
        # end
        
        # occursin(Regex("CODE[[:blank:]]*:"), l)
        
        # if issection(l,"CODE")
            
        # end
        
        # code = replace(l, r"^CODE[[:blank:]]*:[[:blank:]]*" => "")
        
        # if code != "FORM-A"
        #     error("MTG code is $code, but MTG.jl is only compatible with FORM-A MTG.")
        # end
        
        # # Find MTG index in file to be able to return the true line at which there is an error
        # MTG_section_begin = grep("MTG[[:blank:]]*:", MTG_file)
        
        # MTG_file = strip_empty_lines(MTG_file)
        # # NB: could use pipes here, but can be ~2x slower
        
        # # Checking that all sections are present and ordered properly:
        # check_sections(MTG_file)
        
        # code = parse_MTG_code(MTG_file)
        # classes = parse_MTG_classes(MTG = MTG_file)
        # description = parse_MTG_description(MTG_file)
        # features = parse_MTG_features(MTG_file)
        
        # MTG = parse_MTG_MTG(MTG_file,classes,description,features,MTG_section_begin)
        
        #   attr(MTG, which = "classes") = classes
        #   attr(MTG, which = "description") = description
        #   attr(MTG, which = "features") = features
        
        #   class(MTG) = append(class(MTG), "mtg")

    # close(f) 
    # MTG
    (mtg,classes,description,features)
end