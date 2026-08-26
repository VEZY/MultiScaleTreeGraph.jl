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
| `type=` in `descendants` and `ancestors` | Caller-selected result storage before attribute result types were inferred | Public API deprecation | Omit `type=`; typed columns infer the result type. Use `ignore_nothing=true` to filter absent values | `test/test-compatibility.jl`; Julia deprecation warning | Remove in 0.17 |

An inventory of MultiScaleTreeGraph and its maintained ecosystem packages found no package,
tutorial, or documentation caller of the named constructors or `insert_node!`. The only
maintained uses of `type=` are the explicit compatibility checks. Ordinary tests use the
current inferred-result API. A deprecated call found in maintained downstream code should be
migrated, not used to justify extending this window.

!!! compat "Base function exports"
    MultiScaleTreeGraph defines methods of Base functions such as `show`, `length`,
    `iterate`, `append!`, `names`, and `==`, but no longer re-exports those names. They
    remain available normally because Base owns them; callers do not need to qualify or
    import them from MultiScaleTreeGraph.

## Compatibility that remains intentional

| Boundary | Producer | Category | Normalization | Test/behavior | Exit |
|:--|:--|:--|:--|:--|:--|
| String forms of MTG symbols and links | User code and historical files | Public input normalization | Convert once to `Symbol` | Node and MTG reader tests; no warning | Retain while these public input forms are documented |
| Historical MTG text files | External MTG datasets | External format | `read_mtg` parses into the canonical node and columnar representation | Reader and writer round-trip tests; no warning | Indefinite external-format boundary |

These input formats do not require ordinary runtime code to maintain a second writable
representation.

If a deprecated Julia call still appears in maintained code, migrate that caller instead of
adding another compatibility branch.
