"""Authoring tool for Bannerfall's unit pixel art.

Draws each troop type of each culture top-down, facing up, as small palette-indexed
grids, then writes them to scripts/art/sprite_data.gd (which the game turns into
textures at startup) and to preview PNGs. Team colors are placeholders (T, t, L) that
the game swaps for blue or red.

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
}
TEAMS = {
    "blue": {"T": (64, 112, 216), "t": (34, 62, 136), "L": (150, 186, 255)},
    "red": {"T": (200, 68, 60), "t": (120, 34, 30), "L": (255, 168, 156)},
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


# ------------------------------------------------------------------ bodies

VARDISH, KHARZANI, RYUMON = "vardish", "kharzani", "ryumon"
CULTURES = (VARDISH, KHARZANI, RYUMON)


def ringed_disc(g, cx, cy, r, c, shade=None, light=None):
    """A disc with its own dark outline, so it reads against what's under it."""
    g.disc(cx, cy, r + 0.9, "k")
    g.disc(cx, cy, r, c, shade=shade, light=light)


def feet(g, cx, cy, frame, c="H"):
    """Boots in front and behind the body; they swap on alternate walk frames."""
    front_left = frame != 1
    for x, forward in ((cx - 2, front_left), (cx + 1, not front_left)):
        y = cy - 4 if forward else cy + 3
        g.rect(int(x), int(y), int(x) + 1, int(y) + 1, c)


def torso(g, cx, cy, culture, plain=False):
    """Shoulders and chest: a surcoat, a kaftan, or lacquered plates laced in the team color.
    A plain torso is an unarmored kimono with a crossed collar."""
    g.ellipse(cx, cy, 5.3, 3.7, "k")
    if plain:
        g.ellipse(cx, cy, 4.6, 3.0, "T", shade="t", light="L")
        g.set(cx - 1, cy - 2, "f")
        g.set(cx, cy - 1, "f")
        g.set(cx + 1, cy - 2, "f")
        g.line(cx - 3, cy + 1, cx + 3, cy + 1, "b")   # the obi
    elif culture == RYUMON:
        g.ellipse(cx, cy, 4.6, 3.0, "b", shade="k", light="B")
        # rows of lacing across the plates
        for dy in (-1, 1):
            g.line(cx - 3, cy + dy, cx + 3, cy + dy, "T")
        g.set(cx - 4, cy, "t")
        g.set(cx + 4, cy, "t")
    elif culture == KHARZANI:
        g.ellipse(cx, cy, 4.6, 3.0, "T", shade="t", light="L")
        g.set(cx + 2, cy + 1, "g")                    # a sash knot
        g.set(cx + 3, cy + 1, "g")
    else:
        g.ellipse(cx, cy, 4.6, 3.0, "T", shade="t", light="L")
        g.line(cx, cy - 2, cx, cy + 2, "L")           # the cross on the surcoat
        g.line(cx - 1, cy, cx + 1, cy, "L")


def steel_helm(g, cx, cy, point=False):
    ringed_disc(g, cx, cy - 0.5, 1.7, "m", shade="M")
    g.set(cx - 1, cy - 1.5, "f")  # glint
    if point:
        g.set(cx, cy - 0.5, "M")


def kettle_hat(g, cx, cy):
    """A wide steel brim around a round crown."""
    ringed_disc(g, cx, cy - 0.5, 2.6, "M")
    g.disc(cx, cy - 0.5, 1.5, "m", shade="M")
    g.set(cx - 1, cy - 1.5, "f")


def turban(g, cx, cy, spike=False):
    ringed_disc(g, cx, cy - 0.5, 2.0, "c", shade="C")
    # the wrap's folds
    g.set(cx - 1, cy - 1.5, "C")
    g.set(cx + 1, cy + 0.5, "C")
    g.set(cx, cy - 0.5, "M" if spike else "C")
    if spike:
        g.set(cx, cy - 1.5, "m")


