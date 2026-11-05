#!/usr/bin/env python3
"""Prototype of the manor improvements drawn into the settlement vista.

Paints the Vardish village of scripts/ui/settlement_scene.gd on its 180 x 80 grid with
the same primitives (r, p, tri, dome, grid, ridge), then adds the three improvements a
fief can build, at the places and in the colours the GDScript port should use:

  granary   a timber barn on staddle stones, left of the village on the field edge
  palisade  pointed stakes where the rail fences were, gate posts, a watchtower by the road
  mill      a brook down the right edge, a slate-roofed mill with its wheel, two stalls

It also paints each improvement alone on a small "plate" for the Manor card's
thumbnails, in each culture's form, so the row and the vista show the same building.

    python3 tools/fief_vista_proto.py OUT_DIR

writes before.png / after.png (the village bare and with everything built, scaled 4x),
step_*.png (one improvement at a time), night.png, and plate_<culture>_<key>[_ghost].png.
Nothing here runs in the game; it is the picture the plan asks for, kept as reference.
"""
import math
import os
import re
import sys

from PIL import Image

W, H, HZ = 180, 80, 44
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DARK = "2a2430"
GOLD = "d9a944"
NIGHT_TINT = (0x4A / 255, 0x54 / 255, 0x88 / 255)

LOOK = {
    "vardish": {"sky": ["6f86a8", "a9b8c8", "d3d9de"], "far": "7d92a3", "mid": "55785c", "grass": "6c9448",
                "grass2": "5c8540", "tuft": "4b7236", "road": "a08766", "road2": "8a7356", "stone": "c4bca9",
                "stoneS": "8e8576", "mortar": "aea591", "roof": "64708a", "roofS": "424a60", "tile": "b04c36",
                "tileS": "783026", "wood": "5a3e28", "plaster": "e6dcc2", "thatch": "c9a35a", "thatchS": "94723a"},
    "kharzani": {"sky": ["6aa2d0", "b4cfdc", "f2dcaa"], "far": "e8cd98", "mid": "d7ad66", "grass": "e0bf84",
                 "grass2": "d3ad6c", "tuft": "c39a5a", "road": "c9a46a", "road2": "b08b52", "stone": "daba84",
                 "stoneS": "aa8a5a", "mortar": "c8a670", "roof": "2f8a7a", "roofS": "1d5e54", "tile": "ece6d6",
                 "tileS": "bdb5a2", "wood": "7a5232", "plaster": "ece6d6", "thatch": "c99a62", "thatchS": "9c7244"},
    "ryumon": {"sky": ["88a9c4", "c9cdd6", "f0d6cf"], "far": "8592a8", "mid": "4f6658", "grass": "7c9c54",
               "grass2": "6c8c48", "tuft": "587a3c", "road": "9a8a6a", "road2": "7a6a50", "stone": "8a8a86",
               "stoneS": "5a5a58", "mortar": "a0a09c", "roof": "3a3f4a", "roofS": "262a33", "tile": "3a3f4a",
               "tileS": "262a33", "wood": "4a362e", "plaster": "f1ece0", "thatch": "a8875a", "thatchS": "7a6040"},
}
BANNER_VARD = {"map": {"B": "3459b8", "W": "e6e8f0", "R": "c9473d"},
               "rows": ["BBBBBBB", "BBBRBBB", "BBWWWBB", "BWBWBWB", "BWWWWWB", "BWWBWWB", "BWWBWWB", "BBBBBBB", ".BBBBB.", "..BBB.."]}
FIG_VARD = {"rows": [".hh.", ".ss.", "bbbb", "bsbb", ".bb.", ".ll.", ".l.l"],
            "map": {"h": "6a4a2c", "s": "e2b284", "b": "5c7a3a", "l": "3a2c22"}, "alt": {"b": "8a4a3a", "h": "c8a060"}}
TEAM_VARD = {"T": "4a74d1", "t": "284282", "L": "a0befa"}


def hexc(c):
    if isinstance(c, tuple):
        return c
    c = c.lstrip("#")
    return (int(c[0:2], 16) / 255, int(c[2:4], 16) / 255, int(c[4:6], 16) / 255, 1.0 if len(c) < 8 else int(c[6:8], 16) / 255)


def lerp(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3)) + (1.0,)


def lightened(c, k):
    c = hexc(c)
    return tuple(min(1.0, c[i] + (1.0 - c[i]) * k) for i in range(3)) + (1.0,)


def darkened(c, k):
    c = hexc(c)
    return tuple(c[i] * (1.0 - k) for i in range(3)) + (1.0,)


