# Feel and polish: the second pass

**Status: built, not yet run in Godot.** The session that built this could not run the
engine, so the checks were `gdparse`, `tools/check_calls.py` and `tools/check_infer.py`
(all clean apart from the known `_top_layer` false positive). Run before trusting it:

    godot --headless --path . --script res://tests/feel_polish_tests.gd
    godot --headless --path . --script res://tests/battle_sound_tests.gd
    godot --headless --path . --script res://tests/battle_feel_tests.gd
    godot --headless --path . --script res://tests/menu_tests.gd
    godot --headless --path . --script res://tests/run_tests.gd

The game had two feel passes already ([`game-feel-audit.md`](game-feel-audit.md),
[`combat-feel-plan.md`](combat-feel-plan.md)). This one picks up what they missed, found by
reading the code. None of it changes a rule: the battle sim is untouched and every effect
reads it.

## What was built

### 1. Men drawn between sim steps (`battle_screen.gd`)

The sim steps at 30 Hz. The screen used to draw each man at his raw sim position, so men
moved at 30 frames a second under a camera and effects running at 60. At the slow paces it
was worse: about 7 steps a second under the thumb's slow, 4 under the death roll.

Before the frame's last step, `_remember_positions()` keeps where every man, every squad's
middle and every missile stood. They are then drawn between that and where they stand now, by
`_lerp_k`, the leftover accumulator over a step. Men (`_drawn_pos`), standards (`_drawn_avg`)
and arrows (`_drawn_proj`) all use it. A move of more than 40 field units between steps (a
squad placed, men arriving) is drawn where it lands. The step loop now runs a counted number
of steps rather than looping on the accumulator, so the snapshot is taken before the last one.

### 2. Blows heard as they land

The random 0.22–0.5 s clash timer is gone. A blow is heard from the same detection that
throws its sparks (`_update_effects` → `_blow_sound`), where it landed, in the kind the
attacker trades (`BLOWS`). Only in a melee; an arrow strike is heard as the volley landing.
A budget (8 a second, at most 3 at once) keeps a big melee from rattling. The melee bed
still carries the din. `tests/battle_sound_tests.gd` now strikes real blows instead of
winding the timer.

### 3. Orders that sound, refusals that are felt

Four cues are synthesized in `tools/music.py` (`python3 tools/music.py order_select`, and so
on): `order_select` (a wooden tick and a banner lifted), `order_march` (two drum taps),
`order_attack` (three strokes rising, steel on a shield rim) and `order_refuse` (a muffled
knock, a sagging low note).

| Moment | Sound |
|---|---|
| A squad taken in hand (`_select`) | `order_select` |
| March (`_order_move`), a line formed (`_order_line`) | `order_march` |
| Hold | `order_march`, lower |
| Attack (`_order_attack`), Advance | `order_attack`, and a quiet war cry from the squad on attack |
| A line drawn, waiting for its tap | `order_select`, quieter (was the paper page sound) |
| Any refusal (`_refuse`, 14 sites) | `order_refuse` and a `refuse` pulse |

### 4. The map camera (`map_screen.gd`)

- **Fling:** the last 100 ms of a drag becomes a velocity that carries on and decays
  (`FLING_FRICTION`). Running into the edge soaks it up faster.
- **Soft edges:** a drag past the edge moves the map 35% of the way with the finger
  (`EDGE_GIVE`), and it springs back once let go.
- **Glides:** Show on map (`_focus_place`, `_focus_party`) and the double tap to the party
  glide over 0.35 s (`_glide_to`). Wheel notches add up and ease about the pointer.
- **Follow:** when a journey starts, the view keeps the party inside the middle half of the
  view, easing. A pan, a pinch or Show on map hands the view to the player until the next
  journey (`_looked_away`).
- Under Reduced motion: no fling, no give, every move a cut. The follow still keeps the party
  in sight.

### 5. The road autosave off the frame (`game_state.gd`)

The 5-second autosave while travelling now calls `save_game_async()`. It takes a deep copy of
`to_dict()` on the main thread, since `to_dict` hands out live arrays. The JSON text and the
write happen on a `WorkerThreadPool` task, under their own temporary name. `save_game()` and
`load_game()` wait for a write in flight first, so an older snapshot never lands over a newer
save. If a write is still going when the next autosave comes, that autosave is skipped.
`save_timing` records the main-thread copy, the worker's write and the last synchronous save.
**This should be measured on a phone:** if the copy turns out to cost as much as the text did,
the next step is to build the snapshot incrementally.

