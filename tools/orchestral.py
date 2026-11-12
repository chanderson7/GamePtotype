"""The orchestral pieces: Home (The Glass Sea and the campfire versions), the battle music
in layers, the battle's aftermath and its stingers. Recorded instruments (tools/sampler.py)
carry the orchestra; the synthesized oud, ney, koto and shakuhachi from music.py keep each
realm's own voice.

The battle music is a set of loops of exactly the same length, played together in the
game and faded by what's happening:
  deploy_<realm>    before the lines meet: drones, a heartbeat drum, a call to arms
  base_<realm>      always on once fighting: drums and a driving string ostinato, written to
                    carry on a phone speaker (no part leans on the deep bass alone)
  high_<realm>      the tune, faded in as more of the field is fighting
  turn_win          a bright fanfare layer when the fight is going your way
  turn_lose         low tremolo and dark horns when your lines waver
Realms: vardish, kharzani, ryumon, and siege (a heavier, half-time version for assaults).
All share one chord progression, so the two turn layers fit over any of them.
"""
import numpy as np

import sampler as S
from music import (SR, Track, band, drum, hz, master, pluck, reverb, rng_for, wind)

# ------------------------------------------------------------------ instruments

_SPECS = {
    "horn": ("Brass/F Horn/sus", [3, 4], 12),
    "horn_soft": ("Brass/F Horn/sus", [1, 2], 12),
    "horn_stac": ("Brass/F Horn/stac", [2, 3], 12),
    "trumpet": ("Brass/Trumpet/sus", [3], 12),
    "trumpet_stac": ("Brass/Trumpet/stac", [2, 3], 12),
    "trombone": ("Brass/Tenor Trombone/sus", [2, 3], 12),
    "violins": ("Strings/Violin Section/susVib", [2], 12),
    "violins_soft": ("Strings/Violin Section/susVib", [1], 12),
    "violins_trem": ("Strings/Violin Section/Trem", [2], 12),
    "violins_spic": ("Strings/Violin Section/Spic", [2], 12),
    "violas": ("Strings/Viola Section/susvib", None, 12),
    "cellos": ("Strings/Cello Section/susvib", None, 12),
    "cellos_spic": ("Strings/Cello Section/spic", [2], 12),
    "cellos_trem": ("Strings/Cello Section/trem", None, 12),
    "harp": ("Strings/Harp", None, 0),
    "flute": ("Woodwinds/Flute/susvib", None, 12),
    "glock": ("Percussion/Glock", None, 12),
}
_KITS = {
    "snare": ("Percussion", r"Snare2-HitSN_v[579]_"),
    "snare_ghost": ("Percussion", r"Snare2-HitSN_v[13]_"),
    "snare_roll": ("Percussion", r"Snare2-rollSN_v[35]_"),
    "bass": ("Percussion", r"BDrumNewhit_v[567]_"),
    "tenor": ("VSCO 1 Percussion/drums/tenor/tenor_lower", r"_f+_"),
    "tenor_hi": ("VSCO 1 Percussion/drums/tenor/tenor_higher", r"_f+_"),
    "crash": ("Percussion", r"cymbal-crash1_(mf|ff)_"),
    "swell": ("Percussion", r"susCymb1-cresc-Median"),
    "gong": ("Percussion", r"gongHit_f\."),
    "tamb": ("Percussion", r"Tamb1-Hit"),
}
# The timpani are recorded drum by drum, not by note: each drum's pitch, measured.
_TIMPANI = {1: 41.5, 2: 53.7, 3: 56.4, 4: 59.1, 5: 61.4}
_loaded = {}


def inst(name):
    if name not in _loaded:
        folder, layers, octave = _SPECS[name]
        _loaded[name] = S.Instrument(folder, layers, octave)
    return _loaded[name]


def kit(name):
    if name not in _loaded:
        _loaded[name] = S.Kit(*_KITS[name])
    return _loaded[name]


def timpani(midi, rng, roll=False, length=None):
    drum_no = min(_TIMPANI, key=lambda k: abs(_TIMPANI[k] - midi))
    key = ("timp_roll" if roll else "timp") + str(drum_no)
    if key not in _loaded:
        folder = "Percussion/Timpani/Rolls" if roll else "Percussion/Timpani"
        pattern = r"Timpani%d_Roll" % drum_no if roll else r"Timpani%d_Hit_v[34]" % drum_no
        _loaded[key] = S.Kit(folder, pattern)
    return _loaded[key].hit(rng, shift=midi - _TIMPANI[drum_no], length=length)


# ------------------------------------------------------------------ writing helpers

CHORDS = {
    "Dm": [50, 53, 57], "Bb": [46, 50, 53], "C": [48, 52, 55], "A": [45, 49, 52], "F": [41, 45, 48],
    "Gm": [43, 46, 50], "D": [50, 54, 57], "G": [43, 47, 50], "Bm": [47, 50, 54], "Em": [40, 43, 47],
}


def put(tr, name, midi, at, dur, gain, pan, rng, release=0.3, attack=0.0):
    tr.add(inst(name).note(midi, dur, rng, release=release, attack=attack), at, gain, pan)


