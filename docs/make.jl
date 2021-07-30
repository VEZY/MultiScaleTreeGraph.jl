using MTG
using Documenter

DocMeta.setdocmeta!(MTG, :DocTestSetup, :(using MTG); recursive = true)

makedocs(;
    modules = [MTG],
    authors = "remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo = "https://github.com/VEZY/MTG.jl/blob/{commit}{path}#{line}",
    sitename = "MTG.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://VEZY.github.io/MTG.jl",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => "get_started.md",
        "API" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/VEZY/MTG.jl",
)
