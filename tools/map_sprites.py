"""Authoring tool for Bannerfall's world-map pixel art.

Draws the settlements of each culture (town, castle, village) in a three-quarter view,
the terrain that grows between them (trees, pines, palms, blossom, dunes, mountains,
mesas, fields and paddies) and the parties on the roads, as palette-indexed grids. Writes
them to scripts/art/map_sprite_data.gd, which the game turns into textures at startup,
and to a preview PNG. T/t/L are the owner's colors, swapped in by the game.

    python3 tools/map_sprites.py [preview_dir]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from unit_sprites import Grid, PALETTE as UNIT_PALETTE  # noqa: E402

PALETTE = dict(UNIT_PALETTE)
PALETTE.update({
    "a": (200, 192, 174),   # stone wall
    "A": (140, 130, 116),   # stone wall shade
    "o": (176, 76, 54),     # red tile roof
    "O": (120, 48, 38),     # red tile shade
    "j": (100, 112, 138),   # slate roof
    "J": (66, 74, 96),      # slate shade
    "d": (218, 186, 132),   # sandstone
    "D": (170, 138, 90),    # sandstone shade
    "1": (242, 246, 250),   # snow
    "2": (112, 164, 176),   # paddy water
    "3": (138, 170, 82),    # green field
    "4": (208, 182, 98),    # ripe field
    "5": (176, 106, 72),    # mesa rock
    "6": (122, 72, 50),     # mesa shade
    "7": (36, 72, 52),      # pine shade
    "8": (60, 104, 70),     # pine
    "9": (236, 210, 156),   # dune crest
    "0": (255, 214, 120),   # lit window
})
TEAM = {"T": (74, 116, 209), "t": (40, 66, 130), "L": (160, 190, 250)}


def tri_roof(g, x0, x1, top, base, c, shade):
    """A gabled roof seen from the front: a triangle, its right half in shade."""
    mid = (x0 + x1) / 2.0
    for y in range(top, base + 1):
        t = (y - top) / max(1.0, base - top)
        half = (x1 - x0) / 2.0 * t
        for x in range(int(round(mid - half)), int(round(mid + half)) + 1):
            g.set(x, y, shade if x > mid else c)


def crenels(g, x0, x1, y, c):
    for x in range(x0, x1 + 1, 2):
        g.set(x, y, c)


def wall(g, x0, y0, x1, y1, c="a", shade="A"):
    g.rect(x0, y0, x1, y1, c)
    g.rect(x0, y1, x1, y1, shade)
    for x in range(x0 + 2, x1, 4):          # coursing
        g.set(x, (y0 + y1) // 2, shade)


def banner(g, x, y, h=4):
    g.line(x, y, x, y + h, "W")
    g.rect(x + 1, y, x + 3, y + 1, "T")
    g.set(x + 3, y + 1, "t")


def tiered_roof(g, cx, y, half, c="b", shade="B"):
    """A Ryumon roof tier: wide, flat, eaves turned up at both ends."""
    g.rect(cx - half, y, cx + half, y + 1, c)
    g.set(cx - half - 1, y - 1, c)
    g.set(cx + half + 1, y - 1, c)
    g.rect(cx - half + 1, y, cx + half - 1, y, shade)


# ------------------------------------------------------------------ settlements

def vardish_town():
    g = Grid(32, 26)
    # houses behind the walls: red roofs
    for x0 in (4, 11, 19):
        g.rect(x0, 9, x0 + 6, 13, "a")
        tri_roof(g, x0 - 1, x0 + 7, 5, 9, "o", "O")
    # the keep, slate-roofed, with a banner
    g.rect(13, 4, 19, 13, "a")
    g.rect(17, 4, 19, 13, "A")
    tri_roof(g, 12, 20, 0, 4, "j", "J")
    banner(g, 16, -3 + 3, 3)
    # curtain wall with two round towers and a gate
    wall(g, 2, 14, 29, 20)
    crenels(g, 2, 29, 13, "a")
    for tx in (1, 26):
        g.rect(tx, 11, tx + 4, 21, "a")
        g.rect(tx + 3, 11, tx + 4, 21, "A")
        tri_roof(g, tx - 1, tx + 5, 7, 11, "j", "J")
    g.rect(14, 16, 17, 20, "k")
    g.set(15, 16, "W")
    g.set(16, 16, "W")
    g.set(8, 16, "0")
    g.set(22, 16, "0")
    g.outline()
    return g


def vardish_castle():
    g = Grid(24, 24)
    g.rect(5, 8, 17, 20, "a")
    g.rect(14, 8, 17, 20, "A")
    crenels(g, 5, 17, 7, "a")
    g.rect(10, 15, 12, 20, "k")
    g.set(8, 11, "0")
    # corner tower with a cone roof and a banner
    g.rect(15, 5, 20, 21, "a")
    g.rect(19, 5, 20, 21, "A")
    tri_roof(g, 14, 21, 0, 5, "j", "J")
    banner(g, 17, 0, 2)
    g.outline()
    return g


def vardish_village():
    g = Grid(28, 18)
    # strips of field
    for i, c in enumerate("3434"):
        g.rect(1 + i * 3, 12, 3 + i * 3, 16, c)
    # half-timbered cottages under thatch
    for x0, top in ((10, 5), (18, 7)):
        g.rect(x0, top + 4, x0 + 6, top + 9, "c")
        for x in (x0, x0 + 3, x0 + 6):
            g.line(x, top + 4, x, top + 9, "W")
        g.rect(x0, top + 9, x0 + 6, top + 9, "W")
        tri_roof(g, x0 - 1, x0 + 7, top, top + 4, "y", "Y")
        g.set(x0 + 2, top + 6, "0")
    g.outline()
    return g


def kharzani_town():
    g = Grid(32, 26)
    # white houses and a great dome behind sandstone walls
    for x0, h in ((3, 9), (21, 8)):
        g.rect(x0, h, x0 + 7, 14, "c")
        g.rect(x0 + 5, h, x0 + 7, 14, "C")
    g.rect(11, 8, 20, 14, "c")
    g.ellipse(15.5, 8.0, 5.0, 4.5, "c", shade="C", light="1")
    g.set(15, 2, "g")
    g.set(15, 3, "g")
    # minaret
    g.rect(24, 1, 25, 12, "c")
    g.rect(25, 1, 25, 12, "C")
    g.rect(23, 3, 26, 3, "D")
    g.set(24, 0, "g")
    wall(g, 1, 14, 30, 20, "d", "D")
    crenels(g, 1, 30, 13, "d")
    for tx in (0, 27):
        g.rect(tx, 11, tx + 4, 21, "d")
        g.rect(tx + 3, 11, tx + 4, 21, "D")
        crenels(g, tx, tx + 4, 10, "d")
    g.ellipse(15.5, 18.5, 2.2, 2.6, "k")
    g.rect(14, 18, 17, 20, "k")
    g.set(7, 16, "0")
    g.set(23, 16, "0")
    banner(g, 5, 6, 3)
    g.outline()
    return g


def kharzani_castle():
    g = Grid(26, 22)
    g.rect(5, 7, 20, 19, "d")
    g.rect(16, 7, 20, 19, "D")
    crenels(g, 5, 20, 6, "d")
    g.ellipse(12.5, 16.0, 1.8, 2.2, "k")
    g.rect(11, 16, 14, 19, "k")
    for tx in (2, 19):
        g.ellipse(tx + 2.5, 12.5, 3.0, 8.0, "d", shade="D")
        crenels(g, tx, tx + 5, 4, "d")
    banner(g, 12, 1, 4)
    g.set(8, 10, "0")
    g.outline()
    return g


def kharzani_village():
    g = Grid(28, 18)
    for x0, y0, w, h in ((3, 8, 7, 6), (11, 10, 6, 5), (18, 7, 6, 7)):
        g.rect(x0, y0, x0 + w, y0 + h, "d")
        g.rect(x0, y0, x0 + w, y0, "9")
        g.rect(x0 + w - 1, y0 + 1, x0 + w, y0 + h, "D")
        g.set(x0 + 2, y0 + 3, "k")
    # a palm by the well
    g.line(25, 15, 24, 6, "W")
    for dx, dy in ((-3, 1), (-2, -1), (0, -2), (2, -1), (3, 1)):
        g.line(24, 5, 24 + dx, 5 + dy, "v")
    g.set(24, 5, "V")
    g.outline()
    return g


def ryumon_town():
    g = Grid(32, 28)
    # town houses with dark roofs
    for x0 in (1, 23):
        g.rect(x0, 17, x0 + 7, 21, "c")
        g.rect(x0, 15, x0 + 7, 16, "b")
        g.set(x0 + 3, 19, "0")
    # the keep on its stone base
    for i, y in enumerate(range(18, 25)):
        g.rect(8 - i // 2, y, 23 + i // 2, y, "a" if i % 2 else "A")
    g.rect(11, 12, 20, 17, "c")
    g.rect(18, 12, 20, 17, "C")
    tiered_roof(g, 15, 10, 6)
    g.rect(12, 7, 19, 9, "c")
    tiered_roof(g, 15, 5, 5)
    g.rect(13, 2, 18, 4, "c")
    tiered_roof(g, 15, 1, 4)
    g.set(13, 0, "g")
    g.set(18, 0, "g")
    g.set(14, 14, "0")
    g.set(17, 8, "0")
    banner(g, 26, 9, 4)
    g.outline()
    return g


def ryumon_castle():
    g = Grid(24, 24)
    for i, y in enumerate(range(15, 22)):
        g.rect(4 - i // 2, y, 19 + i // 2, y, "a" if i % 2 else "A")
    g.rect(7, 9, 16, 14, "c")
    g.rect(14, 9, 16, 14, "C")
    tiered_roof(g, 11, 7, 6)
    g.rect(8, 4, 15, 6, "c")
    tiered_roof(g, 11, 2, 5)
    g.set(9, 1, "g")
    g.set(14, 1, "g")
    g.set(10, 11, "0")
    banner(g, 19, 3, 4)
    g.outline()
    return g


def ryumon_village():
    g = Grid(28, 18)
    # a flooded paddy with rows of rice
    g.rect(1, 11, 11, 16, "2")
    for x in range(2, 11, 2):
        g.line(x, 12, x, 15, "3")
    for x0, top in ((13, 4), (20, 7)):
        g.rect(x0 + 1, top + 5, x0 + 6, top + 9, "w")
        tri_roof(g, x0 - 1, x0 + 8, top, top + 5, "y", "Y")
        g.rect(x0, top + 5, x0 + 7, top + 5, "Y")
        g.set(x0 + 3, top + 7, "0")
    g.outline()
    return g


# ------------------------------------------------------------------ terrain

def tree():
    g = Grid(8, 10)
    g.rect(3, 6, 4, 9, "W")
    g.disc(4.0, 4.0, 3.6, "v", shade="V", light="u")
    g.outline("V")
    return g


def pine():
    g = Grid(8, 11)
    g.rect(3, 8, 4, 10, "W")
    for i, y in enumerate(range(0, 9)):
        half = 0.5 + i * 0.42
        for x in range(int(round(3.5 - half)), int(round(3.5 + half)) + 1):
            g.set(x, y, "7" if x >= 4 else "8")
    g.outline("7")
    return g


def palm():
    g = Grid(10, 11)
    g.line(5, 10, 4, 4, "W")
    g.set(5, 8, "w")
    for dx, dy in ((-4, 2), (-3, -1), (0, -3), (3, -1), (4, 2), (-1, 0), (2, 1)):
        g.line(4, 3, 4 + dx, 3 + dy, "v" if dx < 1 else "V")
    g.set(4, 3, "V")
    return g


def blossom():
    g = Grid(8, 10)
    g.rect(3, 6, 4, 9, "W")
    g.disc(4.0, 4.0, 3.6, "p", shade="o", light="1")
    g.set(2, 3, "1")
    g.outline("O")
    return g


def dune():
    g = Grid(14, 6)
    g.ellipse(7.0, 4.0, 6.5, 2.6, "d", shade="D", light="9")
    g.line(2, 3, 10, 1, "9")
    return g


def mountain(kind):
    """A peak lit from the left: grey in Vardmark, snow-capped on the isles."""
    g = Grid(20, 15)
    peak, base = 9.5, 14
    for y in range(1, base + 1):
        half = (y - 1) * 0.72
        ridge = peak + math.sin(y * 1.9) * 0.9   # the crest wanders, splitting light from shade
        for x in range(int(round(peak - half)), int(round(peak + half)) + 1):
            g.set(x, y, "i" if x < ridge else "E")
        if y > 4 and y % 3 == 0:
            g.set(peak - half + 1, y, "e")          # a gully on the lit face
    if kind == "snow":
        for y in range(1, 5):
            half = (y - 1) * 0.72
            for x in range(int(round(peak - half)), int(round(peak + half)) + 1):
                g.set(x, y, "1" if x <= peak else "C")
    # a second, lower shoulder
    for y in range(7, base + 1):
        half = (y - 7) * 0.8
        for x in range(int(round(15 - half)), int(round(15 + half)) + 1):
            if g.get(x, y) == ".":
                g.set(x, y, "e" if x < 15 else "E")
    g.outline("E")
    return g


def mesa():
    g = Grid(18, 10)
    g.rect(4, 2, 13, 3, "5")
    for y in range(3, 9):
        grow = (y - 3) // 2
        g.rect(4 - grow, y, 13 + grow, y, "5")
        g.rect(10 + grow, y, 13 + grow, y, "6")
    g.rect(4, 2, 13, 2, "9")
    g.outline("6")
    return g


def fields(kind):
    """A patch of farmland around a village: strips of green and gold, or paddies."""
    g = Grid(16, 10)
    if kind == "paddy":
        g.rect(0, 0, 15, 9, "2")
        for y in range(1, 10, 2):
            g.line(0, y, 15, y, "3")
        g.rect(7, 0, 8, 9, "Y")
    else:
        for i in range(4):
            g.rect(i * 4, 0, i * 4 + 3, 9, "3" if i % 2 == 0 else "4")
        if kind == "dry":
            g.rect(0, 0, 15, 9, "4")
            g.rect(0, 4, 15, 5, "3")
    return g


# ------------------------------------------------------------------ parties

def rider(frame):
    """Your warband on the road: a rider under a banner, side on, trotting right."""
    g = Grid(18, 18)
    lift = 1 if frame == 1 else 0
    # banner on a pole
    g.line(7, 1, 7, 10, "W")
    g.rect(8, 1, 12, 4, "T")
    g.rect(8, 4, 12, 4, "t")
    g.set(12, 2, "L")
    # horse
    g.rect(4, 11 - lift, 13, 13 - lift, "r")
    g.rect(4, 13 - lift, 13, 13 - lift, "R")
    g.rect(13, 8 - lift, 15, 11 - lift, "r")
    g.set(15, 8 - lift, "R")
    g.set(16, 9 - lift, "r")
    g.set(3, 11 - lift, "n")
    g.set(2, 12 - lift, "n")
    for x, up in ((5, 0), (7, 1), (11, 1), (12, 0)):
        down = (up + frame) % 2
        g.rect(x, 14 - lift, x, 16 - down, "n")
    # rider in the owner's colors
    g.rect(8, 7 - lift, 10, 10 - lift, "T")
    g.set(10, 8 - lift, "t")
    g.disc(9.5, 6.0 - lift, 1.3, "s")
    g.set(9, 5 - lift, "m")
    g.set(10, 5 - lift, "m")
    g.outline()
    return g


def bandits(frame):
    """A bandit band: three men on foot under a ragged banner."""
    g = Grid(18, 16)
    g.line(3, 1, 3, 12, "W")
    g.rect(4, 1, 8, 3, "H")
    g.set(8, 3, ".")
    g.set(6, 4, "H")
    for i, x in enumerate((3, 8, 13)):
        bob = (i + frame) % 2
        g.rect(x, 9 - bob, x + 2, 12 - bob, "h" if i != 1 else "H")
        g.disc(x + 1.5, 7.5 - bob, 1.3, "S")
        g.rect(x, 13 - bob, x, 14, "n")
        g.rect(x + 2, 13, x + 2, 14 - bob, "n")
    g.line(10, 4, 11, 12, "w")   # a spear
    g.set(10, 3, "m")
    g.outline()
    return g


def lord(frame):
    """A lord's warband: a mounted lord under a tall banner in his realm's colors, a
    rider at his side and a spearman on foot."""
    g = Grid(26, 22)
    lift = 1 if frame == 1 else 0
    # a second rider behind, smaller
    g.rect(1, 13 - lift, 8, 15 - lift, "R")
    g.rect(8, 11 - lift, 9, 13 - lift, "R")
    g.rect(4, 10 - lift, 5, 12 - lift, "t")
    g.disc(4.5, 9.0 - lift, 1.1, "s")
    for x in (2, 7):
        g.rect(x, 16 - lift, x, 18 - (frame + x) % 2, "n")
    # a spearman on foot
    g.rect(20, 14, 21, 17, "h")
    g.disc(20.5, 12.5, 1.2, "S")
    g.rect(20, 18, 20, 19 - frame, "n")
    g.rect(21, 18 - frame, 21, 19, "n")
    g.line(23, 6, 23, 18, "w")
    g.set(23, 5, "m")
    # the lord's tall banner, swallowtailed
    g.line(10, 0, 10, 13, "W")
    g.rect(11, 0, 17, 5, "T")
    g.rect(11, 5, 17, 5, "t")
    g.set(17, 1, ".")
    g.set(17, 4, ".")
    g.set(16, 2, "L")
    g.set(12, 2, "g")
    # the lord's horse, barded in his colors
    g.rect(8, 15 - lift, 18, 17 - lift, "r")
    g.rect(8, 17 - lift, 18, 17 - lift, "R")
    g.rect(9, 15 - lift, 16, 16 - lift, "T")
    g.rect(18, 12 - lift, 20, 15 - lift, "r")
    g.set(20, 12 - lift, "R")
    g.set(21, 13 - lift, "r")
    for x, up in ((9, 0), (11, 1), (15, 1), (17, 0)):
        down = (up + frame) % 2
        g.rect(x, 18 - lift, x, 20 - down, "n")
    # the lord: steel and his colors, a gold circlet
    g.rect(12, 11 - lift, 14, 14 - lift, "T")
    g.set(14, 12 - lift, "t")
    g.disc(13.5, 10.0 - lift, 1.3, "m", shade="M")
    g.set(13, 9 - lift, "g")
    g.set(14, 9 - lift, "g")
    g.outline()
    return g


def marshal(frame, culture):
    """A marshal's host on the march: the marshal mounted under the realm's great standard,
    with a line of foot behind, dressed by culture: Vardish steel and kite shields, Kharzani
    turbans and a horse-tail standard, Ryumon lacquer under tall nobori banners."""
    g = Grid(34, 26)
    lift = 1 if frame == 1 else 0
    head, head_shade = {"vardish": ("m", "M"), "kharzani": ("c", "C"), "ryumon": ("b", "B")}[culture]
    # the column on foot behind, three abreast in two files
    for i, x in enumerate((2, 7, 12, 17)):
        step = (frame + i) % 2
        y0 = 13 + (i % 2)
        g.rect(x, y0 + 2, x + 2, y0 + 5, "T" if i % 2 == 0 else "t")
        g.disc(x + 1.0, y0 + 0.8, 1.2, head, shade=head_shade)
        g.rect(x, y0 + 6, x, y0 + 8 - step, "n")
        g.rect(x + 2, y0 + 6 - step, x + 2, y0 + 8, "n")
        if culture == "vardish":
            g.rect(x - 1, y0 + 2, x - 1, y0 + 5, "L")   # kite shield edge
        g.line(x + 3, y0 - 4, x + 3, y0 + 7, "w")       # spear
        g.set(x + 3, y0 - 5, "m")
    # the great standard
    if culture == "ryumon":
        # tall nobori: narrow vertical banners on crossbar poles
        for x in (6, 15):
            g.line(x, 0, x, 13, "W")
            g.line(x, 0, x + 3, 0, "W")
            g.rect(x + 1, 1, x + 3, 9, "T")
            g.rect(x + 1, 9, x + 3, 9, "t")
            g.set(x + 2, 3, "L")
    else:
        g.line(22, 0, 22, 14, "W")
        g.rect(23, 0, 31, 6, "T")
        g.rect(23, 6, 31, 6, "t")
        g.set(31, 1, ".")
        g.set(31, 5, ".")
        g.disc(26.5, 3.0, 1.4, "g")
        if culture == "kharzani":
            g.line(21, 1, 21, 4, "C")    # horse-tail on the staff
            g.line(20, 2, 20, 5, "c")
    # the marshal, mounted and barded in the realm's colors
    g.rect(19, 18 - lift, 30, 20 - lift, "q")
    g.rect(19, 20 - lift, 30, 20 - lift, "Q")
    g.rect(20, 18 - lift, 28, 19 - lift, "T")
    g.rect(30, 15 - lift, 32, 18 - lift, "q")
    g.set(33, 16 - lift, "q")
    for x, up in ((20, 0), (22, 1), (27, 1), (29, 0)):
        down = (up + frame) % 2
        g.rect(x, 21 - lift, x, 23 - down, "n")
    g.rect(23, 13 - lift, 26, 17 - lift, "T")
    g.set(26, 14 - lift, "t")
    g.disc(24.5, 11.5 - lift, 1.5, head, shade=head_shade)
    g.set(24, 10 - lift, "g")
    g.set(25, 10 - lift, "g")
    g.outline()
    return g



# ---------------------------------------------------------------- parties, drawn as grids
# Each realm's lord rides his own horse (bay, sand, near black) under the realm's cloth;
# his men march behind on foot; bandits look like their region's outlaws. Drawn pixel by
# pixel here (facing right) rather than from shapes; the game flips them for direction.

HORSE = [
    "..................kk.....",
    ".................knRk....",
    "................knRRRk...",
    "...............knRRRRRk..",
    "...............knRRkRRRk.",
    "..............knRRk.kRRRk",
    ".............knRRRk..kkk.",
    "...kkkkkkkkkknRRRk.......",
    "..kRRRRRRRRRRRRRRk.......",
    ".kRRRRRRRRRRRRRRRk.......",
    "kRkRRRRRRRRRRRRRRk.......",
    "n.kRRRRRRRRRRRRRk........",
]
HORSE_LEGS = [
    ["n..kRk.kRk..kRk.kRk......",
     "n..kRk.kRk..kRk.kRk......",
     "...kRk..kRk.kRk..kRk.....",
     "...knk..knk.knk..knk....."],
    ["n..kRk.kRk..kRk.kRk......",
     "n...kRkkRk...kRkkRk......",
     "....kRkRk....kRkRk.......",
     "....knknk....knknk......."],
]
CLOTH = ["...kTTTTTTTTk...", "..kTLTTTTTTLTk..", "..ktgtgtgtgtgk.."]
RIDERS = {
    "vardish": ["...kkk.......k..", "..kmmmk.....kmk.", "..kmkkk.....kwTT", "..kmmmk.....kwk.", ".kTTTTTk....kwk.",
                "kfTTLTTk....kwk.", "kffLLLTskkkkkwk.", "kfTTLTTk....kwk.", ".kfTTTk.....kwk.", "..kTTk......kwk."],
    "kharzani": ["..kkkk.......k.", ".kffffk.....kmk", ".kfgffk....kmk.", "..kssk....kmk..", ".kTTTTk..kmk...",
                 "kTTLTTTkkmk....", "kTTTTTTskk.....", "kgggggk........", ".kTTTTk........", "..kTTk........."],
    "ryumon": ["kkkkk..k.k.....", "k111k..kgk.....", "kTTTk.kbbbk....", "kTkTkkbbbbbk...", "kTTTk..kssk..k.",
               ".W...kTbTbk.kmk", ".W..kbTbTbskkw.", ".W..kTbTbTk..w.", ".W..kbTbTbk..w.", ".W...kbbk....w."],
}
HORSE_COAT = {"vardish": ("R", "n"), "kharzani": ("y", "n"), "ryumon": ("q", "k")}
FOOT = {
    "vardish": ["......k.", "..kkkkmk", ".kmmmkwk", "..kssk.w", ".kTTTTkw", ".kTLTTsw", ".kTTTTkw", "..tttt.w", "..kRkRkw", "..kRkRk.", "..knkn.."],
    "kharzani": ["..kkk...", ".kfffk..", ".kfgfk.k", "..kssk.k", ".kTTTTkk", ".kTTTTsk", ".kTTTTkk", "..TTTT.k", "..kYkYk.", "..kYkYk.", "..knkn.."],
    "ryumon": ["......k.", "..kkkkmk", ".kbbbbwk", "kbbbbbbk", "..kssk.w", ".kTbTbkw", ".kbTbTsw", ".kTbTbkw", "..kbbk.w", "..kQkQkw", "..knkn.."],
}
OUTLAWS = {
    "vardish": ["..kkkk....", ".kHHHHk...", ".kHkssk...", "kHHHHHk.kk", "khhhhhHkmk", "khhhhhhkwk", ".khhhhhsw.", ".khhhhhk..", "..kHkHk...", "..kHkHk...", "..knkn...."],
    "kharzani": ["..kkkk....", ".kyyyyk...", ".kykkyk...", ".kssyyk..k", "kyyyyyykmk", "kyYyyyyskm", "kyyYyyyk.k", ".kyyyyyk..", "..kYkYk...", "..kYkYk...", "..knkn...."],
    "ryumon": ["...kkkk...", "..kyyyyk..", "kyyyyyyyyk", "kYYYYYYYYk", "..kssk...k", ".kbbbbbkmk", ".kbBbbbskk", ".kbbBbbk..", "..kbkbk...", "..kbkbk...", "..knkn...."],
    "wako": ["..kkkkk...", ".kooooOk..", ".kssssk...", "..ksk....k", ".k1o1o1kmk", ".ko1o1oskk", ".k1o1o1k..", "..kssk....", "..kWkWk...", "..kWkWk...", "..knkn...."],
}
CAMPFIRE = [
    ["...o.....", "..o0o..o.", ".o000oo0o", "..o0O00o.", ".kWWWWWk.", "kWk...kWk"],
    [".....o...", "..o.o0o..", ".o0o000o.", "..o00O0..", ".kWWWWWk.", "kWk...kWk"],
]


def _paste(canvas, rows, x0, y0, flip=False):
    for y, r in enumerate(rows):
        if flip:
            r = r[::-1]
        for x, ch in enumerate(r):
            if ch != "." and 0 <= y0 + y < len(canvas) and 0 <= x0 + x < len(canvas[0]):
                canvas[y0 + y][x0 + x] = ch


def _canvas(w, h):
    return [["."] * w for _ in range(h)]


def _rows(canvas):
    return ["".join(r) for r in canvas]


def mounted(culture, frame):
    """A lord of `culture` in the saddle: horse, the realm's cloth, the rider."""
    coat, mane = HORSE_COAT[culture]
    c = _canvas(26, 26)
    horse = [r.replace("R", coat).replace("n", mane) for r in HORSE + HORSE_LEGS[frame]]
    _paste(c, horse, 0, 10)
    _paste(c, CLOTH, 2, 17)
    _paste(c, RIDERS[culture], 4, 9 - (1 if frame == 1 else 0))
    return _rows(c)


