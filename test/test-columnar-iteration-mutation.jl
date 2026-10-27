using Test
using MultiScaleTreeGraph

@testset "Columnar iteration across heterogeneous and sparse columns" begin
    shared = [1.0, 2.0]
    scientific_ref = Ref(4.0)
    staged = MultiScaleTreeGraph.ColumnarAttrs(Dict{Symbol,Any}(
        :integer => 1, :nullable => nothing, :shared => shared,
    ))
    @test Dict(pairs(staged)) == Dict(:integer => 1, :nullable => nothing, :shared => shared)
    @test staged[:shared] === shared
    @test iterate(MultiScaleTreeGraph.ColumnarAttrs()) === nothing

    root = Node(NodeMTG(:/, :Scene, 1, 0))
    first_leaf = Node(root, NodeMTG(:+, :Leaf, 1, 1), staged)
    middle_leaf = Node(root, NodeMTG(:+, :Leaf, 2, 1), (integer=2.5, text="middle"))
    last_leaf = Node(root, NodeMTG(:+, :Leaf, 3, 1), (integer=3, scientific_ref=scientific_ref))
    empty_leaf = Node(root, NodeMTG(:+, :Empty, 1, 1))

    for node in (first_leaf, middle_leaf, last_leaf)
        attrs = node_attributes(node)
        entries = collect(pairs(attrs))
        @test first.(entries) == keys(attrs)
        @test length(entries) == length(attrs)
        @test all(entry isa Pair{Symbol,Any} for entry in entries)
        @test all(isequal(value, attrs[key]) for (key, value) in entries)
    end
    @test iterate(node_attributes(empty_leaf)) === nothing
    @test Dict(pairs(node_attributes(first_leaf)))[:nullable] === nothing
    @test !haskey(node_attributes(middle_leaf), :nullable)
    @test Dict(pairs(node_attributes(first_leaf)))[:shared] === shared
    @test Dict(pairs(node_attributes(last_leaf)))[:scientific_ref] === scientific_ref

    # Widening must keep entry order and preserve both explicit nothing and
    # absent values in other rows of the same bucket.
    last_leaf[:integer] = "widened"
    before_order = keys(node_attributes(last_leaf))
    @test Dict(pairs(node_attributes(last_leaf)))[:integer] == "widened"
    @test first_leaf[:integer] === 1
    @test middle_leaf[:integer] === 2.5
    @test first.(collect(pairs(node_attributes(last_leaf)))) == before_order
    delete!(node_attributes(first_leaf), :integer)
    @test !haskey(Dict(pairs(node_attributes(first_leaf))), :integer)
    first_leaf[:integer] = nothing
    @test haskey(Dict(pairs(node_attributes(first_leaf))), :integer)
    @test Dict(pairs(node_attributes(first_leaf)))[:integer] === nothing
end

@testset "Column row removal keeps moved rows and presence counts" begin
    root = Node(NodeMTG(:/, :Scene, 1, 0))
    removed = Node(root, NodeMTG(:+, :Leaf, 1, 1), (value=1, only_removed=true, nullable=nothing))
    survivor = Node(root, NodeMTG(:+, :Leaf, 2, 1), (value=2.0, nullable=nothing))
    shared = [3.0]
    moved = Node(root, NodeMTG(:+, :Leaf, 3, 1), (value="last", shared=shared))
    survivor_snapshot = Dict(pairs(node_attributes(survivor)))
    moved_snapshot = Dict(pairs(node_attributes(moved)))

    # Removing the first row swaps the last row into its slot.
    prune!(removed)
    @test Dict(pairs(node_attributes(survivor))) == survivor_snapshot
    @test Dict(pairs(node_attributes(moved))) == moved_snapshot
    @test moved[:shared] === shared
    @test !haskey(node_attributes(moved), :nullable)
    @test !haskey(node_attributes(moved), :only_removed)
    @test survivor[:nullable] === nothing

    store = node_attributes(moved).ref.store
    bucket = store.buckets[store.symbol_to_bucket[:Leaf]]
    for column in bucket.columns
        @test length(column.data) == 2
        @test length(column.present) == 2
        @test column.n_present == count(column.present)
    end

    # The last-row path must update counts without copying a different row.
    prune!(survivor)
    @test Dict(pairs(node_attributes(moved))) == moved_snapshot
    for column in bucket.columns
        @test length(column.data) == 1
        @test column.n_present == count(column.present)
    end
    prune!(moved)
    @test isempty(children(root))
    for column in bucket.columns
        @test isempty(column.data)
        @test isempty(column.present)
        @test column.n_present == 0
    end
end
