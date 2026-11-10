#!/usr/bin/env python3
"""The opening's one cue: `glint`, the light running across the title. A soft rising
shimmer of four bell tones (E, G#, B, E) over a breath of air, all above 1 kHz, so a phone
speaker carries it and it sits clear of the music. Synthesized, no samples needed; writes
assets/audio/sfx/glint.ogg (needs numpy and ffmpeg). Run tools/sfx_levels.py after.

    python3 tools/opening_sfx.py
"""
import os
import subprocess

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx", "glint.ogg")
SR = 44100
LENGTH = 1.4


def bell(freq, start, length, decay, gain):
    t = np.arange(int(length * SR)) / SR
    tone = np.zeros_like(t)
    # A bell's inharmonic partials, the upper ones dying first.
    for ratio, amp, d in [(1.0, 1.0, 1.0), (2.76, 0.32, 0.55), (5.4, 0.12, 0.3)]:
        tone += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay * d))
    attack = np.minimum(1.0, t / 0.006)
    out = np.zeros(int(LENGTH * SR))
    i = int(start * SR)
    seg = (tone * attack * gain)[: len(out) - i]
    out[i:i + len(seg)] += seg
    return out


def air(rng):
    # A breath of air: noise, band-limited to 3-7 kHz, swelling and falling with the slit.
    n = int(LENGTH * SR)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec[(f < 3000) | (f > 7000)] = 0
    x = np.fft.irfft(spec, n)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 2
    return x / np.max(np.abs(x)) * env * 0.05


def glint():
    rng = np.random.default_rng(7)
    notes = [1318.5, 1661.2, 1975.5, 2637.0]
    x = sum(bell(f, 0.06 * i, LENGTH - 0.06 * i, 0.42, 0.55 - 0.08 * i) for i, f in enumerate(notes))
    x = x + air(rng)
    t = np.arange(len(x)) / SR
    x *= np.minimum(1.0, (LENGTH - t) / 0.25)  # no click at the end
    return x / np.max(np.abs(x)) * 0.8


def write(x, path):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", path], input=pcm, check=True)


if __name__ == "__main__":
    write(glint(), OUT)
    print("Wrote", os.path.relpath(OUT, ROOT))
