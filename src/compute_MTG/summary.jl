"""
    get_classes(mtg)

Compute the mtg classes based on its content. Usefull after having mutating the mtg nodes.
"""
function get_classes(mtg)
    attributes = traverse(mtg, node -> (SYMBOL=symbol(node), SCALE=scale(node)), type=@NamedTuple{SYMBOL::Symbol, SCALE::Int64})
    attributes = unique(attributes)
    n = length(attributes)
    symbols_ = Vector{Symbol}(undef, n)
    scales_ = Vector{Int}(undef, n)
    @inbounds for i in eachindex(attributes)
        symbols_[i] = attributes[i].SYMBOL
        scales_[i] = attributes[i].SCALE
    end

    ColumnTable(
        Symbol[:SYMBOL, :SCALE, :DECOMPOSITION, :INDEXATION, :DEFINITION],
        AbstractVector[
            symbols_,
            scales_,
            fill("FREE", n),
            fill("FREE", n),
            fill("IMPLICIT", n)
        ]
    )
end

"""
    get_description(mtg)

Returns `nothing`, because we can't really predict the description section from an mtg.
"""
function get_description(mtg)
    return nothing
end

"""
    get_features(mtg)

Compute the mtg features section based on its attributes. Usefull after having computed new attributes
in the mtg.
"""
function get_features(mtg)
    names_ = Symbol[]
    types_ = String[]
    seen = Set{Tuple{Symbol,String}}()

    traverse!(mtg) do node
        for (name, value) in pairs(node_attributes(node))
            T = typeof(value)
            if (T <: AbstractVector) || (T <: Nothing) || (name in (:description, :symbols, :scales))
                continue
            end

            typ =
                if T <: AbstractFloat
                    "REAL"
                elseif T <: Bool
                    "BOOLEAN"
                elseif T <: Integer
                    "INT"
                elseif T <: Date
                    "DD/MM/YY"
                else
                    "STRING"
                end

            row = (Symbol(name), typ)
            if !(row in seen)
                push!(seen, row)
                push!(names_, row[1])
                push!(types_, row[2])
            end
        end
    end

    ColumnTable(Symbol[:NAME, :TYPE], AbstractVector[names_, types_])
end

"""
    scales(mtg)

Get all the scales of an MTG.
"""
function scales(mtg)
    vec = Int[]
    traverse(mtg) do node
        push!(vec, scale(node))
    end

    return unique(vec)
end

function symbols(mtg)
    vec = Symbol[]
    traverse!(mtg) do node
        push!(vec, symbol(node))
    end
    return unique(vec)
end

components = symbols

"""
    symbols(mtg)
    components(mtg)

Get all the symbols names, a.k.a. components of an MTG.
"""
components, symbols

"""
    list_nodes(mtg)

List all nodes IDs in the subtree of `mtg`.
"""
list_nodes(mtg) = traverse(mtg, node -> node_id(node), type=Int)

"""
    max_id(mtg)

Returns the maximum id of the mtg
"""
function max_id(mtg)
    maxid = Ref(0)

    function update_maxname(id, maxid)
        id > maxid[] ? maxid[] = id : nothing
    end

    traverse!(get_root(mtg), x -> update_maxname(node_id(x), maxid))

    return maxid[]
end
