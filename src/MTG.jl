module MTG
using AbstractTrees
using Printf
using DataFrames
import MutableNamedTuples:MutableNamedTuple
using DelimitedFiles
using OrderedCollections
import XLSX:readxlsx,sheetnames
import SHA.sha1 # for naming the cache variable
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
include("compute_MTG/check_filters.jl")
include("compute_MTG/mutation.jl")
include("compute_MTG/append_attributes.jl")
include("compute_MTG/traverse.jl")
include("compute_MTG/delete_nodes.jl")
include("compute_MTG/filter/filter-funs.jl")
include("write_mtg/update_sections.jl")
include("write_mtg/write_mtg.jl")
include("compute_MTG/insert_nodes.jl")
include("compute_MTG/mutation_helpers.jl")
include("compute_MTG/DataFrame.jl")
include("compute_MTG/nleaves.jl")
include("compute_MTG/pipe_model.jl")
include("compute_MTG/get_node.jl")

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
export descendants, ancestors, descendants!
export Node
export AbstractNodeMTG
export NodeMTG
export MutableNodeMTG
export check_filters
export get_features
export get_classes
export get_description
export clean_cache!
export branching_order!
export nleaves!, nleaves, nleaves_siblings!
export pipe_model!
export get_node

end
