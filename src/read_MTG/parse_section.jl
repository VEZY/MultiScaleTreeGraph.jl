"""
Parse MTG section

# Arguments
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`.
- `header::Array{String,1}`: A string defining the expected header for the class.
- `section::String`: The section name.
- `line::Array{Int64,1}`: The line number at which f is at the start of the funtion (mutated).
- `l::Array{String,1}`: the current line

# Note

The buffered IO stream (`f`) should start at the line of the section.

# Returns

The parsed section of the MTG

# Examples

```jldoctest
file = "test/files/simple_plant.mtg"
f = open(file, "r")

parse_section!(f,["SYMBOL", "SCALE", "DECOMPOSITION", "INDEXATION", "DEFINITION"],"CLASSES")

close(f)
```
"""
function parse_section!(f,header,section,line,l;allow_empty=false)
    l[1] = next_line!(f,line)
    
    if length(l[1]) == 0 
        allow_empty && return
        error("No header was found for MTG section `",section,"`. did you put an empty line in-between ",
        "the section name and its header?")
    end
    l_header = split(l[1], "\t")

    if l_header != header
        error("The header of the MTG `",section,"` section is different than:\n",join(header, "\t"))
    end

    l[1] = next_line!(f,line)
    section_l = strip.(split(l[1], "\t"))
    classes = [section_l]

    while (length(section_l) == length(header)) & !issection(l[1]) & !eof(f)
        l[1] = next_line!(f,line)

        # Break if empty line:
        (length(l[1]) == 0) && break

        section_l = strip.(split(l[1], "\t"))
        append!(classes, [section_l])
    end

    DataFrame([classes[x][y] for x = 1:length(classes), y = 1:length(l_header)],l_header)
end