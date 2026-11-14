# Romance portraits

Edda, Farah and Kaede are drawn by `tools/portrait_kit/`, the same way the lords are drawn
by `tools/pixel_kit/`: flat shades per material, lit from the upper left, each part
outlined where it lies over another. They're drawn on a grid 1.6 times the lords'
(192×256, shown at 768×1024), so there's more in them: lids, lashes and ringed irises,
shaded lips, hair lock by lock, cloth with folds and patterns.

Godot ignores this folder (`.gdignore`); the game reads only what the kit renders into
`assets/portraits/`.

## What's where

| Path | What it is |
| --- | --- |
| `outfits.json` | What each woman wears: for each outfit, a list of pieces. `"_game"` names the outfits the game shows besides the wedding's. |
| `<who>/template.png` | Her figure with nothing on it, with marks where clothes sit: draw a hand-made piece over it. |
| `<who>/layers/<name>.png` | Hand-drawn pieces, worn with `{"piece": "layer", "name": "<name>"}`. |
| `tools/portrait_kit/build.py` | Who each woman is (`PEOPLE`: her face, colouring, features), her expressions (`MOODS`), and the commands below. |
| `tools/portrait_kit/face.py`, `hair.py`, `garb.py`, `canvas.py` | Heads and features; each woman's hair; garments, trims, jewellery and headwear; the drawing surface and colours. |
| `../<who>_<expression>.png`, `../<who>_<outfit>_<expression>.png`, `../face/` | What the game shows: rendered here, don't edit by hand. |
| `../source/` | The first portraits, paintings at 384×512. The game no longer uses them; kept for reference. |

Farah's files are `farid_*`.

## What she wears in the game

| | Everyday | Court | Travel | Wedding |
| --- | --- | --- | --- | --- |
| **Edda** (Vardish) | teal kirtle, square neck with a woven edge, laced, over a linen shift; belt; amber brooch | wine damask kirtle edged in gold and stones; green mantle with ermine and a gold chain; pearls; gold circlet; earrings | moss kirtle, high-necked shift; brown cloak, hood thrown back, fur at the collar, amber clasp | hair unbound under a gold crown; woad-blue kirtle edged in gold; garnet pendant |
| **Farah** (Kharzani) | indigo kaftan banded in gold over an embroidered shirt; saffron sash; coin necklace; turquoise earrings | crimson damask kaftan; a jewelled collar with coins; coin circlet; fine veil edged in gold | rust riding coat; indigo scarf over her hair, dotted and edged in gold | crimson kaftan stitched with gold; veil; coin circlet with a garnet |
| **Kaede** (Ryumon) | slate kosode with a white under-collar; plum vest; navy obi with a maple cord; jade hairpin | rose kosode under a plum robe scattered with chrysanthemums; brocade obi; gold comb; blossoms; coral pin | charcoal kosode; slate haori with crests, tied with a cord; moss obi | white robes lined in crimson, gold crests; brocade obi; gold comb, coral pin |

Where she wears which (`StoryArt.outfit_for`):
- **Court** in the hall of a feast that's on, where she's among the guests. Dances are always at a feast.
- **Travel** once she's been driven from her own seat (her town taken).
- **Wedding** on the day.
- **Everyday** otherwise. The talks are in her own room, so where you are matters only at a feast.

## Commands