def kabuto(g, cx, cy, horns=False):
    """A lacquered helmet with a flared neck guard and a gold crest in front; a bannerman's
    crest spreads into tall horns."""
    g.ellipse(cx, cy + 0.6, 3.0, 1.6, "k")
    g.ellipse(cx, cy + 0.6, 2.4, 1.0, "b", light="B")
    ringed_disc(g, cx, cy - 0.5, 1.6, "b", light="B")
    g.set(cx - 1, cy - 2.5, "g")
    g.set(cx + 1, cy - 2.5, "g")
    g.set(cx, cy - 2.5, "k")
    if horns:
        g.set(cx - 2, cy - 3.5, "g")
        g.set(cx + 2, cy - 3.5, "g")
        g.set(cx - 2, cy - 2.5, "g")
        g.set(cx + 2, cy - 2.5, "g")


def jingasa(g, cx, cy, lacquer=False):
    """The wide, flat hat of the ashigaru: straw, or for the better-kept, black lacquer
    with a gold crest."""
    if lacquer:
        ringed_disc(g, cx, cy - 0.5, 2.7, "b", light="B")
        g.set(cx, cy - 0.5, "g")
        return
    ringed_disc(g, cx, cy - 0.5, 2.7, "y", shade="Y", light="f")
    g.set(cx, cy - 0.5, "Y")


def great_helm(g, cx, cy):
    """A flat-topped steel helm with a dark eye-slit across its front."""
    ringed_disc(g, cx, cy - 0.5, 2.0, "m", shade="M")
    g.line(cx - 1, cy - 2, cx + 1, cy - 2, "k")


def plume(g, cx, cy):
    """A feather in the team color, trailing back from the crown."""
    g.line(cx, cy - 0.5, cx, cy + 2, "L")
    g.set(cx, cy + 3, "T")


def pauldrons(g, cx, cy, c="m", shade="M"):
    """Steel plates over both shoulders."""
    for side in (-1, 1):
        g.disc(cx + side * 3.7, cy, 1.5, c, shade=shade)


def gilded(g, cx, cy):
    """Rows of gilt lamellae across the chest."""
    for dy in (-1, 1):
        g.line(cx - 3, cy + dy, cx + 3, cy + dy, "g")


def veil(g, cx, cy):
    """A desert wrap over the head and face, a slit left for the eyes."""
    ringed_disc(g, cx, cy - 0.5, 1.9, "C", shade="Z", light="c")
    g.line(cx - 1, cy - 2, cx + 1, cy - 2, "s")


def topknot(g, cx, cy):
    """A bare head in a white headband, the topknot laid forward."""
    ringed_disc(g, cx, cy - 0.5, 1.8, "f")
    g.disc(cx, cy - 0.5, 1.1, "b", light="B")
    g.line(cx, cy - 1.5, cx, cy - 0.5, "n")


def hood(g, cx, cy):
    ringed_disc(g, cx, cy - 0.5, 1.7, "t", shade="k", light="T")
    g.set(cx, cy - 2.0, "s")  # face in the hood opening


def sashimono(g, cx, cy, tall=6):
    """The little banner on a pole at a Ryumon soldier's back, in the team color."""
    x = int(cx)
    g.line(x, cy + 2, x, cy + 2 + tall, "W")
    g.rect(x - 2, int(cy + 3), x - 1, int(cy + 2 + tall), "T")
    g.set(x - 2, cy + 3, "L")
    g.set(x - 2, cy + 2 + tall, "t")
    g.set(x - 1, cy + 2 + tall, "t")


def kite_shield(g, cx, cy):
    """Tall and narrow, broad at the top, with a cross on its face."""
    g.ellipse(cx, cy, 2.7, 4.6, "k")
    g.ellipse(cx, cy, 2.0, 3.9, "T", shade="t", light="L")
    g.line(cx, cy - 2.5, cx, cy + 2.5, "f")
    g.line(cx - 1, cy - 1, cx + 1, cy - 1, "f")


def round_shield(g, cx, cy, r=2.8):
    """A round shield with a bright rim and a gold boss."""
    ringed_disc(g, cx, cy, r, "L")
    g.disc(cx, cy, r - 0.8, "T", shade="t", light="L")
    g.set(cx, cy, "g")


