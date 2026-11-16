"""The music and sounds of the game's ceremonies, beginning with the wedding.

The wedding had the campfire tune for its ceremony and the feast tune after, two bells
and a cheer. It has its own now.

Music, played by the recorded orchestra (tools/sampler.py) with each people's own
instrument, each a seamless loop of well over a minute:

  wedding_vardish   Hearth and Road. D major, in three: the harp alone, the tune on the
                    flute, then on the violins with a horn under it, and the harp home.
  wedding_kharzani  The Open Door. D hijaz, slow: the oud alone, the ney's tune over a
                    soft drum and a drone, the strings joining, the oud alone to close.
  wedding_ryumon    Two Names. E, in the bright (yo) scale: koto figures, the shakuhachi's
                    tune, the harp doubling it, the koto alone.

Sounds (rendered into assets/audio/sfx with the rest):

  married      the moment of "I do": a harp run up, bells and the strings' chord
  heartbeat    while "I do" is held
  hearth       a fire close by (a long seamless loop): the Vardish rite, her room at night
  murmur       guests waiting, talking low (a long seamless loop)
  feast_din    a hall at table: talk, laughter, cups (a long seamless loop)
  cups         cups knocked together in a toast
  laugh        a table laughing
  applause     hands, for a dance or a verse
  pour         a cup filled
  cup_down     a cup set down
  cord         a cord drawn through the fire's smoke and over a wrist
  knot         a knot pulled tight
  bread        a loaf broken
  salt         salt, a pinch
  quill        a pen on a contract
  brush        a brush on a register
  seal         a seal pressed
  lantern      a paper lantern let go
  door         a door shut on the noise

    python3 tools/music.py 'wedding_*'   # the three themes
    python3 tools/music.py ceremony      # the sounds
"""
import numpy as np

import battle_sfx as B
from music import SR, band, bell, drum, hz, lowpass, rng_for, seamless
from orchestral import held, koto, melody, ney, oud, put, render, render_once, shakuhachi, strike, synth_line

CH = {"D": [50, 54, 57], "G": [43, 47, 50], "A": [45, 49, 52], "Bm": [47, 50, 54], "Em": [40, 43, 47]}


def beats(line):
    return sum(b for _m, b in line)


def check(name, line, want):
    got = beats(line)
    assert abs(got - want) < 1e-6, "%s has %s beats, wants %s" % (name, got, want)
    return line


# ------------------------------------------------------------------ the themes

def wedding_vardish():
    """Hearth and Road: a slow air in D, in three."""
    bpm, per = 66, 3
    beat = 60.0 / bpm
    bar = beat * per
    prog = ["D", "G", "D", "A", "Bm", "G", "A", "D", "D", "G", "D", "Bm", "G", "A", "D", "D"]
    chords = prog * 2                       # 32 bars
    tune = check("hearth", [(66, 2), (69, 1), (71, 2), (69, 1), (66, 1), (64, 1), (62, 1), (64, 3),
                            (66, 2), (69, 1), (71, 1), (74, 2), (73, 2), (71, 1), (69, 3),
                            (74, 2), (73, 1), (71, 2), (67, 1), (69, 1), (66, 1), (62, 1), (66, 3),
                            (67, 1), (71, 1), (74, 1), (73, 1), (71, 1), (69, 1), (69, 2), (64, 1), (62, 3)], 48)
    # A line for the horn under the second time through: the roots, a bar each.
    under = check("under", [(CH[c][0] + 12, 3) for c in prog], 48)

    def score(tr, off):
        rng = rng_for("wedding_vardish")
        for i, name in enumerate(chords):
            ch = CH[name]
            t0 = off + i * bar
            low = ch[0] - 12 if ch[0] >= 47 else ch[0]
            for j, m in enumerate([low, ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 12]):
                put(tr, "harp", m, t0 + j * beat * 0.5 + rng.uniform(0, 0.012), beat * 1.4, 0.2 if j else 0.26, 0.25, rng, release=1.2)
            if i % 2 == 0:
                held(tr, "cellos", low, t0, bar * 2, 0.06 if i < 16 else 0.07, -0.25, rng, attack=1.2)
            if i >= 16 and i % 2 == 0:
                held(tr, "violas", ch[1] + 12, t0, bar * 2, 0.035, 0.2, rng, attack=1.4)
            if i in (16, 24):
                put(tr, "glock", ch[0] + 36, t0, 1.5, 0.05, 0.35, rng, release=1.0)
        # The flute comes in on the second phrase of the first time through.
        melody(tr, "flute", tune[14:], off + bar * 8, beat, 0.17, -0.15, rng, transpose=12, legato=0.97, release=0.45)
        t2 = off + bar * 16
        melody(tr, "violins_soft", tune, t2, beat, 0.075, -0.2, rng, transpose=12, legato=0.98, release=0.5)
        melody(tr, "horn_soft", under[:24], t2, beat, 0.04, 0.15, rng, legato=0.98, release=0.6)
        melody(tr, "flute", tune[23:], t2 + bar * 8, beat, 0.06, 0.2, rng, transpose=24, legato=0.97, release=0.45)
    return render("wedding_vardish", bar * len(chords), score, wet=0.36, verb=3.0, loudness=-19.0)


