using Test
using BenchmarkTools
using MultiScaleTreeGraph

include(joinpath(@__DIR__, "..", "test-row-mutation-topology-benchmark.jl"))
using .A1RowMutationTopologyBenchmarks

function assert_topology(data, n::Int)
    @test length(data.leaves) == n
    @test length(children(data.root)) == n
    @test length(data.root) == n + 1
    @test max_id(data.root) == n + 1
    @test node_id.(data.leaves) == collect(2:(n + 1))

    for index in unique((1, cld(n, 2), n))
        leaf = data.leaves[index]
        @test parent(leaf) === data.root
        @test get_node(data.root, index + 1) === leaf
    end
end

function assert_dense_attributes(data, n::Int)
    for index in unique((1, cld(n, 2), n))
        leaf = data.leaves[index]
        @test attribute(leaf, :x, nothing) == index
        @test attribute(leaf, :y, nothing) == Float64(index)
        @test attribute(leaf, :flag, nothing) == isodd(index)
    end
    dense_values = descendants(data.root, :x; symbol=:Leaf, ignore_nothing=true)
    @test eltype(dense_values) === Int
    @test dense_values == collect(1:n)
end

function assert_sparse_attributes(data, n::Int, mode::Symbol)
    for index in 1:n
        leaf = data.leaves[index]
        @test attribute(leaf, :shared, nothing) == index
        if iszero(index % 8)
            @test haskey(leaf, :local)
            @test attribute(leaf, :local, nothing) == index
        elseif mode === :row_local
            @test !haskey(leaf, :local)
            @test attribute(leaf, :local, :absent) === :absent
        else
            @test mode === :legacy_schema_wide
            @test haskey(leaf, :local)
            @test attribute(leaf, :local, :absent) === nothing
        end
    end
    sparse_values = descendants(data.root, :local; symbol=:Leaf, ignore_nothing=true)
    @test eltype(sparse_values) === Int
    @test sparse_values == collect(8:8:n)
end

function assert_benchmark_size_group(group)
    expected_sizes = Set(string.(A1_SIZE_TIERS))
    @test Set(keys(group)) == expected_sizes
    for size_key in expected_sizes
        benchmark_parameters = params(group[size_key])
        @test benchmark_parameters.samples == A1_BENCHMARK_SAMPLES
        @test benchmark_parameters.evals == 1
    end
end

@testset "A1 mutation capability" begin
    probe = ROW_MUTATION_PROBE
    @test probe.package_version == A1_PACKAGE_VERSION
    @test probe.mode in (:legacy_schema_wide, :row_local)
    @test probe.popped_value == 1
    @test probe.pop_target_absent
    @test probe.delete_target_absent
    @test probe.empty_target_empty
    @test probe.nullable_target_present
    @test probe.explicit_schema_drop

    if probe.mode === :row_local
        @test probe.pop_neighbor_present
        @test probe.delete_neighbor_present
        @test probe.empty_neighbor_present
        @test !probe.nullable_neighbor_present
    else
        @test !probe.pop_neighbor_present
        @test !probe.delete_neighbor_present
        @test !probe.empty_neighbor_present
        @test probe.nullable_neighbor_present
    end
end

@testset "A1 BenchmarkTools suite assembly" begin
    suite = BenchmarkGroup()
    a1 = build_a1_benchmark_suite!(suite)

    @test Set(keys(suite)) == Set(["a1_row_mutation_topology"])
    @test suite["a1_row_mutation_topology"] === a1

    expected_groups = Set([
        "explicit_cold",
        "explicit_hot_append",
        "preexisting_auto_id",
        "write_mtg",
    ])
    row_local_mutation_supported() && push!(expected_groups, "row_local")
    @test Set(keys(a1)) == expected_groups

    @test Set(keys(a1["explicit_cold"])) == Set(["dense", "sparse"])
    assert_benchmark_size_group(a1["explicit_cold"]["dense"])
    assert_benchmark_size_group(a1["explicit_cold"]["sparse"])

    @test Set(keys(a1["explicit_hot_append"])) == Set(["dense"])
    assert_benchmark_size_group(a1["explicit_hot_append"]["dense"])

    @test Set(keys(a1["preexisting_auto_id"])) == Set(["dense"])
    assert_benchmark_size_group(a1["preexisting_auto_id"]["dense"])

    @test Set(keys(a1["write_mtg"])) == Set(["dense", "sparse"])
    assert_benchmark_size_group(a1["write_mtg"]["dense"])
    assert_benchmark_size_group(a1["write_mtg"]["sparse"])

    if row_local_mutation_supported()
        @test haskey(a1, "row_local")
        @test Set(keys(a1["row_local"])) ==
              Set(["empty_restore", "pop_restore", "sparse_toggle"])
        assert_benchmark_size_group(a1["row_local"]["empty_restore"])
        assert_benchmark_size_group(a1["row_local"]["pop_restore"])
        assert_benchmark_size_group(a1["row_local"]["sparse_toggle"])
    else
        @test row_mutation_mode() === :legacy_schema_wide
        @test !haskey(a1, "row_local")
    end