def held(tr, name, midi, at, dur, gain, pan, rng, attack=0.4):
    """A note held longer than its recording: overlapping notes, each faded in."""
    seg = 4.0
    t = 0.0
    while t < dur - 0.01:
        part = min(seg + 0.5, dur - t + 0.5)
        tr.add(inst(name).note(midi, part, rng, release=0.6, attack=attack if t == 0 else 0.6), at + t, gain, pan)
        t += seg


def strike(tr, name, at, gain, pan, rng, shift=0.0, length=None):
    tr.add(kit(name).hit(rng, shift=shift, length=length), at, gain, pan)


def melody(tr, name, line, start, beat, gain, pan, rng, transpose=0, legato=0.95, release=0.25):
    t = start
    for midi, beats in line:
        if midi is not None:
            put(tr, name, midi + transpose, t, beats * beat * legato, gain, pan, rng, release=release)
        t += beats * beat
    return t


def synth_line(tr, voice, line, start, beat, gain, pan, rng, transpose=0):
    t = start
    for midi, beats in line:
        if midi is not None:
            tr.add(voice(hz(midi + transpose), beats * beat, rng), t, gain, pan)
        t += beats * beat
    return t


def render(name, length, score, wet=0.26, verb=2.2, loudness=-16.0):
    """Like music.render_loop: three passes, the middle one kept, so the loop is seamless."""
    track = Track(length * 3 + verb)
    for k in range(3):
        score(track, length * k)
    buf = reverb(track.buf, verb, wet, seed=len(name))
    return master(buf[:, int(length * SR): int(length * SR) * 2], loudness=loudness)


def render_once(length, score, wet=0.25, verb=2.2, tail=1.8, loudness=-15.0):
    track = Track(length + verb + tail)
    score(track, 0.0)
    buf = reverb(track.buf, verb, wet)[:, : int((length + tail) * SR)]
    k = int(0.8 * SR)
    buf[:, -k:] *= np.linspace(1.0, 0.0, k)
    # The stingers land on a cymbal and timpani, whose transients overshoot once encoded:
    # more headroom than the loops need (the game plays them a little louder anyway).
    return master(buf, loudness=loudness, ceiling=0.7)


# Synthesized voices for the realms' own instruments (from music.py's building blocks).
def ney(f, s, r):
    return wind(f, s * 0.97, breath=0.35, vib=0.007, vib_rate=4.6, bend=-0.6, attack=0.1,
                harm=(1.0, 0.3, 0.12, 0.05), rng=r)


def zurna(f, s, r):
    """The shawm of the Kharzani war bands: reedy and bright, cutting over the drums."""
    return wind(f, s * 0.94, breath=0.18, vib=0.006, vib_rate=5.5, bend=-0.4, attack=0.03,
                harm=(1.0, 0.75, 0.6, 0.45, 0.3, 0.2), rng=r)


def shakuhachi(f, s, r):
    return wind(f, s * 0.95, breath=0.4, vib=0.009, vib_rate=4.2, bend=-1.0, attack=0.16,
                harm=(1.0, 0.18, 0.06, 0.02), rng=r)


def oud(f, s, r):
    return pluck(f, s + 1.0, bright=0.45, decay=0.8, glide=-0.012, rng=r)


def koto(f, s, r):
    return pluck(f, max(s, 0.3) + 2.2, bright=0.72, decay=1.6, inharm=0.0006, rng=r)


def lute(f, s, r):
    return pluck(f, max(s, 0.3) + 1.6, bright=0.55, decay=1.1, rng=r)


def clap(rng):
    n = int(0.08 * SR)
    c = band(rng.standard_normal(n), 1200, 4000) * np.exp(-np.arange(n) / SR / 0.015)
    return c / (np.max(np.abs(c)) + 1e-9) * 0.35


# ------------------------------------------------------------------ battle

BATTLE_BPM = 120
BEAT = 60.0 / BATTLE_BPM
BAR = BEAT * 4
# Four sections of eight bars: the theme, its answer, a breakdown, the climax.
PROG = ["Dm", "Dm", "Bb", "Bb", "C", "C", "A", "A",
        "Dm", "F", "C", "Gm", "Dm", "Bb", "Gm", "A",
        "Bb", "Bb", "Gm", "Gm", "Dm", "Dm", "A", "A",
        "Dm", "Bb", "F", "C", "Gm", "Bb", "A", "A"]
BATTLE_LENGTH = BAR * len(PROG)
THEME_A = [(62, 1.5), (64, 0.5), (65, 1), (69, 1), (74, 3), (72, 1), (70, 1.5), (69, 0.5), (65, 1), (62, 1), (65, 4),
           (64, 1.5), (65, 0.5), (67, 1), (72, 1), (76, 3), (74, 1), (73, 2), (69, 2), (64, 2), (69, 2)]
THEME_B = [(69, 1.5), (69, 0.5), (74, 1), (77, 1), (81, 3), (79, 1), (79, 1.5), (77, 0.5), (76, 1), (72, 1), (74, 4),
           (77, 1.5), (76, 0.5), (74, 1), (69, 1), (70, 2), (74, 2), (79, 1.5), (77, 0.5), (74, 1), (70, 1), (73, 4)]
