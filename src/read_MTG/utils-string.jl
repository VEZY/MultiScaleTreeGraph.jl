"""
    issection(string)

# Is a section

Is a string part of an MTG section ? Returns `true` if it does, `false` otherwise.


```jldoctest
julia> issection("CODE :")
true
```
"""
function issection(string)
    sections = ("CODE", "CLASSES", "DESCRIPTION", "FEATURES","MTG")
    occursin(Regex("($(join(sections,"|")))[[:blank:]]*:"), string)
end

"""
    issection(string,section)

# Is a section

Is a string part of an MTG section ? Returns `true` if it does, `false` otherwise.

# Arguments  
- `string::String`: The string to test.  
- `section::String`: The section to test.

```jldoctest
julia> issection("CODE :", "CODE")
true
```
"""
function issection(string,section)
    occursin(Regex("$section[[:blank:]]*:"), string)
end


"""
    next_line!(f,line)

# Read line 

Read the next line in the IO stream, strip the comments, and increment the line index.

# Arguments  
- `f::IOStream`: A buffered IO stream to the mtg file, *e.g.* `f = open(file, "r")`.
- `line::Array{Int64,1}`: The line number at which f is at the start of the funtion (mutated).
- `whitespace::Bool`: remove leading whitespaces.
"""
function next_line!(f,line;whitespace = true)
    line[1] = line[1] + 1
    strip_comments(readline(f);whitespace = whitespace)
end


"""

    split_MTG_elements(l)

# Split MTG line

Split the elements (e.g. inter-node, growth unit...) in an MTG line

# Arguments  
- `l::String`: A string for an MTG line (e.g. "/P1/A1").

# Return

A vector of elements (keeping their link, e.g. + or <)

```jldoctest
julia> split("/A1+U85/U86<U87<.<U93<U94<.<U96<U97+.+U100", r"(?<=.)(?=[</+])")
12-element Array{SubString{String},1}:
 "/A1"
 "+U85"
 "/U86"
 "<U87"
 ⋮
 "<U96"
 "<U97"
 "+."
 "+U100"
```
"""
function split_MTG_elements(l)
  split(l, r"(?<=.)(?=[</+])")
end

