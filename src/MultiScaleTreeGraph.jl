module MultiScaleTreeGraph

using AbstractTrees
using Printf
import MutableNamedTuples: MutableNamedTuple
using DelimitedFiles
using OrderedCollections
import XLSX: readxlsx, sheetnames
import SHA: sha1 # for naming the cache variable
import Base
import DataFrames: DataFrame, insertcols!
import DataFrames: transform!, transform # We define our own version for transforming the MTG
import DataFrames: select!, select # We define our own version for transforming the MTG
import DataFrames: rename! # We define our own version for renaming node attributes
import Tables
import MetaGraphsNext: MetaGraph, code_for, add_edge! # Transform to MetaGraph
import Graphs.DiGraph
import Dates: Date, @dateformat_str, format

include("types/AbstractNodeMTG.jl")
include("types/Attributes.jl")
include("types/Node.jl")
include("read_MTG/read_MTG.jl")
include("read_MTG/strip_comments.jl")
include("read_MTG/utils-string.jl")
include("read_MTG/parse_section.jl")
include("read_MTG/parse_mtg.jl")
include("read_MTG/expand_node.jl")
include("compute_MTG/node_funs.jl")
include("print_MTG/print.jl")
include("compute_MTG/caching.jl")
include("compute_MTG/equality.jl")
include("compute_MTG/indexing.jl")
include("compute_MTG/descendants.jl")
include("compute_MTG/ancestors.jl")
include("compute_MTG/check_filters.jl")
include("compute_MTG/mutation.jl")
include("compute_MTG/append_attributes.jl")
include("compute_MTG/traverse.jl")
include("compute_MTG/columnarize.jl")
include("compute_MTG/transform.jl")
include("compute_MTG/select.jl")
include("compute_MTG/delete_nodes.jl")
include("compute_MTG/prune.jl")
include("compute_MTG/filter/filter-funs.jl")
include("compute_MTG/summary.jl")
include("write_mtg/write_mtg.jl")
include("compute_MTG/insert_nodes.jl")
include("compute_MTG/mutation_helpers.jl")
include("compute_MTG/nleaves.jl")
include("compute_MTG/pipe_model.jl")
include("compute_MTG/get_node.jl")
include("conversion/DataFrame.jl")
include("conversion/Tables.jl")
include("conversion/MetaGraph.jl")

export read_mtg
export isleaf
export isroot
export children, lastchild
export reparent!, rechildren!
export addchild!
export traverse!
export traverse
export transform!, transform, select!, select
export get_root
export nextsibling, prevsibling, lastsibling
export print
export show
export length
export DataFrame
export MetaGraph
export iterate
export siblings
export append!
export @mutate_node!
export @mutate_mtg!
export is_filtered
export delete_nodes!
export delete_node!
export prune!
export insert_parents!, insert_generations!, insert_children!, insert_siblings!
export insert_parent!, insert_generation!, insert_child!, insert_sibling!
export write_mtg
export is_segment!
export descendants, ancestors, ancestors!, descendants!
export Node
export AbstractNodeMTG
export NodeMTG
export MutableNodeMTG
export (==)
export check_filters
export get_features, get_attributes
export names, scales, symbols, components
export node_id, node_mtg, node_attributes
export symbol, scale, index, link
export symbol!, scale!, index!, link!
export ColumnarStore
export Column, SymbolBucket, MTGAttributeStore, NodeAttrRef
export attribute, attribute!, attributes, attribute_names
export add_column!, drop_column!, rename_column!
export descendants_strategy, descendants_strategy!
export columnarize!
export symbol_table, mtg_table
export list_nodes
export get_classes
export get_description
export cache_nodes!, clean_cache!
export branching_order!
export nleaves!, nleaves, nleaves_siblings!
export pipe_model!
export get_node
export new_child_link
export new_id, max_id

end
