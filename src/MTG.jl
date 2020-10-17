module MTG

using AbstractTrees
using Printf
using DataFrames
using MutableNamedTuples

# Write your package code here.
include("read_MTG/read_MTG.jl")
include("read_MTG/strip_comments.jl")
include("read_MTG/utils-string.jl")
include("read_MTG/parse_section.jl")
include("read_MTG/parse_mtg.jl")
include("read_MTG/NodeMTG.jl")
include("read_MTG/expand_node.jl")

export read_mtg
export printnode

# Not sure to keep as export
export Node

# Just for testing:
export strip_comments
export issection
export parse_section!
export next_line!
export parse_mtg!
export split_MTG_elements
export NodeMTG
export parse_MTG_node
export parse_MTG_node_attr
export expand_node!

end
