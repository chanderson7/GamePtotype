"""The music of the three lands, heard on the map and in their towns, and their feasts.

Each land's theme is a through-composed piece of several minutes (it was a single minute
of synthesized instruments, looped under every hour of travel): its own instrument leads,
the recorded orchestra (tools/sampler.py) carries it, and it moves through sections so a
long ride hears it change and come home. Each is a seamless loop.

  vardish   The Long Road. D dorian, in three. Harp alone, then the tune on the flute
            over the lute; the horn's song in F with the strings under it; the tune
            again high on the violins with the whole consort; the lute alone to close.
  kharzani  The Red Waste. D hijaz. An oud improvising over the drone; the tune over the
            maqsum on the drums; the strings' answer with the ney above; the tune in
            unison, oud and violins together; the drums falling away to the oud alone.
  ryumon    Mist on the Strait. E in-scale. Koto figures alone; the shakuhachi's tune with
            the taiko far off; the strings and a high flute with the drums building; both
            winds together, a bell; the koto alone.

The feasts, for weddings and dances (they had the campfire tune):

  feast_vardish   A reel in D, a fiddle and a pipe over a tabor and a strummed lute.
  feast_kharzani  A dance in hijaz on the oud and ney, the darbuka and the clapping hands.
  feast_ryumon    A festival tune: a high flute over the taiko and koto.

Every line of every tune is checked to fill its bars, so the sections stay in step.

    python3 tools/music.py vardish      # one piece (music.py renders these)
"""
import numpy as np

from music import SR, hz, rng_for
from orchestral import (held, inst, kit, koto, lute, melody, ney, oud, put, render, shakuhachi, strike,
                        synth_line, timpani, clap)

# Chords as MIDI notes, root position, around the tenor.
CH = {
    "Dm": [50, 53, 57], "C": [48, 52, 55], "Am": [45, 48, 52], "F": [41, 45, 48], "Bb": [46, 50, 53],
    "Gm": [43, 46, 50], "G": [43, 47, 50], "A": [45, 49, 52], "D": [50, 54, 57], "Em": [40, 43, 47],
    "Bm": [47, 50, 54], "Eb": [51, 55, 58], "Cm": [48, 51, 55],
}


def beats(line):
    return sum(b for _m, b in line)


def check(name, line, want):
    got = beats(line)
    assert abs(got - want) < 1e-6, "%s has %s beats, wants %s" % (name, got, want)
    return line


def bass_note(name):
    root = CH[name][0]
    return root - 12 if root >= 46 else root


# ------------------------------------------------------------------ Vardmark

