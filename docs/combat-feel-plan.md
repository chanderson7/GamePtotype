# Bannerfall: the combat feel plan

- **Date:** 2026-11-04
- **Status:** built (2026-11-04). Deviations are listed at the end.
- **Goal:** make a battle feel premium: men who act rather than flash, blows that land, a
  field with an hour, callouts with a hierarchy, and a start and an end that are moments.
  Everything here is presentation. The simulation in `battle_sim.gd` is not touched:
  same seed, same battle, same result, with or without any of it.

## What the battle already does

This is not a first feel pass. The battle screen already has sparks and spatter where
blows land, a warm glow along the front, dust behind squads coloured by the ground,
arrows with streaks and landing shadows, men who take 0.45 s to fall and leave their gear,
standards that ripple, dip when ordered, tremble when wavering and topple when a squad
breaks, a camera that follows the fighting with shake and a 0.06 s hit-stop on charges, the
death roll with slow time and a spotlight, the winners' cheer, positional sound with a melee
bed and layered music, haptics, and reduced-motion fallbacks for all of it.

So the plan is not "add juice". It is to fix the six things that still read as a prototype
when you look closely at a phone-sized frame.

## What reads as cheap today

Reference frames are in the mockups (`scratchpad/feelshots/`, the `grid_now.png`,
`grid_quiet.png` and `zoom.png` captures).

1. **Men don't act; they flash.** Every unit has three frames: walk A, walk B and a strike
   pose held flat for 0.3 s. There is no wind-up, no lunge, no recoil. Being hit is a white
   silhouette and a cross. A death is one rotation and a tint. At battle zoom a man is about
   25 px tall and the strike frame is nearly invisible, so a melee is two coloured blobs with
   sparks on top (`zoom.png`, left).
2. **A braced line looks like a walking one.** "BRACED", "SHIELD WALL" and "SCHILTRON" are
   words over the squad; the men stand exactly as they do marching.
3. **Callouts stack and all weigh the same.** `BROKEN` over `WAVERING` over `CHARGE!`, in
   the same plain outlined font, drifting up (`zoom.png`, right). A captain's death and a
   charge get the same treatment as "out of arrows".
4. **Every battle is fought at noon.** The world keeps an hour; the map, the camp and the
   hall are lit by it; the battle ignores it. Shadows are a fixed (1.5, 3) offset.
5. **Fight has no beat, and neither does the end.** Tap *Fight* and the men start walking.
   When it's decided, the winners cheer for 1.8 s and a list slides up. There is no frame
   you would screenshot.
6. **The HUD never feels anything.** Cards show a bar and a number; the power bar jumps; the
   ability dot just appears. Nothing on the bottom half of the screen ever reacts to a blow.

## Design rules (unchanged from the feel roadmap)

- Every effect explains something; one dominant cue at a time.
- Presentation reads the sim and never writes it: no damage, morale, positions, RNG, time.
  Offsets in this plan are draw-time only and are never stored on a soldier.
- Reduced motion keeps every state and word and removes every offset, stamp, zoom and shake.
- Phone first: density budgets, 60 FPS target, 30 FPS floor in the densest battle.

## A. Men who swing, flinch and fall

Mockup: `mock_a_men.png`. All of this is computed in `_draw_men` from fields the sim already
keeps per soldier (`swing`, `flash`, `cooldown`, `stride`, `facing`, `target`) and from
events, as draw offsets. The pale ghost in the mockup is where the sim has the man.

### A1. The strike, in three phases on the existing 0.3 s swing

`so.swing` counts down from 0.3 the moment a blow is struck. Read it as a phase:

| Phase | swing | Draw |
| --- | --- | --- |
| Wind-up | 0.30–0.22 | walk frame, pulled 1.5 px back along `-facing`, rolled −10° |
| Strike | 0.22–0.14 | strike frame, lunged 2.5 px along `facing`, +4° |
| Recover | 0.14–0 | strike frame easing back to the slot (ease-out cubic) |

The damage moment in the sim is at the start of the swing; the lunge is read as the follow-
through. Archers: in the 0.2 s before `cooldown` runs out with a target in range, draw the
strike frame (the bow drawn); the loose is the existing arrow. Javelins the same.

### A2. The flinch

When `so.flash` is set (a hit): the victim nudges 2 px away from `so.target` (or, with none,
along `-facing`) and tilts 12°, both decaying with the flash's own 0.2 s. The white flash
drops to 0.45 alpha so the kit stays readable; the cross goes.

### A3. The charge shove

On a `charge` event, every victim in `CHARGE_RADIUS` of the impact gets a presentation
shove: 6 px along the charge for 0.35 s (ease-out), tilt 28°, and the rank behind gets half
of it. A dust ring at the impact (exists). This is kept in a short list on the screen
(`_shoved`: soldier → {dir, at}) and read in `_draw_men`; it is never written to `so.pos`.

