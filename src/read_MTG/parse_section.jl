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

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
f = open(file, "r")
line = [0] ; l = [""]; l[1] = MultiScaleTreeGraph.next_line!(f,line)

while MultiScaleTreeGraph.issection(l[1]) || MultiScaleTreeGraph.issection(l[1],"CLASSES")
    l[1] = MultiScaleTreeGraph.next_line!(f,line)
end

classes = MultiScaleTreeGraph.parse_section!(f,["SYMBOL","SCALE","DECOMPOSITION","INDEXATION","DEFINITION"],"CLASSES",line,l)

close(f)
```
"""
function parse_section!(f, header, section, line, l; allow_empty=false)

    l[1] = next_line!(f, line)

    if length(l[1]) == 0
        allow_empty && return
        error("No header was found for MTG section `", section, "`. did you put an empty line in-between ",
            "the section name and its header?")
    end
    l_header = split(l[1], "\t")

    if l_header != header
        error("The header of the MTG `", section, "` section is different than:\n", join(header, "\t"))
    end

    l[1] = next_line!(f, line)

    if length(l[1]) == 0
        allow_empty && return
        error("Data not found in MTG section `", section, "`. Did you put empty lines between the header",
            " of the section and its header? If so, remove them before proceeding.")
    end

    # Return if the line is a new section
    issection(l[1]) && return

    section_l = strip.(split(l[1], "\t"))
    classes = [section_l]

    while (length(section_l) == length(header)) && !issection(l[1]) && !eof(f)
        l[1] = next_line!(f, line)

        # Read next line if the line is empty:
        if length(l[1]) == 0
            continue
        end

        # Break if line is a new section
        issection(l[1]) && break

        section_l = strip.(split(l[1], "\t"))
        append!(classes, [section_l])
    end

    DataFrame([classes[x][y] for x = eachindex(classes), y = eachindex(l_header)], l_header)
end
