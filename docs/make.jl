using MultiScaleTreeGraph
using Documenter
using Plots
DocMeta.setdocmeta!(MultiScaleTreeGraph, :DocTestSetup, :(using MultiScaleTreeGraph); recursive = true)

makedocs(;
    modules = [MultiScaleTreeGraph],
    authors = "remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo = "https://github.com/VEZY/MultiScaleTreeGraph.jl/blob/{commit}{path}#{line}",
    sitename = "MultiScaleTreeGraph.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://VEZY.github.io/MultiScaleTreeGraph.jl",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => "get_started.md",
        "The MTG format" => [
            "Concept" => "the_mtg/mtg_concept.md",
            "File format" => "the_mtg/mtg_format.md",
            "Our implementation" => "the_mtg/our_implementation.md"
        ],
        # "Tutorials" => "tutorial_simple.md",
        "API" => "api.md",
    ]
)

deploydocs(;
    repo = "github.com/VEZY/MultiScaleTreeGraph.jl"
)
