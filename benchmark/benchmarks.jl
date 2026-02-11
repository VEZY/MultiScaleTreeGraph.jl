using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.develop(PackageSpec(path=dirname(@__DIR__)))
Pkg.instantiate()

using BenchmarkTools
using MultiScaleTreeGraph
using Random
using Tables

const SUITE = BenchmarkGroup()

const SIZE_TIERS = (
    small=10_000,
    medium=100_000,
    large=300_000,
)

function synthetic_mtg(; n_nodes::Int=10_000, seed::Int=42)
    rng = MersenneTwister(seed)

    root = Node(
        1,
        MutableNodeMTG(:/, :Plant, 1, 1),
        MultiScaleTreeGraph.ColumnarAttrs(Dict{Symbol,Any}(
            :mass => rand(rng),
            :height => rand(rng),
            :temperature => 20.0,
        )),
    )

    candidates = Node[root]
    leaves = Node[]
    internodes = Node[]
    all_nodes = Node[root]

    next_id = 1
    while next_id < n_nodes
        parent_ = candidates[rand(rng, eachindex(candidates))]
        next_id += 1

        roll = rand(rng)
        if roll < 0.60
            sym = :Internode
            scale_ = 2
            link_ = :<
            attrs = Dict{Symbol,Any}(
                :mass => rand(rng),
                :Length => rand(rng),
                :Diameter => rand(rng),
            )
        elseif roll < 0.95
            sym = :Leaf
            scale_ = 3
            link_ = :+
            attrs = Dict{Symbol,Any}(
                :mass => rand(rng),
                :Width => rand(rng),
                :Area => rand(rng),
            )
        else
            sym = :Axis
            scale_ = 2
            link_ = :<
            attrs = Dict{Symbol,Any}(
                :mass => rand(rng),
                :Length => rand(rng),
            )
        end

        child = Node(next_id, parent_, MutableNodeMTG(link_, sym, 1, scale_), attrs)
        push!(all_nodes, child)

        if sym == :Leaf
            push!(leaves, child)
        else
            push!(internodes, child)
            push!(candidates, child)
        end
    end

    sample_size = min(512, length(all_nodes))
    sample_nodes = rand(rng, all_nodes, sample_size)
    sample_leaves = isempty(leaves) ? sample_nodes : rand(rng, leaves, min(512, length(leaves)))

    return (root=root, leaves=leaves, internodes=internodes, all_nodes=all_nodes, sample_nodes=sample_nodes, sample_leaves=sample_leaves)
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
            vals = ancestors(n, :Length, recursivity_level=4)
            for v in vals
                v === nothing || (s += v)
            end
        end
    end
    return s
end

function ancestors_workload_inplace(nodes, reps::Int)
    s = 0.0
    buf = Union{Nothing,Float64}[]
    @inbounds for _ in 1:reps
        for n in nodes
            ancestors!(buf, n, :Length, recursivity_level=4)
            for v in buf
                v === nothing || (s += v)
            end
        end
    end
    return s
end

function descendants_repeated_workload(root, reps::Int)
    s = 0.0
    @inbounds for _ in 1:reps
        vals = descendants(root, :Length, symbol=:Internode, ignore_nothing=true)
        for v in vals
            s += v
        end
    end
    return s
end

function descendants_repeated_workload_inplace(root, reps::Int)
    s = 0.0
    buf = Float64[]
    @inbounds for _ in 1:reps
        descendants!(buf, root, :Length, symbol=:Internode, ignore_nothing=true)
        for v in buf
            s += v
        end
    end
    return s
end

function traverse_update_one!(root)
    traverse!(root) do node
        m = attribute(node, :mass, default=0.0)
        attribute!(node, :mass, m + 0.1)
    end
    return nothing
end

function traverse_update_multi_leaf!(root)
    traverse!(root, symbol=:Leaf) do node
        width = attribute(node, :Width, default=0.0)
        area = attribute(node, :Area, default=0.0)
        attribute!(node, :Width, width * 1.001)
        attribute!(node, :Area, area + width)
    end
    return nothing
end

function traverse_update_multi_mixed!(root)
    traverse!(root, symbol=(:Leaf, :Internode)) do node
        m = attribute(node, :mass, default=0.0)
        attribute!(node, :mass, m * 0.999 + 0.0001)
        attribute!(node, :update_counter, attribute(node, :update_counter, default=0) + 1)
    end
    return nothing
end

function descendants_tuple_workload(root)
    vals = descendants(root, [:Length, :mass], symbol=:Internode, ignore_nothing=true)
    s = 0.0
    for v in vals
        s += v[1] + v[2]
    end
    return s
end

function descendants_mixed_one(root; ignore_nothing::Bool)
    descendants(root, :Length, symbol=(:Leaf, :Internode), ignore_nothing=ignore_nothing)
end

function descendants_mixed_many(root; ignore_nothing::Bool)
    descendants(root, [:Length, :Area], symbol=(:Leaf, :Internode), ignore_nothing=ignore_nothing)
end

