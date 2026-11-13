"""Authoring tool for Bannerfall's siege engines in pixel art.

Drawn like the men (tools/unit_sprites.py): top-down, facing up (toward the wall),
lit from the upper left, outlined in the same ink and at the same pixel size, so a
trebuchet stands beside its crew as one picture. Each land builds its own way:

  Vardish   counterweight trebuchet, hide-roofed tower and ram, plank mantlets,
            springalds on the wall towers
  Kharzani  a traction mangonel throwing naphtha, a tower roofed with palm mats
  Ryumon    a light bamboo thrower, a tower of dark lacquered planks, bundles of bamboo
            for shields

Writes scripts/art/siege_sprite_data.gd (the game builds textures from it) and, with a
directory, preview sheets.

    python3 tools/siege_sprites.py [preview_dir]
"""
import math
import os
import sys

PALETTE = {
    "k": (26, 20, 32),      # outline ink (as the men)
    "o": (196, 140, 82),    # wood, lit
    "w": (150, 98, 52),     # wood
    "W": (98, 62, 32),      # wood, shade
    "O": (64, 40, 22),      # wood, deep shade
    "h": (128, 84, 52),     # hide, lit
    "H": (86, 54, 34),      # hide, shade
    "m": (206, 212, 222),   # iron, lit
    "M": (124, 132, 148),   # iron
    "N": (72, 76, 90),      # iron, shade
    "y": (214, 182, 112),   # rope
    "Y": (152, 120, 66),    # rope, shade
    "e": (150, 146, 138),   # stone
    "E": (100, 96, 92),     # stone, shade
    "i": (196, 192, 182),   # stone, lit
    "a": (212, 196, 116),   # bamboo, lit
    "A": (154, 138, 72),    # bamboo
    "Z": (104, 92, 46),     # bamboo, shade
    "c": (226, 210, 168),   # palm mat, lit
    "C": (172, 150, 104),   # palm mat, shade
    "b": (52, 44, 50),      # black lacquer
    "B": (96, 84, 92),      # lacquer sheen
    "r": (166, 42, 36),     # red cloth / lacquer
    "j": (255, 196, 92),    # flame, bright
    "J": (240, 120, 40),    # flame
    "l": (190, 60, 30),     # flame, deep
    "f": (236, 230, 214),   # bowstring, fletching
}

