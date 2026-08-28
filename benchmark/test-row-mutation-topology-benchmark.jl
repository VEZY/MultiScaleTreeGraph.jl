module A1RowMutationTopologyBenchmarks

using BenchmarkTools
using Logging: NullLogger, with_logger
using MultiScaleTreeGraph

export A1_BENCHMARK_SAMPLES,
       A1_MUTATION_REPETITIONS,
       A1_PACKAGE_VERSION,
       A1_SIZE_TIERS,
       ROW_MUTATION_PROBE,
       append_dense_explicit!,
       build_a1_benchmark_suite!,
       build_dense_auto_id,
       build_dense_explicit,
       build_sparse_explicit,
       empty_restore_batch!,
       pop_restore_batch!,
       prepare_sparse_toggle_fixture,
       row_local_mutation_supported,
       row_mutation_mode,
       sparse_toggle_batch!,
       write_fixture

const A1_SIZE_TIERS = (32, 256, 1024)
const A1_BENCHMARK_SAMPLES = 12
const A1_MUTATION_REPETITIONS = 1024
const A1_ABSENT = Symbol("__a1_absent__")
const A1_PACKAGE_VERSION = Base.pkgversion(MultiScaleTreeGraph)

@inline _leaf_link(index::Int) = isone(index) ? :/ : :+

function fresh_root()
    return Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        (root_value=1,),
    )
end

function grow_dense_explicit!(root, n::Int)
    leaves = Vector{typeof(root)}()
    sizehint!(leaves, n)
    for index in 1:n
        leaf = Node(
            index + 1,
            root,
            MutableNodeMTG(_leaf_link(index), :Leaf, index, 2),
            (x=index, y=Float64(index), flag=isodd(index)),
        )
        push!(leaves, leaf)
    end
    return (root=root, leaves=leaves)
end

function build_dense_explicit(n::Int)
    return grow_dense_explicit!(fresh_root(), n)
end

function append_dense_explicit!(root, existing_leaf_count::Int)
    leaf_index = existing_leaf_count + 1
    return Node(
        leaf_index + 1,
        root,
        MutableNodeMTG(:+, :Leaf, leaf_index, 2),
        (x=leaf_index, y=Float64(leaf_index), flag=isodd(leaf_index)),
    )
end

@inline function _sparse_attributes(index::Int)
    if iszero(index % 8)
        return NamedTuple{(:shared, :local)}((index, index))
    end
    return (shared=index,)
end

function grow_sparse_explicit!(root, n::Int)
    leaves = Vector{typeof(root)}()
    sizehint!(leaves, n)
    for index in 1:n
        leaf = Node(
            index + 1,
            root,
            MutableNodeMTG(_leaf_link(index), :Leaf, index, 2),
            _sparse_attributes(index),
        )
        push!(leaves, leaf)
    end
    return (root=root, leaves=leaves)
end

function build_sparse_explicit(n::Int)
    return grow_sparse_explicit!(fresh_root(), n)
end

function build_dense_auto_id(n::Int)
    root = fresh_root()
    leaves = Vector{typeof(root)}()
    sizehint!(leaves, n)
    for index in 1:n
        # Exercise the public ID-less constructor separately from explicit-ID
        # construction. Columnar MTGs obtain the next ID from the store's
        # cached maximum instead of traversing the tree.
        leaf = Node(
            root,
            MutableNodeMTG(_leaf_link(index), :Leaf, index, 2),
            (x=index, y=Float64(index), flag=isodd(index)),
        )
        push!(leaves, leaf)
    end
    return (root=root, leaves=leaves)
end

