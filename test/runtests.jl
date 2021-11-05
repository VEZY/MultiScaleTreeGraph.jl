using Test
using MTG
using DataFrames
using MutableNamedTuples
using RecipesBase
using Plots # Add this dependency because else the tests on plot recip return an error (I don't know why)

@testset "read_mtg" begin
    include("test-read_mtg.jl")
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

@testset "plot recipes" begin
    include("test-plot-recipe.jl")
end

@testset "conversion" begin
    include("test-conversion.jl")
end