THEME_C = [(74, 8), (70, 8), (69, 8), (73, 8)]
THEME_D = [(74, 1.5), (76, 0.5), (77, 1), (81, 1), (82, 3), (81, 1), (81, 1.5), (79, 0.5), (77, 1), (72, 1), (76, 4),
           (79, 1.5), (77, 0.5), (74, 1), (70, 1), (77, 2), (74, 2), (76, 2), (73, 2), (69, 4)]
REALMS = ("vardish", "kharzani", "ryumon", "siege")


def _bass_root(chord):
    r = CHORDS[chord][0]
    return r + 12 if r < 45 else r   # keep the ostinato at A2 and above, where a phone still hears it


def battle_base(realm):
    def score(tr, off):
        rng = rng_for("base_" + realm)
        for i, ch in enumerate(PROG):
            t0 = off + i * BAR
            sec, k = divmod(i, 8)
            root = _bass_root(ch)
            breakdown = sec == 2 and k < 4
            # The ostinato: spiccato cellos in eighths, violas an octave up in the second
            # and last sections. Siege: half as busy, with low trombones under it.
            if not breakdown:
                pattern = [0, 0, 7, 0, 12, 0, 7, 0] if realm != "siege" else [0, None, 0, None, 7, None, 0, 12]
                for j, iv in enumerate(pattern):
                    if iv is None:
                        continue
                    accent = j in (0, 4)
                    put(tr, "cellos_spic", root + iv, t0 + j * BEAT / 2, BEAT * 0.42, 0.55 if accent else 0.38,
                        -0.25, rng, release=0.08)
                    if sec in (1, 3):
                        put(tr, "violins_spic", root + 12 + iv, t0 + j * BEAT / 2, BEAT * 0.4, 0.22 if accent else 0.15,
                            0.25, rng, release=0.06)
            if realm == "siege" and k % 2 == 0 and sec != 2:
                held(tr, "trombone", CHORDS[ch][0], t0, BAR * 2, 0.22, 0.0, rng, attack=0.2)
            if breakdown:
                held(tr, "cellos", CHORDS[ch][0], t0, BAR, 0.18, -0.2, rng, attack=0.3)
            _drums(tr, realm, t0, sec, k, ch, rng)
    return render("base_" + realm, BATTLE_LENGTH, score, wet=0.2, verb=1.8)


def _drums(tr, realm, t0, sec, k, ch, rng):
    """One bar of the realm's drums."""
    breakdown = sec == 2 and k < 4
    build = sec == 2 and k >= 6
    root = CHORDS[ch][0]
    timp_root = root - 12 if root >= 45 else root
    if k == 0 and sec != 2:
        strike(tr, "crash", t0, 0.22, 0.3, rng)
    if sec == 2 and k == 4:
        strike(tr, "crash", t0, 0.16, 0.3, rng)
    if build and k == 6:
        strike(tr, "swell", t0, 0.1, -0.2, rng)
    if realm == "vardish":
        if breakdown:
            strike(tr, "bass", t0, 0.5, 0.0, rng)
            strike(tr, "tenor", t0 + BEAT * 2, 0.35, -0.1, rng)
            return
        strike(tr, "bass", t0, 0.55, 0.0, rng)
        if sec == 3:
            strike(tr, "bass", t0 + BEAT * 2, 0.45, 0.0, rng)
        for b_, g in ((0, 0.42), (1.5, 0.3), (2, 0.38), (3.5, 0.3)):
            strike(tr, "tenor", t0 + b_ * BEAT, g, -0.15, rng)
        for b_ in (1, 3):
            strike(tr, "snare", t0 + b_ * BEAT, 0.32, 0.15, rng)
        for b_ in (2.75, 3.25):
            strike(tr, "snare_ghost", t0 + b_ * BEAT, 0.12, 0.15, rng)
        if build:
            for s in range(16):
                strike(tr, "snare", t0 + s * BEAT / 4, 0.05 + 0.008 * s + (0.03 if k == 7 else 0), 0.15, rng)
        if k % 2 == 0:
            tr.add(timpani(timp_root, rng, length=1.6), t0, 0.32, -0.05)
    elif realm == "kharzani":
        # the maqsum, war-band loud: DUM tek . tek DUM . tek .
        dums = (0, 2) if not breakdown else (0,)
        teks = (0.5, 1.5, 3) if not breakdown else (3,)
        for b_ in dums:
            strike(tr, "tenor", t0 + b_ * BEAT, 0.48, -0.1, rng, shift=-3)
            strike(tr, "bass", t0 + b_ * BEAT, 0.3, 0.0, rng)
        for b_ in teks:
            strike(tr, "tenor_hi", t0 + b_ * BEAT, 0.3, 0.2, rng, shift=4, length=0.25)
            strike(tr, "tamb", t0 + b_ * BEAT, 0.16, 0.35, rng)
        if not breakdown and sec in (1, 3):
            for s in range(8):
                tr.add(drum(430, 0.035, noise=1.0, rng=rng, drop=0.2, noise_hi=6500), t0 + s * BEAT / 2 + BEAT / 4, 0.07, 0.3)
        if build:
            for s in range(16):
                strike(tr, "tenor_hi", t0 + s * BEAT / 4, 0.06 + 0.01 * s, 0.2, rng, shift=4, length=0.2)
        if k % 4 == 0 and not breakdown:
            tr.add(timpani(timp_root, rng, length=1.6), t0, 0.26, -0.05)
    elif realm == "ryumon":
        # taiko: a great drum on one and the and of three, doko-doko into the next bar,
        # the small shime drum ticking the off-beats
        strike(tr, "bass", t0, 0.5, 0.0, rng, shift=-2)
        strike(tr, "tenor", t0, 0.42, -0.1, rng, shift=-5)
        if not breakdown:
            strike(tr, "tenor", t0 + BEAT * 2.5, 0.38, -0.1, rng, shift=-5)
            for b_ in (3.5, 3.75):
                strike(tr, "tenor", t0 + b_ * BEAT, 0.26, 0.1, rng, shift=-2, length=0.4)
            for s in range(4):
                strike(tr, "tenor_hi", t0 + (s + 0.5) * BEAT, 0.16, 0.3, rng, shift=7, length=0.15)
        if k == 7:
            tr.add(clap(rng), t0 + BEAT * 3, 0.5, -0.3)
            tr.add(clap(rng), t0 + BEAT * 3.5, 0.4, -0.3)
        if build:
            for s in range(8):
                strike(tr, "tenor", t0 + s * BEAT / 2, 0.1 + 0.02 * s, 0.0, rng, shift=-3, length=0.5)
    else:  # siege: half time, heavy
        strike(tr, "bass", t0, 0.6, 0.0, rng)
        tr.add(timpani(timp_root, rng, length=2.0), t0, 0.4, -0.05)
        if not breakdown:
            strike(tr, "snare", t0 + BEAT * 2, 0.36, 0.15, rng)
            strike(tr, "bass", t0 + BEAT * 2.5, 0.35, 0.0, rng)
            for b_ in (3, 3 + 1 / 3, 3 + 2 / 3):
                strike(tr, "tenor", t0 + b_ * BEAT, 0.3, -0.15, rng)
        if k == 0:
            strike(tr, "gong", t0, 0.22, 0.0, rng)
        if build:
            tr.add(timpani(timp_root, rng, roll=True, length=BAR), t0, 0.08 + 0.06 * (k - 6), -0.05)


