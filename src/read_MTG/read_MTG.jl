"""
    read_mtg(file, mtg_type = MutableNodeMTG; sheet_name = nothing)

Read an MTG file

# Arguments

- `file::String`: The path to the MTG file.
- `mtg_type = MutableNodeMTG`: the type used to hold the mtg encoding for each node (*i.e.*
link, symbol, index, scale). See details section below.
- `sheet_name = nothing`: the sheet name in case you're reading an `xlsx` or `xlsm` file. It
reads the first sheet if `nothing` (default behavior).

# Details

Attributes are always stored as `ColumnarAttrs` (typed columnar backend).
Input values from the file are converted automatically.

The `MultiScaleTreeGraph` package provides two types for `mtg_type`, one immutable ([`NodeMTG`](@ref)), and
one mutable ([`MutableNodeMTG`](@ref)). If you're planning on modifying the mtg encoding of
some of your nodes, you should use [`MutableNodeMTG`](@ref), and if you don't want to modify
anything, use [`NodeMTG`](@ref) instead as it should be faster.

# Note

See the documentation of the MTG format from the package documentation for further details,
*e.g.* [The MTG concept](@ref).

# Returns

The MTG root node.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# We can also read an mtg directly from an excel file from the field:
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","tree3h.xlsx")
mtg = read_mtg(file)
```
"""
function read_mtg(file, mtg_type=MutableNodeMTG; sheet_name=nothing)
    file_extension = splitext(basename(file))[2]

    if file_extension == ".xlsx" || file_extension == ".xlsm"
        xlsx_file = readxlsx(file)
        if sheet_name === nothing
            xlsx_data = xlsx_file[sheetnames(xlsx_file)[1]][:]
        else
            xlsx_data = xlsx_file[sheet_name][:]
        end

        f = IOBuffer()
        DelimitedFiles.writedlm(f, xlsx_data)
        seekstart(f)
        # test = String(take!(io))
        mtg, classes, description, features = parse_mtg_file(f, mtg_type)
        close(f)
    else
        # read the mtg file
        # f = open(file, "r")
        mtg, classes, description, features =
            open(file, "r") do f
                parse_mtg_file(f, mtg_type)
            end
    end

    # Adding overall classes and symbols information to the root node (used for checks):
    append!(mtg, (symbols=classes.SYMBOL, scales=classes.SCALE, description=description))

    return mtg
end

function parse_mtg_file(f, mtg_type)
    line = [0]
    l = [""]
    l[1] = next_line!(f, line)

    while !eof(f)
        # Ignore empty lines between sections:
        while !issection(l[1]) && !eof(f)
            l[1] = next_line!(f, line)
        end

        # Parse the mtg CODE section, and then continue to next while loop iteration:
        if issection(l[1], "CODE")
            code = strip(replace(l[1], r"^CODE[[:blank:]]*:[[:blank:]]*" => ""))

            # read next line before continuing the while loop
            l[1] = next_line!(f, line)
            continue
        end

        # Parse the mtg CLASSES section, and then continue to next while loop iteration:
        if issection(l[1], "CLASSES")
            global classes = parse_section!(f, ["SYMBOL", "SCALE", "DECOMPOSITION", "INDEXATION", "DEFINITION"], "CLASSES", line, l)
            classes.SCALE = parse.(Int, classes.SCALE)
            replace!(classes.SYMBOL, "\$" => "Scene")
            continue
        end

        # Parse the mtg DESCRIPTION section:
        if issection(l[1], "DESCRIPTION")
            global description = parse_section!(f, ["LEFT", "RIGHT", "RELTYPE", "MAX"], "DESCRIPTION", line, l, allow_empty=true)
            if description !== nothing
                description.RIGHT = split.(description.RIGHT, ",")
                if !all([i in description.RELTYPE for i in ("+", "<")])
                    error("Unknown relation type(s) in DESCRIPTION section: ",
                        join(unique(description.RELTYPE[occursin.(description.RELTYPE, ("+<")).==0]), ", "))
                end
            end
            continue
        end

        # Parse the mtg FEATURES section:
        if issection(l[1], "FEATURES")
            global features = parse_section!(f, ["NAME", "TYPE"], "FEATURES", line, l, allow_empty=true)
            continue
        end

        # Parse the mtg FEATURES section:
        if issection(l[1], "MTG")
            global mtg = parse_mtg!(f, classes, features, line, l, mtg_type)
            continue
        end

    end

    return (mtg, classes, description, features)
end
