# Default input icons

Generated using the built-in image_gen tool on September 8, 2026. Charcoal faces,
white labels and transparent backgrounds. These are fallback glyphs loaded by the action system through `glyphs.canis`.

| Sheet | Size | Icons |
| --- | --- | --- |
| [xbox.png](xbox.png) | 1254 × 1254 | 36 |
| [switch.png](switch.png) | 1254 × 1254 | 36 |
| [playstation.png](playstation.png) | 1254 × 1254 | 36 |
| [steam_controller.png](steam_controller.png) | 1254 × 1254 | 36 |
| [keyboard_en_us.png](keyboard_en_us.png) | 1448 × 1086 | 104 |

Switch uses Pro-controller controls plus SL/SR. PlayStation uses DualSense
controls. Steam Controller means the original 2015 device: one analog stick,
two trackpads and two rear grip buttons. Keyboard covers a US English 104-key
layout, including left/right modifiers and the number pad.

Each matching `.atlas.json` lists numbered IDs, descriptive labels, pixel
rectangles `[x, y, width, height]` and normalized `[left, top, right, bottom]`
UVs. Coordinates start at the top left. Convert vertical UV coordinates when
the renderer expects a bottom-left origin. Preserve aspect ratio when drawing.
Use the recorded rectangles: generated artwork has uneven outer margins.
The four unused keyboard cells are not indexed.

The PNG alpha channels are preserved as generated. Some edges have fine raster
fringing. The keyboard prompt has been inspected in the controls menu; other
controller families still need an in-game hardware review. The JSON atlas metadata
is converted to the engine YAML catalog by `build_glyph_catalog.py`.

Steam-native prompts select glyphs from the actual remapped action
origins through the optional provider. These defaults represent controls,
not a guarantee about which control is bound to an action.

The exact generation prompts and row/column labels are in
[docs/input-icons](../../../../../docs/input-icons/). To rebuild metadata without
altering image pixels, run `python docs/input-icons/index_sheets.py` from the
repository root (requires Pillow and NumPy).

After rebuilding atlas metadata, run `python3 docs/input-icons/build_glyph_catalog.py`
from the repository root to rebuild `glyphs.canis`. This does not alter PNG pixels.
Canis Sprite2D takes `(left, 1-bottom, right-left, bottom-top)`; ImGui takes the
top-left endpoints directly. Unknown controls use readable text fallbacks.