def battle_high(realm):
    def score(tr, off):
        rng = rng_for("high_" + realm)
        a, b, d = off, off + BAR * 8, off + BAR * 24
        c = off + BAR * 16
        if realm == "vardish":
            melody(tr, "horn", THEME_A, a, BEAT, 0.42, -0.15, rng)
            melody(tr, "trumpet", THEME_B, b, BEAT, 0.3, 0.1, rng)
            melody(tr, "horn", THEME_B, b, BEAT, 0.3, -0.15, rng, transpose=-12)
            melody(tr, "trumpet", THEME_D, d, BEAT, 0.48, 0.1, rng)
            melody(tr, "horn", THEME_D, d, BEAT, 0.45, -0.15, rng, transpose=-12)
        elif realm == "kharzani":
            synth_line(tr, zurna, THEME_A, a, BEAT, 0.16, 0.1, rng)
            synth_line(tr, zurna, THEME_B, b, BEAT, 0.16, 0.1, rng)
            melody(tr, "horn_soft", THEME_B, b, BEAT, 0.22, -0.2, rng, transpose=-12)
            synth_line(tr, zurna, THEME_D, d, BEAT, 0.24, 0.1, rng)
            melody(tr, "trumpet", THEME_D, d, BEAT, 0.34, -0.1, rng)
        elif realm == "ryumon":
            synth_line(tr, shakuhachi, THEME_A, a, BEAT, 0.22, -0.1, rng)
            synth_line(tr, shakuhachi, THEME_B, b, BEAT, 0.22, -0.1, rng)
            for i in range(8):
                held(tr, "violins_trem", CHORDS[PROG[8 + i]][1] + 12, b + i * BAR, BAR, 0.1, 0.25, rng, attack=0.2)
            melody(tr, "horn", THEME_D, d, BEAT, 0.48, -0.1, rng, transpose=-12)
            synth_line(tr, shakuhachi, THEME_D, d, BEAT, 0.28, 0.15, rng)
        else:
            melody(tr, "trombone", THEME_A, a, BEAT, 0.34, -0.1, rng, transpose=-12)
            melody(tr, "horn", THEME_A, a, BEAT, 0.28, 0.15, rng)
            melody(tr, "horn", THEME_B, b, BEAT, 0.4, -0.1, rng)
            melody(tr, "trombone", THEME_B, b, BEAT, 0.26, 0.15, rng, transpose=-24)
            melody(tr, "trumpet", THEME_D, d, BEAT, 0.48, 0.1, rng)
            melody(tr, "trombone", THEME_D, d, BEAT, 0.42, -0.15, rng, transpose=-24)
        # the breakdown, the same for all: strings hold the chords, the horns call over them
        for i in range(0, 8, 2):
            ch = CHORDS[PROG[16 + i]]
            for m, g in ((ch[1] + 12, 0.06), (ch[2] + 12, 0.05), (ch[0] + 24, 0.05)):
                held(tr, "violins_soft", m, c + i * BAR, BAR * 2, g, 0.2, rng)
            held(tr, "violas", ch[0] + 12, c + i * BAR, BAR * 2, 0.06, -0.2, rng)
        melody(tr, "horn_soft", THEME_C, c, BEAT, 0.16, -0.1, rng, legato=0.98)
    return render("high_" + realm, BATTLE_LENGTH, score, wet=0.26, verb=2.0)


