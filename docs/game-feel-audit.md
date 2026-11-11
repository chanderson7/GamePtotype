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


## Added after: the lord talk

The talk with a lord (`lord_conversation.gd`) is its own screen, not a `TalkView`, so it
missed items 10 and 11 above (the note under 11 was true of the dance, not of this). It
now moves the same way, through the same helpers:

- **Opening and leaving.** They step in from their side, their banner unfurls, the plate
  and your banner fade up; leaving is a 0.12 s fade (the host still hears `closed` at once).
- **The line.** Written out (`TalkView.write_out`), a tap finishes it, and the replies
  arrive in a short run after it. Nothing waits: a reply can be pressed at once.
- **The face.** `_show(speech, extras, replies, mood, gesture)`: the portrait wears a
  `CaptainFace` expression for the exchange (warm or proud for what they like, grim for
  what they don't) with a gesture (a nod, a shake of the head, a lean in, a turn away,
  leaving the stage). At rest they breathe and blink (`CaptainFace` draws "blink").
- **The numbers.** The Regard chip counts to its new value and glows, the change rises
  off their face (and is taken off `regard_events`, so it doesn't rise again on the page
  behind), and the conviction bar fills from where it stood (`Widgets.fill_from`).
- **Set pieces.** The oath: their banner comes down, the crown's goes up, the card glows.
  Single combat: your champion steps onto the stage, they close twice, then the result
  (decided and saved before any of it shows; a tap skips it). Drawn swords: a glint of
  steel as the talk gives way to the field.
- **The place.** Firelight in a hall or your camp after dark, their banner stirs, and a
  painted place drifts very slowly.

All of it is still under Reduced motion. Checked by `_lord_talk` in
`tests/game_feel_tests.gd`.

## Added after: the romance screens

Visits, the dance and the wedding are `TalkView`s, so most of this lives there and every
talk built on it gets it:

- **Faces are alive.** A slow breath, and `gesture(side, kind)`: a laugh ("bounce"), a
  lean in, drawn back. `express(side, tex, mood)` changes the picture and plays the
  gesture that goes with a `StoryArt` expression. Breath, lean and sway go through scale
  and rotation about the feet, so they never fight the layout or a position tween. The
  painted portraits blink too (see "The painted portraits blink" below).
- **Only the new line is said.** A visit lays its exchange out again on each "Go on";
  `write_lines` keeps the lines already heard still, and the log glides to the newest.
- **Replies and keepsakes arrive.** Replies in a short run (pressable at once); a memory
  kept, a status badge and the wedding's closing card settle in with a glow
  (`TalkView.land`).
- **Trust and standing are seen to change.** On the nameplate the bar fills from where
  it stood, the number counts, the heart beats and a heart rises off their face. No sum
  is floated: what it meant stays in words, as before. Courting, sworn friendship and
  engagement drop a ribbon; a parting dims them.
- **The dance.** A partner steps in (`replace_face`) and sways while you dance.
- **The wedding.** Guests' faces come in one after another, the rite is told a line at a
  time (a tap brings the rest), and "Married" throws petals (`WeddingDressing.burst`).
- **People.** Back from a visit, her trust bar fills to its new value and new memories
  glow (`Scenes.people_seen`).

Checked by `_romance_moves` in `tests/game_feel_tests.gd`.

## Added after: the big moments, the pages, and the battle's stride

**Big moments.**

- **The captains' talk at the fire** is told a line at a time (`TalkView.say_in_turn`).
  Every line is in the talk from the start, so the way on can be pressed at once and
  nothing waits; each shows and is written as its turn comes, at about reading pace, and
  a tap brings the rest. The one speaking is lit and warm, the one listening quiet
  (`spotlight`), and both blink (`set_blink`; one clock for every blinking face,
  `TalkView.blink_step`, shared with the lord talk). A line is leaned into by its own
  speaker's face: with two faces on a stage it used to be the right-hand one, always.
- **A bond's new rank**: the two step toward each other and the rank is struck
  (`Widgets.step_in`, `Widgets.stamp`). At a remembrance the lost captain arrives as
  they were and greys as you watch.
- **A crown raised, a crown fallen** takes the screen for a breath (`Scenes.moment`):
  the light drops, the banner unfurls (or comes down) over its words, and a tap sends
  it away. It waits its turn with the ribbons.
- **The map tells what concerns you** with a ribbon: a fief granted or lost, a lord
  sworn, slain or taken by you, a siege on your holding, an alliance made or ended, a
  castle or town your crown gains or loses, and peace as well as war. A holding that
  changes hands furls its old banner and lets down the new, with a ring going out.

**Pages that were rebuilt in a frame.**

- **Crown**: the word on what you did lands with a glow, the card it changed shows
  itself (`_act(ok, message, glow)`), and the treasury counts to its new sum.
- **Town**: a hero who joins is seen (their face on a ribbon, `Scenes.ribbon_face`; the
  Squads tab glows), the lists' result drops in, its bouts are read out in turn when
  opened, and a toast, gift or speech glows where it was done.
- **Letters**: a letter unfolds when opened, as does a reply written out or sent
  (`Widgets.unfold`); unread dots beat once when you come to the tab (`Widgets.pulse`).
