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
        # "Tutorials" => "tutorial_simple.md",
        "API" => "api.md",
    ]
)

deploydocs(;
    repo = "github.com/VEZY/MultiScaleTreeGraph.jl"
)
