# The `.mtg` file format

The `.mtg` file format was developed in the [AMAP lab](https://amap.cirad.fr/) to be able to describe a plant in the MTG format directly in a file.

The file format is generally used when measuring a plant on the field or to write on disk the results of an architectural model such as AMAPSim or VPalm for example. This format helps exchange and archive data about plants in a standard and efficient way.

The format is described in details in the original paper from Godin et al. (1997), but our implementation in Julia is detailed in this section.

## Example MTG

Let's define a very simple virtual plant composed of only two internodes and two leaves:

```@raw html
<div class="sketchfab-embed-wrapper">
<iframe title="A 3D model" width="640" height="480" src="https://sketchfab.com/models/2a699871f6f6459faa11c206bf81ae9a/embed?autospin=0.2&amp;autostart=1&amp;preload=1&amp;ui_controls=1&amp;ui_infos=1&amp;ui_inspector=1&amp;ui_stop=1&amp;ui_watermark=1&amp;ui_watermark_link=1" frameborder="0" allow="autoplay; fullscreen; vr" mozallowfullscreen="true" webkitallowfullscreen="true"></iframe>
<p style="font-size: 13px; font-weight: normal; margin: 5px; color: #4A4A4A;">
<a href="https://sketchfab.com/3d-models/a-simple-3d-plant-2a699871f6f6459faa11c206bf81ae9a?utm_medium=embed&utm_source=website&utm_campaign=share-popup" target="_blank" style="font-weight: bold; color: #1CAAD9;">A simple 3D plant</a>
by <a href="https://sketchfab.com/rvezy?utm_medium=embed&utm_source=website&utm_campaign=share-popup" target="_blank" style="font-weight: bold; color: #1CAAD9;">rvezy</a>
on <a href="https://sketchfab.com?utm_medium=embed&utm_source=website&utm_campaign=share-popup" target="_blank" style="font-weight: bold; color: #1CAAD9;">Sketchfab</a>
</p>
</div>
```

The corresponding MTG file is provided with this package. Let's print it using Julia's built-in read method:

```@example
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
println(read(file, String))
```

This is a consequent file for such a tiny plant! This is because MTG files have a header with several sections before the MTG of the plant itself, which only appears after the `MTG:` line.

Let's dig into the information we have here.

## The MTG sections

### Introduction

An MTG file is divided into five sections. These sections are defined by a keyword and a colon. The content of each section appears on a new line right after the keyword. A section can appear right after the content of the previous section, or they can be separated by blank lines. In fact, all blank lines are ignored in an MTG file.

### The CODE section

The first section of an MTG file is the `CODE` section. It must appear first in the file as it is used to determine which version of the format specification the MTG file is following. The standard format in 2021 is the `FORM-A` specification.

### The CLASSES section

The `CLASSES` section lists all symbols used in the MTG, and associates the scale of each symbol.

The data is presented as a table with five columns:

- `SYMBOL`: the string used for the node symbol.
- `SCALE`: the scale of the symbol, meaning all nodes with the given symbol will have this scale.
- `DECOMPOSITION`: This is not used anymore
- `INDEXATION`: This is not used anymore
- `DEFINITION`: This is not used anymore

The first row of the table is reserved and shouldn't be updated. It is a standard to use the dollar sign as the symbol for the scene, *i.e.* the node with the higher scale that encompass all MTGs. This node is usually not used in an MTG because MTG files mostly describe just a single plant (or a part of), not a whole scene.

!!! warning
    The symbol must be a character string without any numbers at the end, because the index of a node is read as the numbers at the end of a node name, so if a node symbol ends with a number, it will be parsed as an index. For example a symbol written `Axis1` with index `1` will give Axis11 in the MTG, which will be parsed as `Axis` for the symbol and `11` for the index.
    Numbers are allowed inside the symbol though, *e.g.* Ax1s is allowed.

### The DESCRIPTION section

The `DESCRIPTION` section is a table with four columns, and it defines a set of topological rules the MTG nodes of a same scale must follow. The rules are completely optional, but the header of the section is mandatory. In other words, the table can be empty.

The `LEFT` column designates the symbol of a parent node, the `RIGHT` column the symbol of a child node, the `RELTYPE` column the type of links allowed between the two, and `MAX` the maximum number of times these types of connexions are allowed in the MTG. The user can use a question mark to denote no maximum.

!!! note
    The rules only apply between symbols sharing the same scale (*e.g.* a node with itself, or in our example, the Internode with a Leaf).

These rules are mainly used to check the integrity of an MTG that has been written by hand on the field.

!!! warning
    This package does not implement any check on the rules yet. You can let this section empty (with the header) for your mtg if you don't plan to read it with other tools than `MultiScaleTreeGraph.jl`.

### The FEATURES section

This section is a table with two columns that define the name of the attributes (or features) that can be attached to nodes, and the type of these attributes. This section makes sure that attributes are interpreted correctly when parsing the file.

The `NAME` column is used to give the name of an attribute, and the `TYPE` column its type. The type can be:

- `REAL` for real numbers, *e.g.* 0.1
- `INT` for integer numbers, *e.g.* 1
- `STRING` for strings, *e.g.* broken
- `ALPHA` for reserved keywords:
  + NbEl: NumBer of ELements, the number of children at the next scale
  + Length: the node length
  + BottomDiameter, the bottom tapering applied to the node for computing its geometry
  + TopDiameter, the tapering applied at the top
  + State, defines the state of a node. It can take the value D (Dead), A (Alive), B (Broken) , P (Pruned), G (Growing), V (Vegetative), R (Resting), C (Completed), M (Modified), or any combination of these given letters.

!!! warning
    This package does not implement any check on the State of a node, and does not make use of the reserved keywords.

### The MTG section

This section is the actual MTG. It describes the topology of the plant node by node, and give the possibility to add attributes to them.

The MTG is encoded as a table with tabulation separated values. The header of this section defines the columns used for describing the topology and the ones used for the attributes. The first column name is reserved and must be named `ENTITY-CODE`. Then, a set of empty column names (*i.e.* just tabulations) that defines how many columns are used for the topology. Finally, the following columns are used to define the attributes of the nodes. Their names must match the ones given in [The FEATURES section](@ref).
