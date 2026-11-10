# The opening: what's wrong with it and what to do

A plan, nothing built yet. The opening is `scripts/menu/opening.gd` (240 lines), played over
Home by `scripts/menu/title.gd`; its first frame is meant to be the boot splash
(`assets/splash.png`, rendered by `tools/render_splash.gd`). `tests/opening_tests.gd` covers
it and passes today.

## How it plays now

Frames captured from the running game (Godot 4.7, a 9:19.5 phone, a campaign under way). A
4:3 tablet and a first visit show the same things.

![The opening as it plays now](mockups/opening-as-it-plays.png)

| Seconds | What happens |
|---|---|
| 0.0–0.3 | The first frame holds. |
| 0.25–1.3 | Dawn rises in stepped bands; the banners light 0.15 s apart and sway. |
| 0.95–1.55 | The glint crosses the title. |
| 1.35–1.95 | The land slides down 35% of the screen and fades. |
| 1.55–2.25 | The title shrinks and rises to its place on Home. |
| 1.95–2.75 | The night fades off Home, all of it at once. |

## What's wrong

1. **The splash is not the first frame.** The splash has the word alone, in Cinzel, centred.
   The opening's first frame has the painted wordmark: three small banners, a line of sea,
   the name in another face, and the tagline. So every launch starts with a jump, which is
   the one thing the splash was built to avoid. The wordmark came to Home after the splash
   was rendered, and the render tool builds its own stand-in title, so nothing noticed. The
   test checks the splash's size, shape and corner colour, never what is in it.
2. **Six banners.** The wordmark has its own three banners, so a second, smaller set stands
   under the three on the ridge, in a different order (ridge: Kharzan, Vardmark, Ryumon;
   wordmark: Vardmark, Ryumon, Kharzan).
3. **The glint is broken.** It shows the hidden Cinzel label in pale gold through a 36px
   slit. Over the wordmark, which is set in another face and has banners where the label has
   its first letter, that reads as a stray pale stroke passing through the name (see 1.3 s).
4. **The land falls through the title.** At 1.7 s the fading banners and the dawn band are
   sliding down across the wordmark as it rises. And the dawn that has just come up goes
   down again.
5. **It goes dark in the middle.** At 1.9 s the screen is flat night with a small wordmark
   in flight. The story reads night, dawn, night, Home. The dawn never reaches Home, though
   Home is the Glass Sea at dawn (`title.gd` lights its map with `DAWN`).
6. **Home arrives as one cross-fade.** Map, title, card and buttons at the same moment.
   Home's own 0.35 s fade-in is spent under the opening where nobody sees it.
7. **It is silent.** No cue marks the dawn or the title. The music starts when Home is
   built and fades in over 1.4 s, timed to nothing.
8. **A tap makes a cut.** `hurry()` jumps to 1.35 s, so the dawn and the banners snap to
   full before the fast finish.
9. **Reduced motion gets a hard cut** from the splash to Home. A plain fade is not motion.

## What to build

The idea stays: night on the ridge, dawn, the title, Home. Three changes of substance: the
splash is the first frame again, the dawn opens onto Home with no dark between, and there
is one set of banners which becomes the mark.

### Stage 1: make it true again (small)

Fixes only. The opening looks as it does now, without the faults.

- **One title, built in one place.** Move `title.gd`'s `_title()` and `_wordmark()` to a
  small shared script (`scripts/ui/wordmark.gd`). Home, the opening and the render tool all
  build the title from it. The tool's stand-in goes.
