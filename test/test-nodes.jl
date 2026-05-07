# Create a node:

@testset "NodeMTG and MutableNodeMTG" begin
    # Test NodeMTG constructor with all arguments
    node_mtg = MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 2)
    @test node_mtg.link == :/
    @test node_mtg.symbol == :Plant
    @test node_mtg.index == 1
    @test node_mtg.scale == 2

    # Symbol inputs should also be accepted and exposed as strings for compatibility
    node_mtg_sym = MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 2)
    @test node_mtg_sym.link == :/
    @test node_mtg_sym.symbol == :Plant

    # Test NodeMTG constructor with nothing as index
    node_mtg_nothing = MultiScaleTreeGraph.NodeMTG(:/, :Internode, nothing, 3)
    @test node_mtg_nothing.link == :/
    @test node_mtg_nothing.symbol == :Internode
    @test node_mtg_nothing.index == -9999
    @test node_mtg_nothing.scale == 3

    # Test MutableNodeMTG constructor with all arguments
    mutable_node_mtg = MultiScaleTreeGraph.MutableNodeMTG(:+, :Leaf, 2, 4)
    @test mutable_node_mtg.link == :+
    @test mutable_node_mtg.symbol == :Leaf
    @test mutable_node_mtg.index == 2
    @test mutable_node_mtg.scale == 4

    # Test MutableNodeMTG constructor with nothing as index
    mutable_node_mtg_nothing = MultiScaleTreeGraph.MutableNodeMTG(:<, :Apex, nothing, 5)
    @test mutable_node_mtg_nothing.link == :<
    @test mutable_node_mtg_nothing.symbol == :Apex
    @test mutable_node_mtg_nothing.index == -9999
    @test mutable_node_mtg_nothing.scale == 5

    mutable_node_mtg_sym = MultiScaleTreeGraph.MutableNodeMTG(:+, :Leaf, 2, 4)
    @test mutable_node_mtg_sym.link == :+
    @test mutable_node_mtg_sym.symbol == :Leaf

    # Test mutability of MutableNodeMTG
    mutable_node_mtg.link = :<
    mutable_node_mtg.symbol = :Flower
    mutable_node_mtg.index = 3
    mutable_node_mtg.scale = 6
    @test mutable_node_mtg.link == :<
    @test mutable_node_mtg.symbol == :Flower
    mutable_node_mtg.link = :+
    mutable_node_mtg.symbol = :Leaf
    @test mutable_node_mtg.link == :+
    @test mutable_node_mtg.symbol == :Leaf
    @test mutable_node_mtg.index == 3
    @test mutable_node_mtg.scale == 6

    # Test assertions
    @test_throws AssertionError MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, -1)  # scale < 0
    @test_throws AssertionError MultiScaleTreeGraph.NodeMTG(:invalid, :Plant, 1, 1)  # invalid link
    @test_throws AssertionError MultiScaleTreeGraph.MutableNodeMTG(:/, :Plant, 1, -1)  # scale < 0
    @test_throws AssertionError MultiScaleTreeGraph.MutableNodeMTG(:invalid, :Plant, 1, 1)  # invalid link
end

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    @test get_attributes(mtg) == []
    @test node_attributes(mtg) isa MultiScaleTreeGraph.ColumnarAttrs
    @test isempty(node_attributes(mtg))
    @test node_id(mtg) == 1
    @test parent(mtg) === nothing
    @test node_mtg(mtg) == mtg_code
end

@testset "Create node" begin
    mtg_code = MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 1)
    mtg = MultiScaleTreeGraph.Node(mtg_code)
    internode = MultiScaleTreeGraph.Node(
        mtg,
        MultiScaleTreeGraph.NodeMTG(:/, :Internode, 1, 2)
    )
    @test parent(internode) == mtg
    @test node_id(internode) == 2
    @test node_mtg(internode) == MultiScaleTreeGraph.NodeMTG(:/, :Internode, 1, 2)
    @test node_attributes(internode) isa MultiScaleTreeGraph.ColumnarAttrs
    @test isempty(node_attributes(internode))
    @test children(mtg) == [internode]
