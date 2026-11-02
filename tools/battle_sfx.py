"""Battle sound effects, built from recorded metal and wood (the VS Chamber Orchestra's
anvil, brake drum, cymbals, gong, claves, log drums and shaker; CC0) layered with
synthesized bodies, rings and crowds. Run through tools/music.py ("python3 tools/music.py
battle_sfx"), which writes each to assets/audio/sfx/.

Every sound here keeps most of its weight above 250 Hz, so a phone speaker still plays it.

  sword_1..12   blade on blade: a bright ring and a scrape
  shield_1..12  a blow on a shield: a wooden thunk and the boss ringing
  spear_1..12   shafts knocking and a point glancing off
  heavy_1..12   axe and mace: a deep thud and a crash of iron
  melee_bed     the din of a line fighting, as a seamless loop (its volume follows the fight)
  footsteps, hooves         marching and riding loops, rebuilt to carry on a phone
  crossbow, morale_low      rebuilt likewise
  arrows_land_1..3, bolts_land_1..2, javelins_land_1..2   missiles coming down
  warcry_1..3, panic_1..2, cheer_1..2, gasp   crowds of men
  cav_impact, brace, captain_down, quiver_empty
  ram_1..3, gate_break, ladders              the siege
  call_start_<realm>, call_charge_<realm>, call_retreat_<realm>, reinforce_<realm>
"""
import numpy as np

import sampler as S
from music import SR, band, drum, lowpass, pluck, rng_for, seamless, wind

_kits = {}
_KITS = {
    "anvil": ("Percussion", r"Anvil_Hit1"),
    "brake": ("Percussion", r"BrakeDrum1_Hammer"),
    "stick": ("Percussion", r"susCymb1-hitstick"),
    "crash_short": ("Percussion", r"cymbal-crashshort"),
    "cym_clash": ("VSCO 1 Percussion/varMetal/Cymbals/clash", r"crash_hit_(ff|fff)_"),
    "scrape": ("Percussion", r"susCymb1-scrape"),
    "gong_scrape": ("Percussion", r"gongscrape"),
    "smack": ("VSCO 1 Percussion/varMetal/Gong", r"gong_smack"),
    "claves": ("Percussion", r"Claves1_Hit"),
    "log_hi": ("Percussion", r"LogDrumHi"),
    "log_lo": ("Percussion", r"LogDrumLo"),
    "slit": ("VSCO 1 Percussion/varWood/log_drum", r"slitdrum"),
    "shaker": ("VSCO 1 Percussion/varWood/Camo's Shaker", r"shake"),
    "ratchet": ("Percussion", r"Ratchet1-Slow"),
    "bass": ("Percussion", r"BDrumNewhit_v[567]_"),
    "tenor": ("VSCO 1 Percussion/drums/tenor/tenor_lower", r"_f+_"),
    "tenor_hi": ("VSCO 1 Percussion/drums/tenor/tenor_higher", r"_f+_"),
}


def kit(name):
    if name not in _kits:
        _kits[name] = S.Kit(*_KITS[name])
    return _kits[name]


def hit(name, rng, shift=0.0, length=None, gain=1.0):
    return kit(name).hit(rng, shift=shift, length=length) * gain


def mix(parts, length):
    """[(sound, at seconds, gain)] laid into one buffer `length` seconds long."""
    out = np.zeros(int(length * SR))
    for x, at, g in parts:
        s = max(0, int(at * SR))
        if s >= len(out):
            continue
        n = min(len(x), len(out) - s)
        out[s:s + n] += x[:n] * g
    return out


def tail(x, seconds):
    k = min(len(x), int(seconds * SR))
    x = x.copy()
    x[-k:] *= np.linspace(1.0, 0.0, k) ** 2
    return x


def norm(x, peak=0.89):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def ring(rng, lo, hi, n_partials, decay, length):
    """Inharmonic partials, as a struck blade rings."""
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for _ in range(n_partials):
        f = rng.uniform(lo, hi)
        out += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / (decay * rng.uniform(0.6, 1.4))) * rng.uniform(0.3, 1.0)
    return out / n_partials