function build_tier!(suite, tier_name::String, n_nodes::Int)
    seed = Int(mod(hash(tier_name), typemax(Int)))
    data = synthetic_mtg(n_nodes=n_nodes, seed=seed)
    root = data.root
    sample_nodes = data.sample_nodes
    sample_leaves = data.sample_leaves

    tier = BenchmarkGroup()
    suite[tier_name] = tier

    tier["traverse"]["full_tree_nodes"] = @benchmarkable traverse!($root, _ -> nothing)

    tier["traverse_update"]["one_attr_all_nodes"] = @benchmarkable traverse_update_one!($root)
    tier["traverse_update"]["multi_attr_leaf_only"] = @benchmarkable traverse_update_multi_leaf!($root)
    tier["traverse_update"]["multi_attr_leaf_internode"] = @benchmarkable traverse_update_multi_mixed!($root)

    tier["descendants_query"]["one_attr_one_symbol"] = @benchmarkable descendants($root, :Length, symbol=:Internode, ignore_nothing=true)
    tier["descendants_query"]["many_attr_one_symbol"] = @benchmarkable descendants_tuple_workload($root)
    tier["descendants_query"]["one_attr_mixed_keep_nothing"] = @benchmarkable descendants_mixed_one($root, ignore_nothing=false)
    tier["descendants_query"]["one_attr_mixed_ignore_nothing"] = @benchmarkable descendants_mixed_one($root, ignore_nothing=true)
    tier["descendants_query"]["many_attr_mixed_keep_nothing"] = @benchmarkable descendants_mixed_many($root, ignore_nothing=false)
    tier["descendants_query"]["many_attr_mixed_ignore_nothing"] = @benchmarkable descendants_mixed_many($root, ignore_nothing=true)

    tier["descendants_query"]["one_attr_one_symbol_inplace"] = @benchmarkable begin
        buf = Float64[]
        descendants!(buf, $root, :Length, symbol=:Internode, ignore_nothing=true)
    end

    tier["many_queries"]["children_repeated"] = @benchmarkable children_workload($sample_nodes, 300)
    tier["many_queries"]["parent_repeated"] = @benchmarkable parent_workload($sample_nodes, 300)
    tier["many_queries"]["ancestors_repeated"] = @benchmarkable ancestors_workload($sample_leaves, 40)
    tier["many_queries"]["ancestors_repeated_inplace"] = @benchmarkable ancestors_workload_inplace($sample_leaves, 40)
    tier["many_queries"]["descendants_repeated"] = @benchmarkable descendants_repeated_workload($root, 30)
    tier["many_queries"]["descendants_repeated_inplace"] = @benchmarkable descendants_repeated_workload_inplace($root, 30)

    if tier_name == "small"
        tier["api_surface_small_only"]["insert_child"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=8_000, seed=111)
            mtg_ = data_.root
            insert_child!(mtg_[1], MutableNodeMTG(:<, :Internode, 1, 2), x -> Dict{Symbol,Any}(:mass => 0.1), [max_id(mtg_)])
        end

        tier["api_surface_small_only"]["delete_node"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=8_000, seed=222)
            mtg_ = data_.root
            target = get_node(mtg_, node_id(mtg_[1]))
            delete_node!(target)
        end

        tier["api_surface_small_only"]["prune_subtree"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=8_000, seed=333)
            mtg_ = data_.root
            prune!(mtg_[1])
        end

        tier["api_surface_small_only"]["transform"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=8_000, seed=444)
            mtg_ = data_.root
            transform!(mtg_, :mass => (x -> x + 1.0) => :mass2, ignore_nothing=true)
        end

        tier["api_surface_small_only"]["select"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=8_000, seed=555)
            mtg_ = data_.root
            select!(mtg_, :mass, :Length, ignore_nothing=true)
        end

        tier["api_surface_small_only"]["tables_symbol"] = @benchmarkable symbol_table($root, :Leaf)
        tier["api_surface_small_only"]["tables_unified"] = @benchmarkable mtg_table($root)

        tier["api_surface_small_only"]["write_mtg"] = @benchmarkable begin
            data_ = synthetic_mtg(n_nodes=3_000, seed=666)
            mtg_ = data_.root
            f = tempname() * ".mtg"
            write_mtg(mtg_, f)
            rm(f, force=true)
        end
    end
end

suite_name = "mstg"
if Sys.iswindows()
    suite_name *= "_windows"
elseif Sys.isapple()
    suite_name *= "_mac"
elseif Sys.islinux()
    suite_name *= "_linux"
end

SUITE[suite_name] = BenchmarkGroup()

build_tier!(SUITE[suite_name], "small", SIZE_TIERS.small)
build_tier!(SUITE[suite_name], "medium", SIZE_TIERS.medium)
build_tier!(SUITE[suite_name], "large", SIZE_TIERS.large)

# Keep the largest tier focused on critical hot paths.
delete!(SUITE[suite_name]["large"], "api_surface_small_only")

if abspath(PROGRAM_FILE) == @__FILE__
    results = run(SUITE, verbose=true)
    println(results)
end