def wedding_kharzani():
    """The Open Door: slow, in hijaz on D."""
    bpm = 63
    beat = 60.0 / bpm
    bar = beat * 4
    n_bars = 20
    p1 = check("door_1", [(69, 2), (70, 1), (69, 1), (66, 2), (67, 1), (69, 1), (70, 1.5), (69, 0.5), (67, 1), (66, 1), (63, 1), (62, 3)], 16)
    p2 = check("door_2", [(74, 2), (72, 1), (70, 1), (69, 2), (70, 1), (72, 1), (74, 1), (75, 1), (74, 1), (72, 1), (70, 1), (69, 3)], 16)
    p3 = check("door_3", [(69, 1), (70, 1), (72, 2), (70, 1), (69, 1), (67, 2), (66, 1), (67, 1), (69, 1), (66, 1), (63, 1), (62, 3)], 16)

    def score(tr, off):
        rng = rng_for("wedding_kharzani")
        for i in range(n_bars):
            t0 = off + i * bar
            if 4 <= i < 16:
                # The oud keeps a figure under the others: D, A, D above, A.
                for j, m in enumerate([50, 57, 62, 57]):
                    tr.add(oud(hz(m), beat * 0.9, rng), t0 + j * beat + rng.uniform(0, 0.012), 0.1, 0.25)
                strike(tr, "tenor", t0, 0.1, -0.1, rng, shift=-5, length=0.7)
                strike(tr, "tenor_hi", t0 + beat * 2.5, 0.04, 0.2, rng, shift=5, length=0.15)
            if 4 <= i < 16 and i % 4 == 0:
                held(tr, "cellos", 38, t0, bar * 4, 0.09, -0.2, rng, attack=1.4)
                held(tr, "violas", 45, t0, bar * 4, 0.05, 0.2, rng, attack=1.6)
        synth_line(tr, oud, p1, off, beat, 0.24, 0.15, rng)
        synth_line(tr, ney, p1, off + bar * 4, beat, 0.16, -0.2, rng)
        synth_line(tr, ney, p2, off + bar * 8, beat, 0.16, -0.2, rng)
        melody(tr, "violins_soft", p2, off + bar * 8, beat, 0.07, 0.25, rng, legato=0.98, release=0.5)
        synth_line(tr, oud, p3, off + bar * 12, beat, 0.2, 0.15, rng)
        melody(tr, "violins_soft", p3, off + bar * 12, beat, 0.11, -0.25, rng, transpose=12, legato=0.98, release=0.5)
        synth_line(tr, oud, p1, off + bar * 16, beat, 0.22, 0.15, rng, transpose=-12)
    return render("wedding_kharzani", bar * n_bars, score, wet=0.36, verb=3.0, loudness=-19.0)


