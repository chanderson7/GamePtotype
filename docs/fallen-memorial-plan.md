# The fallen: a memorial at camp

A captain who dies today gets: a card on the map (their face at the fire, eyes shut), a
camp moment ("An empty place") whose Remember button only scrolls the Warband page, and a
row in a list on the Camp tab. They deserve a place. This plan gives the company one: a
rise at the edge of camp where each of the fallen has a stone, a roll of their names, a
page for each, and a short gathering when someone is laid to rest.

Mockup (made from the game's own pieces, not the finished look):
`docs/mockups/memorial_mock.png`. Left: the memorial with the roll, the newest not yet
mourned. Right: one captain's page.

## Status: built

All seven packages are in: `scripts/data/memorial_lines.gd`, `scripts/ui/memorial_scene.gd`,
`scripts/ui/memorial_life.gd`, `scenes/memorial.tscn` + `scripts/menu/memorial.gd`, the
GameState functions (`memorial_of`, `unmourned`, `memorial_where`, `memorial_day`,
`memorial_slayer`, `memorial_epitaph`, `memorial_mourners`, `memorial_gather`,
`light_candle`, `candle_lit`), the vow in the journal, the five ways in, and
`tests/memorial_tests.gd`. Where it differs from the plan below:

- A death whose camp moment was already dismissed counts as mourned at the fire, so an old
  save doesn't greet you with a gathering for everyone who ever fell. Asked for directly
  (the camp moment, the map's card), a gathering opens for anyone not yet laid to rest.
- The map card's **Remember** puts the cards still to come back on the queue, so nothing is
  lost on the way to the memorial.
- The constants live in `memorial_lines.gd` with the words.

## What we have to build on

- `GameState.fallen`: a record per dead captain (`_memorial`): name, first, company, type,
  culture, battles, kills, the battle number they fell in, the hour, their last words,
  bonds (names with rank) and `bond_points`, temperament, quirk, history (scars, tourneys,
  wounds), `is_hero`, `killed_by_lord_id/name`, `avenged`, `avenged_words`, and `mourned`.
  It works with `CaptainArt.texture()` for their face.
- `GameState.remembered_bonds()` and `_memorial_talk()`: a bonded survivor's talk "by the
  empty place", opened from the Bonds tab (bond_conversation, `memorial: true`).
- `CampMoments`: the "An empty place" moment, waiting until `mourned`.
- The grudge: a lord who kills a captain carries `grudge` and `grudge_captain_name`;
  beating him marks the memorial `avenged`.
- Art pieces: `CaptainArt` (faces in any mood, `/shut`), `Widgets.framed`,
  `Widgets.banner`, `CampLife` and `HallLife` (how an overlay brings a painting to life),
  `HallScene` (how a pixel place is drawn in code, per culture).

## The place

The company carries a stone for each of its dead and sets them out at every camp on the
nearest rise. It's drawn in code at 240x150 (`scripts/ui/memorial_scene.gd`, like
HallScene), in the company's own culture:

| Culture | Name | What stands there |
| --- | --- | --- |
| Vardish | The Cairn Field | cairns of grey stones, a tall standing stone with names cut into it, the company banner at half mast |
| Kharzani | The Garden of Lamps | white headstones with brass oil lamps, a cypress, a small domed tomb |
| Ryumon | The Lantern Grove | stone lanterns, wooden grave tablets, a maple dropping leaves |

- The camp's tents and fire are small and far off below; the hour tints it (dusk, night,
  dawn: `TalkView.time_word`).
- **A stone per captain**, up to 7 drawn large, newest nearest; their pennant in their
  company's colour; a hero's stone has a gold mark. Older stones are drawn as a cluster of
  small "old stones" further up the hill.
- **The newest, if not yet mourned**: fresh earth, flowers, an unlit candle.
- **Alive** (`scripts/ui/memorial_life.gd`, built like CampLife): candles flicker on the
  stones where one is lit, mist drifts along the hill, the banner stirs, stars twinkle,
  fireflies in summer, leaves or petals by culture. Reduced motion: only the candles' glow.
- **Empty**: before anyone falls, the hill holds only the company stone: "No stones yet.
  Keep it that way."

## The screen (`scenes/memorial.tscn`, `scripts/menu/memorial.gd`)

Portrait, from the top:

1. **The hill** (about 40% of the screen), each stone a tap target (≥ `Style.TOUCH`). A tap
   shows their name on a small plate over the stone; a second tap opens their page.
2. **Kicker and title**: "THE FALLEN · 6 REMEMBERED", the place's name, one line about it.
3. **Not yet mourned**: a gold card for each, with their face, "Fell at Ravensford", and
   **Gather the company** (the gathering below).
4. **The roll**: every name, newest first: dim face, name, company, "battle 27 · 56 foes",
   ★ avenged. Past 12, the rest are folded under "Older (N)". A tap opens their page.
5. **Back** (to wherever it was opened from: `Scenes.memorial_return`).

Music: the camp track for the company's culture, quiet. A bell when a candle is lit.

## A captain's page (an overlay on the memorial)

- Their face, large, eyes shut, over their own stone. **Tap the face** to see them as they
  were (proud, eyes open) for a few seconds.
- Name in the display font; **the epitaph** under it in quotes (chosen at the gathering,
  or made from their temperament and deeds for anyone mourned before this existed).