def turn_win():
    """When the fight goes your way: trumpets calling, violins high and bright, bells."""
    def score(tr, off):
        rng = rng_for("turn_win")
        for i, ch in enumerate(PROG):
            t0 = off + i * BAR
            notes = CHORDS[ch]
            held(tr, "violins_soft", notes[1] + 24, t0, BAR, 0.1, 0.3, rng, attack=0.3)
            held(tr, "violins_soft", notes[2] + 24, t0, BAR, 0.08, 0.3, rng, attack=0.3)
            if i % 2 == 1:
                for j, m in enumerate((notes[0] + 24, notes[0] + 24, notes[0] + 24, notes[2] + 24)):
                    at = t0 + BEAT * 3 + j * BEAT / 3 if j < 3 else t0 + BAR
                    if j < 3:
                        put(tr, "trumpet_stac", m, at, BEAT / 3, 0.22, -0.2, rng, release=0.1)
            if i % 4 == 0:
                put(tr, "glock", notes[2] + 36, t0, 1.2, 0.12, 0.35, rng, release=0.6)
                put(tr, "trumpet", notes[0] + 24, t0, BAR * 0.9, 0.18, -0.25, rng)
    return render("turn_win", BATTLE_LENGTH, score, wet=0.28, verb=2.2, loudness=-18.0)


def turn_lose():
    """When your lines waver: low tremolo, a horn grinding a half step above the chord,
    the timpani rolling up into each phrase."""
    def score(tr, off):
        rng = rng_for("turn_lose")
        for i in range(0, len(PROG), 2):
            t0 = off + i * BAR
            root = CHORDS[PROG[i]][0]
            low = root - 12 if root >= 45 else root
            held(tr, "cellos_trem", low + 12, t0, BAR * 2, 0.2, -0.2, rng, attack=0.5)
            held(tr, "violas", root + 1 + 12 if i % 4 == 0 else root + 12, t0, BAR * 2, 0.09, 0.2, rng, attack=0.8)
            if i % 4 == 2:
                put(tr, "horn_soft", root + 13, t0 + BEAT, BAR * 1.4, 0.2, 0.1, rng, attack=0.6, release=0.6)
                tr.add(timpani(low, rng, roll=True, length=BAR), t0 + BAR, 0.18, -0.05)
    return render("turn_lose", BATTLE_LENGTH, score, wet=0.3, verb=2.4, loudness=-19.0)


def deploy(realm):
    """Before the lines meet: a drone, a heartbeat drum, a call to arms. Half the battle's
    length, so it comes round twice for every pass of the rest."""
    chords = ["Dm"] * 4 + ["Bb"] * 4 + ["Gm"] * 4 + ["A"] * 4

    def score(tr, off):
        rng = rng_for("deploy_" + realm)
        for i in range(0, 16, 4):
            ch = CHORDS[chords[i]]
            held(tr, "cellos", ch[0], off + i * BAR, BAR * 4, 0.24, -0.2, rng, attack=1.0)
            held(tr, "violas", ch[2], off + i * BAR, BAR * 4, 0.14, 0.2, rng, attack=1.2)
            tr.add(timpani(ch[0] - 12 if ch[0] >= 45 else ch[0], rng, length=2.5), off + i * BAR, 0.3, -0.05)
        for i in range(16):
            t0 = off + i * BAR
            if realm == "ryumon":
                if i % 2 == 0:
                    strike(tr, "tenor", t0, 0.4, 0.0, rng, shift=-5)
            elif realm == "siege":
                strike(tr, "bass", t0, 0.45, 0.0, rng)
                if i % 8 == 0:
                    strike(tr, "gong", t0, 0.2, 0.0, rng)
            else:
                strike(tr, "tenor", t0, 0.34, -0.1, rng, shift=-3 if realm == "kharzani" else 0)
                strike(tr, "tenor", t0 + BEAT * 0.75, 0.22, -0.1, rng, shift=-3 if realm == "kharzani" else 0)
        for i in range(12, 16):
            held(tr, "violins_trem", CHORDS["A"][1] + 24 if i >= 14 else CHORDS["Gm"][1] + 24, off + i * BAR, BAR, 0.05 + 0.03 * (i - 12), 0.25, rng)
        call = [(62, 1), (69, 1), (74, 6)]
        for at in (0, 8):
            t0 = off + at * BAR + BEAT
            if realm == "vardish":
                melody(tr, "horn", call, t0, BEAT, 0.34, -0.1, rng)
            elif realm == "kharzani":
                synth_line(tr, ney, [(62, 1), (63, 0.5), (66, 0.5), (69, 4)], t0, BEAT, 0.2, 0.1, rng)
            elif realm == "ryumon":
                synth_line(tr, shakuhachi, [(69, 3), (67, 1), (62, 4)], t0, BEAT, 0.22, -0.1, rng)
            else:
                melody(tr, "trombone", [(50, 1), (57, 1), (62, 6)], t0, BEAT, 0.34, -0.1, rng)
    return render("deploy_" + realm, BAR * 16, score, wet=0.3, verb=2.4, loudness=-17.0)


