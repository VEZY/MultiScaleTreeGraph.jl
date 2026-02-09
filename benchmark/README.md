# Benchmarks

Benchmarks are configured for [AirspeedVelocity.jl](https://github.com/MilesCranmer/AirspeedVelocity.jl) in CI.

Run the benchmark suite locally:

```bash
julia --project=benchmark benchmark/benchmarks.jl
```

Workloads currently covered:

- full-tree traversal
- traversal + data extraction from descendants
- repeated many-small queries (`children`, `parent`, `ancestors`)