def wedding_ryumon():
    """Two Names: the bright pentatonic on E (E F# A B C#), unhurried."""
    bpm = 56
    beat = 60.0 / bpm
    bar = beat * 4
    figures = {1: [52, 59, 64, 66, 69, 66, 64, 59], 2: [57, 61, 64, 69, 73, 69, 64, 61],
               3: [54, 59, 61, 66, 71, 66, 61, 59], 4: [52, 59, 64, 71, 73, 71, 69, 64]}
    order = [1, 1, 2, 1, 3, 2, 4, 1, 1, 2, 3, 2, 4, 1, 2, 3, 4, 1]
    tune = check("names", [(71, 3), (73, 1), (76, 2), (73, 2), (71, 1), (69, 1), (66, 2), (64, 4),
                           (69, 2), (71, 1), (73, 1), (78, 3), (76, 1), (73, 2), (71, 1), (69, 1), (71, 4)], 32)

    def score(tr, off):
        rng = rng_for("wedding_ryumon")
        for i, fig in enumerate(order):
            t0 = off + i * bar
            for j, m in enumerate(figures[fig]):
                tr.add(koto(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.012), 0.1 if j else 0.13, 0.3)
            if 2 <= i < 16 and i % 4 == 2:
                held(tr, "cellos", 40, t0, bar * 4, 0.08, -0.2, rng, attack=1.6)
            if 10 <= i < 16 and i % 4 == 2:
                held(tr, "violas", 59, t0, bar * 4, 0.045, 0.2, rng, attack=1.8)
        synth_line(tr, shakuhachi, tune, off + bar * 2, beat, 0.17, -0.2, rng)
        t2 = off + bar * 10
        synth_line(tr, shakuhachi, tune[:8], t2, beat, 0.15, -0.2, rng)
        melody(tr, "harp", tune[:8], t2, beat, 0.12, 0.3, rng, release=1.4)
        melody(tr, "harp", tune[8:], t2 + bar * 4, beat, 0.14, 0.3, rng, transpose=-12, release=1.4)
        for at, m in ((2, 88), (6, 85), (10, 88), (14, 83)):
            put(tr, "glock", m, off + bar * at, 1.5, 0.035, 0.4, rng, release=1.0)
    return render("wedding_ryumon", bar * len(order), score, wet=0.4, verb=3.2, loudness=-19.0)


MUSIC = {"wedding_vardish": wedding_vardish, "wedding_kharzani": wedding_kharzani, "wedding_ryumon": wedding_ryumon}


# ------------------------------------------------------------------ the moment

def _mono(buf):
    return (buf[0] + buf[1]) * 0.5


def married():
    """A harp run up the scale, bells at the top, and the strings' chord held under it."""
    scale = [50, 54, 57, 62, 64, 66, 69, 71, 74, 76, 78, 81, 86]

    def score(tr, off):
        rng = rng_for("married")
        for k, m in enumerate(scale):
            put(tr, "harp", m, off + k * 0.065, 2.0, 0.16 + 0.006 * k, -0.3 + 0.05 * k, rng, release=1.6)
        top = off + len(scale) * 0.065
        for m, g in ((62, 0.12), (66, 0.1), (69, 0.1), (74, 0.09)):
            put(tr, "violins_soft", m + 12, top, 3.4, g, -0.2, rng, release=1.2, attack=0.25)
        put(tr, "cellos", 38, top, 3.6, 0.14, -0.25, rng, release=1.2, attack=0.3)
        put(tr, "horn_soft", 62, top, 3.2, 0.08, 0.2, rng, release=1.0, attack=0.3)
        for k, m in enumerate((86, 90, 93, 98)):
            put(tr, "glock", m, top + k * 0.16, 2.0, 0.07, 0.35, rng, release=1.4)
        tr.add(bell(hz(74), 3.5, rng), top, 0.16, 0.0)
        tr.add(bell(hz(81), 3.0, rng), top + 0.7, 0.1, 0.25)
    return _mono(render_once(4.6, score, wet=0.34, verb=2.6, tail=1.4, loudness=-17.0))


def heartbeat():
    """Three beats of a heart, close: lub-dub, lub-dub, lub-dub."""
    rng = rng_for("heartbeat")
    parts = []
    for k in range(3):
        at = 0.02 + k * 0.86
        parts.append((band(drum(58, 0.09, dur=0.35, noise=0.05, rng=rng, drop=0.5), 30, 400), at, 1.0))
        parts.append((band(drum(72, 0.06, dur=0.3, noise=0.04, rng=rng, drop=0.4), 30, 500), at + 0.27, 0.7))
    return B.tail(B.mix(parts, 2.7), 0.2)


# ------------------------------------------------------------------ rooms and crowds

def hearth():
    """A fire close by: a low breath, a steady hiss, crackles, and a pop now and then."""
    rng = rng_for("hearth")
    n = int(24.0 * SR)
    over = int(1.5 * SR)
    m = n + over
    t = np.arange(m) / SR
    breath = band(rng.standard_normal(m), 60, 420) * (0.10 + 0.03 * np.sin(2 * np.pi * 0.11 * t) + 0.02 * np.sin(2 * np.pi * 0.37 * t))
    hiss = band(rng.standard_normal(m), 900, 5000) * 0.02
    out = breath + hiss
    for _ in range(520):
        s = int(rng.integers(0, m - int(0.05 * SR)))
        k = int(rng.uniform(0.006, 0.03) * SR)
        tt = np.arange(k) / SR
        out[s:s + k] += band(rng.standard_normal(k), 1400, 8000) * np.exp(-tt / 0.005) * rng.uniform(0.08, 0.3)
    for _ in range(14):
        s = int(rng.integers(0, m - int(0.2 * SR)))
        pop = band(drum(rng.uniform(180, 320), 0.02, dur=0.12, noise=0.7, rng=rng, drop=0.3, noise_hi=5000), 150, 6000)
        out[s:s + len(pop)] += pop[: m - s] * rng.uniform(0.25, 0.5)
    return seamless(out, n, over)


