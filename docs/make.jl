using MultiScaleTreeGraph
using Documenter

DocMeta.setdocmeta!(MultiScaleTreeGraph, :DocTestSetup, :(using MultiScaleTreeGraph); recursive=true)

makedocs(;
    modules=[MultiScaleTreeGraph],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/VEZY/MultiScaleTreeGraph.jl/blob/{commit}{path}#{line}",
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
            "tutorials/0.read_write.md",
            "tutorials/1.manipulate_node.md",
            "tutorials/2.descendants_ancestors_filters.md",
            "tutorials/3.transform_mtg.md",
            "tutorials/4.convert_mtg.md",
            "tutorials/5.plotting.md",
            "tutorials/6.add_remove_nodes.md",
            "tutorials/7.performance_considerations.md",
        ],
        "API" => "api.md",
    ]
)

deploydocs(;
    repo="github.com/VEZY/MultiScaleTreeGraph.jl"
)
