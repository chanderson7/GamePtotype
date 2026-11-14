# Romance portraits at twice the detail (768×1024)

A brief for repainting Edda, Farah and Kaede with twice the detail of today's portraits:
the same women, pose, framing, palette and light, painted at 768×1024 instead of
384×512. Fifteen paintings: five expressions each. The wedding gowns and the other faces
(blinks, glances, raised brows) are made from these by `tools/portrait_wedding.py` and
`tools/portrait_faces.py`, not painted (see the steps at the end).

They're made with the same image generator as the originals (`image_gen`; see
`story-art-manifest.md`), which this repository's cloud sessions don't have. Each
prompt edits today's painting, so the face stays the face players know.

## What "twice the detail" means here

Keep:
- The person: face, age, proportions, skin, eyes, hair colour and style.
- The pose, head angle, crop, and where everything sits in the frame. The game lays the
  blink and glance faces over a fixed strip (x 212–420, y 208–352 at 768×1024), so the
  eyes must land where today's do.
- The palette, the warm upper-left light, the transparent background, and the crisp
  pixel-painting look: hard-edged clusters, no blur or airbrush.

Add:
- Finer clusters: one pixel at 768 wide where today there's one at 384, so a strand of
  hair, a lash or a stitch can be drawn on its own.
- Hair: separate strands and the braids' and curls' turns, not just bands of tone.
- Eyes and lashes: an iris ring and a catchlight, lashes as single strokes, the lid
  crease.
- Cloth: the weave of wool and linen, the stitches of the trim, folds with a lit edge.
- Metal: the clasps' engraving and a bright rim where the light catches.

## The prompt for each neutral

Give the generator today's neutral painting (`assets/portraits/<file>_neutral.png`,
doubled to 768×1024 with nearest-neighbour, so the registration carries over) and this
prompt with the character's lines filled in:

> Use case: identity-preserve, detail upscale. Repaint this Bannerfall game portrait at
> 768×1024 with twice the detail: the SAME [who], same face, age, proportions, expression,
> hairstyle, clothes, pose, crop, canvas registration, palette, warm upper-left light and
> transparent background. Keep the crisp hand-placed pixel-painting technique (hard-edged
> clusters, no blur, no airbrush, no photographic texture) but at half the cluster size,
> adding fine detail: [details]. Do not move the head, eyes or shoulders; do not add props,
> text, a frame or a background. One production portrait, 768×1024, transparent.

| Who | Game files | `[who]` | `[details]` |
| --- | --- | --- | --- |
| Edda | `edda_*.png` | woman, Edda, 28, a northern steward, with chestnut hair braided around her head into a low bun and a few loose strands, grey-green eyes, a cream linen collar with a round brass clasp, a deep teal wool dress and a brown leather belt with a brass buckle | single loose strands and the turns of each braid; grey-green irises with a dark ring and a catchlight, lashes as single strokes; the weave of the teal wool and the stitched seams of the bodice; the linen's soft fold at the collar; the clasp's engraved knot and the buckle's bright rim |
| Farah | `farid_*.png` | woman, Farah, 31, a Kharzani envoy, with warm brown skin, dark eyes, dark curly hair pinned up loosely with curls about her face, a navy coat with bands of gold geometric embroidery, a cream tunic with gold trim and a brass clasp, and a gold-worked sash | each curl's turn and highlight; dark irises with a warm catchlight; the embroidery's repeating diamonds and their gold thread; the coat's wool and the tunic's linen; the clasp's engraving; the sash's woven bands |
| Kaede | `kaede_*.png` | woman, Kaede, 27, a Ryumon archivist, with light warm skin, dark observant eyes, straight black hair in a low knot with loose strands and a wooden hairpin, layered robes (a navy outer robe, a plum panel with a woven geometric border, an off-white inner collar), a dark sash and a round bronze clasp | single strands at her temples and the knot's wrap; the hairpin's grain; dark irises with a catchlight; the woven border's pattern and the layered collars' edges; the robes' fabric texture; the bronze clasp's engraving |

## The four other expressions

From the new 768×1024 neutral, one identity-preserving edit each, with today's wording
for what changes (`story-art-manifest.md`):

> Use case: identity-preserve. Edit this [who] game portrait: change ONLY her facial
> expression to [expression]. Preserve the exact same woman, face proportions, hair,
> clothes, pose, light, pixel-painting technique and detail, canvas size (768×1024),
> registration and transparent background. No movement of head or shoulders, no props,
> text or frame.

| Expression | Edda | Farah | Kaede |
| --- | --- | --- | --- |
| amused | a small wry amused smile, slightly lifted eyebrow, gently brightened eyes | small knowing smile, one slightly lifted brow, brightened eyes | small unexpectedly playful smile and gently brightened eyes |
| thoughtful | a reflective expression, gently knit eyebrows, mouth relaxed and closed, eyes slightly lowered | reflective lowered gaze, gently knit brows, relaxed closed mouth | focused reflective gaze, slightly knit brows, relaxed closed mouth |
| concerned | restrained concern, subtly drawn brows and a serious closed mouth, no tears | restrained concern, subtly drawn brows, serious closed mouth | restrained concern, drawn brows and serious closed mouth, no tears |
| warm | a warm affectionate but restrained closed-mouth smile, softened eyebrows and kind eyes | warm affectionate closed-mouth smile, softened brows and kind eyes | quiet affectionate closed-mouth smile, softened brows and kind eyes |

## Bringing them into the game

1. Save each as `assets/portraits/<file>_<expression>.png`, 768×1024 RGBA, over today's.
   Check the registration: today's painting doubled and the new one, laid over each
   other, should have the eyes, nose and mouth in the same place.
2. The game already takes a portrait at 768×1024 (any whole multiple of 384×512): the
   head and hair movement works in portrait space (`portrait_life.gdshader`), and the
   other faces are laid at FACE times two (`StoryArt.face_rect`;
   `tests/portrait_scale_tests.gd`).
3. Turn on mipmaps in the new portraits' import settings, and draw the romance portraits
   with `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` where they're set to plain nearest
   (`story_art.gd`, `wedding.gd`, `people.gd`, `settlement_screen.gd`, `map_screen.gd`).
   Shown smaller than its pixels, a 768×1024 painting would otherwise drop every
   other pixel and shimmer.
4. `tools/portrait_wedding.py` and `tools/portrait_faces.py` are tuned to the 384×512
   paintings, pixel by pixel (where the eyes are, lash widths, the hair's reach). Re-tune
   them on the new paintings (every position and distance doubles, then check by eye
   with their preview output) and run them again: the wedding gowns, then the faces.
5. Run the suite (`game_feel_tests` checks the blinks and faces) and look at each
   portrait in the game at 100% and 150% text.
