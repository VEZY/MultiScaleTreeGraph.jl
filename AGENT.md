# MultiScaleTreeGraph Performance Agent Notes

## Goal
- Optimize traversal-heavy workloads for very large trees.
- Prioritize low allocations and type-stable code paths.

## Benchmark Commands
- Local suite:
  - `julia --project=benchmark benchmark/benchmarks.jl`
- Package tests (workaround for current precompile deadlock on Julia 1.12.1):
  - `julia --project --compiled-modules=no -e 'using Pkg; Pkg.test()'`

## CI Benchmarks
- Uses `AirspeedVelocity.jl` via `.github/workflows/Benchmarks.yml`.
- Benchmark definitions live in `benchmark/benchmarks.jl` and must expose `const SUITE`.

## Current Hot Paths
- `src/compute_MTG/traverse.jl`
- `src/compute_MTG/ancestors.jl`
- `src/compute_MTG/descendants.jl`
- `src/compute_MTG/indexing.jl`
- `src/compute_MTG/check_filters.jl`
- `src/types/Node.jl`
- `src/compute_MTG/node_funs.jl`

## Practical Optimization Rules
- Avoid allocating temporary arrays in per-node loops.
- Prefer in-place APIs for repeated queries:
  - `ancestors!(buffer, node, key; ...)`
  - `descendants!(buffer, node, key; ...)`
- Keep filter checks branch-light when no filters are provided.
- Keep key access on typed attribute containers (`NamedTuple`, `MutableNamedTuple`, typed dicts) in specialized methods when possible.
- Preserve API behavior and add tests for every optimization that changes internals.