- **Re-render the splash** from that title, so frame 0 and the splash are the same picture.
- **A guard that runs headless.** The render tool writes `assets/splash.json` beside the
  image: the MD5 of `wordmark.png`, and where the title and each banner sit in the box at
  t = 0. The test builds the opening at the box's size, compares those rects, and compares
  the MD5. That catches exactly what happened here (the title changed, the splash didn't).
  Pixels can't be compared headless, so the tool also takes `--check`: render, compare with
  the committed image, fail above a small mean error. Run it under xvfb when the opening
  changes.
- **The glint, done on the picture.** A clipped copy of the same wordmark, modulated pale,
  through the slit. It then brightens the letters that are there. It runs over the name
  only, not the small banners.
- **The land leaves without crossing the title.** It sinks 8% of the box, not 35%, and has
  faded before the title starts to move.
- **A tap never cuts.** `hurry()` keeps `t` where it is and raises the rate, so the rest
  plays through in about 0.4 s.
- **Reduced motion:** the opening's first frame fades off Home over 0.25 s. Nothing moves.

### Stage 2: the dawn opens onto Home (medium)

The second half is rebuilt so the light that rises behind the ridge is the light Home is in.

| Seconds | What happens |
|---|---|
| 0.0–0.25 | Hold: the splash, exactly. This also covers a slow first frame. |
| 0.25–1.2 | Dawn. The stars go out from the horizon upward. The banners catch the light left to right, 0.22 s apart, each a little over-bright for a moment; a gust follows the light along the ridge, so each banner starts to sway as it is lit. |
| 1.0–1.5 | The glint crosses the name. |
| 1.5–2.3 | The night lifts from the horizon upward, in the same 18px steps as the dawn bands, with a warm edge. Home's map shows first, under the dawn. The ridge sinks and darkens out below the lifting edge. The title rises ahead of that edge to its place on Home. |
| 2.1–2.7 | Home arrives in order: the card rises 24px and fades in, then the bottom row. Home's own column fade waits for this, not for `_ready`. |

- No frame is flat night after 0.25 s. That is the test for point 5.
- Taps reach Home when the card is up (about 2.4 s), not when the last fade ends.
- The night overlay is drawn as bands with their own alpha: no shader, safe on GL
  Compatibility, a few dozen rectangles a frame.
- Total 2.7 s, as now.

**Sound.** Three cues, all under the sound settings that exist:
- `birds`, quietly, from 0.3 s, fading under the music.
- One short rising cue as the glint crosses. There is no fitting sound in `assets/audio/sfx`
  (`horn` and `bell` are battle and town); make one with `tools/battle_sfx.py` or
  `tools/music.py`, and add its level to `sfx_levels.gd`.
- `Sound.haptic()` once, when the title lands.
- The music starts with the opening and reaches full as the title lands: give the opening
  the 1.4 s fade's start, or hold `play_music` until 1.0 s. Try both by ear.

### Stage 3: the banners become the mark (medium)

One set of banners. The three on the ridge are the wordmark's three, large.

- **The splash:** the three banners on the ridge in the wordmark's order (Vardmark, Ryumon,
  Kharzan) and the name with its tagline under them. No small banners.
- **The gathering,** 1.5–2.2 s: each ridge banner shrinks and flies to its place beside the
  name, 0.06 s apart, and over its last 0.15 s cross-fades into the painted one. The name
  slides right to make room. The mark is whole as it reaches Home.
- **How:** the wordmark is one image, so it is shown as two regions of it (banners, name)
  with `AtlasTexture`. Each piece has a start rect in the box and an end rect taken from
  Home's own wordmark, and moves between them. Nothing is measured by eye.
- The line of sea under the wordmark's banners fades in as they land.
- Re-render the splash; the Stage 1 guard covers the new first frame.

Stage 3 changes what the splash looks like, so decide it before Stage 1's re-render if it
is wanted; then the splash is rendered once.

## Files

| File | Change |
|---|---|
| `scripts/ui/wordmark.gd` (new) | The title label and wordmark, shared; the two regions for Stage 3. |
| `scripts/menu/opening.gd` | The timeline, the glint, the lifting night, `hurry()`, the cues, the gathering. |
| `scripts/menu/title.gd` | Uses the shared title; Home's column waits for the opening; reduced-motion fade. |
| `tools/render_splash.gd` | Builds the real title; writes `splash.json`; `--check`. |
| `assets/splash.png`, `assets/splash.json` | Re-rendered. |
| `scripts/audio/sound.gd`, `scripts/data/sfx_levels.gd`, one new sfx | The opening's cue. |
| `tests/opening_tests.gd` | The guard; no dark frame; the land never overlaps the title; a tap doesn't move `t`; taps pass at the card; reduced motion fades. |
| `README.md` | The opening's paragraph, and the `--check` command. |

## Done when

- The splash and frame 0 match on a phone, a tablet and a desktop window: `--check` passes,
  and a screen recording of a cold start shows no jump.
- No frame between 0.25 s and the end is a flat colour.
- Nothing crosses the title at any time.
- A tap at any moment ends it in under half a second with no cut.
- With reduced motion nothing moves, and nothing cuts.
- `tests/opening_tests.gd`, `menu_tests.gd`, `presentation_tests.gd` and
  `screen_width_tests.gd` pass.
- Checked on a real phone, cold start, sound on: the cue lands with the glint.

## Questions

1. **One set of banners or two?** Stage 3 is the better opening, and it changes the splash's
   picture and the order on the ridge. Without it, Stages 1 and 2 stand on their own, with
   six banners.
2. **The ridge's order.** Stage 3 puts Ryumon in the middle, as the wordmark has it. If
   Vardmark should stay in the middle, the wordmark image is the thing to change.
3. **A shorter opening for a returning player?** It plays once a launch, every launch. A
   1.6 s cut when a campaign exists (hold, a quick dawn, lift) is a small addition to Stage 2.

## Not in this plan

Home's wordmark is hard to read over the map once the opening has gone (brass on green,
under a 25% veil). That is Home's layout, not the opening, and wants its own look.
