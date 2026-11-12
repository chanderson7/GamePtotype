"""Authoring tool: dresses Bannerfall's painted romance portraits for their wedding.

Edda, Farah and Kaede were painted once per expression, in everyday clothes. This paints
their wedding dress over those same paintings, after what brides of the times their
cultures draw on wore: new cloth (a veil, a hood), loose hair, a crown, worked in code
with the paintings' light (from the upper left), dark outlines and flat tones; and their
own garments re-dyed by their own light and shade, so the painter's folds stay.

  Edda   (a northern court)  her best gown in deep woad blue, a gold-embroidered border
         at the neckline; her hair unbound under her braided crown, falling in waves over
         both shoulders, as a bride's was; a gold bridal crown set with garnets
  Farah  (a desert court)    crimson silk, its bands worked in bright gold; a sheer ivory
         veil set back on her crown and falling past her shoulders, bordered in gold; a
         circlet of gold coins with a garnet on her brow, gold earrings, a coin necklace
  Kaede  (an island court)   all in white: white robes with their pattern woven white on
         white, a red inner collar; her hair as she wears it, the pin through her knot
         lacquered red and a small gold comb set behind her crown

Writes assets/portraits/<who>_wedding_<expression>.png for the expressions the wedding
uses, and assets/portraits/face/<who>_wedding_hair.png, where the shader may swing hair
on the dressed painting (Edda's loose locks, Kaede's as every day, nothing under a veil). Then run
tools/portrait_faces.py, which gives the dressed paintings their blinks and glances.

    python3 tools/portrait_wedding.py

Needs Pillow and numpy.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
WHO = ["edda", "farid", "kaede"]
EXPRESSIONS = ["neutral", "warm", "amused"]
NECK = {"edda": 236, "farid": 236, "kaede": 228}

GOLD = [(0.0, (92, 54, 18)), (0.4, (176, 122, 40)), (0.75, (226, 180, 82)), (1.0, (255, 232, 160))]
GOLD_LIGHT = (252, 226, 150)
GOLD_MID = (214, 166, 72)
GOLD_DARK = (120, 80, 28)
GARNET = (170, 22, 38)


# ---------------------------------------------------------------- drawing
def load(who, expression):
    return np.array(Image.open(os.path.join(PORTRAITS, "%s_%s.png" % (who, expression))).convert("RGBA")).astype(float)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def grow(m, n=1):
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m


def blur(f, n=2):
    for _ in range(n):
        f = (f + np.roll(f, 1, 0) + np.roll(f, -1, 0) + np.roll(f, 1, 1) + np.roll(f, -1, 1)) / 5.0
    return f


def hsv(a):
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, (g - b) / np.maximum(d, 1e-6) % 6,
                 np.where(mx == g, (b - r) / np.maximum(d, 1e-6) + 2, (r - g) / np.maximum(d, 1e-6) + 4)) * 60
    return np.where(d > 0, h, 0), s, mx


def luminance(a):
    return 0.30 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]


def ramp(stops, t):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[..., None]
        out = np.where(((t >= t0) & (t <= t1))[..., None], np.array(c0) * (1 - k) + np.array(c1) * k, out)
    return out


def curve(points, n=12):
    """A smooth line through `points` (Catmull-Rom)."""
    p = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = map(np.array, (p[i - 1], p[i], p[i + 1], p[i + 2]))
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(points[-1])
    return out


def poly(points, shape, ss=4):
    """How much of each pixel a polygon covers (0..1)."""
    h, w = shape
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([(x * ss, y * ss) for x, y in points], fill=255)
    return np.array(im.resize((w, h), Image.BOX)).astype(float) / 255.0


def stroke(points, width, shape, ss=4):
    """How much of each pixel a line through `points`, `width` wide, covers (0..1)."""
    h, w = shape
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).line([(x * ss, y * ss) for x, y in points], fill=255, width=max(1, int(round(width * ss))), joint="curve")
    return np.array(im.resize((w, h), Image.BOX)).astype(float) / 255.0


def lay(out, cover, colour, alpha=1.0):
    k = (np.clip(cover, 0, 1) * alpha)[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + np.asarray(colour, float) * k
    out[..., 3] = np.maximum(out[..., 3], np.clip(cover, 0, 1) * 255)


def form_light(xx, yy, centre, radii, ripple, light=(-0.55, -0.7, 0.5), ambient=0.28):
    """Light on a rounded form: a dome over `centre`, hanging straight below it, its surface
    rippled sideways by `ripple`. Lit from the upper left, like the paintings."""
    cx, cy = centre
    rx, ry = radii
    u = (xx - cx) / rx
    v = np.clip((yy - cy) / ry, -1, 0)
    z = np.sqrt(np.clip(1 - u * u - v * v, 0.02, 1))
    n = np.dstack([u + ripple, v, z])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lv = np.array(light, float)
    lv /= np.linalg.norm(lv)
    return np.clip(ambient + (1 - ambient) * np.clip((n * lv).sum(-1), 0, 1), 0, 1)


def cel(lit, levels=7):
    """Light in a few flat tones, as a pixel painter lays it, checkered where two meet."""
    t = lit * levels
    base = np.floor(t)
    frac = t - base
    checker = (np.indices(lit.shape).sum(0) % 2).astype(float)
    base = base + ((frac > 0.62) | ((frac > 0.38) & (checker > 0)))
    return np.clip(base / levels, 0, 1)


def disc(shape, cx, cy, r, soft=0.8):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]].astype(float)
    return np.clip((r - np.hypot(xx - cx, yy - cy)) / soft + 0.5, 0, 1), xx - cx, yy - cy


def coin(out, cx, cy, r):
    """A gold coin or bead: a dark rim, lit from the upper left, a glint."""
    h, w = out.shape[:2]
    rim, _dx, _dy = disc((h, w), cx, cy, r + 0.7)
    lay(out, rim, GOLD_DARK)
    body, dx, dy = disc((h, w), cx, cy, r)
    lit = 1.0 + 0.45 * np.clip((-dx - dy) / (1.4 * max(r, 1.0)), -1, 1)
    k = body[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + np.clip(np.array(GOLD_MID, float) * lit[..., None], 0, 255) * k
    if r >= 1.8:
        glint, _dx, _dy = disc((h, w), cx - r * 0.35, cy - r * 0.35, max(0.6, r * 0.28), soft=0.6)
        lay(out, glint * 0.9, GOLD_LIGHT)


def gem(out, cx, cy, r, colour=GARNET):
    """A red stone in a gold setting."""
    h, w = out.shape[:2]
    setting, _dx, _dy = disc((h, w), cx, cy, r + 1.0)
    lay(out, setting, GOLD_MID)
    body, dx, dy = disc((h, w), cx, cy, r)
    lit = 1.0 + 0.5 * np.clip((-dx - dy) / (1.4 * r), -1, 1)
    k = body[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + np.clip(np.array(colour, float) * lit[..., None], 0, 255) * k
    glint, _dx, _dy = disc((h, w), cx - r * 0.4, cy - r * 0.4, max(0.6, r * 0.3), soft=0.6)
    lay(out, glint * 0.85, (255, 220, 220))


def chain(out, points, step=1.6):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(1, int(np.hypot(x1 - x0, y1 - y0) / step))
        for i in range(n):
            coin(out, x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, 0.55)


def hairline(a, x0, x1, start):
    """Where the forehead meets the hair, as a smooth curve over x0..x1: up from row
    `start` (inside the forehead) while the skin lasts, then fitted."""
    tone = np.median(a[start - 2:start + 3, (x0 + x1) // 2 - 6:(x0 + x1) // 2 + 6, :3].reshape(-1, 3), axis=0)
    xs, ys = [], []
    for x in range(x0, x1 + 1):
        y = start
        while y > 40 and np.abs(a[y - 1, x, :3] - tone).max() < 55:
            y -= 1
        xs.append(x)
        ys.append(y)
    fit = np.polyfit(xs, ys, 2)
    return {x: float(np.polyval(fit, x)) for x in range(x0, x1 + 1)}


def redye(src, who, hues, least, stops, greys=True):
    """A garment re-dyed through `stops` by its own light and shade: the pixels of its hue
    below the neck, with the folds too dark to show a hue."""
    h, s, v = hsv(src)
    yy = np.mgrid[0:src.shape[0], 0:src.shape[1]][0]
    below = (yy >= NECK[who]) & (src[..., 3] > 0)
    lo, hi = hues
    cloth = below & (h >= lo) & (h < hi) & (s >= least)
    leaning = (h >= lo - 30) & (h < hi + 30)
    if greys:
        deep = below & (v < 0.45) & ((s < 0.14) | leaning | ((h >= 45) & (h < 300) & (s < 0.3)))
    else:
        deep = below & (v < 0.30) & leaning
    for _ in range(6):
        cloth = cloth | (grow(cloth) & deep)
    lum = luminance(src)
    lo_l, hi_l = np.percentile(lum[cloth], 2), np.percentile(lum[cloth], 99.5)
    t = np.clip((lum - lo_l) / max(1.0, hi_l - lo_l), 0, 1) ** 0.85
    out = src.copy()
    out[cloth, :3] = ramp(stops, t)[cloth]
    return out, cloth


def locks(shape, masses, palette, seed=7, ss=3):
    """Loose hair as locks: strands that wave together, darker at the back of the mass,
    lit where their waves turn toward the upper left. An RGBA layer."""
    rng = np.random.default_rng(seed)
    h, w = shape
    im = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark, _mid, base, light, shine = [np.array(c, float) for c in palette]
    jobs = []
    for m in masses:
        x0, y0, x1, y1 = m["roots"]
        for i in range(m["locks"]):
            t0 = (i + rng.uniform(-0.3, 0.3)) / max(1, m["locks"] - 1)
            jobs.append(dict(m=m, sx=x0 + (x1 - x0) * t0, sy=y0 + (y1 - y0) * t0, depth=rng.uniform(0, 1),
                             length=rng.uniform(*m["length"]), phase=rng.uniform(0, 2 * np.pi),
                             drift=m["drift"] * rng.uniform(0.7, 1.3), width=rng.uniform(*m["lock_width"]),
                             tone=rng.uniform(-0.12, 0.12)))
    jobs.sort(key=lambda j: j["depth"])
    for j in jobs:
        amp, lam = j["m"]["wave"]
        n = int(j["width"] * 1.6) + 3
        for k in range(n):
            off = (k / max(1, n - 1) - 0.5) * j["width"]
            ln = j["length"] * (1 - 0.18 * abs(off) / max(1, j["width"]) * 2 + 0.06 * np.sin(k * 2.3))
            steps = int(ln / 3)
            pts = []
            for s in range(steps + 1):
                t = s / max(1, steps)
                y = j["sy"] + ln * t
                bend = amp * (0.35 + 0.8 * t) * np.sin((y - j["sy"]) / lam * 2 * np.pi + j["phase"])
                pts.append((j["sx"] + j["drift"] * t ** 1.3 + bend + off * (1 - 0.55 * t), y, t))
            for (xa, ya, ta), (xb, yb, _tb) in zip(pts, pts[1:]):
                slope = (xb - xa) / max(1e-3, yb - ya)
                across = off / max(1, j["width"]) + 0.5
                catch = np.clip(-slope * 1.4 + 0.15, 0, 1) * np.clip(1.2 - abs(across - 0.35) * 2.2, 0, 1)
                shade = np.clip(0.2 + 0.7 * j["depth"] + j["tone"] - 0.25 * abs(across - 0.4), 0, 1)
                col = dark * (1 - shade) + base * shade
                col = col * (1 - 0.6 * catch) + (light * 0.6 + shine * 0.4) * 0.6 * catch
                col = col * (1 - 0.3 * ta) + dark * 0.3 * ta
                d.line([(xa * ss, ya * ss), (xb * ss, yb * ss)], fill=tuple(int(c) for c in col) + (255,),
                       width=max(1, int(round((1.7 * (1 - ta) + 0.9 * ta) * ss))))
    return np.array(im.resize((w, h), Image.LANCZOS)).astype(float)


# ---------------------------------------------------------------- the three
def edda(src):
    h, w = src.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    _h, sat, mx = hsv(src)
    woad = [(0.0, (10, 14, 34)), (0.3, (26, 36, 80)), (0.65, (50, 68, 124)), (1.0, (118, 136, 182))]
    out, gown = redye(src, "edda", (150, 280), 0.06, woad)
    gown = gown & (yy > 236)
    # A gold-embroidered border where the gown meets her linen at the neckline.
    linen = (mx > 0.6) & (sat < 0.42) & (yy > 262)
    border = gown & grow(linen, 4) & (xx > 70) & (xx < 300) & (yy < 470)
    t = cel(np.clip(0.3 + 0.55 * (1 - np.clip((yy - 270) / 220, 0, 1)) + 0.2 * ((xx + yy) % 3 == 0), 0, 1), levels=5)
    out[border, :3] = ramp(GOLD, t)[border]
    # Her hair unbound below her braided crown: locks from her left temple and from under
    # her bun, over both shoulders. Not over her face, ear or throat.
    layer = locks((h, w), [
        dict(roots=(108, 132, 96, 206), locks=11, length=(170, 250), drift=-30, wave=(5.0, 64), lock_width=(9, 14)),
        dict(roots=(232, 176, 280, 200), locks=12, length=(150, 230), drift=24, wave=(5.0, 68), lock_width=(10, 15)),
    ], [(40, 16, 8), (92, 42, 20), (140, 70, 32), (192, 112, 54), (234, 160, 92)], seed=5)
    face = poly(curve([(118, 112), (150, 100), (190, 102), (214, 118), (222, 150), (226, 176), (214, 210), (204, 240),
                       (216, 272), (190, 300), (160, 292), (146, 262), (140, 232), (122, 206), (114, 160), (118, 112)]), (h, w))
    alpha = layer[..., 3] / 255.0 * (1 - face)
    mass = alpha > 0.5
    k = alpha[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + layer[..., :3] * k
    out[..., 3] = np.maximum(out[..., 3], alpha * 255)
    lay(out, (grow(mass, 1) & ~mass & (face < 0.5)).astype(float) * 0.6, (40, 16, 8))
    shade = blur((grow(mass, 3) & ~mass & gown).astype(float), 1)[..., None] * 0.35
    out[..., :3] = out[..., :3] * (1 - shade)
    # A gold bridal crown on her braid: a band of two rows, trefoils rising, garnets set in it.
    def top(x):
        ys = np.nonzero(src[:, x, 3] > 128)[0]
        return int(ys[0]) if len(ys) else None
    band = [(x, top(x) + 15 + 0.035 * abs(x - 176)) for x in range(108, 254, 2) if top(x) is not None]
    for (x0, y0), (x1, y1) in zip(band, band[1:]):
        for t in np.linspace(0, 1, 3):
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            coin(out, x, y, 1.9)
            coin(out, x, y + 2.4, 1.6)
    for x, y in band[::7]:
        coin(out, x, y - 3.4, 1.7)
        coin(out, x - 2.2, y - 6.0, 1.5)
        coin(out, x + 2.2, y - 6.0, 1.5)
        coin(out, x, y - 8.2, 1.6)
    for x, y in band[3::7]:
        gem(out, x, y + 1.2, 1.7)
    free = blur(mass.astype(float) * smooth(170, 330, yy), 3)
    return out, free


def farah(src):
    h, w = src.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    crimson = [(0.0, (38, 8, 12)), (0.4, (122, 20, 30)), (0.75, (178, 42, 46)), (1.0, (226, 104, 92))]
    out, _coat = redye(src, "farid", (165, 270), 0.12, crimson)
    # The coat's bands worked in bright gold.
    hh, ss, vv = hsv(src)
    throat = poly(curve([(150, 236), (205, 226), (222, 250), (212, 300), (186, 330), (160, 300), (148, 262)]), (h, w))
    bands = (yy > 262) & (throat < 0.5) & (hh > 18) & (hh < 55) & (ss > 0.35) & (vv > 0.30) & (src[..., 3] > 0)
    t = np.clip((luminance(src) - 40) / 150.0, 0, 1)
    out[bands, :3] = ramp(GOLD, t)[bands]
    # Gold: a circlet of coins along her hairline with a garnet on her brow, earrings, a
    # necklace of coins at her throat.
    line = hairline(out, 128, 196, 116)
    pts = [(x, line[x] - 1.0) for x in sorted(line) if x % 2 == 0]
    chain(out, pts)
    for x, y in pts[::4]:
        coin(out, x, y + 2.2, 1.6)
    mid = 158
    top = line.get(mid, 100) - 1.0
    chain(out, [(mid, top), (mid, top + 6)])
    coin(out, mid, top + 6.5, 1.4)
    gem(out, mid, top + 10.5, 2.6)
    chain(out, [(236, 178), (236, 190)])
    coin(out, 236, 177.5, 1.8)
    gem(out, 236, 192, 2.4)
    coin(out, 236, 198.5, 2.2)
    for dx in (-2.4, 0, 2.4):
        coin(out, 236 + dx, 202.5, 0.9)
    neck = [(158, 262), (166, 270), (174, 276), (183, 280), (192, 281), (201, 278), (209, 272), (215, 266)]
    chain(out, neck)
    for x, y in neck[1:-1]:
        chain(out, [(x, y), (x, y + 3)])
        coin(out, x, y + 5, 2.0)
    chain(out, [(188, 281), (188, 287)])
    coin(out, 188, 291, 3.4)
    gem(out, 188, 291, 1.4)
    # A sheer ivory veil set back on her crown, falling past her shoulders, its folds more
    # opaque where the silk lies doubled, bordered in gold all round.
    outer = curve([(66, 356), (46, 364), (26, 354), (36, 300), (52, 236), (66, 172), (86, 112), (120, 64), (170, 40),
                   (222, 42), (268, 70), (298, 120), (316, 182), (330, 248), (346, 306), (360, 352), (340, 364),
                   (318, 354), (300, 366)], n=14)
    inner = curve([(286, 358), (270, 318), (256, 268), (250, 214), (248, 160), (240, 112), (218, 82), (182, 72),
                   (146, 78), (120, 98), (108, 136), (104, 186), (102, 236), (94, 282), (96, 326), (108, 360),
                   (88, 366)], n=14)
    veil = poly(outer + inner, (h, w))
    m = veil > 0.5
    ang = np.arctan2(xx - 182.0, yy - 36.0)
    fall = smooth(80, 240, yy)
    ripple = fall * (0.34 * np.sin(ang * 18.0) + 0.12 * np.sin(ang * 43.0 + 0.9))
    lit = cel(form_light(xx, yy, (182.0, 170.0), (126.0, 132.0), ripple))
    silk = ramp([(0.0, (120, 96, 78)), (0.4, (196, 178, 150)), (0.75, (238, 228, 206)), (1.0, (255, 250, 236))], lit)
    alpha = 0.42 + 0.22 * np.abs(np.sin(ang * 18.0)) * fall
    k = (np.clip(veil, 0, 1) * alpha)[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + silk * k
    out[..., 3] = np.maximum(out[..., 3], np.clip(veil, 0, 1) * 255 * 0.85)
    border = grow(~m, 5) & m & (((xx > 92) & (xx < 290)) | (yy < 300))
    border = border | (m & (yy > 336) & grow(~m, 5))
    lay(out, border.astype(float), ramp(GOLD, 0.25 + 0.75 * cel(np.clip(lit * 1.1, 0, 1), levels=5)))
    lay(out, (border & (((xx + yy) % 6) < 1.2) & ~(grow(~m, 1) & m)).astype(float) * 0.55, (110, 64, 20))
    lay(out, (grow(m, 1) & ~m).astype(float) * 0.55, (70, 44, 20))
    return out, None


def kaede(src):
    h, w = src.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    hh, ss, vv = hsv(src)
    lum = luminance(src)
    # White robes, their pattern woven white on white; a red inner collar.
    throat = poly(curve([(146, 236), (198, 222), (215, 228), (217, 250), (207, 272), (200, 290), (176, 330),
                         (160, 300), (144, 262)]), (h, w))
    below = (yy >= 226) & (src[..., 3] > 0) & (throat < 0.5)
    clasp = np.hypot(xx - 192, yy - 396) < 15
    # The strands that hang over her robe stay hair: dark, warm and saturated, where they hang.
    hangs_left = (xx < 140) & (xx > 70) & (yy < 292)
    hangs_right = (xx > 196) & (xx < 228) & (yy < 300)
    warm = (hh < 40) | (hh > 352)
    hair = (hangs_left | hangs_right) & ((warm & (ss > 0.5) & (vv < 0.62)) | (vv < 0.12))
    hair = hair | (grow(hair, 1) & (hangs_left | hangs_right) & (vv < 0.3) & (ss > 0.35) & warm)
    # Above her shoulders only the back of the collar and of the robe is cloth: the rest is
    # her hair (near black, or dark and warm), and stays.
    hair = hair | ((yy < 238) & (~((xx > 214) & (xx < 262)) | (vv < 0.14) | ((hh < 40) & (ss > 0.5) & (vv < 0.62))))
    # The side of her neck shows behind that strand: skin (richer than the linen) stays too.
    hair = hair | ((xx > 196) & (xx < 252) & (yy >= 222) & (yy < 264) & (hh > 12) & (hh < 36) & (ss >= 0.47) & (vv > 0.5))
    # Her inner collar: cream linen (paler than skin), inside the line of the lapels.
    zone = poly([(118, 300), (140, 240), (160, 236), (214, 226), (254, 226), (258, 262), (236, 300), (200, 380),
                 (130, 380)], (h, w)) > 0.5
    collar = below & zone & ~hair & ~hangs_left & (ss < 0.47) & (vv > 0.42) & (hh > 15) & (hh < 50)
    collar = collar | (below & hangs_right & ~hair & (yy > 238))   # the strand lies on the collar
    # Its back, by her neck: paler than any skin.
    collar = collar | ((src[..., 3] > 0) & (xx > 206) & (xx < 262) & (yy >= 224) & (yy < 262) & ~hair
                       & (ss < 0.40) & (vv > 0.5) & (hh > 10) & (hh < 55))
    robe = below & ~clasp & ~hair & ~collar
    out = src.copy()
    silk = [(0.0, (96, 98, 122)), (0.3, (176, 176, 194)), (0.6, (226, 226, 234)), (1.0, (252, 251, 247))]
    out[robe, :3] = ramp(silk, 0.42 + 0.58 * np.clip((lum - 8) / 150.0, 0, 1))[robe]
    red = [(0.0, (70, 10, 16)), (0.5, (168, 30, 38)), (1.0, (226, 92, 84))]
    out[collar, :3] = ramp(red, 0.2 + 0.8 * np.clip((lum - 120) / 110.0, 0, 1))[collar]
    # The robe's own outline against what's behind her, as the painting draws it.
    figure = out[..., 3] > 128
    lay(out, (robe & grow(~figure, 1)).astype(float) * 0.8, (70, 70, 88))
    # Her hair as she wears it, dressed for the day with two things only. The pin through
    # her knot is lacquered red (re-dyed by its own light, its gold band kept)...
    pin = (xx > 250) & (xx < 300) & (yy > 158) & (yy < 186) & (src[..., 3] > 0) & (hh < 45) & (ss > 0.42) \
        & (vv > 0.2) & ~((vv > 0.5) & (hh > 30))
    pin = pin & ((xx > 268) | (vv > 0.24))
    lacquer = [(0.0, (64, 8, 14)), (0.5, (164, 26, 34)), (1.0, (236, 96, 84))]
    out[pin, :3] = ramp(lacquer, np.clip((lum - 20) / 95.0, 0, 1))[pin]
    coin(out, 296.5, 166.5, 2.0)
    # ...and a small gold comb is set behind her crown, across the sweep of her hair: an
    # arched spine, its teeth running back into the hair toward her knot.
    spine = curve([(231, 120), (236, 110), (244, 102), (255, 98)], n=10)
    for i in range(1, len(spine) - 1, 3):
        x, y = spine[i]
        lay(out, stroke([(x + 0.8, y + 0.8), (x + 5.2, y + 5.0)], 1.0, (h, w)) * 0.9, (150, 100, 34))
    lay(out, stroke(spine, 5.4, (h, w)), GOLD_DARK)
    lay(out, stroke(spine, 3.8, (h, w)), GOLD_MID)
    lay(out, stroke([(x - 0.9, y - 0.9) for x, y in spine[2:-2]], 1.2, (h, w)) * 0.95, GOLD_LIGHT)
    return out, "as every day"


DRESS = {"edda": edda, "farid": farah, "kaede": kaede}


def main():
    face_dir = os.path.join(PORTRAITS, "face")
    os.makedirs(face_dir, exist_ok=True)
    for who in WHO:
        free = None
        for expression in EXPRESSIONS:
            dressed, hair = DRESS[who](load(who, expression))
            Image.fromarray(np.clip(np.round(dressed), 0, 255).astype("uint8"), "RGBA").save(
                os.path.join(PORTRAITS, "%s_wedding_%s.png" % (who, expression)), optimize=True)
            if free is None:
                free = hair if hair is not None else np.zeros(dressed.shape[:2])
        if isinstance(free, str):                     # her hair is as it is every day
            import portrait_faces
            map_ = portrait_faces.hair(who)
        else:
            free = np.clip(free / max(free.max(), 1e-6), 0, 1)
            map_ = Image.fromarray(np.round(free * 255).astype("uint8"), "L")
        map_.save(os.path.join(face_dir, "%s_wedding_hair.png" % who), optimize=True)
    print("dressed %d paintings" % (len(WHO) * len(EXPRESSIONS)))


if __name__ == "__main__":
    main()