def vardish():
    bpm, per = 84, 3
    beat = 60.0 / bpm
    bar = beat * per
    intro = ["Dm", "C", "Dm", "Am", "F", "C", "Dm", "Dm"]
    verse = ["Dm", "C", "Dm", "Am", "Dm", "F", "C", "Dm", "F", "C", "Dm", "Dm", "F", "G", "Am", "Am"]
    song = ["F", "C", "Dm", "Bb", "F", "C", "Gm", "A", "F", "C", "Dm", "Bb", "Gm", "C", "A", "A"]
    coda = ["Dm", "C", "Dm", "Am", "Dm", "C", "Dm", "Dm"]
    chords = intro + verse + song + verse + coda          # 64 bars
    sections = {"intro": (0, 8), "verse": (8, 24), "song": (24, 40), "high": (40, 56), "coda": (56, 64)}
    tune = check("tune", [(69, 1), (74, 1), (76, 1), (77, 1.5), (76, 0.5), (72, 1), (74, 2), (69, 1), (72, 1), (76, 1),
                          (81, 1), (81, 1.5), (79, 0.5), (77, 1), (81, 1), (84, 1), (81, 1), (79, 1), (76, 1), (72, 1),
                          (74, 3)], 24)
    tune2 = check("tune2", [(81, 1), (84, 1), (81, 1), (79, 1.5), (77, 0.5), (76, 1), (77, 2), (74, 1), (72, 1), (76, 1),
                            (79, 1), (79, 1.5), (77, 0.5), (76, 1), (74, 1), (76, 1), (79, 1), (81, 3), (None, 3)], 24)
    horn_song = check("horn", [(65, 2), (69, 1), (72, 2), (70, 1), (69, 1.5), (67, 0.5), (65, 1), (67, 3),
                               (65, 2), (64, 1), (62, 2), (65, 1), (67, 1.5), (69, 0.5), (70, 1), (69, 3)], 24)
    horn_song2 = check("horn2", [(72, 2), (74, 1), (72, 1.5), (70, 0.5), (69, 1), (70, 2), (67, 1), (69, 3),
                                 (65, 1.5), (67, 0.5), (69, 1), (70, 2), (72, 1), (69, 1), (67, 1), (64, 1), (69, 3)], 24)
    fragment = check("frag", [(74, 2), (72, 1), (69, 3), (None, 6)], 12)

    def score(tr, off):
        rng = rng_for("realm_vardish")
        for i, name in enumerate(chords):
            ch = CH[name]
            t0 = off + i * bar
            sec = next(k for k, (a, b) in sections.items() if a <= i < b)
            # Harp arpeggios in the intro and the high verse; the lute in the verses and coda.
            if sec in ("intro", "high"):
                for j, m in enumerate([ch[0], ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]):
                    put(tr, "harp", m + 12, t0 + j * beat / 2, beat, 0.25 if sec == "intro" else 0.15, 0.35, rng, release=1.2)
            if sec in ("verse", "high", "coda"):
                for j, m in enumerate([ch[0], ch[2], ch[0] + 12, ch[1] + 12, ch[2], ch[0] + 12]):
                    tr.add(lute(hz(m + 12), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.008),
                           0.12 if sec != "coda" else 0.15, 0.25)
            if sec == "song":
                # Plucked strings under the horn: cello on the beat, the chord answered.
                put(tr, "cellos_spic", bass_note(name), t0, beat * 0.6, 0.22, -0.25, rng, release=0.3)
                for j in (1, 2):
                    put(tr, "violins_spic", ch[1] + 12, t0 + j * beat, beat * 0.4, 0.08, 0.3, rng, release=0.2)
                    put(tr, "violas", ch[2] + 12 if ch[2] < 60 else ch[2], t0 + j * beat, beat * 0.4, 0.06, 0.1, rng, release=0.2)
            # The low strings: a drone through the intro and coda, the bass line elsewhere.
            if i % 2 == 0:
                if sec in ("intro", "coda"):
                    held(tr, "cellos", 38, t0, bar * 2, 0.1, -0.2, rng, attack=1.0)
                elif sec in ("verse", "high"):
                    held(tr, "cellos", bass_note(name), t0, bar * 2, 0.12, -0.2, rng, attack=0.6)
            if sec in ("song", "high") and i % 2 == 0:
                held(tr, "violas", ch[1] + 12, t0, bar * 2, 0.08, 0.15, rng, attack=0.8)
            if sec == "song" and i % 2 == 0:
                held(tr, "cellos", bass_note(name), t0, bar * 2, 0.1, -0.2, rng, attack=0.8)
            if sec == "high" and i % 2 == 0:
                held(tr, "violins_soft", ch[2] + 24 if ch[2] + 24 <= 86 else ch[2] + 12, t0, bar * 2, 0.04, 0.3, rng, attack=0.8)
            # A tabor, lightly, in the verses: the walk of the road.
            if sec == "verse":
                strike(tr, "tenor_hi", t0, 0.07, -0.1, rng, shift=2, length=0.25)
                strike(tr, "tamb", t0 + beat * 2, 0.025, 0.2, rng)
        s = lambda k: off + sections[k][0] * bar
        melody(tr, "flute", fragment, s("intro") + bar * 4, beat, 0.12, -0.15, rng, legato=0.98, release=0.5)
        melody(tr, "flute", tune, s("verse"), beat, 0.17, -0.15, rng, legato=0.97, release=0.35)
        melody(tr, "flute", tune2, s("verse") + bar * 8, beat, 0.17, -0.15, rng, legato=0.97, release=0.35)
        melody(tr, "horn_soft", horn_song, s("song"), beat, 0.36, -0.1, rng, legato=0.98, release=0.5)
        melody(tr, "horn_soft", horn_song2, s("song") + bar * 8, beat, 0.36, -0.1, rng, legato=0.98, release=0.5)
        melody(tr, "flute", [(None, 3)] + horn_song2[:-1], s("song") + bar * 8, beat, 0.07, 0.3, rng, transpose=12, release=0.4)
        melody(tr, "violins", tune, s("high"), beat, 0.16, 0.15, rng, legato=1.0, release=0.5)
        melody(tr, "violins", tune2, s("high") + bar * 8, beat, 0.16, 0.15, rng, legato=1.0, release=0.5)
        melody(tr, "flute", tune, s("high"), beat, 0.08, -0.25, rng, transpose=12, release=0.3)
        # The swell into the high verse, and the settling into the coda.
        tr.add(timpani(38, rng, roll=True, length=bar * 2), s("high") - bar * 2, 0.1, -0.05)
        tr.add(timpani(38, rng, length=3.0), s("high"), 0.2, -0.05)
        synth_line(tr, lute, tune[:9], s("coda") + bar * 2, beat, 0.12, 0.1, rng, transpose=-12)
    return render("realm_vardish", bar * len(chords), score, wet=0.32, verb=2.8, loudness=-18.0)