function _mutation_probe()
    pop_data = build_dense_explicit(2)
    popped_value = Base.pop!(node_attributes(pop_data.leaves[1]), :x)
    pop_target_absent = !haskey(pop_data.leaves[1], :x)
    pop_neighbor_present =
        haskey(pop_data.leaves[2], :x) &&
        attribute(pop_data.leaves[2], :x, A1_ABSENT) == 2

    delete_data = build_dense_explicit(2)
    Base.delete!(node_attributes(delete_data.leaves[1]), :x)
    delete_target_absent = !haskey(delete_data.leaves[1], :x)
    delete_neighbor_present =
        haskey(delete_data.leaves[2], :x) &&
        attribute(delete_data.leaves[2], :x, A1_ABSENT) == 2

    empty_data = build_dense_explicit(2)
    Base.empty!(node_attributes(empty_data.leaves[1]))
    empty_target_empty = isempty(node_attributes(empty_data.leaves[1]))
    empty_neighbor_present =
        haskey(empty_data.leaves[2], :x) &&
        attribute(empty_data.leaves[2], :x, A1_ABSENT) == 2

    nullable_data = build_dense_explicit(2)
    nullable_data.leaves[1][:nullable] = nothing
    nullable_target_present =
        haskey(nullable_data.leaves[1], :nullable) &&
        nullable_data.leaves[1][:nullable] === nothing
    nullable_neighbor_present = haskey(nullable_data.leaves[2], :nullable)

    schema_drop_data = build_dense_explicit(2)
    drop_column!(schema_drop_data.root, :Leaf, :x)
    explicit_schema_drop = all(leaf -> !haskey(leaf, :x), schema_drop_data.leaves)

    row_local_signature =
        popped_value == 1 &&
        pop_target_absent &&
        pop_neighbor_present &&
        delete_target_absent &&
        delete_neighbor_present &&
        empty_target_empty &&
        empty_neighbor_present &&
        nullable_target_present &&
        !nullable_neighbor_present &&
        explicit_schema_drop

    schema_wide_signature =
        popped_value == 1 &&
        pop_target_absent &&
        !pop_neighbor_present &&
        delete_target_absent &&
        !delete_neighbor_present &&
        empty_target_empty &&
        !empty_neighbor_present &&
        nullable_target_present &&
        nullable_neighbor_present &&
        explicit_schema_drop

    mode = if row_local_signature
        :row_local
    elseif schema_wide_signature
        :legacy_schema_wide
    else
        :unknown
    end

    return (
        mode=mode,
        package_version=A1_PACKAGE_VERSION,
        popped_value=popped_value,
        pop_target_absent=pop_target_absent,
        pop_neighbor_present=pop_neighbor_present,
        delete_target_absent=delete_target_absent,
        delete_neighbor_present=delete_neighbor_present,
        empty_target_empty=empty_target_empty,
        empty_neighbor_present=empty_neighbor_present,
        nullable_target_present=nullable_target_present,
        nullable_neighbor_present=nullable_neighbor_present,
        explicit_schema_drop=explicit_schema_drop,
    )
end

const ROW_MUTATION_PROBE = _mutation_probe()

row_mutation_mode() = ROW_MUTATION_PROBE.mode
row_local_mutation_supported() = row_mutation_mode() === :row_local

function pop_restore_batch!(leaves, repetitions::Int=A1_MUTATION_REPETITIONS)
    row_local_mutation_supported() || throw(ArgumentError(
        "pop/restore is only benchmarked when row-local ColumnarAttrs mutation is available",
    ))
    checksum = 0
    nleaves = length(leaves)
    @inbounds for repetition in 1:repetitions
        leaf = leaves[mod1(17 * repetition, nleaves)]
        attrs = node_attributes(leaf)
        value = Base.pop!(attrs, :x)
        attrs[:x] = value
        checksum += value
    end
    return checksum
end

function empty_restore_batch!(leaves, repetitions::Int=A1_MUTATION_REPETITIONS)
    row_local_mutation_supported() || throw(ArgumentError(
        "empty/restore is only benchmarked when row-local ColumnarAttrs mutation is available",
    ))
    checksum = 0
    nleaves = length(leaves)
    @inbounds for repetition in 1:repetitions
        leaf = leaves[mod1(17 * repetition, nleaves)]
        attrs = node_attributes(leaf)
        x = attrs[:x]
        y = attrs[:y]
        flag = attrs[:flag]
        Base.empty!(attrs)
        attrs[:x] = x
        attrs[:y] = y
        attrs[:flag] = flag
        checksum += x + flag
    end
    return checksum
end

