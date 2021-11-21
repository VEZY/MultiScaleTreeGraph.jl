# The `.mtg` file format

The `.mtg` file format was developed in the [AMAP lab](https://amap.cirad.fr/) to be able to describe a plant in the MTG format directly in a file.

The file format is generally used when measuring a plant on the field or to write on disk the results of an architectural model such as AMAPSim or VPalm for example. This format helps exchange and archive data about plants in a standard and efficient way.

The format is described in details in the original paper from Godin et al. (1997), but our implementation in Julia is detailed in this section.

## Example plant

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

The corresponding MTG file is provided with this package. Let's print it:

```@example
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
println(read(file, String))
```
