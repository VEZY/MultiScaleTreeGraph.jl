"""
Strip comments from a string

    striplinecomment{T<:String,U<:String}(a::T, cchars::U="#;")

# Arguments  
- `a::String`: the string from which the comments has to be stripped
- `cchars::String`: the characters that defines comments 
From https://rosettacode.org/wiki/Strip_comments_from_a_string#Julia  
- `whitespace::Bool`: remove leading whitespaces.


```jldoctest
julia> strip_comments("test1")
"test1"

julia> strip_comments("test2 # with a comment")
"test2"

julia> strip_comments("# just a comment")
""
```
"""
function strip_comments(a::String, cchars::String="#;"; whitespace = true)
    if whitespace
        b = strip(a)
    else
        b = rstrip(a)
    end

    0 < length(cchars) || return b
    for c in cchars
        r = Regex(@sprintf "\\%c.*" c)
        b = replace(b, r => "")
    end
    rstrip(b)
end