def _babble(rng, length, voices, level, pitch=(95, 250)):
    """Many people talking at once, none of them understood: short syllables in every
    vowel, each a voice or two, scattered through `length` seconds."""
    n = int(length * SR)
    out = np.zeros(n)
    for _ in range(voices):
        at = rng.uniform(0.0, length - 0.5)
        d = rng.uniform(0.14, 0.38)
        syl = B.crowd(rng, d + 0.1, voices=int(rng.integers(1, 3)), vowel=str(rng.choice(["a", "e", "o", "u"])),
                      pitch=pitch, fall=rng.uniform(0.0, 0.25), rise=rng.uniform(0.0, 0.12), dur=d, swell=False, onset=(0.0, 0.03))
        s = int(at * SR)
        out[s:s + len(syl)] += syl[: n - s] * rng.uniform(0.4, 1.0)
    return band(out, 140, 3200) * level


def murmur():
    """Guests waiting for it to begin: low talk, a cough of cloth, the air of a yard."""
    rng = rng_for("murmur")
    L, over = 20.0, 1.5
    x = _babble(rng, L + over, 420, 0.9)
    m = len(x)
    t = np.arange(m) / SR
    x += band(rng.standard_normal(m), 90, 900) * (0.012 + 0.004 * np.sin(2 * np.pi * 0.13 * t))
    return seamless(lowpass(x, 5000), int(L * SR), int(over * SR))


def feast_din():
    """A hall at table: louder talk, a laugh somewhere, cups, a bench scraped."""
    rng = rng_for("feast_din")
    L, over = 22.0, 1.5
    x = _babble(rng, L + over, 760, 1.0, pitch=(100, 300))
    m = len(x)
    for at in (3.1, 9.4, 15.8, 19.6):
        lg = _laugh(rng, 5, 8)
        s = int(at * SR)
        x[s:s + len(lg)] += lg[: m - s] * 0.45
    for _ in range(16):
        s = int(rng.integers(0, m - SR))
        c = _clink(rng)
        x[s:s + len(c)] += c[: m - s] * rng.uniform(0.05, 0.12)
    for at in (6.2, 13.0):
        th = band(drum(110, 0.05, dur=0.3, noise=0.5, rng=rng, drop=0.3, noise_hi=1800), 80, 2500)
        s = int(at * SR)
        x[s:s + len(th)] += th[: m - s] * 0.12
    t = np.arange(m) / SR
    x += band(rng.standard_normal(m), 90, 900) * 0.01
    return seamless(lowpass(x, 6000), int(L * SR), int(over * SR))


def _laugh(rng, pulses, voices):
    """A few people laughing: quick falling syllables, slowing and dying away."""
    out = np.zeros(int(2.0 * SR))
    at = 0.0
    for k in range(pulses):
        ha = B.crowd(rng, 0.2, voices=voices, vowel="a" if k % 2 == 0 else "e", pitch=(170, 330), fall=0.3, dur=0.13, swell=False, onset=(0.0, 0.04))
        s = int(at * SR)
        out[s:s + len(ha)] += ha[: len(out) - s] * (1.0 - 0.13 * k)
        at += 0.17 + 0.02 * k + rng.uniform(0.0, 0.02)
    return out[: int((at + 0.3) * SR)]


def laugh():
    rng = rng_for("laugh")
    a = _laugh(rng, 7, 14)
    b = _laugh(rng, 5, 8)
    return B.tail(B.mix([(a, 0.0, 1.0), (b, 0.22, 0.6)], 1.9), 0.4)


