struct _ShiftedWriterVector{T} <: AbstractVector{T}
    values::Vector{T}
end

Base.size(vector::_ShiftedWriterVector) = size(vector.values)
Base.axes(vector::_ShiftedWriterVector) = (0:(length(vector.values) - 1),)
Base.getindex(vector::_ShiftedWriterVector, index::Int) = vector.values[index + 1]

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
        layout = MultiScaleTreeGraph._mtg_write_layout(mtg)
        feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(mtg, features)
        @test MultiScaleTreeGraph._mtg_columnar_write_context(
            layout, feature_columns
        ) isa MultiScaleTreeGraph._MTGColumnarWriteContext

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

    projected = mktemp() do path, io
        close(io)
        write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=Dict(:long_text => fill(long_text, 2)),
        )
        return read(path, String)
    end
    @test _written_mtg_section_for_test(projected) == expected_section
end

@testset "Feature overrides are aligned, typed, and source preserving" begin
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(
            :reference => 10,
            :date => Date(2026, 8, 24),
            :other => "root",
            :mtg_print => "original root",
        ),
    )
    Node(
        1_000,
        root,
        MutableNodeMTG(:<, :Leaf, -9999, 2),
        Dict{Symbol,Any}(
            :reference => 1_000,
            :date => Date(2025, 1, 2),
            :other => "child",
            :mtg_print => "original child",
        ),
    )
    features = DataFrame(
        NAME=[:reference, :date, :other, :mtg_print],
        TYPE=["INT", "DD/MM/YY", "STRING", "STRING"],
    )
    overrides = Dict{Symbol,AbstractVector}(
        :reference => Union{Nothing,Int}[2, 1],
        :date => Union{Nothing,Date}[Date(2024, 12, 31), nothing],
        :mtg_print => ["projected root", "projected child"],
    )
    source_attributes = [Dict(pairs(node_attributes(node))) for node in traverse(root, identity)]

    expected = deepcopy(root)
    expected_nodes = traverse(expected, identity)
    for (i, node) in pairs(expected_nodes)
        node[:reference] = overrides[:reference][i]
        node[:date] = overrides[:date][i]
        node[:mtg_print] = overrides[:mtg_print][i]
    end
    expected_section = _legacy_mtg_section_for_test(expected, features)

    actual = mktemp() do path, io
        close(io)
        write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=overrides,
        )
        return read(path, String)
    end
    @test _written_mtg_section_for_test(actual) == expected_section
    @test occursin("31/12/2024", actual)
    @test !occursin("24/8/2026", actual)
    @test [Dict(pairs(node_attributes(node))) for node in traverse(root, identity)] ==
          source_attributes

    high_level = mktemp() do path, io
        close(io)
        write_mtg(
            path,
            root;
            classes=get_classes(root),
            description=nothing,
            features=features,
            feature_overrides=overrides,
        )
        return read(path, String)
    end
    @test high_level == actual

    default = mktemp() do path, io
        close(io)
        write_mtg(path, root, get_classes(root), nothing, features)
        return read(path, String)
    end
    empty_override = mktemp() do path, io
        close(io)
        write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=Dict{Symbol,Vector{Int}}(),
        )
        return read(path, String)
    end
    @test empty_override == default

    invalid_overrides = (
        (Dict(:undeclared => [1, 2]), "undeclared MTG feature :undeclared"),
        (Dict(:reference => [1]), "expected 2 values aligned with MTG preorder"),
        (Dict("reference" => [1, 2]), "keys must be Symbols"),
        (Dict(:reference => 1), "must be an AbstractVector"),
        (
            Dict(:reference => _ShiftedWriterVector([1, 2])),
            "must use one-based axes",
        ),
    )
    for (invalid, expected_message) in invalid_overrides
        mktemp() do path, io
            close(io)
            error = try
                write_mtg(
                    path,
                    root,
                    get_classes(root),
                    nothing,
                    features;
                    feature_overrides=invalid,
                )
                nothing
            catch caught
                caught
            end
            @test error isa ArgumentError
            @test occursin(expected_message, sprint(showerror, error))
            @test endswith(read(path, String), "MTG:\n")
        end
    end