- **Captain's page**: a new role is struck onto the page and told with their proud
  face; the living blink (`CaptainArt.blink_loop`).
- **Warband**: the captains around the fire blink, and men back on their feet (or lost)
  since you last looked are counted in.

**The battle.** The audit behind this pass found most of what the immersion roadmap
lists under "Formation state" and "Terrain contact" already built: the ring where a
company halts, the wavering standard and glances, edge markers for your own companies,
and dust by the ground under it. What was added:

- **A stride in four.** Every soldier and horse has a passing step (frame 3, drawn by
  `tools/unit_sprites.py`: boots drawn in under the body, a horse's legs gathered
  level), and a stride runs step, passing, step, passing (`WALK`), twice as fast in a
  rout. The three frames there were are unchanged.
- **A halt is felt**: the men dip into their stance as the ring goes out.
- **Rings on the water** under men wading or fighting in a ford.
- **A warning at the edge** for enemy horse at the charge near one of yours, out of
  sight: an open red chevron (yours are filled).

Checked by `_turning_points` and `_pages_show_change` in `tests/game_feel_tests.gd`
and section 6b of `tests/battle_feel_tests.gd`.

## Seen on a screen

The pass above was then played on a real (virtual) display and looked at frame by
frame: `xvfb-run` with Mesa's software renderer, as `tools/render_splash.gd` does, with
`--fixed-fps 30` and the viewport saved at chosen moments. What that showed, and what
was changed because of it:

- **Reply tags and "what changed" notes stood one letter to a line** (on `main` too): a
  wrapping label in a flow container is given no width. They now take the rest of their
  line (`TalkView.marks`, `TalkView.fx_note`).
- **The heart that rises when trust is won started above the screen**: a painted
  portrait fills the stage. It starts by their head now.
- **The petals at a wedding were a few specks.** They're a shower.
- **The fire talk waited ten seconds before anyone spoke**: narration is given a glance
  (`TalkView.turn_time`), what's said its reading time.
- **In a duel your champion stood under your own banner's mark**: it's furled while
  they fight.
- **The passing step can hardly be seen**: from above, boots are under the body. The
  step is now in the body as well: a marching man's shoulders roll and he sways off his
  line, a horse stretches and gathers, and both ease away as a company halts
  (`look["march"]`).
- **The warning for horse out of sight sat under the objective** at the top of the
  field, where the enemy mostly comes from. It sits clear of it, and is larger.

Still as they were, and seen on the way: the Crown page's last tab wraps its label
("Diplomac / y") at phone width.

## The painted portraits are alive

Edda, Farah and Kaede are paintings, one per expression, and none was painted blinking,
glancing aside or with a lifted brow. `tools/portrait_faces.py` makes those faces from
each painting's own pixels, so they sit exactly on it:

- **shut** and **half**: the eyes closed (skin mended over them from what surrounds them,
  the lid lit, the lashes along the lower lid) and halfway closed. A blink is half, shut,
  half, open.
- **soft**: the lids a third of the way down: a fond look, and the bottom of a nod.
- **away**: the irises moved further the way they lean: a glance aside. Not made where the
  eyes are already lowered (the three thoughtful paintings).
- **brow1**, **brow2**: the brows raised. The brow moves whole, the forehead gives, and only
  the thin strip of plain skin under it stretches, so the lid's crease stays put.

Only the strip the eyes and brows are in is kept (`StoryArt.FACE`, 104×72, the same on
every painting), one per face, stacked: `assets/portraits/face/<who>_<expression>.png`.
`StoryArt.face_frame(tex, name)` lays a strip over the painting the first time that face
is asked for. The tool also writes `<who>_hair.png`, how freely each pixel of loose hair
may swing.

`assets/shaders/portrait_life.gdshader` moves the head and hair without repainting: the
head tilts and sinks on a neck that bends between chin and collar, a nod turns the front
of the face down more than the edge of the head (so it's a turn, not a slide), and loose
hair swings, held where it leaves the head. Each character's head is placed in
`StoryArt.HEADS`.

`PortraitLife` decides, moment to moment, the face worn and how the head sits: a breath
in the head and hair always; a two-step blink every few seconds; a glance aside of their
own now and then; and what a mood calls for, through `TalkView.express`: amused, a brow
lifted with a tilt; warm, a small nod with the eyes lowered; thoughtful, the lids lowered
further and the head tilted (the thoughtful paintings already look down, so they have no
glance to give).
Trust won on a romance visit brings a soft look (`TalkView.life_act`). The nod was tried
deeper first, and read as a bob; it is now small and slow.

- A face asked for mid-blink or mid-glance doesn't flicker; a new expression lands on the
  new face and brings its own other faces.
- A face that isn't painted (a captain's, put in the same place) loses the shader.
- Under Reduced motion the painting is shown as painted, and nothing moves.
- On a page (People), `StoryArt.candidate_portrait` blinks in two steps by itself.
- Run the tool again after a portrait is repainted. One eye is given by hand (`BY_HAND`:
  Farah, thoughtful, all but shut already); each character's hanging hair is placed in
  `HAIR_HANGS`.

Seen on a screen in all three talks, at the height of each move; checked by
`_painted_blink` in `tests/game_feel_tests.gd`.
