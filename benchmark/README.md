# Benchmarks

Benchmarks are configured for [AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl) in CI.

Run the benchmark suite locally:

```bash
julia --project=benchmark benchmark/benchmarks.jl
```

Run the byte-parity, allocation, and timing gates for the streaming MTG writer:

```bash
julia --project=benchmark benchmark/write_mtg_streaming.jl
```

Run the focused correctness gate for A1 row-local mutation and topology fixtures:

```bash
julia --project=benchmark benchmark/test/runtests.jl
```

The `a1_row_mutation_topology` benchmark group uses deterministic fixtures with
32, 256, and 1,024 leaf rows plus one root. It measures cold explicit-ID
construction, one hot explicit-ID append, and `write_mtg` for dense and sparse
attributes. Row-local `pop!`, `empty!`, and sparse-toggle workloads are registered
only when a public behavior probe confirms that the loaded MultiScaleTreeGraph
revision supports row-local absence. Historical schema-wide revisions keep their
semantic oracle but are not used as a timing baseline for those different
operations.

The `automatic_id` subgroup exercises repeated ID-less node construction. For
columnar MTGs, the next ID comes from the store's cached maximum instead of a
full-tree search. The subgroup keeps the cost of automatic ID allocation visible
separately from explicit-ID construction.

The writer gate exercises 40 features at 1,000 and 10,000 nodes. It compares the
streaming path with the compatibility materialization path, measures seven alternating
samples after warmup, and checks linear scaling.

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