function prepare_sparse_toggle_fixture(n::Int)
    row_local_mutation_supported() || throw(ArgumentError(
        "sparse toggles require row-local ColumnarAttrs mutation",
    ))
    data = build_sparse_explicit(n)
    seed_attrs = node_attributes(first(data.leaves))
    seed_attrs[:ephemeral] = 0
    Base.pop!(seed_attrs, :ephemeral)
    return data
end

function sparse_toggle_batch!(leaves, repetitions::Int=A1_MUTATION_REPETITIONS)
    row_local_mutation_supported() || throw(ArgumentError(
        "sparse toggles require row-local ColumnarAttrs mutation",
    ))
    checksum = 0
    nleaves = length(leaves)
    @inbounds for repetition in 1:repetitions
        leaf = leaves[mod1(17 * repetition, nleaves)]
        attrs = node_attributes(leaf)
        attrs[:ephemeral] = repetition
        checksum += Base.pop!(attrs, :ephemeral)
    end
    return checksum
end

function write_fixture(path::AbstractString, root)
    try
        with_logger(NullLogger()) do
            write_mtg(path, root)
        end
        return filesize(path)
    catch
        isfile(path) && rm(path; force=true)
        rethrow()
    end
end

function build_a1_benchmark_suite!(suite::BenchmarkGroup)
    mode = row_mutation_mode()
    mode in (:legacy_schema_wide, :row_local) || error(
        "Unsupported ColumnarAttrs mutation behavior $(mode); " *
        "refusing to assemble a partial A1 benchmark suite.",
    )
    a1 = BenchmarkGroup()
    suite["a1_row_mutation_topology"] = a1
    repetitions = A1_MUTATION_REPETITIONS

    for n in A1_SIZE_TIERS
        size_key = string(n)

        a1["explicit_cold"]["dense"][size_key] =
            @benchmarkable build_dense_explicit($n) samples=A1_BENCHMARK_SAMPLES evals=1
        a1["explicit_cold"]["sparse"][size_key] =
            @benchmarkable build_sparse_explicit($n) samples=A1_BENCHMARK_SAMPLES evals=1
        a1["explicit_hot_append"]["dense"][size_key] = @benchmarkable(
            append_dense_explicit!(data_.root, $n),
            setup=(data_ = build_dense_explicit($n)),
            samples=A1_BENCHMARK_SAMPLES,
            evals=1,
        )

        # Kept separate so the cost of automatic ID allocation remains visible
        # independently of explicit-ID construction.
        a1["automatic_id"]["dense"][size_key] =
            @benchmarkable build_dense_auto_id($n) samples=A1_BENCHMARK_SAMPLES evals=1

        dense_root = build_dense_explicit(n).root
        sparse_root = build_sparse_explicit(n).root
        a1["write_mtg"]["dense"][size_key] = @benchmarkable(
            write_fixture(path_, $dense_root),
            setup=(path_ = tempname() * ".mtg"),
            teardown=(isfile(path_) && rm(path_; force=true)),
            samples=A1_BENCHMARK_SAMPLES,
            evals=1,
        )
        a1["write_mtg"]["sparse"][size_key] = @benchmarkable(
            write_fixture(path_, $sparse_root),
            setup=(path_ = tempname() * ".mtg"),
            teardown=(isfile(path_) && rm(path_; force=true)),
            samples=A1_BENCHMARK_SAMPLES,
            evals=1,
        )

        if mode === :row_local
            a1["row_local"]["pop_restore"][size_key] = @benchmarkable(
                pop_restore_batch!(data_.leaves, $repetitions),
                setup=(data_ = build_dense_explicit($n)),
                samples=A1_BENCHMARK_SAMPLES,
                evals=1,
            )
            a1["row_local"]["empty_restore"][size_key] = @benchmarkable(
                empty_restore_batch!(data_.leaves, $repetitions),
                setup=(data_ = build_dense_explicit($n)),
                samples=A1_BENCHMARK_SAMPLES,
                evals=1,
            )
            a1["row_local"]["sparse_toggle"][size_key] = @benchmarkable(
                sparse_toggle_batch!(data_.leaves, $repetitions),
                setup=(data_ = prepare_sparse_toggle_fixture($n)),
                samples=A1_BENCHMARK_SAMPLES,
                evals=1,
            )
        end
    end

    return a1
end

end