def thud(rng, freq, decay, length, slap=0.6):
    """A body blow: a falling sine with a mid-range slap of noise, so it carries on a phone."""
    x = drum(freq, decay, dur=length, noise=slap, rng=rng, drop=0.8, noise_hi=2500)
    return band(x, 120, 6000)


# ------------------------------------------------------------------ the clash banks

def sword(i):
    rng = rng_for("sword_%d" % i)
    L = 0.42
    metal = hit(rng.choice(["anvil", "brake", "stick"]), rng, shift=rng.uniform(3, 10), length=0.3)
    parts = [(band(metal, 600, 12000), 0.0, 1.0),
             (ring(rng, 2200, 6200, 6, 0.09, L), 0.0, 0.5),
             (band(rng.standard_normal(int(0.02 * SR)), 2000, 9000), 0.0, 0.4)]
    if rng.uniform() < 0.5:   # a scrape as the blades slide
        parts.append((band(hit("scrape", rng, shift=rng.uniform(2, 6), length=0.18), 1500, 9000), 0.03, 0.35))
    if rng.uniform() < 0.4:   # a quick second blow
        parts.append((band(hit("brake", rng, shift=rng.uniform(5, 11), length=0.2), 900, 12000), rng.uniform(0.09, 0.16), 0.55))
    return norm(tail(mix(parts, L), 0.1))


def shield(i):
    rng = rng_for("shield_%d" % i)
    L = 0.4
    wood = hit(rng.choice(["log_lo", "slit"]), rng, shift=rng.uniform(-7, -2), length=0.3)
    boss = hit("brake", rng, shift=rng.uniform(-2, 3), length=0.25)
    parts = [(band(wood, 180, 6000), 0.0, 1.0),
             (thud(rng, rng.uniform(140, 200), 0.05, L, slap=0.9), 0.0, 0.7),
             (band(boss, 800, 8000), 0.005, rng.uniform(0.15, 0.35))]
    if rng.uniform() < 0.5:
        parts.append((band(hit("anvil", rng, shift=rng.uniform(4, 9), length=0.2), 1200, 10000), rng.uniform(0.05, 0.12), 0.35))
    return norm(tail(mix(parts, L), 0.1))


def spear(i):
    rng = rng_for("spear_%d" % i)
    L = 0.38
    parts = []
    knocks = 2 if rng.uniform() < 0.6 else 3
    t = 0.0
    for k in range(knocks):
        parts.append((band(hit(rng.choice(["claves", "log_hi"]), rng, shift=rng.uniform(-9, -3), length=0.15), 250, 7000), t, 1.0 - 0.2 * k))
        t += rng.uniform(0.03, 0.08)
    parts.append((band(hit("stick", rng, shift=rng.uniform(6, 12), length=0.12), 2000, 12000), rng.uniform(0.0, 0.05), 0.4))
    parts.append((thud(rng, rng.uniform(180, 240), 0.03, L, slap=0.5), 0.0, 0.3))
    return norm(tail(mix(parts, L), 0.1))


def heavy(i):
    rng = rng_for("heavy_%d" % i)
    L = 0.55
    parts = [(thud(rng, rng.uniform(90, 130), 0.09, L, slap=1.0), 0.0, 1.0),
             (band(hit("smack", rng, shift=rng.uniform(-3, 2), length=0.4), 300, 8000), 0.0, 0.7),
             (band(hit("anvil", rng, shift=rng.uniform(-4, 1), length=0.3), 500, 10000), 0.01, 0.55),
             (band(hit("tenor", rng, shift=rng.uniform(-2, 2), length=0.3), 150, 6000), 0.0, 0.5)]
    if rng.uniform() < 0.5:   # mail rattling
        parts.append((band(hit("shaker", rng, shift=rng.uniform(-3, 3), length=0.2), 2000, 12000), 0.04, 0.35))
    return norm(tail(mix(parts, L), 0.15))


BANKS = {"sword": sword, "shield": shield, "spear": spear, "heavy": heavy}
BANK_SIZE = 12


