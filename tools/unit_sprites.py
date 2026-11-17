"""Authoring tool for Vaskaria's unit pixel art.

Draws each troop type of each culture top-down, facing up, as small palette-indexed
grids, then writes them to scripts/art/sprite_data.gd (which the game turns into
textures at startup) and to preview PNGs. Team colors are placeholders (T, t, L) that
the game swaps for each side's dye.

A side is told by its dyed cloth and nothing else: a shield's face, a hood, a plume, a
sash, a banner, the hems of a horse's cloth. Steel, leather, wood and undyed cloth are
the same for both. A kind of troop is told by its kit, drawn a little larger than life:
shield and sword, a long spear, a bow, a horse and lance.

The three cultures dress the same four roles differently, so a squad reads at a
glance as well as by its flag:
  Vardish   steel helms, kite shields, surcoats; pikes, crossbows, barded knights
  Kharzani  white turbans, round shields, scimitars; recurve bows, light grey horses
  Ryumon    black lacquer, wide straw hats, sashimono banners; katana, yari, long yumi

    python3 tools/unit_sprites.py [preview_dir]
"""
import math
import os
import sys

# Palette: one character per color. "." is transparent.
PALETTE = {
    "k": (26, 20, 32),      # outline
    "T": None, "t": None, "L": None,  # team main / dark / light
    "s": (226, 178, 132),   # skin
    "S": (176, 122, 84),    # skin shade
    "m": (206, 212, 222),   # steel light
    "M": (124, 132, 148),   # steel dark
    "w": (150, 98, 52),     # wood
    "W": (98, 62, 32),      # wood dark
    "h": (112, 70, 40),     # leather
    "H": (76, 46, 26),      # leather dark
    "g": (226, 178, 70),    # gold
    "f": (236, 230, 214),   # fletching / string
    "r": (140, 92, 50),     # horse
    "R": (98, 62, 34),      # horse shade
    "n": (44, 30, 22),      # mane, hooves
    "c": (238, 232, 216),   # turban cloth
    "C": (190, 180, 158),   # turban fold
    "b": (46, 42, 54),      # black lacquer
    "B": (88, 82, 104),     # lacquer sheen
    "y": (204, 168, 98),    # straw hat
    "Y": (150, 116, 62),    # straw shade
    "x": (214, 208, 196),   # grey horse
    "X": (156, 148, 138),   # grey horse shade
    "q": (74, 54, 46),      # dark bay horse
    "Q": (44, 32, 28),      # dark bay shade
    "v": (84, 128, 56),     # leaves
    "V": (52, 88, 38),      # leaves shade
    "u": (128, 168, 74),    # leaves light
    "z": (156, 134, 80),    # dry scrub
    "Z": (112, 92, 52),     # dry scrub shade
    "p": (240, 178, 198),   # blossom
    "e": (150, 146, 138),   # stone
    "E": (100, 96, 92),     # stone shade
    "i": (192, 188, 178),   # stone light
    "A": (86, 94, 108),     # mail in shadow
    "o": (104, 116, 82),    # wool, moss
    "O": (70, 82, 58),      # wool shade
    "d": (218, 196, 146),   # sand cloth
    "D": (170, 146, 100),   # sand cloth shade
    "j": (150, 110, 74),    # russet wool
    "J": (106, 74, 48),     # russet shade
}
TEAMS = {
    # Dyes, not paint: woad and madder. Only cloth that would be dyed carries them.
    "blue": {"T": (66, 94, 146), "t": (40, 58, 98), "L": (136, 164, 208)},
    "red": {"T": (158, 72, 58), "t": (104, 42, 36), "L": (214, 142, 122)},
}


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [["."] * w for _ in range(h)]

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "."

    def disc(self, cx, cy, r, c, shade=None, light=None):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy <= r * r:
                    col = c
                    # light from the upper left
                    if light and dx + dy < -r * 0.55:
                        col = light
                    elif shade and dx + dy > r * 0.45:
                        col = shade
                    self.px[y][x] = col

    def ellipse(self, cx, cy, rx, ry, c, shade=None, light=None):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    col = c
                    if light and dx + dy < -0.75:
                        col = light
                    elif shade and dy > 0.45:
                        col = shade
                    self.px[y][x] = col

    def rect(self, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def outline(self, c="k"):
        """Ring every opaque shape with a 1-pixel outline (4-neighbour)."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy) not in (".", c):
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = c

    def rows(self):
        return ["".join(r) for r in self.px]


# ------------------------------------------------------------------ figures

VARDISH, KHARZANI, RYUMON = "vardish", "kharzani", "ryumon"
CULTURES = (VARDISH, KHARZANI, RYUMON)
HORSES = {VARDISH: ("r", "R"), KHARZANI: ("x", "X"), RYUMON: ("q", "Q")}

# What each unit wears and carries. A recruit is "culture/role"; a trained branch is its
# unit id. body: what covers the shoulders; back: what hangs or stands behind them;
# helm; shield; arm: the weapon. Anything not given is the recruit's.
KIT = {
    "vardish/infantry": dict(body="mail", back="skirt", helm="nasal", shield="kite", arm="sword"),
    "vardish_men_at_arms": dict(body="plate", helm="great"),
    "vardish_sergeants": dict(arm="mace", plume=True),
    "vardish/spearmen": dict(body="jack", back="skirt", helm="kettle", shield="round", arm="spear"),
    "vardish_pikemen": dict(arm="pike", shield=None),
    "vardish_halberdiers": dict(arm="halberd", shield=None, body="mail"),
    "vardish/archers": dict(body="tunic", back="quiver", helm="hood", arm="bow"),
    "vardish_crossbowmen": dict(arm="crossbow", helm="kettle", body="jack"),
    "vardish_longbowmen": dict(arm="longbow"),
    "vardish/cavalry": dict(body="mail", helm="nasal", shield="kite", arm="lance", cloth="c", plume=True),
    "vardish_knights": dict(body="plate", helm="great", barded=True),
    "vardish_mounted_sergeants": dict(helm="kettle", plume=False),

    "kharzani/infantry": dict(body="kaftan", back="skirt", helm="turban", shield="buckler", arm="scimitar"),
    "kharzani_javelin_askari": dict(arm="javelins"),
    "kharzani_guard_askari": dict(body="lamellar", helm="spike", shield="great_round"),
    "kharzani/spearmen": dict(body="kaftan", back="skirt", helm="turban", shield="buckler", arm="spear"),
    "kharzani_spear_guard": dict(body="lamellar", helm="spike", shield="great_round"),
    "kharzani_levy_spears": dict(shield=None, helm="wrap"),
    "kharzani/archers": dict(body="kaftan", back="quiver", helm="turban", arm="recurve"),
    "kharzani_composite_bowmen": dict(body="lamellar", helm="spike"),
    "kharzani_desert_archers": dict(helm="veil"),
    "kharzani/cavalry": dict(body="kaftan", helm="turban", shield="buckler", arm="lance", cloth="d"),
    "kharzani_horse_archers": dict(arm="horsebow", shield=None),
    "kharzani_faris_lancers": dict(body="lamellar", helm="spike", barded=True),

    "ryumon/infantry": dict(body="do", back="sashimono", helm="kabuto", arm="katana"),
    "ryumon_hatamoto": dict(helm="horned", crest=True),
    "ryumon_ronin": dict(body="kimono", back=None, helm="topknot"),
    "ryumon/spearmen": dict(body="do", back="sashimono", helm="jingasa", arm="yari"),
    "ryumon_yari_ashigaru": dict(arm="long_yari"),
    "ryumon_naginata": dict(arm="naginata", helm="kabuto"),
    "ryumon/archers": dict(body="do", back="quiver", helm="jingasa", arm="yumi"),
    "ryumon_yumi_samurai": dict(helm="kabuto", back="sashimono"),
    "ryumon_ashigaru_archers": dict(body="kimono"),
    "ryumon/cavalry": dict(body="do", back="sashimono", helm="kabuto", arm="lance", cloth="b"),
    "ryumon_mounted_samurai": dict(helm="horned", crest=True, barded=True),
    "ryumon_mounted_archers": dict(arm="horsebow", helm="jingasa"),
}


def kit_of(culture, role, unit):
    k = dict(KIT["%s/%s" % (culture, role)])
    if unit:
        k.update(KIT[unit])
    k["culture"] = culture
    return k


def feet(g, cx, cy, frame, c="H"):
    """Boots ahead of and behind the body; they swap on alternate walk frames. On the
    passing frame (3) both are drawn in under the body: the legs crossing."""
    if frame == 3:
        g.rect(int(cx - 3), int(cy - 4), int(cx - 2), int(cy - 3), c)
        g.rect(int(cx + 1), int(cy + 3), int(cx + 2), int(cy + 4), c)
        return
    left_ahead = frame != 1
    for x, ahead in ((cx - 3, left_ahead), (cx + 1, not left_ahead)):
        y = cy - 6 if ahead else cy + 4
        g.rect(int(x), int(y), int(x) + 1, int(y) + 1, c)


def back(g, cx, cy, k):
    """What is behind the shoulders, which from above is most of a man."""
    what = k.get("back")
    if what == "skirt":
        cloth, shade = ("d", "D") if k["culture"] == KHARZANI else ("c", "C")
        g.ellipse(cx, cy + 3.2, 4.6, 3.4, cloth, shade=shade)
        for x in range(int(cx - 3), int(cx + 3)):          # the dyed hem
            g.set(x, cy + 6, "T")
        g.set(cx - 4, cy + 5, "T")
        g.set(cx + 3, cy + 5, "T")
    elif what == "quiver":
        g.rect(int(cx + 2), int(cy + 2), int(cx + 3), int(cy + 7), "h")
        g.set(cx + 2, cy + 7, "H")
        g.set(cx + 3, cy + 7, "H")
        g.set(cx + 2, cy + 1, "f")
        g.set(cx + 3, cy + 1, "L")
        g.set(cx + 4, cy + 2, "f")
    elif what == "sashimono":
        # a banner on a pole at the back: the clan's colour, and from above the plainest
        # thing about a man
        g.rect(int(cx - 1), int(cy + 2), int(cx), int(cy + 9), "T")
        for y in range(int(cy + 2), int(cy + 10)):
            g.set(cx + 1, y, "t")
        g.set(cx - 1, cy + 2, "L")
        g.set(cx - 1, cy + 3, "L")
        g.set(cx, cy + 5, "g" if k.get("crest") else "f")
        g.set(cx, cy + 10, "W")


def shoulders(g, cx, cy, k):
    """Shoulders and chest, by what covers them."""
    b = k["body"]
    if b == "mail":
        g.ellipse(cx, cy, 6.0, 4.0, "M", shade="A", light="m")
        for x in range(int(cx - 4), int(cx + 5), 2):       # the rings catching light
            g.set(x, cy - 1, "m")
        g.rect(int(cx - 1), int(cy + 1), int(cx), int(cy + 3), "T")   # the surcoat's back
        g.set(cx - 1, cy + 1, "L")
    elif b == "plate":
        g.ellipse(cx, cy, 6.0, 4.0, "m", shade="M", light="f")
        for side in (-1, 1):                                # pauldrons
            g.disc(cx + side * 4.6, cy - 0.2, 2.1, "m", shade="M", light="f")
        g.rect(int(cx - 1), int(cy + 1), int(cx), int(cy + 3), "T")
    elif b == "jack":
        g.ellipse(cx, cy, 5.8, 3.8, "c", shade="C")
        for x in (cx - 4, cx - 2, cx + 1, cx + 3):          # quilting
            g.line(x, cy - 1, x, cy + 2, "C")
        g.line(cx - 4, cy + 3, cx + 3, cy + 3, "h")
    elif b == "tunic":
        g.ellipse(cx, cy, 5.4, 3.6, "o", shade="O")
        g.line(cx - 4, cy + 2, cx + 3, cy + 2, "h")
        g.set(cx, cy + 2, "g")
    elif b == "kaftan":
        g.ellipse(cx, cy, 5.8, 3.8, "d", shade="D")
        g.line(cx - 5, cy + 1, cx + 4, cy + 1, "T")         # the sash
        g.set(cx + 3, cy + 2, "T")
        g.set(cx + 3, cy + 3, "L")
    elif b == "lamellar":
        g.ellipse(cx, cy, 6.0, 4.0, "M", shade="A", light="m")
        for y in (cy - 1, cy + 1):
            for x in range(int(cx - 4), int(cx + 5), 2):
                g.set(x + (0 if y < cy else 1), y, "g")
        g.line(cx - 5, cy + 2, cx + 4, cy + 2, "T")
    elif b == "do":
        g.ellipse(cx, cy, 5.6, 3.8, "b", shade="k", light="B")
        for y in (cy - 1, cy + 1):                           # lacing, dyed
            for x in range(int(cx - 3), int(cx + 4), 2):
                g.set(x, y, "T")
        for side in (-1, 1):                                 # sode: the shoulder plates
            x0 = int(cx + side * 5 - (1 if side < 0 else 0))
            g.rect(x0, int(cy - 2), x0 + 1, int(cy + 1), "b")
            g.rect(x0, int(cy - 1), x0 + 1, int(cy - 1), "T")
            g.rect(x0, int(cy + 1), x0 + 1, int(cy + 1), "T")
    else:   # kimono
        g.ellipse(cx, cy, 5.4, 3.6, "e", shade="E")
        g.set(cx - 1, cy - 2, "f")
        g.set(cx, cy - 1, "f")
        g.set(cx + 1, cy - 2, "f")
        g.line(cx - 4, cy + 2, cx + 3, cy + 2, "T")         # the obi


def helm(g, cx, cy, k):
    h = k["helm"]
    hy = cy - 1.0
    if h in ("nasal", "great"):
        if k.get("plume"):
            g.rect(int(cx - 1), int(hy + 2), int(cx), int(hy + 5), "T")
            g.set(cx - 1, hy + 5, "L")
        if h == "nasal":
            g.disc(cx, hy, 3.3, "M", shade="A", light="m")
            g.line(cx, hy - 3, cx, hy - 5, "A")              # the nasal, out over the face
            g.set(cx - 1, hy - 1, "f")
        else:
            g.disc(cx, hy, 3.5, "m", shade="M", light="f")
            g.line(cx - 2, hy - 2, cx + 1, hy - 2, "k")      # the sights
            g.line(cx, hy - 1, cx, hy + 2, "M")
    elif h == "kettle":
        if k.get("plume"):
            g.rect(int(cx - 1), int(hy + 3), int(cx), int(hy + 5), "T")
        g.disc(cx, hy, 4.4, "A", light="M")                  # the brim
        g.disc(cx, hy, 2.7, "M", shade="A", light="m")
        g.set(cx - 1, hy - 1, "f")
    elif h == "hood":
        g.disc(cx, hy, 3.3, "T", shade="t", light="L")
        g.set(cx, hy + 3, "T")
        g.set(cx, hy + 4, "t")
        g.set(cx, hy - 3, "s")                               # a nose under it
    elif h in ("turban", "spike", "veil", "wrap"):
        if h == "veil":
            g.ellipse(cx, hy + 2.6, 2.6, 2.6, "c", shade="C")
        g.disc(cx, hy, 3.4, "c", shade="C", light="f")
        if h == "wrap":
            g.line(cx - 2, hy + 1, cx + 2, hy - 1, "C")
        else:
            g.line(cx - 3, hy + 1, cx + 2, hy - 2, "T")      # the dyed band wound through it
            g.set(cx - 2, hy - 1, "C")
        if h == "spike":
            g.disc(cx, hy, 1.3, "m", shade="M")
            g.set(cx, hy, "f")
            g.set(cx, hy - 3, "g")
        else:
            g.set(cx, hy - 3, "g" if h == "turban" else "C")
    elif h in ("kabuto", "horned"):
        g.ellipse(cx, hy + 1.4, 4.6, 2.6, "b", light="B")    # the neck guard
        g.line(cx - 3, hy + 3, cx + 3, hy + 3, "T")
        g.disc(cx, hy, 3.3, "b", shade="k", light="B")
        g.set(cx, hy - 3, "g")
        g.set(cx - 1, hy - 4, "g")
        g.set(cx + 1, hy - 4, "g")
        if h == "horned":
            for side in (-1, 1):
                g.set(cx + side * 3, hy - 3, "g")
                g.set(cx + side * 4, hy - 4, "g")
                g.set(cx + side * 4, hy - 5, "g")
    elif h == "jingasa":
        g.disc(cx, hy, 4.5, "y", shade="Y", light="f")
        g.disc(cx, hy, 1.2, "Y")
        g.set(cx, hy, "T")                                   # the mon, dyed
    else:   # topknot
        g.disc(cx, hy, 3.0, "n", light="q")
        g.set(cx, hy, "k")
        g.set(cx, hy + 1, "k")
        g.set(cx, hy - 3, "s")


def shield(g, cx, cy, k, forward=0):
    s = k.get("shield")
    if not s:
        return
    x, y = cx - 6.5, cy - 2.0 - forward
    if s == "kite":
        g.ellipse(x, y, 3.3, 4.8, "T", shade="t", light="L")
        g.line(x, y - 4, x, y + 4, "L")
        g.line(x - 2, y - 1, x + 2, y - 1, "L")
        g.set(x, y - 1, "g")
    elif s == "round":
        g.disc(x + 0.5, y + 0.5, 3.2, "w", shade="W")
        g.disc(x + 0.5, y + 0.5, 2.0, "T", shade="t")
        g.set(x, y, "m")
    elif s == "buckler":
        g.disc(x + 0.5, y + 0.5, 3.0, "T", shade="t", light="L")
        g.set(x, y, "g")
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            g.set(x + dx, y + dy, "g")
    else:   # great_round
        g.disc(x + 0.5, y + 0.5, 3.8, "g", shade="Y")
        g.disc(x + 0.5, y + 0.5, 2.8, "T", shade="t", light="L")
        g.disc(x + 0.5, y + 0.5, 1.0, "g")


def hand_arm(g, cx, cy, k, frame):
    """What the right hand holds, at rest and (frame 2) struck."""
    a = k["arm"]
    x = cx + 6
    hit = frame == 2
    if a == "sword":
        if hit:
            g.line(cx + 5, cy - 3, cx + 9, cy - 9, "m")
            g.set(cx + 9, cy - 9, "f")
            g.set(cx + 4, cy - 2, "g")
            g.set(cx + 5, cy - 2, "g")
        else:
            g.line(x, cy - 2, x, cy - 9, "m")
            g.set(x, cy - 10, "f")
            g.rect(int(x - 1), int(cy - 1), int(x + 1), int(cy - 1), "g")
        g.set(x - (1 if hit else 0), cy, "s")
    elif a == "mace":
        if hit:
            g.line(cx + 5, cy - 2, cx + 7, cy - 6, "W")
            g.disc(cx + 8.5, cy - 7.5, 1.9, "m", shade="M")
        else:
            g.line(x, cy - 1, x, cy - 6, "W")
            g.disc(x + 0.5, cy - 7.5, 1.9, "m", shade="M")
        g.set(x - (1 if hit else 0), cy, "s")
    elif a == "scimitar":
        pts = ((4, -2), (5, -3), (6, -4), (7, -5), (8, -5), (9, -6)) if hit else ((6, -2), (6, -3), (6, -4), (6, -5), (7, -6), (7, -7), (8, -8))
        for i, (dx, dy) in enumerate(pts):
            g.set(cx + dx, cy + dy, "f" if i == len(pts) - 1 else "m")
        g.set(cx + pts[0][0] - 1, cy - 1, "g")
        g.set(cx + pts[0][0], cy - 1, "g")
        g.set(cx + 5, cy, "s")
    elif a == "javelins":
        if hit:
            g.line(cx + 5, cy - 2, cx + 8, cy - 10, "w")
            g.set(cx + 8, cy - 11, "m")
        else:
            for jx, top in ((x, cy - 10), (x + 2, cy - 8)):
                g.line(jx, cy + 1, jx, top, "w")
                g.set(jx, top - 1, "m")
                g.set(jx, top - 2, "f")
        g.set(x, cy, "s")
    elif a == "katana":
        # held in both hands before the body; the cut carries it out to the right
        if hit:
            g.line(cx + 2, cy - 4, cx + 9, cy - 8, "m")
            g.set(cx + 9, cy - 8, "f")
        else:
            g.line(cx + 2, cy - 4, cx + 4, cy - 11, "m")
            g.set(cx + 4, cy - 12, "f")
        g.set(cx + 1, cy - 4, "g")
        g.set(cx, cy - 3, "s")
        g.set(cx + 2, cy - 3, "s")


def pole_arm(g, cx, cy, k, frame):
    """A spear or its kin, carried upright in the right hand; the thrust (frame 2) runs it
    out ahead. It is the plainest thing about a spearman, so it is long and its head broad."""
    a = k["arm"]
    x = cx + 6
    reach = 3 if frame == 2 else 0
    length = {"spear": 13, "pike": 16, "halberd": 13, "yari": 13, "long_yari": 16, "naginata": 12}[a]
    top = cy - length - reach
    g.line(x, cy + 6 - reach, x, top + 2, "w")
    if a in ("spear", "pike"):
        g.rect(x, top, x, top + 2, "m")
        g.set(x, top - 1, "f")
        g.set(x - 1, top + 2, "m")
        g.set(x + 1, top + 2, "m")
        if a == "pike":
            g.set(x + 1, top + 4, "T")                       # a pennon under the head
            g.set(x + 2, top + 4, "T")
            g.set(x + 1, top + 5, "t")
    elif a == "halberd":
        g.rect(x, top, x, top + 1, "f")
        g.rect(x + 1, top + 2, x + 2, top + 4, "m")          # the axe
        g.set(x + 3, top + 3, "m")
        g.set(x - 1, top + 3, "M")                           # the hook behind
    elif a in ("yari", "long_yari"):
        g.rect(x, top, x, top + 2, "m")
        g.set(x, top - 1, "f")
        g.set(x - 1, top + 3, "m")                           # the cross-blade
        g.set(x + 1, top + 3, "m")
        g.set(x, top + 5, "T")                               # a dyed tassel
    else:   # naginata: a long curved blade
        for i, (dx, dy) in enumerate(((0, 3), (0, 2), (0, 1), (1, 0), (1, -1), (2, -2))):
            g.set(x + dx, top + dy, "f" if i == 5 else "m")
        g.set(x, top + 4, "g")
    g.set(x, cy - 1 - reach, "s")
    g.set(x, cy + 2 - reach, "s")


def bow(g, cx, cy, k, frame):
    """The bow held out ahead across the body: strung and at rest, or (frame 2) drawn with
    the arrow on it. Each people's bow has its own shape."""
    a = k["arm"]
    drawn = frame == 2
    by = cy - 6
    if a == "crossbow":
        g.line(cx, cy - 3, cx, by - 4, "W")                  # the tiller
        for dx in range(-5, 6):
            g.set(cx + dx, by - 3 + (1 if abs(dx) > 3 else 0), "m")
        if drawn:
            g.line(cx - 5, by - 2, cx, by, "f")
            g.line(cx + 5, by - 2, cx, by, "f")
            g.set(cx, by - 5, "f")
        else:
            g.line(cx - 5, by - 2, cx + 5, by - 2, "f")
        g.set(cx - 1, cy - 3, "s")
        g.set(cx + 1, cy - 3, "s")
        return
    half = {"bow": 7, "longbow": 9, "recurve": 7, "yumi": 9, "horsebow": 6}[a]
    depth = {"bow": 4, "longbow": 4, "recurve": 3, "yumi": 4, "horsebow": 3}[a]
    wood = "w" if a in ("bow", "longbow") else ("h" if a in ("recurve", "horsebow") else "b")
    ox = 2 if a == "yumi" else 0                             # a yumi is held below its middle
    for dx in range(-half, half + 1):
        t = abs(dx) / float(half)
        y = by - depth * (1.0 - t * t)
        if a in ("recurve", "horsebow") and t > 0.8:
            y -= 1.5                                         # the ears curl forward again
        g.set(cx + dx + ox, y, wood)
        if a in ("longbow", "yumi"):
            g.set(cx + dx + ox, y + 1, wood)
    if a == "yumi":
        g.set(cx + ox, by - depth, "T")                      # the grip, wound in the clan's colour
    lx, rx = cx - half + ox, cx + half + ox
    if drawn:
        g.line(lx, by, cx, cy - 2, "f")
        g.line(rx, by, cx, cy - 2, "f")
        g.line(cx, cy - 2, cx, by - depth - 3, "w")
        g.set(cx, by - depth - 4, "m")
    else:
        g.line(lx, by, rx, by, "f")
    g.set(cx - 2 + ox, by - depth + 1, "s")
    if drawn:
        g.set(cx + 1, cy - 2, "s")


def foot(frame, culture, role, unit=None):
    k = kit_of(culture, role, unit)
    if role == "spearmen":
        g = Grid(22, 28)
        cx, cy = 10.0, 19.0
    else:
        g = Grid(22, 22)
        cx, cy = 11.0, 13.0
    feet(g, cx, cy, frame if frame != 2 else 0, "b" if culture == RYUMON else "H")
    back(g, cx, cy, k)
    shoulders(g, cx, cy, k)
    if role == "infantry":
        hand_arm(g, cx, cy, k, frame)
    elif role == "spearmen":
        pole_arm(g, cx, cy, k, frame)
    shield(g, cx, cy, k, 1 if frame == 2 else 0)
    helm(g, cx, cy, k)
    if role == "archers":
        bow(g, cx, cy, k, frame)
    g.outline()
    return g, (cx, cy)


def infantry(frame, culture=VARDISH, unit=None):
    return foot(frame, culture, "infantry", unit)


def spearmen(frame, culture=VARDISH, unit=None):
    return foot(frame, culture, "spearmen", unit)


def archers(frame, culture=VARDISH, unit=None):
    return foot(frame, culture, "archers", unit)


def cavalry(frame, culture=VARDISH, unit=None):
    """A horse seen from above, head up the canvas, under its cloth; the rider's shoulders
    and helm over the saddle; a lance carried upright and (frame 2) couched forward."""
    k = kit_of(culture, "cavalry", unit)
    g = Grid(22, 28)
    cx, cy = 11.0, 17.0
    coat, dark = HORSES[culture]
    # hooves: a pair shows ahead and behind, swapping with the stride
    stride = frame if frame != 2 else 0
    if stride == 3:
        pairs = ((cx - 4, cy - 2), (cx + 3, cy + 6))
    elif stride == 1:
        pairs = ((cx + 3, cy - 5), (cx - 4, cy + 8))
    else:
        pairs = ((cx - 4, cy - 5), (cx + 3, cy + 8))
    for x, y in pairs:
        g.rect(int(x), int(y), int(x) + 1, int(y) + 1, "n")
    g.rect(int(cx - 1), int(cy + 8), int(cx), int(cy + 10), "n")                  # tail
    g.ellipse(cx, cy + 1, 4.4, 8.2, coat, shade=dark)                              # barrel and rump
    g.ellipse(cx, cy - 8.5, 2.4, 4.0, coat, shade=dark)                            # neck
    g.ellipse(cx, cy - 13, 1.9, 2.6, coat)                                         # head
    g.line(cx, cy - 11, cx, cy - 5, "n")                                           # mane
    g.set(cx - 2, cy - 14, dark)
    g.set(cx + 1, cy - 14, dark)
    # the horse's cloth: undyed, with the side's colour at its hems; a barded horse wears
    # more of it, with the house's mark on the quarters
    cloth = k.get("cloth", "c")
    shade = {"c": "C", "d": "D", "b": "k"}[cloth]
    top = cy - (5 if k.get("barded") else 2)
    g.rect(int(cx - 4), int(top), int(cx + 3), int(cy + 7), cloth)
    for y in range(int(top), int(cy + 8)):
        g.set(cx - 4, y, "T")
        g.set(cx + 3, y, "T")
    g.line(cx - 4, cy + 7, cx + 3, cy + 7, "T")
    g.line(cx - 3, cy + 6, cx + 2, cy + 6, shade)
    if k.get("barded"):
        g.line(cx - 4, top, cx + 3, top, "T")
        g.rect(int(cx - 1), int(cy + 4), int(cx), int(cy + 5), "T")
        g.set(cx - 1, cy + 4, "g")
    # the rider
    back(g, cx, cy - 1, k) if k.get("back") == "sashimono" else None
    rk = dict(k)
    shoulders_small(g, cx, cy, rk)
    a = k["arm"]
    if a == "lance":
        x = cx + 6
        if frame == 2:
            g.line(x - 1, cy + 3, x - 1, cy - 16, "w")
            g.set(x - 1, cy - 17, "f")
        else:
            g.line(x, cy + 6, x, cy - 13, "w")
            g.set(x, cy - 14, "m")
            g.set(x, cy - 15, "f")
            g.rect(int(x + 1), int(cy - 12), int(x + 3), int(cy - 11), "T")       # pennon
            g.set(x + 1, cy - 10, "t")
        g.set(x - (1 if frame == 2 else 0), cy, "s")
    if k.get("shield"):
        small = dict(k)
        shield_small(g, cx, cy, small)
    helm(g, cx, cy, k)
    if a == "horsebow":
        bow(g, cx, cy, k, frame)
    g.outline()
    return g, (cx, cy)


def shoulders_small(g, cx, cy, k):
    """A rider's shoulders: the foot soldier's, a size smaller, over the saddle."""
    b = k["body"]
    c, sh, li = {"mail": ("M", "A", "m"), "plate": ("m", "M", "f"), "kaftan": ("d", "D", None), "lamellar": ("M", "A", "m"),
        "do": ("b", "k", "B")}.get(b, ("c", "C", None))
    g.ellipse(cx, cy, 5.0, 3.2, c, shade=sh, light=li)
    if b in ("kaftan", "lamellar"):
        g.line(cx - 4, cy + 1, cx + 3, cy + 1, "T")
    elif b == "do":
        for x in range(int(cx - 3), int(cx + 4), 2):
            g.set(x, cy + 1, "T")
    else:
        g.rect(int(cx - 1), int(cy + 1), int(cx), int(cy + 2), "T")
    if b == "lamellar":
        for x in range(int(cx - 3), int(cx + 4), 2):
            g.set(x, cy - 1, "g")


def shield_small(g, cx, cy, k):
    x, y = cx - 6.0, cy - 1.0
    if k["shield"] == "kite":
        g.ellipse(x, y, 2.4, 3.6, "T", shade="t", light="L")
        g.set(x, y - 1, "g")
    else:
        g.disc(x + 0.5, y + 0.5, 2.6, "T", shade="t", light="L")
        g.set(x, y, "g")


def corpse(kind):
    """A fallen man (kind 0) or horse (kind 1), drawn dull; the game tints it by team."""
    if kind == 1:
        g = Grid(22, 14)
        g.ellipse(11, 7, 7.5, 3.4, "R", shade="n")
        g.ellipse(4, 5.5, 2.5, 1.6, "R")
        g.line(6, 10, 8, 12, "n")
        g.line(13, 10, 15, 12, "n")
        g.ellipse(12, 6, 3.0, 2.2, "t")
    else:
        g = Grid(14, 10)
        g.ellipse(7, 5, 4.5, 2.2, "t")
        g.disc(2.5, 5, 1.8, "M")
        g.line(9, 3, 12, 1, "M")
        g.rect(11, 5, 12, 5, "H")
        g.rect(11, 7, 12, 7, "H")
    g.outline()
    return g, (g.w / 2.0, g.h / 2.0)


# ------------------------------------------------------------------ field

def rock(kind):
    """A low boulder, lit from the upper left."""
    g = Grid(12, 9) if kind == 0 else Grid(8, 7)
    cx, cy = g.w / 2.0, g.h / 2.0
    g.ellipse(cx, cy, g.w / 2.0 - 1.2, g.h / 2.0 - 1.2, "e", shade="E", light="i")
    if kind == 0:
        g.set(cx + 1, cy - 1, "E")
        g.set(cx + 2, cy, "E")
    g.outline("E")
    return g, (cx, cy)


def bush(culture):
    """Meadow shrubs in Vardmark, dry scrub in Kharzan, blossom on the isles."""
    g = Grid(12, 11)
    if culture == KHARZANI:
        for dx, dy in ((-4, -2), (-2, -4), (0, -5), (2, -4), (4, -2), (-3, 1), (3, 1), (0, -1)):
            g.line(6, 8, 6 + dx, 7 + dy, "z" if dx <= 0 else "Z")
        g.set(6, 8, "Z")
        return g, (6.0, 7.0)
    for cx, cy, r in ((4.0, 6.0, 2.6), (8.0, 6.5, 2.4), (6.0, 4.0, 2.8)):
        g.disc(cx, cy, r, "v", shade="V", light="u")
    if culture == RYUMON:
        for x, y in ((4, 4), (7, 3), (8, 6), (5, 7), (6, 5)):
            g.set(x, y, "p")
    g.outline("V")
    return g, (6.0, 6.0)


def arrow():
    g = Grid(3, 9)
    g.line(1, 2, 1, 7, "w")
    g.set(1, 0, "m"); g.set(1, 1, "m")
    g.set(0, 1, "M"); g.set(2, 1, "M")
    g.set(0, 8, "f"); g.set(2, 8, "f"); g.set(1, 8, "f")
    return g, (1.5, 4.5)


BUILDERS = {"infantry": infantry, "spearmen": spearmen, "archers": archers, "cavalry": cavalry}

# The trained branches, by the unit id the game knows them by: (culture, role). Each is
# its recruit's figure with its own kit, so a squad's training shows on the field.
BRANCHES = {
    "vardish_men_at_arms": (VARDISH, "infantry"), "vardish_sergeants": (VARDISH, "infantry"),
    "vardish_pikemen": (VARDISH, "spearmen"), "vardish_halberdiers": (VARDISH, "spearmen"),
    "vardish_crossbowmen": (VARDISH, "archers"), "vardish_longbowmen": (VARDISH, "archers"),
    "vardish_knights": (VARDISH, "cavalry"), "vardish_mounted_sergeants": (VARDISH, "cavalry"),
    "kharzani_javelin_askari": (KHARZANI, "infantry"), "kharzani_guard_askari": (KHARZANI, "infantry"),
    "kharzani_spear_guard": (KHARZANI, "spearmen"), "kharzani_levy_spears": (KHARZANI, "spearmen"),
    "kharzani_composite_bowmen": (KHARZANI, "archers"), "kharzani_desert_archers": (KHARZANI, "archers"),
    "kharzani_horse_archers": (KHARZANI, "cavalry"), "kharzani_faris_lancers": (KHARZANI, "cavalry"),
    "ryumon_hatamoto": (RYUMON, "infantry"), "ryumon_ronin": (RYUMON, "infantry"),
    "ryumon_yari_ashigaru": (RYUMON, "spearmen"), "ryumon_naginata": (RYUMON, "spearmen"),
    "ryumon_yumi_samurai": (RYUMON, "archers"), "ryumon_ashigaru_archers": (RYUMON, "archers"),
    "ryumon_mounted_samurai": (RYUMON, "cavalry"), "ryumon_mounted_archers": (RYUMON, "cavalry"),
}


def _frames(fn, culture, unit=None):
    frames = [fn(f, culture, unit) for f in range(4)]   # walk 1, walk 2, strike, passing
    return {"frames": [f[0].rows() for f in frames], "pivot": frames[0][1]}


def build_all():
    """Every culture's four recruits as "culture/type", each trained branch by its unit
    id, plus the bodies and the arrow."""
    out = {}
    for culture in CULTURES:
        for name, fn in BUILDERS.items():
            out["%s/%s" % (culture, name)] = _frames(fn, culture)
    for unit, (culture, role) in BRANCHES.items():
        out[unit] = _frames(BUILDERS[role], culture, unit)
    out["corpse"] = {"frames": [corpse(0)[0].rows()], "pivot": corpse(0)[1]}
    out["corpse_horse"] = {"frames": [corpse(1)[0].rows()], "pivot": corpse(1)[1]}
    out["arrow"] = {"frames": [arrow()[0].rows()], "pivot": arrow()[1]}
    for kind in range(2):
        g, pivot = rock(kind)
        out["rock%d" % kind] = {"frames": [g.rows()], "pivot": pivot}
    for culture in CULTURES:
        g, pivot = bush(culture)
        out["%s/bush" % culture] = {"frames": [g.rows()], "pivot": pivot}
    return out


def gd_color(rgb):
    return "Color(%.3f, %.3f, %.3f)" % tuple(c / 255.0 for c in rgb)


def write_gd(sprites, path):
    lines = [
        "## Generated by tools/unit_sprites.py; edit the tool, not this file.",
        "## Unit pixel art, top-down and facing up. Each sprite is a list of frames (walk,",
        "## walk, strike, and the passing step between the two walks: a stride is walk,",
        "## passing, walk, passing); each frame is rows of palette characters. T/t/L are",
        "## team colors.",
        "extends RefCounted",
        "",
        "const PALETTE := {",
    ]
    for ch, rgb in PALETTE.items():
        if rgb is not None:
            lines.append('\t"%s": %s,' % (ch, gd_color(rgb)))
    lines.append("}")
    lines.append("")
    lines.append("const TEAMS := [")
    for team in ("blue", "red"):
        cols = TEAMS[team]
        lines.append("\t{%s}," % ", ".join('"%s": %s' % (k, gd_color(v)) for k, v in cols.items()))
    lines.append("]")
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


def preview(sprites, out_dir, scale=6):
    """A sheet of every unit: one row per recruit and branch, walk-walk-strike in blue then red."""
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    names = []
    for c in CULTURES:
        for n in BUILDERS:
            names.append("%s/%s" % (c, n))
            names += [u for u, cr in BRANCHES.items() if cr == (c, n)]
    cell_w = 24 * scale
    cell_h = 30 * scale
    gap = scale * 4
    sheet = Image.new("RGBA", (cell_w * 6 + gap, cell_h * len(names)), (78, 122, 56, 255))
    for ti, team in enumerate(("blue", "red")):
        pal = dict(PALETTE)
        pal.update(TEAMS[team])
        for ni, name in enumerate(names):
            for fi, rows in enumerate(sprites[name]["frames"]):
                img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
                for y, r in enumerate(rows):
                    for x, ch in enumerate(r):
                        if ch != ".":
                            img.putpixel((x, y), pal[ch] + (255,))
                img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
                ox = ti * (cell_w * 3 + gap) + fi * cell_w + (cell_w - img.width) // 2
                oy = ni * cell_h + (cell_h - img.height) // 2
                sheet.alpha_composite(img, (ox, oy))
    sheet.save(os.path.join(out_dir, "units_preview.png"))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = build_all()
    os.makedirs(os.path.join(here, "..", "scripts", "art"), exist_ok=True)
    write_gd(sprites, os.path.join(here, "..", "scripts", "art", "sprite_data.gd"))
    if len(sys.argv) > 1:
        preview(sprites, sys.argv[1])
    print("wrote scripts/art/sprite_data.gd")
