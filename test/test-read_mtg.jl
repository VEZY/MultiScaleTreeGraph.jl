mtg = read_mtg("files/simple_plant.mtg", NodeMTG)
classes = get_classes(mtg)
features = get_features(mtg)

@testset "test classes" begin
    @test classes isa MultiScaleTreeGraph.ColumnTable
    @test size(classes) == (5, 5)
    @test String.(classes.SYMBOL) == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test classes.SCALE == [0, 1, 2, 3, 3]
end

@testset "test features" begin
    @test features isa MultiScaleTreeGraph.ColumnTable
    @test size(features) == (5, 2)
    @test sort(collect(features.NAME)) == sort([:Length, :Width, :XEuler, :dateDeath, :isAlive])
end

@testset "test mtg content" begin
    @test length(mtg) == 7
    @test typeof(mtg) == Node{NodeMTG,MultiScaleTreeGraph.ColumnarAttrs}
    @test node_id(mtg) == 1
    @test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs
    @test mtg[:scales] == [0, 1, 2, 3, 3]
    @test mtg[:symbols] == ["Scene", "Individual", "Axis", "Internode", "Leaf"]
    @test node_mtg(mtg) == NodeMTG("/", "Scene", 0, 0)
    @test typeof(children(mtg)) <: Vector{Node{NodeMTG,MultiScaleTreeGraph.ColumnarAttrs}}

    leaf_1 = get_node(mtg, 5)
    @test leaf_1[:Length] == 0.2
    @test leaf_1[:Width] == 0.1
    @test leaf_1[:isAlive] == false
    @test leaf_1[:dateDeath] == Date("2022-08-24")
end

@testset "test mtg mutation" begin
    @test (mtg[:scales] .= [0, 1, 2, 3, 4]) == [0, 1, 2, 3, 4]
    @test MultiScaleTreeGraph.node_mtg!(mtg, MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)) == MultiScaleTreeGraph.NodeMTG(:<, :Leaf, 2, 0)
    child = mtg[1]
    reparent!(child, nothing)
    @test parent(child) === nothing
    @test isempty(children(mtg))
end

@testset "test mtg with empty lines" begin
    mtg1 = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-blanks.mtg")
    @test traverse(mtg1, node_mtg) == traverse(mtg2, node_mtg)
    @test traverse(mtg1, n -> Dict(pairs(node_attributes(n)))) == traverse(mtg2, n -> Dict(pairs(node_attributes(n))))
end

@testset "mtg with several nodes in the same line" begin
    mtg1 = read_mtg("files/simple_plant.mtg")
    mtg2 = read_mtg("files/simple_plant-P1U1.mtg")
    @test traverse(mtg1, node_mtg) == traverse(mtg2, node_mtg)
    @test traverse(mtg1, n -> Dict(pairs(node_attributes(n)))) == traverse(mtg2, n -> Dict(pairs(node_attributes(n))))
end

@testset "mtg with no attributes" begin
    mtg = read_mtg("files/palm.mtg")
    @test names(mtg) == [:scales, :description, :symbols]
    traverse(mtg) do x
        !MultiScaleTreeGraph.isroot(x) && @test isempty(node_attributes(x))
    end
end

@testset "read_mtg parser state is local" begin
    parser_state_names = (:classes, :description, :features, :mtg)
    @test all(name -> !isdefined(MultiScaleTreeGraph, name), parser_state_names)

    files = [
        "files/simple_plant.mtg",
        "files/simple_plant-blanks.mtg",
        "files/simple_plant-P1U1.mtg",
        "files/palm.mtg",
    ]

    for file in files
        mtg = read_mtg(file, NodeMTG)
        @test node_id(mtg) == 1
        @test mtg[:symbols] isa Vector{String}
        @test mtg[:scales] isa Vector{Int}
    end

    @test all(name -> !isdefined(MultiScaleTreeGraph, name), parser_state_names)
end

function _legacy_parse_attrs_for_test(
    node_data, features, feature_names, attr_column_start
)
    length(node_data) < attr_column_start &&
        return MultiScaleTreeGraph.ColumnarAttrs()
    node_data_attr = node_data[attr_column_start:end]
    node_attr = Dict{Symbol,Any}()
    sizehint!(node_attr, length(node_data_attr))
    for i in eachindex(node_data_attr)
        field = node_data_attr[i]
        (field == "" || field == "NA") && continue
        feature_name = feature_names[i]
        typ = features.TYPE[i]
        if typ == "INT"
            node_attr[feature_name] = parse(Int, field)
        elseif typ == "BOOLEAN"
            node_attr[feature_name] = parse(Bool, field)
        elseif typ == "DD/MM/YY"
            node_attr[feature_name] = Date(field, dateformat"d/m/y")
        elseif typ == "REAL" ||
               (typ == "ALPHA" && feature_name in (:Width, :Length))
            node_attr[feature_name] = parse(Float64, field)
        else
            node_attr[feature_name] = field
        end
    end
    return MultiScaleTreeGraph.ColumnarAttrs(node_attr)
end

