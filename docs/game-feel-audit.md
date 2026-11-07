# Game feel audit: where the UI should move

**Status: built (all twelve), with three corrections to this audit, listed under
"As built" at the end.** A pass over every screen for what moves, what doesn't, and what
the genre's best do at the same moments. Nothing here changes rules; it's all
presentation, and all of it respects *Reduced motion*.

## What already moves

The battle is the best-feeling part of the game and the measure for the rest: a
directional screen shake, a hit flash in the shader, wind-up and flinch poses, floaters,
a ticker, event banners, haptics on orders and hits, slow time for a decisive fall and a
death roll with its own pacing. Outside it, the kit is small and used unevenly:

| Where | What moves |
|---|---|
| Screen changes | 0.15 s fade to black, 0.25 s back (`Scenes.go`) |
| Sheets and cards | fade + a small back-eased grow, 0.22 s (`Style.ease_in`); used on map sheets, the town's info sheet, the battle result |
| Silver and food tiles | count to the new number over 0.45 s with a brass flash (`Widgets.tick_to`), on the town and Warband pages only |
| Tab bars | the lit tab fades 0.6 → 1 over 0.16 s; the page under it rebuilds in one frame |
| Toasts, letter banner | fade only |
| Map | lanterns sway, the wedding ring pulses, parties walk with dust or wake, campfires flicker, lamps at night |
| Town vista | clouds, smoke, lanterns; a new building flashes in with a knock of timber |
| Title | the camera drifts |
| Talk | the face fades in over 0.18 s |

Everything else is instant. The pattern behind most of the gaps is one habit: every
action calls `_build()` and the whole page is remade in a frame. The scroll position
survives, but nothing on the page can say *this* is what changed.

## The gaps, in order of what they'd buy

Ranked by how often a player meets the moment times how flat it is now. Effort is a
rough day count.

### 1. Touch feedback on every button (½ day)

Buttons swap a stylebox when pressed and nothing else. A thumb on glass needs the
button to answer: a quick squash to 0.96 on press, a pop back with a little overshoot
on release, and a light haptic on primary buttons. *Clash Royale*, *Marvel Snap* and
*Slay the Spire* (mobile) all do this; it's the single cheapest thing that makes a
menu feel like a game rather than a settings page. One place to add it: `Style.make_theme`
can't do scale, so a `Style.pressable(button)` helper connected to `button_down` /
`button_up`, called from `Page.button`, `_button`, `tab_bar`, `round_button` and the
sheet dock. Haptics already exist (`Sound.haptic`) but only the battle uses them.

### 2. Sheets close the way they open (¼ day)

`_close_sheet` sets `visible = false`. The open is eased, the close is a cut, and the
asymmetry is felt every time. A 0.12 s fade-and-shrink out (`Style.ease_out`, the
mirror of `ease_in`), then hide. Same for the town's info sheet, the Crown's sheets and
the rules sheet.

### 3. The thing that changed shows itself (1 day)

After *Hire*, *Buy food*, *Train*, *Grant*, *Hear*, a toast or a gift, the page is
rebuilt and the new card just exists. What the genre does:

- *Stardew*, *Hearthstone*, *Kingdom Two Crowns*: the bought thing hops, the coins
  burst from the tile.
- *Hades*, *Slay the Spire*: a new row slides in from the side 60 ms after its
  neighbours settle.

Give `_build()` a notion of "what's new" (the pattern `_just_built` → `show_built`
already does this for one case): the hired squad's card eases in with a slight lift and
a brass edge that fades over a second; a trained squad's level chip pops; the silver
tile ticks (it already does) *and* a "−180" floater rises from it. The same floater
serves Regard: **"+5"** rising from a lord's face when a toast, gift or seat of honour
lands, which is the heart of the court and today is a line of text in a notice.
*Crusader Kings* and *Fire Emblem* both put the number by the face.

### 4. Tabs slide, not cut (½ day)

Switching Court → Market remakes the page. Keep the rebuild but crossfade the old
content out (0.1 s) and let the new content rise 8 px into place (0.18 s), and slide
the lit-tab underline from the old tab to the new one instead of fading it. This is
the iOS/Material standard and reads as "the same page, turned".

### 5. The battle result tallies instead of appearing (½ day)

The card eases in with every number already on it. *Into the Breach*, *XCOM* and
*Fire Emblem* make the tally the moment: the title stamps in with the stinger (a
0.3 s scale 1.3 → 1 with a thud), then the two tallies count up, then the rewards
roll in one at a time with the coin sound, then each company row slides in 80 ms
apart. The whole sequence is under two seconds and tappable to skip. `tick_to` and
`ease_in` are already there to build it from.

### 6. Time passing is seen (½ day)

*Wait* and travel jump the clock. When hours pass on the map, sweep the clock in the
top bar and tint the sky through them over 0.6 s (the night lamp already exists per
hour); *Kingdom Come* and *Stardew* both treat the clock as a dial. The same sweep
covers the six hours of loading the carts after a raid.

### 7. The road encounter lands (½ day)

