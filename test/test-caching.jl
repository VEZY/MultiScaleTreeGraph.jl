file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

@testset "caching" begin
    mtg = read_mtg(file)

    # Cache all leaf nodes:
    cache_nodes!(mtg, symbol=:Leaf)

    # Cached nodes are stored in the traversal_cache field of the mtg (here, the two leaves):
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_78a6583f9e4f630383e9f8bdcd9d1bc5d1a6e540"] == [get_node(mtg, 5), get_node(mtg, 7)]
    # cache_nodes!(mtg, is_leaf)
    @test traverse(mtg, symbol, symbol=:Leaf) == [:Leaf, :Leaf]

    # Modifying the mtg via the cache:
    traverse!(mtg, symbol=:Leaf) do x
        x[:x] = node_id(x)
    end
    @test [get_node(mtg, 5)[:x], get_node(mtg, 7)[:x]] == [5, 7]

    # Cache based on another symbol:
    cache_nodes!(mtg, symbol=:Internode)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 2
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_8b5413ba4d893f432a65c83e5bd53e5839e22a5d"]) == 2
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_8b5413ba4d893f432a65c83e5bd53e5839e22a5d"] == [get_node(mtg, 4), get_node(mtg, 6)]

    # Cache all nodes:
    cache_nodes!(mtg)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 3
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ab6319555fc952f43d7d80401e3f1f6124fd6644"]) == length(mtg)

    # Cache with 2 filters:
    cache_nodes!(mtg, symbol=:Internode, link=:<)
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)) == 4
    @test length(MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ede6d4d594437acaca56712d385c03e014ff1b4b"]) == 1
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)["_cache_ede6d4d594437acaca56712d385c03e014ff1b4b"] == [get_node(mtg, 6)]

    traverse!(mtg, symbol=:Internode, link=:<) do x
        x[:x] = node_id(x) + 2
    end
    @test get_node(mtg, 6)[:x] == (get_node(mtg, 6) |> node_id) + 2
    @test get_node(mtg, 6)[:x] == 8

    # Re-setting the :x attribute to the node id:
    traverse!(mtg) do x
        x[:x] = node_id(x)
    end
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]

    # Manually put a node in the cache and use it for computation:
    # Carefull, this is just for testing purpose, it is not recommended to do this in a real case.
    no_filter_cache_name = MultiScaleTreeGraph.cache_name(nothing, nothing, nothing, true, nothing)
    MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name] = [MultiScaleTreeGraph.Node(MutableNodeMTG(:/, :Test, 1, 0), Dict{Symbol,Any}(:a => 1))]

    # Test if the cache is used:
    traverse!(mtg) do x
        x[:x] = node_id(x) + 4
    end
    # NB: if the cache is used here, it will only compute for the node we just created instead
    # of all the nodes in the mtg.

    # Check that the node in the cache was modified:
    @test MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name][1][:x] == node_id(MultiScaleTreeGraph.node_traversal_cache(mtg)[no_filter_cache_name][1]) + 4

    # Check that the nodes of the MTG where not modified:
    @test [node[:x] for node in AbstractTrees.PreOrderDFS(mtg)] == [1, 2, 3, 4, 5, 6, 7]
end