# Sprite palette and the party sprites, read from the game's data so the party is the real one.
def load_sprites():
    path = os.path.join(os.path.dirname(__file__), "..", "scripts", "art", "map_sprite_data.gd")
    src = open(path).read()
    pal = {}
    for m in re.finditer(r'"(\w)": Color\(([\d.]+), ([\d.]+), ([\d.]+)\)', src):
        pal[m.group(1)] = (float(m.group(2)), float(m.group(3)), float(m.group(4)), 1.0)
    sprites = {}
    for name in ["follower/vardish", "mounted/vardish"]:
        i = src.index('"%s": {' % name)
        j = src.index('"frames": [', i)
        k = src.index("],", j)
        rows = re.findall(r'"([.\w]+)"', src[j:k])
        sprites[name] = rows
    return pal, sprites


PAL, SPRITES = load_sprites()


class Painter:
    def __init__(self):
        self.img = [[(0.0, 0.0, 0.0, 0.0)] * W for _ in range(H)]
        self.ga = 1.0
        self.lights = []
        self.fires = []
        self.lanterns = []
        self.smokes = []
        self.wheels = []

    def put(self, x, y, c):
        if x < 0 or y < 0 or x >= W or y >= H:
            return
        c = hexc(c)
        a = c[3] * self.ga
        if a >= 0.999:
            self.img[y][x] = (c[0], c[1], c[2], 1.0)
            return
        if a <= 0:
            return
        d = self.img[y][x]
        k = d[3] * (1.0 - a)
        oa = a + k
        self.img[y][x] = tuple((c[i] * a + d[i] * k) / oa for i in range(3)) + (oa,)

    def r(self, x, y, w, h, c):
        x0, y0, w0, h0 = round(x), round(y), round(w), round(h)
        for yy in range(y0, y0 + h0):
            for xx in range(x0, x0 + w0):
                self.put(xx, yy, c)

    def p(self, x, y, c):
        self.put(round(x), round(y), c)

    def faint(self, a, fn):
        was = self.ga
        self.ga = a
        fn()
        self.ga = was

    def grid(self, rows, x, y, m=None, flip=False):
        m = m or {}
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == ".":
                    continue
                col = m.get(ch, PAL.get(ch, "ff00ff"))
                self.p(x + (len(row) - 1 - i if flip else i), y + j, col)

    def ridge(self, f, c, x0=0, x1=W, bottom=H):
        for x in range(x0, x1):
            y = round(f(x))
            self.r(x, y, 1, bottom - y, c)

    def tri(self, x0, x1, top, base, c, sh=None):
        mid = (x0 + x1) / 2.0
        for y in range(top, base + 1):
            t = (y - top) / max(1.0, base - top)
            half = (x1 - x0) / 2.0 * t
            for x in range(round(mid - half), round(mid + half) + 1):
                self.p(x, y, sh if sh is not None and x > mid else c)

    def dome(self, cx, by, rad, c, sh=None, hi=None):
        for y in range(-rad, 1):
            w = round(math.sqrt(rad * rad - y * y))
            for x in range(-w, w + 1):
                col = c
                if sh is not None and x > w * 0.25:
                    col = sh
                elif hi is not None and x < -w * 0.4 and y < -rad * 0.3:
                    col = hi
                self.p(cx + x, by + y, col)

    def win(self, x, y, w=1, h=2, c=DARK):
        self.r(x, y, w, h, c)
        self.lights.append((x, y, w, h))

    def torch(self, x, y):
        self.r(x, y + 1, 1, 2, "4a3324")
        self.fires.append((x, y))

    def smoke(self, x, y, h, c, a):
        self.smokes.append((x, y, h, c, a))

    def wash(self, c, a):
        c = hexc(c)
        for y in range(H):
            for x in range(W):
                d = self.img[y][x]
                if d[3] > 0:
                    self.img[y][x] = tuple(d[i] + (c[i] - d[i]) * a for i in range(3)) + (d[3],)

    def multiply(self, t):
        for y in range(H):
            for x in range(W):
                d = self.img[y][x]
                self.img[y][x] = (d[0] * t[0], d[1] * t[1], d[2] * t[2], d[3])


def col(key, L):
    return L[key]


# ---------------------------------------------------------------- the village as it is

def sky(P, o, L):
    cols = ["0d1430", "1b2650", "34406a"] if o["night"] else L["sky"]
    n = len(cols) - 1
    for y in range(HZ + 6):
        t = y / (HZ + 6) * n
        i = min(n - 1, int(t))
        f = t - i
        q = f * 4.0
        qi = int(q)
        qf = q - qi
        a, b = hexc(cols[i]), hexc(cols[i + 1])
        for x in range(W):
            k = (qi + 1 if qf * 16.0 > BAYER[y % 4][x % 4] else qi) / 4.0
            P.img[y][x] = lerp(a, b, k)
    P.r(0, HZ + 6, W, H - HZ - 6, cols[n])


def pine(P, x, base, h, c="2f5a3e", s="244834"):
    P.r(x, base - 2, 1, 2, "4a3324")
    for i in range(h):
        w = int(math.fmod(i * 0.6, 3.0)) + int(i / 3)
        for k in range(-w, w + 1):
            P.p(x + k, base - h - 1 + i, s if k > 0 else c)


