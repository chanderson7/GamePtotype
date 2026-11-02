"""Recorded instruments for tools/music.py, from the VS Chamber Orchestra Community Edition
(public domain, CC0: https://github.com/sgossner/VSCO-2-CE). tools/fetch_samples.sh puts the
few folders the music uses in tools/samples/vsco (not committed: the rendered music is).

Each instrument is a folder of WAVs named by note ("MOHorn_sus_A#1_v2_1.wav"). A note is
played from the nearest recorded pitch, resampled to the one asked for, cut to length
with a short release. Drums are played as recorded. Everything is converted once to mono
32 kHz and cached in tools/samples/cache.
"""
import hashlib
import os
import re
import subprocess

import numpy as np

SR = 32000
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("BANNERFALL_SAMPLES", os.path.join(HERE, "samples", "vsco"))
CACHE = os.path.join(HERE, "samples", "cache")

NOTE = re.compile(r"(?<![A-Za-z])([A-G])(#|b)?(-?\d)(?=[_.\-]|$)")
LAYER = re.compile(r"_v(\d)")
STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def available():
    return os.path.isdir(ROOT)


def _midi(name):
    found = NOTE.findall(os.path.splitext(name)[0])
    if not found:
        return None
    letter, acc, octave = found[-1]
    return 12 * (int(octave) + 1) + STEPS[letter] + (1 if acc == "#" else -1 if acc == "b" else 0)


def load(path):
    """A sample as mono float at SR, its silent lead-in trimmed, at a common loudness."""
    os.makedirs(CACHE, exist_ok=True)
    key = hashlib.sha1(os.path.relpath(path, ROOT).encode()).hexdigest()[:16]
    cached = os.path.join(CACHE, key + ".npy")
    if os.path.exists(cached):
        return np.load(cached)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    x = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    start = int(np.argmax(np.abs(x) > peak * 0.03))
    x = x[max(0, start - int(0.004 * SR)):]
    body = x[: int(0.5 * SR)]
    x = x / (np.sqrt(np.mean(body ** 2)) + 1e-9) * 0.2
    np.save(cached, x)
    return x


class Instrument:
    """A pitched instrument: every WAV under `folder` (relative to ROOT) named by note."""

    def __init__(self, folder, layers=None, octave=12):
        # Most of the library names notes with middle C as C3, an octave below the usual
        # MIDI naming (`octave` puts that right); the harp uses C4.
        self.zones = []   # (midi, layer, path)
        base = os.path.join(ROOT, folder)
        for name in sorted(os.listdir(base)):
            if not name.lower().endswith(".wav"):
                continue
            m = _midi(name)
            if m is None:
                continue
            lm = LAYER.search(name)
            layer = int(lm.group(1)) if lm else 1
            if layers is not None and layer not in layers:
                continue
            self.zones.append((m + octave, layer, os.path.join(base, name)))
        if not self.zones:
            raise FileNotFoundError("no notes in " + base)

    def note(self, midi, dur, rng=None, release=0.25, attack=0.0, layer=None):
        zones = self.zones if layer is None else [z for z in self.zones if z[1] == layer] or self.zones
        best = min(abs(z[0] - midi) for z in zones)
        near = [z for z in zones if abs(z[0] - midi) == best]
        zone = near[int(rng.integers(len(near)))] if rng is not None and len(near) > 1 else near[0]
        x = load(zone[2])
        ratio = 2.0 ** ((midi - zone[0]) / 12.0)
        if abs(ratio - 1.0) > 1e-4:
            x = np.interp(np.arange(0, len(x) - 1, ratio), np.arange(len(x)), x)
        n = min(len(x), int((dur + release) * SR))
        out = x[:n].copy()
        rel = min(n, int(release * SR))
        if n < len(x) and rel > 0:
            out[-rel:] *= np.linspace(1.0, 0.0, rel) ** 1.5
        if attack > 0:
            k = min(n, int(attack * SR))
            out[:k] *= np.linspace(0.0, 1.0, k)
        return out


class Kit:
    """Unpitched one-shots: `pattern` picks files under `folder`; each hit is one of them,
    chosen at random, optionally retuned by `shift` semitones."""

    def __init__(self, folder, pattern=""):
        base = os.path.join(ROOT, folder)
        self.paths = [os.path.join(base, n) for n in sorted(os.listdir(base))
                      if n.lower().endswith(".wav") and re.search(pattern, n)]
        if not self.paths:
            raise FileNotFoundError("no hits matching %r in %s" % (pattern, base))

    def hit(self, rng=None, shift=0.0, length=None):
        path = self.paths[int(rng.integers(len(self.paths)))] if rng is not None else self.paths[0]
        x = load(path)
        if shift:
            x = np.interp(np.arange(0, len(x) - 1, 2.0 ** (shift / 12.0)), np.arange(len(x)), x)
        if length is not None:
            n = min(len(x), int(length * SR))
            x = x[:n].copy()
            k = min(n, int(0.05 * SR))
            x[-k:] *= np.linspace(1.0, 0.0, k)
        return x
