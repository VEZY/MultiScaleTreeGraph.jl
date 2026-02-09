using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.develop(PackageSpec(path=dirname(@__DIR__)))
Pkg.instantiate()

using BenchmarkTools
using MultiScaleTreeGraph
using Random

const SUITE = BenchmarkGroup()

function synthetic_tree(; branching::Int=4, depth::Int=8, nsamples::Int=256, seed::Int=42)
    rng = MersenneTwister(seed)

    root = Node(
        1,
        NodeMTG("/", "Scale1", 1, 1),
        Dict{Symbol,Float64}(
            :mass => rand(rng),
            :area => rand(rng),
            :height => rand(rng),
        ),
    )

    frontier = [root]
    next_id = 1

    for d in 1:depth
        next_frontier = Node{NodeMTG,Dict{Symbol,Float64}}[]
        sym = "Scale$(d + 1)"
        sc = d + 1
        for p in frontier
            for b in 1:branching
                next_id += 1
                child = Node(
                    next_id,
                    p,
                    NodeMTG("<", sym, b, sc),
                    Dict{Symbol,Float64}(
                        :mass => rand(rng),
                        :area => rand(rng),
                        :height => rand(rng),
                    ),
                )
                push!(next_frontier, child)
            end
        end
        frontier = next_frontier
    end

    all_nodes = traverse(root, x -> x, type=typeof(root))
    sample_nodes = rand(rng, all_nodes, min(nsamples, length(all_nodes)))

    return root, frontier, sample_nodes
end

function children_workload(nodes, reps::Int)
    s = 0
    @inbounds for _ in 1:reps
        for n in nodes
            s += length(children(n))
        end
    end
    return s
end

function parent_workload(nodes, reps::Int)
    s = 0
    @inbounds for _ in 1:reps
        for n in nodes
            p = parent(n)
            s += p === nothing ? 0 : node_id(p)
        end
    end
    return s
end

function ancestors_workload(nodes, reps::Int)
    s = 0.0
    @inbounds for _ in 1:reps
        for n in nodes
            vals = ancestors(n, :mass, recursivity_level=4, type=Float64)
            for v in vals
                s += v
            end
        end
    end
    return s
end

function ancestors_workload_inplace_1(nodes, reps::Int)
    s = 0.0
    @inbounds for _ in 1:reps
        for n in nodes
            out = ancestors!(n, :mass, recursivity_level=4, type=Float64)
            for v in out
                s += v
            end
        end
    end
    return s
end

function ancestors_workload_inplace_2(nodes, reps::Int)
    s = 0.0
    buf = Float64[]
    @inbounds for _ in 1:reps
        for n in nodes
            ancestors!(buf, n, :mass, recursivity_level=4, type=Float64)
            for v in buf
                s += v
            end
        end
    end
    return s
end

function descendants_extraction_workload(root)
    vals = descendants(root, :mass, type=Float64)
    s = 0.0
    @inbounds for v in vals
        s += v
    end
    return s
end

function descendants_extraction_workload_inplace_1(root)
    descendants!(root, :mass, type=Float64)
end

function descendants_extraction_workload_inplace_2(root)
    vals = Float64[]
    descendants!(vals, root, :mass, type=Float64)
end

suite_name = "mstg"
if Sys.iswindows()
    suite_name *= "_windows"
elseif Sys.isapple()
    suite_name *= "_mac"
elseif Sys.islinux()
    suite_name *= "_linux"
end

SUITE[suite_name] = BenchmarkGroup([
    "traverse",
    "traverse_extract",
    "many_queries",
])

root, leaves, sample_nodes = synthetic_tree()
SUITE[suite_name]["traverse"]["full_tree_nodes"] = @benchmarkable traverse!($root, _ -> nothing)
SUITE[suite_name]["traverse_extract"]["descendants_mass"] = @benchmarkable descendants_extraction_workload($root)
SUITE[suite_name]["traverse_extract"]["descendants_mass_inplace"] = @benchmarkable descendants_extraction_workload_inplace_1($root)

# Add this one only if we have a method for `descendants!(val, node, key, type)`
if hasmethod(descendants!, Tuple{AbstractVector,Node,Symbol})
    SUITE[suite_name]["traverse_extract"]["descendants_mass_inplace"] = @benchmarkable descendants_extraction_workload_inplace_2($root)
end

SUITE[suite_name]["many_queries"]["children_repeated"] = @benchmarkable children_workload($sample_nodes, 300)
SUITE[suite_name]["many_queries"]["parent_repeated"] = @benchmarkable parent_workload($sample_nodes, 300)
SUITE[suite_name]["many_queries"]["ancestors_repeated"] = @benchmarkable ancestors_workload($leaves, 40)
if hasmethod(ancestors!, Tuple{AbstractVector,Node,Symbol})
    SUITE[suite_name]["many_queries"]["ancestors_repeated_inplace"] = @benchmarkable ancestors_workload_inplace($leaves, 40)
end

if abspath(PROGRAM_FILE) == @__FILE__
    results = run(SUITE, verbose=true)
    println(results)
end
