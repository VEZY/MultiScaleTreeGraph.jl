const _MTG_SECTION_REGEX = r"(CODE|CLASSES|DESCRIPTION|FEATURES|MTG)[[:blank:]]*:"
const _MTG_CODE_SECTION_REGEX = r"CODE[[:blank:]]*:"
const _MTG_CLASSES_SECTION_REGEX = r"CLASSES[[:blank:]]*:"
const _MTG_DESCRIPTION_SECTION_REGEX = r"DESCRIPTION[[:blank:]]*:"
const _MTG_FEATURES_SECTION_REGEX = r"FEATURES[[:blank:]]*:"
const _MTG_MTG_SECTION_REGEX = r"MTG[[:blank:]]*:"

"""
    issection(string)

# Is a section

Is a string part of an MTG section ? Returns `true` if it does, `false` otherwise.


```julia
issection("CODE :")
```
"""
issection(string) = occursin(_MTG_SECTION_REGEX, string)

"""
    issection(string,section)

# Is a section

Is a string part of an MTG section ? Returns `true` if it does, `false` otherwise.

# Arguments
- `string::String`: The string to test.
- `section::String`: The section to test.

```julia
issection("CODE :", "CODE")
```
"""
function issection(string, section)
    if section isa AbstractString
        section == "CODE" && return occursin(_MTG_CODE_SECTION_REGEX, string)
        section == "CLASSES" && return occursin(_MTG_CLASSES_SECTION_REGEX, string)
        section == "DESCRIPTION" &&
            return occursin(_MTG_DESCRIPTION_SECTION_REGEX, string)
        section == "FEATURES" && return occursin(_MTG_FEATURES_SECTION_REGEX, string)
        section == "MTG" && return occursin(_MTG_MTG_SECTION_REGEX, string)
    end
    occursin(Regex("$section[[:blank:]]*:"), string)
end


"""
    next_line!(f,line)

# Read line

Read the next line in the IO stream, strip the comments, the missing values and increment the line index.

# Arguments
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`.
- `line::Array{Int64,1}`: The line number at which f is at the start of the funtion (mutated).
- `whitespace::Bool`: remove leading whitespaces.
"""
function next_line!(f, line;whitespace = true)
    line[1] = line[1] + 1
    missing_repl = whitespace ? "\t" : ""
    missing_pat = whitespace ? r"(\t){0,1}missing" : r"missing"

    x = replace(readline(f), missing_pat => missing_repl)
    strip_comments(x; whitespace = whitespace)
end


"""

    split_MTG_elements(l)

# Split MTG line

Split the elements (e.g. inter-node, growth unit...) in an MTG line

# Arguments
- `l::String`: A string for an MTG line (e.g. "/P1/A1").

# Return

A vector of elements (keeping their link, e.g. + or <)

```julia
split_MTG_elements("/A1+U85/U86<U87<.<U93<U94<.<U96<U97+.+U100")
```
"""
function split_MTG_elements(l)
    split(l, r"(?<=.)(?=[</+])")
end
