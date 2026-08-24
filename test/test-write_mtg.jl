file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
mtg = read_mtg(file)

# Removing the description because we don't write it anyway:
mtg[:description] = nothing

@testset "Test write / read again: simple plant" begin
    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end


mtg = read_mtg("files/simple_plant.mtg", NodeMTG)

@testset "Test write / read again: simple plant + NodeMTG" begin
    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f, NodeMTG)
        return mtg2
    end

    # Check that all nodes are the same (not testing node 1 as it has description that is not written):
    for i in 2:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end

@testset "Test write / read again: simple plant P1U1" begin
    mtg = read_mtg("files/simple_plant-P1U1.mtg")
    mtg[:description] = nothing

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end

@testset "Test write / read again: palm" begin
    mtg = read_mtg("files/palm.mtg")
    mtg[:description] = nothing

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    # Check that all nodes are the same:
    for i in 1:length(mtg)
        @test get_node(mtg, i) == get_node(mtg2, i)
    end
end


file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant-follow.mtg")
mtg = read_mtg(file)

@testset "Test write / read again: simple plant with GU follow" begin

    @test length(mtg) == 35
    @test length(children(mtg[1][1])) == 2
    @test children(mtg[1][1])[1] |> symbol == :N
    @test children(mtg[1][1])[2] |> symbol == :GU

    mtg2 = mktemp() do f, io
        write_mtg(f, mtg)
        mtg2 = read_mtg(f)
        return mtg2
    end

    @test length(mtg2) == length(mtg)
    @test descendants(mtg, :diameter_mm) == descendants(mtg2, :diameter_mm)
    @test descendants(mtg, :length_cm) == descendants(mtg2, :length_cm)
    @test descendants(mtg, :azimuth) == descendants(mtg2, :azimuth)
    @test traverse(mtg, symbol) == traverse(mtg2, symbol)
    @test traverse(mtg, index) == traverse(mtg2, index)
end

function _legacy_paste_node_mtg_for_test(mtg, features)
    lead = Int[]
    parent_ref = String[]
    print_node = String[]
    MultiScaleTreeGraph.get_node_printing!(mtg, lead, parent_ref, print_node)
    max_tabs = maximum(lead)

    attributes = MultiScaleTreeGraph.OrderedDict{String,Vector{Any}}()
    attributes["mtg_print"] = string.(
        repeat.("\t", lead),
        parent_ref,
        print_node,
        repeat.("\t", max_tabs .- lead),
    )
    for var in string.(features.NAME)
        push!(attributes, var => descendants(mtg, var, self=true))
    end

    feature_type = Dict{String,String}()
    @inbounds for i in eachindex(features.NAME)
        feature_type[string(features.NAME[i])] = string(features.TYPE[i])
    end
    for (key, values_) in attributes
        if get(feature_type, key, "") == "DD/MM/YY"
            replace!(x -> isnothing(x) ? x : Dates.format(x, dateformat"d/m/Y"), values_)
        end
        replace!(values_, nothing => "")
    end

    mtg_colnames = collect(keys(attributes))
    mtg_colnames[1] = string("ENTITY-CODE", repeat("\t", max_tabs))
    return attributes, mtg_colnames
end

function _legacy_mtg_section_for_test(mtg, features)
    io = IOBuffer()
    MultiScaleTreeGraph.writedlm(io, ["MTG:"])
    attributes, column_names = _legacy_paste_node_mtg_for_test(mtg, features)
    MultiScaleTreeGraph.writedlm(io, reshape(column_names, (1, :)), quotes=false)
    for i in eachindex(attributes["mtg_print"])
        row = Any[attributes[key][i] for key in keys(attributes)]
        MultiScaleTreeGraph.writedlm(io, reshape(row, (1, :)), quotes=false)
    end
    return String(take!(io))
end

function _written_mtg_section_for_test(text::String)
    section = findfirst("MTG:\n", text)
    section === nothing && error("Written file has no MTG section.")
    return text[first(section):end]
end

function _many_feature_writer_fixture(nfeatures::Int)
    feature_names = [Symbol("feature_", lpad(i, 2, '0')) for i in 1:nfeatures]
    feature_types = [
        (i % 7 == 1 ? "REAL" :
         i % 7 == 2 ? "INT" :
         i % 7 == 3 ? "BOOLEAN" :
         i % 7 == 0 ? "DD/MM/YY" : "STRING") for i in 1:nfeatures
    ]

    function node_attributes_for(ordinal::Int)
        attrs = Dict{Symbol,Any}()
        for i in eachindex(feature_names)
            key = feature_names[i]
            typ = feature_types[i]
            value = if ordinal == 2 && i % 5 == 0
                nothing
            elseif typ == "REAL"
                ordinal + i / 100
            elseif typ == "INT"
                ordinal * i
            elseif typ == "BOOLEAN"
                isodd(ordinal + i)
            elseif typ == "DD/MM/YY"
                ordinal == 4 && i % 14 == 0 ? nothing : Date(2026, mod1(i, 12), ordinal)
            elseif ordinal == 4 && i % 6 == 0
                missing
            elseif i % 7 == 5
                Symbol("state_$(ordinal)_$(i)")
            else
                "node$(ordinal)-feature$(i)"
            end
            attrs[key] = value
        end
        return attrs
    end

    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        node_attributes_for(1),
    )
    axis = Node(
        41,
        root,
        MutableNodeMTG(:/, :Axis, 1, 2),
        node_attributes_for(2),
    )
    Node(
        105,
        axis,
        MutableNodeMTG(:+, :Leaf, 1, 3),
        node_attributes_for(3),
    )
    continuation = Node(
        1_000,
        axis,
        MutableNodeMTG(:<, :Axis, 2, 2),
        node_attributes_for(4),
    )
    Node(
        10_000,
        continuation,
        MutableNodeMTG(:<, :Axis, -9999, 2),
        node_attributes_for(5),
    )

    features = DataFrame(NAME=feature_names, TYPE=feature_types)
    return root, features