end

@testset "Feature overrides preserve the fallback lookup boundary" begin
    encoding = MutableNodeMTG(:/, :Plant, 1, 1)
    attributes = MultiScaleTreeGraph.ColumnarAttrs(Dict(:reference => 10, :other => "root"))
    NodeType = Node{typeof(encoding),typeof(attributes)}
    root = NodeType(
        10,
        nothing,
        NodeType[],
        encoding,
        attributes,
        nothing,
    )
    features = DataFrame(NAME=[:reference, :other], TYPE=["INT", "STRING"])
    layout = MultiScaleTreeGraph._mtg_write_layout(root)
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(root, features)
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        layout,
        feature_columns,
    ) === nothing

    expected = deepcopy(root)
    expected[:reference] = 1
    expected_section = _legacy_mtg_section_for_test(expected, features)
    actual = mktemp() do path, io
        close(io)
        write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=Dict(:reference => [1]),
        )
        return read(path, String)
    end
    @test _written_mtg_section_for_test(actual) == expected_section
    @test root[:reference] == 10
end

@testset "Duplicate feature last STRING type overrides earlier date type" begin
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:date => Date(2026, 8, 24)),
    )
    Node(
        20,
        root,
        MutableNodeMTG(:<, :Leaf, 1, 2),
        Dict{Symbol,Any}(:date => Date(2025, 1, 2)),
    )
    features = DataFrame(
        NAME=[:date, :date], TYPE=["DD/MM/YY", "STRING"]
    )
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(root, features)
    @test feature_columns.names == ["date"]
    @test collect(feature_columns.is_date) == [false]
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        MultiScaleTreeGraph._mtg_write_layout(root), feature_columns
    ) isa MultiScaleTreeGraph._MTGColumnarWriteContext

    expected_section = _legacy_mtg_section_for_test(root, features)
    actual = mktemp() do path, io
        close(io)
        write_mtg(path, root, get_classes(root), nothing, features)
        return read(path, String)
    end
    @test _written_mtg_section_for_test(actual) == expected_section
    @test occursin("2026-08-24", actual)
    @test !occursin("24/08/2026", actual)
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

@testset "Typed column writer preserves scalar and container cells" begin
    root = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(
            :vector_value => [1, 2],
            :missing_value => missing,
            :nothing_value => nothing,
            :date_value => Date(2026, 8, 24),
            :plain_date => Date(2026, 8, 24),
            :text_value => "root",
        ),
    )
    branch = Node(
        1_000,
        root,
        MutableNodeMTG(:+, :Branch, 1, 2),
        Dict{Symbol,Any}(
            :vector_value => [3, 4, 5],
            :missing_value => "present",
            :date_value => nothing,
            :plain_date => Date(2025, 1, 2),
            :text_value => "branch",
        ),
    )
    Node(
        10_000,
        branch,
        MutableNodeMTG(:<, :Leaf, 1, 3),
        Dict{Symbol,Any}(
            :vector_value => String["a", "b"],
            :missing_value => missing,
            :nothing_value => nothing,
            :date_value => Date(2024, 12, 31),
            :plain_date => Date(2024, 12, 31),
        ),
    )
    features = DataFrame(
        NAME=[
            :vector_value,
            :missing_value,
            :nothing_value,
            :absent_value,
            :absent_date,
            :date_value,
            :plain_date,
            :text_value,
        ],
        TYPE=[
            "STRING",
            "STRING",
            "STRING",
            "STRING",
            "DD/MM/YY",
            "DD/MM/YY",
            "STRING",
            "STRING",
        ],
    )

    for subtree in (root, branch)
        layout = MultiScaleTreeGraph._mtg_write_layout(subtree)
        feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(
            subtree, features
        )
        @test MultiScaleTreeGraph._mtg_columnar_write_context(
            layout, feature_columns
        ) isa MultiScaleTreeGraph._MTGColumnarWriteContext

        expected_section = _legacy_mtg_section_for_test(subtree, features)
        actual = mktemp() do path, io
            close(io)
            write_mtg(path, subtree, get_classes(subtree), nothing, features)
            return read(path, String)
        end
        @test _written_mtg_section_for_test(actual) == expected_section
        @test occursin("missing", actual)
        @test occursin("[1, 2]", actual) || subtree === branch
        @test occursin("24/8/2026", actual) || subtree === branch
        @test occursin("2026-08-24", actual) || subtree === branch
    end
