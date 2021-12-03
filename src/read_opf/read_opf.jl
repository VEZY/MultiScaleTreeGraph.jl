"""
Read an OPF file, parse its values and return the result as an OrderedDict.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
```
"""
function read_opf(file)

    doc = readxml(file)
    xroot = root(doc)
    line = [2]

    if xroot.name != "opf"
        error("The file is not an OPF")
    end

    if xroot["version"] != "2.0"
        error("Cannot reaf OPF files version other than V2.0")
    end

    editable = parse(Bool, xroot["editable"])

    # node = elements(xroot)[2]
    for node in eachelement(xroot)
        if node.name == "meshBDD"
            meshBDD = parse_meshBDD!(node)
        end

        if node.name == "materialBDD"
            materialBDD = parse_opf_elements!(
                node,
                "materialBDD",
                "material",
                [Int64, Float64, Float64, Float64, Float64, Float64]
            )

        end

        if node.name == "shapeBDD"

        end

        if node.name == "attributeBDD"

        end

        if node.name == "topology"
            mtg = Node()
        end
    end
    # close(reader)

    parse_opf_elements!(opf, "materialBDD", "material", [Int64, Float64, Float64, Float64, Float64, Float64])
    parse_opf_elements!(opf, "shapeBDD", "shape", [Int64, String, Int64, Int64])
    parse_opf_attributeBDD!(opf)
    parse_opf_topology!(opf, attr_type(opf["attributeBDD"]))

    return opf
end


"""
Parse an array of values from the OPF into a Julia array (Arrays in OPFs
are not following XML recommendations)
"""
function parse_opf_array(elem, type = Float64)
    if type == String
        strip(elem)
    else
        parsed = map(x -> parse(type, x), split(elem))
        if length(parsed) == 1
            return parsed[1]
        else
            return parsed
        end
    end
end


"""
Parse the mesh_BDD using [parse_opf_array]
"""
function parse_meshBDD!(node)
    # MeshBDD:
    meshes = Dict{Int,Dict{String,Union{Vector{Float64},Vector{Int64}}}}()

    for m in eachelement(node)
        m.name != "mesh" ? @warn("Unknown node element in meshBDD: $(m.name)") : nothing
        mesh = Dict{String,Union{Vector{Float64},Vector{Int}}}()
        for i in eachelement(m)
            if i.name == "faces"
                push!(mesh, i.name => parse_opf_array(i.content, Int))
            else
                push!(mesh, i.name => parse_opf_array(i.content))
            end
        end
        push!(meshes, parse(Int, m["Id"]) => mesh)
    end

    return meshes
end


"""
Generic parser for OPF elements.

# Arguments

- `opf::OrderedDict`: the opf Dict (using [XMLDict.xml_dict])
- `child::String`: the child name (e.g. "materialBDD")
- `subchild::String`: the sub-child name (e.g. "material")
- `elem_types::Array`: the target types of the element (e.g. "[String, Int64]")

# Details

`elem_types` should be of the same length as the number of elements found in each
item of the subchild.

child = "materialBDD"
subchild = "material"
elem_types = [Int64, Float64, Float64, Float64, Float64, Float64]
"""
function parse_opf_elements!(node, child, subchild, elem_types)
    elements(elements(elements(node)[1])[1])

    for m = 1:length(node[child][subchild])
        elem_keys = collect(keys(node[child][subchild][m]))
        for i = 1:length(elem_keys)
            if !isa(node[child][subchild][m][elem_keys[i]], Array)
                node[child][subchild][m][elem_keys[i]] =
                    parse_opf_array(opf[child][subchild][m][elem_keys[i]], elem_types[i])
            end
        end
    end
end

"""
 Parse the opf attributes as a Dict.
"""
function parse_opf_attributeBDD!(opf)
    opf["attributeBDD"] = Dict([a[:name] => a[:class] for a in opf["attributeBDD"]["attribute"]])
end

"""
Get the attributes types in Julia `DataType`.
"""
attr_type = function (attr)
    attr_Type = Dict{String,DataType}()
    for i in keys(attr)
        if attr[i] in ["Object", "String", "Color", "Image"]
            push!(attr_Type, i => String)
        elseif attr[i] == "Integer"
            push!(attr_Type, i => Int32)
        elseif attr[i] in ["Double", "Metre", "Centimetre", "Millimetre", "10E-5 Metre"]
            push!(attr_Type, i => Float32)
        elseif attr[i] == "Boolean"
            push!(attr_Type, i => Bool)
        end
    end
    return attr_Type
end


"""
Parse the geometry element of the OPF.

# Note
The transformation matrix is 3*4.
"""
function parse_geometry(elem)
    elem["mat"] = SMatrix{3,4}(transpose(reshape(parse_opf_array(elem["mat"]), 4, 3)))
    elem["dUp"] = parse_opf_array(elem["dUp"])
    elem["dDwn"] = parse_opf_array(elem["dDwn"])
end


"""
Parser for OPF topology.

# Note

The transformation matrices in `geometry` are 3*4.
"""
function parse_opf_topology!(node, attrType, child = "topology")
    node[child][:scale] = parse_opf_array(node[child][:scale], Int32)
    node[child][:id] = parse_opf_array(node[child][:id], Int32)

    # Parsing the attributes to their true type:
    for i in intersect(collect(keys(attrType)), collect(keys(node[child])))
        node[child][i] = parse_opf_array(node[child][i], attrType[i])
    end

    # Parse the geometry (transformation matrix and dUp and dDwn):
    try
        parse_geometry(node[child]["geometry"])
    catch
        nothing
    end

    # Make the function recursive for each component:
    for i in intersect(collect(keys(node[child])), ["decomp", "branch", "follow"])
        # If it is an Array (several "follow" are represented as an Array under only
        # one "follow" to avoid several same key names in a Dict), then do it for each:
        if isa(node[child][i], Array)
            for j = 1:length(node[child][i])
                parse_opf_topology!(node[child][i], attrType, j)
            end
        else
            parse_opf_topology!(node[child], attrType, i)
        end
    end
end
