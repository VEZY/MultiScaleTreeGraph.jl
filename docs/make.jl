using MultiScaleTreeGraph
using Documenter

DocMeta.setdocmeta!(MultiScaleTreeGraph, :DocTestSetup, :(using MultiScaleTreeGraph); recursive=true)

makedocs(;
    modules=[MultiScaleTreeGraph],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "MultiScaleTreeGraph.jl"),
    sitename="MultiScaleTreeGraph.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/MultiScaleTreeGraph.jl",
        assets=String[],
        size_threshold=300000
    ),
    pages=[
        "Home" => "index.md",
        "Getting started" => "get_started.md",
        "The MTG format" => [
            "Concept" => "the_mtg/mtg_concept.md",
            "File format" => "the_mtg/mtg_format.md",
            "Our implementation" => "the_mtg/our_implementation.md"
        ],
        "Tutorials" => [
            "Read and Write MTGs" => "tutorials/0.read_write.md",
            "Create and Manipulate Nodes" => "tutorials/1.manipulate_node.md",
            "Traversal, Descendants, Ancestors and Filters" => "tutorials/2.descendants_ancestors_filters.md",
            "Transform and Select Attributes" => "tutorials/3.transform_mtg.md",
            "Convert MTGs to Tables and Graphs" => "tutorials/4.convert_mtg.md",
            "Plot MTGs" => "tutorials/5.plotting.md",
            "Add and Remove Nodes" => "tutorials/6.add_remove_nodes.md",
            "Performance Considerations" => "tutorials/7.performance_considerations.md",
        ],
        "API" => "api.md",
    ]
)

deploydocs(;
    repo="github.com/VEZY/MultiScaleTreeGraph.jl"
)
