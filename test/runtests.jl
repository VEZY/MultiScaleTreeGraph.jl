using Test
using MultiScaleTreeGraph
using DataFrames, Dates
using Graphs, AbstractTrees

@testset "read_mtg" begin
    include("test-read_mtg.jl")
end

@testset "simple helper functions" begin
    include("test-summary.jl")
end

@testset "simple node functions" begin
    include("test-nodes.jl")
end

@testset "columnar backend" begin
    include("test-columnar.jl")
end

@testset "descendants()" begin
    include("test-descendants.jl")
end

@testset "ancestors()" begin
    include("test-ancestors.jl")
end

@testset "mutation" begin
    include("test-mutation.jl")
    include("test-insert_node.jl")
    include("test-traverse.jl")
    include("test-transform.jl")
end

@testset "Deletion / Pruning" begin
    include("test-delete-prune.jl")
end

@testset "conversion" begin
    include("test-conversion.jl")
end

@testset "writing" begin
    include("test-write_mtg.jl")
end


@testset "Caching" begin
    include("test-caching.jl")
end
