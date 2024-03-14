
@testset "test insert_parent!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
    max_node_id = [max_id(mtg)]
    length_before = length(mtg)

    insert_parent!(mtg[1][1], template, node -> typeof(node_attributes(node))(), max_node_id) # providing max_id

    @test length(mtg) == length_before + 1
    @test link(mtg[1][1]) == template.link
    @test symbol(mtg[1][1]) == template.symbol
    @test index(mtg[1][1]) == template.index
    @test scale(mtg[1][1]) == template.scale
    @test node_id(mtg[1][1]) == max_node_id[1]  # max_id is already incremented, but we added one more node

    mtg_2 = read_mtg("files/simple_plant.mtg")
    insert_parent!(mtg_2[1][1], template) # not providing max_id

    @test mtg_2 == mtg
    @test mtg_2[1][1] == mtg[1][1]

    mtg_3 = read_mtg("files/simple_plant.mtg")
    # Provide the template as a function (should take the previous template from its child):
    insert_parent!(
        mtg_3[1][1],
        x -> (
            link=link(x[1]),
            symbol=symbol(x[1]),
            index=index(x[1]),
            scale=scale(x[1]),
        )
    ) # not providing max_id

    @test mtg_3 == mtg
    @test node_mtg(mtg_3[1][1]) == node_mtg(mtg_3[1][1][1][1])


    # Test inserting a new root:
    mtg_4 = read_mtg("files/simple_plant.mtg")
    insert_parent!(mtg_4, template)

    @test get_root(mtg_4) |> node_mtg == template

    # Test inserting with attributes:

    mtg_5 = read_mtg("files/simple_plant.mtg")

    # Just a constant value:
    insert_parent!(mtg_5, template, x -> Dict{Symbol,Any}(:Length => 1,))

    # Using descendants values
    insert_parent!(
        get_root(mtg_5),
        template,
        node -> Dict{Symbol,Any}(:Total_Length => sum(descendants(node, :Length, ignore_nothing=true)),)
    )

    mtg_5 = get_root(mtg_5)

    @test node_mtg(mtg_5) == template
    @test mtg_5[:Total_Length] ≈ 0.6
    @test mtg_5[1][:Length] == 1
end


@testset "test insert_parents!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MutableNodeMTG("/", "Shoot", 0, 1)
    length_before = length(mtg)
    insert_parents!(
        mtg,
        template,
        node -> Dict{Symbol,Any}(:Total_Length => round(sum(descendants(node, :Length, ignore_nothing=true)), digits=1),),
        scale=2
    )

    @test length(mtg) == length_before + 1
    @test node_mtg(mtg[1][1]) == template
    @test node_id(mtg[1][1]) == 8
    @test node_attributes(mtg[1][1]) == Dict{Symbol,Any}(:Total_Length => 0.6)
end


@testset "test insert_child!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
    max_node_id = [max_id(mtg)]
    length_before = length(mtg)

    mtg_orig = deepcopy(mtg)

    insert_child!(mtg[1], template, node -> typeof(node_attributes(node))(), max_node_id) # providing max_id
    insert_parent!(mtg_orig[1][1], template)

    @test length(mtg) == length(mtg_orig)
    @test mtg_orig[1][1] == mtg_orig[1][1]
end


@testset "test insert_children!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MutableNodeMTG("/", "Rachis", 0, 4)
    length_before = length(mtg)
    insert_children!(mtg, template, symbol="Leaf")

    @test length(mtg) == length_before + 2

    @test get_node(mtg, 8) |> node_mtg == template
    @test get_node(mtg, 9) |> node_mtg == template
end


@testset "test insert_generation!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MultiScaleTreeGraph.MutableNodeMTG("/", "Shoot", 0, 1)
    max_node_id = [max_id(mtg)]
    length_before = length(mtg)

    mtg_orig = deepcopy(mtg)

    insert_child!(mtg[1], template, node -> typeof(node_attributes(node))(), max_node_id) # providing max_id
    insert_generation!(mtg_orig[1], template)

    @test length(mtg) == length(mtg_orig)
    @test mtg_orig[1][1] == mtg_orig[1][1]
end

@testset "test insert_generations!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MutableNodeMTG("/", "Rachis", 0, 4)
    length_before = length(mtg)
    insert_generations!(mtg, template, symbol="Internode")

    @test length(mtg) == length_before + 2

    @test get_node(mtg, 8) |> node_mtg == template
    @test get_node(mtg, 9) |> node_mtg == template
end


@testset "test insert_sibling!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MultiScaleTreeGraph.MutableNodeMTG("/", "Individual", 0, 1)
    max_node_id = [max_id(mtg)]
    length_before = length(mtg)

    mtg_orig = deepcopy(mtg)

    insert_child!(mtg, template, node -> typeof(node_attributes(node))(), max_node_id) # providing max_id
    insert_sibling!(mtg_orig[1], template)

    @test length(mtg) == length(mtg_orig)
    @test mtg_orig[2] == mtg_orig[2]
end

@testset "test insert_siblings!" begin
    mtg = read_mtg("files/simple_plant.mtg")
    template = MutableNodeMTG("+", "Leaf", 0, 3)
    length_before = length(mtg)
    # Add a new leaf at each leaf node:
    insert_siblings!(mtg, template, symbol="Leaf")

    @test length(mtg) == length_before + 2

    @test get_node(mtg, 8) |> node_mtg == template
    @test get_node(mtg, 9) |> node_mtg == template
end