- `python3 tools/portrait_kit/build.py` renders everything the game shows:
  - each portrait, for every outfit and expression;
  - its face strip: her eyes shut, half shut, soft, glancing aside, and her brows raised
    twice (`StoryArt.FACE` and `FRAMES`; the game lays a strip over the portrait to blink);
  - a map of what swings when her head moves (loose strands, unbound hair, a veil's fall).

  Then run `godot --headless --path . --import` and the tests `portrait_scale_tests` and
  `game_feel_tests`.
- `python3 tools/portrait_kit/build.py sheet /tmp/outfits.png` shows every outfit of all three side by side.
- `python3 tools/portrait_kit/build.py faces /tmp/faces.png` shows each woman's five expressions and six faces.
- `python3 tools/portrait_kit/build.py template` writes each `<who>/template.png`.

## Designing an outfit

An outfit is a list of pieces, drawn first to last (a shift first, a cloak late):

```json
"court": {"pieces": [
  {"piece": "chemise", "cloth": "white", "neck": "round", "depth": 0.25},
  {"piece": "kirtle", "cloth": "wine", "neck": "square", "depth": 0.9, "pattern": "diamond",
   "trim": {"mat": "gold", "pattern": "embroidered", "width": 5, "gems": ["garnet", "pearl"]}},
  {"piece": "mantle", "cloth": "forest", "fur": "ermine", "metal": "gold", "stone": "garnet"},
  {"piece": "circlet", "metal": "gold", "gem": "garnet"}
]}
```

The pieces (`PIECES` in `garb.py`, each documented there):
- **Vardish:** `chemise`, `kirtle`, `mantle`, `cloak`, `belt`.
- **Kharzani:** `shirt`, `kaftan`, `sash`, `collar` (a jewelled one), `scarf`, `veil`.
- **Ryumon:** `kosode`, `overrobe` (a vest, a haori, an outer robe), `obi`, `comb`, `pin`, `flowers`.
- **For anyone:** `necklace` (chain, pearls, coins, beads), `brooch`, `earrings`, `circlet`, `crown`, `layer`.

What they take:
- **Cloth** by name (`CLOTHS` and `RAMPS` in `canvas.py`: `teal`, `wine`, `indigo`,
  `linen`, `ermine`…) or as `"#rrggbb"`, which is dyed into six shades by the same rule
  as the lords' house colours.
- **Necklines** (`neck`): square, round, v, boat, high; `depth` from 0 to 1.
- **Patterns** in the cloth (`pattern`): a motif (dot, cross, diamond, lozenge, kiku, leaf,
  star) woven a shade lighter, or `{"motif": …, "mat": "gold"}` stitched in a material, or
  `{"stripes": 7}`.
- **Trim** (`trim`): `{"mat", "width", "pattern", "gems"}`; band patterns are plain,
  embroidered, dotted, braid, diamonds, key.
- **Metals** gold, silver, bronze; **stones** garnet, jade, pearl, coral, amber, turquoise, sapphire.
- `"hair": "unbound"` on an outfit lets Edda's hair down.

To put a new outfit in the game: add its name to `"_game"` and to `StoryArt.OUTFITS`
(`scripts/ui/story_art.gd`), and say where she wears it in `StoryArt.outfit_for`.

## Drawing a piece by hand

When the pieces can't make what you want, draw it:

1. Open `<who>/template.png` (192×256) in a pixel editor (Aseprite, Pixelorama, Piskel).
   The marks: white at the base of the neck, red at the shoulders, blue at the breastbone,
   cyan along the waist, green at the ear's lobe, yellow along the hairline.
2. Draw the piece on its own layer, one pixel per grid pixel, no smoothing. Leave
   everything else transparent.
3. Save just the piece as `<who>/layers/<name>.png`.
4. Wear it: `{"piece": "layer", "name": "<name>"}`, among the other pieces where it goes
   in the order.
   - Drawn in greys (light where it's lit) with `"dye": "<cloth>"`, it takes that cloth's
     shades, so one drawing comes in every colour.
   - Drawn in colour, it's worn as drawn.
   - `"over_hair": true` puts it over her hair; `"behind": true` behind her neck.

It's outlined where it lies over her other clothes, like any piece. `edda/layers/shawl.png`
is an example, worn dyed rose by Edda's `shawl_example` outfit (not in the game).

## Changing a face

- **Who she is:** `PEOPLE` in `build.py` picks her head shape, eyes, brows, nose and mouth
  (the shapes are `HEADS`, `EYES`, `BROWS`, `NOSES`, `MOUTHS` in `face.py`), her freckles,
  and her skin, hair and eye colours.
- **Her expressions:** `MOODS` in `build.py` sets, for each of the five, how far her lids
  are down, where she looks, each brow's mood and her mouth's.
- **Her hair:** one function each in `hair.py`.
- Every head shares where the features sit. If you move them, the face strip must still
  hold everything that changes in a blink: `build.py` stops if it doesn't
  (`FACE_STRIP` there, `StoryArt.FACE` in the game, which is twice it).