end

@testset "Typed writer falls back on mixed columnar stores" begin
    root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:value => 1),
    )
    external = Node(
        20,
        MutableNodeMTG(:/, :External, 1, 1),
        Dict{Symbol,Any}(:value => 2),
    )
    push!(children(root), external)
    features = DataFrame(NAME=[:value], TYPE=["INT"])
    layout = MultiScaleTreeGraph._mtg_write_layout(root)
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(root, features)
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        layout, feature_columns
    ) === nothing

    mktemp() do path, io
        close(io)
        @test_throws ArgumentError write_mtg(
            path, root, get_classes(root), nothing, features
        )
        @test endswith(read(path, String), "MTG:\n")
    end
    mktemp() do path, io
        close(io)
        @test_throws ArgumentError write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=Dict(:value => [10, 20]),
        )
        @test endswith(read(path, String), "MTG:\n")
    end
end

@testset "Typed writer validates every bucket row before streaming" begin
    root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:value => "root"),
    )
    child = Node(
        2,
        root,
        MutableNodeMTG(:<, :Plant, 2, 1),
        Dict{Symbol,Any}(:value => "child"),
    )
    attrs = node_attributes(child)
    store = attrs.ref.store
    bid = store.node_bucket[node_id(child)]
    row = store.node_row[node_id(child)]
    bucket = store.buckets[bid]
    column = bucket.columns[bucket.col_index[:value]]
    resize!(column.data, row - 1)
    resize!(column.data, row)
    @test !isassigned(column.data, row)

    features = DataFrame(NAME=[:value], TYPE=["STRING"])
    layout = MultiScaleTreeGraph._mtg_write_layout(root)
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(root, features)
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        layout, feature_columns
    ) === nothing

    mktemp() do path, io
        close(io)
        @test_throws UndefRefError write_mtg(
            path, root, get_classes(root), nothing, features
        )
        @test endswith(read(path, String), "MTG:\n")
    end
    mktemp() do path, io
        close(io)
        @test_throws UndefRefError write_mtg(
            path,
            root,
            get_classes(root),
            nothing,
            features;
            feature_overrides=Dict(:value => ["projected root", "projected child"]),
        )
        @test endswith(read(path, String), "MTG:\n")
    end
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
    layout = MultiScaleTreeGraph._mtg_write_layout(mtg)
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(mtg, features)
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        layout, feature_columns
    ) isa MultiScaleTreeGraph._MTGColumnarWriteContext
    mktemp() do path, io
        close(io)
        @test_throws MethodError write_mtg(path, mtg, get_classes(mtg), nothing, features)
        @test endswith(read(path, String), "MTG:\n")
    end
end

@testset "Duplicate date mtg_print fails before ENTITY-CODE" begin
    mtg = Node(
        10,
        MutableNodeMTG(:/, :Plant, 1, 1),
        Dict{Symbol,Any}(:mtg_print => missing, :other => 1),
    )
    features = DataFrame(
        NAME=[:mtg_print, :other, :mtg_print],
        TYPE=["STRING", "INT", "DD/MM/YY"],
    )
    feature_columns = MultiScaleTreeGraph._mtg_write_feature_columns(mtg, features)
    @test feature_columns.names == ["mtg_print", "other"]
    @test collect(feature_columns.is_date) == [true, false]
    @test MultiScaleTreeGraph._mtg_columnar_write_context(
        MultiScaleTreeGraph._mtg_write_layout(mtg), feature_columns
    ) isa MultiScaleTreeGraph._MTGColumnarWriteContext

    mktemp() do path, io
        close(io)
        @test_throws MethodError write_mtg(
            path, mtg, get_classes(mtg), nothing, features
        )
        @test endswith(read(path, String), "MTG:\n")
    end
end
