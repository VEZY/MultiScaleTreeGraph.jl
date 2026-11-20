The MTG files in this directory come from [OpenAlea.MTG's test
data](https://github.com/openalea/mtg/tree/34e15035db740c3ed03d3a0c94b87391859f8d1b/test/data)
and are distributed under the upstream [CeCILL-C license](LICENSE).
They are copied byte for byte.

| File | Reader coverage |
| --- | --- |
| `mtg3.mtg` | Repeated labels and branches in a single-scale graph |
| `mtg51.mtg` | Indented decomposition and branching at different scales |
| `test6_apricot2.mtg` | Whitespace in a topology cell and in an empty integer feature cell |
| `test8_boutdenoylum2.mtg` | Walnut data with the same feature schema as the larger `test9_noylum2.mtg` |
| `test10_agraf.mtg` | The complete `agraf.mtg` from issue #116, with `<<` and endpoint feature values |
| `test12_wij10.mtg` | A single apple tree with the `TOPO` header, nested ranges, and the same feature schema as `test11_wij10.mtg` |

Upstream uses these data for parsing, traversal, statistics, and PlantFrame.
The Julia tests check reading, including node counts per scale. OpenAlea
includes an implicit scale-zero root in its counts for these files.