def infantry(frame, culture=VARDISH, unit=None):
    g = Grid(16, 18)
    cx, cy = 8.0, 8.5
    if culture == RYUMON and unit != "ryumon_ronin":
        # masterless ronin carry no lord's banner; the hatamoto's bears a gold crest
        sashimono(g, cx - 1, cy + 1, tall=7 if unit == "ryumon_hatamoto" else 6)
        if unit == "ryumon_hatamoto":
            g.set(cx - 3, cy + 6, "g")
    feet(g, cx, cy, frame if frame < 2 else 0, "b" if culture == RYUMON else "H")
    torso(g, cx, cy, culture, plain=unit == "ryumon_ronin")
    if unit == "vardish_men_at_arms":
        pauldrons(g, cx, cy)
    elif unit == "kharzani_guard_askari":
        gilded(g, cx, cy)
    if culture == RYUMON:
        # katana held two-handed before the body; the cut sweeps it out to the right
        if frame == 2:
            g.line(cx + 1, cy - 3, cx + 6, cy - 6, "m")
            g.set(cx + 6, cy - 6, "f")
            g.set(cx + 1, cy - 2, "s")
            g.set(cx, cy - 2, "s")
        else:
            g.line(cx + 1, cy - 3, cx + 2, cy - 8, "m")
            g.set(cx + 2, cy - 8, "f")
            g.set(cx + 1, cy - 2, "g")
            g.set(cx, cy - 2, "s")
            g.set(cx + 2, cy - 2, "s")
        if unit == "ryumon_ronin":
            topknot(g, cx, cy)
        else:
            kabuto(g, cx, cy, horns=unit == "ryumon_hatamoto")
    elif culture == KHARZANI:
        if unit == "kharzani_javelin_askari":
            # a pair of javelins in the right hand; the throw sends one out ahead
            if frame == 2:
                g.line(cx + 3, cy - 3, cx + 6, cy - 8, "w")
                g.set(cx + 6, cy - 9, "m")
            else:
                for jx, top in ((cx + 4, cy - 8), (cx + 5, cy - 7)):
                    g.line(jx, cy - 1, jx, top, "w")
                    g.set(jx, top - 1, "m")
            g.set(cx + 4, cy - 1, "s")
            round_shield(g, cx - 3.6, cy - 1.0, 2.3)
            turban(g, cx, cy)
        else:
            # a curved scimitar at the right shoulder
            if frame == 2:
                for i, (dx, dy) in enumerate(((3, -2), (4, -3), (5, -4), (6, -4), (7, -5))):
                    g.set(cx + dx, cy + dy, "m" if i < 4 else "f")
            else:
                for i, (dx, dy) in enumerate(((4, -3), (4, -4), (4, -5), (5, -6), (5, -7))):
                    g.set(cx + dx, cy + dy, "m" if i < 4 else "f")
            g.set(cx + 3, cy - 2, "g")
            g.set(cx + 4, cy - 1, "s")
            sy = cy - 2.0 if frame == 2 else cy - 1.0
            guard = unit == "kharzani_guard_askari"
            round_shield(g, cx - 3.6, sy, 3.2 if guard else 2.9)
            turban(g, cx, cy, spike=guard)
            if guard:
                g.set(cx - 1, cy - 1.5, "g")
                g.set(cx + 1, cy + 0.5, "g")
    else:
        if unit == "vardish_sergeants":   # a flanged mace, at the shoulder or swung
            if frame == 2:
                g.line(cx + 3, cy - 2, cx + 5, cy - 4, "W")
                g.disc(cx + 6, cy - 5.5, 1.5, "m", shade="M")
            else:
                g.line(cx + 4, cy - 2, cx + 4, cy - 5, "W")
                g.disc(cx + 4.5, cy - 6.5, 1.5, "m", shade="M")
            g.set(cx + 4, cy - 1, "s")
        elif frame == 2:   # cut: blade sweeps out across the front
            g.line(cx + 3, cy - 2, cx + 6, cy - 6, "m")
            g.set(cx + 6, cy - 6, "f")
            g.rect(int(cx + 2), int(cy - 2), int(cx + 3), int(cy - 2), "g")
            g.set(cx + 3, cy - 1, "s")
        else:            # sword held upright at the right shoulder
            g.line(cx + 4, cy - 3, cx + 4, cy - 7, "m")
            g.set(cx + 4, cy - 8, "f")
            g.rect(int(cx + 3), int(cy - 2), int(cx + 5), int(cy - 2), "g")
            g.set(cx + 4, cy - 1, "s")
        sy = cy - 2.5 if frame == 2 else cy - 1.5
        kite_shield(g, cx - 4.4, sy)
        if unit == "vardish_men_at_arms":
            great_helm(g, cx, cy)
        else:
            steel_helm(g, cx, cy)
            if unit == "vardish_sergeants":
                plume(g, cx, cy)
    g.outline()
    return g, (cx, cy)