LANDS = ("vardish", "kharzani", "ryumon")


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            if c is None:
                self.px.pop((x, y), None)
            else:
                self.px[(x, y)] = c

    def get(self, x, y):
        return self.px.get((x, y))

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def box(self, x0, y0, x1, y1, base, lit, shade):
        """A block lit from the upper left: its top and left edge lit, bottom and right shaded."""
        self.rect(x0, y0, x1, y1, base)
        for x in range(int(x0), int(x1) + 1):
            self.put(x, y0, lit)
            self.put(x, y1, shade)
        for y in range(int(y0), int(y1) + 1):
            self.put(x0, y, lit)
            self.put(x1, y, shade)

    def line(self, x0, y0, x1, y1, c, width=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for dx in range(width):
                for dy in range(width):
                    self.put(x + dx - (width - 1) / 2.0, y + dy - (width - 1) / 2.0, c)

    def beam(self, x0, y0, x1, y1, width=2, lit="o", base="w", shade="W"):
        """A squared timber between two points: lit on the side toward the upper left."""
        self.line(x0, y0, x1, y1, base, width)
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln       # one side of the beam
        if nx + ny > 0:
            nx, ny = -nx, -ny             # make it the upper-left side
        off = (width - 1) / 2.0 + 0.4
        self.line(x0 + nx * off, y0 + ny * off, x1 + nx * off, y1 + ny * off, lit, 1)
        self.line(x0 - nx * off, y0 - ny * off, x1 - nx * off, y1 - ny * off, shade, 1)

    def disc(self, cx, cy, r, c, lit=None, shade=None):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                d = math.hypot(x - cx, y - cy)
                if d <= r:
                    col = c
                    if lit and (x - cx) + (y - cy) < -r * 0.5:
                        col = lit
                    elif shade and (x - cx) + (y - cy) > r * 0.6:
                        col = shade
                    self.put(x, y, col)

    def outline(self, ink="k"):
        """Ink every empty pixel that touches the drawing (the men's outline)."""
        add = []
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.px and 0 <= p[0] < self.w and 0 <= p[1] < self.h:
                    add.append(p)
        for p in add:
            self.px[p] = ink

    def rows(self):
        return ["".join(self.px.get((x, y), ".") for x in range(self.w)) for y in range(self.h)]

    def flip_x(self):
        g = Grid(self.w, self.h)
        for (x, y), c in self.px.items():
            g.px[(self.w - 1 - x, y)] = c
        return g


# ---------------------------------------------------------------- stone throwers

def _wheel(g, cx, cy, frame=0, r=2.6, lit="o", base="w", shade="O", hub="M"):
    """A cart wheel seen from above, on its edge: a short thick bar."""
    g.rect(cx - 1, cy - r, cx + 1, cy + r, base)
    g.line(cx - 1, cy - r, cx - 1, cy + r, lit)
    g.line(cx + 1, cy - r, cx + 1, cy + r, shade)
    g.put(cx, cy - r + (frame % 2), hub)
    g.put(cx, cy + 1 - (frame % 2), hub)


def trebuchet(frame, land="vardish"):
    """frame 0 wound (the arm drawn down to the back, the sling and stone on the ground
    behind), 1 swinging (the arm upright, foreshortened), 2 thrown (the arm forward)."""
    g = Grid(32, 46)
    wood = {"vardish": ("o", "w", "W"), "kharzani": ("o", "w", "W"), "ryumon": ("a", "A", "Z")}[land]
    cx = 15.5
    # The base: two long sills on wheels, and two cross-timbers between them.
    for sx in (5, 26):
        g.beam(sx, 8, sx, 43, 3, *wood)
    for yy in (10, 41):
        g.beam(5, yy, 26, yy, 2, *wood)
    for sx in (2, 29):
        for yy in (13, 38):
            _wheel(g, sx, yy, 0, 2.6, *({"ryumon": ("a", "A", "Z")}.get(land, ("o", "w", "O"))))
    # The winch at the back, its rope wound round it.
    g.beam(8, 36, 23, 36, 3, *wood)
    for xx in range(9, 23, 2):
        g.put(xx, 36, "y")
    g.disc(7, 36, 1.8, "M", "m", "N")
    g.disc(24, 36, 1.8, "M", "m", "N")
    # Two tall uprights carrying the axle (the brightest wood: they stand highest), braced
    # back to the sills.
    for s in (-1, 1):
        ux = cx + s * 6.5
        g.beam(ux - s * 4.0, 15, ux, 22, 2, *wood)
        g.beam(ux - s * 4.0, 31, ux, 26, 2, *wood)
        g.box(ux - 1.5, 20, ux + 1.5, 28, wood[0], wood[0], wood[1])
    g.line(cx - 6, 24, cx + 6, 24, "M", 2)
    g.line(cx - 6, 23, cx + 6, 23, "m")
    # The arm, its counterweight (a Vardish box of stones bound in iron), and the sling.
    def weight(y0, y1):
        g.box(cx - 6, y0, cx + 5, y1, "W", "w", "O")
        for yy in range(int(y0) + 2, int(y1), 3):
            g.line(cx - 5, yy, cx + 4, yy, "M")
        g.line(cx - 6, y0, cx + 5, y0, "m")
    if frame == 0:
        g.beam(cx - 0.5, 20, cx - 0.5, 45, 4, *wood)
        if land == "vardish":
            weight(13, 21)
        g.line(cx, 45, cx + 4, 44, "y")
        g.disc(cx + 5, 43, 1.9, "e", "i", "E")
    elif frame == 1:
        g.beam(cx - 0.5, 14, cx - 0.5, 32, 5, *wood)
        if land == "vardish":
            weight(27, 34)
        g.line(cx, 14, cx - 4, 9, "y")
        g.disc(cx - 4, 8, 1.9, "e", "i", "E")
    else:
        g.beam(cx - 0.5, 1, cx - 0.5, 29, 4, *wood)
        if land == "vardish":
            weight(27, 35)
        g.line(cx, 1, cx + 3, 0, "y")
    if land == "kharzani":
        # A traction mangonel: ropes from the short end of the arm, fanned back for the crew
        # to haul on; a pot of naphtha in the sling, glowing.
        end_y = {0: 20, 1: 31, 2: 29}[frame]
        for k, dx in enumerate((-9, -5, -1, 3, 7)):
            g.line(cx + dx * 0.2, end_y, cx + dx, 45, "y" if k % 2 == 0 else "Y")
        if frame == 0:
            g.disc(cx + 5, 43, 1.9, "J", "j", "l")
        elif frame == 1:
            g.disc(cx - 4, 8, 1.9, "J", "j", "l")
    if land == "ryumon":
        # Lashings of rope where bamboo meets bamboo.
        for (x, y) in ((5, 10), (26, 10), (5, 41), (26, 41), (9, 22), (22, 22)):
            g.put(x, y, "y")
    g.outline()
    return g


# ---------------------------------------------------------------- the tower

def tower(frame, land="vardish"):
    """frames 0 and 1 rolling (the wheels' spokes turn), 2 docked (its bridge down across
    the wall top, ahead of it)."""
    g = Grid(32, 56)
    x0, x1, y0, y1 = 4, 27, 24, 53
    roof = {"vardish": ("h", "H"), "kharzani": ("c", "C"), "ryumon": ("B", "b")}[land]
    # Wheels, two each side.
    for sx in (2, 29):
        for yy in (29, 47):
            _wheel(g, sx, yy, frame, 3.0)
    # The body: plank walls round a roof.
    g.box(x0, y0, x1, y1, "w", "o", "W")
    g.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, roof[0])
    # The roof: hides stitched over (Vardish), palm mats (Kharzani), lacquered planks
    # with red trim (Ryumon); a ridge down the middle, the right side in shade.
    mid = (x0 + x1) // 2
    g.rect(mid + 1, y0 + 2, x1 - 2, y1 - 2, roof[1])
    g.line(mid, y0 + 2, mid, y1 - 2, "W")
    if land == "vardish":
        for yy in range(y0 + 6, y1 - 2, 6):
            g.line(x0 + 2, yy, x1 - 2, yy, "W")
        for yy in range(y0 + 4, y1 - 2, 6):
            g.put(x0 + 4, yy, "y")
            g.put(x1 - 4, yy, "Y")
    elif land == "kharzani":
        for yy in range(y0 + 3, y1 - 2, 3):
            for xx in range(x0 + 2 + (yy % 2), x1 - 1, 3):
                g.put(xx, yy, "C" if xx <= mid else "Y")
    else:
        for xx in range(x0 + 4, x1 - 2, 4):
            g.line(xx, y0 + 2, xx, y1 - 2, "b")
        g.line(x0 + 2, y0 + 2, x1 - 2, y0 + 2, "r")
        g.line(x0 + 2, y1 - 2, x1 - 2, y1 - 2, "r")
    # The fighting platform on top: a parapet of merlons all round.
    for xx in range(x0, x1 + 1, 3):
        g.rect(xx, y0, xx + 1, y0 + 1, "o")
        g.rect(xx, y1 - 1, xx + 1, y1, "W")
    for yy in range(y0, y1 + 1, 3):
        g.rect(x0, yy, x0 + 1, yy + 1, "o")
        g.rect(x1 - 1, yy, x1, yy + 1, "W")
    if frame < 2:
        # The drawbridge raised: its planks stand against the front.
        g.box(x0 + 3, y0 - 4, x1 - 3, y0 - 1, "w", "o", "W")
        for xx in range(x0 + 5, x1 - 3, 3):
            g.put(xx, y0 - 3, "W")
        g.line(x0 + 3, y0 - 5, x0 + 3, y0 - 1, "y")
        g.line(x1 - 3, y0 - 5, x1 - 3, y0 - 1, "Y")
    else:
        # Down: a plank bridge running ahead to the wall walk.
        g.box(x0 + 4, 1, x1 - 4, y0 - 1, "w", "o", "W")
        for yy in range(3, y0 - 1, 3):
            g.line(x0 + 5, yy, x1 - 5, yy, "W")
        g.line(x0 + 4, 1, x0 + 4, y0 - 1, "y")
        g.line(x1 - 4, 1, x1 - 4, y0 - 1, "Y")
    g.outline()
    return g