def melee_bed():
    """The din of lines locked together: blows near and far, shouts and grunts under them,
    mail jingling. Seamless, eight seconds."""
    rng = rng_for("melee_bed")
    L = 8.0
    over = 1.0
    n = int((L + over) * SR)
    out = np.zeros(n)
    pool = [fn(k) for fn in BANKS.values() for k in range(1, 7)]
    t = 0.0
    while t < L + over - 0.6:
        x = pool[int(rng.integers(len(pool)))]
        far = rng.uniform()
        g = 0.12 + 0.3 * (1 - far)
        x = lowpass(x, 3000 + 7000 * (1 - far)) if far > 0.5 else x
        s = int(t * SR)
        out[s:s + len(x)] += x[: n - s] * g
        t += rng.exponential(0.07)
    out += crowd(rng, L + over, voices=24, vowel="a", pitch=(95, 170), swell=False) * 0.25
    for _ in range(int((L + over) * 3)):
        s = int(rng.uniform(0, L + over - 0.3) * SR)
        j = band(hit("shaker", rng, shift=rng.uniform(-2, 4), length=0.25), 2500, 12000) * 0.08
        out[s:s + len(j)] += j[: n - s]
    return norm(seamless(out, int(L * SR), int(over * SR)), 0.8)


# ------------------------------------------------------------------ crowds

VOWELS = {  # formants (Hz, bandwidth)
    "a": [(730, 110), (1150, 120), (2500, 160)],
    "o": [(520, 90), (880, 100), (2400, 160)],
    "u": [(330, 80), (800, 100), (2300, 160)],
    "e": [(530, 90), (1850, 120), (2500, 160)],
}


def formant(x, vowel):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    shape = np.zeros_like(f)
    for k, (fc, bw) in enumerate(VOWELS[vowel]):
        shape += (1.0 / (1 + k * 0.7)) / (1 + ((f - fc) / bw) ** 2)
    return np.fft.irfft(spec * shape, len(x))


def crowd(rng, length, voices=30, vowel="a", pitch=(110, 200), swell=True, rise=0.0, onset=(0.0, 0.12),
          dur=None, fall=0.0):
    """Many men shouting together: each a buzzing voice with its own pitch, vibrato and
    timing, all shaped into a vowel."""
    n = int(length * SR)
    t = np.arange(n) / SR
    raw = np.zeros(n)
    for _ in range(voices):
        f0 = rng.uniform(*pitch)
        start = rng.uniform(*onset)
        d = (dur or length) * rng.uniform(0.75, 1.0)
        contour = 1.0 + rise * np.clip((t - start) / max(d, 0.1), 0, 1) - fall * np.clip((t - start) / max(d, 0.1), 0, 1) ** 2
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * rng.uniform(4.5, 7.0) * t + rng.uniform(0, 6))
        jitter = 1.0 + 0.01 * lowpass(rng.standard_normal(n), 20)
        f = f0 * contour * vib * jitter
        phase = np.cumsum(f) / SR
        buzz = 2.0 * (phase % 1.0) - 1.0
        env = np.clip((t - start) / 0.08, 0, 1) * np.clip((start + d - t) / 0.25, 0, 1)
        if swell:
            env *= np.clip((t - start) / (d * 0.6), 0.25, 1.0)
        raw += buzz * env * rng.uniform(0.5, 1.0)
    raw += band(rng.standard_normal(n), 800, 4000) * 0.15 * voices / 10 * (np.abs(raw).mean() > 0)
    return formant(raw, vowel) / max(1.0, voices ** 0.5)


def warcry(i):
    rng = rng_for("warcry_%d" % i)
    L = 1.8
    x = crowd(rng, L, voices=36, vowel="a", pitch=(120, 210), rise=0.18, onset=(0.0, 0.18), dur=1.5)
    x = mix([(x, 0.0, 1.0), (band(hit("shaker", rng, length=0.4), 2000, 10000), 0.0, 0.05)], L)
    return norm(tail(x, 0.35))


