@testset "Prepared edits on the original columnar tree" begin
    root = Node(1, NodeMTG(:/, :Plant, 1, 1), (rank=0,))
    other = Node(1, NodeMTG(:/, :Plant, 1, 1), (rank=0,))
    plan = prepare_node_edits(root)
    label = NodeMTG(:+, :Leaf, 1, 2)
    @test_throws ArgumentError addchild!(plan, other, 2, label)
    @test_throws ArgumentError addchild!(plan, root, 2, label, (rank=1, weight=1.0,))
    @test isempty(children(root))
    @test get_node(root, 2) === nothing
    leaf = addchild!(plan, root, 2, label)
    @test isempty(node_attributes(leaf))
    @test attribute(plan, leaf, :rank, -1) === -1
    child = addchild!(plan, leaf, 3, NodeMTG(:<, :Leaf, 2, 2), (rank=7, tag=nothing))
    @test attribute(plan, child, :rank) === 7
    @test attribute(plan, child, :tag, -1) === nothing
    @test_throws ArgumentError addchild!(plan, root, 3, label)
    @test_throws ArgumentError delete_node!(plan, other)
    @test delete_node!(plan, leaf) === root
    @test only(children(root)) === child
    @test parent(child) === root
    @test link(child) === :+
    @test attribute(child, :rank) === 7
    @test get_node(root, 2) === nothing
    @test_throws ArgumentError attribute(plan, leaf, :rank)
    @test_throws ArgumentError addchild!(plan, root, 4, label, (rank="four",))
    @test get_node(root, 4) === nothing
    @test only(children(root)) === child
end

@testset "Refresh a prepared tree after declaring a column" begin
    root = Node(1, NodeMTG(:/, :Plant, 1, 1), (;))
    plan = prepare_node_edits(root)
    label = NodeMTG(:+, :Leaf, 1, 2)
    first_leaf = addchild!(plan, root, 2, label)
    add_column!(root, :Leaf, :area, Float32; default=0f0)
    @test_throws ArgumentError addchild!(plan, root, 3, label)
    @test_throws ArgumentError delete_node!(plan, first_leaf)
    @test_throws ArgumentError attribute(plan, first_leaf, :area)
    @test only(children(root)) === first_leaf
    refreshed = prepare_node_edits(first_leaf)
    second_leaf = addchild!(refreshed, root, 3, label, (area=0.5f0,))
    @test attribute(refreshed, first_leaf, :area) === 0f0
    @test attribute(refreshed, second_leaf, :area) === 0.5f0
    @test attribute(refreshed, second_leaf, :area; default=0.0) === attribute(second_leaf, :area, 0.0) === 0.5
    @test_throws InexactError attribute(refreshed, second_leaf, :area, 0)
    @test delete_node!(refreshed, first_leaf) === root
    @test only(children(root)) === second_leaf
end

@testset "Declared attribute types include organ symbols without nodes" begin
    root = Node(1, NodeMTG(:/, :Plant, 1, 1), (;))
    @test attribute_type(root, :kind) === Union{}
    add_column!(root, :Leaf, :kind, Int; default=3)
    add_column!(root, :Flower, :kind, Symbol; default=:open)
    add_column!(root, :Plant, :note, String; default="plot")
    @test isempty(children(root))
    @test attribute_type(root, :kind) === Union{Int,Symbol}
    leaf = addchild!(prepare_node_edits(root), root, 2, NodeMTG(:+, :Leaf, 1, 2))
    @test attribute_type(leaf, :note) === String
    @test attribute_type(leaf, :kind) === Union{Int,Symbol}
    drop_column!(root, :Leaf, :kind)
    @test attribute_type(leaf, :kind) === Symbol
end
