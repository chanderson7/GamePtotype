# Fief and manor: visuals and UI plan

**Status:** planned, not built.
**Mockups:** `mockups/fief-manor-tab.png` (the Fief tab and the station sheet, with
notes) and `mockups/fief-vista-improvements.png` (the village before and after, at night,
and the improvement plates by culture).
**Prototype:** `tools/fief_vista_proto.py` paints the Vardish village with the three
improvements on the game's 180 × 80 grid, using the same primitives as
`scripts/ui/settlement_scene.gd`, so every coordinate and colour below is one that has
been looked at. Run `python3 tools/fief_vista_proto.py OUT_DIR`.

The fief rules in `scripts/game_state.gd` and `scripts/data/fiefs.gd` stay as they are.
This plan changes what the player sees of them.

## What's there now

From the Thornwall screenshot and `settlement_screen.gd` (`_add_fief_management`):

1. **Building something changes nothing you can see.** The vista at the top of the
   screen is painted from `SettlementScene.params()`, which reads the garrison, raids,
   the market and who is visiting, but nothing from `player_fief`. A built improvement
   gets " [Built]" in brass on its row and that is all.
2. **The estate's numbers are one run of text.** "Estate Treasury: 0 / 1500 silver
   (+50/day) · Granary: 20 / 100 rations (+12/day)" is a sentence under the title. Both
   stores are capped (`MAX_STORAGE_SILVER`, `max_food_capacity`), so a full store is
   income being lost each day, and nothing says so.
3. **Garrison rows say who, not how.** "Doran's Shields (Doran of the Fens · 17 men)" and
   a two-line "Take into Warband" button. The button is greyed when the warband is full
   and nothing says why. Wounded men, the reason to station a squad, are an aside in
   parentheses.
4. **Twelve "Station …" buttons** in a grid are the loudest thing on the page. The verb
   repeats twelve times, and no button says how many men a squad has or whether any are
   hurt.
5. **The improvement rows all weigh the same.** Name, a three-effect sentence, and
   "Construct (300 silver)". The one you can't afford is greyed with no amount; the one
   you've built looks like the others but for the word.
6. **Two kinds of card.** The fief section uses bare `PanelContainer`s under capital
   headings, while the rest of the screen uses `_card` with the heading inside. The
   sections read as a different screen.
7. **The chip row is wrong for a village fief.** `garrison_capacity()` is 0 for villages
   (`Lords.GARRISON_ROLES` has no village entry), so the header chip says "Garrison 35/0"
   in green.
8. **Renouncing is one tap.** "Renounce Fealty (Forfeit fief to crown, -25 relation)" is a
   full-width raised button at the bottom with no confirmation.
9. **The Warband's "Your fiefdom" card** (`main_menu.gd`, `_fief_overview_row`) is two
   lines of numbers and nothing of the place.
10. **The palisade's description promises more than the rules do.** It says the
    watchtower spots raiders early; `world_sim._burn()` adds 15 militia and multiplies the
    defence by 1.35, and that is all.

## 1. The estate in the picture

The settlement vista is the right place for the visuals: every settlement already has
one, it is painted from saved facts, and the player sees it on arrival and at the top of
the Fief tab. The improvements become part of it.

### Data

- `SettlementScene.params()` gains `"improvements": [keys]`, read from
  `world.game_state.player_fief` when `id` is the player's fief (the world holds
  `game_state`, as `_burn()` already uses). Old save summaries lack the key, so every
  reader uses `o.get("improvements", [])`.
- The buildings stay drawn when the fief is `lost`: they are still standing, under
  another banner. Nothing is drawn for a settlement that was never the player's.

### Where each one goes (Vardish village, from the prototype)

The vista is 180 × 80 cells with the horizon at row 44. The title "Thornwall" and its
line sit on a dark fade over the bottom third, left of about column 108, so anything new
goes above row 50 or right of the road. The three improvements are spread across the
village so a lord sees the place fill in, not one corner grow:

| Improvement | What is painted | Where |
|---|---|---|
| Granary & Stores | A timber barn on four staddle stones, 16 wide, a taller and steeper thatch roof than the cottages, a loading door, a ramp and two sacks | Left, on the field edge behind the fence: `granary_vard(P, L, 4, 54)` |
| Palisade & Watchtower | Sharpened stakes two apart with two rails where the rail fences were; two taller stakes flank the road; a four-legged tower with a railed platform, slate roof, a guard in the realm's colour and a torch | Fences at rows 58 and 60; the tower left of the road mouth at `watchtower_vard(P, L, o, 82, 64)`; gate posts at columns 86 and 94 |
| Water Mill & Market Stalls | A brook down the right edge, widening as it comes forward; a stone-footed mill with a slate roof, a lit window and a chimney; a two-ring wheel standing half in the water, with its flume; two awninged stalls from `_market` right of the road | Brook from (177, 50) to (169, 80); mill at `mill_vard(P, L, 154, 72)`; stalls at `[98, 79]` and `[114, 79]` |