# ------------------------------------------------------------------ Kharzan

def kharzani():
    bpm = 88
    beat = 60.0 / bpm
    bar = beat * 4
    n_bars = 64
    sections = {"taqsim": (0, 8), "a": (8, 24), "answer": (24, 40), "unison": (40, 56), "close": (56, 64)}
    tune = check("tune", [(62, 1), (63, 0.5), (66, 0.5), (67, 1), (66, 1), (63, 1), (62, 1), (62, 2),
                          (69, 1), (67, 0.5), (66, 0.5), (67, 1), (69, 1), (70, 1), (69, 1), (69, 2),
                          (72, 1), (70, 0.5), (69, 0.5), (70, 1), (69, 0.5), (67, 0.5), (66, 1), (67, 1), (69, 2),
                          (67, 0.5), (66, 0.5), (63, 1), (66, 1), (63, 1), (62, 4)], 32)
    answer = check("answer", [(74, 2), (75, 1), (74, 1), (72, 1.5), (70, 0.5), (69, 1), (70, 1),
                              (72, 2), (70, 1), (69, 1), (67, 4),
                              (69, 1), (70, 0.5), (69, 0.5), (67, 1), (66, 1), (67, 2), (69, 1), (70, 1),
                              (72, 1.5), (70, 0.5), (69, 1), (66, 1), (62, 4)], 32)
    taqsim = check("taqsim", [(None, 2), (74, 1.5), (75, 0.5), (74, 2), (72, 1), (70, 1), (69, 4),
                              (None, 2), (67, 0.5), (69, 0.5), (70, 1), (69, 1), (67, 1), (66, 1), (63, 1), (62, 4),
                              (None, 1), (69, 1), (70, 1), (72, 1), (70, 1), (66, 1), (67, 1), (62, 1)], 32)
    ney_line = check("ney", [(81, 4), (79, 2), (78, 2), (79, 4), (75, 4), (74, 4), (75, 2), (78, 2), (74, 8)], 32)

    def drums(tr, t0, rng, full):
        # The maqsum: dum . tek tek . dum . tek, on the low and high drum, with a tambourine.
        strike(tr, "tenor", t0, 0.17, -0.1, rng, shift=-5, length=0.7)
        strike(tr, "tenor_hi", t0 + beat * 1.0, 0.07, 0.2, rng, shift=5, length=0.2)
        strike(tr, "tenor_hi", t0 + beat * 1.5, 0.06, 0.2, rng, shift=5, length=0.2)
        strike(tr, "tenor", t0 + beat * 2.5, 0.12, -0.1, rng, shift=-5, length=0.6)
        strike(tr, "tenor_hi", t0 + beat * 3.0, 0.07, 0.2, rng, shift=5, length=0.2)
        if full:
            for k in range(8):
                strike(tr, "tamb", t0 + k * beat / 2, 0.018 if k % 2 else 0.03, 0.35, rng)

    def score(tr, off):
        rng = rng_for("realm_kharzani")
        s = lambda k: off + sections[k][0] * bar
        for i in range(n_bars):
            t0 = off + i * bar
            sec = next(k for k, (a, b) in sections.items() if a <= i < b)
            if i % 4 == 0:
                held(tr, "cellos", 38, t0, bar * 4, 0.12, -0.2, rng, attack=1.2)
                held(tr, "violas", 45, t0, bar * 4, 0.05 if sec in ("taqsim", "close") else 0.07, 0.2, rng, attack=1.4)
            if sec in ("a", "answer", "unison"):
                drums(tr, t0, rng, full=sec != "a" or i >= 16)
                put(tr, "cellos_spic", 38, t0, beat * 0.5, 0.12, -0.25, rng, release=0.2)
                put(tr, "cellos_spic", 38, t0 + beat * 2.5, beat * 0.5, 0.09, -0.25, rng, release=0.2)
            if sec == "close" and i < 60:
                strike(tr, "tenor", t0, 0.1, -0.1, rng, shift=-5, length=0.7)
            if sec == "unison" and i % 2 == 0:
                tr.add(clap(rng), t0 + beat * 1.5, 0.5, -0.3)
                tr.add(clap(rng), t0 + beat * 3.5, 0.5, 0.3)
        synth_line(tr, oud, taqsim, s("taqsim"), beat, 0.24, 0.2, rng)
        synth_line(tr, ney, [(74, 8), (69, 8), (None, 16)], s("taqsim"), beat, 0.08, -0.25, rng)
        synth_line(tr, oud, tune, s("a"), beat, 0.25, 0.2, rng)
        synth_line(tr, oud, tune, s("a") + bar * 8, beat, 0.22, 0.2, rng)
        synth_line(tr, ney, tune, s("a") + bar * 8, beat, 0.1, -0.25, rng, transpose=12)
        melody(tr, "violins", answer, s("answer"), beat, 0.15, 0.15, rng, legato=0.97, release=0.3)
        melody(tr, "violas", answer, s("answer"), beat, 0.07, -0.05, rng, transpose=-12, legato=0.97, release=0.3)
        synth_line(tr, ney, ney_line, s("answer") + bar * 8, beat, 0.12, -0.25, rng)
        synth_line(tr, oud, answer, s("answer") + bar * 8, beat, 0.14, 0.25, rng, transpose=-12)
        melody(tr, "violins", tune, s("unison"), beat, 0.15, 0.1, rng, transpose=12, legato=0.97, release=0.3)
        synth_line(tr, oud, tune, s("unison"), beat, 0.22, 0.25, rng)
        melody(tr, "violins", answer, s("unison") + bar * 8, beat, 0.15, 0.1, rng, legato=0.97, release=0.3)
        synth_line(tr, oud, answer, s("unison") + bar * 8, beat, 0.2, 0.25, rng, transpose=-12)
        synth_line(tr, ney, ney_line, s("unison") + bar * 8, beat, 0.08, -0.3, rng, transpose=12)
        synth_line(tr, oud, taqsim[:9], s("close"), beat, 0.22, 0.2, rng)
    return render("realm_kharzani", bar * n_bars, score, wet=0.3, verb=2.6, loudness=-18.0)