# ------------------------------------------------------------------ after the battle

def rest_victory():
    """Under the results when you've won: the Glass Sea's horn tune in D major, slowly."""
    bpm = 72
    beat = 60.0 / bpm
    bar = beat * 4
    chords = ["D", "G", "D", "A", "Bm", "G", "A", "D"]
    tune = [(62, 1.5), (64, 0.5), (66, 1), (69, 1), (74, 4), (73, 1.5), (71, 0.5), (69, 2), (66, 4),
            (71, 1.5), (73, 0.5), (74, 1), (71, 1), (67, 2), (69, 2), (69, 4), (66, 4)]

    def score(tr, off):
        rng = rng_for("rest_victory")
        for i, name in enumerate(chords):
            ch = CHORDS[name]
            t0 = off + i * bar
            for j, m in enumerate([ch[0], ch[1] + 12, ch[2] + 12, ch[0] + 24, ch[2] + 12, ch[1] + 12, ch[0] + 12, ch[2]]):
                put(tr, "harp", m + 12, t0 + j * beat / 2, beat, 0.2, 0.3, rng, release=1.2)
            held(tr, "cellos", ch[0] - 12 if ch[0] >= 47 else ch[0], t0, bar, 0.14, -0.2, rng, attack=0.6)
        melody(tr, "horn_soft", tune, off, beat, 0.3, -0.1, rng, legato=0.98, release=0.5)
        melody(tr, "flute", [(None, 16), (78, 2), (76, 2), (74, 4), (73, 2), (74, 2), (76, 4)], off, beat, 0.12, 0.25, rng)
    return render("rest_victory", bar * len(chords), score, wet=0.34, verb=2.8, loudness=-18.0)


def rest_defeat():
    """Under the results when you've lost: low strings and a flute, falling."""
    bpm = 60
    beat = 60.0 / bpm
    bar = beat * 4
    chords = ["Dm", "Bb", "Gm", "A", "Dm", "Gm", "A", "Dm"]
    lament = [(74, 2), (72, 1), (70, 1), (69, 4), (70, 2), (69, 1), (67, 1), (65, 2), (64, 2),
              (65, 2), (67, 1), (65, 1), (62, 4), (64, 2), (61, 2), (62, 4)]

    def score(tr, off):
        rng = rng_for("rest_defeat")
        for i, name in enumerate(chords):
            ch = CHORDS[name]
            t0 = off + i * bar
            held(tr, "cellos", ch[0] - 12 if ch[0] >= 47 else ch[0], t0, bar, 0.2, -0.2, rng, attack=1.0)
            held(tr, "violas", ch[1] + 12, t0, bar, 0.1, 0.2, rng, attack=1.2)
        melody(tr, "flute", lament, off, beat, 0.2, 0.15, rng, legato=0.98, release=0.6)
        put(tr, "horn_soft", 50, off + bar * 4, bar * 1.8, 0.14, -0.3, rng, attack=0.8, release=1.0)
    return render("rest_defeat", bar * len(chords), score, wet=0.36, verb=3.0, loudness=-19.0)


def victory():
    rng = rng_for("victory2")
    beat = 60.0 / 120

    def score(tr, off):
        tr.add(timpani(38, rng, roll=True, length=beat * 1.5), off, 0.3, -0.05)
        t = beat * 1.5
        for m, b in [(62, 0.5), (69, 0.5), (74, 0.5), (78, 1.5), (81, 3)]:
            put(tr, "trumpet", m + 12 if m < 70 else m, off + t, b * beat * 0.95, 0.4, 0.1, rng, release=0.6)
            put(tr, "horn", m - 12, off + t, b * beat * 0.95, 0.34, -0.15, rng, release=0.6)
            t += b * beat
        land = off + beat * 4.5
        tr.add(timpani(38, rng, length=3.0), land, 0.55, -0.05)
        strike(tr, "crash", land, 0.4, 0.3, rng)
        strike(tr, "bass", land, 0.5, 0.0, rng)
        for m, g in ((62, 0.18), (66, 0.16), (69, 0.16), (74, 0.14)):
            put(tr, "violins", m + 12, land, beat * 4, g, 0.25, rng, release=1.2)
        put(tr, "cellos", 50, land, beat * 4, 0.22, -0.25, rng, release=1.2)
    return render_once(beat * 9, score, wet=0.3, verb=2.4)


def defeat():
    rng = rng_for("defeat2")
    beat = 60.0 / 60

    def score(tr, off):
        strike(tr, "gong", off, 0.35, 0.0, rng)
        tr.add(timpani(38, rng, length=3.0), off, 0.5, -0.05)
        held(tr, "cellos_trem", 38 + 12, off, beat * 5, 0.24, -0.2, rng, attack=0.3)
        t = 0.0
        for m, b in [(62, 1), (60, 1), (58, 1), (57, 2.5)]:
            put(tr, "horn", m, off + t + 0.2, b * beat * 0.97, 0.36, 0.1, rng, release=0.8)
            t += b * beat
        held(tr, "violas", 53, off + beat * 3.2, beat * 2.5, 0.12, 0.25, rng, attack=0.8)
        tr.add(timpani(45, rng, length=3.0), off + beat * 3.2, 0.4, -0.05)
    return render_once(beat * 6, score, wet=0.32, verb=2.8)