end

@testset "parent and children setters stay synchronized" begin
    mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG(:/, :Plant, 1, 1))
    first_parent = MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG(:/, :Axis, 1, 2))
    second_parent = MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG(:+, :Axis, 2, 2))
    child = MultiScaleTreeGraph.Node(first_parent, MultiScaleTreeGraph.NodeMTG(:/, :Internode, 1, 3))
    # Simulate a stale duplicate child entry from direct children vector mutation.
    push!(children(first_parent), child)

    reparent!(child, second_parent)
    @test parent(child) === second_parent
    @test !any(n -> n === child, children(first_parent))
    @test count(n -> n === child, children(second_parent)) == 1

    reparent!(child, second_parent)
    @test count(n -> n === child, children(second_parent)) == 1

    reparent!(child, nothing)
    @test parent(child) === nothing
    @test !any(n -> n === child, children(second_parent))

    rechildren!(first_parent, typeof(children(first_parent))([child]))
    @test parent(child) === first_parent
    @test children(first_parent) == [child]

    rechildren!(second_parent, typeof(children(second_parent))([child]))
    @test parent(child) === second_parent
    @test !any(n -> n === child, children(first_parent))
    @test children(second_parent) == [child]

    rechildren!(second_parent, typeof(children(second_parent))())
    @test parent(child) === nothing
    @test isempty(children(second_parent))
end

# From a file:
file = "files/simple_plant.mtg"
mtg = read_mtg(file)

@testset "names" begin
    @test sort!(get_attributes(mtg)) == [:Length, :Width, :XEuler, :dateDeath, :description, :isAlive, :scales, :symbols]
    @test names(mtg) == get_attributes(mtg)
    attrs_no_meta = setdiff(names(mtg), [:description, :symbols, :scales])
    @test sort(names(DataFrame(mtg))[7:end]) == sort(string.(attrs_no_meta))
    mtg_print = sprint(show, mtg)
    @test occursin("Symbols:", mtg_print)
    @test occursin("Scales:", mtg_print)
end


@testset "get attribute value" begin
    @test mtg[1][1][1][:Width] == 0.02
    @test node_attributes(mtg[1][1][1])[:Width] == 0.02
end

@testset "set attribute value" begin
    mtg[1][1][1][:Width] = 1.0
    @test mtg[1][1][1][:Width] == 1.0
end

@testset "siblings" begin
    node = get_node(mtg, 5)
    @test nextsibling(node) == get_node(mtg, 6)
    @test prevsibling(nextsibling(node)) == node
end

@testset "getdescendant" begin
    # This is the function from AbstractTrees.jl
    AbstractTrees.getdescendant(mtg, (1, 1, 1, 2)) == get_node(mtg, 6)
end


@testset "Adding a child with a different MTG encoding type" begin
    mtg = read_mtg(file, MutableNodeMTG)
    VERSION >= v"1.7" && @test_throws "The parent node has an MTG encoding of type `MutableNodeMTG`, but the MTG encoding you provide is of type `NodeMTG`, please make sure they are the same." Node(mtg, NodeMTG(:/, :Branch, 1, 2))
end

@testset "addchild! re-columnarizes when attaching a root subtree" begin
    mtg_a = read_mtg(file)
    mtg_b = read_mtg(file)
    addchild!(mtg_a, mtg_b; force=true)
    @test_nowarn descendants(mtg_a, :Width)
end

@testset "new child node attributes are in the columnar store" begin
    mtg = read_mtg(file)
    leaf = addchild!(mtg, MutableNodeMTG(:+, :Leaf, 999, 2), Dict{Symbol,Any}(:my_attr => 42))
    @test leaf[:my_attr] == 42
    vals = descendants(mtg, :my_attr; ignore_nothing=true)
    @test vals == [42]
end