def applause():
    """Hands, coming in together and thinning out."""
    rng = rng_for("applause")
    L = 2.8
    n = int(L * SR)
    out = np.zeros(n)
    for _ in range(900):
        at = min(L - 0.1, abs(rng.normal(0.9, 0.75)))
        k = int(rng.uniform(0.012, 0.03) * SR)
        tt = np.arange(k) / SR
        c = band(rng.standard_normal(k), rng.uniform(900, 1600), rng.uniform(3000, 5200)) * np.exp(-tt / rng.uniform(0.004, 0.009))
        s = int(at * SR)
        out[s:s + k] += c[: n - s] * rng.uniform(0.3, 1.0)
    return B.tail(out, 0.8)


# ------------------------------------------------------------------ the table

def _clink(rng):
    """One cup against another: a few high partials, short."""
    x = B.ring(rng, 1900, 5600, 5, 0.09, 0.45)
    k = int(0.004 * SR)
    x[:k] += band(rng.standard_normal(k), 2000, 9000) * 0.5
    return x


def cups():
    """Cups knocked together down a table, and one set down."""
    rng = rng_for("cups")
    parts = [(_clink(rng), at, g) for at, g in ((0.0, 1.0), (0.07, 0.7), (0.19, 0.85), (0.31, 0.5), (0.42, 0.6))]
    parts.append((band(drum(140, 0.04, dur=0.2, noise=0.4, rng=rng, drop=0.3, noise_hi=2000), 90, 3000), 0.62, 0.5))
    return B.tail(B.mix(parts, 1.1), 0.25)


def pour():
    """A cup filled: the stream, and the note of the cup rising as it fills."""
    rng = rng_for("pour")
    L = 1.3
    n = int(L * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.08, 0, 1) * np.clip((L - t) / 0.25, 0, 1)
    x = band(rng.standard_normal(n), 500, 4200) * 0.25 * env
    for _ in range(90):
        at = rng.uniform(0.03, L - 0.2)
        k = int(rng.uniform(0.015, 0.04) * SR)
        tt = np.arange(k) / SR
        f = (500 + 900 * at / L) * rng.uniform(0.8, 1.5)
        blip = np.sin(2 * np.pi * (f + 1800 * tt) * tt) * np.exp(-tt / 0.012)
        s = int(at * SR)
        x[s:s + k] += blip[: n - s] * rng.uniform(0.1, 0.3)
    return x


def cup_down():
    rng = rng_for("cup_down")
    parts = [(B.ring(rng, 1100, 3200, 4, 0.04, 0.25), 0.0, 0.6),
             (band(drum(170, 0.035, dur=0.2, noise=0.3, rng=rng, drop=0.3, noise_hi=2400), 90, 4000), 0.0, 1.0)]
    return B.tail(B.mix(parts, 0.35), 0.12)


# ------------------------------------------------------------------ the rites

def _swish(rng, length, lo, hi, shape):
    n = int(length * SR)
    t = np.arange(n) / SR
    return band(rng.standard_normal(n), lo, hi) * shape(t)


def cord():
    """A cord drawn through the smoke: the fire flaring under it, the cord's dry rub."""
    rng = rng_for("cord")
    L = 1.1
    flare = _swish(rng, L, 150, 1400, lambda t: np.exp(-((t - 0.3) / 0.22) ** 2) * 0.9)
    rub = _swish(rng, L, 700, 3800, lambda t: np.clip((t - 0.25) / 0.2, 0, 1) * np.clip((L - t) / 0.35, 0, 1) * (0.55 + 0.45 * np.sin(2 * np.pi * 17 * t) ** 2))
    return B.tail(flare + rub * 0.45, 0.25)


def knot():
    """A knot pulled tight: two short pulls and the cord creaking."""
    rng = rng_for("knot")
    parts = []
    for at, g in ((0.0, 0.8), (0.32, 1.0)):
        parts.append((_swish(rng, 0.2, 500, 3200, lambda t: np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.06)), at, 0.5 * g))
        parts.append((band(drum(150, 0.03, dur=0.15, noise=0.3, rng=rng, drop=0.3, noise_hi=1800), 90, 2500), at + 0.09, 0.8 * g))
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    creak = np.sin(2 * np.pi * (310 + 120 * t / 0.22) * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 46 * t))) * np.exp(-t / 0.12)
    parts.append((band(creak, 200, 2400), 0.4, 0.25))
    return B.tail(B.mix(parts, 0.8), 0.15)


