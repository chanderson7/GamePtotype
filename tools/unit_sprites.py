"""Authoring tool for Bannerfall's unit pixel art.

Draws each troop type top-down, facing up, as small palette-indexed grids, then
writes them to scripts/art/sprite_data.gd (which the game turns into textures at
startup) and to preview PNGs. Team colors are placeholders (T, t, L) that the game
swaps for blue or red.

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

def ringed_disc(g, cx, cy, r, c, shade=None, light=None):
    """A disc with its own dark outline, so it reads against what's under it."""
    g.disc(cx, cy, r + 0.9, "k")
    g.disc(cx, cy, r, c, shade=shade, light=light)


def feet(g, cx, cy, frame):
    """Boots in front and behind the body; they swap on alternate walk frames."""
    front_left = frame != 1
    for x, forward in ((cx - 2, front_left), (cx + 1, not front_left)):
        y = cy - 4 if forward else cy + 3
        g.rect(int(x), int(y), int(x) + 1, int(y) + 1, "H")


def torso(g, cx, cy):
    g.ellipse(cx, cy, 5.3, 3.7, "k")
    g.ellipse(cx, cy, 4.6, 3.0, "T", shade="t", light="L")


def helmet(g, cx, cy, point=False):
    ringed_disc(g, cx, cy - 0.5, 1.7, "m", shade="M")
    g.set(cx - 1, cy - 1.5, "f")  # glint
    if point:
        g.set(cx, cy - 0.5, "M")


def hood(g, cx, cy):
    ringed_disc(g, cx, cy - 0.5, 1.7, "t", shade="k", light="T")
    g.set(cx, cy - 2.0, "s")  # face in the hood opening


def infantry(frame):
    g = Grid(16, 16)
    cx, cy = 8.0, 8.5
    feet(g, cx, cy, frame if frame < 2 else 0)
    torso(g, cx, cy)
    if frame == 2:   # cut: blade sweeps out across the front
        g.line(cx + 3, cy - 2, cx + 6, cy - 6, "m")
        g.set(cx + 6, cy - 6, "f")
        g.rect(int(cx + 2), int(cy - 2), int(cx + 3), int(cy - 2), "g")
        g.set(cx + 3, cy - 1, "s")
    else:            # sword held upright at the right shoulder
        g.line(cx + 4, cy - 3, cx + 4, cy - 7, "m")
        g.set(cx + 4, cy - 8, "f")
        g.rect(int(cx + 3), int(cy - 2), int(cx + 5), int(cy - 2), "g")
        g.set(cx + 4, cy - 1, "s")
    # round shield on the left arm, with a gold boss; pushed forward on the strike
    sy = cy - 2.0 if frame == 2 else cy - 1.0
    ringed_disc(g, cx - 3.6, sy, 2.6, "T", shade="t", light="L")
    g.set(cx - 3.6, sy, "g")
    helmet(g, cx, cy)
    g.outline()
    return g, (cx, cy)


def spearmen(frame):
    g = Grid(16, 22)
    cx, cy = 8.0, 14.5
    feet(g, cx, cy, frame if frame < 2 else 0)
    torso(g, cx, cy)
    thrust = 3 if frame == 2 else 0
    # long spear held two-handed along the right side, point well out in front
    x = cx + 3
    g.line(x, cy + 5 - thrust, x, cy - 10 - thrust, "w")
    g.set(x, cy + 5 - thrust, "W")
    g.line(x, cy - 11 - thrust, x, cy - 13 - thrust, "m")
    g.set(x - 1, cy - 11 - thrust, "M")
    g.set(x + 1, cy - 11 - thrust, "M")
    g.set(x, cy - 2 - thrust // 2, "s")
    g.set(x - 1, cy + 1, "s")
    helmet(g, cx, cy, point=True)
    g.outline()
    return g, (cx, cy)


def archers(frame):
    g = Grid(16, 16)
    cx, cy = 8.0, 9.5
    feet(g, cx, cy, frame if frame < 2 else 0)
    # quiver on the back, fletchings showing
    g.rect(int(cx + 2), int(cy + 1), int(cx + 3), int(cy + 3), "h")
    g.set(cx + 2, cy + 4, "f")
    g.set(cx + 3, cy + 4, "f")
    torso(g, cx, cy)
    # bow held out in front, bowed forward; string pulled to the chest on the draw
    draw = 2 if frame == 2 else 0
    pts = []
    for i in range(-5, 6):
        t = i / 5.0
        pts.append((cx + i * 0.75, cy - 3.5 - (1.0 - t * t) * 3.0))
    for x, y in pts:
        g.set(x, y, "w")
    g.set(*pts[0], "W")
    g.set(*pts[-1], "W")
    if draw:
        g.line(pts[0][0], pts[0][1], cx, cy - 3.5 + draw, "f")
        g.line(pts[-1][0], pts[-1][1], cx, cy - 3.5 + draw, "f")
    else:
        g.line(pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], "f")
    if frame == 2:
        g.line(cx, cy - 7, cx, cy - 2, "w")   # nocked arrow
        g.set(cx, cy - 8, "m")
    g.set(cx, cy - 6.5, "s")   # bow hand
    hood(g, cx, cy)
    g.outline()
    return g, (cx, cy)


