using MTG
using BenchmarkTools

# read_mtg("test/files/simple_plant.mtg")
file = "test/files/simple_plant.mtg"

line = [0]
l = [""]
f = open(file, "r")
for i in 1:27
    l[1] = next_line!(f,line)
end
close(f)

header = ["LEFT","RIGHT","RELTYPE","MAX"]
section = "DESCRIPTION"
line = [0]
# l = [""]
# l[1] = next_line!(f,line)


mtg,classes,description,features = read_mtg("test/files/simple_plant.mtg")

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