# Romance portrait rigs

Edda, Farah and Kaede in the game are our own versions of their paintings. Their faces
and hair are rebuilt from the paintings by `tools/portrait_rig.py`; everything they wear
is designed and drawn by `tools/portrait_wardrobe.py`. Both are drawn at 768×1024 as pixel
art between the paintings and the lords' portraits. Godot ignores this folder and
`../source/` (`.gdignore`); the game reads only what the tool renders into
`assets/portraits/`.

## What's where

| Path | What it is |
| --- | --- |
| `../source/<who>_<expression>.png` | The paintings the rigs are made from, 384×512: five expressions each (Farah's files are `farid_*`). Also the wedding paintings (`tools/portrait_wedding.py` makes them from these) and, in `../source/face/`, their blinks and glances (`tools/portrait_faces.py`). |
| `<who>/regions_<expression>.png` | What each pixel of a painting is, one flat colour per part. Paint over it to fix a part. |
| `outfits.json` | Each woman's outfits: lists of pieces to draw (`"pieces"`), or ramps that recolour the painted clothes. `"_game"` names the outfits the game shows. |
| `<who>/template.png` | Her figure on the 192×256 grid, unclothed and grey, with the wardrobe's anchors marked: draw a hand-made piece over it. |
| `<who>/layers/<name>.png` | Hand-drawn pieces, worn with `{"piece": "layer", "name": "<name>"}`. |
| `../<who>_<expression>.png`, `../<who>_<outfit>_<expression>.png`, `../face/` | What the game shows: rendered here, don't edit by hand. |

## What she wears in the game

Each woman has three outfits (`"_game": ["everyday", "court", "travel"]`), each in her
own people's style:

| | Everyday | Court | Travel |
| --- | --- | --- | --- |
| **Edda** (Vardish) | teal wool gown, square neck, laced, over a linen shift; belt; amber brooch | wine damask gown with hanging sleeves lined in gold; green fur-trimmed mantle; gold circlet, chain and earrings with garnets | moss gown, high-necked shift, belt; brown cloak with the hood down, rust lining, amber clasp |
| **Farah** (Kharzani) | indigo kaftan open over linen, gold diamond trim; striped saffron sash; coin necklace; turquoise earrings | crimson damask kaftan, gold sash; coin circlet and necklace with turquoise; sheer white veil edged in gold | rust riding coat; brown sash; indigo head scarf, dotted and banded in gold |
| **Kaede** (Ryumon) | charcoal kimono, linen collar; moss obi with a maple cord; jade hairpin | plum kimono with chrysanthemums, layered white and maple collars; gold damask obi; coral pin with a dangle; gold comb | slate kimono under a charcoal haori; narrow moss obi |

Where she wears which (`StoryArt.outfit_for`):
- **Court** in the hall of a feast that's on, where she's among the guests. Dances are always at a feast.
- **Travel** once she's been driven from her own seat (her town taken) and lives out of what she carried.
- **Everyday** otherwise. The talks are in her own room, so where you are matters only at a feast.

The People page, the hall's list of guests, the talks and the dance all show her dressed
so. The wedding paintings are their own (`tools/portrait_wedding.py`).

## How a portrait is made

1. **The head:** every expression's own head (face and hair) on the neutral painting's
   neck. Above the neck (`NECK` in the tool) it is the expression's, blended over 12
   pixels, so one outfit dresses all five expressions alike.
2. **The parts:** skin, eyes, hair, and the painted clothes' parts. They're found from
   hand-placed outlines and colour rules (`RIGS` in the tool) and saved as the region
   maps. The wardrobe keeps only the head and hair from them.
3. **The look** (`"_style"` in `outfits.json`):
   - `"pixel"` (what the game uses): pixel art on a 192×256 grid (`"grid"`), drawn at
     768×1024, between the paintings (384×512) and the lords (120×160). The painting is
     resampled sharply onto the grid, so eyes and lips survive. Each part gets a few
     flat tones of its own (its `"tones"`), with ordered dithering where they meet
     (`"dither"`, 0 for none). The face also keeps tones for whatever is far from every
     skin tone (irises, lips, lashes: `"features"`). Hair is streaked along its strands,
     and a dark rim runs round the figure, as on the lords.
   - `"painted"`: the painting at twice the size, sharpened: smooth, as first made.
4. **The clothes** (`"pieces"`): `tools/portrait_wardrobe.py` clears the painted clothes
   away and draws her neck and shoulders in her own skin tones. It then draws each piece
   in order, on the same grid, lit from the upper left like her face. Each piece takes
   its fabric's few tones, with creases at the waist and elbows, dithered where they
   meet, and is outlined where it meets another. Her loose hair falls in front of what
   she wears; veils, scarves, hoods, circlets, combs, pins and earrings go over it.

The blinks and glances are drawn the same way, in the very same tones, so they sit
exactly on it.

## Designing an outfit

An outfit is a list of pieces, drawn first to last (so a chemise comes first and a cloak
late):

```json
"court": {"pieces": [
  {"piece": "chemise", "fabric": "white", "neckline": "round"},
  {"piece": "gown", "fabric": "wine", "neckline": "square", "sleeves": "hanging",
   "pattern": "damask", "lining": "gold", "trim": {"kind": "dots", "fabric": "gold", "gem": "garnet"}},
  {"piece": "mantle", "fabric": "forest", "fur": "fur", "clasp": "gold"},
  {"piece": "circlet", "metal": "gold", "gem": "garnet"}
]}
```

The pieces and their options are listed at the top of `tools/portrait_wardrobe.py`.
- **Garments:** chemise, gown, coat, wrap (kimono), jacket (haori), mantle, cloak (hood up or down), sash (obi), belt.
- **Headwear:** scarf, veil.
- **Jewellery:** necklace (chain, pearls, coins, beads), choker, brooch, earrings.
- **In the hair:** circlet, comb, pin, flowers.

Fabrics (`linen`, `teal`, `wine`, `indigo`, `fur`…), metals (`gold`, `silver`, `bronze`) and
gems (`garnet`, `jade`, `turquoise`…) are named in the tool, or given as a ramp of hex
colours, darkest first. Garments take a `neckline` (square, v, round, boat, high), a
`pattern` (damask, stripes, checks, dots, diamonds, kiku) and a `trim` (braid, dots,
diamonds, band, fur).

To work on one:
- Look at an outfit on all five expressions: `python3 tools/portrait_rig.py preview edda court /tmp/outfits`
- See every outfit of all three side by side: `python3 tools/portrait_rig.py sheet /tmp/outfits.png`
- Put it in the game: add its name to `"_game"` and to `StoryArt.OUTFITS`
  (`scripts/ui/story_art.gd`), say where she wears it in `StoryArt.outfit_for`, and run
  `python3 tools/portrait_rig.py render` (or `render court` for one outfit). Then
  `godot --headless --path . --import`, and run `portrait_scale_tests`, which checks every
  outfit's portraits are 768×1024 and blink.

An outfit without `"pieces"` is a recolour of the painted clothes instead: for each
part, a ramp of colours (`["120a14", "3a0d1e", "6e1a30", "9c2c44", "c65a6a"]`, dark to
light) dyed by the painting's own light and shade. The `painted` outfits are those: the
painter's own clothes.

## Drawing a piece by hand

When code can't draw what you want (a particular embroidery, a fur collar of your own, a
shawl), draw it:

