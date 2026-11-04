#!/usr/bin/env python3
"""Measures how loud every sound effect is and writes scripts/data/sfx_levels.gd.

A file's level is its loudest tenth of a second (RMS, dBFS): what the ear notices in a
short hit. Sound.gd sets each battle sound's volume from its target level and this
measure, so every take of a sound plays equally loud, however it was recorded. Run it
again after rendering or replacing any file in assets/audio/sfx (needs ffmpeg and numpy):

    python3 tools/sfx_levels.py
"""
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT = os.path.join(ROOT, "scripts", "data", "sfx_levels.gd")
RATE = 44100
WINDOW = 0.1


def samples(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def loudest(x):
    n = int(RATE * WINDOW)
    if len(x) <= n:
        return 20 * np.log10(float(np.sqrt(np.mean(x ** 2))) + 1e-9)
    best = 0.0
    for i in range(0, len(x) - n, n // 4):
        best = max(best, float(np.sqrt(np.mean(x[i:i + n] ** 2))))
    return 20 * np.log10(best + 1e-9)


def main():
    levels = {}
    for f in sorted(os.listdir(SFX)):
        name, ext = os.path.splitext(f)
        if ext.lower() not in (".ogg", ".wav"):
            continue
        levels[name] = round(loudest(samples(os.path.join(SFX, f))), 1)
    lines = [
        "## How loud each sound effect file is: its loudest tenth of a second, in dBFS.",
        "## Written by tools/sfx_levels.py; run it again after changing assets/audio/sfx.",
        "extends RefCounted",
        "",
        "const LOUDEST := {",
    ]
    lines += ['\t"%s": %.1f,' % (k, v) for k, v in levels.items()]
    lines += ["}", ""]
    with open(OUT, "w") as out:
        out.write("\n".join(lines))
    print("%d files -> %s" % (len(levels), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
