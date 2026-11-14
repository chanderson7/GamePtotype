#!/usr/bin/env python3
"""The score of the "Captains" trailer: "Who Carries the Banner", written for the cut.

    python3 tools/trailer2/score.py        # -> $TRAILER_OUT/score.wav (48 kHz, 70 s)

D minor, 120 beats a minute in 4/4, so a bar is two seconds and a beat fifteen frames: every
cut in cut.py lands on a beat of this. The picture's moments are the music's:

    bars  1-3    0:00  the charge in slow motion: a low D, a heartbeat, a lone horn
    bar   4      0:06  the blow: the first hit
    bars  5-8    0:08  the captains: violas turning under the horn's tune
    bars  9-10   0:16  a captain falls: everything stops but high strings and the heartbeat
    bar   11     0:20  the die lands: a bell, and nothing else
    bar   12     0:22  the rise
    bar   13     0:24  the title: the full orchestra
    bars 14-21   0:26  the battles: the tune in the brass over galloping strings and drums
    bars 22-25   0:42  the world: strings, harp and flute, at half the pace
    bars 26-29   0:50  the last charge: trumpets on top, drums at double time
    bar   30     0:58  victory: the last hit
    bars 31-35   1:00  the name: the horn alone again, and a major chord to end on

It is played by recorded instruments: the VS Chamber Orchestra Community Edition (CC0),
fetched by tools/trailer2/samples.sh into tools/samples/vsco, or wherever VSCO_DIR points.
Needs numpy, scipy and soundfile.
"""
import glob
import os
import re
import sys

import numpy as np
import soundfile as sf
from scipy.signal import butter, fftconvolve, sosfilt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VSCO = os.environ.get("VSCO_DIR", os.path.join(ROOT, "tools", "samples", "vsco"))
OUT = os.environ.get("TRAILER_OUT", "/tmp/bannerfall-trailer2")
SR = 48000
BEAT = 0.5
LENGTH = 70.0
TAIL = 3.0
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def at(bar, beat=1.0):
    """Seconds at a beat of a bar (both counted from 1)."""
    return ((bar - 1) * 4 + (beat - 1)) * BEAT


# ------------------------------------------------------------------ recorded instruments

_cache = {}


def _read(path):
    """A sample as stereo float32 at its own rate, its leading silence trimmed."""
    if path not in _cache:
        x, sr = sf.read(path, dtype="float32", always_2d=True)
        if x.shape[1] == 1:
            x = np.repeat(x, 2, axis=1)
        mono = np.abs(x).max(axis=1)
        peak = float(mono.max()) or 1.0
        start = max(0, int(np.argmax(mono > peak * 0.03)) - int(sr * 0.004))
        _cache[path] = (x[start:, :2], sr)
    return _cache[path]


def _shift(x, sr, semitones):
    """`x` at SR, played `semitones` higher (resampled, so higher is also shorter)."""
    step = (sr / SR) * 2.0 ** (semitones / 12.0)
    n = int((len(x) - 1) / step)
    pos = np.arange(n) * step
    i = pos.astype(np.int64)
    f = (pos - i)[:, None].astype(np.float32)
    return x[i] * (1.0 - f) + x[i + 1] * f


class Voice:
    """One articulation of one instrument: its samples by pitch and loudness layer.

    The library names its notes an octave below their sound (its C3 is middle C), except
    the harp; `octave` puts that right. Every sample is levelled to the same loudness, so a
    note's `dyn` (0 to 1) sets both how loud it is and which layer (soft or hard) plays it.
    """

    def __init__(self, folder, octave=1, short=False):
        self.short = short
        self.notes = {}
        self.turn = 0
        for path in sorted(glob.glob(os.path.join(VSCO, folder, "*.wav"))):
            m = re.search(r"_([A-G]#?)(\d)(?:_|\.)", os.path.basename(path))
            if not m:
                continue
            midi = 12 * (int(m.group(2)) + 1 + octave) + NOTE[m.group(1)]
            layer = re.search(r"_v(\d)", path)
            name = os.path.basename(path)
            rank = int(layer.group(1)) if layer else {"mp": 1, "mf": 2, "f": 3}.get(name.rsplit("_", 1)[-1][:-4], 2)
            self.notes.setdefault(midi, {}).setdefault(rank, []).append(path)
        if not self.notes:
            sys.exit("No samples in %s (run tools/trailer2/samples.sh, or set VSCO_DIR)" % os.path.join(VSCO, folder))
        self.pitches = sorted(self.notes)

    def sample(self, midi, dyn):
        near = min(self.pitches, key=lambda p: (abs(p - midi), p > midi))
        layers = self.notes[near]
        ranks = sorted(layers)
        takes = layers[ranks[min(len(ranks) - 1, int(dyn * len(ranks)))]]
        self.turn += 1
        x, sr = _read(takes[self.turn % len(takes)])
        key = ("level", takes[self.turn % len(takes)])
        if key not in _cache:
            body = x[: int(sr * (0.35 if self.short else 1.2))]
            _cache[key] = 0.1 / (float(np.sqrt((body ** 2).mean())) + 1e-9)
        return _shift(x, sr, midi - near) * _cache[key]