@testset "section regex fast paths preserve public matching" begin
    @test MultiScaleTreeGraph.issection("prefix CODE : suffix")
    @test MultiScaleTreeGraph.issection("NOTCODE:")
    @test MultiScaleTreeGraph.issection("prefix MTG : suffix", "MTG")
    @test MultiScaleTreeGraph.issection("prefix MTG : suffix", SubString("MTG", 1, 3))
    @test MultiScaleTreeGraph.issection("prefix MTG:", :MTG)
    @test MultiScaleTreeGraph.issection("prefix MTG:", "M.G")
    @test !MultiScaleTreeGraph.issection("prefix code:")
    @test_throws ErrorException MultiScaleTreeGraph.issection("prefix MTG:", "(")
end

@testset "attribute parser preserves values, types, and Dict copy order" begin
    features = MultiScaleTreeGraph.ColumnTable(
        Symbol[:NAME, :TYPE],
        AbstractVector[
            [:count, :alive, :when, :measure, :label, :Width, :skipped],
            ["INT", "BOOLEAN", "DD/MM/YY", "REAL", "STRING", "ALPHA", "STRING"],
        ],
    )
    feature_names = Symbol.(features.NAME)
    node_data = split(
        "/Plant1\t7\ttrue\t24/08/2026\t1.5\tlabel-value\t2.25\tNA",
        "\t",
    )
    expected = _legacy_parse_attrs_for_test(
        node_data, features, feature_names, 2
    )
    actual = MultiScaleTreeGraph.parse_MTG_node_attr(
        node_data, features, feature_names, 2, [17]
    )
    @test collect(pairs(actual)) == collect(pairs(expected))
    @test actual[:count] === 7
    @test actual[:alive] === true
    @test actual[:when] == Date(2026, 8, 24)
    @test actual[:measure] === 1.5
    @test actual[:Width] === 2.25
    @test typeof(actual[:label]) == typeof(expected[:label])
    @test !haskey(actual, :skipped)

    nwide = 40
    wide_names = [Symbol("feature_$i") for i in 1:nwide]
    wide_types = [
        (i % 5 == 1 ? "INT" :
         i % 5 == 2 ? "REAL" :
         i % 5 == 3 ? "BOOLEAN" :
         i % 5 == 4 ? "DD/MM/YY" : "STRING") for i in 1:nwide
    ]
    wide_values = [
        (typ == "INT" ? string(i) :
         typ == "REAL" ? string(i / 10) :
         typ == "BOOLEAN" ? string(isodd(i)) :
         typ == "DD/MM/YY" ? "24/08/2026" : "value-$i") for
        (i, typ) in enumerate(wide_types)
    ]
    wide_features = MultiScaleTreeGraph.ColumnTable(
        Symbol[:NAME, :TYPE], AbstractVector[wide_names, wide_types]
    )
    wide_data = vcat("/Plant1", wide_values)
    wide_expected = _legacy_parse_attrs_for_test(
        wide_data, wide_features, wide_names, 2
    )
    wide_actual = MultiScaleTreeGraph.parse_MTG_node_attr(
        wide_data, wide_features, wide_names, 2, [18]
    )
    @test collect(pairs(wide_actual)) == collect(pairs(wide_expected))
end

@testset "attribute parser diagnostics and row atomicity" begin
    features = MultiScaleTreeGraph.ColumnTable(
        Symbol[:NAME, :TYPE],
        AbstractVector[[:count, :alive], ["INT", "BOOLEAN"]],
    )
    feature_names = Symbol.(features.NAME)
    fields = split("\t/Plant1\tbad\ttrue", "\t")

    conversion_error = try
        MultiScaleTreeGraph._parse_MTG_node_attr_fields(
            fields, features, feature_names, 3, 2, [17]
        )
        nothing
    catch error_
        error_
    end
    @test conversion_error isa ErrorException
    @test conversion_error.msg ==
          "Found issue in the MTG when converting column count with value bad into Integer." *
          " Please check line [17] of the MTG:\n/Plant1\tbad\ttrue"

    forced = MultiScaleTreeGraph._parse_MTG_node_attr_fields(
        fields, features, feature_names, 3, 2, [17]; force=true
    )
    @test !haskey(forced, :count)
    @test forced[:alive] === true

    too_many = try
        MultiScaleTreeGraph.parse_MTG_node_attr(
            ["/Plant1", "1", ""],
            MultiScaleTreeGraph.ColumnTable(
                Symbol[:NAME, :TYPE], AbstractVector[[:count], ["INT"]]
            ),
            [:count],
            2,
            [18],
        )
        nothing
    catch error_
        error_
    end
    @test too_many isa ErrorException
    @test endswith(too_many.msg, "/Plant1\t1\t")

    classes = MultiScaleTreeGraph.ColumnTable(
        Symbol[:SYMBOL, :SCALE], AbstractVector[["Plant"], [1]]
    )
    tree_dict = Dict{Int,Node}()
    line = [17]
    l = ["\t/Plant1\tbad\ttrue"]
    last_node_column = zeros(Integer, 2)
    last_node_column[1] = 1
    next_node_id = [1]
    @test_throws ErrorException MultiScaleTreeGraph.parse_line_to_node!(
        tree_dict,
        l,
        line,
        3,
        last_node_column,
        next_node_id,
        MutableNodeMTG,
        features,
        feature_names,
        classes,
    )
    @test isempty(tree_dict)
    @test next_node_id == [1]
    @test last_node_column == [1, 0]
end