def panic(i):
    rng = rng_for("panic_%d" % i)
    L = 1.6
    out = np.zeros(int(L * SR))
    for k in range(9):
        at = rng.uniform(0.0, 1.0)
        v = rng.choice(["a", "e", "o"])
        x = crowd(rng, 0.6, voices=3, vowel=v, pitch=(200, 340), fall=0.35, dur=0.5, swell=False)
        s = int(at * SR)
        out[s:s + len(x)] += x[: len(out) - s] * rng.uniform(0.6, 1.0)
    return norm(tail(out, 0.3))


def cheer(i):
    rng = rng_for("cheer_%d" % i)
    L = 2.4
    hu = crowd(rng, 0.5, voices=30, vowel="u", pitch=(120, 200), dur=0.35, swell=False)
    rah = crowd(rng, L - 0.4, voices=40, vowel="a", pitch=(140, 260), rise=0.12, dur=1.7)
    out = mix([(hu, 0.0, 0.7), (rah, 0.32, 1.0)], L)
    return norm(tail(out, 0.5))


def gasp():
    rng = rng_for("gasp")
    x = crowd(rng, 1.0, voices=24, vowel="o", pitch=(150, 260), fall=0.25, dur=0.7, swell=False)
    return norm(tail(x, 0.3), 0.6)


# ------------------------------------------------------------------ movement, missiles

def footsteps():
    """A company marching: bootfalls with the crunch of earth and grit, and mail jingling,
    so it carries on a phone. Seamless, one second."""
    rng = rng_for("footsteps2")
    L, over = 1.0, 0.25
    parts = []
    for at in np.arange(0.0, L + over, 0.125):
        jit = at + rng.uniform(-0.012, 0.012)
        crunch = band(rng.standard_normal(int(0.09 * SR)), 350, 3200) * np.exp(-np.arange(int(0.09 * SR)) / SR / 0.03)
        parts += [(crunch, jit, rng.uniform(0.35, 0.55)),
                  (thud(rng, rng.uniform(150, 210), 0.025, 0.1, slap=0.8), jit, 0.35)]
        if rng.uniform() < 0.5:
            parts.append((band(hit("shaker", rng, shift=rng.uniform(-2, 3), length=0.12), 2500, 11000), jit + 0.01, 0.12))
    x = mix(parts, L + over)
    return seamless(x, int(L * SR), int(over * SR))


def hooves():
    """Horses at the canter: the three-beat clop on hard ground, harness jingling."""
    rng = rng_for("hooves2")
    L, over = 1.0, 0.25
    parts = []
    for bar in np.arange(0.0, L + over, 0.5):
        for k, off in enumerate((0.0, 0.09, 0.18)):
            at = bar + off + rng.uniform(-0.01, 0.01)
            parts.append((band(hit(rng.choice(["claves", "log_hi"]), rng, shift=rng.uniform(-14, -9), length=0.12), 250, 5000), at, 0.5))
            parts.append((thud(rng, rng.uniform(120, 160), 0.03, 0.12, slap=0.9), at, 0.4))
        parts.append((band(hit("shaker", rng, shift=rng.uniform(0, 4), length=0.15), 3000, 12000), bar + 0.3, 0.12))
    x = mix(parts, L + over)
    return seamless(x, int(L * SR), int(over * SR))


def crossbow():
    rng = rng_for("crossbow2")
    L = 0.5
    twang = pluck(220.0 * rng.uniform(0.95, 1.05), 0.4, bright=0.75, decay=0.12, rng=rng)
    whoosh = band(rng.standard_normal(int(0.3 * SR)), 1500, 6000) * np.exp(-np.arange(int(0.3 * SR)) / SR / 0.08)
    parts = [(band(hit("claves", rng, shift=-4, length=0.1), 400, 8000), 0.0, 0.9),
             (twang, 0.0, 0.7), (whoosh, 0.02, 0.35)]
    return norm(tail(mix(parts, L), 0.1))