def follower(culture, frame):
    rows = FOOT[culture]
    return rows if frame == 0 else rows[1:] + ["." * len(rows[0])]


def outlaw_band(kind, frame):
    """Three of a region's outlaws together."""
    fig = OUTLAWS[kind]
    c = _canvas(26, 16)
    bob = 1 if frame == 1 else 0
    _paste(c, fig, 0, 4)
    _paste(c, fig, 8, 1 + bob, flip=True)
    _paste(c, fig, 15, 5)
    return _rows(c)

SETTLEMENTS = {
    "vardish/town": vardish_town, "vardish/castle": vardish_castle, "vardish/village": vardish_village,
    "kharzani/town": kharzani_town, "kharzani/castle": kharzani_castle, "kharzani/village": kharzani_village,
    "ryumon/town": ryumon_town, "ryumon/castle": ryumon_castle, "ryumon/village": ryumon_village,
}
TERRAIN = {
    "tree": tree, "pine": pine, "palm": palm, "blossom": blossom, "dune": dune,
    "mountain": lambda: mountain("grey"), "mountain_snow": lambda: mountain("snow"), "mesa": mesa,
    "fields": lambda: fields("green"), "fields_dry": lambda: fields("dry"), "paddy": lambda: fields("paddy"),
}


def build_all():
    out = {}
    for name, fn in list(SETTLEMENTS.items()) + list(TERRAIN.items()):
        g = fn()
        # Settlements and terrain stand on the bottom middle of their sprite.
        out[name] = {"frames": [g.rows()], "pivot": (g.w / 2.0, g.h - 1.0)}
    for culture in ("vardish", "kharzani", "ryumon"):
        frames = [marshal(f, culture) for f in range(2)]
        out["marshal/" + culture] = {"frames": [f.rows() for f in frames], "pivot": (frames[0].w / 2.0, frames[0].h - 1.0)}
    for name, fn in (("rider", rider), ("bandits", bandits), ("lord", lord)):
        frames = [fn(f) for f in range(2)]
        out[name] = {"frames": [f.rows() for f in frames], "pivot": (frames[0].w / 2.0, frames[0].h - 1.0)}
    for culture in ("vardish", "kharzani", "ryumon"):
        out["mounted/" + culture] = {"frames": [mounted(culture, f) for f in range(2)], "pivot": (13.0, 25.0)}
        out["follower/" + culture] = {"frames": [follower(culture, f) for f in range(2)], "pivot": (4.0, 10.0)}
    for kind in ("vardish", "kharzani", "ryumon", "wako"):
        out["outlaws/" + kind] = {"frames": [outlaw_band(kind, f) for f in range(2)], "pivot": (13.0, 15.0)}
    out["campfire"] = {"frames": CAMPFIRE, "pivot": (4.5, 5.0)}
    for name, spr in out.items():
        for rows in spr["frames"]:
            assert len(set(len(r) for r in rows)) == 1, name
            for r in rows:
                for ch in r:
                    assert ch == "." or ch in PALETTE or ch in TEAM, (name, ch)
    return out