# ---------------------------------------------------------------- the ram

def ram(frame, land="vardish"):
    """A roofed ram: frame 0 the log drawn back, 1 swung home (its iron head at the gate)."""
    g = Grid(24, 42)
    roof = {"vardish": ("h", "H"), "kharzani": ("c", "C"), "ryumon": ("B", "b")}[land]
    x0, x1, y0, y1 = 3, 20, 8, 40
    for sx in (1, 22):
        for yy in (13, 34):
            _wheel(g, sx, yy, 0, 2.6)
    g.box(x0, y0, x1, y1, "w", "o", "W")
    mid = (x0 + x1) // 2
    g.rect(x0 + 1, y0 + 1, mid, y1 - 1, roof[0])
    g.rect(mid + 1, y0 + 1, x1 - 1, y1 - 1, roof[1])
    g.line(mid, y0 + 1, mid, y1 - 1, "O")
    for yy in range(y0 + 4, y1 - 1, 5):
        g.line(x0 + 1, yy, x1 - 1, yy, "W" if land != "ryumon" else "r")
    # The log, out of the front of the shed, its iron head.
    head = 1 if frame == 1 else 4
    g.beam(mid, head + 3, mid, y0 + 2, 3, "o", "w", "W")
    g.box(mid - 2, head, mid + 2, head + 3, "M", "m", "N")
    g.outline()
    return g