def morale_low():
    """A wavering company: a low horn falling a step, with a soft drum. Pitched where a
    phone still sounds it."""
    rng = rng_for("morale_low2")
    from music import brass
    L = 1.7
    parts = [(brass(196.0, 0.55, attack=0.05, release=0.2, rng=rng), 0.0, 0.5),
             (brass(174.6, 0.9, attack=0.05, release=0.4, rng=rng), 0.55, 0.5),
             (band(hit("tenor", rng, shift=-2, length=0.6), 150, 5000), 0.0, 0.6)]
    return norm(tail(mix(parts, L), 0.3), 0.8)


def _rain(rng, kind, count, spread, L):
    parts = []
    for _ in range(count):
        at = rng.uniform(0.0, spread)
        if kind == "arrows":
            if rng.uniform() < 0.55:   # into shields and wood
                x = band(hit(rng.choice(["log_hi", "claves"]), rng, shift=rng.uniform(-6, 2), length=0.1), 400, 9000)
            else:                       # into earth
                x = band(rng.standard_normal(int(0.06 * SR)), 300, 2500) * np.exp(-np.arange(int(0.06 * SR)) / SR / 0.015)
            parts.append((x, at, rng.uniform(0.3, 0.7)))
        elif kind == "bolts":
            parts.append((band(hit("claves", rng, shift=rng.uniform(-2, 4), length=0.08), 800, 12000), at, rng.uniform(0.6, 1.0)))
            parts.append((band(hit("stick", rng, shift=rng.uniform(4, 9), length=0.08), 2000, 12000), at, 0.25))
        else:  # javelins
            parts.append((band(hit(rng.choice(["log_lo", "slit"]), rng, shift=rng.uniform(-4, 1), length=0.2), 200, 7000), at, rng.uniform(0.6, 1.0)))
            parts.append((thud(rng, 170, 0.04, 0.2, slap=0.8), at, 0.4))
    return norm(tail(mix(parts, L), 0.12))


def arrows_land(i):
    return _rain(rng_for("arrows_land_%d" % i), "arrows", 18, 0.55, 0.8)


def bolts_land(i):
    return _rain(rng_for("bolts_land_%d" % i), "bolts", 7, 0.3, 0.55)


def javelins_land(i):
    return _rain(rng_for("javelins_land_%d" % i), "javelins", 5, 0.35, 0.7)


# ------------------------------------------------------------------ moments

def cav_impact():
    rng = rng_for("cav_impact")
    L = 1.6
    parts = []
    t = 0.0
    gap = 0.11
    while t < 0.75:   # hooves thundering in, closing up
        parts.append((band(hit(rng.choice(["claves", "log_hi"]), rng, shift=rng.uniform(-14, -8), length=0.12), 250, 5000), t, 0.45 + t * 0.5))
        parts.append((thud(rng, rng.uniform(110, 150), 0.04, 0.15, slap=1.0), t, 0.4 + t * 0.4))
        t += gap
        gap = max(0.05, gap * 0.92)
    for k in range(4):   # the crash into the line
        parts.append((heavy(k + 1), 0.78 + rng.uniform(0, 0.08), 0.8))
        parts.append((shield(k + 1), 0.8 + rng.uniform(0, 0.1), 0.6))
    parts.append((band(hit("cym_clash", rng, shift=-3, length=0.6), 600, 10000), 0.8, 0.45))
    parts.append((warcry(1), 0.78, 0.4))
    return norm(tail(mix(parts, L), 0.3))


def brace():
    rng = rng_for("brace")
    L = 0.8
    parts = [(shield(k + 1), k * 0.03 + rng.uniform(0, 0.015), 0.55) for k in range(7)]
    parts.append((crowd(rng, 0.35, voices=20, vowel="a", pitch=(110, 170), dur=0.25, swell=False), 0.05, 0.9))
    return norm(tail(mix(parts, L), 0.2))


def captain_down():
    rng = rng_for("captain_down")
    L = 1.4
    parts = [(thud(rng, 110, 0.12, 0.6, slap=1.0), 0.0, 1.0),
             (band(hit("cym_clash", rng, shift=-6, length=0.5), 500, 9000), 0.02, 0.4),
             (band(hit("shaker", rng, shift=-3, length=0.3), 2000, 10000), 0.03, 0.4),
             (gasp(), 0.15, 0.8)]
    return norm(tail(mix(parts, L), 0.3))


