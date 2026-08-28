# Compatibility and deprecations

MultiScaleTreeGraph converts historical MTG files into the current in-memory model, but
maintained package code, examples, and tutorials should use the current Julia API. A
deprecated Julia entry point is a migration aid, not a second permanent API.

## Scheduled removals

The following deprecated entry points are retained through the 0.16 release series and are
scheduled for removal in MultiScaleTreeGraph 0.17:

| Deprecated entry point | Historical role | Category | Current replacement | Retained evidence and warning | Exit |
|:--|:--|:--|:--|:--|:--|
| `Node(name, id, ...)` constructors | Public API from when a separate string name identified each node | Public API deprecation | `Node(id, ...)`; a node's MTG symbol carries its identity | `test/test-compatibility.jl`; Julia deprecation warning | Remove in 0.17 |
| `insert_node!(node, template, maxid)` | Public predecessor of the explicit insertion operations | Public API deprecation | Normally `insert_parent!(node, template)`. To preserve a caller-managed ID counter, use `insert_parent!(node, template, _ -> typeof(node_attributes(node))(), maxid)` | `test/test-compatibility.jl`; Julia deprecation warning | Remove in 0.17 |
| `type=` in attribute-value overloads of `descendants`, `descendants!`, `ancestors`, and `ancestors!` | Caller-selected result storage before attribute result types were inferred | Public API deprecation | Omit `type=`. Single-key non-mutating calls infer when possible; use an explicit typed buffer when an exact element type is required. Use `ignore_nothing=true` to filter absent values | `test/test-compatibility.jl`; Julia deprecation warning | Remove in 0.17 |

An inventory of MultiScaleTreeGraph and its maintained ecosystem packages found no package,
tutorial, or documentation caller of the named constructors or `insert_node!`. The only
maintained uses of `type=` on `descendants` or `ancestors` are the explicit compatibility
checks. Ordinary tests use the current inferred-result API; `traverse(...; type=...)` remains
a separate supported keyword. A deprecated call found in maintained downstream code should
be migrated, not used to justify extending this window.

### Migration details

- The named-node family includes root constructors for `NamedTuple` and
  `MutableNamedTuple`, attached-node constructors for those and other attribute
  backends, plus the low-level
  parent/children/cache form. For the ordinary constructors, remove the leading string name
  and keep the ID, MTG metadata, parent (when present), and attributes. Code using the
  low-level form should use the current constructor shape and pass an actual children vector
  instead of the historical `nothing` placeholder.
- `insert_node!` historically inserted a parent. Replace it with `insert_parent!`; retain the
  explicit attribute factory and `maxid` argument only when the caller really owns that ID
  counter.
- For single-key `descendants` and `ancestors` calls, remove `type=`. Columnar attributes
  provide an inferred result type; without enough type information, a result may use a
  broader element type. Multi-key calls retain their heterogeneous result representation.
  When an exact element type is required, encode it in the reusable output buffer, for
  example `values = Union{Nothing,Float64}[]` followed by
  `descendants!(values, node, :Width)`. The dict-backed cache-producing
  `descendants!(node, key)` form can also drop `type=`; callers that require a typed result
  should use the explicit-buffer form.

This removal does not apply to `traverse(...; type=...)`, where `type` remains part of the
current public API.

!!! compat "Base function exports"
    MultiScaleTreeGraph defines methods of Base functions such as `show`, `length`,
    `iterate`, `append!`, `names`, and `==`, but no longer re-exports those names. They
    remain available normally because Base owns them; callers do not need to qualify or
    import them from MultiScaleTreeGraph.

## Compatibility that remains intentional

| Boundary | Producer | Category | Normalization | Test/behavior | Exit |
|:--|:--|:--|:--|:--|:--|
| String forms of MTG symbols and links | User code and historical files | Public input normalization | Convert once to `Symbol` | Node and MTG reader tests; no warning | Retain while these public input forms are documented |
| Historical MTG text files | External MTG datasets | External format | `read_mtg` parses into the canonical node and columnar representation | `test/test-read_mtg.jl` and `test/test-write_mtg.jl`; no warning | Indefinite external-format boundary |

These input formats do not require ordinary runtime code to maintain a second writable
representation.

### Private traversal fallback

The public contract is the result of `get_features`. The private
`_get_features_legacy` helper is an internal traversal fallback used when the optimized
columnar path cannot safely handle a backing store. Its name describes the implementation
path, not a legacy MTG file format. It is neither exported nor versioned as a compatibility
API and may be changed or removed without a deprecation cycle, provided `get_features`
retains its public behavior. The equivalence checks in `test/test-summary.jl` protect that
behavior; they do not make the helper public.

Support for external MTG text files is independent of this helper and remains the permanent
reader/writer boundary described above.

If a deprecated Julia call still appears in maintained code, migrate that caller instead of
adding another compatibility branch.
