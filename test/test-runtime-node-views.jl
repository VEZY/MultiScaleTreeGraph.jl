using Test
using MultiScaleTreeGraph
using AbstractTrees

module RuntimeNodeHandleFixture
using MultiScaleTreeGraph
import AbstractTrees

mutable struct Store
    parents::Vector{Int}
    child_ids::Vector{Vector{Int}}
    encodings::Vector{NodeMTG}
    values::Vector{Dict{Symbol,Any}}
    live::BitVector
end
struct Handle <: AbstractMTGNode
    store::Store
    id::Int
end

function checked(node::Handle)
    node.store.live[node.id] || throw(ArgumentError("removed test handle"))
    return node.store
end
MultiScaleTreeGraph.node_id(node::Handle) = node.id
MultiScaleTreeGraph.node_mtg(node::Handle) = checked(node).encodings[node.id]
MultiScaleTreeGraph.node_attributes(node::Handle) = checked(node).values[node.id]
Base.parent(node::Handle) = begin
    store = checked(node)
    id = store.parents[node.id]
    iszero(id) ? nothing : Handle(store, id)
end
AbstractTrees.children(node::Handle) = [Handle(checked(node), id) for id in checked(node).child_ids[node.id]]

function MultiScaleTreeGraph.add_node!(parent::Handle, id::Int, encoding::NodeMTG, values)
    store = checked(parent)
    id == length(store.live) + 1 || throw(ArgumentError("test handles use monotonic ids"))
    push!(store.parents, parent.id)
    push!(store.child_ids, Int[])
    push!(store.encodings, encoding)
    push!(store.values, Dict{Symbol,Any}(pairs(values)))
    push!(store.live, true)
    push!(store.child_ids[parent.id], id)
    return Handle(store, id)
end

function MultiScaleTreeGraph.delete_node!(node::Handle)
    store = checked(node)
    isempty(store.child_ids[node.id]) || throw(ArgumentError("test deletion requires leaf"))
    parent = Base.parent(node)
    parent === nothing && throw(ArgumentError("test deletion requires nonroot"))
    filter!(!=(node.id), store.child_ids[parent.id])
    store.live[node.id] = false
    return parent
end

function root()
    store = Store([0], [Int[]], [NodeMTG(:/, :Scene, 1, 0)], [Dict{Symbol,Any}(:note => "root")], trues(1))
    return Handle(store, 1)
end
end

@testset "Custom runtime node handles use the MTG interface" begin
    root = RuntimeNodeHandleFixture.root()
    axis = add_node!(root, 2, NodeMTG(:/, :Axis, 1, 1), (label=:axis,))
    leaf = add_node!(axis, 3, NodeMTG(:+, :Leaf, 1, 2), (value=2.0,))
    sibling = add_node!(root, 4, NodeMTG(:+, :Axis, 2, 1), NamedTuple())
    @test root isa AbstractMTGNode
    @test get_root(leaf) === root
    @test get_node(root, 3) === leaf
    @test get_node(root, 90) === nothing
    @test traverse(root, node_id; type=Int) == [1, 2, 3, 4]
    @test traverse(root, node_id; symbol="Axis", type=Int) == [2, 4]
    @test traverse(root, node_id; scale=2, type=Int) == [3]
    @test traverse(root, node_id; filter_fun=n -> node_id(n) != 2, all=false, type=Int) == [1, 4]
    @test traverse(root, node_id; recursivity_level=2, type=Int) == [1, 2, 4]
    @test traverse(root, (node, increment) -> node_id(node) + increment, 10; type=Int) == [11, 12, 13, 14]
    visited = Int[]
    traverse!(root) do node
        push!(visited, node_id(node))
    end
    @test visited == [1, 2, 3, 4]
    @test length(root) == 4
    @test max_id(root) == 4 && new_id(root) == 5
    @test MultiScaleTreeGraph.isroot(root) && !MultiScaleTreeGraph.isroot(axis) && MultiScaleTreeGraph.isleaf(leaf)
    @test lastchild(axis) === leaf
    @test (symbol(leaf), scale(leaf), index(leaf), link(leaf)) == (:Leaf, 2, 1, :+)
    @test axis[1] === leaf
    @test leaf["value"] == 2.0
    @test leaf[:missing] === nothing
    leaf["value"] = 3.0
    @test attribute(leaf, :value) == 3.0
    @test attribute(leaf, :missing; default=7) == 7
    attribute!(leaf, :extra, 8)
    @test haskey(leaf, :extra) && :extra in attribute_names(leaf)
    @test attributes(leaf; format=:dict) == Dict(:value => 3.0, :extra => 8)
    @test getproperty(attributes(leaf), :extra) == 8
    @test ancestors(leaf; symbol=:Axis) == [axis]
    @test descendants(root; symbol=:Leaf) == [leaf]
    ref = attribute_ref(leaf, :value, Float64)
    @test ref isa Ref{Float64}
    @test eltype(typeof(ref)) === Float64
    ref[] = 4
    @test leaf[:value] === 4.0
    leaf[:value] = 5.0
    @test ref[] === 5.0
    delete_node!(leaf)
    @test_throws ArgumentError ref[]
    @test get_node(root, 3) === nothing
    @test children(axis) == RuntimeNodeHandleFixture.Handle[]

    ordinary = Node(NodeMTG(:/, :Scene, 1, 0))
    child = add_node!(ordinary, 2, NodeMTG(:+, :Leaf, 1, 1), (value=1.0,))
    @test ordinary isa AbstractMTGNode
    @test parent(child) === ordinary
    @test ordinary[1] === child
    @test child["value"] == 1.0
    child["value"] = 2.0
    @test child[:value] == 2.0