### A4. Stagger, then fall

A death becomes two beats: 0.15 s of stagger (strike frame, flash 0.5, lean −6°, tint
toward grey) then the existing 0.3 s fall with a small dust ring. A man killed by a charge
falls along the charge's direction, 10 px back, rather than where he stood. `FALL_TIME` goes
from 0.45 to 0.45 + 0.15 so the corpse appears when the body lands.

### A5. The brace pose

A braced squad (`sq.braced()`), a shield wall and a schiltron draw their men leaned 8°
into their facing and 1 px low, with the front rank 1 px closer together. No new pixel art:
the lean is enough at battle zoom to make a line that has set itself look set. A squad that
leaves the brace stands up over 0.3 s.

### A6. Breathing, and running

A man holding still bobs 1 px on his own phase (`sin(clock * 1.6 + index * 0.9)`), so a
line waiting for a charge isn't a sticker. Routing men lean 15° forward and alternate walk
frames at twice the stride rate; they already drop gear and go grey.

### A7. Men in a melee are drawn in depth order

Today squads draw in list order and each squad in soldier order, so the back rank of one
squad paints over the front rank of the next. Men of **engaged** squads are gathered and
sorted by `pos.y` once per frame (about 200 men on a full field; `sort_custom` on a
pre-sized array is well under 0.2 ms). Unengaged squads keep the cheap path.

### Not in A

No new frames of pixel art. If the lean doesn't sell the brace at phone zoom, a fourth
"guard" frame for the 12 base sprites (4 types × 3 cultures) is the follow-up, with
branches falling back to their base type's frame plus their own palette.

## B. Impact that lands

Mockup: `mock_bf_hud_impact.png`, lower panel.

- **B1. Hit-stop by weight.** `HITSTOP` becomes 0.05–0.12 s scaled by how many men the
  charge struck (the event already carries the victim squad; count flashes in the radius).
  Simultaneous charges in the same 0.3 s coalesce into one stop.
- **B2. Directional shake.** `_shake_offset` is no longer random: it is a decaying
  oscillation along the charge's direction (`sin(t * 40) * amp * dir`), so the screen is
  knocked the way the horses went. Routine shake sources (gate, rout) keep the random form.
  One shake owner at a time: a new source replaces, never adds.
- **B3. Punch zoom.** A charge on or by your men adds +3% to `cam_zoom` toward the impact,
  easing back over 0.25 s. Off under reduced motion and while the camera is held.
- **B4. Volley landing.** The arrows of one volley land in a 0.1 s burst (they already
  share a flight); every man under the shadow flinches (A2) even when the arrow misses, with
  a thud per three arrows capped by the sound budget.
- **B5. Screen shake setting.** Settings get *Screen shake: off · light · full* alongside
  reduced motion and haptics; light halves every amplitude.

## C. Callouts with a hierarchy

Mockup: `mock_c_callouts.png`. `_float_text` and `floaters` are replaced by three kinds of
cue with their own drawing and their own budget.

| Tier | What | How it's drawn | Used for |
| --- | --- | --- | --- |
| 1 · moment | one at a time, whole-field | a plate in the display font (Cinzel), stamps in (scale 1.3→1.0 in 0.12 s), 2.0 s; the biggest add the letterbox bars the spotlight already has | your captain down, your squad breaks, their chief or lord falls, the gate, the battle decided |
| 2 · squad | one per squad | small caps in a dark pill over the standard, slides up 12 px, 1.2 s; pills fan apart the way standards do | CHARGE, BRACED, FLANK, REAR, SHIELD WALL, SCHILTRON, VOLLEY, WHEEL, FURY, STEADY |
| 3 · state | no text | a badge on the standard and on the card, pulsing while it holds (the wavering "!" already exists) | wavering, out of arrows, shaken |

Rules:

1. A tier-1 cue silences tier 2 for 0.6 s and ducks the melee bed (the duck exists).
2. The same words on the same squad never show twice within 3 s.
3. Two tier-1 cues queue; they never overlap. The death roll counts as one.
4. An enemy squad breaking is tier 2 ("BROKEN" in their colour), yours is tier 1.
5. Reduced motion: no stamp or slide; the same words, same durations.

The ticker along the top keeps its job as the written record and is unchanged.

## D. The hour of the fight

Mockup: `mock_d_hour.png`. The battle takes `GameState.world.hour` at the moment it
starts and keeps it (a battle lasts minutes, not hours).