def one_shot(rel_path, gain=1.0, semitones=0.0):
    x, sr = _read(os.path.join(VSCO, rel_path))
    x = _shift(x, sr, semitones)
    return x * (gain / (float(np.abs(x).max()) + 1e-9))


# ------------------------------------------------------------------ the desk

class Track:
    def __init__(self, pan=0.0, send=0.3, gain=1.0):
        self.buf = np.zeros((int((LENGTH + TAIL) * SR), 2), dtype=np.float32)
        angle = (pan + 1.0) * np.pi / 4.0
        self.lr = np.array([np.cos(angle), np.sin(angle)], dtype=np.float32) * np.sqrt(2.0)
        self.send = send
        self.gain = gain

    def add(self, x, t):
        i = int(round(t * SR))
        if i < 0:
            x, i = x[-i:], 0
        n = min(len(x), len(self.buf) - i)
        if n > 0:
            self.buf[i:i + n] += x[:n] * self.lr


TRACKS = {}


def track(name, pan=0.0, send=0.3, gain=1.0):
    TRACKS[name] = Track(pan, send, gain)
    return TRACKS[name]


def _fade(n, rising):
    ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, max(2, n), dtype=np.float32))
    return ramp if rising else ramp[::-1]


def play(tr, voice, midi, t, dur, dyn, swell=None, attack=0.012, release=0.16):
    """A note. `swell`: (from, to) loudness across it, as fractions of `dyn`."""
    x = voice.sample(midi, dyn if swell is None else dyn * max(swell))
    if voice.short:
        x = x[: int(min(len(x), max(dur, 0.25) * SR + 0.6 * SR))].copy()
        tail = min(len(x), int(0.25 * SR))
        x[-tail:] *= _fade(tail, False)[:, None]
    else:
        x = x[: int((dur + release) * SR)].copy()
        a = min(len(x), int(attack * SR))
        x[:a] *= _fade(a, True)[:, None]
        r = min(len(x), int(release * SR))
        x[-r:] *= _fade(r, False)[:, None]
        if swell is not None:
            x *= np.linspace(swell[0], swell[1], len(x), dtype=np.float32)[:, None] / max(swell)
    tr.add(x * dyn ** 1.5, t)


def line(tr, voice, t, notes, dyn, octave=0, legato=0.07, swell=None):
    """Notes one after another: (midi or None, beats)."""
    for midi, beats in notes:
        if midi is not None:
            play(tr, voice, midi + 12 * octave, t, beats * BEAT + (legato if not voice.short else 0.0), dyn,
                 swell=swell, attack=0.05, release=0.2)
        t += beats * BEAT


def strike(tr, x, t, dyn=1.0, fade=None, cut=None):
    x = x if cut is None else x[: int(cut * SR)]
    if fade is not None:
        x = x.copy()
        n = min(len(x), int(fade * SR))
        x[-n:] *= _fade(n, False)[:, None]
    tr.add(x * dyn, t)


def rising(x, peak_at, t, secs, power=2.2, stop=0.06):
    """The `secs` of `x` that lead up to its second `peak_at`, growing, ending just shy of t."""
    a = max(0, int((peak_at - secs) * SR))
    seg = x[a: int((peak_at - stop) * SR)].copy()
    seg *= (np.linspace(0.0, 1.0, len(seg), dtype=np.float32) ** power)[:, None]
    n = int(0.02 * SR)
    seg[-n:] *= _fade(n, False)[:, None]
    return seg, t - stop - len(seg) / SR


# ------------------------------------------------------------------ the orchestra

horn, horn_s = Voice("Brass/F Horn/sus"), Voice("Brass/F Horn/stac", short=True)
trumpet, trumpet_s = Voice("Brass/Trumpet/sus"), Voice("Brass/Trumpet/stac", short=True)
bone, bone_s = Voice("Brass/Tenor Trombone/sus"), Voice("Brass/Tenor Trombone/stac", short=True)
tuba, tuba_s = Voice("Brass/Tuba/sus"), Voice("Brass/Tuba/stac", short=True)
vln, vln_s, vln_t = Voice("Strings/Violin Section/susVib"), Voice("Strings/Violin Section/Spic", short=True), Voice("Strings/Violin Section/Trem")
vla, vla_s, vla_t = Voice("Strings/Viola Section/susvib"), Voice("Strings/Viola Section/spic", short=True), Voice("Strings/Viola Section/trem")
vc, vc_s, vc_t = Voice("Strings/Cello Section/susvib"), Voice("Strings/Cello Section/spic", short=True), Voice("Strings/Cello Section/trem")
cb, cb_s = Voice("Strings/Solo Contrabass/SusVib"), Voice("Strings/Solo Contrabass/Spic", short=True)
harp = Voice("Strings/Harp", octave=0, short=True)
flute = Voice("Woodwinds/Flute/susvib")

