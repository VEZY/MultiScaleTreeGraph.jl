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
include("read_MTG/Tree_funs.jl")
include("print_MTG/print.jl")
include("compute_MTG/descendants.jl")
include("compute_MTG/ancestors.jl")
include("compute_MTG/DataFrame.jl")
include("compute_MTG/check_filters.jl")

export read_mtg
export printnode
export isleaf
export isroot
export children
export addchild!
export traverse!
export printnode
export getroot
export nextsibling
export print
export show
export length
export DataFrame
export printnode
export iterate
export siblings

# Not sure to keep as export
export Node
export check_filters

# Just for testing:
export descendants, ancestors
export unsafe_getindex
export get_printing_
export get_printing
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