def oak(P, x, base, rad):
    c, s = "4f7a3e", "3a5e2e"
    P.r(x, base - rad, 1, rad, "5a3e28")
    P.dome(x, base - rad + 1, rad, c, s, lightened(c, 0.15))
    P.r(x - rad + 1, base - rad + 1, 2 * rad - 1, 1, s)


def land(P, L):
    P.ridge(lambda x: 33 + math.sin(x / 23.0) * 3 + math.sin(x / 9.0 + 1) * 1.2, col("far", L), 0, W, HZ + 2)
    P.ridge(lambda x: 39 + math.sin(x / 17.0 + 2) * 2.2, col("mid", L), 0, W, HZ + 2)
    for x in range(2, W, 5):
        pine(P, x + (x * 7 % 3), 43 + round(math.sin(x / 17.0 + 2) * 1.5), 5 + (x * 13 % 4), "3f6a4a", "2f5a3e")


def ground(P, L):
    g1, g2 = col("grass", L), col("grass2", L)
    for y in range(HZ, H):
        t = (y - HZ) / (H - HZ)
        for x in range(W):
            P.img[y][x] = hexc(g2 if t * 16.0 > BAYER[y % 4][x % 4] + 4 else g1)
    # Godot's RNG with seed 17 isn't reproducible here; a fixed scatter stands in.
    tuft = col("tuft", L)
    for i in range(60):
        x = (i * 37 + 11) % W
        y = HZ + 2 + (i * 53 + 7) % (H - HZ - 3)
        P.p(x, y, tuft)
        P.p(x + 1, y - 1, tuft)


def road(P, L, gx, gy, w0):
    rd, edge = col("road", L), col("road2", L)
    for y in range(gy, H):
        t = (y - gy) / (H - gy)
        half = w0 / 2.0 + t * 14.0
        P.r(gx - half, y, half * 2.0, 1, rd)
        P.p(gx - half, y, edge)
        P.p(gx + half - 1, y, edge)
        if (y * 5) % 7 == 0:
            P.p(gx - 2 + (y % 5), y, edge)


def fields(P, x0, y0, w, h, cols):
    for y in range(h):
        for x in range(w):
            P.p(x0 + x, y0 + y, cols[int(math.floor((x + y * 0.5) / 2.0)) % len(cols)])


def banner(P, x, y, pole=0):
    if pole > 0:
        P.r(x - 1, y - 1, 1, pole + 1, "3a2a1c")
        P.p(x - 1, y - 2, GOLD)
    P.grid(BANNER_VARD["rows"], x, y, BANNER_VARD["map"])


def person(P, x, y, alt=False, flip=False, tool=""):
    m = dict(FIG_VARD["map"])
    if alt:
        m.update(FIG_VARD["alt"])
    P.grid(FIG_VARD["rows"], x, y - 7, m, flip)
    if tool == "hoe":
        P.r(x + (-1 if flip else 4), y - 6, 1, 6, "7a5232")
        P.p(x + (-2 if flip else 5), y - 1, "9c948a")
    elif tool == "basket":
        P.r(x + (-1 if flip else 3), y - 4, 2, 2, "b8945a")


def guard(P, x, y, c):
    P.p(x + 1, y, "9aa0aa")
    P.p(x + 1, y + 1, "e2b284")
    P.r(x, y + 2, 3, 3, c)
    P.r(x + 3, y - 2, 1, 7, "5a4030")
    P.p(x + 3, y - 3, "bbb5a4")


def beast(P, kind, x, y, flip=False):
    if kind == "sheep":
        P.grid([".www.", "wwwwk", "wwww.", ".k.k."], x, y - 4, {"w": "e8e2d2", "k": "3a3030"}, flip)
    elif kind == "hen":
        P.grid([".r", "ww", "w."], x, y - 3, {"r": "c9473d", "w": "f0ead8"})