T_HORN = track("horns", -0.25, 0.42, 1.25)
T_SOLO = track("solo horn", -0.1, 0.5, 1.3)
T_TPT = track("trumpets", 0.25, 0.38, 1.1)
T_BONE = track("trombones", 0.35, 0.36, 0.95)
T_TUBA = track("tuba", 0.2, 0.3, 0.9)
T_V1 = track("violins 1", -0.5, 0.42, 1.0)
T_V2 = track("violins 2", -0.3, 0.4, 0.9)
T_VA = track("violas", 0.15, 0.4, 0.95)
T_VC = track("cellos", 0.4, 0.38, 1.0)
T_CB = track("basses", 0.5, 0.3, 1.1)
T_HARP = track("harp", -0.45, 0.45, 0.9)
T_FL = track("flute", -0.15, 0.45, 0.6)
T_DRUM = track("drums", 0.0, 0.22, 1.0)
T_TIMP = track("timpani", 0.1, 0.3, 0.6)
T_METAL = track("metal", 0.0, 0.4, 1.0)
T_FX = track("rises", 0.0, 0.3, 1.0)
T_SUB = track("sub", 0.0, 0.0, 0.7)

P = "Percussion/"
V1 = "VSCO 1 Percussion/"
BD = [one_shot(P + "BDrumNewhit_v7_rr%d_Sum.wav" % k) for k in (1, 2)]
BD_SOFT = [one_shot(P + "BDrumNewhit_v3_rr%d_Sum.wav" % k) for k in (1, 2)]
BD_DEEP = one_shot(V1 + "drums/bass/bdrum_fff_1.wav")
TENOR_LO = [one_shot(V1 + "drums/tenor/tenor_lower/tenor_fff_%d.wav" % k) for k in (1, 2, 3, 4)]
TENOR_HI = [one_shot(V1 + "drums/tenor/tenor_higher/tenorH_fff_%d.wav" % k) for k in (1, 2, 3, 4)]
SNARE_ROLL = one_shot(P + "Snare2-rollNS_v5_rr1_Sum.wav")
CRASH = [one_shot(P + "cymbal-crash1_ff_rr%d.wav" % k) for k in (1, 2)]
SWELL = one_shot(P + "susCymb1-cresc-Long_v1.wav")      # loudest 7.2 s in
SWELL_AT = 7.2
GONG = one_shot(V1 + "varMetal/Gong/gong_hit_fff.wav")
GONG_SOFT = one_shot(P + "gongHit_mf.wav")
ANVIL = one_shot(P + "Anvil_Hit1_v3_Sum.wav")
BELL = one_shot(P + "TB_hit_C4_v4_rr1.wav", semitones=2.0)  # a D
# The five kettledrums as recorded sit near F#2, B2, C#3, E3 and F#3 (measured from their
# partials); each note here is the nearest drum, retuned.
TIMP = {38: ("Timpani1", 38 - 41.55), 45: ("Timpani2", 45 - 46.8), 50: ("Timpani3", 50 - 49.5), 43: ("Timpani1", 43 - 41.55),
        46: ("Timpani2", 46 - 46.8), 41: ("Timpani1", 41 - 41.55), 48: ("Timpani3", 48 - 49.5), 57: ("Timpani5", 57 - 54.5)}
_timp = {}


def timp(t, midi, dyn):
    drum, shift = TIMP[midi]
    layer = "v4" if dyn > 0.6 and drum != "Timpani1" else "v3"
    key = (drum, layer, midi)
    if key not in _timp:
        _timp[key] = [one_shot(P + "Timpani/%s_Hit_%s_rr%d_Sum.wav" % (drum, layer, k), semitones=shift) for k in (1, 2)]
    strike(T_TIMP, _timp[key][int(t * 8) % 2], t, dyn * 1.1, fade=1.2, cut=3.5)


TIMP_ROLL_A = one_shot(P + "Timpani/Rolls/Timpani2_Roll_v5_rr1_Sum.wav", semitones=45 - 46.8)
TIMP_ROLL_D = one_shot(P + "Timpani/Rolls/Timpani1_Roll_v5_rr1_Sum.wav", semitones=38 - 41.55)

_turn = [0]


def drum(kind, t, dyn=1.0):
    _turn[0] += 1
    k = _turn[0]
    if kind == "bd":
        strike(T_DRUM, BD[k % 2], t, dyn, fade=0.8, cut=2.6)
    elif kind == "soft":
        strike(T_DRUM, BD_SOFT[k % 2], t, dyn, fade=0.6, cut=1.6)
    elif kind == "lo":
        strike(T_DRUM, TENOR_LO[k % 4], t, dyn * 0.8)
    elif kind == "hi":
        strike(T_DRUM, TENOR_HI[k % 4], t, dyn * 0.6)


def boom(t, dyn=1.0):
    """What a hit leaves below the orchestra: a sine falling from 70 Hz to 38."""
    n = int(1.6 * SR)
    s = np.arange(n, dtype=np.float32) / SR
    freq = 38.0 + 32.0 * np.exp(-s / 0.07)
    wave = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-s / 0.42)
    wave[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR), dtype=np.float32)
    T_SUB.add(np.repeat((wave * 0.5 * dyn)[:, None], 2, axis=1).astype(np.float32), t)


