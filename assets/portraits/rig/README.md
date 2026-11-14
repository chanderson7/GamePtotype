# Romance portrait rigs

Edda, Farah and Kaede in the game are our own versions of their paintings: rebuilt from
them by `tools/portrait_rig.py`, from rigs that can be re-dressed, and drawn at 768×1024
as pixel art between the paintings and the lords' portraits. Godot ignores this folder and `../source/` (`.gdignore`); the game reads only
what the tool renders into `assets/portraits/`.

## What's where

| Path | What it is |
| --- | --- |
| `../source/<who>_<expression>.png` | The paintings the rigs are made from, 384×512: five expressions each (Farah's files are `farid_*`). Also the wedding paintings (`tools/portrait_wedding.py` makes them from these) and, in `../source/face/`, their blinks and glances (`tools/portrait_faces.py`). |
| `<who>/regions_<expression>.png` | What each pixel of a painting is, one flat colour per part. Paint over it to fix a part. |
| `outfits.json` | Each woman's outfits: for each part, a ramp of colours or nothing (the painter's own). |
| `../<who>_<expression>.png`, `../face/` | What the game shows: rendered here, don't edit by hand. |

## How a portrait is made

1. **The body:** every expression wears the neutral painting's body. Above the neck
   (`NECK` in the tool) is the expression's own head, blended over 12 pixels. So one
   outfit dresses all five expressions alike.
2. **The parts:** skin, eyes, hair, inner garment (the linen), outer garment (coat,
   dress, robe), accent (Kaede's plum panels), trim (embroidery and borders), belt or
   sash, metal (clasps, buckles), accessory (Kaede's hairpin). They're found from
   hand-placed outlines and colour rules (`RIGS` in the tool) and saved as the region
   maps.
3. **The outfit:** a part given a ramp, like `["120a14", "3a0d1e", "6e1a30", "9c2c44", "c65a6a"]`
   (dark to light), is dyed by the painting's own light and shade along that ramp, so
   the painter's folds and highlights stay. A part left out keeps its painted colours.
4. **The look** (`"_style"` in `outfits.json`):
   - `"pixel"` (what the game uses): pixel art on a 192×256 grid (`"grid"`), drawn at
     768×1024, between the paintings (384×512) and the lords (120×160). The painting is
     resampled sharply onto the grid, so eyes and lips survive. Each part gets a few
     flat tones of its own, its `"tones"` (or its outfit's ramp), with ordered dithering
     where they meet (`"dither"`, 0 for none). The face also keeps tones for whatever is
     far from every skin tone (irises, lips, lashes: `"features"`). Hair is streaked
     along its strands, and a dark rim runs round the figure, as on the lords. A bigger
     grid (256×341, say) is closer to the paintings; a smaller one to the lords.
   - `"painted"`: the painting at twice the size, sharpened, with single hair strands,
     a twill in the wool, a weave in the linen and a rim on metal: smooth, as first made.
   The blinks and glances are drawn the same way, in the very same tones, so they sit
   exactly on it.

## Changing an outfit

- Add or edit an outfit in `outfits.json`, then look at it on all five expressions:
  `python3 tools/portrait_rig.py preview edda wine_silver /tmp/outfits`
- To put an outfit in the game, render with it: `python3 tools/portrait_rig.py render wine_silver`
  (the game shows whatever was rendered last; `everyday` is the painter's own colours).
  Then run the suite (`game_feel_tests`, `portrait_scale_tests` check the faces).

## Fixing a part

The region maps are close but not perfect: the line where Edda's jaw meets her neck,
for one, counts as hair, so it takes a new hair colour. Open
`<who>/regions_<expression>.png` in any paint program and paint the pixels with the
right part's colour (no smoothing). The colours are `REGION_COLORS` in the tool: skin
F0BE96, eyes 3CDC78, hair 964614, inner FAFAE6, outer 1E5AC8, accent 962896, trim FFD228,
belt 783C1E, metal FF7800, accessory 00C8DC, nothing 000000. A map you've painted is
kept: `regions` only writes the maps that are missing. Delete one to make it again.
Wedding paintings aren't mapped yet: they're doubled and given hair strands, but
not re-dyed or woven.

## Changing what they wear, not just its colour

A recolour keeps the painted garment's shape. A new garment (another neckline, sleeves,
a cloak) has to be drawn over the painting in code, the way `tools/portrait_wedding.py`
draws the wedding gowns, crowns and veils. That's the next step for the rig: garments as
drawn layers it can put on or take off.

## Repainting a source

A new or repainted painting goes in `../source/` at 384×512, with the same framing: the
eyes where today's are (the blink strip is x 106–210, y 104–176). Then run, in order,
`tools/portrait_wedding.py`, `tools/portrait_faces.py`, delete that woman's region maps,
`tools/portrait_rig.py regions` (check the maps by eye), and `tools/portrait_rig.py render`.