| Band | Hours | Tint over the field | Shadows | Extra |
| --- | --- | --- | --- | --- |
| dawn | 5–8 | warm `ffc88c` at 0.14 | long, cast east (toward +x), 1.8× | a pale band of mist along the far edge |
| day | 8–17 | none | the current (1.5, 3) | — |
| dusk | 17–20 | orange `ff783c` at 0.20 | long, cast west, 1.8× | flags lit from the side (the existing `lit` flag path) |
| night | 20–5 | blue `1e2d6e` at 0.42 | none | a soft vignette; a warm disc of light round every standard and the castle gate; a few stars in the letterbox when one is up |

Implementation: one `draw_rect` of the tint over the field after the ground and before the
men (so the HUD is untouched), the shadow direction and length as two variables read by
`_draw_shadows` and the standards, and the night discs as additive circles under the men.
The ground textures and ground dust colours are read through the same tint so dust at night
isn't daytime-yellow. Wind: one wind vector per battle (a hash of the site and the hour)
drives the flag wave, the dust drift and the grass ripples together, so they stop
disagreeing. No weather; rain stays deferred as the roadmap says.

Readability floor: the enemy's red and your blue are checked at night against the tinted
ground; if the contrast drops under the day value by more than a third the night alpha is
reduced until it doesn't (a one-time check in tests, not at runtime).

## E. The start and the end

Mockup: `mock_e_beats.png`. Two beats, both under the roadmap's 0.9 s budget and both
skippable with a tap.

- **E1. Fight.** On *Fight*: the HUD dims, the letterbox bars slide in, the camera pulls
  from your line out to the whole field over 0.8 s, and a title card sits over the field in
  the display font: the place ("Near Highcliff"), then the ground, the hour and the numbers
  ("Vardish meadow · dusk · 96 against 48"), then the commander line the scouts already
  wrote. The horns (`_call("start")`) and `Sound.battle_clash()` play under it as they do
  now. The sim does not step until the card clears; a tap clears it at once.
- **E2. Decided.** When the last enemy squad breaks: 0.5 s at `SLOW_PACE` on that rout with
  the spotlight (both exist for captains), then the cheer (exists), with **VICTORY** stamped
  on the field in Cinzel with a warm glow for 1.0 s, and only then the ledger eases up. On a
  loss there is no cheer: the field's colour drains over 0.8 s (a desaturating tint) while
  your men run, **DEFEAT** stamps in their red, then the ledger.
- **E3. The ledger's picture.** Every result panel gets the strip the siege result already
  has: the ground colour, the hour's tint, both standards. It is the one frame of the
  battle that goes to camp.

## F. A HUD that feels it

Mockup: `mock_bf_hud_impact.png`, top two panels.

- **F1. Cards.** A squad struck from the flank or rear, or by a charge, flashes a red edge
  for 0.3 s. When it breaks the card cracks (a drawn line), shakes 0.3 s and goes grey. The
  morale bar eases toward its value at 4/s rather than jumping. When the ability comes ready
  the brass dot pulses once (scale 1→1.6→1 over 0.3 s) with a soft click.
- **F2. The power bar.** The split eases at 3/s. Men lost in the last 0.6 s leave a pale
  ghost chunk on their side that drains away, so a bad charge is visible as a bite rather
  than a number that was different a moment ago.
- **F3. Pause.** The field desaturates 40% and gets the vignette under the pause panel; the
  men hold their frame as they do. Resume eases the colour back over 0.3 s.

## G. The death roll, polished

Same information, same timing (4.2 s, lands at 1.5 s), same skip.

- The plate slides in from the top with the existing duck and a thud instead of fading.
- The die is drawn as a pixel die that tumbles (±8° rotation, rounded corners, a shadow)
  and settles with a bounce when it lands; the number stays as it is.
- The odds bar fills from zero over 0.3 s so the eye reads the chance before the number.
- "FALLEN" stamps in (tier-1 treatment) with the bell and a 9-unit shake (exists);
  "WOUNDED" slides in without one.
- The portrait grows to 96 × 128 in a brass frame; the company name under it.

## Order and size

| # | Package | Size | Why first |
| --- | --- | --- | --- |
| 1 | A. Men who swing, flinch and fall | M | The men are in every frame of every battle; this is the biggest change per line |
| 2 | C. Callouts with a hierarchy | S–M | Removes the one thing in `zoom.png` that looks broken today |
| 3 | B. Impact that lands | S | Mostly tuning of systems that exist |
| 4 | D. The hour of the fight | M | The largest visual range for the least art: a tint and two shadow numbers |
| 5 | E. The start and the end | S–M | The two screenshots a player would share |
| 6 | F. A HUD that feels it | S | Small draws in `_draw_chip` and `_draw_power` |
| 7 | G. The death roll | S | Already good; last |

Packages 1–3 are one slice ("the fight"), 4–5 a second ("the hour and the beats"), 6–7 a
third ("the frame"). Each slice ships with its tests and screenshots.

## Files