# ------------------------------------------------------------------ Ryumon

def ryumon():
    bpm = 66
    beat = 60.0 / bpm
    bar = beat * 4
    n_bars = 48
    sections = {"koto": (0, 8), "song": (8, 24), "rising": (24, 36), "both": (36, 44), "close": (44, 48)}
    figures = {1: [52, 59, 64, 65, 64, 59, 57, 59], 2: [57, 60, 64, 65, 64, 60, 59, 57],
               3: [53, 57, 60, 64, 60, 57, 53, 52], 4: [52, 59, 64, 71, 69, 65, 64, 59]}
    order = ([1, 1, 2, 1, 3, 2, 4, 1] + [1, 2, 1, 3, 1, 2, 4, 1] * 2 + [3, 3, 2, 2, 1, 4, 3, 2, 1, 1, 4, 4]
             + [1, 2, 3, 2, 1, 2, 4, 1] + [1, 2, 4, 1])
    assert len(order) == n_bars
    roots = {1: 40, 2: 45, 3: 41, 4: 40}
    tune = check("tune", [(71, 3), (69, 1), (71, 2), (72, 2), (71, 1), (69, 1), (65, 2), (64, 4),
                          (69, 2), (71, 1), (72, 1), (76, 3), (72, 1), (71, 2), (69, 1), (65, 1), (64, 4)], 32)
    tune2 = check("tune2", [(76, 3), (77, 1), (76, 2), (72, 2), (71, 2), (72, 1), (71, 1), (69, 4),
                            (65, 2), (69, 1), (71, 1), (72, 3), (71, 1), (69, 2), (65, 2), (64, 4)], 32)
    rising = check("rising", [(64, 4), (65, 4), (69, 6), (71, 2), (72, 4), (71, 4), (69, 8),
                              (71, 4), (72, 4), (76, 6), (77, 2), (76, 4), (72, 4), (71, 8)], 64)

    def score(tr, off):
        rng = rng_for("realm_ryumon")
        s = lambda k: off + sections[k][0] * bar
        for i, fig in enumerate(order):
            t0 = off + i * bar
            sec = next(k for k, (a, b) in sections.items() if a <= i < b)
            loud = {"koto": 0.12, "song": 0.1, "rising": 0.09, "both": 0.09, "close": 0.12}[sec]
            for j, m in enumerate(figures[fig]):
                tr.add(koto(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.012), loud, 0.3)
            if i % 4 == 0:
                held(tr, "cellos", 40, t0, bar * 4, 0.09, -0.2, rng, attack=1.4)
            if sec in ("rising", "both") and i % 2 == 0:
                r = roots[fig]
                held(tr, "violas", r + 12 + 7, t0, bar * 2, 0.06, 0.15, rng, attack=1.0)
                held(tr, "violins_soft", r + 24 + 4 if fig != 2 else r + 24 + 3, t0, bar * 2, 0.04, 0.3, rng, attack=1.2)
            # The taiko: far off in the song, nearer as the strings rise.
            if sec == "song" and i % 2 == 0:
                strike(tr, "bass", t0, 0.12, -0.05, rng, shift=-3)
            if sec in ("rising", "both"):
                strike(tr, "bass", t0, 0.17, -0.05, rng, shift=-3)
                strike(tr, "tenor", t0 + beat * 2.5, 0.08, 0.15, rng, shift=-2, length=0.5)
                if sec == "both" or i >= 30:
                    strike(tr, "tenor", t0 + beat * 3.0, 0.07, 0.15, rng, shift=-2, length=0.4)
                    strike(tr, "tenor", t0 + beat * 3.5, 0.09, 0.15, rng, shift=-2, length=0.4)
        synth_line(tr, shakuhachi, tune, s("song"), beat, 0.18, -0.2, rng)
        synth_line(tr, shakuhachi, tune2, s("song") + bar * 8, beat, 0.18, -0.2, rng)
        melody(tr, "harp", [(76, 2), (71, 2), (69, 4)] * 2, s("song") + bar * 12, beat, 0.1, 0.3, rng, release=1.4)
        melody(tr, "flute", rising, s("rising") - bar * 4, beat, 0.1, 0.25, rng, transpose=12, legato=0.98, release=0.5)
        melody(tr, "violins", rising[:7], s("rising") + bar * 4, beat, 0.08, 0.2, rng, legato=1.0, release=0.6)
        synth_line(tr, shakuhachi, tune, s("both"), beat, 0.17, -0.2, rng)
        melody(tr, "flute", tune, s("both"), beat, 0.08, 0.25, rng, transpose=12, legato=0.98, release=0.4)
        for at, m in ((0, 88), (bar * 2, 83), (bar * 4, 88), (bar * 6, 81)):
            put(tr, "glock", m, s("both") + at, 1.5, 0.05, 0.4, rng, release=1.2)
        strike(tr, "gong", s("both"), 0.08, 0.0, rng)
    return render("realm_ryumon", bar * n_bars, score, wet=0.38, verb=3.2, loudness=-18.0)