# ---------------------------------------------------------------- mantlets, bolts

def mantlet(frame, land="vardish"):
    """A wheeled screen of planks with props behind (Ryumon: lashed bundles of bamboo)."""
    g = Grid(22, 10)
    if land == "ryumon":
        for i in range(6):
            cx = 2.5 + i * 3.4
            g.disc(cx, 3.5, 1.9, "A", "a", "Z")
        g.line(1, 3, 20, 3, "y")
        g.line(1, 5, 20, 5, "Y")
        g.line(4, 6, 2, 8, "Z")
        g.line(17, 6, 19, 8, "Z")
    else:
        lit, base, shade = ("o", "w", "W") if land == "vardish" else ("c", "C", "W")
        g.box(1, 1, 20, 4, base, lit, shade)
        for xx in range(4, 20, 4):
            g.line(xx, 1, xx, 4, shade)
        g.line(5, 5, 4, 8, "W")
        g.line(16, 5, 17, 8, "W")
        g.put(1, 5, "O")
        g.put(20, 5, "O")
    g.outline()
    return g


def bolt_thrower(frame, land="vardish"):
    """A springald on a wall tower: frame 0 spanned with a bolt laid, 1 just loosed."""
    g = Grid(20, 18)
    cx = 9.5
    wood = ("o", "w", "W") if land != "ryumon" else ("B", "b", "b")
    # The stock and its cross-base.
    g.beam(cx, 3, cx, 16, 3, *wood)
    g.beam(cx - 6, 13, cx + 6, 13, 2, *wood)
    # The bow arms swept back to the string.
    pull = 5 if frame == 0 else 1
    for s in (-1, 1):
        g.line(cx, 4, cx + s * 4, 4, wood[1], 2)
        g.line(cx + s * 4, 4, cx + s * 8, 5 + pull * 0.6, wood[1], 2)
        g.line(cx + s * 8, 5 + pull * 0.6, cx, 4 + pull + 1, "f")
    if frame == 0:
        g.line(cx, 1, cx, 10, "W")
        g.put(cx, 0, "m")
        g.put(cx, 1, "M")
    g.outline()
    return g