@testset "structural mutations invalidate traversal caches" begin
    mtg = read_mtg(file)
    internode = get_node(mtg, 4)
    source_encoding = node_mtg(internode)
    new_parent = addchild!(
        parent(internode),
        MutableNodeMTG(
            :+,
            source_encoding.symbol,
            source_encoding.index + 100,
            source_encoding.scale,
        ),
        Dict{Symbol,Any}(),
    )

    cache_nodes!(mtg)
    cache_nodes!(internode)
    @test length(MultiScaleTreeGraph._node_store(mtg).subtree_index.traversal_cache_nodes) == 2
    added = addchild!(internode, MutableNodeMTG(:+, :Leaf, 2, 3), Dict{Symbol,Any}(:AfterCache => 123))

    @test MultiScaleTreeGraph._maybe_traversal_cache(mtg) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(internode) === nothing
    @test MultiScaleTreeGraph._node_store(mtg).subtree_index.traversal_cache_nodes === nothing
    @test added in traverse(mtg, node -> node)
    @test :AfterCache in get_features(mtg).NAME

    old_parent = internode
    cache_nodes!(mtg)
    cache_nodes!(old_parent)
    cache_nodes!(new_parent)
    reparent!(added, new_parent)

    @test MultiScaleTreeGraph._maybe_traversal_cache(mtg) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(old_parent) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(new_parent) === nothing
    @test added in traverse(new_parent, node -> node)
    @test !(added in traverse(old_parent, node -> node))

    cache_nodes!(mtg)
    prune!(added)
    @test MultiScaleTreeGraph._maybe_traversal_cache(mtg) === nothing
    @test !(added in traverse(mtg, node -> node))

    deleted_mtg = read_mtg(file)
    cache_nodes!(deleted_mtg)
    delete_node!(get_node(deleted_mtg, 5))
    @test MultiScaleTreeGraph._maybe_traversal_cache(deleted_mtg) === nothing

    sibling_mtg = read_mtg(file)
    cache_nodes!(sibling_mtg)
    old_length = length(sibling_mtg)
    insert_sibling!(
        get_node(sibling_mtg, 5),
        MutableNodeMTG(:+, :Leaf, 2, 3),
        _ -> Dict{Symbol,Any}(:SiblingAfterCache => 456)
    )
    @test MultiScaleTreeGraph._maybe_traversal_cache(sibling_mtg) === nothing
    @test length(sibling_mtg) == old_length + 1
    @test :SiblingAfterCache in get_features(sibling_mtg).NAME

    pruned_cache_mtg = read_mtg(file)
    pruned_root = get_node(pruned_cache_mtg, 4)
    cached_descendant = get_node(pruned_cache_mtg, 6)
    cache_nodes!(cached_descendant)
    @test MultiScaleTreeGraph._node_store(pruned_cache_mtg).subtree_index.traversal_cache_nodes !== nothing
    prune!(pruned_root)
    @test MultiScaleTreeGraph._maybe_traversal_cache(cached_descendant) === nothing
    @test MultiScaleTreeGraph._node_store(pruned_cache_mtg).subtree_index.traversal_cache_nodes === nothing

    cycle_mtg = read_mtg(file)
    cycle_ancestor = get_node(cycle_mtg, 4)
    cycle_descendant = get_node(cycle_mtg, 6)
    cycle_parent_ids = [
        node_id(node) => (parent(node) === nothing ? nothing : node_id(parent(node)))
        for node in traverse(cycle_mtg, node -> node)
    ]
    @test_throws ArgumentError reparent!(cycle_ancestor, cycle_descendant)
    @test [
        node_id(node) => (parent(node) === nothing ? nothing : node_id(parent(node)))
        for node in traverse(cycle_mtg, node -> node)
    ] == cycle_parent_ids

    indexed_mtg = read_mtg(file)
    indexed_parent = get_node(indexed_mtg, 4)
    replaced = indexed_parent[1]
    replacement = Node(
        max_id(indexed_mtg) + 1,
        MutableNodeMTG(:+, :Leaf, 200, scale(replaced)),
        Dict{Symbol,Any}(:IndexedAfterCache => true),
    )
    cache_nodes!(indexed_mtg)
    indexed_parent[1] = replacement
    @test MultiScaleTreeGraph._maybe_traversal_cache(indexed_mtg) === nothing
    @test parent(replacement) === indexed_parent
    @test parent(replaced) === nothing
    @test replacement in traverse(indexed_mtg, node -> node)
    @test !(replaced in traverse(indexed_mtg, node -> node))

    rechildren_mtg = read_mtg(file)
    rechildren_parent = get_node(rechildren_mtg, 4)
    independent_child = Node(
        max_id(rechildren_mtg) + 1,
        MutableNodeMTG(:+, :IndependentChild, 1, 3),
        Dict{Symbol,Any}(),
    )
    rechildren!(rechildren_parent, [independent_child])
    @test MultiScaleTreeGraph._node_store(independent_child) ===
          MultiScaleTreeGraph._node_store(rechildren_parent)
    cache_nodes!(rechildren_parent)
    addchild!(
        independent_child,
        MutableNodeMTG(:+, :CacheChild, 1, 4),
        Dict{Symbol,Any}(),
    )
    @test MultiScaleTreeGraph._maybe_traversal_cache(rechildren_parent) === nothing

    function assert_insert_cache_invalidation!(inserted)
        @test MultiScaleTreeGraph._maybe_traversal_cache(inserted) === nothing
        cache_nodes!(inserted)
        registry = MultiScaleTreeGraph._node_store(inserted).subtree_index.traversal_cache_nodes
        @test registry !== nothing
        @test MultiScaleTreeGraph._traversal_cache_registered(
            MultiScaleTreeGraph._node_store(inserted), inserted
        )
        child = addchild!(
            inserted,
            MutableNodeMTG(:+, :CacheChild, 1, scale(inserted) + 1),
            Dict{Symbol,Any}(),
        )
        @test MultiScaleTreeGraph._maybe_traversal_cache(inserted) === nothing
        @test child in traverse(inserted, node -> node)
    end

    inserted_parent_mtg = read_mtg(file)
    parent_target = get_node(inserted_parent_mtg, 4)
    insert_parent!(
        parent_target,
        MutableNodeMTG(:/, :InsertedParent, 1, scale(parent_target)),
    )
    assert_insert_cache_invalidation!(parent(parent_target))

    inserted_root_mtg = read_mtg(file)
    insert_parent!(
        inserted_root_mtg,
        MutableNodeMTG(:/, :InsertedRoot, 1, scale(inserted_root_mtg)),
    )
    assert_insert_cache_invalidation!(parent(inserted_root_mtg))

    inserted_sibling_mtg = read_mtg(file)
    sibling_id = max_id(inserted_sibling_mtg) + 1
    insert_sibling!(
        get_node(inserted_sibling_mtg, 5),
        MutableNodeMTG(:+, :InsertedSibling, 1, 3),
    )
    assert_insert_cache_invalidation!(get_node(inserted_sibling_mtg, sibling_id))

    inserted_generation_mtg = read_mtg(file)
    generation_target = get_node(inserted_generation_mtg, 4)
    generation_id = max_id(inserted_generation_mtg) + 1
    insert_generation!(
        generation_target,
        MutableNodeMTG(:/, :InsertedGeneration, 1, scale(generation_target)),
    )
    assert_insert_cache_invalidation!(get_node(inserted_generation_mtg, generation_id))

    raw_parent = Node(
        1,
        MutableNodeMTG(:/, :RawRoot, 1, 0),
        Dict{Symbol,Any}(),
    )
    RawNode = typeof(raw_parent)
    raw_attrs = MultiScaleTreeGraph.ColumnarAttrs()
    MultiScaleTreeGraph.bind_columnar_child!(
        node_attributes(raw_parent),
        raw_attrs,
        2,
        :RawChild,
    )
    raw_cache = Dict{String,Vector{RawNode}}("raw-cache" => RawNode[raw_parent])
    raw_child = RawNode(
        2,
        raw_parent,
        RawNode[],
        MutableNodeMTG(:+, :RawChild, 1, 1),
        raw_attrs,
        raw_cache,
    )
    raw_registry = MultiScaleTreeGraph._node_store(raw_parent).subtree_index.traversal_cache_nodes
    @test raw_registry !== nothing
    @test MultiScaleTreeGraph._traversal_cache_registered(
        MultiScaleTreeGraph._node_store(raw_parent), raw_child
    )
    addchild!(raw_parent, raw_child)
    @test MultiScaleTreeGraph._maybe_traversal_cache(raw_child) === nothing
    @test MultiScaleTreeGraph._node_store(raw_parent).subtree_index.traversal_cache_nodes === nothing
    converted_raw = RawNode(
        Int32(3),
        nothing,
        RawNode[],
        MutableNodeMTG(:/, :ConvertedRaw, 1, 0),
        MultiScaleTreeGraph.ColumnarAttrs(),
        Dict(),
    )
    @test node_id(converted_raw) == 3
    @test getfield(converted_raw, :traversal_cache) isa Dict{String,Vector{RawNode}}

    nonroot_columnar_mtg = read_mtg(file)
    nonroot_columnar_branch = get_node(nonroot_columnar_mtg, 4)
    cache_nodes!(nonroot_columnar_mtg)
    columnarize!(nonroot_columnar_branch)
    @test MultiScaleTreeGraph._node_store(nonroot_columnar_branch) ===
          MultiScaleTreeGraph._node_store(nonroot_columnar_mtg)
    addchild!(
        nonroot_columnar_branch,
        max_id(nonroot_columnar_mtg) + 1,
        MutableNodeMTG(:+, :ColumnarizedChild, 1, scale(nonroot_columnar_branch) + 1),
        Dict{Symbol,Any}(:NonrootColumnarAfterCache => true),
    )
    @test MultiScaleTreeGraph._maybe_traversal_cache(nonroot_columnar_mtg) === nothing
    @test :NonrootColumnarAfterCache in get_features(nonroot_columnar_mtg).NAME

    id_root = Node(1, MutableNodeMTG(:/, :IdRoot, 1, 0), Dict{Symbol,Any}())
    id_high = addchild!(
        id_root,
        100,
        MutableNodeMTG(:+, :IdHigh, 1, 1),
        Dict{Symbol,Any}(),
    )
    reparent!(id_high, nothing)
    id_store = MultiScaleTreeGraph._node_store(id_root)
    @test MultiScaleTreeGraph._node_store(id_high) === id_store
    @test max_id(id_root) == 1
    @test id_store.max_node_id == 100
    @test new_id(id_root) == 101
    id_root_new = Node(id_root, MutableNodeMTG(:+, :IdRootNew, 1, 1))
    id_high_new = Node(id_high, MutableNodeMTG(:+, :IdHighNew, 1, 2))
    @test node_id(id_root_new) == 101
    @test node_id(id_high_new) == 102
    @test id_store.max_node_id == 102

    source_tree = Node(
        100,
        MutableNodeMTG(:/, :SourceRoot, 1, 0),
        Dict{Symbol,Any}(),
    )
    source_parent = addchild!(
        source_tree,
        101,
        MutableNodeMTG(:+, :SourceParent, 1, 1),
        Dict{Symbol,Any}(),
    )
    moved_subtree = addchild!(
        source_parent,
        102,
        MutableNodeMTG(:+, :MovedSubtree, 1, 2),
        Dict{Symbol,Any}(:MovedValue => 102),
    )
    moved_descendant = addchild!(
        moved_subtree,
        103,
        MutableNodeMTG(:+, :MovedDescendant, 1, 3),
        Dict{Symbol,Any}(:MovedDescendantValue => 103),
    )
    target_tree = Node(
        1,
        MutableNodeMTG(:/, :TargetRoot, 1, 0),
        Dict{Symbol,Any}(),
    )
    target_parent = addchild!(
        target_tree,
        2,
        MutableNodeMTG(:+, :TargetParent, 1, 1),
        Dict{Symbol,Any}(),
    )
    source_store = MultiScaleTreeGraph._node_store(source_tree)
    target_store = MultiScaleTreeGraph._node_store(target_tree)
    @test source_store.max_node_id == 103
    @test target_store.max_node_id == 2
    cache_nodes!(source_tree)
    cache_nodes!(moved_subtree)
    cache_nodes!(moved_descendant)
    cache_nodes!(target_tree)
    reparent!(moved_subtree, target_parent)
    @test MultiScaleTreeGraph._maybe_traversal_cache(source_tree) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(moved_subtree) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(moved_descendant) !== nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(target_tree) === nothing
    @test parent(moved_subtree) === target_parent
    @test !(moved_subtree in traverse(source_tree, identity, type=typeof(source_tree)))
    @test moved_subtree in traverse(target_tree, identity, type=typeof(target_tree))
    @test MultiScaleTreeGraph._node_store(moved_subtree) === target_store
    @test MultiScaleTreeGraph._node_store(moved_descendant) === target_store
    @test source_store.node_bucket[node_id(moved_subtree)] == 0
    @test source_store.node_bucket[node_id(moved_descendant)] == 0
    @test source_store.max_node_id == 101
    @test target_store.max_node_id == 103
    @test source_store.subtree_index.traversal_cache_nodes === nothing
    cache_nodes!(target_tree)
    addchild!(
        moved_descendant,
        104,
        MutableNodeMTG(:+, :MovedChild, 1, 4),
        Dict{Symbol,Any}(:CrossStoreAfterCache => true),
    )
    @test MultiScaleTreeGraph._maybe_traversal_cache(target_tree) === nothing
    @test MultiScaleTreeGraph._maybe_traversal_cache(moved_descendant) === nothing
    @test :CrossStoreAfterCache in get_features(target_tree).NAME
    @test target_store.max_node_id == 104

    conflict_tree = Node(
        1,
        MutableNodeMTG(:/, :ConflictRoot, 1, 0),
        Dict{Symbol,Any}(),
    )
    conflict_old_child = addchild!(
        conflict_tree,
        2,
        MutableNodeMTG(:+, :ConflictChild, 1, 1),
        Dict{Symbol,Any}(),
    )
    conflicting_replacement = Node(
        2,
        MutableNodeMTG(:/, :ReplacementRoot, 1, 0),
        Dict{Symbol,Any}(),
    )
    conflict_children_before = copy(children(conflict_tree))
    conflict_store_before = MultiScaleTreeGraph._node_store(conflict_tree)
    replacement_store_before = MultiScaleTreeGraph._node_store(conflicting_replacement)
    @test_throws ArgumentError conflict_tree[1] = conflicting_replacement
    @test children(conflict_tree) == conflict_children_before
    @test parent(conflict_old_child) === conflict_tree
    @test parent(conflicting_replacement) === nothing
    @test MultiScaleTreeGraph._node_store(conflict_tree) === conflict_store_before
    @test MultiScaleTreeGraph._node_store(conflicting_replacement) === replacement_store_before

    rechildren_target = Node(
        1,
        MutableNodeMTG(:/, :RechildrenTarget, 1, 0),
        Dict{Symbol,Any}(),
    )
    rechildren_old = addchild!(
        rechildren_target,
        2,
        MutableNodeMTG(:+, :RechildrenOld, 1, 1),
        Dict{Symbol,Any}(),
    )
    incoming_a = Node(
        100,
        MutableNodeMTG(:/, :IncomingA, 1, 0),
        Dict{Symbol,Any}(),
    )
    incoming_b = Node(
        100,
        MutableNodeMTG(:/, :IncomingB, 1, 0),
        Dict{Symbol,Any}(),
    )
    rechildren_before = copy(children(rechildren_target))
    target_store_before = MultiScaleTreeGraph._node_store(rechildren_target)
    incoming_a_store_before = MultiScaleTreeGraph._node_store(incoming_a)
    incoming_b_store_before = MultiScaleTreeGraph._node_store(incoming_b)
    @test_throws ArgumentError rechildren!(rechildren_target, [incoming_a, incoming_b])
    @test children(rechildren_target) == rechildren_before
    @test parent(rechildren_old) === rechildren_target
    @test parent(incoming_a) === nothing
    @test parent(incoming_b) === nothing
    @test MultiScaleTreeGraph._node_store(rechildren_target) === target_store_before
    @test MultiScaleTreeGraph._node_store(incoming_a) === incoming_a_store_before
    @test MultiScaleTreeGraph._node_store(incoming_b) === incoming_b_store_before

    relabelled_source = Node(
        20,
        MutableNodeMTG(:/, :RelabelledSource, 1, 0),
        Dict{Symbol,Any}(:SourceValue => 20),
    )
    relabelled_child = addchild!(
        relabelled_source,
        1,
        MutableNodeMTG(:+, :RelabelledChild, 1, 1),
        Dict{Symbol,Any}(:ChildValue => 1),
    )
    relabelled_descendant = addchild!(
        relabelled_child,
        2,
        MutableNodeMTG(:+, :RelabelledDescendant, 1, 2),
        Dict{Symbol,Any}(:DescendantValue => 2),
    )
    relabelled_source_store = MultiScaleTreeGraph._node_store(relabelled_source)
    setfield!(relabelled_source, :id, 1)
    setfield!(relabelled_child, :id, 2)
    setfield!(relabelled_descendant, :id, 3)

    relabelled_target = Node(
        50,
        MutableNodeMTG(:/, :RelabelledTarget, 1, 0),
        Dict{Symbol,Any}(),
    )
    relabelled_target_parent = addchild!(
        relabelled_target,
        51,
        MutableNodeMTG(:+, :RelabelledTargetParent, 1, 1),
        Dict{Symbol,Any}(),
    )
    relabelled_target_store = MultiScaleTreeGraph._node_store(relabelled_target)
    @test relabelled_source_store.max_node_id == 20
    @test relabelled_target_store.max_node_id == 51

    addchild!(relabelled_target_parent, relabelled_source)

    @test parent(relabelled_source) === relabelled_target_parent
    @test [node_id(node) for node in traverse(relabelled_source, identity)] == [1, 2, 3]
    @test relabelled_source[:SourceValue] == 20
    @test relabelled_child[:ChildValue] == 1
    @test relabelled_descendant[:DescendantValue] == 2
    @test all(
        node -> MultiScaleTreeGraph._node_store(node) === relabelled_target_store,
        traverse(relabelled_source, identity),
    )
    @test [
        MultiScaleTreeGraph.node_attributes(node).ref.node_id
        for node in traverse(relabelled_source, identity)
    ] == [1, 2, 3]
    @test all(
        old_id -> relabelled_source_store.node_bucket[old_id] == 0,
        (20, 1, 2),
    )
    @test relabelled_source_store.max_node_id == 0
    @test relabelled_target_store.max_node_id == 51
end