def vard_village(P, o, L):
    """scripts/ui/settlement_scene.gd _vard_village, healthy, with the improvement hooks."""
    imps = o["improvements"]
    fields(P, 0, 44, 70, 8, ["8aaa52", "7a9a46", "d0b662", "c4a858"])
    fields(P, 112, 44, 68, 8, ["d0b662", "c4a858", "8aaa52", "7a9a46"])
    oak(P, 24, 46, 5)
    oak(P, 150, 46, 6)
    oak(P, 166, 48, 4)
    wood = col("wood", L)

    def cottage(x, base, w, h, i):
        P.r(x, base - h, w, h, col("plaster", L))
        for xx in range(int(x), int(x) + w, 4):
            P.r(xx, base - h, 1, h, wood)
        P.r(x, base - h, w, 1, wood)
        rc, rs = col("thatch", L), col("thatchS", L)
        P.tri(x - 2, x + w + 1, int(base - h - 6), int(base - h), rc, rs)
        for yy in range(int(base - h - 4), int(base - h), 2):
            P.r(x, yy, w, 1, darkened(rc, 0.12))
        P.r(x + w - 3, base - h - 7, 2, 4, col("stoneS", L))
        P.smoke(x + w - 2, base - h - 8, 8, "d8d4d0", 0.45)
        P.r(x + 2, base - 4, 2, 4, "4a3324")
        P.win(x + w - 4, base - h + 2, 2, 2)

    # NEW: the granary stands on the field edge, behind the left fence, before the cottages.
    if "granary" in imps:
        granary_vard(P, L, 4, 54)
    cottage(44, 56, 12, 7, 0)
    cottage(64, 52, 10, 6, 1)
    cottage(110, 53, 11, 6, 2)
    cottage(128, 58, 13, 8, 3)
    # The shrine by the road.
    P.r(96, 58, 7, 4, col("stone", L))
    P.r(96, 58, 7, 1, col("stoneS", L))
    P.r(96, 52, 1, 6, wood)
    P.r(102, 52, 1, 6, wood)
    P.tri(95, 104, 49, 52, col("thatch", L), col("thatchS", L))
    # NEW: the mill's brook runs down the right edge, behind the fence, before it is cut.
    if "mill" in imps:
        brook_vard(P)
    # The rail fences, or the palisade in their place.
    if "fortifications" in imps:
        palisade_vard(P, L, 2, 40, 58)
        palisade_vard(P, L, 144, 154 if "mill" in imps else 178, 60)
        watchtower_vard(P, L, o, 82, 64)
        gate_posts_vard(P, L, 64)
    else:
        for x in range(4, 40, 4):
            P.r(x, 62, 1, 4, wood)
        P.r(4, 63, 36, 1, "8a6a44")
        for x in range(144, 154 if "mill" in imps else 178, 4):
            P.r(x, 64, 1, 4, wood)
        P.r(144, 65, 10 if "mill" in imps else 34, 1, "8a6a44")
    banner(P, 30, 48, 10)
    if "mill" in imps:
        mill_vard(P, L, 154, 72)


def foreground(P, o):
    imps = o["improvements"]
    if "mill" in imps:
        # The flock grazes left of the road once the mill and stalls take the right.
        beast(P, "sheep", 50, 72)
        beast(P, "sheep", 60, 76, True)
        beast(P, "sheep", 40, 70)
        beast(P, "hen", 136, 72)
        beast(P, "hen", 141, 74)
        market_vard(P, o, [[98, 79], [114, 79]])
        person(P, 108, 79, True, True)
    else:
        beast(P, "sheep", 150, 74)
        beast(P, "sheep", 160, 76, True)
        beast(P, "sheep", 166, 72)
        beast(P, "hen", 112, 70)
        beast(P, "hen", 116, 72)
    person(P, 22, 74, False, False, "hoe")
    person(P, 78, 70, True, True)
    if "mill" not in imps:
        person(P, 120, 76, False, False, "basket")
    # Your party, right of the road, as settlement_scene._foreground places it.
    x = 134
    P.grid(SPRITES["follower/vardish"], x - 18, 67, TEAM_VARD)
    P.grid(SPRITES["follower/vardish"], x - 10, 68, TEAM_VARD)
    P.grid(SPRITES["mounted/vardish"], x, 52, TEAM_VARD)


# ---------------------------------------------------------------- the improvements (Vardish)

def granary_vard(P, L, x, base):
    """A timber barn on four staddle stones, 16 wide, from `base` (the floor) up 17 rows."""
    stone, shade = col("stone", L), col("stoneS", L)
    wood = col("wood", L)
    board = "7a5a3a"
    # Staddle stones: a stalk and a wider cap, so rats can't climb in.
    for sx in (x + 1, x + 5, x + 9, x + 13):
        P.r(sx + 1, base - 2, 1, 2, shade)
        P.r(sx, base - 3, 3, 1, stone)
    P.r(x - 1, base - 4, 18, 1, wood)                      # sill beam
    P.r(x, base - 11, 16, 7, board)                        # plank walls
    for xx in range(x, x + 16, 3):
        P.r(xx, base - 11, 1, 7, wood)
    P.r(x, base - 11, 16, 1, wood)
    P.r(x + 6, base - 9, 3, 5, DARK)                       # the loading door
    P.r(x + 6, base - 6, 3, 1, "3a3030")
    P.r(x + 7, base - 13, 1, 1, DARK)                      # owl hole under the ridge
    rc, rs = col("thatch", L), col("thatchS", L)
    P.tri(x - 2, x + 17, base - 17, base - 11, rc, rs)     # a steeper, taller roof than the cottages
    for yy in range(base - 15, base - 11, 2):
        P.r(x + 1, yy, 14, 1, darkened(rc, 0.12))
    # Sacks on the ramp, and a ramp.
    P.r(x + 9, base - 3, 5, 1, "8a6a44")
    P.r(x + 14, base - 2, 2, 2, "d0b662")
    P.p(x + 15, base - 3, "c4a858")