end

@testset "Streaming writer preserves wide columnar MTG bytes" begin
    for nfeatures in (28, 40)
        mtg, features = _many_feature_writer_fixture(nfeatures)
        @test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs
        @test list_nodes(mtg) == [10, 41, 105, 1_000, 10_000]

        expected_section = _legacy_mtg_section_for_test(mtg, features)
        actual = mktemp() do path, io
            close(io)
            write_mtg(path, mtg, get_classes(mtg), nothing, features)
            return read(path, String)
        end
        @test _written_mtg_section_for_test(actual) == expected_section

        expected_attributes, expected_names = _legacy_paste_node_mtg_for_test(mtg, features)
        actual_attributes, actual_names = MultiScaleTreeGraph.paste_node_mtg(mtg, features)
        @test actual_names == expected_names
        @test isequal(actual_attributes, expected_attributes)
        @test occursin("missing", actual)
        @test occursin("^<Axis", actual)
    end
end

@testset "Streaming writer preserves flush and duplicate-feature bytes" begin
    long_text = repeat("long-field-", 2_000)
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict(
            :long_text => long_text,
            :date => Date(2026, 8, 24),
            :missing_value => missing,
            :nothing_value => nothing,
            :symbol_value => :root,
            :quoted_value => "root\t\"quoted\"\nvalue",
        ),
    )
    Node(
        10_000,
        root,
        MutableNodeMTG(:<, :Leaf, -9999, 2),
        Dict(
            :long_text => long_text,
            :date => Date(2025, 1, 2),
            :missing_value => "present",
            :nothing_value => nothing,
            :symbol_value => :child,
            :quoted_value => "child\t\"quoted\"\nvalue",
        ),
    )
    features = DataFrame(
        NAME=[
            :long_text,
            :date,
            :missing_value,
            :date,
            :nothing_value,
            :symbol_value,
            :quoted_value,
        ],
        TYPE=["STRING", "STRING", "STRING", "DD/MM/YY", "STRING", "STRING", "STRING"],
    )

    expected_section = _legacy_mtg_section_for_test(root, features)
    @test ncodeunits(expected_section) > 16 * 1024
    actual = mktemp() do path, io
        close(io)
        write_mtg(path, root, get_classes(root), nothing, features)
        return read(path, String)
    end
    @test _written_mtg_section_for_test(actual) == expected_section
end

@testset "Streaming writer preserves mtg_print feature collision" begin
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict(:other => 1, :mtg_print => "root entity override"),
    )
    Node(
        10_000,
        root,
        MutableNodeMTG(:<, :Leaf, -9999, 2),
        Dict(:other => 2, :mtg_print => "child entity override"),
    )
    features = DataFrame(
        NAME=[:other, :mtg_print],
        TYPE=["INT", "STRING"],
    )

    expected_section = _legacy_mtg_section_for_test(root, features)
    actual = mktemp() do path, io
        close(io)
        write_mtg(path, root, get_classes(root), nothing, features)
        return read(path, String)
    end
    @test _written_mtg_section_for_test(actual) == expected_section

    expected_attributes, expected_names = _legacy_paste_node_mtg_for_test(root, features)
    actual_attributes, actual_names = MultiScaleTreeGraph.paste_node_mtg(root, features)
    @test actual_names == expected_names
    @test isequal(actual_attributes, expected_attributes)
end

@testset "Table rows stream without changing DelimitedFiles quoting" begin
    table = DataFrame(
        first=["plain", "with\ttab", "with\"quote", "with\nline", repeat("long", 6_000)],
        second=Any[1, missing, true, :symbol, 42],
    )
    expected = IOBuffer()
    for i in 1:size(table, 1)
        row = Any[table[i, j] for j in 1:size(table, 2)]
        MultiScaleTreeGraph.writedlm(expected, reshape(row, (1, :)))
    end
    actual = IOBuffer()
    MultiScaleTreeGraph._write_table_rows(actual, table)
    actual_bytes = take!(actual)
    expected_bytes = take!(expected)
    @test length(actual_bytes) > 16 * 1024
    @test actual_bytes == expected_bytes
end

@testset "Streaming writer preserves date conversion errors" begin
    mtg = Node(10, MutableNodeMTG(:/, :Plant, 1, 1), Dict(:date => missing))
    features = DataFrame(NAME=[:date], TYPE=["DD/MM/YY"])
    mktemp() do path, io
        close(io)
        @test_throws MethodError write_mtg(path, mtg, get_classes(mtg), nothing, features)
        @test endswith(read(path, String), "MTG:\n")
    end
end
