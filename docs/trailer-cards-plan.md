# Vaskaria: the trailer's title and end cards

- **Date:** 2026-11-14
- **Status:** packages 1 to 6 built (2026-11-14); package 7 not built, as planned. Built as
  written, except: the thumbnail's name is size 140 with 10 between letters, not 150 (at 150
  its last letter ran into the phone). Checks: the seven untouched frames are pixel-identical
  to before; a full render took 5 min 22 s; the mix reads -14.0 LUFS; the last frame is the
  end card.
- **Scope:** the two cards of the *Captains* trailer (`tools/trailer2/cut.py`): the name at
  0:24 and the end card at 1:00. Nothing else in the trailer changes.

## What is wrong with them

Both cards are the logo, small, on an empty dark field.

- They are the only frames in the trailer with **no game in them**. Every other frame is
  pixel art in motion; these two are a flat gradient.
- The logo is the in-game header's lockup (banners left, name right), made to sit small at
  the top of a phone screen. On a 16:9 card it fills a third of the width, sits off-centre,
  and leaves most of the frame empty.
- The letters are **flat brass**: no light, no edge, no depth. The tagline is about 37
  pixels tall at 1080p, grey, and unreadable on a phone.
- **Nothing moves.** The title has one scale-in; the end card holds still for ten seconds.
- "COMING TO IPHONE" is the trailer's only call to action and is the smallest thing on screen.
- The trailer **ends on black** (a fade). A player that stops on the last frame shows nothing.

## What other games do

From game trailers generally, and three points checked today (sources at the end):

1. **The logo sits on the game, not on a colour.** Key art or dimmed gameplay behind the
   title, moving slowly.
2. **The logo is big and centred**, usually a stacked lockup (emblem over name) so the card
   is symmetrical; the name spans half the frame or more.
3. **The letters have material**: a metal gradient, a lit edge, a hard shadow, and a glint
   that sweeps across once.
4. **The air moves**: embers, dust or snow drifting through, so a held card is never still.
5. **The reveal lands on the music**: a slam, a shake, a flash, a ring of light, then the
   glint.
6. **The end card says one thing to do**, large, under the logo, with the platform. One
   call to action, not several. *(sourced)*
7. **The last frame is the end card, not black**, because players stop on it. *(sourced)*
8. **Room is left for YouTube's end-screen buttons** (a video tile and a subscribe circle),
   inside the middle 80% of the frame. *(sourced; sizes are third-party figures)*
9. **Store badges follow the store's rules.** Apple's: only Apple's own badge artwork, one
   per video, never animated or altered, below the main message, and the pre-order badge
   only once the app can actually be pre-ordered. *(sourced)* Until then: plain words.

## Brief for whoever builds this

You are changing how two cards are drawn in `tools/trailer2/cut.py`. Read that file and
`tools/trailer2/README.md` first. Work through the packages below in order; each one can be
committed on its own.

**Rules**