- Tiles: battles, foes, scars; tourneys won if any.
- **Where and when**: "Led Ivo's Shields for 13 battles. Fell at Ashby, battle 27, on day
  41." (Place and day are new on the record; old saves read "somewhere on the road".)
- **Who did it**, if a lord: their banner and name, and what became of them: *still rides*
  (with **Show on the map**, which centres the map on their party), *your captive*,
  *slain*, or *avenged at Khalun*.
- **Their last words**, in brass.
- **Mourned by**: the bonded survivors' faces in grief with their rank letter. A tap opens
  that survivor's talk by the empty place (the existing memorial talk).
- **Light a candle**: once a day per stone; it burns on their stone for three days. Nothing
  else: remembrance, not a resource.
- **Their record**: opens the existing captain profile (it already handles the fallen).

## The gathering (the first visit after a death)

When a captain is not yet mourned, **Gather the company** (or the camp moment's Remember)
plays a short scene over the hill at dusk:

1. The company stands around the fresh earth: the survivors' faces in grief, seated in a
   row like the feast's guests, the closest friend in front.
2. **The friend speaks**: their line from `CampMoments` (mourn) or the memorial talk's
   opening, written out.
3. **The rite**, one tap, in the company's way: *Raise the cairn* (Vardish: stones stack
   one by one, with a soft knock for each), *Light the lamp* (Kharzani: the lamp catches
   and glows), *Set the tablet* (Ryumon: the tablet is set, incense curls). A bell.
4. **Words over them**, three choices that shape the epitaph:
   - *Honour*: "They held when it mattered." The epitaph is made from their deeds.
   - *Grief*: "We'll keep their place by the fire." The epitaph is personal.
   - *Vengeance* (only if a lord killed them): "Selim will answer for this." The epitaph
     is a vow, and the journal gets a commitment: avenge them on that lord (it ends when
     the grudge is settled).
5. It closes on the finished stone with its candle lit.

What it does: the record is `mourned` (the camp moment goes), its epitaph and rite are kept,
a candle is lit, and **each pair of survivors who were both bonded to the dead gains a
little bond with each other** (shared grief: +1.0 points, once per death). Tap skips each
step; Reduced motion shows each step still.

## The ways in

- **Warband, Camp tab**: "The fallen" becomes a strip showing the hill small, the count and
  the 3 newest, with **Visit the memorial**.
- **The camp moment** "An empty place": Remember opens the memorial on that captain's
  gathering.
- **The map's fallen-captain card** (EventCards): a second button, **Remember them**, opens
  their page (returning to the map).
- **The victory scene**: a tap on a face under Remembered opens their page.
- **A fallen captain's profile**: **Their stone** opens their page.

## Numbers and data

- `scripts/data/memorial_lines.gd`: the place names and lines per culture; rite names and
  words; epitaphs by temperament × word choice (honour/grief/vengeance), with `{name}`,
  `{company}`, `{place}`, `{lord}` filled in; a hero's own epitaph from `heroes.gd` if one
  exists.
- On the memorial record (saved, with defaults for old saves): `place` (where they fell:
  `world.here()` or the nearest place), `day`, `epitaph`, `rite`, `words_said`
  (honour/grief/vengeance), `candle_day` (-1 for none).
- Constants in `scripts/data/memorial_lines.gd`: `SHOWN_STONES := 7`, `ROLL_FOLD := 12`,
  `CANDLE_DAYS := 3`, `SHARED_GRIEF := 1.0`.
- GameState: `memorial_place_name()`, `memorial_epitaph(m)`, `memorial_gather(id, words)
  -> {ok, epitaph, shared: [[a, b]]}`, `light_candle(id) -> bool`, `candle_lit(m) -> bool`,
  `memorial_slayer(m) -> {name, realm, state, party}`.

## Packages (for implementation)

Each is one commit with its tests, in this order.

1. **The record and the rules**: place and day kept at death; `memorial_lines.gd`;
   `memorial_gather`, `light_candle`, `memorial_epitaph`, `memorial_slayer`; the vengeance
   commitment in the journal; save and load with defaults. *Check:* gathering marks
   mourned, clears the camp moment, gives shared grief once, and twice does nothing; a
   candle once a day; old saves load with "somewhere on the road".
2. **The place's art**: `memorial_scene.gd` for the three cultures, stones for 0, 1, 7 and
   20 fallen, the fresh grave; `memorial_life.gd`. *Check:* render all cultures at those
   counts at 720x1280 and 720x1560; the candles move between frames; Reduced motion holds still.
3. **The screen**: hill with tappable stones, the roll, the not-yet-mourned cards, the
   empty state, Back. *Check:* every stone and row opens the right page; the roll folds
   past 12; fits at 1.5x text.
4. **A captain's page**: everything above, Show on the map, the survivor's talk, the
   profile. *Check:* each slayer state shows right; Show on the map centres the map on the
   lord.
5. **The gathering**: the scene, the rites, the words, the epitaph. *Check:* each choice
   gives its epitaph; vengeance only with a lord, and its journal entry; tap skips;
   Reduced motion.
6. **The ways in**: the Camp tab strip, the camp moment, the map card's button, the victory
   faces, the profile button. *Check:* each opens the right place and Back returns to where
   it came from.
7. **Tests**: `tests/memorial_tests.gd` with all of the above; the Warband tests still find
   `FallenCard`.

## Not in this plan

Visiting a captain's actual grave on the map; family letters to the fallen's kin; painted
(rather than code-drawn) art for the memorial, which can replace `memorial_scene.gd` later
without changing the screen.