def hit(t, dyn=1.0, bell=False, ring=6.0):
    """The whole battery on one beat."""
    drum("bd", t, dyn)
    strike(T_DRUM, BD_DEEP, t, 0.9 * dyn, fade=1.5, cut=4.0)
    strike(T_METAL, GONG, t - 0.35, 0.5 * dyn, fade=ring * 0.7, cut=ring)
    strike(T_METAL, CRASH[int(t) % 2], t, 0.55 * dyn, fade=2.5, cut=5.0)
    timp(t, 38, dyn)
    boom(t, dyn)
    if bell:
        strike(T_METAL, BELL, t, 0.5 * dyn, fade=4.0, cut=7.0)


def rise(t, secs, dyn=1.0, snare=True):
    """Everything that climbs to a hit at `t`: cymbal, snare and kettledrum rolls."""
    x, start = rising(SWELL, SWELL_AT, t, min(secs, 6.5))
    T_FX.add(x * 0.75 * dyn, start)
    if snare:
        x, start = rising(SNARE_ROLL, min(6.5, secs + 0.3), t, secs, power=2.6)
        T_FX.add(x * 0.5 * dyn, start)
    x, start = rising(TIMP_ROLL_A, secs + 2.0, t, secs, power=2.0)
    T_TIMP.add(x * 0.9 * dyn, start)


# ------------------------------------------------------------------ the tune and its harmony

D2, A2, D3, A3, D4, A4, D5 = 38, 45, 50, 57, 62, 69, 74
# The tune, at the trumpets' pitch: two four-bar halves.
FIRST = [(69, 3), (74, 1), (74, 2), (72, 1), (70, 1), (69, 3), (65, 1), (67, 2), (64, 1), (67, 1)]
SECOND = [(69, 3), (74, 1), (77, 2), (76, 1), (74, 1), (74, 2), (70, 1), (74, 1), (76, 4)]
# Per chord: bass, the cellos', violas' and second violins' driving notes, the trombones' pair.
CHORD = {
    "Dm": {"bass": 38, "vc": 50, "va": 57, "v2": 65, "pad": (50, 57), "timp": 38},
    "Bb": {"bass": 34, "vc": 46, "va": 53, "v2": 62, "pad": (46, 53), "timp": 46},
    "F": {"bass": 41, "vc": 53, "va": 60, "v2": 69, "pad": (53, 60), "timp": 41},
    "C": {"bass": 36, "vc": 48, "va": 55, "v2": 64, "pad": (48, 55), "timp": 48},
    "Gm": {"bass": 31, "vc": 43, "va": 50, "v2": 58, "pad": (43, 50), "timp": 43},
    "A": {"bass": 33, "vc": 45, "va": 52, "v2": 61, "pad": (45, 52), "timp": 45},
}
GALLOP = [(0.0, 1.0), (0.25, 0.62), (0.375, 0.74)]  # an eighth and two sixteenths to the beat


def gallop(bar, chord, dyn, high=False):
    c = CHORD[chord]
    for beat in range(4):
        t0 = at(bar, beat + 1)
        lift = 1.0 if beat in (0, 2) else 0.86
        for off, weight in GALLOP:
            d = dyn * weight * lift
            play(T_VC, vc_s, c["vc"], t0 + off, 0.2, d)
            play(T_VA, vla_s, c["va"], t0 + off, 0.2, d * 0.95)
            play(T_V2, vln_s, c["v2"], t0 + off, 0.2, d * 0.9)
            if high:
                play(T_V1, vln_s, c["v2"] + 12, t0 + off, 0.2, d * 0.8)
        play(T_CB, cb_s, c["bass"] + (12 if c["bass"] < 30 else 0), t0, 0.3, dyn * lift)
        if beat in (0, 2):
            play(T_TUBA, tuba_s, c["bass"] + (12 if c["bass"] < 34 else 0), t0, 0.3, dyn * 0.9)


def pad(bar, chord, dyn, bars=1):
    c = CHORD[chord]
    for midi in c["pad"]:
        play(T_BONE, bone, midi, at(bar), bars * 2.0 - 0.05, dyn, attack=0.03, release=0.12)
    play(T_TUBA, tuba, c["bass"] + (12 if c["bass"] < 34 else 0), at(bar), bars * 2.0 - 0.05, dyn * 0.8, attack=0.03, release=0.12)


def war_drums(bar, dyn, double=False):
    for beat, kind, weight in [(1, "bd", 1.0), (2, "lo", 0.7), (2.5, "hi", 0.6), (3, "bd", 0.9), (3.5, "hi", 0.6),
                               (4, "lo", 0.8), (4.5, "hi", 0.7), (4.75, "hi", 0.8)]:
        drum(kind, at(bar, beat), dyn * weight)
    if double:
        for eighth in range(8):
            drum("lo" if eighth % 2 == 0 else "hi", at(bar, 1 + eighth * 0.5), dyn * (0.75 if eighth % 2 == 0 else 0.5))
        for beat in (2, 4):
            drum("bd", at(bar, beat), dyn * 0.75)
            strike(T_METAL, ANVIL, at(bar, beat), 0.28 * dyn, cut=1.2, fade=0.4)