What moves to make room: the flock grazes left of the road once the mill takes the
right, the basket-carrier becomes a stallholder, the hens go to column 136, and the
right fence stops at column 154. The player's party stays where `_foreground` puts it.

### The other cultures and castles

The plates in the mockup show each culture's form; the village placements follow the
same three places (left on the field edge, by the road, on the right water):

- **Kharzan:** a domed mud-brick store with a ladder to its crown hatch; a brick wall
  with a stepped parapet and a square burj with a lantern niche; a noria on the existing
  channel (`_khar_village` already paints water at column 39) lifting into a trough.
- **Ryumon:** a raised kura with plaster walls, a shuttered window and a heavy tile
  roof; bamboo stakes lashed with rope and a yagura with a red rail and a paper lantern;
  a thatched mill over the paddy channel.
- **Castles** can be fiefs too (`available_fiefs_for_grant` excludes only towns). The
  granary's roof shows over the wall left of the gate tower, the palisade becomes an
  outwork across the approach with the tower at its end, and the mill sits right of the
  walls. Never cover the gate, the banner, or a visiting lord's banner.

Each painter is written once per culture and called from the village and castle
painters. Twelve pictures (three cultures, two kinds, day and night) are rendered and
looked at before this step is done; the prototype's `step_*.png` show the method.

### Night and motion

- The watchtower's torch is a `fire` by day and a `lantern` at night, like the gate
  torches. The mill's window is a `win`, so it lights with the rest.
- A new `wheels` list in the scene (`[x, y, radius]`) lets the vista turn the mill
  wheel: four spoke frames drawn over the static rim at the fire rate. Reduced motion
  holds it still, as it does the smoke.
- When the fief is burned, the stalls stand empty and the wheel stops; the buildings
  themselves survive a raid (the rules don't destroy them).

### Plates: the same building on the Manor card

`SettlementScene.plate(culture, key, built) -> Image` paints one improvement alone on a
40 × 30 strip of its culture's ground, with the same painter the vista uses. Shown at 3×
with nearest filtering it is a 120 × 90 thumbnail on the row. Unbuilt, the plate is a
ghost: the same drawing greyed to about 45% over the panel colour, so the row reads as
"what you could build" and the moment it's built the colour comes in.

### The build moment

After `build_fief_improvement` succeeds the page rebuilds as now, and the vista
`refresh()`es with the new building in it. Then:

- the new building's rectangle fades in from a pale flash over 0.4 s, and three short
  dust puffs (smoke plumes six high, `d8d4d0`) rise from its foot and are dropped after
  1.5 s;
- the row's ghost plate crossfades to the built one and the brass edge appears;
- `coins` plays, followed by a hammer-and-saw clip (a new `assets/audio/sfx/build.ogg`,
  one second; `click` until it exists).

With reduced motion the building is simply there.

### The Warband card

`_fief_overview_row` on the Warband gets a 120-tall `SettlementVista.make(fief_id,
world, 120)` across the top of the card, the estate as it is today, with the two lines of
numbers under it. The same card is where the player checks on the fief from the road, so
it should show the place.

## 2. The Fief tab

Every section becomes a `Widgets.card`, in the order of the mockup. Nothing else on the
screen moves.

### The chips

For a village fief the header chip reads "Garrison 35 men · 15 militia" (green when any
squad is stationed, muted when none), using `village_militia()` for the 15. Villages
that aren't the player's show no garrison chip at all, as capacity is 0. Castles and
towns keep "Garrison 40/60".

### Your estate

- Card title "YOUR ESTATE", aside "day 41 as its lord" from `granted_at`.
- "Lord of Thornwall" in the display face (`Style.label` at 48 so Cinzel is used), then
  "Sworn vassal of the Vardmark · seat of your company" or "Seat of your crown · ruler of
  …" as now.
- Two store tiles side by side, each a value over its cap, a line of income, and a
  `Widgets.meter`: "320 / 1,500 silver · +80 a day in taxes" and "250 / 250 rations · +15
  a day". A full store turns its meter and line red: "Granary full · grain is going to
  waste", "Treasury full · taxes are being lost". These are true to `_fief_day()`, which
  clamps both.
- "Collect 320 silver" (brass when there is anything) and "Take 250 rations". At zero
  the button reads "Collect taxes" and is greyed.
- Burned: a red chip "Raided · yields crippled" beside the title, and the rebuild row at
  the top of the Manor card as now.

### Garrison

- Card title "GARRISON", aside "2 squads · 35 men".
- A row per stationed squad in the Squads tab's shape (`_squad_row`): the captain's face
  with the troop badge, the squad's name, "Doran of the Fens · 17 men · Shields", and a
  third line "▼ 3 wounded · one heals each day" in `ENEMY_LIGHT`, or "Whole" in muted.
  A "Take back" button on the right.
- When the warband is full the buttons are greyed and one line under the list says why:
  "Your warband is full, 12 of 12 squads. Station one to make room."
- Empty state: "No squads stationed. The village has only its 15 militia."
- One button, "Station a squad here…", opens the station sheet. It is absent with one
  squad, replaced by "You can't leave your only squad."
- A closing line states the whole defence as `_burn()` computes it: "Holds against
  raiders with 15 militia, 35 stationed men and the palisade's 15. Stationed men heal one
  wound a day." Castles say "40 of 60 men on the walls" instead.

### The station sheet

Built like the place's info sheet (`_build_info_sheet`: a shade, a panel anchored to the
bottom, sliding up), named `StationSheet`:

