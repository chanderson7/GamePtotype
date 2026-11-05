# Captain faces: the richer design

Adopted. `scripts/art/captain_face.gd` now draws every captain with more in them than the
first generator did: a jaw and cheekbones, eyes with an iris and a lid, clothes that carry
rank, troops and veteran role, and an expression for the moment. It began as a prototype
beside the old generator behind a switch; after review it replaced it, and the switch is
gone. Expressions are wired where the moment is known: `pain` on the death roll, `grief`
for the survivor on a memorial card and in a bond memorial, `warm` at a bond talk and a
new bond rank, `proud` on the profile just after a promotion.

Sheets, all in `mockups/`:

| Sheet | What it shows |
| --- | --- |
| `captain-faces-compare.png` | 24 captains, the current face above the prototype's. Same seed, same identity. |
| `captain-faces-expressions.png` | Six captains across the seven expressions: resting, grim, pain, grief, proud, fear, warm. |
| `captain-faces-uniforms.png` | Each culture: four troop types at rank 1, 2 and 3, then the four veteran roles. |
| `captain-faces-lords.png` | Lords and rulers, current above prototype. |
| `captain-faces-sizes.png` | Both at every size the game shows a portrait, from the camp token to the profile. |
| `captain-faces-batch-1.png` to `-4.png` | 96 numbered captains across every culture, troop, rank, temper, quirk, wound and role, used for review. |

## What the first generator did

The first generator drew a 48 × 64 bust from a captain's id and culture. It does the
important thing well: every captain has one face, kept across screens and saves, and it
changes with their life (scars, grey, a bandage, a pin for rank). Its limits, from the
baseline sheet (`compare`, top rows):

1. **The head is an oval with one shadow band.** No jaw, chin or cheek, so the four head
   shapes are hard to tell apart and the face reads as flat.
2. **Eyes are two pixels.** A white and a dark. There is no iris, lid or gaze, which is
   most of what carries feeling at this size.
3. **Expressions are only the temperament.** The brows and mouth come from Vengeful,
   Steadfast or Fragile, plus the Lucky grin and the Bold half-smile. The same face shows
   on the death roll, at a friend's memorial, and at a promotion.
4. **Rank is two brass pixels on the collar,** and the troop marks (a strap, a tassel, a
   small shield) are small enough to miss. A veteran role shows nowhere on the figure.
5. **Hair is a flat cap**, long hair two straight blocks, beards a flat fill.

## The design

### Size

60 × 80, the same 3:4 as before. Every portrait in the game is a `TextureRect` that
keeps aspect, so the new size fits each slot unchanged. The extra 25% each way is what
pays for an iris, a jaw and a readable mouth; a 48 × 64 face has no room for them.

### Detail

- **Head.** Four shapes that differ in jaw: a narrowing chin, a square jaw, a long face,
  a soft one. Light from the upper left: a lit plane down the left cheek, shadow down the
  right that deepens at the edge, a hollow under the right cheekbone, a shadow where the
  jaw turns, a dark neck under the chin.
- **Eyes.** 4 × 2 with a white, a two-pixel iris with a highlight, an upper lid line and
  a crease above it. Wide-set or close-set per captain. Five iris colours.
- **Nose.** Three: straight, broad, short, each with a bridge shadow and a lit tip.
- **Mouth.** Two-tone lips, full or thin per captain, with the shadow under the lower lip.
- **Hair.** Strands catching light on the lit side, a hairline shadow on the brow, waves
  in long hair, a tied braid, a topknot with its tie, turbans in wound folds with a jewel.
- **Skin.** Freckles and a mole for some; age lines under the eyes and from the nose.
- **Scars** are a pale line with a dark edge, six long, in the same seeded places.

### Uniform

Each culture keeps its four garments, redrawn so the collar meets the neck and the chest
has a shadow under the chin. Over them:

- **Troops.** Archers: a quiver strap with a buckle and three fletched arrows over the far
  shoulder. Cavalry: a brass cloak clasp at the throat and a horsehair tassel. Spearmen:
  the spear's red tassel. Infantry: a round leather shield with a boss, slung at the
  near shoulder.
- **Rank.** Seasoned (8 battles): brass along the collar. Veteran (20): a short cloak of
  the accent colour over the far shoulder, pinned with a brooch.
- **Veteran role.** A token low on the lit side of the chest: a hawk's feather for the
  Scout, a ring of keys for the Quartermaster, a brass whistle on a red cord for the
  Drillmaster, a gold laurel over the heart for the Champion.
- **Nobles** keep the fur collar (shoulder wings for the Ryumon), the chain of office and
  the ruler's circlet, drawn at the new size.

### Expressions

`image(captain, backdrop, expression)` and `CaptainArt.texture(captain, expression)` take
one of:

| Expression | Brows | Eyes | Mouth | Else | Where it belongs |
| --- | --- | --- | --- | --- | --- |
| `""` resting | by temperament | open (narrow if Vengeful) | by temperament and quirk | | everywhere it shows today |
| `grim` | knitted, a crease | narrowed | a tight line | | battle cards, the deploy screen |
| `pain` | worried, creased | squeezed shut | teeth clenched | sweat, a flush | the death roll, "wounded" results |
| `grief` | worried | looking down | turned down | a tear | memorials, a fallen friend |
| `proud` | outer ends lifted | open | an assured half-smile | | the promotion, a victory |
| `fear` | high | wide, three rows of white | open | pale, sweat | routing, a Fragile captain breaking |
| `warm` | soft | smiling, closed | a broad smile | a flush | bond talks, the fire at camp |

The temperament still sets the resting face, so a Vengeful captain's `warm` is still
their face smiling.

## What the sheets show

- **Identity holds** (`compare`). Every captain is recognisably the same person in both
  rows: the seeded draws are the same and in the same order, with the new ones (eye
  spacing, lip, freckles, mole) drawn after.
- **Expressions read at the sizes that matter** (`expressions`, `sizes`). Grim, fear,
  warm, grief and pain are clear at the Warband size and above. At the camp token
  (36 × 48) they mostly don't, in either generator; the token should keep the resting face.
- **Rank and role show** (`uniforms`). The veteran cloak reads at every size; the role
  tokens read at the Warband size and above, and are a few pixels at the battle card.
- **Where it's about even:** the two smallest sizes. The prototype's gain is from the
  Warband roster up: the bond intro, the talk screens, the death roll, the profile.

## What adoption changed

- `captain_face.gd` is the new generator; the old one and the `CaptainArt.prototype`
  switch are gone. Every portrait keeps its slot: the face is the same 3:4.
- `CaptainArt.texture(captain, expression)` and `CaptainArt.portrait(captain, size,
  expression)` take an expression; the face cache keys on it and on the veteran role.
- `Captains.face_record` keeps the veteran role, so a memorial shows the token the
  captain wore.
- After review: long hair and the tied tail hang behind the head (in front they framed
  the face like a hood), beards follow the jaw, and ears sit on the face's edge.
- Tests in `captain_development_tests.gd`: the size, the same face every time, a different
  face for another captain, each expression changing it, the role token, and a face
  record drawing the same face as the captain.

## Open questions

- **A helmet option** for infantry and spearmen at rank 3 was left out: it hides the hair
  that carries most of a captain's identity. A helmet carried under the arm would need a
  wider bust.
- **Battle-card faces** (54 × 72) keep the resting face for now. `grim` reads at that
  size if a battle look is wanted later.
- **Women's faces.** The generator's `soft` flag already draws some captains with softer
  features and fewer beards; at the new size there is room for a dedicated set of jaw,
  brow and lip shapes for them, which would be the next detail pass.