def heartbeat(bar, dyn, twice=False):
    for beat in ([1, 1.75, 3, 3.75] if twice else [1, 1.75]):
        drum("soft", at(bar, beat), dyn * (1.0 if beat == int(beat) else 0.7))


# ------------------------------------------------------------------ the piece

def cold_open():
    """Bars 1-3: a low D under slow-motion riders, a heartbeat, and the horn's first call."""
    play(T_CB, cb, D2, 0.0, 6.0, 0.55, swell=(0.5, 1.0), attack=0.8, release=0.1)
    for midi in (D2, A2):
        play(T_VC, vc_t, midi, 0.2, 5.75, 0.6, swell=(0.25, 1.0), attack=1.0, release=0.05)
    play(T_VA, vla_t, D4, 2.0, 3.95, 0.5, swell=(0.2, 1.0), attack=1.0, release=0.05)
    for bar in (1, 2, 3):
        heartbeat(bar, 0.5 + 0.12 * bar)
    line(T_SOLO, horn, at(2), [(57, 3), (62, 1), (62, 1.5), (60, 0.5), (58, 1.8)], 0.62)
    rise(6.0, 2.2, 0.8, snare=False)


def blow():
    """Bar 4: the charge strikes."""
    hit(6.0, 1.0)
    for midi, v in [(38, bone_s), (45, bone_s), (50, horn_s), (57, horn_s), (38, tuba_s)]:
        play(T_BONE if v is bone_s else (T_HORN if v is horn_s else T_TUBA), v, midi, 6.0, 0.5, 0.95)
    for tr, v, notes in [(T_VC, vc_t, (38, 45)), (T_VA, vla_t, (50, 57)), (T_V2, vln_t, (62, 65)), (T_V1, vln_t, (69, 74))]:
        for midi in notes:
            play(tr, v, midi, 6.0, 1.9, 0.8, swell=(1.0, 0.55), attack=0.01, release=0.08)
    play(T_CB, cb, D2, 6.0, 1.9, 0.8, release=0.08)
    for beat, kind, w in [(2.5, "lo", 0.8), (3, "bd", 0.85), (3.5, "lo", 0.7), (4, "bd", 0.9), (4.5, "lo", 0.9), (4.75, "hi", 0.9)]:
        drum(kind, at(4, beat), w)
    timp(at(4, 3), 38, 0.8)
    timp(at(4, 4.5), 45, 0.8)


def captains():
    """Bars 5-8: names and faces, then the fire. Violas turn; the horn sings the tune."""
    turns = {"Dm": [50, 57, 62, 57, 53, 57, 62, 57], "Bb": [50, 58, 62, 58, 53, 58, 62, 58],
             "F": [48, 57, 60, 57, 53, 57, 60, 57], "C": [48, 55, 60, 55, 52, 55, 60, 55]}
    for i, chord in enumerate(["Dm", "Bb", "F", "C"]):
        bar = 5 + i
        for k, midi in enumerate(turns[chord]):
            accent = 0.5 if k % 4 == 0 else 0.38
            play(T_VA, vla_s, midi, at(bar, 1 + k * 0.5), 0.2, accent + 0.03 * i)
            if bar >= 7:
                play(T_VC, vc_s, midi - 12, at(bar, 1 + k * 0.5), 0.2, accent * 0.8)
        play(T_CB, cb, CHORD[chord]["bass"], at(bar), 1.95, 0.5, attack=0.08)
        drum("soft", at(bar), 0.4)
    line(T_SOLO, horn, at(5), FIRST, 0.6, octave=-1)
    # The fire: violins above, a harp spreading each chord.
    for bar, pair, spread in [(7, (69, 72), [41, 48, 53, 57, 60, 65, 69, 72]), (8, (67, 72), [36, 43, 48, 52, 55, 60, 64, 67])]:
        for midi in pair:
            play(T_V1, vln, midi, at(bar), 1.95, 0.38, attack=0.3, release=0.25)
        for k, midi in enumerate(spread):
            play(T_HARP, harp, midi, at(bar, 1 + k * 0.5), 1.5, 0.5)


