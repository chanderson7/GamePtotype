"""Authoring tool: dresses Bannerfall's painted romance portraits for their wedding.

Edda, Farah and Kaede were painted once per expression, in everyday clothes. This makes
their wedding clothes from those same paintings: each garment is recoloured through a
ramp by its own light and shade (so every fold, seam and texture the painter put there
stays), and wedding details are painted into the hair, lit from the upper left like the
paintings.

  Edda   honey-ivory wool dress, its stitching left gold; a wreath of white and blush flowers
  Farah  crimson coat over her cream linen, flecked with gold; a circlet of gold coins at
         her hairline with a red drop on her brow, gold and garnet earrings, a coin
         necklace at her throat, and jasmine in her curls
  Kaede  white over-robe, red collar; a pin of red and white blossoms by her knot

Writes assets/portraits/<who>_wedding_<expression>.png for the expressions the wedding
uses. Then run tools/portrait_faces.py, which gives them their blinks and glances too.

    python3 tools/portrait_wedding.py [preview_dir]

Needs Pillow and numpy.
"""
import colorsys
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
WHO = ["edda", "farid", "kaede"]
EXPRESSIONS = ["neutral", "warm", "amused"]
# Nothing above this line is clothing.
NECK = {"edda": 236, "farid": 236, "kaede": 228}

# Ramps: (stop, colour) from deepest shade to brightest light.
IVORY = [(0.0, (70, 52, 40)), (0.35, (176, 146, 106)), (0.7, (228, 204, 160)), (1.0, (250, 238, 208))]
CRIMSON = [(0.0, (38, 8, 12)), (0.4, (122, 20, 30)), (0.75, (178, 42, 46)), (1.0, (226, 104, 92))]
SILK = [(0.0, (62, 64, 80)), (0.35, (168, 170, 182)), (0.7, (226, 226, 230)), (1.0, (252, 252, 250))]
RED = [(0.0, (48, 8, 10)), (0.45, (150, 26, 30)), (1.0, (228, 88, 78))]
GOLD = (222, 178, 92)

# Which garments, by hue (degrees) and least saturation, are dressed in which ramp; and
# whether the garment's greyish shading is taken with it (not beside a patterned band).
DRESS = {
    "edda": [((150, 280), 0.06, IVORY, True)],
    "farid": [((165, 270), 0.12, CRIMSON, True)],
    "kaede": [((175, 265), 0.12, SILK, True), ((300, 360), 0.15, RED, False)],
}


def load(who, expression):
    return np.array(Image.open(os.path.join(PORTRAITS, "%s_%s.png" % (who, expression))).convert("RGBA")).astype(float)


def hsv(a):
    flat = a[..., :3].reshape(-1, 3) / 255.0
    out = np.array([colorsys.rgb_to_hsv(*p) for p in flat]).reshape(a.shape[:2] + (3,))
    out[..., 0] *= 360.0
    return out


def ramp(stops, t):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[..., None]
        inside = ((t >= t0) & (t <= t1))[..., None]
        out = np.where(inside, np.array(c0) * (1 - k) + np.array(c1) * k, out)
    return out


def dress(a, who):
    """The garments recoloured, each through its ramp by its own light and shade."""
    out = a.copy()
    h = hsv(a)
    yy = np.mgrid[0:a.shape[0], 0:a.shape[1]][0]
    for (lo, hi), least, stops, greys in DRESS[who]:
        below = (yy >= NECK[who]) & (a[..., 3] > 0)
        cloth = below & (h[..., 0] >= lo) & (h[..., 0] < hi) & (h[..., 1] >= least)
        # The cloth's deepest folds are too dark to show its hue: take dark pixels beside
        # it that lean the same way, are greyish, or have no hue at all; not hair (warm and dark).
        leaning = (h[..., 0] >= lo - 30) & (h[..., 0] < hi + 30)
        if greys:
            deep = below & (h[..., 2] < 0.45) & ((h[..., 1] < 0.14) | leaning | ((h[..., 0] >= 45) & (h[..., 0] < 300) & (h[..., 1] < 0.3)))
        else:
            deep = below & (h[..., 2] < 0.30) & leaning
        for _ in range(6):
            near = cloth | np.roll(cloth, 1, 0) | np.roll(cloth, -1, 0) | np.roll(cloth, 1, 1) | np.roll(cloth, -1, 1)
            cloth = cloth | (near & deep)
        light = 0.30 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]
        lum = light[cloth]
        lo_l, hi_l = np.percentile(lum, 2), np.percentile(lum, 99.5)
        t = (light - lo_l) / max(1.0, hi_l - lo_l)
        t = np.clip(t, 0, 1) ** 0.85
        new = ramp(stops, t)
        out[cloth, :3] = new[cloth]
    return out


def paint(out, cover, colour):
    """Lay `colour` over `out` where `cover` (0..1) says, keeping out's alpha at least that."""
    k = cover[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + np.array(colour, float) * k
    out[..., 3] = np.maximum(out[..., 3], cover * 255)


def disc(shape, cx, cy, r, soft=0.8):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]].astype(float)
    d = np.hypot(xx - cx, yy - cy)
    return np.clip((r - d) / soft + 0.5, 0, 1), xx - cx, yy - cy


