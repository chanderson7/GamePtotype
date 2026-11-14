# Trailer tools

Records gameplay footage straight from the game with Godot's Movie Maker, then cuts it into a 16:9 trailer for YouTube.

```sh
export TRAILER_OUT=/tmp/bannerfall-trailer   # clips, logs and the finished video go here
tools/trailer/record_all.sh                  # every shot in shots.txt, three at a time
tools/trailer/record_all.sh battle_woods     # or only the ones named
python3 tools/trailer/edit.py                # -> $TRAILER_OUT/bannerfall_trailer.mp4 (+ thumbnail, captions)
```

Needs Godot 4.7 as `godot`, `ffmpeg`, Python 3 with Pillow, and `xvfb-run` when there's no display. Recording is slow: 5–20% of real time, because every frame is saved as a PNG.

| File | What it does |
| --- | --- |
| `shots.txt` | Each shot, how many seconds to record, and portrait (the game's own screens) or landscape (battles and the map, full frame). |
| `capture.gd` | Sets the game up for one shot (`SHOTS`): a campaign of a given people at a given hour and place, a lord's talk, the wedding, or a battle. It can press replies on cue (`taps`). Nothing is saved, and preferences go to a scratch file. The music is off: the trailer is scored separately and the clips keep their field sounds. |
| `battle_cam.gd` | Puts the battle HUD away and holds the camera on the fighting (the clash, one squad, or a pan), keeping the screen's own shake. |
| `map_cam.gd` | Puts the map HUD away and drifts the camera across the Glass Sea. |
| `taps.gd` | Presses a reply by id or by its words at a given second. |
| `record.sh` | Records one shot: `record.sh <shot> <seconds> [portrait\|landscape]`. A temporary `override.cfg` sizes the window. |
| `edit.py` | The cut (`EDL`, 80 s, cut on the bars of the main theme `title.ogg`): cards, clips, captions in the game's fonts, the clips' own sound under the theme, loudness set for YouTube (-14 LUFS), and a 1280x720 thumbnail. The end card's line ("Coming to iPhone") is `END_LINE`. It also writes the words on screen as `bannerfall_trailer.srt`, to upload beside the video. |

Battles are the computer fighting both sides. These shots don't name the fight's seed (`seed` here only picks the ground), so a battle shot differs from one recording to the next and its in-point in `edit.py` has to be looked at again. `tools/trailer2/` names a seed for every fight; its shots repeat.