def spearmen(frame, culture=VARDISH, unit=None):
    g = Grid(16, 24)
    cx, cy = 8.0, 15.5
    if culture == RYUMON:
        sashimono(g, cx - 1, cy + 1)
    feet(g, cx, cy, frame if frame < 2 else 0, "b" if culture == RYUMON else "H")
    torso(g, cx, cy, culture)
    if unit == "kharzani_spear_guard":
        pauldrons(g, cx, cy, "M", "k")
    thrust = 3 if frame == 2 else 0
    x = cx + 3
    if culture == VARDISH:
        if unit == "vardish_pikemen":
            # a long pike, point far out in front
            g.line(x, cy + 6 - thrust, x, cy - 12 - thrust, "w")
            g.set(x, cy + 6 - thrust, "W")
            g.line(x, cy - 13 - thrust, x, cy - 14 - thrust, "m")
            g.set(x, cy - 15 - thrust, "f")
        elif unit == "vardish_halberdiers":
            # a poleaxe: an axe blade to the left of the head, a hook behind, a spike on top
            g.line(x, cy + 5 - thrust, x, cy - 10 - thrust, "w")
            g.set(x, cy + 5 - thrust, "W")
            g.rect(int(x - 2), int(cy - 12 - thrust), int(x - 1), int(cy - 10 - thrust), "m")
            g.set(x - 2, cy - 10 - thrust, "M")
            g.set(x + 1, cy - 11 - thrust, "M")
            g.line(x, cy - 11 - thrust, x, cy - 13 - thrust, "m")
            g.set(x, cy - 14 - thrust, "f")
        else:
            # a levy's spear, shorter than a pike, with a shield on the other arm
            g.line(x, cy + 4 - thrust, x, cy - 9 - thrust, "w")
            g.set(x, cy + 4 - thrust, "W")
            g.line(x, cy - 10 - thrust, x, cy - 11 - thrust, "m")
            g.set(x, cy - 12 - thrust, "f")
    elif culture == KHARZANI:
        g.line(x, cy + 4 - thrust, x, cy - 9 - thrust, "w")
        g.set(x, cy + 4 - thrust, "W")
        if unit == "kharzani_levy_spears":
            # a plain cane spear
            g.line(x, cy - 10 - thrust, x, cy - 11 - thrust, "m")
        else:
            # a spear with a broad blade and a tassel below it
            g.line(x, cy - 10 - thrust, x, cy - 12 - thrust, "m")
            g.set(x - 1, cy - 10 - thrust, "m")
            g.set(x + 1, cy - 10 - thrust, "M")
            g.set(x - 1, cy - 9 - thrust, "L")
            g.set(x + 1, cy - 9 - thrust, "T")
    elif unit == "ryumon_naginata":
        # a naginata: a curved blade on a long shaft
        g.line(x, cy + 5 - thrust, x, cy - 9 - thrust, "W")
        g.set(x, cy - 10 - thrust, "g")
        g.line(x, cy - 11 - thrust, x, cy - 12 - thrust, "m")
        g.set(x + 1, cy - 13 - thrust, "m")
        g.set(x + 1, cy - 14 - thrust, "f")
    else:
        # a yari: long shaft, slim straight blade; the yari ashigaru's is longer still
        top = 15 if unit == "ryumon_yari_ashigaru" else 14
        g.line(x, cy + 5 - thrust, x, cy - (top - 3) - thrust, "W")
        g.line(x, cy - (top - 2) - thrust, x, cy - top - thrust, "m")
        g.set(x, cy - top - thrust, "f")
    g.set(x, cy - 2 - thrust // 2, "s")
    g.set(x - 1, cy + 1, "s")
    if culture == VARDISH:
        if unit == "vardish_halberdiers":
            steel_helm(g, cx, cy, point=True)
        else:
            if unit != "vardish_pikemen":
                kite_shield(g, cx - 4.2, cy - 0.5)
            kettle_hat(g, cx, cy)
    elif culture == KHARZANI:
        if unit == "kharzani_levy_spears":
            turban(g, cx, cy)
        elif unit == "kharzani_spear_guard":
            round_shield(g, cx - 3.8, cy - 0.5, 2.7)
            steel_helm(g, cx, cy, point=True)
        else:
            round_shield(g, cx - 3.8, cy - 0.5, 2.2)
            turban(g, cx, cy, spike=True)
    elif unit == "ryumon_naginata":
        kabuto(g, cx, cy)
    else:
        jingasa(g, cx, cy, lacquer=unit == "ryumon_yari_ashigaru")
    g.outline()
    return g, (cx, cy)


def _bow(g, cx, cy, half, depth, draw, culture):
    """A bow held out in front, bowed forward; on the draw the string comes to the chest."""
    pts = []
    for i in range(-half, half + 1):
        t = i / float(half)
        bend = (1.0 - t * t) * depth
        if culture == KHARZANI and abs(t) > 0.75:
            bend -= (abs(t) - 0.75) * 6.0   # recurved tips flick forward
        # the yumi is gripped below its middle: the upper limb reaches further
        x = cx + i * (0.85 if culture == RYUMON and i < 0 else 0.75)
        pts.append((x, cy - 3.5 - bend))
    for x, y in pts:
        g.set(x, y, "w" if culture != RYUMON else "W")
    g.set(*pts[0], "k")
    g.set(*pts[-1], "k")
    if draw:
        g.line(pts[0][0], pts[0][1], cx, cy - 3.5 + draw, "f")
        g.line(pts[-1][0], pts[-1][1], cx, cy - 3.5 + draw, "f")
    else:
        g.line(pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], "f")


