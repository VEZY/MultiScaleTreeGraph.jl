using Test
using MTG
using DataFrames
using MutableNamedTuples

@testset "read_mtg" begin
    include("test-read_mtg.jl")
end

@testset "descendants()" begin
    include("test-descendants.jl")
end

@testset "ancestors()" begin
    include("test-ancestors.jl")
end
