"""
    transform!(node::Node, args..., <keyword arguments>)

Transform (mutate) an MTG (`node`) in place to add attributes specified by `args...`.

# Arguments

- `node::Node`: An MTG node (*e.g.* the whole mtg returned by `read_mtg()`).
- `args::Any`: the transformations (see details)
- <keyword arguments>:

    - `scale = nothing`: The scale to filter-in (i.e. to keep). Usually a Tuple-alike of integers.
    - `symbol = nothing`: The symbol to filter-in. Usually a Tuple-alike of Strings.
    - `link = nothing`: The link with the previous node to filter-in. Usually a Tuple-alike of Char.
    - `filter_fun = nothing`: Any filtering function taking a node as input, e.g. [`isleaf`](@ref).

# Returns

Nothing, mutates the (sub-)tree in-place.

# Details

The interface of the function is inspired from the one used in
[`DataFrames.jl`](https://dataframes.juliadata.org/stable/), but adapted to an MTG.

The `args...` provided can be of the following forms:

1. a `:var_name => :new_var_name` pair. This form is used to rename an attribute name
1. a `:var_name => function` or `[:var_name1, :var_name2] => function` pair. The variables
are declared as a Symbol or a String (or a vector of), and they are passed as positional
arguments to the function. This form automatically generates the new column name by
concatenating the source column name(s) and the function name if any.
1. a `:var_name => function => :new_var_name` form that does the same as the previous form
but explicitly naming the resulting variable.
1. a `function => :new_var_name` form that applies a function to a node and puts the results
in a new attribute. This form is usually applied when searching ancestors or descendants values.
1. a `function` form that applies a mutating function to a node, without expecting any output.
This form is adapted when using a function that already mutates the node, without the need to
return anything, *e.g.* [`branching_order!`](@ref).

Carefull to the form you use! Form 2 and 3 expect a function that uses one or more node
attributes (== variables) as inputs, while form 4 and 5 expect a function that uses a node.

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)

# We can use transform to apply a function over all nodes (same as using [`traverse!`](@ref))
transform!(mtg,  x -> isleaf(x) ? println(x.name," is a leaf") : nothing)
node_5 is a leaf
node_7 is a leaf

# We can compute a new variable based on another. For example to know if the value of the
# `:Length` attribute is provided or not, we can do:
transform!(mtg, :Length => isnothing)
# To check the values we first call [`get_features`](@ref) to know the new variable name:
get_features(mtg)
# And then we get the values using [`descendants`](@ref)
descendants(mtg, :Length_isnothing, self = true)
# Or DataFrame:
DataFrame(mtg, :Length_isnothing)

# We can also set the attribute name ourselves like so:
transform!(mtg, :Length => isnothing => :no_length)
descendants(mtg, :no_length, self = true)

# We can provide anonymous functions if we want to:
transform!(mtg, :Length => (x -> isnothing(x)))
descendants(mtg, :no_length, self = true)

# When a node does not have an attribute, it returns `nothing`. Most basic functions do not
# handle well those, e.g.:
transform!(mtg, :Length => log)
# It does not work because some nodes have no value for `:Length`.
# The solution is to handle these cases in our own functions instead:
transform!(mtg, :Length => (x -> x === nothing ? nothing : log(x)) => :log_length)
descendants(mtg, :log_length, self = true)

# Another way is to give a filtering function as an argument:
transform!(mtg, :Length => log => :log_length, filter_fun = x -> x[:Length] !== nothing)

# We can use more than one attribute as input to our function like so:
transform!(
    mtg,
    [:Width, :Length] => ((x, y) -> (x/2)^2 * π * y) => :volume,
    filter_fun = x -> x[:Length] !== nothing && x[:Width] !== nothing
)
descendants(mtg, :volume, self = true)

# Note that `filter_fun` filter the node, so we use the node[:attribute] notation here.

# We can also chain operations, and they will be executed sequentially so we can use variables
# computed on the instruction just before:
density = 0.6
transform!(
    mtg,
    [:Width, :Length] => ((x, y) -> (x/2)^2 * π * y) => :vol,
    :vol => (x -> x * density) => :biomass,
    filter_fun = x -> x[:Length] !== nothing && x[:Width] !== nothing
)
DataFrame(mtg, [:vol, :biomass])

# We can also rename a variable like so:
transform!(
    mtg,
    :biomass => :mass,
    filter_fun = x -> x[:Length] !== nothing && x[:Width] !== nothing
)
DataFrame(mtg, [:vol, :mass])

# Finnaly, we can use variables from ancestors/descendants using the `function => :new_var` form:
function get_mass_descendants(x)
    masses = descendants(x, :mass, ignore_nothing = true)
    if length(masses) == 0
        nothing
    else
        sum(masses)
    end
end

transform!(
    mtg,
    get_mass_descendants => :mass_beared
)
DataFrame(mtg, [:mass, :mass_beared])
```
"""
function transform!(
        mtg::Node,
        args...;
        scale = nothing,
        symbol = nothing,
        link = nothing,
        filter_fun = nothing
    )

    check_filters(mtg, scale = scale, symbol = symbol, link = link)

    for nc in args
        if nc isa Base.Callable
            # If we provide just a function, it is applied to the node directly, so it must handle
            # a node as the first argument.
            # ?NOTE: Here the function takes a node as input
            fun_ = nc
        elseif first(nc) isa Symbol && last(nc) isa Symbol
            # `Name => new name` form, i.e. :x => :y.
            # ?NOTE: Here we just rename an attribute
            fun_ = x -> rename!(x, nc)
        elseif first(nc) isa Base.Callable && last(nc) isa Symbol
            # `function => new name` form, i.e. `node -> sum(descendants(node, :var)) => :newvar`.
            # ?NOTE: Here the function takes a node as input
            fun, newname = nc
            fun_ = x -> x[newname] = fun(x)
        elseif last(nc) isa Pair
            # `Name => function => new name` form, i.e. :x => sqrt => :x_sq
            # ?NOTE: Here the function takes one or more attributes as input
            col_idx, (fun, newname) = nc

            if !isa(col_idx, Vector)
                col_idx = [col_idx]
            end

            fun_ = x -> x[newname] = fun([x[i] for i in col_idx]...)
        else
            # `Name => function` form, i.e. :x => sqrt
            # ?NOTE: Here the function takes one or more attributes as input
            col_idx, fun = nc
            if !isa(col_idx, Vector)
                col_idx = [col_idx]
            end
            fnname = Symbol(fun)
            fnname_string = String(fnname)
            col_idx_name = join([String(i) for i in col_idx], "_")

            if startswith(fnname_string, '#')
                newname = Symbol(string(col_idx_name, "_function"))
            else
                newname = Symbol(join([col_idx_name, String(fnname)], "_"))
            end
            fun_ = x -> x[newname] = fun([x[i] for i in col_idx]...)
        end

        traverse!(
            mtg,
            fun_;
            scale = scale,
            symbol = symbol,
            link = link,
            filter_fun = filter_fun
        )
    end
end
