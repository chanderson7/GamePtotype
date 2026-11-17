"""The everyday sounds outside battle: what a town, a camp and the road do when you act.

Six sounds did most of this work (a page, coins, a click, a horn, a cheer, a bell), so
buying grain, hiring a company, swearing an oath and building a granary all chinked alike.
Each kind of act has its own now:

  provisions  grain bought: a sack set down, and the grain running
  muster      men hired, sent or stationed: boots falling in, a rattle of mail
  drill       a company trained: wooden blades knocked together, a drum tap
  oath        fealty sworn, a hero or a lord taking your service: a blade drawn and rung
  build       something built or mended: a hammer on timber, a saw
  banner      a holding granted or exchanged: cloth shaken out and snapping
  purse       silver in weight (a ransom, tribute, reparations): a bag of coin set down
  torch       a village burned: fire taking a roof
  tear        a contract ended or land given up: paper torn across

    python3 tools/music.py everyday
"""
import numpy as np

import battle_sfx as B
from music import SR, band, drum, rng_for, seamless


def _swish(rng, length, lo, hi, shape):
    n = int(length * SR)
    t = np.arange(n) / SR
    return band(rng.standard_normal(n), lo, hi) * shape(t)


def provisions():
    rng = rng_for("provisions")
    parts = [(band(drum(85, 0.07, dur=0.35, noise=0.6, rng=rng, drop=0.4, noise_hi=1500), 50, 2500), 0.0, 1.0),
             (_swish(rng, 0.12, 300, 2500, lambda t: np.exp(-t / 0.04)), 0.0, 0.5)]
    # The grain running: a hiss of many small grains, thinning out.
    L = 0.7
    n = int(L * SR)
    grain = np.zeros(n)
    for _ in range(260):
        at = abs(rng.normal(0.12, 0.2))
        k = int(0.005 * SR)
        tt = np.arange(k) / SR
        s = int(min(at, L - 0.02) * SR)
        grain[s:s + k] += band(rng.standard_normal(k), 2500, 9000) * np.exp(-tt / 0.0015) * rng.uniform(0.2, 1.0)
    parts.append((grain, 0.22, 0.5))
    return B.tail(B.mix(parts, 1.0), 0.2)


def muster():
    rng = rng_for("muster")
    parts = []
    for k in range(6):
        at = 0.02 + k * 0.085 + rng.uniform(0, 0.02)
        parts.append((band(drum(rng.uniform(95, 130), 0.03, dur=0.14, noise=0.5, rng=rng, drop=0.3, noise_hi=1800), 70, 3000), at, rng.uniform(0.6, 1.0)))
    parts.append((band(drum(100, 0.04, dur=0.2, noise=0.5, rng=rng, drop=0.3, noise_hi=1800), 70, 3000), 0.62, 1.0))
    for at in (0.1, 0.3, 0.62):
        parts.append((B.ring(rng, 3000, 8000, 6, 0.03, 0.15), at, 0.12))
    return B.tail(B.mix(parts, 0.95), 0.2)


def drill():
    rng = rng_for("drill")
    parts = []
    for at, g in ((0.0, 0.9), (0.2, 1.0), (0.38, 0.8)):
        parts.append((band(drum(rng.uniform(380, 520), 0.018, dur=0.12, noise=0.45, rng=rng, drop=0.1, noise_hi=5000), 250, 6000), at, g))
        parts.append((B.ring(rng, 900, 2400, 3, 0.02, 0.1), at, 0.2 * g))
    parts.append((B.hit("tenor_hi", rng, length=0.3), 0.56, 0.5))
    return B.tail(B.mix(parts, 0.95), 0.2)


def oath():
    rng = rng_for("oath")
    # The blade leaving the scabbard, then ringing as it's raised.
    draw = _swish(rng, 0.32, 2500, 9000, lambda t: np.clip(t / 0.25, 0, 1) ** 2 * np.clip((0.32 - t) / 0.03, 0, 1))
    ring = B.ring(rng, 1800, 5200, 7, 0.5, 1.4)
    parts = [(draw, 0.0, 0.5), (ring, 0.3, 1.0), (band(drum(70, 0.12, dur=0.5, noise=0.1, rng=rng, drop=0.4), 40, 400), 0.3, 0.6)]
    return B.tail(B.mix(parts, 1.7), 0.6)


def build():
    rng = rng_for("build")
    parts = []
    for at, g in ((0.0, 0.9), (0.24, 1.0), (0.48, 0.8)):
        parts.append((band(drum(rng.uniform(170, 210), 0.035, dur=0.2, noise=0.4, rng=rng, drop=0.2, noise_hi=3000), 100, 5000), at, g))
        parts.append((B.ring(rng, 2200, 5000, 3, 0.025, 0.1), at, 0.25 * g))
    saw = _swish(rng, 0.5, 900, 4500, lambda t: (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 3.4 * t))) * (0.55 + 0.45 * np.sin(2 * np.pi * 95 * t) ** 2) * np.clip((0.5 - t) / 0.1, 0, 1))
    parts.append((saw, 0.72, 0.4))
    return B.tail(B.mix(parts, 1.3), 0.2)


