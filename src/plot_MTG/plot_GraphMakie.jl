
# This is a working script to plot an MTG using GraphMakie
using NetworkLayout, GraphMakie, GeometryBasics, LightGraphs
node_names = String[traverse(mtg, x -> join([string("(", x.id, ")"), x.MTG.symbol, x.MTG.index], " "))...]
links = String[traverse(mtg, x -> x.MTG.link)[2:end]...]
f, ax, p = graphplot(MetaGraph(mtg); layout = Buchheim(), nlabels = node_names, elabels = links)

# We can also use a custom Layout (like we use with other plots):
function mtg_layout(g::MetaGraph)
    x = zeros(nv(g))
    y = zeros(nv(g))
    z = zeros(nv(g))

    for i = 1:nv(g)
        node_string = "node_" * string(i)
        x[i] = meta_mtg[node_string][:XX]
        y[i] = meta_mtg[node_string][:YY]
        z[i] = meta_mtg[node_string][:ZZ]
    end

    return Point.(zip(x, y, z))
end

f, ax, p = graphplot(MetaGraph(mtg); layout = mtg_layout, nlabels = node_names, elabels = links)