# ------------------------------------------------------------------ Home

TITLE_CHORDS = [  # one chord per half bar, as degrees of D minor (4 is A major, on the way home)
    "Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C", "Dm", "Dm", "Gm", "Gm", "Bb", "A", "Dm", "Dm"]
HORN_1 = [(62, 1.5), (64, 0.5), (65, 1), (69, 1), (74, 2), (72, 1), (70, 1), (69, 3), (65, 1),
          (67, 2), (64, 2), (65, 1.5), (67, 0.5), (69, 1), (74, 1), (70, 2), (69, 1), (67, 1),
          (65, 1), (67, 1), (64, 1), (61, 1), (62, 4)]
HORN_2 = [(69, 2), (74, 2), (77, 2), (76, 1), (74, 1), (72, 3), (69, 1), (67, 2), (72, 2),
          (69, 1.5), (70, 0.5), (72, 1), (74, 1), (74, 2), (70, 2), (69, 2), (73, 2), (74, 4)]


def title():
    """The Glass Sea, for a first visit to Home. Harp alone, then the horn sings, then the
    violins take the tune up high with the whole orchestra under it, then it settles."""
    bpm = 72
    beat = 60.0 / bpm
    bar = beat * 4
    intro = ["Dm", "Dm", "Bb", "Bb", "Dm", "Dm", "A", "A"]
    outro = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]
    halves = intro + TITLE_CHORDS + TITLE_CHORDS + outro   # 24 bars
    length = bar * len(halves) / 2

    def score(tr, off):
        rng = rng_for("title2")
        for h, name in enumerate(halves):
            ch = CHORDS[name]
            t0 = off + h * beat * 2
            bar_no = h // 2
            loud = 1.0 if 12 <= bar_no < 20 else (0.6 if bar_no < 4 or bar_no >= 20 else 0.8)
            for j, m in enumerate([ch[0], ch[1], ch[2], ch[1] + 12]):
                put(tr, "harp", m + 12, t0 + j * beat / 2, beat, 0.24 * (1.1 if bar_no < 4 else 0.85), 0.35, rng, release=1.4)
            if bar_no >= 4 and h % 2 == 0:
                held(tr, "cellos", ch[0] if ch[0] < 47 else ch[0] - 12, t0, bar, 0.14 * loud, -0.2, rng, attack=0.6)
                held(tr, "violas", ch[1] + 12, t0, bar, 0.08 * loud, 0.15, rng, attack=0.8)
            if 12 <= bar_no < 20 and h % 2 == 0:
                held(tr, "horn_soft", ch[2] + 12 if ch[2] < 57 else ch[2], t0, bar, 0.12, -0.3, rng, attack=0.6)
                held(tr, "violins_soft", ch[1] + 24, t0, bar, 0.06, 0.3, rng, attack=0.6)
        # the bells: a few notes as the title appears, more at the swell
        for at, m in ((0, 86), (beat * 3, 81), (bar * 2, 89), (bar * 2 + beat * 3, 86)):
            put(tr, "glock", m, off + at, 1.5, 0.08, 0.4, rng, release=1.0)
        for i in range(12, 20, 2):
            put(tr, "glock", CHORDS[halves[i * 2]][2] + 36, off + i * bar, 1.5, 0.07, 0.4, rng, release=1.0)
        melody(tr, "horn_soft", HORN_1, off + bar * 4, beat, 0.3, -0.1, rng, legato=0.98, release=0.5)
        melody(tr, "violins", HORN_2, off + bar * 12, beat, 0.24, 0.15, rng, transpose=12, legato=1.0, release=0.6)
        melody(tr, "horn", HORN_2, off + bar * 12, beat, 0.18, -0.15, rng, legato=0.98, release=0.5)
        melody(tr, "flute", HORN_2[-6:], off + bar * 16 + beat * 2, beat, 0.1, 0.3, rng, transpose=12)
        # the swell into the high point, and the settling
        tr.add(timpani(38, rng, roll=True, length=bar * 2), off + bar * 10, 0.16, -0.05)
        strike(tr, "swell", off + bar * 11, 0.22, -0.2, rng)
        tr.add(timpani(38, rng, length=3.0), off + bar * 12, 0.3, -0.05)
        melody(tr, "flute", [(74, 1.5), (76, 0.5), (77, 1), (81, 1), (86, 4), (None, 8)], off + bar * 20, beat, 0.12, 0.3, rng)
    return render("title2", length, score, wet=0.36, verb=3.0, loudness=-17.0)


