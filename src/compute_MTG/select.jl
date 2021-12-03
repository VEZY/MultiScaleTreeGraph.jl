"""
    select!(node::Node, args..., <keyword arguments>)
    select(node::Node, args..., <keyword arguments>)

Delete all attributes not selected in `args...`, and optionally apply transformations on the
fly on the selected variables. This function works similarly to [`transform!`](@ref) except
it keeps only the selected variables, while [`transform!`](@ref) add new variables.

See the documentation of [`transform!`](@ref) for more details on the format of `args` and on
how to use the arguments.

This function adds one more form to `args...`: a variable name to just select a variable.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

select!(mtg, :Length => (x -> x / 10) => :length_m, :Width, ignore_nothing = true)
```
"""
function select!(
    mtg::Node,
    args...;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    filter_fun = nothing,
    ignore_nothing = false
)

    check_filters(mtg, scale = scale, symbol = symbol, link = link)

    keep_var = []

    for nc in args

        if nc isa Symbol || nc isa String
            # `new name` form, i.e. just selecting the variable
            push!(keep_var, nc)
        elseif last(nc) isa Symbol
            # `function => new name` form, i.e. `node -> sum(descendants(node, :var)) => :newvar`.
            # or `Name => new name` form, i.e. :x => :y.
            push!(keep_var, last(nc))
        elseif last(nc) isa Pair && (last(last(nc)) isa Symbol || last(last(nc)) isa String)
            # `Name => function => new name` form, i.e. :x => sqrt => :x_sq
            push!(keep_var, last(last(nc)))
        elseif nc isa Base.Callable
            # If we provide just a function, it is just a transformation to apply on the node
            # directly. No need to handle this here (it is handled by transform!)
            continue
        else
            # `Name => function` form, i.e. :x => sqrt
            # ?NOTE: Here the function takes one or more attributes as input
            col_idx, fun = nc
            newname, col_idx = col_name_from_call(col_idx, fun)
            push!(keep_var, newname)
        end
    end

    # Transform the MTG if any transformation is needed:
    transform!(
        mtg,
        args...;
        scale = scale,
        symbol = symbol,
        link = link,
        filter_fun = filter_fun,
        ignore_nothing = ignore_nothing
    )

    # Remove all un-selected attributes from the MTG:
    traverse!(
        mtg,
        node -> [pop!(node, attr) for attr in setdiff(keys(node.attributes), keep_var)]
    )

end


function select(
    mtg::Node,
    args...;
    scale = nothing,
    symbol = nothing,
    link = nothing,
    filter_fun = nothing,
    ignore_nothing = false
)
    new_mtg = deepcopy(mtg)

    select!(
        new_mtg,
        args...;
        scale = scale,
        symbol = symbol,
        link = link,
        filter_fun = filter_fun,
        ignore_nothing = ignore_nothing
    )

    return new_mtg
end