def bread():
    """A loaf broken: the crust cracking, the crumb tearing."""
    rng = rng_for("bread")
    L = 0.7
    n = int(L * SR)
    out = _swish(rng, L, 250, 1600, lambda t: np.exp(-((t - 0.28) / 0.16) ** 2) * 0.35)
    for _ in range(46):
        at = abs(rng.normal(0.2, 0.14))
        k = int(rng.uniform(0.004, 0.014) * SR)
        tt = np.arange(k) / SR
        s = int(min(at, L - 0.05) * SR)
        out[s:s + k] += band(rng.standard_normal(k), 1800, 9000) * np.exp(-tt / 0.003) * rng.uniform(0.3, 1.0)
    return B.tail(out, 0.2)


def salt():
    """A pinch of salt let fall."""
    rng = rng_for("salt")
    L = 0.6
    n = int(L * SR)
    out = np.zeros(n)
    for _ in range(110):
        at = abs(rng.normal(0.16, 0.13))
        k = int(0.004 * SR)
        tt = np.arange(k) / SR
        s = int(min(at, L - 0.02) * SR)
        out[s:s + k] += band(rng.standard_normal(k), 4000, 12000) * np.exp(-tt / 0.0012) * rng.uniform(0.2, 1.0)
    return out


def quill():
    """A pen on a contract: three strokes and a flourish."""
    rng = rng_for("quill")
    parts = []
    at = 0.0
    for d in (0.13, 0.1, 0.16, 0.3):
        parts.append((_swish(rng, d, 2200, 9000, lambda t, d=d: np.sin(np.pi * np.clip(t / d, 0, 1)) * (0.6 + 0.4 * np.sin(2 * np.pi * 60 * t) ** 2)), at, 1.0))
        at += d + 0.05
    return B.mix(parts, at + 0.05)


def brush():
    """A brush on a register: two soft strokes, the second long."""
    rng = rng_for("brush")
    a = _swish(rng, 0.28, 900, 5200, lambda t: np.sin(np.pi * np.clip(t / 0.28, 0, 1)) ** 2)
    b = _swish(rng, 0.55, 700, 4200, lambda t: np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 1.5)
    return B.mix([(a, 0.0, 0.8), (b, 0.36, 1.0)], 1.0)


def seal():
    """A seal pressed into wax, and lifted."""
    rng = rng_for("seal")
    parts = [(band(drum(120, 0.05, dur=0.25, noise=0.3, rng=rng, drop=0.4, noise_hi=1500), 70, 2500), 0.0, 1.0),
             (B.ring(rng, 900, 2600, 3, 0.03, 0.15), 0.0, 0.25),
             (_swish(rng, 0.08, 1500, 6000, lambda t: np.exp(-t / 0.02)), 0.3, 0.2)]
    return B.tail(B.mix(parts, 0.5), 0.12)


def lantern():
    """A paper lantern let go: the flame catching, the paper filling, two small bells."""
    rng = rng_for("lantern")
    L = 2.2
    n = int(L * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # The air it takes, rising: bands of noise, each a little higher and later.
    for k in range(5):
        lo = 250 * 1.45 ** k
        out += band(rng.standard_normal(n), lo, lo * 1.9) * np.exp(-((t - 0.25 - 0.22 * k) / 0.3) ** 2) * 0.3
    for at, m, g in ((0.7, 88, 0.12), (1.05, 93, 0.09)):
        b = bell(hz(m), 1.0, rng)
        s = int(at * SR)
        out[s:s + len(b)] += b[: n - s] * g
    return B.tail(out, 0.5)


def door():
    """A door shut on the noise: the wood, the latch."""
    rng = rng_for("door")
    parts = [(band(drum(95, 0.07, dur=0.4, noise=0.35, rng=rng, drop=0.35, noise_hi=1400), 50, 2200), 0.0, 1.0),
             (band(drum(210, 0.02, dur=0.1, noise=0.5, rng=rng, drop=0.2, noise_hi=3000), 150, 4000), 0.012, 0.3),
             (B.ring(rng, 1400, 3600, 3, 0.02, 0.1), 0.2, 0.18),
             (band(drum(320, 0.012, dur=0.06, noise=0.5, rng=rng, drop=0.2, noise_hi=4000), 200, 5000), 0.2, 0.25)]
    return B.tail(B.mix(parts, 0.6), 0.15)


SFX = {"married": married, "heartbeat": heartbeat, "hearth": hearth, "murmur": murmur, "feast_din": feast_din,
       "laugh": laugh, "applause": applause, "cups": cups, "pour": pour, "cup_down": cup_down,
       "cord": cord, "knot": knot, "bread": bread, "salt": salt, "quill": quill, "brush": brush,
       "seal": seal, "lantern": lantern, "door": door}