def archers(frame, culture=VARDISH, unit=None):
    g = Grid(18, 18)
    cx, cy = 9.0, 9.5
    if culture == RYUMON:
        sashimono(g, cx - 1, cy + 1, tall=5)
    if unit == "vardish_crossbowmen":
        # a pavise slung on the back, to shelter behind while he spans the bow
        g.rect(int(cx - 5), int(cy + 3), int(cx - 1), int(cy + 7), "T")
        g.line(cx - 5, cy + 7, cx - 1, cy + 7, "t")
        g.line(cx - 3, cy + 4, cx - 3, cy + 6, "L")
    if unit == "ryumon_yumi_samurai":
        # a katana at the hip, for when the enemy comes close
        g.line(cx - 4, cy + 1, cx - 6, cy + 5, "b")
        g.set(cx - 4, cy + 1, "g")
    feet(g, cx, cy, frame if frame < 2 else 0, "b" if culture == RYUMON else "H")
    # quiver on the back, fletchings showing
    g.rect(int(cx + 2), int(cy + 1), int(cx + 3), int(cy + 3), "h")
    g.set(cx + 2, cy + 4, "f")
    g.set(cx + 3, cy + 4, "f")
    torso(g, cx, cy, culture)
    draw = 2 if frame == 2 else 0
    if unit == "vardish_crossbowmen":
        # a crossbow: stock pointing ahead, steel prod across it
        g.line(cx, cy - 1, cx, cy - 7, "w")
        g.line(cx - 3, cy - 6, cx + 3, cy - 6, "M")
        g.set(cx - 3, cy - 5, "M")
        g.set(cx + 3, cy - 5, "M")
        g.line(cx - 3, cy - 5, cx, cy - 4 + (1 if draw else 0), "f")
        g.line(cx + 3, cy - 5, cx, cy - 4 + (1 if draw else 0), "f")
        if frame == 2:
            g.set(cx, cy - 8, "m")
        g.set(cx - 1, cy - 2, "s")
        g.set(cx + 1, cy - 2, "s")
        steel_helm(g, cx, cy)
    else:
        # a self bow, a long warbow, a recurve, or the tall yumi
        half, depth = 5, 2.2
        if unit == "vardish_longbowmen":
            half, depth = 8, 2.8
        elif culture == KHARZANI:
            half, depth = (6 if unit == "kharzani_composite_bowmen" else 5), 2.6
        elif culture == RYUMON:
            half, depth = 7, 2.6
        _bow(g, cx, cy, half, depth, draw, culture)
        if frame == 2:
            g.line(cx, cy - 7, cx, cy - 2, "w")
            g.set(cx, cy - 8, "m")
        g.set(cx, cy - 6, "s")
        if culture == VARDISH:
            if unit == "vardish_longbowmen":
                kettle_hat(g, cx, cy)
            else:
                hood(g, cx, cy)
        elif culture == KHARZANI:
            if unit == "kharzani_desert_archers":
                veil(g, cx, cy)
            else:
                turban(g, cx, cy, spike=unit == "kharzani_composite_bowmen")
        elif unit == "ryumon_yumi_samurai":
            kabuto(g, cx, cy)
        else:
            jingasa(g, cx, cy, lacquer=unit == "ryumon_ashigaru_archers")
    g.outline()
    return g, (cx, cy)