end

@testset "Attribute references follow logical rows and preserve their types" begin
    root = Node(1, NodeMTG(:/, :Scene, 1, 0))
    first_leaf = add_node!(root, 2, NodeMTG(:+, :Leaf, 1, 1), (value=1.0,))
    last_leaf = add_node!(root, 3, NodeMTG(:+, :Leaf, 2, 1), (value=2.0,))
    first_ref = attribute_ref(first_leaf, :value, Float64)
    last_ref = attribute_ref(last_leaf, :value)
    @test last_ref isa Ref{Float64}
    @test eltype(typeof(last_ref)) === Float64
    first_ref[] = 3
    @test first_leaf[:value] === 3.0
    first_leaf[:value] = 4.0
    @test first_ref[] === 4.0

    # Widening another row must not change this variable's declared type.
    last_leaf[:value] = "widened"
    @test first_ref[] === 4.0
    @test_throws TypeError last_ref[]
    @test_throws TypeError (last_ref[] = 6.0)
    last_leaf[:value] = 6.0
    @test last_ref[] === 6.0
    @test_throws TypeError attribute_ref(first_leaf, :value, Int)
    @test_throws KeyError attribute_ref(first_leaf, :absent, Float64)

    old_attrs = node_attributes(first_leaf)
    prune!(first_leaf)
    @test last_ref[] === 6.0 # The last physical row moved into the first slot.
    @test_throws ArgumentError first_ref[]
    @test_throws ArgumentError (first_ref[] = 8.0)

    # Reusing the same attribute container and numeric ID creates a new logical
    # row lifetime; the old reference must never retarget it.
    replacement = add_node!(root, 2, NodeMTG(:+, :Leaf, 3, 1), old_attrs)
    replacement[:value] = 9.0
    @test_throws ArgumentError first_ref[]
    @test attribute_ref(replacement, :value)[] === 9.0

    delete!(node_attributes(last_leaf), :value)
    @test_throws KeyError last_ref[]
    @test_throws KeyError (last_ref[] = 7.0)
    last_leaf[:value] = 7.0
    rename_column!(root, :Leaf, :value, :renamed)
    @test_throws KeyError last_ref[]
    @test attribute_ref(last_leaf, :renamed)[] === 7.0

    shared = [1.0, 2.0]
    replacement[:shared] = shared
    shared_ref = attribute_ref(replacement, :shared, Vector{Float64})
    @test shared_ref[] === shared
    other = [3.0]
    shared_ref[] = other
    @test replacement[:shared] === other
    shared_ref[][1] = 4.0
    @test replacement[:shared][1] === 4.0

    replacement[:nullable] = nothing
    nullable = attribute_ref(replacement, :nullable, Union{Nothing,Float64})
    @test nullable[] === nothing
    nullable[] = 2.0
    @test replacement[:nullable] === 2.0
end

@testset "Attribute references survive store migration and schema rebuild" begin
    destination = Node(1, NodeMTG(:/, :Scene, 1, 0))
    source = Node(20, NodeMTG(:/, :Scene, 1, 0))
    moving = add_node!(source, 21, NodeMTG(:+, :Leaf, 1, 1), (value=6.0,))
    reference = attribute_ref(moving, :value, Float64)
    original_store = node_attributes(moving).ref.store
    reparent!(moving, destination)
    @test node_attributes(moving).ref.store !== original_store
    @test reference[] === 6.0
    reference[] = 7.0
    @test moving[:value] === 7.0
    columnarize!(destination)
    @test reference[] === 7.0
    reparent!(moving, nothing)
    @test reference[] === 7.0
    reference[] = 8.0
    @test moving[:value] === 8.0
end