### 6. Sound follows the battle's time (`sound.gd`)

Each frame the battle reports its felt pace (`_felt_pace`): 0 paused, the roll's, the
thumb's or a captain's fall's slow pace, otherwise 1. Hit-stops don't count. `Sound` eases
toward it. The field bus's low-pass falls to 700 Hz at a stop and drops 4 dB. The music bus
steps back up to 9 dB. Field sounds and the melee bed pitch down toward 0.82.
`end_battle_sounds()` puts everything back at once.

### 7. A body typeface (`assets/fonts/BannerfallText.ttf`, `tools/body_font.py`)

Alegreya Sans Medium sits with Cinzel and IM FELL. Measured against Godot's default (Open Sans
SemiBold), its x-height is 0.46 em against 0.54, so at the same size it reads 15% smaller.
Rather than changing 58 size calls (and the test that pins `text_size(26) == 39`), the font
itself is drawn larger on its em: units per em go from 1000 to 893.

| | width of a sample line | x-height | line height |
|---|---|---|---|
| Open Sans SemiBold (old default) | 41.7 em | 0.540 | 1.36 |
| Alegreya Sans Medium | 33.4 em | 0.461 | 1.20 |
| Bannerfall Text | 37.6 em | 0.516 | 1.34 |

So text keeps its apparent size and takes about a tenth less width: nothing should wrap that
didn't before. The digits are mapped to the tabular lining figures (Alegreya's defaults are
old-style), so a number ticking up doesn't wobble. Hinting was dropped and the family renamed,
as the OFL asks of a modified version. The face is the theme's default font
(`Style.make_theme`), the window's theme and the engine's fallback (`Scenes._use_body_font`),
and the font of the battle, the map and People's hand-drawn words.
**Check the 150% text layouts after the first run.**

### 8. Battle sounds read in before the fight

`Sound.warm_battle(realm)` loads every battle sound and the realm's battle layers while the
screen is still dark on the way in. The troop shader compiles on the first frame, which now
falls inside the shutter's hold.

### 9. The smaller items

- **Volume sliders:** Music volume and Sound volume in Settings, squared so the middle of the
  slider is the middle of the loudness. They are written when the slider is let go.
- **Five haptic weights** (`Sound.pulse`): tap, refuse, impact (battle start, gate broken,
  your line breaks, a charge into your men), heavy (the battle decided) and death (a captain's
  fall). `haptic(strong)` maps to heavy and tap. Amplitude is passed on devices that take it.
- **Music rests:** the three road themes play through rather than looping, and the road has
  the map to itself for 25–55 s before the tune comes back. Other music loops as before.
- **Road ghost:** a settlement's sheet draws the road there, faintly, before you ride.
- **Battle ambience:** open ground has `road_open` (wind), and after dark `road_night`. A
  ford keeps its water.
- **Battle entry:** `Scenes.go_battle()` closes a shutter from top and bottom with a low drum
  and an impact pulse, holds a beat, and opens on the field. All six battle entries use it.

### Extra: feel multipliers for device tuning

Settings › Developer › Feel tuning has a slider (0–2, 1 as designed) each for screen shake,
hit-stop, men's motion (lunge, wind-up, flinch, shove), camera follow and vibration strength.
Reset puts them back. They are saved with the device settings so a tuning session survives a
restart. When the numbers are settled, fold them into the constants and reset.

## What the first engine run must confirm

1. Every suite above passes, `feel_polish_tests` included.
2. The body face loads in a fresh checkout without the import cache (`Style.body_font` falls
   back to reading the file), and the 150% text layouts still fit (`text_scale_tests`,
   `screen_width_tests`).
3. On a phone: frame pacing in the densest battle with interpolation on, and the autosave's
   main-thread copy (`GameState.save_timing`) against the old synchronous save.
4. That the map's follow doesn't fight the road-encounter framing or a sheet the player is
   reading.
5. By ear: the order cues' levels against the battle music, and the slowed field.
