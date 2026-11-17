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
from music import SR, band, drum, rng_for


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


SFX = {"provisions": provisions, "muster": muster, "drill": drill, "oath": oath, "build": build, "banner": banner,
       "purse": purse, "torch": torch, "tear": tear}