def banner():
    rng = rng_for("banner")
    parts = []
    for at, d, g in ((0.0, 0.3, 0.7), (0.32, 0.16, 1.0), (0.52, 0.22, 0.6)):
        parts.append((_swish(rng, d, 180, 2600, lambda t, d=d: np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2), at, g))
    parts.append((band(drum(140, 0.02, dur=0.1, noise=0.8, rng=rng, drop=0.2, noise_hi=4000), 100, 5000), 0.42, 0.7))
    return B.tail(B.mix(parts, 0.9), 0.25)


def purse():
    rng = rng_for("purse")
    parts = [(band(drum(110, 0.05, dur=0.3, noise=0.4, rng=rng, drop=0.35, noise_hi=1800), 70, 2500), 0.0, 1.0)]
    for _ in range(18):
        parts.append((B.ring(rng, 2400, 6500, 3, rng.uniform(0.02, 0.05), 0.15), abs(rng.normal(0.03, 0.09)), rng.uniform(0.12, 0.35)))
    return B.tail(B.mix(parts, 0.7), 0.25)


def torch():
    rng = rng_for("torch")
    L = 2.0
    n = int(L * SR)
    t = np.arange(n) / SR
    roar = band(rng.standard_normal(n), 80, 1400) * np.clip(t / 0.5, 0, 1) * np.clip((L - t) / 0.8, 0, 1) * (0.7 + 0.3 * np.sin(2 * np.pi * 2.3 * t))
    out = roar * 0.6
    for _ in range(90):
        s = int(rng.uniform(0.1, L - 0.2) * SR)
        k = int(rng.uniform(0.006, 0.03) * SR)
        tt = np.arange(k) / SR
        out[s:s + k] += band(rng.standard_normal(k), 1200, 8000) * np.exp(-tt / 0.005) * rng.uniform(0.1, 0.4)
    return B.tail(out, 0.6)


def tear():
    rng = rng_for("tear")
    L = 0.55
    n = int(L * SR)
    t = np.arange(n) / SR
    rip = band(rng.standard_normal(n), 1500, 9000) * np.clip(t / 0.04, 0, 1) * np.clip((L - 0.1 - t) / 0.08, 0, 1).clip(0, 1)
    rip *= 0.5 + 0.5 * (np.sin(2 * np.pi * (60 + 220 * t) * t) > 0)
    return B.tail(rip, 0.1)


def _trot(rng, length, over):
    """Your horse at a trot on a packed road: two beats to the stride, each a pair of
    hooves landing a hair apart, a clip and then a clop, with weight under them; tack
    jingling, the saddle creaking now and then."""
    beat = 0.4
    parts = []
    k = 0
    at = 0.0
    while at < length + over:
        high = k % 2 == 0
        for j, late in enumerate((0.0, 0.028)):
            t0 = at + late + rng.uniform(-0.008, 0.008)
            knock = band(B.hit("log_hi" if high else "log_lo", rng, shift=rng.uniform(-16, -13) if high else rng.uniform(-13, -10), length=0.2), 90, 1700)
            parts.append((knock, t0, (0.6 if j == 0 else 0.4) * rng.uniform(0.85, 1.0)))
            parts.append((B.thud(rng, rng.uniform(52, 72), 0.07, 0.24, slap=0.25), t0, 1.0 if j == 0 else 0.65))
            grit = _swish(rng, 0.07, 400, 2200, lambda t: np.exp(-t / 0.022))
            parts.append((grit, t0 + 0.004, 0.08))
        if k % 2 == 1:
            parts.append((band(B.hit("shaker", rng, shift=rng.uniform(0, 4), length=0.12), 3500, 12000), at + 0.1, 0.03))
        if k % 8 == 5:
            n = int(0.22 * SR)
            t = np.arange(n) / SR
            creak = np.sin(2 * np.pi * (240 + 90 * t / 0.22) * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * t))) * np.sin(np.pi * t / 0.22)
            parts.append((band(creak, 180, 1800), at + 0.15, 0.07))
        at += beat
        k += 1
    return B.mix(parts, length + over)


def ride():
    """Riding on the map, the company mostly mounted behind you."""
    rng = rng_for("ride")
    L, over = 8.0, 0.4
    return seamless(_trot(rng, L, over), int(L * SR), int(over * SR))


def ride_column():
    """Riding on the map at the head of a column on foot: your horse, and their boots
    behind it, quieter, with their mail."""
    rng = rng_for("ride_column")
    L, over = 8.0, 0.4
    x = _trot(rng, L, over)
    parts = [(x, 0.0, 1.0)]
    at = 0.0
    while at < L + over:
        t0 = at + rng.uniform(-0.015, 0.015)
        crunch = _swish(rng, 0.09, 350, 3000, lambda t: np.exp(-t / 0.03))
        parts.append((crunch, t0, rng.uniform(0.1, 0.16)))
        parts.append((B.thud(rng, rng.uniform(150, 200), 0.025, 0.1, slap=0.8), t0, 0.1))
        at += 0.2
    return seamless(B.mix(parts, L + over), int(L * SR), int(over * SR))


SFX = {"ride": ride, "ride_column": ride_column, "provisions": provisions, "muster": muster, "drill": drill, "oath": oath, "build": build, "banner": banner,
       "purse": purse, "torch": torch, "tear": tear}
