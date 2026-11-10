# Map feel: how the map answers the thumb

**Status: built.** A pass over the world map for what it felt like to hold, after the
screen-wide pass in [`game-feel-audit.md`](game-feel-audit.md). The map already had
ambient life (cloud shadows, surf, dust and wake behind the company, the hour's light);
what it lacked was any answer to the player's own hands, and its name plates were the
noisiest thing on screen. Nothing here touches the rules: all of it is drawn, and every
motion has a Reduced-motion branch that lands on the end state. Checked in
`tests/game_feel_tests.gd` (`_map_feel`).

## 1. The camera has physics

| What | Before | Now | Where |
|---|---|---|---|
| Lifting mid-drag | stopped dead | coasts on, slowing (`FLING_FRICTION`), unless the finger had stopped | `_release_fling`, `_update_camera` |
| Dragging past the edge | a wall | gives less the further you pull, springs back on release | `_rubber`, `_update_camera` |
| Double-tap, *Show on map*, the journal | cut | glides (0.45 s, cubic out); a finger stops it | `_glide_to`, `_focus_place`, `_focus_party` |
| The road encounter | its own tween | the same glide | `_frame_encounter` |
| Riding | the company could ride off-screen | a dead-zone follow keeps it in the middle 56% of the view (above an open sheet); dragging lets go, setting off or double-tapping takes it back | `_follow_player` |
| Mouse wheel | 15% jumps | the same step, eased toward | `_zoom_eased` |
| Zoom limits | silent | a soft tick and haptic, once per limit | `_bump_zoom_limit` |
| Sprite size | popped between half-steps mid-pinch | still stepped (pixel art stays even), eased between steps | `_sprite_px`, `_update_feel` |

## 2. Taps answer

- A ring opens where the thumb landed: bright with a click and a haptic on something,
  faint and silent on bare ground (`_tap_feedback`, `_draw_tap_fx`).
- The selected place's ring lands from wider with a back-ease (`_select`).
- A thumb pressed on a place rings it before it lifts (`_press_target`); before, only a
  mouse hover did.
- Nearest wins across places, bands and lords (`_tap_candidates`); tapping the same spot
  again within 1.6 s steps to the next thing there. Before, a place always beat a party
  standing on it, so a lord at his own castle couldn't be tapped.
- Setting off draws the route out from the rider, with dust and a haptic; pulling up
  throws a puff (spray at sea) (`_on_travel`, `_burst`).

## 3. Name plates

- **Rows ease.** A party's plate that steps up out of another's way eases to its row
  instead of snapping each frame (`_eased_lift`).
- **Crowds share a plate.** Three or more parties within 34 px show one plate, the one
  that matters most, as "Jessa +2" (`_draw_labels`). Rank: whoever is hunting you, then
  enemies, bands, friends, neutrals; ties go to the bigger party.
- **Places step sideways.** Settlement names place towns first, then castles, then
  villages, and a name that hits one already placed slides sideways away from it
  (`_dodged`).
- **Plates over places are tethered.** A feast's or wedding's plate lifted off its hall
  keeps a line down to it, so it can't be read as its neighbour's (`_tether`).
- **The edge.** Plates stay inside the view's width and fade as what they name leaves
  the screen (`_keep_in_view`), instead of being cut off.
- **Fades, not thresholds.** Lords' and bands' names fade in over the zoom rather than
  appearing at one step (`_party_plates`, `_raw_px`).
- **Hierarchy.** Lords who mean you no harm and are more than two sights away, and bands
  far off, are drawn quieter; enemies always at full strength.

## 4. Parties and the road

- The walk keeps time with the game (`_walk_clock`, faster at fast-forward) and parties
  don't all step in unison; each stride lifts the body a sprite pixel.
- Turning round squashes through thin over 0.14 s (`_turned`).
- The route's dashes march toward where you're going; the stretch of the current road
  already ridden lies faint behind (`_draw_route`, `_dashed_path`).
- Clouds drift faster while time runs fast (`drift_time` in `map_sky.gdshader`).

## 5. Smaller touches

- **Pointers at the edge** to your company, whoever is riding after you (pulsing), and
  sieges and raids on your side's places; up to four, tap to glide there
  (`_draw_pointers`).
- **Night.** Lamps breathe, each on its own beat; the edges darken further after dark
  (`night` in the sky shader).
- **The purse.** The top bar's men, silver and renown count to their new number with a
  brass flash and the change rising off the pill, as in town; food (in days) counts
  without a float, since it falls a day at a time (`_show_resource`).

## Left out

- A wind or parchment swell tied to pan speed: it needs a new looping sound with a
  live volume, which the sound bank doesn't have yet. The zoom-limit tick is in.