def cavalry(frame):
    g = Grid(16, 26)
    cx, cy = 8.0, 14.0
    # legs: front and back pairs stride on alternate frames
    a = 1 if frame == 1 else -1
    for lx in (cx - 3.5, cx + 2.5):
        side = -1 if lx < cx else 1
        g.rect(int(lx), int(cy - 6 + a * side), int(lx), int(cy - 5 + a * side), "n")
        g.rect(int(lx), int(cy + 4 - a * side), int(lx), int(cy + 5 - a * side), "n")
    # tail
    g.line(cx - 0.5, cy + 8, cx - 0.5 + a * 0.6, cy + 11, "n")
    # body and neck
    g.ellipse(cx - 0.5, cy + 0.5, 3.4, 7.5, "r", shade="R")
    g.ellipse(cx - 0.5, cy - 8.0, 1.8, 3.2, "r", shade="R")
    g.line(cx - 0.5, cy - 10.5, cx - 0.5, cy - 5, "n")    # mane
    g.set(cx - 1.5, cy - 11.5, "R")                        # ears
    g.set(cx + 0.5, cy - 11.5, "R")
    # team-coloured caparison over the hindquarters and saddle
    g.ellipse(cx - 0.5, cy + 2.0, 3.6, 3.2, "T", shade="t", light="L")
    g.rect(int(cx - 4), int(cy + 4), int(cx + 3), int(cy + 4), "g")
    # rider
    g.ellipse(cx - 0.5, cy - 1.0, 3.6, 2.3, "T", shade="t", light="L")
    if frame == 2:   # lance couched forward for the charge
        g.line(cx + 3, cy + 2, cx + 3, cy - 12, "w")
        g.set(cx + 3, cy - 12, "m")
        g.set(cx + 3, cy - 11, "m")
    else:            # sword raised
        g.line(cx + 3, cy - 2, cx + 3, cy - 6, "m")
        g.set(cx + 3, cy - 1, "g")
    g.set(cx + 3, cy - 0.5, "s")
    g.disc(cx - 0.5, cy - 1.5, 1.9, "m", shade="M")
    g.set(cx - 1.5, cy - 2.5, "f")
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


def arrow():
    g = Grid(3, 9)
    g.line(1, 2, 1, 7, "w")
    g.set(1, 0, "m"); g.set(1, 1, "m")
    g.set(0, 1, "M"); g.set(2, 1, "M")
    g.set(0, 8, "f"); g.set(2, 8, "f"); g.set(1, 8, "f")
    return g, (1.5, 4.5)


BUILDERS = {"infantry": infantry, "spearmen": spearmen, "archers": archers, "cavalry": cavalry}


def build_all():
    out = {}
    for name, fn in BUILDERS.items():
        frames = [fn(f) for f in range(3)]   # walk 1, walk 2, strike
        out[name] = {"frames": [f[0].rows() for f in frames], "pivot": frames[0][1]}
    out["corpse"] = {"frames": [corpse(0)[0].rows()], "pivot": corpse(0)[1]}
    out["corpse_horse"] = {"frames": [corpse(1)[0].rows()], "pivot": corpse(1)[1]}
    out["arrow"] = {"frames": [arrow()[0].rows()], "pivot": arrow()[1]}
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


def preview(sprites, out_dir, scale=8):
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    names = list(BUILDERS)
    cell_w = 18 * scale
    cell_h = 28 * scale
    sheet = Image.new("RGBA", (cell_w * 3 * 2 + scale * 4, cell_h * len(names)), (78, 122, 56, 255))
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
                ox = ti * (cell_w * 3 + scale * 4) + fi * cell_w + (cell_w - img.width) // 2
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