def the_fall():
    """Bars 9-12: the music holds its breath, the die lands on a bell, then the rise."""
    # Bar 9 (G minor) and bar 10 (A): low strings step up under a high tremolo.
    for bar, bass, low, mid, high in [(9, 31, 43, 70, (74, 82)), (10, 33, 45, 73, (76, 81))]:
        grow = (0.5, 0.75) if bar == 9 else (0.75, 1.0)
        play(T_CB, cb, bass + 12, at(bar), 1.98, 0.6, swell=grow, attack=0.15, release=0.03)
        play(T_VC, vc, low, at(bar), 1.98, 0.6, swell=grow, attack=0.15, release=0.03)
        play(T_VA, vla_t, mid, at(bar), 1.98, 0.5, swell=grow, attack=0.2, release=0.03)
        for midi in high:
            play(T_V1, vln_t, midi, at(bar), 1.98, 0.45, swell=grow, attack=0.3, release=0.03)
        heartbeat(bar, 0.6 + 0.15 * (bar - 9), twice=bar == 10)
    x, start = rising(TIMP_ROLL_A, 3.0, at(11), 1.2, power=2.0, stop=0.03)
    T_TIMP.add(x * 0.6, start)
    # Bar 11: the die lands. One bell, and the room.
    strike(T_METAL, BELL, at(11), 0.85, fade=5.0, cut=8.0)
    strike(T_METAL, GONG_SOFT, at(11), 0.22, fade=4.0, cut=6.0)
    drum("soft", at(11), 0.8)
    boom(at(11), 0.5)
    # Bar 12: out of the silence, the rise to the title, on A.
    play(T_CB, cb, 45, at(11, 3), 2.9, 0.7, swell=(0.2, 1.0), attack=0.6, release=0.02)
    for tr, v, midi in [(T_VC, vc_t, 45), (T_VA, vla_t, 64), (T_V2, vln_t, 69), (T_V1, vln_t, 73), (T_V1, vln_t, 76)]:
        play(tr, v, midi, at(12), 1.93, 0.85, swell=(0.15, 1.0), attack=0.3, release=0.02)
    for tr, v, midi in [(T_BONE, bone, 45), (T_BONE, bone, 52), (T_HORN, horn, 57), (T_HORN, horn, 61), (T_TPT, trumpet, 64)]:
        play(tr, v, midi, at(12), 1.93, 0.85, swell=(0.1, 1.0), attack=0.4, release=0.02)
    rise(at(13), 2.0, 1.0)
    for k in range(4):
        drum("lo", at(12, 1 + k * 0.5), 0.3 + 0.08 * k)
    for k in range(8):
        drum("lo" if k % 2 == 0 else "hi", at(12, 3 + k * 0.25) - (0.06 if k == 7 else 0.0), 0.6 + 0.05 * k)


def title():
    """Bar 13: the name, on the full orchestra."""
    hit(at(13), 1.15, bell=True)
    strike(T_METAL, ANVIL, at(13), 0.35, cut=1.5, fade=0.5)
    for tr, v, notes, d in [(T_TUBA, tuba, (38,), 0.9), (T_BONE, bone, (38, 45, 50), 0.95), (T_HORN, horn, (50, 53, 57), 0.95),
                            (T_TPT, trumpet, (62, 69), 0.85), (T_VC, vc, (38, 45), 0.9), (T_VA, vla, (53, 57), 0.9),
                            (T_V2, vln, (62, 65), 0.9), (T_V1, vln, (69, 74), 0.9), (T_CB, cb, (38,), 0.9)]:
        for midi in notes:
            play(tr, v, midi, at(13), 1.9, d, swell=(1.0, 0.7), attack=0.008, release=0.1)
    for beat, kind, w in [(3, "lo", 0.7), (3.5, "lo", 0.75), (4, "bd", 0.85), (4.25, "hi", 0.8), (4.5, "lo", 0.9), (4.75, "hi", 1.0)]:
        drum(kind, at(13, beat), w)
    timp(at(13, 4), 45, 0.85)
    timp(at(13, 4.5), 45, 0.95)


def battles():
    """Bars 14-21: the tune, whole, in the brass over galloping strings and the drums."""
    chords = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    for i, chord in enumerate(chords):
        bar = 14 + i
        second = i >= 4
        gallop(bar, chord, 0.82 if not second else 0.92, high=second)
        pad(bar, chord, 0.6 if not second else 0.72)
        war_drums(bar, 0.85 if not second else 0.95)
        timp(at(bar), CHORD[chord]["timp"], 0.85)
        timp(at(bar, 3), CHORD[chord]["timp"], 0.6)
    for bar in (14, 18):
        strike(T_METAL, CRASH[bar % 2], at(bar), 0.5, fade=2.5, cut=5.0)
        boom(at(bar), 0.8)
        strike(T_DRUM, BD_DEEP, at(bar), 0.7, fade=1.5, cut=3.5)
    line(T_HORN, horn, at(14), FIRST, 0.92, octave=-1)
    line(T_BONE, bone, at(14), FIRST, 0.7, octave=-2)
    line(T_HORN, horn, at(18), SECOND, 0.97, octave=-1)
    line(T_BONE, bone, at(18), SECOND, 0.85, octave=-1)
    line(T_TPT, trumpet, at(18), SECOND, 0.85)
    line(T_V1, vln, at(18), SECOND, 0.8)
    # Bar 21 leans into the bar after it.
    x, start = rising(SWELL, SWELL_AT, at(22), 1.6, stop=0.02)
    T_FX.add(x * 0.5, start)
    for k in range(4):
        drum("lo", at(21, 4 + k * 0.25), 0.7 + 0.08 * k)


