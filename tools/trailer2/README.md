# The "Captains" trailer

A second trailer, made from nothing in `tools/trailer/`: its own shots, its own cut, and a
score written for it. 1:10, 1920×1080, for YouTube.

It tells one thing the game does that others don't. *Every company has a captain. Every
captain has a name. They remember every fight. And any of them can fall.* The captain who
falls (Rowan of Thornwall, on a die that needed 16 and showed 6) is one of the two the
trailer has just shown talking at the fire. Then: *Lead them anyway*, the name, the battles,
the world, the last charge, victory.

```sh
export TRAILER_OUT=/tmp/bannerfall-trailer2
tools/trailer2/shoot.sh all          # record the 20 shots (about 25 minutes, four at a time)
tools/trailer2/samples.sh            # once: the orchestra's recordings, 1.9 GB, CC0
python3 tools/trailer2/score.py      # -> $TRAILER_OUT/score.wav
python3 tools/trailer2/cut.py        # -> $TRAILER_OUT/bannerfall_captains.mp4, .srt, _thumbnail.jpg
```

Needs Godot 4.7 as `godot`, `ffmpeg`, `xvfb-run` where there is no display, and Python 3
with numpy, scipy, soundfile and Pillow.

| File | What it does |
| --- | --- |
| `stage.gd` | Stages one shot: a fight on a named seed, a siege, the warband, a captain's page, two captains at the fire, a lord's talk, the wedding, a town, the map. `SHOTS` at its top is the list. It can fast-forward a fight to a moment, run true slow motion (the fight stepped a quarter-step a frame, so nothing judders), and point a camera at a company, the fighting, or a spot on the field. While it runs it prints the fight's clock against the recording's: when companies meet and break, when a captain falls and how the die came up, what the gate and the walls are doing. |
| `shoot.sh` | Records shots with Movie Maker (`shoot.sh fall gate`, or `all`), keeping each shot's log; or probes one without drawing it (`shoot.sh --probe fall "seed=4;ff=999" 12`), which is how a moment is found before any frame is recorded. |
| `score.py` | The music, *Who Carries the Banner*: D minor, 120 beats a minute, so a bar is two seconds and every cut can land on a beat. Its docstring maps bars to scenes. It is played by recorded instruments (horn, trumpets, trombones, tuba, strings, harp, flute, kettledrums, bass and tenor drums, cymbals, gong, a bell) from the VS Chamber Orchestra Community Edition, which is CC0. `--stems` also writes each section on its own. |
| `samples.sh` | Fetches those recordings into `tools/samples/vsco`. |
| `cut.py` | Draws every frame and pipes it to ffmpeg: field shots full frame, the game's own screens in a phone large enough to read with the trailer's words beside them, type that lands on the beats. It lays the shots' own sound under the score, sets the loudness for YouTube (−14 LUFS), and writes the captions and a thumbnail. `cut.py --frame 20.07` draws one frame to look at. |

## What makes a shot repeat

The game seeds a fight from the clock. For a trailer cut to music a shot has to be the same
fight every time, so `battle_screen.gd` now lets a fight name its seed
(`pending_battle["seed"]`; without one it is the clock, as before), and `stage.gd` names one
for every fight. The three moments that have to meet the music (the charge striking, the
die landing, VICTORY) are not written into `cut.py` as numbers: it reads them from the log
each recording leaves in `$TRAILER_OUT/logs/`, so a shot recorded again still lands on its
beat.

## Changing it

- **Another captain's death.** `shoot.sh --probe fall "seed=N;ff=999" 12` over a range of
  `N` prints who falls and what the die showed. Seeds 9 and 19 kill Rowan; most seeds wound
  someone or no one.
- **Another battle in the run.** Add a shot to `SHOTS`, record it, and put it in `BATTLES`
  or `LAST` in `cut.py`.
- **Other words.** They are in `picture()` in `cut.py`, and again in `CAPTIONS` for the
  `.srt`. The end card's line is `END_LINE`.
- **The music.** Each scene is a function in `score.py`; the tune is `FIRST` and `SECOND`,
  the harmony `CHORD`. The mix is checked by measurement, not by ear: nobody has listened to
  it on a speaker yet. Do that before it is published.
