using MultiScaleTreeGraph
using Logging: NullLogger, with_logger

function _write_mtg_median(values::Vector{Float64})
    sorted = sort(values)
    middle = length(sorted) ÷ 2
    return isodd(length(sorted)) ? sorted[middle + 1] :
           (sorted[middle] + sorted[middle + 1]) / 2
end

function _write_mtg_performance_fixture(n_nodes::Int; n_features::Int=40)
    feature_names = [Symbol("feature_$(lpad(i, 2, '0'))") for i in 1:n_features]
    feature_types = [i % 4 == 1 ? "REAL" : i % 4 == 2 ? "INT" :
                     i % 4 == 3 ? "BOOLEAN" : "STRING" for i in 1:n_features]

    function attributes_for(id::Int)
        attrs = Dict{Symbol,Any}()
        @inbounds for i in eachindex(feature_names)
            attrs[feature_names[i]] = if feature_types[i] == "REAL"
                id + i / 100
            elseif feature_types[i] == "INT"
                id * i
            elseif feature_types[i] == "BOOLEAN"
                isodd(id + i)
            else
                "n$(id)-f$(i)"
            end
        end
        return attrs
    end

    root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        attributes_for(1),
    )
    nodes = Vector{typeof(root)}(undef, n_nodes)
    nodes[1] = root
    @inbounds for id in 2:n_nodes
        parent_ = nodes[id ÷ 2]
        node_symbol = id % 3 == 0 ? :Leaf : :Internode
        node_link = id % 3 == 0 ? :+ : :<
        node_scale = id % 3 == 0 ? 3 : 2
        nodes[id] = Node(
            id,
            parent_,
            MutableNodeMTG(node_link, node_symbol, id, node_scale),
            attributes_for(id),
        )
    end

    features = MultiScaleTreeGraph.ColumnTable(
        Symbol[:NAME, :TYPE],
        AbstractVector[feature_names, feature_types],
    )
    return (root=root, classes=get_classes(root), features=features)
end

function _write_mtg_materialized(file, data)
    open(file, "w") do io
        MultiScaleTreeGraph.writedlm(io, ["CODE:" "FORM-A"])
        MultiScaleTreeGraph.writedlm(io, [""])
        MultiScaleTreeGraph.writedlm(io, ["CLASSES:"])
        MultiScaleTreeGraph.writedlm(
            io, reshape(String.(names(data.classes)), (1, :))
        )
        classes_print = copy(data.classes)
        symbols_ = String.(classes_print.SYMBOL)
        replace!(symbols_, "Scene" => "\$")
        classes_print.SYMBOL = symbols_
        MultiScaleTreeGraph._write_table_rows(io, classes_print)

        MultiScaleTreeGraph.writedlm(io, [""])
        MultiScaleTreeGraph.writedlm(io, ["DESCRIPTION:"])
        MultiScaleTreeGraph.writedlm(io, ["LEFT" "RIGHT" "RELTYPE" "MAX"])

        MultiScaleTreeGraph.writedlm(io, [""])
        MultiScaleTreeGraph.writedlm(io, ["FEATURES:"])
        MultiScaleTreeGraph.writedlm(
            io, reshape(String.(names(data.features)), (1, :))
        )
        MultiScaleTreeGraph._write_table_rows(io, data.features)

        MultiScaleTreeGraph.writedlm(io, [""])
        MultiScaleTreeGraph.writedlm(io, ["MTG:"])
        attributes, column_names = MultiScaleTreeGraph.paste_node_mtg(
            data.root, data.features
        )
        MultiScaleTreeGraph.writedlm(
            io, reshape(column_names, (1, :)), quotes=false
        )
        for i in eachindex(attributes["mtg_print"])
            row = Any[attributes[key][i] for key in keys(attributes)]
            MultiScaleTreeGraph.writedlm(io, reshape(row, (1, :)), quotes=false)
        end
    end
    return file
end

function _measure_write_mtg_pair(data; samples::Int=7)
    return with_logger(NullLogger()) do
        _measure_write_mtg_pair_unlogged(data; samples=samples)
    end
end

function _measure_write_mtg_pair_unlogged(data; samples::Int=7)
    streaming_path = tempname() * ".mtg"
    materialized_path = tempname() * ".mtg"
    try
        write_mtg(
            streaming_path, data.root, data.classes, nothing, data.features
        )
        _write_mtg_materialized(materialized_path, data)
        read(streaming_path) == read(materialized_path) ||
            error("Streaming and materialized writers produced different bytes.")

        GC.gc()
        streaming_allocations = @allocated write_mtg(
            streaming_path, data.root, data.classes, nothing, data.features
        )
        GC.gc()
        materialized_allocations = @allocated _write_mtg_materialized(
            materialized_path, data
        )

        streaming_times = Vector{Float64}(undef, samples)
        materialized_times = Vector{Float64}(undef, samples)
        for sample in 1:samples
            if isodd(sample)
                streaming_times[sample] = @elapsed write_mtg(
                    streaming_path, data.root, data.classes, nothing, data.features
                )
                materialized_times[sample] = @elapsed _write_mtg_materialized(
                    materialized_path, data
                )
            else
                materialized_times[sample] = @elapsed _write_mtg_materialized(
                    materialized_path, data
                )
                streaming_times[sample] = @elapsed write_mtg(
                    streaming_path, data.root, data.classes, nothing, data.features
                )
            end
        end

        return (
            bytes=filesize(streaming_path),
            streaming=(
                allocations=streaming_allocations,
                seconds=_write_mtg_median(streaming_times),
            ),
            materialized=(
                allocations=materialized_allocations,
                seconds=_write_mtg_median(materialized_times),
            ),
        )
    finally
        isfile(streaming_path) && rm(streaming_path; force=true)
        isfile(materialized_path) && rm(materialized_path; force=true)
    end
end

function write_mtg_performance_gates(; samples::Int=7)
    results = Dict{Int,Any}()
    for n_nodes in (1_000, 10_000)
        data = _write_mtg_performance_fixture(n_nodes)
        result = _measure_write_mtg_pair(data; samples=samples)

        allocation_ratio = result.streaming.allocations /
                           result.materialized.allocations
        time_ratio = result.streaming.seconds / result.materialized.seconds
        allocation_ratio <= 0.75 || error(
            "write_mtg allocation gate failed at $(n_nodes) nodes: " *
            "streaming/materialized = $(allocation_ratio).",
        )
        time_ratio <= 1.02 || error(
            "write_mtg time gate failed at $(n_nodes) nodes: " *
            "streaming/materialized = $(time_ratio).",
        )
        results[n_nodes] = merge(
            result,
            (allocation_ratio=allocation_ratio, time_ratio=time_ratio),
        )
    end

    small = results[1_000].streaming
    large = results[10_000].streaming
    large.allocations <= 15 * small.allocations || error(
        "write_mtg allocation scaling is superlinear: " *
        "10k/1k = $(large.allocations / small.allocations).",
    )
    large.seconds <= 20 * small.seconds || error(
        "write_mtg time scaling is superlinear: " *
        "10k/1k = $(large.seconds / small.seconds).",
    )
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    display(write_mtg_performance_gates())
end
