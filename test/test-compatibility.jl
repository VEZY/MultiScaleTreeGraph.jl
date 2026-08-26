@testset "deprecated Julia entry points" begin
    legacy_node_call = () -> Node("legacy name", 7, NodeMTG(:/, :Plant, 1, 1), (x=1,))
    legacy_node = if Base.JLOptions().depwarn == 0
        legacy_node_call()
    else
        @test_logs (:warn, r"Node\(name::String.*is deprecated") legacy_node_call()
    end
    @test node_id(legacy_node) == 7
    @test symbol(legacy_node) == :Plant
    @test legacy_node[:x] == 1

    raw_attributes = Dict{Symbol,Any}(:x => 2)
    raw_cache = Dict{String,Vector{Node{NodeMTG,typeof(raw_attributes)}}}()
    legacy_raw_call = () -> Node(
        "legacy name",
        8,
        nothing,
        nothing,
        NodeMTG(:/, :Plant, 1, 1),
        raw_attributes,
        raw_cache,
    )
    legacy_raw = if Base.JLOptions().depwarn == 0
        legacy_raw_call()
    else
        @test_logs (:warn, r"Node\(name::String.*is deprecated") legacy_raw_call()
    end
    @test node_id(legacy_raw) == 8
    @test isempty(children(legacy_raw))
    @test legacy_raw[:x] == 2

    mtg = read_mtg("files/simple_plant.mtg")
    target = mtg[1][1]
    template = MutableNodeMTG(:/, :Shoot, 0, 1)
    previous_max = max_id(mtg)
    maxid = [previous_max]
    legacy_insert_call = () -> MultiScaleTreeGraph.insert_node!(target, template, maxid)
    returned = if Base.JLOptions().depwarn == 0
        legacy_insert_call()
    else
        @test_logs (:warn, r"insert_node!.*is deprecated") legacy_insert_call()
    end
    @test returned === target
    @test maxid == [previous_max + 1]
    @test parent(target) !== nothing
    @test node_id(parent(target)) == previous_max + 1

    type_mtg = read_mtg("files/simple_plant.mtg")
    width_all = [nothing, nothing, 0.02, 0.1, 0.02, 0.1]
    leaf_node = get_node(type_mtg, 5)
    legacy_descendants_call = () -> descendants(type_mtg, :Width; type=Union{Nothing,Float64})
    legacy_ancestors_call = () -> ancestors(leaf_node, :Width; type=Union{Nothing,Float64})
    legacy_descendants_result, legacy_ancestors_result = if Base.JLOptions().depwarn == 0
        (legacy_descendants_call(), legacy_ancestors_call())
    else
        descendants_result = @test_logs (:warn, r"Keyword argument `type` in `descendants` is deprecated") legacy_descendants_call()
        ancestors_result = @test_logs (:warn, r"Keyword argument `type` in `ancestors` is deprecated") legacy_ancestors_call()
        (descendants_result, ancestors_result)
    end
    @test legacy_descendants_result == width_all
    @test legacy_ancestors_result == reverse([nothing, nothing, nothing, 0.02])
end

@testset "Base names are extended, not re-exported" begin
    removed_exports = (:print, :show, :length, :iterate, :append!, :names, Symbol("=="))
    @test all(name -> name ∉ Base.names(MultiScaleTreeGraph), removed_exports)
end
