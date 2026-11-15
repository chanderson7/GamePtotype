# Romance portraits

Edda, Farah and Kaede are drawn by `tools/portrait_kit/`, the same way the lords are drawn
by `tools/pixel_kit/`: flat shades per material, lit from the upper left, each part
outlined where it lies over another. They're drawn on a grid 1.6 times the lords'
(192×256, shown at 768×1024), so there's more in them: lids, lashes and ringed irises,
shaded lips, hair lock by lock, cloth with folds and patterns.

What sets them apart from the lords, in the same style:
- **Hair that flows.** Drawn as large tapered locks that curve along a path, each round
  across its width with strand lines and a band of sheen (`lock` in `hair.py`): Edda's long
  waves with a ribbon-tied plait among them, Farah's ringlets, Kaede's straight glossy hair
  drawn back behind her ears under a pinned top knot; a few single hairs come loose
  (`wisps`). What hangs loose swings when her head moves. Nothing covers it: there are
  no hoods or head scarves.
- **Cloth that hangs.** Shoulders and garments have rounded corners (`spoly`), and folds
  curve as they fall (`flowing` in `garb.py`): gathers at the shoulder, creases in the
  bend of the arm.
- **A pose of her own.** Edda's head a little to one side, Farah upright with her chin
  lifted, Kaede's head lowered; one shoulder let down; a jaw of her own (`POSES` in `build.py`).
- **She speaks.** Her mouth opens on the words while her line is written out.
- **A second light.** A fainter light from behind on the right lifts the shaded edge of
  her hair, jaw and shoulders (`compose(rim=True)` in `canvas.py`); the lords have one light.
- **Marks of her own.** Edda's freckles, Farah's kohl-lined eyes, Kaede's beauty mark and
  reddened lips (`PEOPLE` in `build.py`).
- **Something of her work.** A steward's keys at Edda's breast, an envoy's seal on a ribbon
  for Farah, an archivist's brush through Kaede's knot.
- **Dress that follows the year and your losses:** winter clothes, and mourning.

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

| | Everyday | Court | Travel | Winter | Mourning | Wedding |
| --- | --- | --- | --- | --- | --- | --- |
| **Edda** (Vardish) | teal kirtle, square neck with a woven edge, laced, over a linen shift; belt; amber brooch; her keys | wine damask kirtle edged in gold and stones; green mantle with ermine and a gold chain; pearls; gold circlet; earrings | moss kirtle, high-necked shift; brown cloak, hood thrown back, fur at the collar, amber clasp | green cloak with fur at the collar and a rust lining, over a deep teal kirtle | charcoal kirtle, plain; a black ribbon | a gold crown; woad-blue kirtle edged in gold; garnet pendant |
| **Farah** (Kharzani) | indigo kaftan banded in gold over an embroidered shirt; saffron sash; her seal on a crimson ribbon; turquoise earrings | crimson damask kaftan; a jewelled collar with coins; coin circlet; fine veil edged in gold | rust riding coat; an indigo scarf wound at her neck; amber earrings | quilted plum kaftan under a brown mantle edged with sable; her seal | black kaftan edged in silver over white; a white veil | crimson kaftan stitched with gold; veil; coin circlet with a garnet |
| **Kaede** (Ryumon) | slate kosode with a white under-collar; plum vest; navy obi with a maple cord; jade hairpin and her brush | rose kosode under a plum robe scattered with chrysanthemums; brocade obi; gold comb; blossoms; coral pin | charcoal kosode; slate haori with crests, tied with a cord; moss obi | quilted rust robe over navy; a cream scarf wound at her neck | black kosode with white crests and collar | white robes lined in crimson, gold crests; brocade obi; gold comb, coral pin |

Where she wears which (`StoryArt.outfit_for`), the first that holds:
- **Wedding** on the day.
- **Court** in the hall of a feast that's on, where she's among the guests. Dances are always at a feast.
- **Mourning** for three days after one of your captains falls, if she has come to know
  you (courting, committed, engaged, married or a friend).
- **Travel** once she's been driven from her own seat (her town taken).
- **Winter** in winter: the last quarter of a 96-day year that begins in spring on the
  campaign's first day (`StoryArt.season`). Nothing else in the game follows the seasons yet.
- **Everyday** otherwise. The talks are in her own room, so where you are matters only at a feast.

## Commands

- `python3 tools/portrait_kit/build.py` renders everything the game shows:
  - each portrait, for every outfit and expression;
  - its face strip: her eyes shut, half shut, soft, glancing aside, and her brows raised
    twice (`StoryArt.FACE` and `FRAMES`; the game lays a strip over the portrait to blink);
  - its mouth strip: her mouth open on a word (`StoryArt.MOUTH`, in `../mouth/`), laid over
    whatever face she has while she speaks;
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
- **Vardish:** `chemise`, `kirtle`, `mantle`, `cloak` (its hood thrown back), `belt`.
- **Kharzani:** `shirt`, `kaftan`, `sash`, `collar` (a jewelled one), `veil` (worn at the back of her head: nothing covers her hair).
- **Ryumon:** `kosode`, `overrobe` (a vest, a haori, an outer robe), `obi`, `neckwrap`, `comb`, `pin`, `flowers`.
- **For anyone:** `necklace` (chain, pearls, coins, beads), `brooch`, `earrings`, `circlet`, `crown`, `layer`.
- **What each carries:** `keys` (Edda), `seal` (Farah), `brush` (Kaede).

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
- `"ribbon": "<cloth>"` on an outfit is the ribbon that ties Edda's plait (teal unless said).

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
  (the shapes are `HEADS`, `EYES`, `BROWS`, `NOSES`, `MOUTHS` in `face.py`), her marks
  (`freckles`, `kohl`, `mole`), and her skin, lip, hair and eye colours.
- **Her expressions:** `MOODS` in `build.py` sets, for each of the five, how far her lids
  are down, where she looks, each brow's mood and her mouth's.
- **Her hair:** one function each in `hair.py`, built from `lock` (a tapered lock along a
  path: its width, where it thins, where its sheen lies) over a `mass` of hair beneath.
- **How she holds herself:** `POSES` in `build.py` (how low her head sits, how far it
  leans, which shoulder is let down). Clothes and layers are drawn on the unposed figure
  (the template shows it) and move with the pose.
- Every head shares where the features sit. If you move them, the face strip must still
  hold everything that changes in a blink, and the mouth strip everything that changes
  when she speaks: `build.py` stops if they don't (`FACE_STRIP` and `MOUTH_STRIP` there,
  `StoryArt.FACE` and `MOUTH` in the game, which are twice them).