1. `python3 tools/portrait_rig.py template` writes `<who>/template.png`. It is her figure
   on the 192×256 grid, grey and unclothed, with the anchors marked: white at the neck,
   red at the shoulders, blue at the sternum, cyan along the waist, green at the ear,
   yellow along the hairline, magenta at the bun.
2. In any pixel editor (Aseprite, Pixelorama, Piskel), draw the piece on its own layer
   over the template, 192×256, one pixel per grid pixel, no smoothing. Leave everything
   else transparent.
3. Save just the piece as `<who>/layers/<name>.png`.
4. Wear it: `{"piece": "layer", "name": "<name>"}`, among the other pieces where it goes
   in the order.
   - Drawn in full colour, it is worn as drawn.
   - Drawn in greys (light where it's lit) and given `"dye": "<fabric>"`, it's coloured
     in that fabric's tones, so one drawing comes in every colour.
   - `"over_hair": true` puts it over her hair, like a veil.

It's outlined where it meets her other clothes, like a drawn piece. `<who>/layers/` also
holds an example, `shawl.png`, worn by Edda's `shawl_example` outfit (not in the game),
dyed rose.

## Fixing a part

The region maps are close but not perfect: the line where Edda's jaw meets her neck,
for one, counts as hair. Open `<who>/regions_<expression>.png` in any paint program and
paint the pixels with the right part's colour (no smoothing). The colours are
`REGION_COLORS` in the tool: skin F0BE96, eyes 3CDC78, hair 964614, inner FAFAE6, outer
1E5AC8, accent 962896, trim FFD228, belt 783C1E, metal FF7800, accessory 00C8DC, nothing
000000. A map you've painted is kept: `regions` only writes the maps that are missing.
Delete one to make it again. Wedding paintings aren't mapped: they're drawn in the pixel
look as painted.

Where a woman's body sits on the grid (chin, neck, shoulders, arms, waist, ears,
hairline) is `BODIES` in `tools/portrait_wardrobe.py`. The template shows it; move a mark
there if a garment sits wrong on her.

## Repainting a source

A new or repainted painting goes in `../source/` at 384×512, with the same framing: the
eyes where today's are (the blink strip is x 106–210, y 104–176). Then run, in order:
1. `tools/portrait_wedding.py`
2. `tools/portrait_faces.py`
3. Delete that woman's region maps, then `tools/portrait_rig.py regions` (check the maps by eye).
4. `tools/portrait_rig.py template` (check her anchors in `BODIES`).
5. `tools/portrait_rig.py render`.