- `scripts/battle/battle_screen.gd`: A (`_draw_men`, `_draw_falling`, `_draw_shadows`, a
  `_shoved` list), B (`_consume_events` charge branch, `_update_camera`), C (a `_cues`
  list replacing `floaters`, `_draw_cues`), D (`_hour_band`, the tint and shadow
  variables, `_draw_night_lights`), E (`_start_battle`, `_process` decided branch,
  `_draw_title_card`, `_draw_stamp`), F (`_draw_chip`, `_draw_power`, pause), G
  (`_draw_roll`).
- `scripts/ui/style.gd`: the shake setting and a `stamp()` easing helper.
- `scripts/menu/settings.gd`, `scripts/audio/sound.gd`: the shake setting; the click for
  an ability coming ready; the stamp thud.
- `scripts/battle/battle_sim.gd`: **no change.** If anything here needs a field the sim
  doesn't expose, it is added as a read-only derived value on the screen side.
- `tests/battle_feel_tests.gd` (new), `tests/battle_cues` (extended).

## Tests

1. **The boundary.** The same seeded battle stepped headless with the screen attached and
   without it ends on the same tick with the same corpses, winner and morale.
2. **Draw offsets never persist.** After a charge, every `so.pos` equals the sim's; the
   `_shoved` list empties within 0.4 s.
3. **Cue budget.** Three `charge` events on one squad in 2 s produce one pill; a captain
   down silences tier 2 for 0.6 s; two tier-1 cues queue in order.
4. **The hour.** A battle started at hour 22 has the night band, zero shadow length and
   the discs; at hour 12 none; the band is fixed for the battle's length. The night
   contrast floor passes for all three grounds.
5. **The beats.** The sim does not step while the title card is up; a tap clears it and the
   first step follows on the next frame; the card never outlasts 0.9 s on its own. On a win
   the stamp precedes `result_panel.visible`; on a loss there is no cheer.
6. **Reduced motion.** With it on: no offsets in `_draw_men` (positions equal the sim's
   screen positions), no stamp scale, no punch zoom, no shake; every word still appears.
7. **Settings.** Shake "off" zeroes `_shake` on a gate breach; "light" halves it.
8. **Frame cost.** The densest balance battle (12 squads a side) renders a frame in under
   the current cost plus 15% on the headless build, measured by the existing speed check.

## Screenshots to take

The five frames of `grid_now.png` again after each slice, plus: a braced line beside a
marching one; a charge at the moment of the shove; the four hours of one field; the title
card; the VICTORY and DEFEAT stamps; the cracked card; the death roll.

## Not in this plan

- New pixel-art frames (see A, "Not in A").
- Weather, seasons, or anything that changes a rule.
- Voice barks beyond the calls that exist.
- A cinematic longer than the two sub-second beats.

## As built

Everything above is in `scripts/battle/battle_screen.gd`, with the shake setting in
`scripts/audio/sound.gd` and `scripts/menu/settings.gd`, one grade shader
(`assets/shaders/battle_grade.gdshader`) and `tests/battle_feel_tests.gd` (51 checks). Where
it differs from the plan:

- **Larger offsets.** At phone zoom the plan's 1.5–2.5 unit nudges were invisible: the
  lunge is 4.5 field units, the wind-up 2.5, a flinch 3.5, a charge shove 9.
- **The wind-up comes before the blow.** The sim strikes at the start of a swing, so the
  wind-up is read from the cooldown running out (the last 0.12 s before a blow; 0.24 s for
  a bow), and the swing itself is the lunge and recovery. Nothing waits on it.
- **A charge death falls where he stood.** Falling along the charge would have snapped the
  body to its resting angle; the stagger and dust carry it instead.
- **The brace is a crouch, not a lean.** Seen from above, the lean read as a rotation. A
  set squad is drawn 10% shorter and a step forward instead.
- **SHAKEN stays a word.** It's the reaction to a friend's death, an event rather than a
  lasting state, so it's a squad callout like FURY and STEADY.
- **Pause and defeat use a screen grade.** One shader on a layer between the field and the
  HUD drains the colour; the hour's washes are plain draws, as planned. The title card and
  the end stamp are drawn on a HUD layer so the grade never greys them.
- **No slow-motion on the last rout.** The sim stops when the battle is decided, so the
  end uses the spotlight on the last squad to break instead.
- **The death roll's portrait** is 78 × 104 in a brass frame, not 96 × 128, so the name
  beside it still fits on a phone.
- **Routers ran backwards.** The sim never turns a routing man, so routers were drawn
  facing the enemy while running away; they now face their own edge.
- **"A squad that halts settles into its ground"** failed before this pass: a squad told to
  march that arrived within one frame was never seen to move. The screen now notes orders
  before the sim steps, and the test passes.
