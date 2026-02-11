# Benchmarks

Benchmarks are configured for [AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl) in CI.

Run the benchmark suite locally:

```bash
julia --project=benchmark benchmark/benchmarks.jl
```

Workloads currently covered:

- tiered datasets: `small` (~10k nodes), `medium` (~100k), `large` (~300k)
- full-tree traversal and traversal updates
  - one attribute update on all nodes
  - multi-attribute update on one symbol (`:Leaf`)
  - multi-attribute update on mixed symbols (`[:Leaf, :Internode]`)
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