"X blocks the road!" eases in like any sheet. It's the game's most dramatic interrupt
and should feel like one: the camera eases to the two parties and zooms a step in
(0.4 s), a horn, then the sheet rises with the lord's portrait sliding in from his side
of the road. *Battle Brothers* and *Bad North* both cut the camera to the threat
before asking. The camera already supports `cam_center`/`cam_scale`; tween them.

### 8. Letters and news slide from where they come (¼ day)

The letter banner fades in under the top bar. Slide it down from behind the bar with
a small overshoot, and the envelope's seal can "press" (scale 1.15 → 1) a beat after
it lands. *Sorcery!* and *80 Days* do exactly this with their letters.

### 9. Deeds, ranks and promotions get a stamp (½ day)

"A deed to remember" and a bond's new rank are notes and small rows. A ribbon that
drops in, holds and rolls up (like *Fire Emblem*'s support rank card or a *Hades*
keepsake unlock) fits the chronicle tone. There's already a `bond_rank` and a
`promotion` sound waiting for a picture to go with them.

### 10. Talk has a pulse (½ day)

Faces fade in and the words appear at once. A soft text reveal (30 characters a second,
tap to finish) with the speaking portrait nudging up 3 px on each new line, as in
*Banner Saga* and *Fire Emblem*, makes a conversation feel spoken. Keep it off under
Reduced motion and offer "Text appears at once" in Settings, since some players
hate typewriters.

### 11. Scenes that don't move at all (1 day each)

- **The dance and the wedding** have no tweens. The partners' portraits can slide in
  from either side, the bunting sway with the lanterns on the map's clock, the vow
  card ease in on its own beat.
- **The hall** (lord talk indoors) is a static tinted picture; its hearth and lanterns
  can flicker the way the camp's fire already does.
- **The war council**: a tapped face could lean in (scale 1.06) while its bubble
  rises; aims re-sort with their rows gliding, not snapping.

### 12. Battle: two small things (½ day)

Already the best screen, but: a 60 ms hit-stop when a captain falls or a lord is
taken (*Bad North*, *Hollow Knight*; the slow-time code is there, this is a freeze
before it), and the "To arms!" moment at the end of deployment deserves a banner
sweep with the horn, not only the clash.

## Order of work

1, 2 and 4 first: three small changes that touch every screen. Then 3 and 5, which are
the moments players look at most. 6 to 9 next. 10 to 12 as polish.

Roughly five days for the lot; the first four items are under two.

## Rules for all of it

- Every motion checks `Style.motion_reduced()` and has a no-motion branch that sets
  the final state at once, as `ease_in` and `tick_to` do.
- Nothing waits on an animation: a tap during a tally finishes it.
- Durations stay under 0.25 s for feedback and under 2 s for sequences; game UI that
  moves slowly feels broken, not rich.
- One helper per motion in `Style`/`Widgets`, so the whole game moves the same way.

## As built

Every item is in, each checked by `tests/game_feel_tests.gd` (with its Reduced-motion
branch) and the floating numbers, ribbon and encounter also checked in renders.

Three things this audit got wrong, found while building:

- **1. Buttons** already sank under the thumb (`Sound._on_node_added`); the audit only
  searched the UI scripts. What was missing, and is now there: the spring back with an
  overshoot, a press that a scrolling page takes over no longer stays sunk, and primary
  (brass) buttons tick.
- **6. Time** on the map was never jumping: Wait and travel already run the clock frame
  by frame. The sweep is for hours that pass out of sight (a town, a talk, a battle, a
  regroup); the map remembers the last hour it showed (`Scenes.map_clock_seen`).
- **12. The battle** already had a hit-stop on charges and a title card at the start.
  Added: the same beat for a captain's fall, a lord taken or slain and a chief's band
  breaking, and the horn as the title goes up.

Other choices made while building:

- **3.** After hiring, the new company lives on another tab, so it's the **Squads tab**
  that glows: where the company went. Floating numbers come from `Widgets.tick_to`,
  so every silver- or food-changing tap on the town and Warband pages gets one without
  wiring each action. Regard floats from any face built by `CourtUI` (it carries the
  lord's id) on the town and Crown pages.
- **4.** The tab bar animates only when it's rebuilt within 1.5 s of its last build, so a
  real tab change slides and fades while arriving on a screen doesn't.
- **5.** VICTORY already stamps on the field before the card, so the card's title only
  settles in (1.15 → 1); the sequence is the content.
- **7.** The lord's portrait pops rather than sliding: its container owns its position.
- **10.** Their lines are written out; yours appear at once (you chose them).
- **11.** The dance, the wedding and the indoor hall all build on `TalkView`, so faces
  sliding in and firelight after dark cover all three; the wedding's bunting, lanterns
  and petals have their own breeze.

Helpers, so the whole game moves the same way: `Style.ease_out / closing / stop_easing`,
`Widgets.dismiss_sheet / float_up / flash / show_regard / live`, `Scenes.ribbon`,
`TalkView.writing / finish_writing`.