def gd_color(rgb):
    return "Color(%.3f, %.3f, %.3f)" % tuple(c / 255.0 for c in rgb)


def write_gd(sprites, path):
    lines = [
        "## Generated by tools/map_sprites.py; edit the tool, not this file.",
        "## World-map pixel art: settlements by culture and type, terrain, and parties. Each",
        "## sprite is a list of frames of palette rows, standing on its pivot. T/t/L are the",
        "## owner's colors.",
        "extends RefCounted",
        "",
        "const PALETTE := {",
    ]
    for ch, rgb in PALETTE.items():
        if rgb is not None:
            lines.append('\t"%s": %s,' % (ch, gd_color(rgb)))
    lines.append("}")
    lines.append("")
    lines.append("const SPRITES := {")
    for name, spr in sprites.items():
        lines.append('\t"%s": {' % name)
        lines.append("\t\t\"pivot\": Vector2(%.1f, %.1f)," % spr["pivot"])
        lines.append("\t\t\"frames\": [")
        for rows in spr["frames"]:
            lines.append("\t\t\t[")
            for r in rows:
                lines.append('\t\t\t\t"%s",' % r)
            lines.append("\t\t\t],")
        lines.append("\t\t],")
        lines.append("\t},")
    lines.append("}")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def preview(sprites, out_dir, scale=5):
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    pal = dict(PALETTE)
    pal.update(TEAM)
    names = list(sprites)
    cols = 6
    cell = 36 * scale
    rows_n = (sum(len(sprites[n]["frames"]) for n in names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell * cols, cell * rows_n), (96, 128, 70, 255))
    i = 0
    for name in names:
        for rows in sprites[name]["frames"]:
            img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
            for y, r in enumerate(rows):
                for x, ch in enumerate(r):
                    if ch != ".":
                        img.putpixel((x, y), pal[ch] + (255,))
            img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
            ox = (i % cols) * cell + (cell - img.width) // 2
            oy = (i // cols) * cell + (cell - img.height) // 2
            sheet.alpha_composite(img, (ox, oy))
            i += 1
    sheet.save(os.path.join(out_dir, "map_preview.png"))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = build_all()
    write_gd(sprites, os.path.join(here, "..", "scripts", "art", "map_sprite_data.gd"))
    if len(sys.argv) > 1:
        preview(sprites, sys.argv[1])
    print("wrote scripts/art/map_sprite_data.gd")