- Title "Station a squad" and one line: "It stays at Thornwall, heals a wound a day and
  holds the village. At least one squad must ride with you."
- A row per warband squad, wounded first, each with the face, "Edda · 14 of 20 men ·
  Pikes", and "▼ 6 wounded · whole in 6 days here" or "Whole". A "Station" button per
  row (`Station_%d`), brass for wounded squads.
- Stationing closes the sheet and rebuilds the page where it was.

### Manor

- Card title "MANOR", aside "2 of 3 built".
- Rebuild row first when burned, as now, in the red tone.
- A row per improvement in a fixed order: the plate on the left; the name with a "Built"
  chip when built; the effects as ▲ lines; on the right a "Build" button over its cost
  in small muted text. The lines come from the data (below), one per rule the game
  applies, and no more.
- Can't afford: the button is greyed and a red line in the text says "Need 130 more
  silver".
- Built: the row takes a brass left edge and a brass wash at 7%, the plate is in colour,
  and the button is gone.

### Renounce

A flat muted text button at the foot of the tab, "Renounce fealty…". Tapping it opens an
inline confirmation in the manner of `_show_branch_choice`: "You forfeit Thornwall to the
crown and lose 25 relation with the Vardmark." with "Renounce" in the enemy tone and
"Keep it". Rulers still don't see it.

## 3. Data changes

In `scripts/data/fiefs.gd`, each improvement gets `effects`, the ▲ lines, written to
what the rules do:

| Key | Lines |
|---|---|
| granary | "+15 rations a day", "Stores 250 rations" |
| fortifications | "15 militia join the defence", "+35% strength holding the village" |
| mill | "+30 silver a day in taxes" |

The sentence `description` stays for the Chronicle and notes, with "spot raiders early"
removed until a rule does it.

In the vista: `params()["improvements"]`, `build()` returns `wheels`, and
`plate(culture, key, built)`.

## 4. Order of work

1. **Painters.** `params()` reads the improvements; the three Vardish painters from the
   prototype, ported cell for cell; gate posts, the brook, the moved flock; `wheels` in
   the vista; `plate()`. Tests: `build()` for every culture, kind and set of improvements
   returns images and no errors; `plate()` is 40 × 30; a few known cells have the
   building's colour (the granary's roof at (10, 40), the tower's gold finial at
   (82, 34), the wheel's rim). Render the twelve pictures and look.
2. **The Fief tab.** Cards, tiles, garrison rows, the station sheet, the Manor rows with
   plates, the renounce confirmation, the chip fix. The rules are untouched, so
   `tests/fief_tests.gd` passes as is; `tests/screen_width_tests.gd` already loads "your
   fief" with a full warband and should add all three improvements built and one burned
   state; `tests/gathering_tests.gd` still finds `HostCard` on the tab.
3. **The build moment.** Flash, dust, the plate crossfade, the sound.
4. **The Warband card** crop.
5. **Kharzan, Ryumon and castles.** The other six painters, from the plates, and the
   castle placements, with the same render-and-look step.

Steps 1 and 2 are independent and can be done in either order; 3 needs both.

## Open questions

- **Build time.** Building is instant today and the tests assume it. A two-day build
  with scaffolding (the painters already have a "fresh timber" look for rebuilt cottages)
  would give the moment more weight but adds a state to save and show. Recommendation:
  keep it instant and let the flourish carry it; revisit if a later feature adds days.
- **Raids.** A raid halves the treasury and burns cottages. Should it also wreck the
  mill or the stalls, with `repair_fief` restoring them? Recommendation: no; the
  improvements are expensive and a raid already costs enough. The vista shows the stalls
  empty and the wheel still until the village is rebuilt, at no extra cost.
- **Castle names.** "Palisade & Watchtower" on a castle fief reads oddly. Recommendation:
  keep one name and draw it as an outwork; rename only if players ask.
- **A fourth improvement** later (a chapel or a tavern for morale and recruits) fits the
  card without change; the vista would need a fourth place, likely behind the cottages on
  the left.