def the_world():
    """Bars 22-25: the Glass Sea. Half the pace: strings, harp, a flute; then the last rise."""
    drum("bd", at(22), 0.9)
    strike(T_METAL, CRASH[0], at(22), 0.35, fade=3.0, cut=5.0)
    boom(at(22), 0.6)
    timp(at(22), 46, 0.8)
    song = [(77, 3), (74, 1), (72, 3), (69, 1), (70, 2), (74, 2), (73, 2), (76, 2)]
    line(T_V1, vln, at(22), song, 0.78, legato=0.12)
    line(T_FL, flute, at(22), song, 0.6, octave=1, legato=0.1)
    plan = [("Bb", 62, [46, 53, 58, 62, 65, 70, 74, 77], 53), ("F", 60, [41, 48, 53, 57, 60, 65, 69, 72], 57),
            ("Gm", 58, [43, 50, 55, 58, 62, 67, 70, 74], 55), ("A", 61, [45, 52, 57, 61, 64, 69, 73, 76], 57)]
    for i, (chord, third, spread, inner) in enumerate(plan):
        bar = 22 + i
        c = CHORD[chord]
        grow = (1.0, 1.0) if bar < 25 else (0.8, 1.3)
        play(T_VA, vla, third, at(bar), 1.97, 0.62, swell=grow, attack=0.1, release=0.15)
        for midi in c["pad"]:
            play(T_VC, vc, midi, at(bar), 1.97, 0.62, swell=grow, attack=0.1, release=0.15)
        play(T_CB, cb, c["bass"] + (12 if c["bass"] < 30 else 0), at(bar), 1.97, 0.7, attack=0.08, release=0.15)
        play(T_HORN, horn, inner, at(bar), 1.97, 0.45, swell=grow, attack=0.2, release=0.2)
        for k, midi in enumerate(spread):
            play(T_HARP, harp, midi, at(bar, 1 + k * 0.5), 1.5, 0.62)
        if bar > 22:
            drum("soft", at(bar), 0.75)
            timp(at(bar), c["timp"], 0.55)
    for tr, v, midi in [(T_BONE, bone, 45), (T_BONE, bone, 52), (T_TPT, trumpet, 64), (T_TPT, trumpet, 69)]:
        play(tr, v, midi, at(25, 2), 1.42, 0.85, swell=(0.1, 1.0), attack=0.3, release=0.02)
    rise(at(26), 2.0, 1.0)
    for k in range(8):
        drum("lo" if k % 2 == 0 else "hi", at(25, 3 + k * 0.25) - (0.06 if k == 7 else 0.0), 0.55 + 0.06 * k)


def last_charge():
    """Bars 26-29: everything. The tune's second half with trumpets on top, drums doubled."""
    for i, chord in enumerate(["Dm", "Bb", "Gm", "A"]):
        bar = 26 + i
        gallop(bar, chord, 1.0, high=True)
        pad(bar, chord, 0.8)
        war_drums(bar, 1.0, double=True)
        timp(at(bar), CHORD[chord]["timp"], 0.95)
        timp(at(bar, 3), CHORD[chord]["timp"], 0.75)
        timp(at(bar, 4.5), CHORD[chord]["timp"], 0.7)
    for bar in (26, 28):
        strike(T_METAL, CRASH[bar % 2], at(bar), 0.6, fade=2.5, cut=5.0)
        boom(at(bar), 1.0)
        strike(T_DRUM, BD_DEEP, at(bar), 0.85, fade=1.5, cut=3.5)
    strike(T_METAL, GONG, at(26) - 0.35, 0.4, fade=3.0, cut=5.0)
    line(T_TPT, trumpet, at(26), SECOND, 0.97)
    line(T_HORN, horn, at(26), SECOND, 1.0, octave=-1)
    line(T_BONE, bone, at(26), SECOND, 0.9, octave=-1)
    line(T_V1, vln, at(26), SECOND, 0.85, octave=1)
    line(T_FL, flute, at(26), SECOND, 0.7, octave=1)
    # Into the last hit: four struck together, and a breath.
    for k, beat in enumerate([4, 4.25, 4.5, 4.75]):
        for tr, v, midi in [(T_BONE, bone_s, 45), (T_HORN, horn_s, 57), (T_TPT, trumpet_s, 69), (T_TUBA, tuba_s, 45)]:
            play(tr, v, midi, at(29, beat) - (0.05 if k == 3 else 0.0), 0.2, 0.8 + 0.05 * k)
    x, start = rising(SWELL, SWELL_AT, at(30), 1.4)
    T_FX.add(x * 0.6, start)