end

@testset "A1 deterministic topology fixtures" begin
    for n in A1_SIZE_TIERS
        dense = build_dense_explicit(n)
        assert_topology(dense, n)
        assert_dense_attributes(dense, n)

        sparse = build_sparse_explicit(n)
        assert_topology(sparse, n)
        assert_sparse_attributes(sparse, n, row_mutation_mode())

        auto_id = build_dense_auto_id(n)
        assert_topology(auto_id, n)
        assert_dense_attributes(auto_id, n)
    end
end

@testset "A1 hot explicit-ID append" begin
    for n in A1_SIZE_TIERS
        data = build_dense_explicit(n)
        existing_last = last(data.leaves)
        existing_last_before = attributes(existing_last; format=:dict)

        added = append_dense_explicit!(data.root, n)

        @test node_id(added) == n + 2
        @test parent(added) === data.root
        @test last(children(data.root)) === added
        @test length(children(data.root)) == n + 1
        @test length(data.root) == n + 2
        @test max_id(data.root) == n + 2
        @test get_node(data.root, n + 2) === added
        @test attribute(added, :x, nothing) == n + 1
        @test attribute(added, :y, nothing) == Float64(n + 1)
        @test attribute(added, :flag, nothing) == isodd(n + 1)
        @test attributes(existing_last; format=:dict) == existing_last_before
    end
end

@testset "A1 modern row-local workloads restore their input" begin
    if row_local_mutation_supported()
        dense = build_dense_explicit(32)
        dense_before = [attributes(leaf; format=:dict) for leaf in dense.leaves]
        @test pop_restore_batch!(dense.leaves, 257) > 0
        @test [attributes(leaf; format=:dict) for leaf in dense.leaves] == dense_before

        @test empty_restore_batch!(dense.leaves, 257) > 0
        @test [attributes(leaf; format=:dict) for leaf in dense.leaves] == dense_before

        sparse = prepare_sparse_toggle_fixture(32)
        @test all(leaf -> !haskey(leaf, :ephemeral), sparse.leaves)
        @test sparse_toggle_batch!(sparse.leaves, 257) > 0
        @test all(leaf -> !haskey(leaf, :ephemeral), sparse.leaves)
    else
        @test row_mutation_mode() === :legacy_schema_wide
    end
end

@testset "A1 dense and sparse MTG round trips" begin
    mktempdir() do directory
        dense = build_dense_explicit(32)
        dense_path_1 = joinpath(directory, "dense-1.mtg")
        dense_path_2 = joinpath(directory, "dense-2.mtg")
        @test write_fixture(dense_path_1, dense.root) > 0
        @test write_fixture(dense_path_2, dense.root) > 0
        @test read(dense_path_1) == read(dense_path_2)

        dense_roundtrip = read_mtg(dense_path_1)
        @test length(dense_roundtrip) == 33
        @test max_id(dense_roundtrip) == 33
        for index in (1, 16, 32)
            leaf = get_node(dense_roundtrip, index + 1)
            @test attribute(leaf, :x, nothing) == index
            @test attribute(leaf, :y, nothing) == Float64(index)
            @test attribute(leaf, :flag, nothing) == isodd(index)
        end

        sparse = build_sparse_explicit(32)
        sparse_path_1 = joinpath(directory, "sparse-1.mtg")
        sparse_path_2 = joinpath(directory, "sparse-2.mtg")
        @test write_fixture(sparse_path_1, sparse.root) > 0
        @test write_fixture(sparse_path_2, sparse.root) > 0
        @test read(sparse_path_1) == read(sparse_path_2)

        sparse_roundtrip = read_mtg(sparse_path_1)
        @test length(sparse_roundtrip) == 33
        @test max_id(sparse_roundtrip) == 33
        roundtrip_leaves = [get_node(sparse_roundtrip, index + 1) for index in 1:32]
        assert_sparse_attributes(
            (root=sparse_roundtrip, leaves=roundtrip_leaves),
            32,
            row_mutation_mode(),
        )
    end
end
