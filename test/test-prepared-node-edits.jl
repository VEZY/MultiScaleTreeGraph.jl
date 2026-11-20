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