def shade(colour, nx, ny, r):
    """`colour` lit from the upper left, at offset (nx, ny) from a petal's centre."""
    lit = 1.0 + 0.28 * np.clip((-nx - ny) / (1.4 * r), -1, 1)
    return np.clip(np.array(colour, float)[None, None, :] * lit[..., None], 0, 255)


def flower(out, cx, cy, r, petal, centre, petals=5, turn=0.0):
    """A small flower: rounded petals lit from the upper left, a dark rim so it reads
    against hair, and a centre."""
    h, w = out.shape[:2]
    rim = np.array(petal, float) * 0.45
    for i in range(petals):
        ang = turn + i * 2 * np.pi / petals
        px, py = cx + np.cos(ang) * r * 0.55, cy + np.sin(ang) * r * 0.55
        edge, dx, dy = disc((h, w), px, py, r * 0.62 + 0.6)
        paint(out, edge, rim)
        body, dx, dy = disc((h, w), px, py, r * 0.62)
        k = body[..., None]
        lit = shade(petal, dx + (px - cx), dy + (py - cy), r)
        out[..., :3] = out[..., :3] * (1 - k) + lit * k
        out[..., 3] = np.maximum(out[..., 3], body * 255)
    middle, dx, dy = disc((h, w), cx, cy, max(1.2, r * 0.28))
    k = middle[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + shade(centre, dx, dy, r * 0.3) * k


def leaf(out, x0, y0, x1, y1, width, colour):
    h, w = out.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    vx, vy = x1 - x0, y1 - y0
    length = max(1e-6, np.hypot(vx, vy))
    t = np.clip(((xx - x0) * vx + (yy - y0) * vy) / (length * length), 0, 1)
    d = np.hypot(xx - (x0 + t * vx), yy - (y0 + t * vy))
    half = width * np.sin(np.pi * t)
    edge = np.clip((half + 0.6 - d) / 0.8 + 0.5, 0, 1)
    paint(out, edge, np.array(colour, float) * 0.5)
    body = np.clip((half - d) / 0.8 + 0.5, 0, 1)
    lit = np.array(colour, float) * (1.08 - 0.25 * t)[..., None]
    k = body[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + lit * k


GOLD_LIGHT = (252, 226, 150)
GOLD_MID = (214, 166, 72)
GOLD_DARK = (120, 80, 28)
GARNET = (170, 22, 38)


def coin(out, cx, cy, r):
    """A gold coin or bead: a dark rim, lit from the upper left, a glint."""
    h, w = out.shape[:2]
    rim, _dx, _dy = disc((h, w), cx, cy, r + 0.7)
    paint(out, rim, GOLD_DARK)
    body, dx, dy = disc((h, w), cx, cy, r)
    lit = 1.0 + 0.45 * np.clip((-dx - dy) / (1.4 * max(r, 1.0)), -1, 1)
    colour = np.clip(np.array(GOLD_MID, float)[None, None, :] * lit[..., None], 0, 255)
    k = body[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + colour * k
    out[..., 3] = np.maximum(out[..., 3], body * 255)
    if r >= 1.8:
        glint, _dx, _dy = disc((h, w), cx - r * 0.35, cy - r * 0.35, max(0.6, r * 0.28), soft=0.6)
        paint(out, glint * 0.9, GOLD_LIGHT)


def gem(out, cx, cy, r, colour=GARNET):
    """A drop of red stone in a gold setting, lit from the upper left."""
    h, w = out.shape[:2]
    setting, _dx, _dy = disc((h, w), cx, cy, r + 1.0)
    paint(out, setting, GOLD_MID)
    body, dx, dy = disc((h, w), cx, cy, r)
    lit = 1.0 + 0.5 * np.clip((-dx - dy) / (1.4 * r), -1, 1)
    c = np.clip(np.array(colour, float)[None, None, :] * lit[..., None], 0, 255)
    k = body[..., None]
    out[..., :3] = out[..., :3] * (1 - k) + c * k
    glint, _dx, _dy = disc((h, w), cx - r * 0.4, cy - r * 0.4, max(0.6, r * 0.3), soft=0.6)
    paint(out, glint * 0.85, (255, 220, 220))


def chain(out, points, step=1.6):
    """Fine gold links along `points`."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(1, int(np.hypot(x1 - x0, y1 - y0) / step))
        for i in range(n):
            t = i / n
            coin(out, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.55)


def hairline(a, x0, x1, start):
    """Where her forehead meets her hair, as a smooth curve over x0..x1: from inside the
    forehead (row `start`) upward, while the skin lasts, then fitted so a stray curl
    doesn't bend it."""
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


def brocade(out, who):
    """Small gold flowers worked into the coat on a diamond lattice, only on the cloth."""
    h, w = out.shape[:2]
    rgb = out[..., :3]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    red = (rgb[..., 0] >= rgb[..., 1] * 1.8) & (rgb[..., 0] > 70) & ((mx - mn) / np.maximum(mx, 1) > 0.55)
    yy = np.mgrid[0:h, 0:w][0]
    coat = red & (yy >= NECK[who] + 30) & (out[..., 3] > 250)
    for row, y in enumerate(range(NECK[who] + 38, h - 6, 17)):
        for x in range(4 + (8 if row % 2 else 0), w - 4, 16):
            if coat[y - 3:y + 4, x - 3:x + 4].all():
                for dx, dy in ((0, -2), (2, 0), (0, 2), (-2, 0)):
                    coin(out, x + dx, y + dy, 0.75)
                coin(out, x, y, 0.9)


def top_of_head(a, x):
    ys = np.nonzero(a[:, x, 3] > 128)[0]
    return int(ys[0]) if len(ys) else None


WHITE = (246, 242, 232)
BLUSH = (238, 186, 186)
JASMINE = (250, 250, 244)
BLOSSOM = (214, 52, 60)
GREEN = (92, 128, 70)
CENTRE = (236, 196, 84)
# Nothing is painted here: StoryArt.FACE, the strip of eyes and brows a blink replaces.
FACE = (106, 104, 210, 176)


def adorn(out, who):
    """The wedding details in the hair."""
    if who == "edda":
        # A wreath on her braided crown, from temple to temple, white and blush by turns.
        spots = []
        for x in range(102, 252, 11):
            top = top_of_head(out, x)
            if top is None:
                continue
            y = top + 12 + 0.06 * abs(x - 172)
            if y + 6 >= FACE[1] and FACE[0] - 6 <= x <= FACE[2] + 6:
                continue
            spots.append((x, y))
        for (x0, y0), (x1, y1) in zip(spots, spots[1:]):
            leaf(out, x0 + 1, y0 + 3, (x0 + x1) / 2 + 4, (y0 + y1) / 2 + 7, 2.8, GREEN)
            leaf(out, x0 + 3, y0 - 1, (x0 + x1) / 2 + 2, (y0 + y1) / 2 - 6, 2.2, GREEN)
        for i, (x, y) in enumerate(spots):
            flower(out, x, y, 6.6 if i % 2 == 0 else 5.4, WHITE if i % 2 == 0 else BLUSH, CENTRE, turn=i * 0.7)
    elif who == "farid":
        brocade(out, who)
        line = hairline(out, 128, 196, 116)
        # A circlet of small gold coins along her hairline, a garnet drop on her brow.
        pts = [(x, line[x] - 1.0) for x in sorted(line) if x % 2 == 0]
        chain(out, pts)
        for x, y in pts[::4]:
            coin(out, x, y + 2.2, 1.6)
        mid = 158
        top = line.get(mid, 100) - 1.5
        chain(out, [(mid, top), (mid, top + 6)])
        coin(out, mid, top + 6.5, 1.4)
        gem(out, mid, top + 10.5, 2.6)
        # Earrings: a gold stud at the lobe, a chain, a garnet, a little bell of gold.
        chain(out, [(236, 178), (236, 190)])
        coin(out, 236, 177.5, 1.8)
        gem(out, 236, 192, 2.4)
        coin(out, 236, 198.5, 2.2)
        for dx in (-2.4, 0, 2.4):
            coin(out, 236 + dx, 202.5, 0.9)
        # A necklace of coins at her throat, a larger one at its centre.
        neck = [(158, 262), (166, 270), (174, 276), (183, 280), (192, 281), (201, 278), (209, 272), (215, 266)]
        chain(out, neck)
        for x, y in neck[1:-1]:
            chain(out, [(x, y), (x, y + 3)])
            coin(out, x, y + 5, 2.0)
        chain(out, [(188, 281), (188, 287)])
        coin(out, 188, 291, 3.4)
        gem(out, 188, 291, 1.4)
        # Jasmine tucked above her ear: a sprig of small white stars, buds and leaves.
        leaf(out, 222, 104, 236, 88, 2.2, GREEN)
        leaf(out, 228, 100, 246, 104, 2.0, GREEN)
        for i, (x, y, r) in enumerate([(220, 86, 4.2), (230, 80, 3.8), (238, 92, 4.0), (226, 96, 3.4), (244, 84, 3.0)]):
            flower(out, x, y, r, JASMINE, CENTRE, petals=5, turn=0.4 + i)
    elif who == "kaede":
        # A pin by her knot: red and white blossoms on a gold bar.
        leaf(out, 228, 126, 262, 112, 1.6, (200, 160, 80))
        for i, (x, y, r, c) in enumerate([(236, 118, 5.0, BLOSSOM), (247, 126, 4.4, WHITE), (233, 131, 4.0, BLOSSOM)]):
            flower(out, x, y, r, c, CENTRE, petals=5, turn=0.3 + i * 0.9)
    return out


def main():
    preview = sys.argv[1] if len(sys.argv) > 1 else ""
    for who in WHO:
        for expression in EXPRESSIONS:
            a = load(who, expression)
            b = adorn(dress(a, who), who)
            Image.fromarray(np.clip(np.round(b), 0, 255).astype("uint8"), "RGBA").save(
                os.path.join(preview or PORTRAITS, "%s_wedding_%s.png" % (who, expression)), optimize=True)
    print("done")


if __name__ == "__main__":
    main()