# ------------------------------------------------------------------ the feasts

def feast_vardish():
    """A reel in D: the pipe (flute) and fiddles take the tune in turn over a strummed
    lute, a tabor on every beat and a plucked bass."""
    bpm, per = 150, 3
    beat = 60.0 / bpm
    bar = beat * per
    prog = ["D", "D", "G", "A", "D", "D", "G", "A", "D", "G", "D", "A", "G", "A", "D", "D"]
    chords = prog * 3                       # 48 bars
    a = check("reel_a", [(74, 1), (76, 1), (78, 1), (81, 2), (78, 1), (79, 1), (78, 1), (76, 1), (74, 1), (76, 1), (78, 1),
                         (79, 2), (83, 1), (81, 1), (79, 1), (78, 1), (76, 3), (74, 1), (76, 1), (78, 1),
                         (81, 2), (78, 1), (83, 1), (81, 1), (79, 1), (78, 1), (76, 1), (74, 1), (73, 1), (74, 1), (76, 1),
                         (78, 2), (76, 1), (74, 1), (73, 1), (71, 1), (74, 3), (None, 3)], 48)
    b = check("reel_b", [(81, 1), (83, 1), (85, 1), (86, 2), (85, 1), (83, 1), (81, 1), (79, 1), (78, 1), (79, 1), (81, 1),
                         (83, 2), (81, 1), (79, 1), (78, 1), (76, 1), (78, 3), (81, 1), (83, 1), (85, 1),
                         (86, 2), (83, 1), (81, 1), (79, 1), (78, 1), (79, 2), (76, 1), (74, 1), (76, 1), (78, 1),
                         (79, 2), (78, 1), (76, 1), (73, 1), (76, 1), (74, 3), (None, 3)], 48)

    def score(tr, off):
        rng = rng_for("feast_vardish")
        for i, name in enumerate(chords):
            ch = CH[name]
            t0 = off + i * bar
            put(tr, "cellos_spic", bass_note(name), t0, beat * 0.6, 0.15, -0.25, rng, release=0.2)
            put(tr, "cellos_spic", bass_note(name) + 7, t0 + beat * 2, beat * 0.5, 0.08, -0.25, rng, release=0.2)
            for j in range(3):
                for k, m in enumerate(ch):
                    tr.add(lute(hz(m + 12), beat * 0.4, rng), t0 + j * beat + k * 0.012, 0.06 if j else 0.08, 0.3)
            strike(tr, "tenor_hi", t0, 0.1, -0.1, rng, shift=3, length=0.25)
            strike(tr, "snare_ghost", t0 + beat, 0.04, 0.1, rng)
            strike(tr, "snare_ghost", t0 + beat * 2, 0.04, 0.1, rng)
            strike(tr, "tamb", t0 + beat * 1.5, 0.03, 0.35, rng)
            if i % 16 == 15:
                strike(tr, "tamb", t0 + beat * 2.5, 0.05, 0.35, rng)
        for rep in range(3):
            t = off + rep * 16 * bar
            lead = ["flute", "violins", "flute"][rep]
            melody(tr, lead, a, t, beat, 0.17 if lead == "flute" else 0.13, -0.15, rng, legato=0.9, release=0.2)
            melody(tr, "violins" if lead == "flute" else "flute", b, t + bar * 8, beat, 0.13, 0.15, rng, legato=0.9, release=0.2)
            if rep == 2:
                melody(tr, "violins_spic", b, t + bar * 8, beat, 0.06, -0.3, rng, transpose=-12, legato=0.6, release=0.1)
    return render("feast_vardish", bar * len(chords), score, wet=0.22, verb=1.8, loudness=-17.0)


