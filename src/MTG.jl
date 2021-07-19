module MTG

using AbstractTrees
using Printf
using DataFrames
using MutableNamedTuples
using DelimitedFiles
using OrderedCollections

import Base.setindex!

include("read_MTG/NodeMTG.jl")
include("read_MTG/read_MTG.jl")
include("read_MTG/strip_comments.jl")
include("read_MTG/utils-string.jl")
include("read_MTG/parse_section.jl")
include("read_MTG/parse_mtg.jl")
include("read_MTG/expand_node.jl")
include("read_MTG/Tree_funs.jl")
include("print_MTG/print.jl")
include("compute_MTG/descendants.jl")
include("compute_MTG/ancestors.jl")
include("compute_MTG/DataFrame.jl")
include("compute_MTG/check_filters.jl")
include("compute_MTG/mutation.jl")
include("compute_MTG/append_attributes.jl")
include("compute_MTG/traverse.jl")
include("compute_MTG/delete_nodes.jl")
include("compute_MTG/filter/filter-funs.jl")
include("write_mtg/update_sections.jl")
include("write_mtg/write_mtg.jl")
include("compute_MTG/insert_nodes.jl")

export read_mtg
export isleaf
export isroot
export children
export addchild!
export traverse!
export traverse
export getroot
export nextsibling
export print
export show
export length
export DataFrame
export iterate
export siblings
export append!
export @mutate_node!
export @mutate_mtg!
export is_filtered
export delete_nodes!
export delete_node!
export insert_nodes!
export insert_node!
export write_mtg
export is_segment!
export descendants, ancestors
export Node
export AbstractNodeMTG
export NodeMTG
export MutableNodeMTG
export check_filters
export get_features
export get_classes
export get_description

end