def platform():
    """The stone platform a courtyard thrower stands on."""
    g = Grid(40, 40)
    g.box(1, 1, 38, 38, "e", "i", "E")
    for yy in range(5, 38, 6):
        g.line(2, yy, 37, yy, "E")
        for xx in range(4 + (yy // 6 % 2) * 4, 37, 8):
            g.line(xx, yy - 5, xx, yy, "E")
    g.outline()
    return g


# ---------------------------------------------------------------- shot, fire, rubble

def stone(frame=0):
    g = Grid(7, 7)
    g.disc(3, 3, 2.6, "e", "i", "E")
    g.outline()
    return g


def naphtha(frame=0):
    g = Grid(7, 7)
    g.disc(3, 3, 2.6, "J", "j", "l")
    g.put(2, 2, "f")
    g.outline("O")
    return g


def bolt(frame=0):
    g = Grid(3, 11)
    g.line(1, 2, 1, 9, "w")
    g.put(1, 0, "m")
    g.put(1, 1, "M")
    g.put(0, 9, "f")
    g.put(2, 9, "f")
    g.put(1, 10, "f")
    return g


def flame(frame):
    """Four frames of a wood fire's tongues, licking up."""
    g = Grid(11, 14)
    shapes = [
        [(5, 12, 4, 9), (2, 12, 2, 6), (8, 12, 2, 7)],
        [(5, 12, 4, 11), (2, 12, 2, 7), (8, 12, 2, 5)],
        [(5, 12, 4, 8), (2, 12, 2, 5), (8, 12, 2, 8)],
        [(5, 12, 4, 10), (2, 12, 2, 8), (8, 12, 2, 6)],
    ][frame % 4]
    for (cx, base, half, h) in shapes:
        for y in range(h):
            w = half * (1.0 - y / float(h)) + 0.4
            for x in range(int(cx - w), int(cx + w) + 1):
                yy = base - y
                col = "l" if y < 2 else ("J" if abs(x - cx) > w * 0.45 or y > h * 0.7 else "j")
                g.put(x, yy, col)
    return g


def rubble(frame):
    """A cell of fallen wall: heaped blocks and dust (tinted by the walls' stone)."""
    import random
    rnd = random.Random(31 + frame)
    g = Grid(14, 14)
    g.rect(0, 2, 13, 11, "E")
    for _ in range(14):
        x = rnd.randint(0, 11)
        y = rnd.randint(0, 10)
        g.box(x, y, x + rnd.randint(1, 3), y + rnd.randint(1, 2), "e", "i", "E")
    g.outline()
    return g


# ---------------------------------------------------------------- the set

def build_all():
    sprites = {}

    def add(name, fn, frames, pivot=None):
        grids = [fn(f) for f in range(frames)]
        w, h = grids[0].w, grids[0].h
        sprites[name] = {"pivot": pivot if pivot is not None else (w / 2.0, h / 2.0), "frames": [g.rows() for g in grids]}

    for land in LANDS:
        add("%s/thrower" % land, lambda f, l=land: trebuchet(f, l), 3, (16.0, 24.0))
        add("%s/tower" % land, lambda f, l=land: tower(f, l), 3, (16.0, 38.5))
        add("%s/ram" % land, lambda f, l=land: ram(f, l), 2, (12.0, 12.0))
        add("%s/mantlet" % land, lambda f, l=land: mantlet(f, l), 1)
        add("%s/bolt" % land, lambda f, l=land: bolt_thrower(f, l), 2)
    add("platform", lambda f: platform(), 1)
    add("stone", stone, 1)
    add("naphtha", naphtha, 1)
    add("bolt_shot", bolt, 1)
    add("flame", flame, 4, (5.5, 12.5))
    add("rubble", rubble, 3)
    return sprites


def gd_color(rgb):
    return "Color(%.3f, %.3f, %.3f)" % tuple(c / 255.0 for c in rgb)


def write_gd(sprites, path):
    lines = [
        "## Generated by tools/siege_sprites.py; edit the tool, not this file.",
        "## Siege engines in pixel art, top-down and facing up (toward the wall). Each sprite",
        "## is a list of frames, each frame rows of palette characters; `pivot` is the pixel",
        "## the engine stands on.",
        "extends RefCounted",
        "",
        "const PALETTE := {",
    ]
    for ch, rgb in PALETTE.items():
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


def preview(sprites, out_dir, scale=6):
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    grass = (78, 122, 56, 255)
    rows_out = []
    for land in LANDS:
        row = []
        for kind in ("thrower", "tower", "ram", "mantlet", "bolt"):
            for rows in sprites["%s/%s" % (land, kind)]["frames"]:
                row.append(rows)
        rows_out.append(row)
    rows_out.append([sprites[n]["frames"][i] for n in ("platform", "stone", "naphtha", "bolt_shot", "flame", "rubble")
                     for i in range(len(sprites[n]["frames"]))])
    tiles = []
    for row in rows_out:
        imgs = []
        for rows in row:
            img = Image.new("RGBA", (len(rows[0]), len(rows)), grass)
            for y, r in enumerate(rows):
                for x, ch in enumerate(r):
                    if ch != ".":
                        img.putpixel((x, y), PALETTE[ch] + (255,))
            imgs.append(img.resize((img.width * scale, img.height * scale), Image.NEAREST))
        tiles.append(imgs)
    gap = scale * 3
    width = max(sum(i.width + gap for i in r) for r in tiles)
    height = sum(max(i.height for i in r) + gap for r in tiles)
    sheet = Image.new("RGBA", (width, height), (40, 38, 44, 255))
    y = 0
    for r in tiles:
        x = 0
        for i in r:
            sheet.paste(i, (x, y))
            x += i.width + gap
        y += max(i.height for i in r) + gap
    sheet.save(os.path.join(out_dir, "siege_sprites.png"))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    sprites = build_all()
    write_gd(sprites, os.path.join(here, "..", "scripts", "art", "siege_sprite_data.gd"))
    if len(sys.argv) > 1:
        preview(sprites, sys.argv[1])
    print("%d sprites" % len(sprites))