HORSES = {VARDISH: ("r", "R"), KHARZANI: ("x", "X"), RYUMON: ("q", "Q")}
## Riders who shoot from the saddle instead of charging.
HORSE_BOWS = ("kharzani_horse_archers", "ryumon_mounted_archers")


def cavalry(frame, culture=VARDISH, unit=None):
    g = Grid(16, 28)
    cx, cy = 8.0, 14.0
    coat, shade = HORSES[culture]
    if unit == "vardish_mounted_sergeants":
        coat, shade = "q", "Q"
    a = 1 if frame == 1 else -1
    # legs: front and back pairs stride on alternate frames
    for lx in (cx - 3.5, cx + 2.5):
        side = -1 if lx < cx else 1
        g.rect(int(lx), int(cy - 6 + a * side), int(lx), int(cy - 5 + a * side), "n")
        g.rect(int(lx), int(cy + 4 - a * side), int(lx), int(cy + 5 - a * side), "n")
    g.line(cx - 0.5, cy + 8, cx - 0.5 + a * 0.6, cy + 11, "n" if culture != KHARZANI else "C")
    # body and neck; the faris rides a lighter, leaner horse
    lean = 0.4 if culture == KHARZANI else 0.0
    g.ellipse(cx - 0.5, cy + 0.5, 3.4 - lean, 7.5, coat, shade=shade)
    g.ellipse(cx - 0.5, cy - 8.0, 1.8 - lean * 0.5, 3.2, coat, shade=shade)
    g.line(cx - 0.5, cy - 10.5, cx - 0.5, cy - 5, "n" if culture != KHARZANI else "C")
    g.set(cx - 1.5, cy - 11.5, shade)
    g.set(cx + 0.5, cy - 11.5, shade)
    if unit == "vardish_knights":
        # a knight's barding: team cloth down over the flanks and the neck
        g.ellipse(cx - 0.5, cy + 1.5, 3.7, 5.6, "T", shade="t", light="L")
        g.rect(int(cx - 1), int(cy - 7), int(cx), int(cy - 5), "T")
        g.rect(int(cx - 4), int(cy + 6), int(cx + 3), int(cy + 6), "g")
    elif culture == VARDISH:
        # a saddle cloth, gold-edged for the retainers
        g.ellipse(cx - 0.5, cy + 2.0, 3.4, 3.0, "T", shade="t", light="L")
        g.rect(int(cx - 4), int(cy + 4), int(cx + 3), int(cy + 4), "t" if unit else "g")
    elif culture == KHARZANI:
        # a short saddle cloth with tassels
        g.ellipse(cx - 0.5, cy + 2.0, 3.2, 2.6, "T", shade="t", light="L")
        g.set(cx - 4, cy + 4, "g")
        g.set(cx + 3, cy + 4, "g")
    else:
        g.ellipse(cx - 0.5, cy + 2.0, 3.4, 3.0, "T", shade="t", light="L")
        g.rect(int(cx - 4), int(cy + 4), int(cx + 3), int(cy + 4), "b")
        if unit == "ryumon_mounted_samurai":
            # the horo: a cloak bellying out behind the rider
            g.ellipse(cx - 0.5, cy + 4.5, 3.6, 3.0, "k")
            g.ellipse(cx - 0.5, cy + 4.5, 3.0, 2.4, "L", shade="T")
            g.line(cx - 0.5, cy + 2.5, cx - 0.5, cy + 6.5, "f")
        else:
            sashimono(g, cx - 1, cy + 0.5, tall=5)
    if unit in HORSE_BOWS:
        # a quiver hung at the saddle
        g.rect(int(cx + 2), int(cy + 3), int(cx + 3), int(cy + 6), "h")
        g.set(cx + 2, cy + 7, "f")
        g.set(cx + 3, cy + 7, "f")
    # rider
    g.ellipse(cx - 0.5, cy - 1.0, 3.6, 2.3, "k")
    if culture == RYUMON:
        g.ellipse(cx - 0.5, cy - 1.0, 3.0, 1.7, "b", light="B")
        g.line(cx - 3, cy - 1, cx + 2, cy - 1, "T")
    else:
        g.ellipse(cx - 0.5, cy - 1.0, 3.0, 1.7, "T", shade="t", light="L")
    if unit in HORSE_BOWS:
        # a short bow out over the horse's neck, drawn to loose
        _bow(g, cx - 0.5, cy - 1.0, 4 if culture == KHARZANI else 5, 2.0, 2 if frame == 2 else 0, culture)
        if frame == 2:
            g.line(cx - 0.5, cy - 8, cx - 0.5, cy - 3, "w")
            g.set(cx - 0.5, cy - 9, "m")
        g.set(cx - 0.5, cy - 6.5, "s")
    elif unit in ("kharzani_faris_lancers", "ryumon_mounted_samurai"):
        # a lance or yari carried at all times, levelled further for the charge
        reach = 3 if frame == 2 else 0
        wood = "W" if culture == RYUMON else "w"
        g.line(cx + 3, cy + 3 - reach, cx + 3, cy - 10 - reach, wood)
        g.set(cx + 3, cy - 11 - reach, "m")
        g.set(cx + 3, cy - 12 - reach, "m" if culture == RYUMON else "f")
        if culture == KHARZANI:   # a pennon on the lance
            g.set(cx + 4, cy - 9 - reach, "T")
            g.set(cx + 4, cy - 8 - reach, "L")
    elif frame == 2:   # lance couched forward for the charge
        g.line(cx + 3, cy + 2, cx + 3, cy - 12, "w" if culture != RYUMON else "W")
        g.set(cx + 3, cy - 12, "m")
        g.set(cx + 3, cy - 11, "m")
        if culture == KHARZANI:   # a pennon on the lance
            g.set(cx + 4, cy - 10, "T")
            g.set(cx + 4, cy - 9, "L")
    else:            # sword raised
        g.line(cx + 3, cy - 2, cx + 3, cy - 6, "m")
        g.set(cx + 3, cy - 1, "g")
    g.set(cx + 3, cy - 0.5, "s")
    if culture == VARDISH:
        kite_shield(g, cx - 4.0, cy - 0.5)
        if unit == "vardish_knights":
            # great helm with a crest
            g.disc(cx - 0.5, cy - 1.5, 1.9, "m", shade="M")
            g.set(cx - 0.5, cy - 2.5, "L")
            g.set(cx - 0.5, cy - 1.5, "T")
            g.set(cx - 1.5, cy - 2.5, "f")
        elif unit == "vardish_mounted_sergeants":
            kettle_hat(g, cx - 0.5, cy - 1.0)
        else:
            steel_helm(g, cx - 0.5, cy - 1.0)
    elif culture == KHARZANI:
        if unit not in HORSE_BOWS:
            round_shield(g, cx - 4.0, cy - 0.5, 2.0)
        if unit == "kharzani_faris_lancers":
            g.disc(cx - 0.5, cy - 1.5, 1.9, "m", shade="M")
            g.set(cx - 0.5, cy - 1.5, "g")
            g.set(cx - 1.5, cy - 2.5, "f")
        else:
            g.disc(cx - 0.5, cy - 1.5, 1.9, "c", shade="C")
            g.set(cx - 0.5, cy - 1.5, "m")
    else:
        g.ellipse(cx - 0.5, cy - 0.9, 2.6, 1.4, "b", light="B")
        g.disc(cx - 0.5, cy - 1.7, 1.6, "b", light="B")
        g.set(cx - 1.5, cy - 3.2, "g")
        g.set(cx + 0.5, cy - 3.2, "g")
        if unit == "ryumon_mounted_samurai":
            g.set(cx - 2.5, cy - 4.2, "g")
            g.set(cx + 1.5, cy - 4.2, "g")
    g.outline()
    return g, (cx, cy)


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
    frames = [fn(f, culture, unit) for f in range(3)]   # walk 1, walk 2, strike
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
        "## walk, strike); each frame is rows of palette characters. T/t/L are team colors.",
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
    cell_w = 20 * scale
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
