# Benchmarks

Benchmarks are configured for [AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl) in CI.

Run the benchmark suite locally:

```bash
julia --project=benchmark benchmark/benchmarks.jl
```

Workloads currently covered:

- tiered datasets: `small` (~10k nodes), `medium` (~100k), `large` (~300k)
- full-tree traversal and traversal updates
  - one/multi-attribute updates using node indexing (`node[:k]`)
  - one/multi-attribute updates using explicit API (`attribute`/`attribute!`)
  - one symbol (`:Leaf`) and mixed symbols (`[:Leaf, :Internode]`)
- descendants queries
  - one/many attributes, one symbol
  - one/many attributes, mixed symbols
  - `ignore_nothing=true/false`
  - in-place and allocating variants
- repeated many-small queries
  - `children`, `parent`, `ancestors`, `ancestors!`
  - repeated descendants retrieval with and without in-place buffers
- API surface (small tier)
  - insertion/deletion/pruning
  - `transform!`, `select!`
  - `symbol_table` / `mtg_table`
  - `write_mtg`