def victory_and_the_name():
    """Bar 30: the last hit. Bars 31-35: it rings away, and the horn is alone again."""
    t = at(30)
    hit(t, 1.25, bell=True, ring=9.0)
    strike(T_METAL, ANVIL, t, 0.4, cut=1.5, fade=0.5)
    for tr, v, notes, d in [(T_TUBA, tuba, (38,), 0.95), (T_BONE, bone, (38, 45, 50), 1.0), (T_HORN, horn, (50, 57, 62), 1.0),
                            (T_TPT, trumpet, (62, 69, 74), 0.9)]:
        for midi in notes:
            play(tr, v, midi, t, 3.2, d, swell=(1.0, 0.15), attack=0.008, release=0.6)
    for tr, v, notes in [(T_CB, cb, (38,)), (T_VC, vc, (38, 45, 50)), (T_VA, vla, (57, 62)), (T_V2, vln, (65, 69)), (T_V1, vln, (74, 81))]:
        for midi in notes:
            play(tr, v, midi, t, 5.6, 0.92, swell=(1.0, 0.12), attack=0.008, release=0.9)
    timp(t + 1.0, 38, 0.5)
    timp(t + 2.0, 38, 0.3)
    # Bars 32-33: the call that opened it, over D then B flat.
    line(T_SOLO, horn, at(32), [(57, 3), (62, 1), (62, 2), (60, 1), (58, 1), (57, 3.6)], 0.6, legato=0.12)
    play(T_CB, cb, 38, at(32), 1.95, 0.45, attack=0.3, release=0.2)
    for midi in (50, 57):
        play(T_VC, vc, midi, at(32), 1.95, 0.42, attack=0.4, release=0.3)
    play(T_CB, cb, 34 + 12, at(33), 1.95, 0.45, attack=0.2, release=0.2)
    for tr, v, midi in [(T_VC, vc, 46), (T_VC, vc, 53), (T_VA, vla, 62)]:
        play(tr, v, midi, at(33), 1.95, 0.45, attack=0.3, release=0.3)
    # Bar 34 on: D major, a harp spread up through it, and out.
    for tr, v, midi in [(T_CB, cb, 38), (T_VC, vc, 50), (T_VC, vc, 57), (T_VA, vla, 66), (T_V2, vln, 69), (T_V1, vln, 74)]:
        play(tr, v, midi, at(34), 3.4, 0.5, swell=(0.7, 1.0), attack=0.5, release=1.6)
    for k, midi in enumerate([38, 45, 50, 54, 57, 62, 66, 69, 74, 78]):
        play(T_HARP, harp, midi, at(34) + 0.11 * k, 3.0, 0.62)
    strike(T_METAL, BELL, at(34), 0.22, fade=3.5, cut=5.5)


# ------------------------------------------------------------------ the room and the master

def hall(secs=2.6):
    """A hall's reply to a clap: noise dying away, the top of it sooner, a little wider than it is long."""
    rng = np.random.default_rng(11)
    n = int(secs * SR)
    s = np.arange(n) / SR
    out = []
    for _ in range(2):
        dark = sosfilt(butter(2, 2600, "low", fs=SR, output="sos"), rng.standard_normal(n)) * np.exp(-s / 0.55) * 2.2
        bright = sosfilt(butter(2, [1800, 9000], "band", fs=SR, output="sos"), rng.standard_normal(n)) * np.exp(-s / 0.3)
        tap = dark + bright
        tap[: int(0.018 * SR)] = 0.0
        out.append(tap)
    ir = np.stack(out, axis=1).astype(np.float32)
    return ir / np.sqrt((ir ** 2).sum(axis=0).max())


def master():
    dry = sum(t.buf * t.gain for t in TRACKS.values())
    wet_in = sum(t.buf * (t.gain * t.send) for t in TRACKS.values() if t.send > 0)
    ir = hall()
    wet = np.stack([fftconvolve(wet_in[:, c], ir[:, c])[: len(dry)] for c in range(2)], axis=1)
    mix = dry + wet * 0.9
    mix = sosfilt(butter(2, 26, "high", fs=SR, output="sos"), mix, axis=0)
    # A hand on the fader, as a trailer is mixed: the quiet scenes come up toward the loud
    # ones (a phone's speaker has little room between them), and drop back at each hit.
    ride = [(0.0, 4.0), (5.9, 4.0), (6.0, 0.0), (7.9, 0.0), (8.0, 4.5), (15.9, 4.5), (16.0, 3.0), (19.95, 3.0), (20.0, 2.0),
            (22.0, 2.0), (24.0, 0.0), (42.0, 0.0), (42.3, 1.5), (48.5, 1.5), (50.0, 0.0), (60.5, 0.0), (62.0, 4.0), (LENGTH + TAIL, 4.0)]
    when = np.arange(len(mix)) / SR
    mix = mix * (10.0 ** (np.interp(when, [a for a, _ in ride], [b for _, b in ride]) / 20.0))[:, None].astype(np.float32)
    # Level so the loud bars sit just under full scale, then round the few peaks over it.
    level = np.percentile(np.abs(mix), 99.9)
    mix = mix * (0.7 / level)
    over = np.abs(mix) > 0.7
    mix[over] = np.sign(mix[over]) * (0.7 + 0.25 * np.tanh((np.abs(mix[over]) - 0.7) / 0.25))
    end = int(LENGTH * SR)
    mix = mix[:end]
    n = int(0.6 * SR)
    mix[-n:] *= _fade(n, False)[:, None]
    return mix.astype(np.float32)


def main():
    for part in (cold_open, blow, captains, the_fall, title, battles, the_world, last_charge, victory_and_the_name):
        part()
    mix = master()
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "score.wav")
    sf.write(path, mix, SR, subtype="PCM_24")
    print("wrote %s (%.1f s, peak %.2f)" % (path, len(mix) / SR, float(np.abs(mix).max())))
    if "--stems" in sys.argv:
        for name, t in TRACKS.items():
            sf.write(os.path.join(OUT, "stem_%s.wav" % name.replace(" ", "_")), t.buf[: int(LENGTH * SR)] * t.gain, SR, subtype="PCM_16")


if __name__ == "__main__":
    main()