def quiver_empty():
    rng = rng_for("quiver_empty")
    L = 0.6
    parts = [(band(hit("shaker", rng, shift=2, length=0.25), 1500, 10000), 0.0, 0.7)]
    for k in range(3):
        parts.append((band(hit("claves", rng, shift=rng.uniform(4, 9), length=0.06), 1000, 10000), 0.08 + k * 0.07, 0.4))
    return norm(tail(mix(parts, L), 0.15), 0.75)


def ram(i):
    rng = rng_for("ram_%d" % i)
    L = 1.2
    parts = [(band(hit("bass", rng, shift=rng.uniform(-3, 0), length=0.6), 140, 5000), 0.0, 0.8),
             (band(hit("log_lo", rng, shift=rng.uniform(-7, -4), length=0.5), 230, 6000), 0.0, 0.9),
             (band(hit("slit", rng, shift=rng.uniform(-6, -3), length=0.4), 220, 6000), 0.005, 0.6),
             (thud(rng, 150, 0.12, 0.8, slap=1.4), 0.0, 0.35),
             (band(hit("ratchet", rng, shift=rng.uniform(-12, -8), length=0.35), 300, 4000), 0.12, 0.25),
             (band(rng.standard_normal(int(0.5 * SR)), 400, 3500) * np.exp(-np.arange(int(0.5 * SR)) / SR / 0.12), 0.05, 0.12)]
    return norm(tail(band(mix(parts, L), 160, 16000), 0.4))


def gate_break():
    rng = rng_for("gate_break")
    L = 2.8
    parts = [(ram(k + 1), k * 0.12, 0.7) for k in range(3)]
    for k in range(8):   # timbers giving way
        parts.append((band(hit(rng.choice(["claves", "log_lo", "slit"]), rng, shift=rng.uniform(-12, -4), length=0.3), 200, 7000),
                      0.25 + rng.uniform(0, 0.9), rng.uniform(0.3, 0.6)))
    parts.append((band(hit("smack", rng, shift=-5, length=1.2), 150, 8000), 0.3, 0.6))
    parts.append((band(hit("cym_clash", rng, shift=-4, length=1.0), 500, 9000), 0.32, 0.35))
    rumble = band(rng.standard_normal(int(2.2 * SR)), 150, 1500) * np.exp(-np.arange(int(2.2 * SR)) / SR / 0.7)
    parts.append((rumble, 0.3, 0.3))
    parts.append((warcry(2), 0.9, 0.45))
    return norm(tail(mix(parts, L), 0.6))


def ladders():
    rng = rng_for("ladders")
    L = 1.3
    parts = []
    for k in range(4):
        at = k * 0.22 + rng.uniform(0, 0.06)
        parts.append((band(hit(rng.choice(["log_hi", "slit"]), rng, shift=rng.uniform(-8, -3), length=0.25), 250, 7000), at, 0.8))
        parts.append((band(hit("scrape", rng, shift=rng.uniform(-6, -2), length=0.2), 600, 8000), at + 0.03, 0.25))
        parts.append((band(hit("claves", rng, shift=rng.uniform(-6, 0), length=0.08), 600, 9000), at + 0.08, 0.35))
    return norm(tail(mix(parts, L), 0.3))


# ------------------------------------------------------------------ each realm's calls

def _horn_line(notes, rng, inst_name="horn", gain=1.0):
    import orchestral as O
    L = sum(d for _, d in notes) + 0.8
    out = np.zeros(int(L * SR))
    t = 0.0
    for m, d in notes:
        x = O.inst(inst_name).note(m, d * 0.95, rng, release=0.35)
        s = int(t * SR)
        out[s:s + len(x)] += x[: len(out) - s] * gain
        t += d
    return out


def _synth_line(voice, notes, rng):
    L = sum(d for _, d in notes) + 0.6
    out = np.zeros(int(L * SR))
    t = 0.0
    for m, d in notes:
        x = voice(440.0 * 2 ** ((m - 69) / 12), d, rng)
        s = int(t * SR)
        out[s:s + len(x)] += x[: len(out) - s]
        t += d
    return out