def camp(realm):
    """Home with a campaign under way: your own realm's tune, by the campfire. Quieter and
    slower than its map theme, the realm's own instrument with a little of the orchestra."""
    rng_name = "camp_" + realm

    if realm == "vardish":
        bpm, per = 76, 3
        beat = 60.0 / bpm
        bar = beat * per
        chords = ["Dm", "C", "Dm", "A", "Dm", "F", "C", "Dm"] * 2
        tune = [(69, 1), (74, 1), (76, 1), (77, 1.5), (76, 0.5), (72, 1), (74, 2), (69, 1), (72, 1), (76, 1), (81, 1),
                (81, 1.5), (79, 0.5), (77, 1), (81, 1), (84, 1), (81, 1), (79, 1), (76, 1), (72, 1), (74, 3)]

        def score(tr, off):
            rng = rng_for(rng_name)
            for i, name in enumerate(chords):
                ch = CHORDS[name]
                t0 = off + i * bar
                for j, m in enumerate([ch[0], ch[2], ch[0] + 12, ch[1] + 12, ch[2], ch[0] + 12]):
                    tr.add(lute(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.01), 0.15, 0.25)
                if i % 2 == 0:
                    held(tr, "cellos", ch[0] - 12 if ch[0] >= 47 else ch[0], t0, bar * 2, 0.1, -0.2, rng, attack=1.0)
            melody(tr, "flute", tune, off, beat, 0.18, -0.15, rng, legato=0.97, release=0.4)
            melody(tr, "harp", tune, off + bar * 8, beat, 0.2, 0.2, rng, transpose=-12, release=1.0)
        return render(rng_name, bar * len(chords), score, wet=0.34, verb=2.8, loudness=-19.0)

    if realm == "kharzani":
        bpm = 70
        beat = 60.0 / bpm
        bar = beat * 4
        tune = [(62, 1), (63, 0.5), (66, 0.5), (67, 1), (66, 1), (63, 1), (62, 1), (62, 2),
                (69, 1), (67, 0.5), (66, 0.5), (67, 1), (69, 1), (70, 1), (69, 1), (69, 2),
                (72, 1), (70, 0.5), (69, 0.5), (70, 1), (69, 0.5), (67, 0.5), (66, 1), (67, 1), (69, 2),
                (67, 0.5), (66, 0.5), (63, 1), (66, 1), (63, 1), (62, 4)]

        def score(tr, off):
            rng = rng_for(rng_name)
            for i in range(0, 16, 4):
                held(tr, "cellos", 38, off + i * bar, bar * 4, 0.12, -0.2, rng, attack=1.2)
                held(tr, "violas", 45, off + i * bar, bar * 4, 0.06, 0.2, rng, attack=1.4)
            for i in range(16):
                t0 = off + i * bar
                strike(tr, "tenor", t0, 0.16, -0.1, rng, shift=-4, length=0.8)
                strike(tr, "tenor_hi", t0 + beat * 1.5, 0.07, 0.2, rng, shift=4, length=0.2)
            synth_line(tr, oud, tune, off, beat, 0.24, 0.2, rng)
            synth_line(tr, ney, tune, off + bar * 8, beat, 0.15, -0.2, rng)
        return render(rng_name, bar * 16, score, wet=0.34, verb=2.8, loudness=-19.0)

    # ryumon
    bpm = 60
    beat = 60.0 / bpm
    bar = beat * 4
    figures = {1: [52, 59, 64, 65, 64, 59, 57, 59], 2: [57, 60, 64, 65, 64, 60, 59, 57],
               3: [53, 57, 60, 64, 60, 57, 53, 52], 4: [52, 59, 64, 71, 69, 65, 64, 59]}
    order = [1, 1, 2, 1, 3, 2, 4, 1, 1, 2, 1, 3, 3, 2, 4, 1]
    tune = [(71, 3), (69, 1), (71, 2), (72, 2), (71, 1), (69, 1), (65, 2), (64, 4),
            (69, 2), (71, 1), (72, 1), (76, 3), (72, 1), (71, 2), (69, 1), (65, 1), (64, 4)]

    def score(tr, off):
        rng = rng_for(rng_name)
        for i, fig in enumerate(order):
            t0 = off + i * bar
            for j, m in enumerate(figures[fig]):
                tr.add(koto(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.012), 0.11, 0.3)
        for i in range(0, 16, 4):
            held(tr, "cellos", 40, off + i * bar, bar * 4, 0.1, -0.2, rng, attack=1.4)
        synth_line(tr, shakuhachi, tune, off + bar * 2, beat, 0.18, -0.2, rng)
        melody(tr, "harp", [(76, 2), (71, 2), (69, 4)] * 2, off + bar * 12, beat, 0.12, 0.3, rng, release=1.4)
    return render(rng_name, bar * len(order), score, wet=0.4, verb=3.2, loudness=-19.0)


MUSIC = {"title": title, "victory": victory, "defeat": defeat,
         "rest_victory": rest_victory, "rest_defeat": rest_defeat,
         "turn_win": turn_win, "turn_lose": turn_lose}
for _r in REALMS:
    MUSIC["deploy_" + _r] = (lambda r: lambda: deploy(r))(_r)
    MUSIC["base_" + _r] = (lambda r: lambda: battle_base(r))(_r)
    MUSIC["high_" + _r] = (lambda r: lambda: battle_high(r))(_r)
for _r in ("vardish", "kharzani", "ryumon"):
    MUSIC["camp_" + _r] = (lambda r: lambda: camp(r))(_r)
