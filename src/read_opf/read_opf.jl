"""
    read_opf(file, attr_type = Dict, mtg_type = MutableNodeMTG)

Read an OPF file, and returns an MTG.

# Arguments

- `file::String`: The path to the opf file.
- `attr_type::DataType = Dict`: the type used to hold the attribute values for each node.
- `mtg_type = MutableNodeMTG`: the type used to hold the mtg encoding for each node (*i.e.*
link, symbol, index, scale). See details section below.

# Details

`attr_type` should be:

- `NamedTuple` if you don't plan to modify the attributes of the mtg, *e.g.* to use them for
plotting or computing statistics...
- `MutableNamedTuple` if you plan to modify the attributes values but not adding new attributes
very often, *e.g.* recompute an attribute value...
- `Dict` or similar (*e.g.* `OrderedDict`) if you plan to heavily modify the attributes, *e.g.*
adding/removing attributes a lot

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
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
```
"""
function read_opf(file, attr_type = Dict, mtg_type = MutableNodeMTG)

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

    opf_attr = attr_type()
    # node = elements(xroot)[5]
    for node in eachelement(xroot)
        if node.name == "meshBDD"
            push!(opf_attr, :meshBDD => parse_meshBDD!(node))
        end

        if node.name == "materialBDD"
            push!(
                opf_attr,
                :materialBDD => parse_opf_elements!(
                    node,
                    [Float64, Float64, Float64, Float64, Float64]
                )
            )
        end

        if node.name == "shapeBDD"
            push!(
                opf_attr,
                :shapeBDD => parse_opf_elements!(
                    node,
                    [String, Int64, Int64]
                )
            )
        end

        if node.name == "attributeBDD"
            push!(opf_attr, :attributeBDD => parse_opf_attributeBDD!(node))
        end

        if node.name == "topology"
            global mtg = parse_opf_topology!(
                node,
                nothing,
                get_attr_type(opf_attr[:attributeBDD]),
                attr_type,
                mtg_type
            )
            append!(mtg, opf_attr)

            return mtg
        end
    end
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
                push!(mesh, i.name => parse_opf_array(i.content, Int) .+ 1)
                # NB: adding 1 to the faces because the opf is 0-based but Julia is 1-based
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
- `elem_types::Array`: the target types of the element (e.g. "[String, Int64]")

# Details

`elem_types` should be of the same length as the number of elements found in each
item of the subchild.
elem_types = [Float64, Float64, Float64, Float64, Float64, Float64]
"""
function parse_opf_elements!(node, elem_types)
    elem_dict = Dict()
    for m in eachelement(node)
        elems_ = Dict()
        for (i, el) in enumerate(elements(m))
            content = parse_opf_array(el.content, elem_types[i])
            if length(content) > 0
                push!(elems_, el.name => content)
            end
        end
        push!(elem_dict, parse(Int, m["Id"]) => elems_)
    end
    return elem_dict
end

"""
 Parse the opf attributes as a Dict.
"""
function parse_opf_attributeBDD!(node)
    elem_dict = Dict()
    for m in eachelement(node)
        push!(elem_dict, m["name"] => m["class"])
    end
    return elem_dict
end

"""
Get the attributes types in Julia `DataType`.
"""
function get_attr_type(attr)
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
elem = elem.content
"""
function parse_geometry(elem)
    geom = Dict()
    for i in eachelement(elem)
        if i.name == "mat"
            push!(geom, "mat" => SMatrix{3,4}(transpose(reshape(parse_opf_array(i.content), 4, 3))))
        elseif i.name == "dUp"
            push!(geom, "dUp" => parse_opf_array(i.content))
        elseif i.name == "dDwn"
            push!(geom, "dDwn" => parse_opf_array(i.content))
        end
    end
    return geom
end


"""
Parser for OPF topology.

# Note

The transformation matrices in `geometry` are 3*4.
parse_opf_topology!(elem, node_i, features)
node = elem
mtg = node_i
"""
function parse_opf_topology!(node, mtg, features, attr_type, mtg_type)
    if node.name == "topology" # First node
        link = "/"
    elseif node.name == "decomp"
        link = "/"
    elseif node.name == "branch"
        link = "+"
    elseif node.name == "follow"
        link = "<"
    end

    MTG = mtg_type(
        link,
        node["class"],
        parse(Int, node["id"]),
        parse(Int, node["scale"])
    )

    if mtg !== nothing
        node_i = Node(mtg.id + 1, mtg, MTG, attr_type())
    else
        # First node:
        node_i = Node(1, MTG, attr_type())
    end

    attrs = attr_type()

    # Handle the children, can be attributes of children nodes:
    # elem = elements(node)[5]
    for elem in eachelement(node)
        # If an element is an attribute, add it to the attributes of the Node:
        if elem.name in keys(features)
            push!(attrs, elem.name => parse_opf_array(elem.content, features[elem.name]))
        elseif elem.name == "geometry"
            # Parse the geometry (transformation matrix and dUp and dDwn):
            push!(attrs, elem.name => parse_geometry(elem))
        else
            parse_opf_topology!(elem, node_i, features, attr_type, mtg_type)
        end
    end

    node_i.attributes = attrs

    return node_i
end