def feast_kharzani():
    """A dance in hijaz: the oud and the ney trade the tune over the darbuka's quick malfuf,
    the tambourine and the clapping hands."""
    bpm = 116
    beat = 60.0 / bpm
    bar = beat * 2
    n_bars = 64
    tune = check("dance", [(62, 0.5), (63, 0.5), (66, 0.5), (67, 0.5), (69, 1), (67, 0.5), (66, 0.5),
                           (67, 0.5), (69, 0.5), (70, 0.5), (69, 0.5), (67, 1), (66, 1),
                           (69, 0.5), (70, 0.5), (72, 0.5), (70, 0.5), (69, 0.5), (67, 0.5), (66, 0.5), (67, 0.5),
                           (66, 0.5), (63, 0.5), (62, 1), (62, 2)], 16)
    turn = check("turn", [(74, 1), (72, 0.5), (70, 0.5), (69, 1), (70, 0.5), (72, 0.5), (74, 0.5), (75, 0.5), (74, 1), (72, 1),
                          (70, 0.5), (69, 0.5), (67, 0.5), (69, 0.5), (70, 1), (69, 0.5), (67, 0.5), (66, 0.5), (67, 0.5), (69, 2),
                          (None, 2)], 16)

    def score(tr, off):
        rng = rng_for("feast_kharzani")
        for i in range(n_bars):
            t0 = off + i * bar
            # Malfuf: dum . . tek . . tek .
            strike(tr, "tenor", t0, 0.17, -0.1, rng, shift=-5, length=0.5)
            strike(tr, "tenor_hi", t0 + beat * 0.75, 0.08, 0.2, rng, shift=5, length=0.15)
            strike(tr, "tenor_hi", t0 + beat * 1.5, 0.08, 0.2, rng, shift=5, length=0.15)
            for k in range(4):
                strike(tr, "tamb", t0 + k * beat / 2, 0.02 if k % 2 else 0.032, 0.35, rng)
            if i % 2 == 1:
                tr.add(clap(rng), t0, 0.55, -0.3)
                tr.add(clap(rng), t0 + beat, 0.55, 0.3)
            put(tr, "cellos_spic", 38 if (i // 4) % 4 != 2 else 43, t0, beat * 0.5, 0.12, -0.25, rng, release=0.15)
            if i % 8 == 0:
                held(tr, "violas", 45, t0, bar * 8, 0.04, 0.2, rng, attack=0.8)
        for k in range(0, n_bars, 16):
            t = off + k * bar
            synth_line(tr, oud, tune, t, beat, 0.24, 0.2, rng)
            synth_line(tr, ney, tune, t + bar * 8, beat, 0.15, -0.25, rng, transpose=12)
            synth_line(tr, oud, tune, t + bar * 8, beat, 0.14, 0.2, rng)
        for k in (32, 48):
            melody(tr, "violins", turn, off + k * bar, beat, 0.12, 0.1, rng, legato=0.9, release=0.2)
    return render("feast_kharzani", bar * n_bars, score, wet=0.22, verb=1.8, loudness=-17.0)


def feast_ryumon():
    """A festival tune: a high flute over the taiko's dance rhythm, the koto keeping time,
    the hand drums answering."""
    bpm = 104
    beat = 60.0 / bpm
    bar = beat * 4
    n_bars = 32
    tune = check("matsuri", [(76, 1), (79, 0.5), (81, 0.5), (83, 1), (81, 1), (79, 0.5), (76, 0.5), (74, 1), (76, 2),
                             (79, 1), (81, 1), (83, 0.5), (86, 0.5), (83, 1), (81, 1), (79, 1), (76, 2),
                             (74, 1), (76, 0.5), (79, 0.5), (81, 1), (79, 1), (76, 1), (74, 1), (71, 2),
                             (74, 1), (76, 1), (79, 1), (76, 1), (74, 0.5), (71, 0.5), (69, 1), (71, 2)], 32)
    # E minor pentatonic for a festival: E G A B D.
    figure = [64, 71, 76, 71, 69, 71, 74, 71]

    def score(tr, off):
        rng = rng_for("feast_ryumon")
        for i in range(n_bars):
            t0 = off + i * bar
            # The taiko: don . don-don . | don . kara-kara
            strike(tr, "bass", t0, 0.2, -0.05, rng, shift=-3)
            strike(tr, "tenor", t0 + beat * 1.0, 0.12, 0.1, rng, shift=-2, length=0.4)
            strike(tr, "tenor", t0 + beat * 1.5, 0.1, 0.1, rng, shift=-2, length=0.4)
            strike(tr, "bass", t0 + beat * 2, 0.14, -0.05, rng, shift=-3)
            for k in (3.0, 3.25, 3.5):
                strike(tr, "tenor_hi", t0 + beat * k, 0.05, 0.25, rng, shift=4, length=0.15)
            for j, m in enumerate(figure):
                tr.add(koto(hz(m - 12 if j % 2 == 0 else m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.01), 0.08, 0.3)
            if i % 4 == 0:
                held(tr, "cellos", 40, t0, bar * 4, 0.07, -0.2, rng, attack=0.6)
        for k in range(0, n_bars, 8):
            melody(tr, "flute", tune, off + k * bar, beat, 0.17, -0.15, rng, legato=0.92, release=0.25)
        synth_line(tr, shakuhachi, [(n - 12, b) if n else (n, b) for n, b in tune], off + 8 * bar, beat, 0.1, 0.25, rng)
        synth_line(tr, shakuhachi, [(n - 12, b) if n else (n, b) for n, b in tune], off + 24 * bar, beat, 0.1, 0.25, rng)
        for at in (0, 16):
            put(tr, "glock", 88, off + at * bar, 1.5, 0.05, 0.4, rng, release=1.0)
    return render("feast_ryumon", bar * n_bars, score, wet=0.24, verb=2.0, loudness=-17.0)


MUSIC = {"vardish": vardish, "kharzani": kharzani, "ryumon": ryumon,
         "feast_vardish": feast_vardish, "feast_kharzani": feast_kharzani, "feast_ryumon": feast_ryumon}