def zurna(f, s, r):
    return wind(f, s * 0.94, breath=0.18, vib=0.006, vib_rate=5.5, bend=-0.4, attack=0.03,
                harm=(1.0, 0.75, 0.6, 0.45, 0.3, 0.2), rng=r)


def conch(f, s, r):
    """The horagai: a great shell blown, breathy, sliding up into its note."""
    return wind(f, s * 0.96, breath=0.45, vib=0.004, vib_rate=3.5, bend=-2.5, attack=0.15,
                harm=(1.0, 0.6, 0.3, 0.15), rng=r)


CALLS = {
    "vardish": {"start": [(50, 0.5), (57, 1.4)], "charge": [(57, 0.18), (57, 0.18), (62, 0.18), (65, 0.9)],
                "retreat": [(62, 0.5), (57, 0.5), (50, 1.2)]},
    "kharzani": {"start": [(62, 0.3), (63, 0.2), (66, 0.3), (69, 1.2)], "charge": [(69, 0.15), (70, 0.15), (69, 0.15), (74, 0.9)],
                 "retreat": [(69, 0.4), (66, 0.4), (63, 0.4), (62, 1.0)]},
    "ryumon": {"start": [(57, 1.6)], "charge": [(57, 0.4), (64, 1.0)], "retreat": [(64, 0.6), (57, 1.2)]},
}


def call(realm, which):
    rng = rng_for("call_%s_%s" % (realm, which))
    notes = CALLS[realm][which]
    if realm == "vardish":
        x = _horn_line(notes, rng, "trumpet" if which == "charge" else "horn")
        drums = [(band(hit("tenor", rng, length=0.5), 150, 6000), 0.0, 0.5)]
    elif realm == "kharzani":
        x = _synth_line(zurna, notes, rng) * 0.6
        drums = [(band(hit("tenor", rng, shift=-3, length=0.5), 150, 6000), k * 0.25, 0.6) for k in range(3)]
    else:
        x = _synth_line(conch, notes, rng) * 0.7
        drums = [(band(hit("bass", rng, shift=-2, length=0.9), 120, 5000), 0.0, 0.7), (band(hit("tenor", rng, shift=-5, length=0.6), 120, 6000), 0.0, 0.6)]
    L = len(x) / SR + 0.3
    return norm(tail(mix([(norm(x), 0.0, 0.8)] + drums, L), 0.4))


def reinforce(realm):
    """Their horn, far off: more men coming."""
    x = call(realm, "start")
    return norm(tail(lowpass(x, 2500), 0.4), 0.7)


SFX = {"melee_bed": melee_bed, "footsteps": footsteps, "hooves": hooves, "crossbow": crossbow, "morale_low": morale_low,
       "gasp": gasp, "cav_impact": cav_impact, "brace": brace, "captain_down": captain_down,
       "quiver_empty": quiver_empty, "gate_break": gate_break, "ladders": ladders}
for _bank, _fn in BANKS.items():
    for _i in range(1, BANK_SIZE + 1):
        SFX["%s_%d" % (_bank, _i)] = (lambda f, i: lambda: f(i))(_fn, _i)
for _name, _fn, _n in (("arrows_land", arrows_land, 3), ("bolts_land", bolts_land, 2), ("javelins_land", javelins_land, 2),
                       ("warcry", warcry, 3), ("panic", panic, 2), ("cheer", cheer, 2), ("ram", ram, 3)):
    for _i in range(1, _n + 1):
        SFX["%s_%d" % (_name, _i)] = (lambda f, i: lambda: f(i))(_fn, _i)
for _r in ("vardish", "kharzani", "ryumon"):
    for _w in ("start", "charge", "retreat"):
        SFX["call_%s_%s" % (_w, _r)] = (lambda r, w: lambda: call(r, w))(_r, _w)
    SFX["reinforce_" + _r] = (lambda r: lambda: reinforce(r))(_r)