- Touch only `tools/trailer2/cut.py` (and this file's status line when done). Do not change
  `score.py`, `stage.gd`, `shoot.sh`, any timing, `bar()`, `LENGTH`, or what any other part
  of `picture(t)` draws. The one exception is named in package 5: what the victory shot
  fades into during its last 0.7 s.
- Python standard library, numpy and Pillow only. No new image files in the repo: every
  piece is drawn from the fonts in `assets/fonts/` and from `assets/branding/wordmark.png`.
- Everything is a pure function of `t`: seeded randomness only
  (`np.random.default_rng(<fixed number>)`), so the same frame always comes out the same.
- Cache what does not change per frame (lockups, masks, particle seeds) in module-level
  dictionaries, as `words()` and `wordmark()` already do. A full render must stay under
  about six minutes.
- Comments in the file's existing voice: plain sentences saying what a thing is for.
- Do not use Apple's logo, an App Store badge, or a drawing of an iPhone with Apple's
  marks. Package 5 leaves a slot for the real badge file.

**Getting set up.** `cut.py` needs the recorded shots in `$TRAILER_OUT/shots/` and their
logs in `$TRAILER_OUT/logs/`. If they are not there, record them (`tools/trailer2/shoot.sh
all`, about 25 minutes; needs Godot 4.7, see the README). A single frame needs no music:
`python3 tools/trailer2/cut.py --frame 24.5` writes `$TRAILER_OUT/frame_024.50.jpg`. The
full render also needs `score.wav` (`samples.sh` once, then `score.py`).

**Before changing anything**, render these frames and keep them as the "before" set:
`10.0 20.07 23.0 30.3 45.5 54.5 58.07` (must not change) and
`24.0 24.1 24.5 25.0 25.9 60.2 61.0 62.2 63.5 66.1 69.97` (the cards).

**Times you will need** (seconds; a bar is 2 s): the title card is `bar(13)` to `bar(14)`,
24.0 to 26.0. The end card is `bar(31)` to the end, 60.0 to 70.0. In the music the horn
enters at 62.0 and a harp chord lands at 66.0.

### Package 1: a lockup made for cards

Add `lockup(scale)` returning one RGBA picture, cached by `scale`, built from three pieces
stacked and centred:

| Piece | Source | At `scale` 1.0 |
| --- | --- | --- |
| Emblem | crop `(0, 0, 452, 354)` of `wordmark.png` (the three banners and the water) | resized to 565×442 (LANCZOS) |
| Name | the word `VASKARIA`, Cinzel Bold | size 230, 30 px between letters |
| Tagline | `Squad battles across the Three Realms`, IM Fell English Italic | size 58, colour (214, 218, 236) |

Vertical gaps: 34 px emblem to name, 26 px name to tagline. Also return (or cache beside
it) the **name's alpha mask** placed in the lockup's coordinates: package 3 needs it.

Give the name material, in this order:

1. **Gradient fill** by height through the letters' mask: (247, 216, 132) at the top,
   (217, 169, 68) at 45%, (150, 103, 36) at the bottom.
2. **Lit edge**: where the mask has ink but the mask shifted by (+2, +3) does not, add
   (255, 240, 190) at 70%. **Shaded edge**: where the mask has ink but the mask shifted by
   (−2, −3) does not, multiply by 0.55.
3. **Dark outline**, 3 px, (20, 14, 8), under the letters (Pillow's `stroke_width` on a
   separate layer, composited beneath).
4. **Hard shadow**: the outline layer's alpha, offset (0, 8), colour (4, 5, 10) at 80%.
5. **Glow**: the letters' alpha blurred 26 px, colour (222, 174, 72) at 22%, under everything.

The tagline gets the same soft dark shadow `words()` gives type today.

Done when: `lockup(1.0)` is about 1400 px wide and 760 px tall; saved over a (9, 12, 22)
background it shows banners above a dimensional brass name above a readable tagline, all
centred. The old `wordmark()` function stays (the thumbnail still uses it until package 6).

### Package 2: the game behind the cards

Add `behind(shot, secs, dim, soften)`: a recorded frame as a backdrop.

- `still(shot, secs)`, resized to (W/soften, H/soften) with BILINEAR, a 2 px Gaussian blur,
  resized back to (W, H).
- Multiply by `dim`, then by (0.80, 0.90, 1.15) per channel, then add `NIGHT × 0.6`.
- Multiply by the vignette `graded()` already builds, then add a **warm core** behind where
  the logo will stand: an ellipse 1100×620 centred on the frame, blurred 200 px, adding
  (60, 40, 14) at its middle. Cache the core.

Use it:

- **Title card:** `behind("clash", mark("clash", "CLASH") - 2.9 + u, dim, 2)` where `u` is
  seconds into the card. Those are the two armies walking toward each other, and they are
  the seconds just before the shot the next bar cuts to, so the title sits over the calm
  and the cut lands on the same field at full brightness. `dim` is 0.42 for the whole card.
- **End card:** `behind("dusk", 7.5 + u * 0.5, 0.26, 5)`: the dusk battle at half speed
  (ten seconds of card from five of footage), soft and dark enough that only its warmth and
  movement read.

Done when: frame 24.5 shows two dim armies under the logo; frame 63.5 shows slow warm
movement, with no readable detail, behind the end card; `night()` is no longer used by
either card (it is still used at 22.0 for "Lead them anyway").

### Package 3: embers and a glint

**Embers**, `embers(canvas, t, strength)`: 150 square sparks, so they sit with the pixel
art. Seed them once with `default_rng(41)`: for each, a start x in [0, W], a start y in
[0.45 × H, H + 20], a rise speed in [26, 90] px/s, a size in {3, 4, 6}, a phase in [0, 1],
a sway width in [8, 40] px, and a life in [3, 7] s. At time `t` a spark's age is
`(t / life + phase) % 1` (0 newborn, 1 gone, then it starts again); its y is
`start_y − age × life × speed`; its x is `start_x + sin(t × 1.3 + phase × 6.28) × sway`;
its brightness is `sin(age × π)`, so it fades in and out and never pops. Colour between (255, 196, 96) and (255, 120, 48) by size. Draw them **added**
to the picture (numpy on a float copy), scaled by `strength`.

**Glint**, `glint(canvas, mask, at, progress)`: a bright bar that crosses the name once.
The bar is 150 px wide, tilted 20°, soft-edged (a triangle falloff across its width); its
centre runs from 200 px left of the name to 200 px right of it as `progress` goes 0 to 1.
Add (255, 246, 214) × 0.75 × bar, **only through the name's mask** from package 1.

Done when: stepping `--frame` from 24.3 to 25.0 shows the bright bar crossing VASKARIA left
to right and touching nothing but the letters; sparks drift upward on both cards and are
never larger than 6 px.

### Package 4: the title card, on the beat

Replace the `# ---- bar 13: the name` block. With `u = t − bar(13)`:

| When (`u`, s) | What happens |
| --- | --- |
| 0.00 | Backdrop from package 2. The lockup lands: scale `1.30 → 1.00` over 0.16 s with `ease`, then creeps to 1.02 by the card's end. Drawn at `lockup(1.0)`, centre (W/2, H/2 + 10). |
| 0.00 – 0.35 | Shake: offset the lockup by `(sin(t × 90) × 14, cos(t × 70) × 10) × (1 − u / 0.35)`. |
| 0.00 – 0.50 | A ring of light behind the lockup: an ellipse outline whose radius grows from 200 to 1100 px, 16 px wide, blurred 14 px, colour (255, 220, 150), opacity `0.5 × (1 − u / 0.5)`. |
| 0.35 – 1.00 | The glint crosses the name once (`progress = (u − 0.35) / 0.65`). |
| whole card | Embers at strength 1.0. |

The white flash at `bar(13)` already exists in `FLASHES`; leave it.

Done when: 24.03 is mid-slam and bright; 24.5 has the glint part-way across; 25.9 is a
settled, centred logo over the dim armies; 26.03 is unchanged from before.

### Package 5: the end card, on the beat

Replace the `# ---- bars 31-35: the name` block. With `u = t − bar(31)`:

| When (`u`, s) | What happens |
| --- | --- |
| 0.0 – 1.2 | The backdrop fades up from the last frame of the victory shot (the existing blend into `night()` at the end of bar 30 becomes a blend into this backdrop at its first frame). |
| 0.4 – 1.6 | The lockup fades in at `lockup(0.82)`, centre (W/2, 430), rising 30 px as it comes (`ease`). It then creeps from scale 1.00 to 1.03 over the rest of the card. |
| 2.0 – 2.7 | The glint crosses the name (the horn enters at 62.0). |
| 2.6 – 3.4 | The call to action fades in at y = 860: `COMING TO IPHONE`, Cinzel Bold 66, colour (240, 233, 216), 12 px between letters, with a brass rule 180 px long and 3 px thick on each side of it, 40 px from the words. |
| 3.2 – 4.0 | If `END_ACTION` is not empty, it fades in at y = 945: IM Fell English Italic 44, colour (198, 201, 214). |
| 6.0 – 6.6 | A second, fainter glint (× 0.5) on the harp chord at 66.0. |
| whole card | Embers at strength 0.8. |

Add two constants beside `END_LINE`:

- `END_ACTION = ""`: a second line for the day there is somewhere to send people, such as
  `Join the beta: <address>`.
- `STORE_BADGE = None`: a path to Apple's own badge file, for the day there is a pre-order.
  When set, paste it **unaltered** (resize only, keeping its proportions, 96 px tall),
  centred at y = 960, appearing with a plain cut at `u = 3.4`: no fade, no movement, no
  effects on it, and drop `END_ACTION` that render. One badge only.

**Hold the last frame.** In `finished()`, remove the fade to black at the end: the last
frame of the video must be the full end card. (The music already fades itself.)

Done when: 61.0 shows the logo arriving over dim dusk; 63.5 shows logo, tagline and call to
action, all readable at a quarter size (shrink the frame to 480×270 and check); 69.97 is the
same card, not black; nothing sits within 54 px of the top or bottom edge or 96 px of the
sides.

### Package 6: the thumbnail

In `thumbnail()`, replace `wordmark(840)` with the name and tagline from the lockup (not
the emblem: there is no room), the name at size 150, left-aligned with the two lines of
type under it. Keep the phone, the die and the words where they are.

Done when: `cut.py --thumbnail` shows the dimensional name, and it still reads at 320×180.

### Package 7 (only if asked): room for YouTube's end screen

Add `END_SCREEN = False`. When `True`, from `u = 3.0` the end card moves to a split layout:
the lockup at `lockup(0.6)` centred at (560, 330) with the call to action under it at
y = 640; a 16:9 frame for the video tile at x 1010–1730, y 300–705; a 290 px circle for the
subscribe button centred at (560, 850). Draw the two zones as brass corner brackets (3 px,
60 px arms, 70% opacity) with small labels above them (`WATCH NEXT`, `SUBSCRIBE`: Cinzel
Bold 26, 6 px between letters). Everything stays inside x 192–1728, y 108–972. Leave it
`False`: empty brackets look broken until the channel has a second video to point at.

## Checking the whole thing

1. The "must not change" frames (10.0, 20.07, 23.0, 30.3, 45.5, 54.5, 58.07) are
   pixel-for-pixel identical to the "before" set. Compare with Pillow's `ImageChops.difference`.
2. Look at every "card" frame listed above, before beside after.
3. A full render: 70.0 s, 1920×1080, and `ffmpeg … -af ebur128` still reads −14.0 LUFS
   (± 0.2). It finishes in under about six minutes.
4. The last frame of the file (`ffmpeg -sseof -0.05 -i … -frames:v 1`) is the end card.

Report back: the before-and-after frames at 24.5, 25.9, 63.5 and 69.97; the render time;
anything in this plan that turned out wrong or was skipped, and why.

## Not in this plan

- The first trailer (`tools/trailer/edit.py`) keeps its plain cards. If *Captains* is the
  one that is published, that cut can borrow `lockup()` later.
- A painted key-art image. That is the real answer to "eye-catching" for the store page and
  the thumbnail, and it is an illustrator's job (see `docs/artwork-roadmap.md`), not this one.
- The in-game logo (`assets/branding/wordmark.png`) is not changed here: it has to stay
  small and flat to sit at the top of a phone screen.

## Sources

- One call to action, and ending on the card rather than black: [codecks.io](https://codecks.io/blog/2023/creating-video-game-trailers-best-practices/), [presskit.gg](https://presskit.gg/field-guides/game-trailers-screenshots-guide), [gameanalytics.com](https://gameanalytics.com/blog/dos-and-donts-of-game-trailers/). Trade advice, not measurement.
- Apple's badge rules (own artwork only, one per video, not animated or altered, pre-order badge only when on pre-order): [App Store marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines). Read the current page before using a badge.
- YouTube end-screen space (the middle 80% of the frame, element sizes): [a third-party previewer](https://www.collabpals.com/tools/youtube-end-screen-previewer), not YouTube's own documentation. Check in YouTube Studio when placing elements.
- Points 1 to 5 under "What other games do" are general trailer practice, not from a source checked today.
