using MTG
# using BenchmarkTools
# using MutableNamedTuples

# read_mtg("test/files/simple_plant.mtg")
file = "test/files/simple_plant.mtg"

line = [0]
l = [""]
f = open(file, "r")
for i in 1:33
    l[1] = next_line!(f,line;whitespace=false)
end

mtg,classes,description,features = read_mtg("test/files/simple_plant.mtg");

printnode(mtg)

isleaf(node.children["node_2"].children["node_3"].children["node_4"].children["node_5"])
getroot(node.children["node_2"].children["node_3"].children["node_4"].children["node_5"])

node.children["node_2"].children["node_3"].children["node_4"].children["node_5"].children

isleaf(mtg)
isroot(mtg)
children(mtg)

close(f)

header = ["LEFT","RIGHT","RELTYPE","MAX"]
section = "DESCRIPTION"
line = [0]
# l = [""]
# l[1] = next_line!(f,line)

x = MutableNamedTuple(a=1, b=2)
x.a
x[1]
x.a = 2

sx = StructArray((test,(a=1, b=2)))

function testfn()
    return
end

testfn() === nothing


any(node_1_node[1] .== ("^","<.","+."))

b = try
    sqrt(1)
catch e
    println("You should have entered a numeric value")
end

@btime read_mtg("test/files/simple_plant.mtg");
# 1.418 ms (1428 allocations: 82.47 KiB)
# 1.423 ms (1422 allocations: 82.45 KiB)
# 1.414 ms (1355 allocations: 75.08 KiB)

read_mtg("test/files/simple_plant_2.mtg")

using DataFrames
DataFrame(classes, ["SYMBOL","SCALE","DECOMPOSITION","INDEXATION","DEFINITION"])


test = Dict{String,Union{Missing, String, Int, Float64}}("a" => 1, "b" => 1.2)

try
  test["a"] = parse(Int,"3")
catch e
    # error("issue")
    pop!(test,"a")
    nothing
end

test["a"] = missing


mutable struct Foo
    bar::Int
    baz::Int
    maz::Int
    function Foo(maz=2)
        foo = new()
        foo.maz = maz
        return foo
    end
end

foo=Foo()