def palisade_vard(P, L, x0, x1, base):
    """Sharpened stakes two apart with a rail, replacing a rail fence."""
    wood = col("wood", L)
    for i, x in enumerate(range(x0, x1, 2)):
        h = 9 if i % 3 else 8
        P.r(x, base - h, 1, h, wood)
        P.p(x, base - h, "8a6a44")                          # the pale cut tip
        P.p(x, base - h + 1, "4a3222")
    P.r(x0, base - 4, x1 - x0, 1, "8a6a44")
    P.r(x0, base - 7, x1 - x0, 1, "6a4e30")


def watchtower_vard(P, L, o, x, base):
    """A timber tower on four legs by the road: platform, rail, a slate roof, a guard with a torch."""
    wood = col("wood", L)
    # Legs and cross braces.
    for lx in (x - 4, x + 4):
        P.r(lx, base - 15, 1, 15, wood)
    for i in range(0, 12, 1):
        P.p(x - 3 + i * 7 // 11, base - 3 - i, "4a3222")
        P.p(x + 3 - i * 7 // 11, base - 3 - i, "4a3222")
    # Platform with a rail and the ladder down.
    P.r(x - 6, base - 16, 13, 1, "8a6a44")
    P.r(x - 6, base - 17, 13, 1, "6a4e30")
    for px in (x - 6, x + 6):
        P.r(px, base - 21, 1, 4, wood)
    P.r(x - 6, base - 20, 13, 1, "8a6a44")
    for yy in range(base - 15, base, 3):
        P.r(x + 5, yy, 2, 1, "a97846")
    # Roof posts and the slate roof.
    for px in (x - 5, x + 5):
        P.r(px, base - 25, 1, 5, wood)
    P.tri(x - 8, x + 8, base - 29, base - 25, col("roof", L), col("roofS", L))
    P.p(x, base - 30, GOLD)
    # The watch, and his torch for the night.
    guard(P, x - 2, base - 24, hexc(TEAM_VARD["T"]))
    P.torch(x + 4, base - 24)
    P.lanterns.append((x + 4, base - 24))


def gate_posts_vard(P, L, base):
    """Two taller stakes flanking the road mouth, so the palisade reads as having a gate."""
    for gx in (86, 94):
        P.r(gx, base - 10, 1, 10, col("wood", L))
        P.p(gx, base - 10, "8a6a44")


def brook_vard(P):
    """A stream down the right edge, widening as it comes forward."""
    for y in range(50, H):
        t = (y - 50) / 30.0
        cx = 177 - t * 8
        w = 3 + t * 3
        P.r(cx - w / 2, y, w, 1, "6a9ab0")
        P.p(cx - w / 2, y, "5a7a60")
        if y % 3 == 0:
            P.p(cx + (y % 2), y, "a8ccd4")


def mill_vard(P, L, x, base):
    """A stone-footed mill with a slate roof, its wheel on the brook, and the flume."""
    wood = col("wood", L)
    stone, shade = col("stone", L), col("stoneS", L)
    P.r(x, base - 4, 12, 4, stone)                          # stone footing
    P.r(x, base - 4, 12, 1, shade)
    P.r(x, base - 10, 12, 6, col("plaster", L))              # timbered upper floor
    for xx in range(int(x), int(x) + 12, 4):
        P.r(xx, base - 10, 1, 6, wood)
    P.r(x, base - 10, 12, 1, wood)
    P.tri(x - 2, x + 13, base - 15, base - 10, col("roof", L), col("roofS", L))
    P.r(x + 2, base - 3, 2, 3, "4a3324")
    P.win(x + 8, base - 8, 2, 2)
    P.r(x + 9, base - 16, 2, 4, shade)                       # chimney
    P.smoke(x + 10, base - 17, 8, "d8d4d0", 0.45)
    # The wheel: a rim of dark wood, four spokes, standing half in the water.
    cx, cy, rad = x + 16, base - 4, 6
    for a in range(0, 360, 8):
        P.p(cx + round(math.cos(math.radians(a)) * rad), cy + round(math.sin(math.radians(a)) * rad), "4a3222")
    for a in (0, 90):
        for k in range(-rad + 1, rad):
            P.p(cx + round(math.cos(math.radians(a)) * k), cy + round(math.sin(math.radians(a)) * k), "6a4e30")
    for a in range(0, 360, 45):
        P.p(cx + round(math.cos(math.radians(a)) * rad), cy + round(math.sin(math.radians(a)) * rad), "8a6a44")
    for a in range(0, 360, 10):                               # a second ring makes the rim read
        P.p(cx + round(math.cos(math.radians(a)) * (rad - 1)), cy + round(math.sin(math.radians(a)) * (rad - 1)), "5a3e28")
    P.p(cx, cy, "8a6a44")
    P.wheels.append((cx, cy, rad))
    # Axle and the flume carrying water onto the top of the wheel.
    P.r(x + 12, cy, 4, 1, wood)
    P.r(x + 13, cy - rad - 2, 8, 1, "8a6a44")
    P.r(x + 20, cy - rad - 3, 1, 2, "a8ccd4")
    # Foam where the wheel strikes the water.
    for k in range(-3, 4, 2):
        P.p(cx + k, cy + 2, "d8eaee")


def market_vard(P, o, spots):
    """settlement_scene._market, as a town paints it, at village spots."""
    aw = ["c9473d", "efe6d0"]
    goods = ["c9473d", "d0b662", "8aaa52", "e6dcc2"]
    wood = "6e4a2e"
    for i, (x, y) in enumerate(spots):
        P.r(x, y - 7, 1, 7, wood)
        P.r(x + 13, y - 7, 1, 7, wood)
        for k in range(15):
            P.r(x - 1 + k, y - 10, 1, 3, aw[int(k / 2) % 2])
        P.r(x, y - 3, 14, 3, wood)
        P.r(x, y - 3, 14, 1, "8a5c38")
        for k in range(6):
            P.p(x + 1 + k, y - 4 - (k % 2), goods[(k + i) % len(goods)])


# ---------------------------------------------------------------- the other cultures' plates

def granary_khar(P, L, x, base):
    """A domed mud-brick store (a matmura) with a ladder to its hatch and sacks at its foot."""
    c, s = "c99a62", "9c7244"
    P.dome(x + 8, base - 2, 9, c, s, lightened(c, 0.12))
    P.r(x - 1, base - 2, 18, 2, c)
    P.r(x + 14, base - 2, 3, 2, s)
    P.r(x + 7, base - 5, 3, 3, DARK)                        # low door
    P.p(x + 8, base - 12, DARK)                             # the hatch at the crown
    for yy in range(base - 11, base, 2):                    # ladder up the shoulder
        P.p(x + 13 - (base - yy) // 4, yy, "7a5232")
    P.r(x + 18, base - 2, 2, 2, "d9962b")
    P.p(x + 19, base - 3, "d0b662")


def palisade_khar(P, L, x0, x1, base):
    """A mud-brick wall with a stepped parapet."""
    c, s = "daba84", "aa8a5a"
    P.r(x0, base - 6, x1 - x0, 6, c)
    P.r(x0, base - 2, x1 - x0, 1, s)
    for x in range(x0, x1, 3):
        P.r(x, base - 8, 2, 2, c)
        P.p(x + 1, base - 7, s)


def watchtower_khar(P, L, o, x, base):
    """A square brick burj with a lantern niche, its watch on top."""
    c, s = "daba84", "aa8a5a"
    P.r(x - 4, base - 20, 9, 20, c)
    P.r(x + 3, base - 20, 2, 20, s)
    for mx in range(x - 4, x + 5, 3):
        P.r(mx, base - 22, 2, 2, c)
    P.r(x - 1, base - 9, 3, 4, DARK)                        # arched slit
    P.p(x, base - 10, DARK)
    guard(P, x - 2, base - 27, hexc("d9962b"))
    P.torch(x + 3, base - 27)
    P.lanterns.append((x + 3, base - 27))


def mill_khar(P, L, x, base):
    """A noria: a tall wheel lifting water from the channel into a raised trough."""
    c, s = "c99a62", "9c7244"
    P.r(x, base - 8, 10, 8, c)
    P.r(x + 8, base - 8, 2, 8, s)
    P.r(x - 1, base - 9, 12, 1, lightened(c, 0.1))
    P.r(x + 2, base - 3, 2, 3, "3a2a20")
    P.r(x + 10, base - 6, 1, 6, "70a4b0")
    cx, cy, rad = x + 17, base - 7, 7
    for a in range(0, 360, 6):
        P.p(cx + round(math.cos(math.radians(a)) * rad), cy + round(math.sin(math.radians(a)) * rad), "7a5232")
    for a in (0, 90):
        for k in range(-rad + 1, rad):
            P.p(cx + round(math.cos(math.radians(a)) * k), cy + round(math.sin(math.radians(a)) * k), "9c7244")
    for a in range(0, 360, 30):
        P.p(cx + round(math.cos(math.radians(a)) * (rad - 1)), cy + round(math.sin(math.radians(a)) * (rad - 1)), "e8dcc0")
    P.r(cx - 9, base - 1, 18, 1, "70a4b0")
    P.r(cx - 9, base - 2, 18, 1, "a8ccd4")
    P.r(x + 10, cy - rad - 1, 9, 1, "9c7244")               # the trough the pots tip into
    P.wheels.append((cx, cy, rad))


def granary_ryu(P, L, x, base):
    """A raised kura: plaster walls on posts, a heavy dark tile roof, a shuttered window."""
    wood = col("wood", L)
    for px in (x + 1, x + 6, x + 11):
        P.r(px, base - 3, 1, 3, wood)
    P.r(x - 1, base - 4, 15, 1, wood)
    P.r(x, base - 11, 13, 7, col("plaster", L))
    P.r(x, base - 11, 13, 1, wood)
    P.r(x + 11, base - 11, 2, 7, "d8d2c4")
    P.r(x + 2, base - 9, 3, 3, DARK)
    P.p(x + 3, base - 8, "8a8a86")
    for k in range(6):
        inset = max(0, 5 - k)
        P.r(x - 2 + inset, base - 17 + k, 17 - inset * 2, 1, col("tileS", L) if k > 3 else col("tile", L))
    P.r(x + 3, base - 18, 7, 2, "262a33")
    P.r(x + 14, base - 2, 2, 2, "b8945a")                   # a rice bale


def palisade_ryu(P, L, x0, x1, base):
    """Bamboo stakes lashed in pairs, with a rope rail."""
    for i, x in enumerate(range(x0, x1, 2)):
        h = 8 if i % 2 else 7
        P.r(x, base - h, 1, h, "a8a060")
        P.p(x, base - h, "d8d2a0")
        for yy in range(base - h + 2, base, 3):
            P.p(x, yy, "7a7440")
    P.r(x0, base - 5, x1 - x0, 1, "6a5a3e")


def watchtower_ryu(P, L, o, x, base):
    """A yagura: four posts, a railed deck, a hipped tile roof, a lantern."""
    wood = col("wood", L)
    for lx in (x - 4, x + 4):
        P.r(lx, base - 16, 1, 16, wood)
    for i in range(0, 10):
        P.p(x - 3 + i * 7 // 9, base - 3 - i, "3a2a24")
    P.r(x - 6, base - 17, 13, 1, "8a6a44")
    P.r(x - 6, base - 20, 13, 1, "b8352a")                  # red rail
    for px in (x - 6, x + 6):
        P.r(px, base - 20, 1, 3, "b8352a")
    for px in (x - 5, x + 5):
        P.r(px, base - 25, 1, 5, wood)
    for k in range(5):
        inset = max(0, 4 - k)
        P.r(x - 9 + inset, base - 30 + k, 19 - inset * 2, 1, col("tileS", L) if k > 2 else col("tile", L))
    guard(P, x - 2, base - 24, hexc("b8352a"))
    P.r(x + 4, base - 24, 1, 3, "f1ece0")                   # paper lantern
    P.p(x + 4, base - 23, "ffb84a")
    P.lanterns.append((x + 4, base - 23))


def mill_ryu(P, L, x, base):
    """A small timber mill over the paddy channel, its wheel under the eaves."""
    wood = col("wood", L)
    P.r(x, base - 9, 12, 9, wood)
    P.r(x + 2, base - 8, 8, 6, col("plaster", L))
    for xx in range(int(x) + 3, int(x) + 10, 3):
        P.r(xx, base - 8, 1, 6, wood)
    for k in range(6):
        inset = max(0, 5 - k)
        P.r(x - 2 + inset, base - 15 + k, 16 - inset * 2, 1, col("thatchS", L) if k > 3 else col("thatch", L))
    P.r(x + 5, base - 3, 3, 3, "2a2024")
    cx, cy, rad = x + 16, base - 4, 5
    for a in range(0, 360, 10):
        P.p(cx + round(math.cos(math.radians(a)) * rad), cy + round(math.sin(math.radians(a)) * rad), "3a2a24")
    for a in (0, 90):
        for k in range(-rad + 1, rad):
            P.p(cx + round(math.cos(math.radians(a)) * k), cy + round(math.sin(math.radians(a)) * k), "6a5a4a")
    P.r(x + 12, cy, 4, 1, wood)
    P.r(cx - 7, base - 1, 14, 1, "a8ccd4")
    P.r(x + 12, cy - rad - 2, 9, 1, "6a5a4a")
    P.wheels.append((cx, cy, rad))


PLATES = {
    "vardish": {"granary": lambda P, L: granary_vard(P, L, 8, 26), "fortifications": lambda P, L: (palisade_vard(P, L, 2, 14, 28), palisade_vard(P, L, 24, 38, 28), watchtower_vard(P, L, {}, 19, 30)),
                "mill": lambda P, L: mill_vard(P, L, 6, 27)},
    "kharzani": {"granary": lambda P, L: granary_khar(P, L, 8, 27), "fortifications": lambda P, L: (palisade_khar(P, L, 2, 38, 28), watchtower_khar(P, L, {}, 19, 28)),
                 "mill": lambda P, L: mill_khar(P, L, 5, 27)},
    "ryumon": {"granary": lambda P, L: granary_ryu(P, L, 10, 26), "fortifications": lambda P, L: (palisade_ryu(P, L, 2, 14, 28), palisade_ryu(P, L, 24, 38, 28), watchtower_ryu(P, L, {}, 19, 30)),
               "mill": lambda P, L: mill_ryu(P, L, 6, 27)},
}
PLATE_W, PLATE_H = 40, 30


def plate(culture, key, ghost=False):
    """The improvement alone on a strip of its culture's ground, 40 x 30, for the Manor card.
    A ghost is the same drawing dimmed and desaturated: what you could build."""
    L = LOOK[culture]
    P = Painter()
    rows = []
    for y in range(PLATE_H):
        t = y / PLATE_H
        for x in range(PLATE_W):
            if y < 24:
                P.img[y][x] = hexc("1a2138")
            else:
                P.img[y][x] = hexc(L["grass2"] if (x + y) % 3 == 0 else L["grass"])
    PLATES[culture][key](P, L)
    img = to_image(P, 1).crop((0, 0, PLATE_W, PLATE_H))
    if ghost:
        px = img.load()
        for y in range(PLATE_H):
            for x in range(PLATE_W):
                r, g, b, a = px[x, y]
                if y < 24 and (r, g, b) == (0x1A, 0x21, 0x38):
                    continue
                if y >= 24:
                    continue
                m = int(0.3 * r + 0.59 * g + 0.11 * b)
                px[x, y] = (int(m * 0.45 + 0x1A * 0.55), int(m * 0.45 + 0x21 * 0.55), int(m * 0.5 + 0x38 * 0.5), a)
    return img


# ---------------------------------------------------------------- night, output

def night(P, o):
    for (x, y, w, h) in P.lights:
        P.r(x, y, w, h, "ffd27a")
    P.multiply(NIGHT_TINT)
    for (x, y, w, h) in P.lights:
        P.r(x, y, w, h, "ffd27a")
    for (x, y) in P.fires:
        P.r(x - 1, y - 1, 3, 3, (1.0, 0.6, 0.23, 0.25))
        P.p(x, y, "ffd678")
        P.p(x, y - 1, "ff7a3a")
    for (x, y) in P.lanterns:
        P.r(x - 2, y - 2, 5, 6, (1.0, 0.48, 0.29, 0.22))
        P.r(x, y, 1, 2, "ff6a3a")


def draw_smokes(P):
    for (x, y, h, c, a) in P.smokes:
        for i in range(h):
            t = i / h
            rr = 1.0 + t * 4.0
            cx = x + t * t * 10.0
            for dx in range(-int(rr), int(rr) + 1):
                if (dx + i) % 2 and abs(dx) > rr - 1.2:
                    continue
                P.put(round(cx + dx), y - i, hexc(c)[:3] + (a * (1.0 - t * 0.6),))


def build(o):
    L = LOOK["vardish"]
    sky_p = Painter()
    sky(sky_p, o, L)
    P = Painter()
    land(P, L)
    ground(P, L)
    road(P, L, 90, 60, 4)
    vard_village(P, o, L)
    foreground(P, o)
    draw_smokes(P)
    if o["night"]:
        night(P, o)
        night_sky = Painter()
        sky(night_sky, o, L)
        for i in range(40):
            night_sky.p((i * 47 + 5) % W, (i * 31 + 3) % 26, "ffffff" if i % 5 == 0 else "a9b5d9")
        sky_p = night_sky
    # Composite the front over the sky.
    out = Painter()
    out.img = [row[:] for row in sky_p.img]
    for y in range(H):
        for x in range(W):
            c = P.img[y][x]
            if c[3] > 0:
                out.put(x, y, c)
    return out


def to_image(P, scale=4):
    img = Image.new("RGBA", (W, H))
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = P.img[y][x]
            px[x, y] = (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(c[3] * 255))
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    base = {"night": False, "improvements": []}
    to_image(build(base)).save(os.path.join(out, "before.png"))
    for key in ["granary", "fortifications", "mill"]:
        to_image(build({"night": False, "improvements": [key]})).save(os.path.join(out, "step_%s.png" % key))
    everything = {"night": False, "improvements": ["granary", "fortifications", "mill"]}
    to_image(build(everything)).save(os.path.join(out, "after.png"))
    to_image(build({"night": True, "improvements": ["granary", "fortifications", "mill"]})).save(os.path.join(out, "night.png"))
    for culture in LOOK:
        for key in ["granary", "fortifications", "mill"]:
            plate(culture, key).resize((PLATE_W * 4, PLATE_H * 4), Image.NEAREST).save(os.path.join(out, "plate_%s_%s.png" % (culture, key)))
            plate(culture, key, True).resize((PLATE_W * 4, PLATE_H * 4), Image.NEAREST).save(os.path.join(out, "plate_%s_%s_ghost.png" % (culture, key)))
    print("wrote", out)


if __name__ == "__main__":
    main()
