"""The romance portraits' wardrobe: clothes and jewellery we design and draw ourselves.

tools/portrait_rig.py keeps only each woman's painted head (her face and hair, in the
rig's pixel look) and calls `dress` to draw everything else on the pixel grid (192x256):
her neck and shoulders in her own skin tones, then each piece of an outfit
(assets/portraits/rig/outfits.json) in layer order, lit from the upper left like her
face, in a few flat tones per fabric, dithered where they meet, outlined like the lords'
portraits. Her loose hair stays in front of what she wears; hoods, veils and scarves go
over it.

An outfit is a list of pieces, each a dict naming the `piece` and its options:

  chemise   {fabric, neckline}                       the shift under everything
  gown      {fabric, neckline, sleeves, pattern, trim, lining}
  coat      {fabric, length, trim, lining, sleeves}  open at the front (a kaftan, a coat)
  wrap      {fabric, collar: [colours], pattern, trim}  crossed at the throat (a kimono)
  jacket    {fabric, trim, pattern}                  a short open jacket (a haori)
  mantle    {fabric, fur, clasp, length}             a cape on the shoulders, open in front
  cloak     {fabric, hood, fur, clasp, lining}       a long cloak; `hood` up or down
  sash      {fabric, width, knot, pattern, cord}     wound at the waist (an obi, a sash)
  belt      {fabric, buckle}                         a narrow belt with a buckle
  scarf     {fabric, trim, pattern}                  wrapped over the hair, the face open
  necklace  {kind: chain|pearls|coins|beads, metal, gem}
  choker    {fabric, metal, gem}
  brooch    {metal, gem, at: chest|throat}
  earrings  {metal, gem}
  circlet   {metal, gem, coins}
  comb      {metal}
  pin       {metal, gem, dangle}
  flowers   {colours, at: crown|bun}
  veil      {fabric, trim, alpha}
  layer     {name, dye, over_hair, outline}          a hand-drawn piece (layers/<name>.png)

Fabrics, metals and gems are named (FABRICS, METALS, GEMS) or given as a ramp of
colours, darkest first. `trim` is {kind: braid|dots|diamonds|band|fur, fabric, gem}.
`neckline`: square, v, round, boat, high. `sleeves`: fitted, flared, hanging.
`pattern`: plain, damask, stripes, diamonds, dots, kiku, checks.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

W, H = 192, 256
LIGHT = np.array([-0.55, -0.7, 0.5])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
YY, XX = np.mgrid[0:H, 0:W].astype(float)
OUTLINE = np.array([14.0, 10.0, 16.0])

FABRICS = {
    # wool and linen
    "linen": ["4e463a", "8e8472", "c9bfa8", "ece4d0", "fbf7ec"],
    "white": ["6a6e78", "a8acb6", "d8dce2", "f2f4f6", "ffffff"],
    "woad": ["0a1230", "16245a", "24388a", "3a56b4", "6a86d6"],
    "teal": ["071a1e", "0f3238", "1c4c52", "2f6c70", "5a9a96"],
    "forest": ["06140c", "123222", "1f5236", "33784e", "5ea377"],
    "moss": ["12160a", "26301a", "3e4c2a", "5c6c3e", "8a9a62"],
    "wine": ["1a060c", "3e0e1c", "6a1a2e", "962a40", "c04a58"],
    "crimson": ["1e0408", "52101a", "8a1c2a", "b8323c", "dc6a64"],
    "rust": ["220c06", "4e1e0e", "7e3418", "ac5226", "d6824a"],
    "saffron": ["2a1204", "6a3410", "a65e1c", "d8922e", "f4c46a"],
    "sand": ["3a2c1c", "6e5a40", "a48c68", "cdb894", "eadcbc"],
    "indigo": ["08081a", "141638", "22265a", "363e80", "5a64a8"],
    "plum": ["160a14", "34142e", "52203e", "763050", "a05a74"],
    "charcoal": ["101216", "22262e", "363c46", "50586a", "7a8496"],
    "slate": ["1a2028", "343e4c", "52606e", "76869a", "a6b4c4"],
    "brown": ["1a0f08", "3a2416", "5c3a22", "825632", "ae7e52"],
    "leather": ["1e1008", "4a2c18", "6a4226", "8a5a36", "b07a4e"],
    "black": ["07060a", "121116", "1e1c24", "2c2a34", "403e4a"],
    "rose": ["2a0a14", "5e1e34", "94344e", "c45a70", "ec9aa6"],
    "maple": ["240804", "5a160a", "922812", "c4441e", "ec7a3c"],
    "sky": ["1c2e46", "345474", "5480a6", "82acd0", "bcd8ee"],
    "fur": ["5e544c", "8e847a", "bcb2a6", "e2dbd0", "f8f4ee"],
    "sable": ["120c08", "2a1c12", "46301e", "66482e", "8c6a48"],
}
METALS = {
    "gold": ["4a2c0a", "a8741e", "e8b850", "fff0b0"],
    "silver": ["2a2c32", "6d747e", "b9c1ca", "eef3f7"],
    "bronze": ["2e1a0a", "6a4220", "a46a34", "d8a060"],
}
GEMS = {
    "garnet": ["3a0510", "8a1428", "d0303f", "ff8f8f"],
    "emerald": ["06261a", "0e5a36", "28a060", "a0f0c0"],
    "sapphire": ["06103a", "142a8a", "3a62d8", "a8c4ff"],
    "pearl": ["7c7268", "c8beb4", "f0ece6", "ffffff"],
    "jade": ["0e3e32", "1c6a56", "5cc8a8", "a8f0d8"],
    "coral": ["5a1a10", "a8402c", "e87a5a", "ffc0a8"],
    "amber": ["4a2006", "96500e", "e09a2a", "ffd88a"],
    "turquoise": ["0a3a3a", "1a7a7a", "3cc0b8", "a8f4ec"],
}

# Each woman's body on the grid: what the pieces are fitted to. `face` is the painted face
# (hoods, veils and scarves leave it open); `ears` the earlobes that show; `hairline` the
# arc a circlet sits on; `bun` where a pin or comb goes through her hair; `crown` the top
# of her head.
BODIES = {
    "edda": {
        "chin": (90, 118), "neck": (80, 115, 112, 133), "collar_y": 132,
        "shoulders": ((40, 141), (152, 140)), "arms": (((32, 150), (12, 256)), ((160, 150), (180, 256))),
        "torso": (96, 210, 74, 110), "sternum": (96, 166), "waist": 240,
        "ears": [(118, 92)], "hairline": [(62, 60), (78, 53), (96, 50), (114, 53), (130, 60)],
        "bun": (140, 80), "crown": (98, 26), "head": (98, 66, 50, 46),
        "face": [(59, 58), (75, 50), (102, 52), (113, 65), (115, 87), (111, 102), (102, 115), (90, 120), (80, 120),
                 (70, 114), (61, 102), (58, 80)],
    },
    "farid": {
        "chin": (86, 119), "neck": (76, 110, 114, 134), "collar_y": 132,
        "shoulders": ((32, 150), (166, 148)), "arms": (((28, 156), (8, 256)), ((164, 156), (184, 256))),
        "torso": (96, 210, 76, 110), "sternum": (92, 170), "waist": 244,
        "ears": [(122, 92)], "hairline": [(60, 62), (76, 55), (94, 52), (112, 55), (128, 62)],
        "bun": (138, 72), "crown": (96, 24), "head": (96, 66, 52, 46),
        "face": [(60, 56), (75, 50), (100, 52), (111, 62), (113, 82), (110, 100), (100, 112), (85, 119), (75, 116),
                 (65, 106), (61, 90), (59, 70)],
    },
    "kaede": {
        "chin": (88, 117), "neck": (80, 112, 112, 130), "collar_y": 128,
        "shoulders": ((34, 150), (162, 148)), "arms": (((30, 156), (8, 256)), ((164, 156), (186, 256))),
        "torso": (96, 210, 74, 110), "sternum": (92, 166), "waist": 240,
        "ears": [(118, 90)], "hairline": [(60, 58), (76, 52), (94, 50), (112, 52), (126, 58)],
        "bun": (136, 84), "crown": (96, 26), "head": (96, 64, 50, 44),
        "face": [(59, 57), (75, 50), (102, 52), (116, 65), (117, 85), (112, 102), (102, 114), (88, 118), (75, 114),
                 (65, 104), (60, 88), (58, 70)],
    },
}


# ---------------------------------------------------------------- drawing kit
def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], float)


def lum(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def colours(name, kind=None):
    """A ramp, darkest first: a name from FABRICS, METALS or GEMS, or a list of colours."""
    if isinstance(name, (list, tuple)):
        return [hexc(c) for c in name]
    for table in ((kind,) if kind else ()) + ("FABRICS", "METALS", "GEMS"):
        t = {"FABRICS": FABRICS, "METALS": METALS, "GEMS": GEMS}.get(table, {})
        if name in t:
            return [hexc(c) for c in t[name]]
    raise KeyError("no fabric, metal or gem called %r" % (name,))


def shade(t, ramp, dither=0.3):
    """t (0 dark .. 1 light) in the ramp's flat tones, ordered-dithered where two meet."""
    C = np.array(ramp)
    k = np.floor(np.clip(t, 0, 1) * (len(C) - 1) + (BAYER[YY.astype(int) % 4, XX.astype(int) % 4] - 0.5) * dither + 0.5)
    return C[np.clip(k.astype(int), 0, len(C) - 1)]


def poly(pts):
    m = Image.new("L", (W, H), 0)
    if len(pts) > 2:
        ImageDraw.Draw(m).polygon([tuple(map(float, p)) for p in pts], fill=255)
    return np.array(m) > 0


def line(pts, width=1):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).line([tuple(map(float, p)) for p in pts], fill=255, width=width, joint="curve")
    return np.array(m) > 0


def disc(cx, cy, r):
    return (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r


def curve(pts, n=12):
    """A smooth path through `pts` (Catmull-Rom)."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (np.array(p, float) for p in P[i - 1:i + 3])
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(tuple(map(float, pts[-1])))
    return out


def edge(m):
    """The pixels of `m` that touch something outside it."""
    return m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))


def grow(m, n=1):
    for _ in range(n):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    return m


def ellipsoid(cx, cy, rx, ry):
    dx, dy = (XX - cx) / rx, (YY - cy) / ry
    z = np.sqrt(np.clip(1 - dx * dx - dy * dy, 0.03, 1))
    n = np.dstack([dx, dy, z])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def cylinder(a, b, r):
    a, b = np.array(a, float), np.array(b, float)
    ax = (b - a) / np.linalg.norm(b - a)
    px, py = XX - a[0], YY - a[1]
    along = px * ax[0] + py * ax[1]
    ox, oy = px - along * ax[0], py - along * ax[1]
    d = np.sqrt(ox * ox + oy * oy) / r
    z = np.sqrt(np.clip(1 - d * d, 0.03, 1))
    n = np.dstack([ox / r, oy / r, z])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def lit(n, ambient=0.3):
    return np.clip((n @ LIGHT) * (1 - ambient) + ambient, 0, 1)


def side(p0, p1):
    """Which side of the line p0->p1 each pixel lies: > 0 on the left of its direction."""
    return (p1[0] - p0[0]) * (YY - p0[1]) - (p1[1] - p0[1]) * (XX - p0[0])


# ---------------------------------------------------------------- the canvas
class Canvas:
    """One portrait being dressed: her head as painted, her figure, and what's drawn so far."""

    def __init__(self, who, head, labels, folds, skin_tones, regions):
        self.who = who
        self.b = BODIES[who]
        self.rgb = head[..., :3].copy()
        self.alpha = head[..., 3] > 0
        self.labels = labels
        hair = labels == regions.index("hair")
        cx, cy = self.b["chin"]
        # Her head: her face and the hair round it; below the chin only her loose hair.
        self.head = self.alpha & ((YY < self.b["collar_y"] - 8) | (hair & (YY < self.b["collar_y"] + 40)))
        self.head &= ~((YY >= cy) & ~hair & ~poly(self._neck_poly()))
        self.front_hair = self.alpha & hair & (YY >= cy - 2) & ~poly(self.b["face"])
        self.front_rgb = self.rgb.copy()
        # Her figure: the painted bust's outline below the head, less any painted cloth
        # standing above her shoulders (a line from the base of her neck out to each
        # shoulder, a little above it for their curve), like Edda's collar: it would
        # become a stub of whatever she wears. Her own skin there stays.
        painted_cloth = self.alpha & ~hair & (labels != regions.index("skin"))
        self.figure = self.alpha & ~self.head & (YY >= cy - 6) & ~(painted_cloth & self._above_shoulders(4))
        self.creases = self._creases()
        self.skin = np.array(sorted(skin_tones, key=lambda c: lum(c)))
        self.painted_skin = (labels == regions.index("skin")) & self.alpha
        # The side of her neck above her shoulders: no garment covers it (a hood lying
        # down lies behind it); only what goes over her head does.
        self.neck_skin = self.painted_skin & self.figure & self._above_shoulders(4)
        self.torso = ellipsoid(*self.b["torso"])
        (a0, a1), (b0, b1) = self.b["arms"]
        self.arm_n = (cylinder(a0, a1, 24), cylinder(b0, b1, 24))
        self.cover = np.zeros((H, W), bool)       # everything drawn over the skin
        self.pieces = []                          # (mask, darkest colour) for outlines
        self.owner = np.full((H, W), -1)          # which outlined piece shows at each pixel
        self.clear = ~self.head

    def _above_shoulders(self, grace):
        """What lies more than `grace` pixels above the lines from the base of her neck
        out to her shoulders, beside the neck."""
        x0, _, x1, y1 = self.b["neck"]
        (lx, ly), (rx, ry) = self.b["shoulders"]
        left = (XX < x0) & (YY < y1 + (ly - y1) * np.clip((x0 - XX) / max(1, x0 - lx), 0, 1) - grace)
        right = (XX > x1) & (YY < y1 + (ry - y1) * np.clip((XX - x1) / max(1, rx - x1), 0, 1) - grace)
        return left | right

    def _neck_poly(self):
        x0, y0, x1, y1 = self.b["neck"]
        return [(x0, y0 - 6), (x1, y0 - 6), (x1 + 3, y1 + 2), (x0 - 3, y1 + 2)]

    def _creases(self):
        """How cloth folds on her, drawn: soft vertical folds falling from below the bust,
        deepening toward the hem, and creases across the bend of each arm."""
        sx, sy = self.b["sternum"]
        fall = np.clip((YY - sy - 6) / 50.0, 0, 1)
        folds = 0.09 * np.cos((XX - sx) / 4.6 + 0.6 * np.sin(YY / 29.0)) * fall
        folds += 0.04 * np.cos((XX - sx) / 2.1 + 1.3) * fall
        for (a, b2) in self.b["arms"]:
            a, b2 = np.array(a, float), np.array(b2, float)
            ax = (b2 - a) / np.linalg.norm(b2 - a)
            along = (XX - a[0]) * ax[0] + (YY - a[1]) * ax[1]
            across = np.abs((XX - a[0]) * ax[1] - (YY - a[1]) * ax[0])
            near = np.clip(1 - across / 26.0, 0, 1) * np.clip(1 - np.abs(along - 60) / 40.0, 0, 1)
            folds += 0.08 * np.cos(along / 3.2) * near
        return folds

    # The figure's parts, for lighting: each arm beyond its armhole (a line from the
    # shoulder down and in toward the underarm).
    def arms(self):
        sl, sr = self.b["shoulders"]
        left = self.figure & (side(sl, (sl[0] + 14, sl[1] + 70)) > 0) & (YY > sl[1] - 6)
        right = self.figure & (side(sr, (sr[0] - 14, sr[1] + 70)) < 0) & (YY > sr[1] - 6)
        return left, right

    def normals(self, mask_left=None, mask_right=None):
        left, right = self.arms()
        if mask_left is not None:
            left, right = mask_left, mask_right
        n = self.torso.copy()
        n[left] = self.arm_n[0][left]
        n[right] = self.arm_n[1][right]
        return n

    def lay(self, mask, rgb, outline=None, over_head=False):
        """Puts `rgb` (a picture, H x W x 3) down where `mask` is, and remembers the piece."""
        if not over_head:
            mask = mask & ~self.head & ~self.neck_skin
        self.rgb[mask] = rgb[mask]
        self.alpha |= mask
        self.cover |= mask
        if outline is not None:
            self.owner[mask] = len(self.pieces)
            self.pieces.append((mask.copy(), np.array(outline, float)))
        else:
            self.owner[mask] = -2
        return mask

    def cloth(self, mask, ramp, normals=None, folds=0.45, extra=0.0, dither=0.3, outline=True, over_head=False):
        """`mask` in fabric `ramp`, lit as its form and folded as the painted cloth was."""
        n = self.torso if normals is None else normals
        t = lit(n) * 0.78 + 0.08 + self.creases * (folds / 0.45) + extra
        return self.lay(mask, shade(t, ramp, dither), ramp[0] if outline else None, over_head=over_head)


# ---------------------------------------------------------------- her skin
def draw_skin(cv):
    """Her neck, shoulders and chest in her own skin tones, lit as her face is: painted
    where the painting shows skin, drawn where it showed cloth."""
    b = cv.b
    x0, y0, x1, y1 = b["neck"]
    region = ((poly(cv._neck_poly()) | (YY >= y1 - 4)) & cv.figure & ~cv.head) | cv.neck_skin
    ref = lum(cv.rgb[cv.painted_skin & (YY > b["chin"][1] - 4) & (YY < y1 + 6)])
    ref = ref.mean() if ref.size else lum(cv.skin).mean()
    tones = lum(cv.skin)
    base = np.searchsorted(tones, ref) / max(1, len(tones) - 1)
    t = lit(cv.torso) * 0.55
    t = t - t[region].mean() + base + 0.05
    neck_shadow = np.clip(1 - (YY - b["chin"][1]) / 10.0, 0, 1) * (np.abs(XX - b["chin"][0]) < 16) * 0.25
    drawn = region & ~cv.painted_skin
    cv.rgb[drawn] = shade(t - neck_shadow, cv.skin, 0.3)[drawn]
    kept = region & cv.painted_skin
    cv.rgb[kept] = cv.front_rgb[kept]
    cv.alpha |= region
    # Her collarbones, faintly.
    sx, sy = b["sternum"]
    for d in (-1, 1):
        cb = line(curve([(sx + d * 4, y1 + 9), (sx + d * 13, y1 + 10), (sx + d * 24, y1 + 7)], 6), 1) & drawn
        cv.rgb[cb] = cv.skin[max(0, len(cv.skin) // 2 - 1)]


# ---------------------------------------------------------------- necklines
def opening(cv, neckline, depth=1.0):
    """The part of the figure a neckline leaves bare."""
    b = cv.b
    x0, y0, x1, y1 = b["neck"]
    sx, sy = b["sternum"]
    cx = (x0 + x1) / 2.0
    neck = poly(cv._neck_poly())
    if neckline == "high":
        return neck & (YY < y1 - 4)
    if neckline == "square":
        w = (x1 - x0) / 2.0 + 14
        bottom = y1 + 4 + (sy - y1) * 0.55 * depth
        return neck | poly([(cx - w, y1 - 6), (cx + w, y1 - 6), (cx + w, bottom), (cx - w, bottom)])
    if neckline == "v":
        bottom = y1 + (sy - y1 + 6) * depth
        return neck | poly([(x0 - 8, y1 - 6), (x1 + 8, y1 - 6), (cx + 2, bottom)])
    if neckline == "round":
        ry = (sy - y1) * 0.6 * depth + 6
        return neck | ((((XX - cx) / ((x1 - x0) / 2.0 + 12)) ** 2 + ((YY - (y1 - 4)) / ry) ** 2 <= 1) & (YY >= y1 - 8))
    if neckline == "boat":
        return neck | ((((XX - cx) / ((x1 - x0) / 2.0 + 30)) ** 2 + ((YY - (y1 - 4)) / (9 * depth)) ** 2 <= 1) & (YY >= y1 - 8))
    raise KeyError("no neckline called %r" % neckline)


def neck_edge(cv, neckline, depth=1.0):
    """The neckline's edge, as a path round the opening (for trims)."""
    b = cv.b
    x0, y0, x1, y1 = b["neck"]
    sx, sy = b["sternum"]
    cx = (x0 + x1) / 2.0
    if neckline == "square":
        w = (x1 - x0) / 2.0 + 15
        bottom = y1 + 5 + (sy - y1) * 0.55 * depth
        return [(cx - w, y1 - 6), (cx - w, bottom), (cx + w, bottom), (cx + w, y1 - 6)]
    if neckline == "v":
        bottom = y1 + (sy - y1 + 6) * depth + 1
        return [(x0 - 9, y1 - 6), (cx + 2, bottom), (x1 + 9, y1 - 6)]
    if neckline in ("round", "boat"):
        rx = (x1 - x0) / 2.0 + (13 if neckline == "round" else 31)
        ry = ((sy - y1) * 0.6 * depth + 7) if neckline == "round" else 10 * depth
        return [(cx + rx * np.cos(a), (y1 - 4) + ry * np.sin(a)) for a in np.linspace(np.pi, 0, 24)]
    if neckline == "high":
        return [(x0 - 3, y1 - 4), (cx, y1 - 1), (x1 + 3, y1 - 4)]
    return []


# ---------------------------------------------------------------- patterns and trims
MOTIFS = {
    "damask": ["..#..", ".###.", "##.##", ".###.", "..#.."],
    "kiku": [".#.#.", "#####", ".#o#.", "#####", ".#.#."],
    "diamonds": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
}


def pattern(cv, mask, kind, ramp, spacing=8):
    """A woven or embroidered pattern over a piece: its motif one tone lighter (or the
    lightest, for a kiku) than the cloth under it."""
    if kind in (None, "plain"):
        return
    rgb = cv.rgb
    C = np.array(ramp)
    lums = lum(C)
    here = lum(rgb)
    up = np.clip(np.searchsorted(lums, here) + 1, 0, len(C) - 1)
    if kind == "stripes":
        m = mask & ((XX.astype(int) % spacing) == 0)
    elif kind == "checks":
        m = mask & ((((XX // spacing) + (YY // spacing)) % 2) == 0) & (((XX + YY) % 2) == 0)
    elif kind == "dots":
        m = mask & ((XX.astype(int) % spacing) == 2) & ((YY.astype(int) % spacing) == 2)
    else:
        motif = MOTIFS[kind]
        n = len(motif)
        m = np.zeros((H, W), bool)
        centre = np.zeros((H, W), bool)
        off = (YY // (spacing + n) % 2) * ((spacing + n) // 2)
        lx = ((XX + off) % (spacing + n)).astype(int)
        ly = (YY % (spacing + n)).astype(int)
        for j, row in enumerate(motif):
            for i, ch in enumerate(row):
                if ch in "#o":
                    m |= (lx == i) & (ly == j)
                if ch == "o":
                    centre |= (lx == i) & (ly == j)
        m &= mask
        centre &= mask
        if kind == "kiku":
            rgb[m] = C[-1]
            rgb[centre] = hexc(METALS["gold"][2])
            return
    rgb[m] = C[up][m]


def trim(cv, path, spec, width=3, within=None):
    """A band along `path`: braid, dots, diamonds, a plain band, or fur."""
    if not spec or not path:
        return
    kind = spec.get("kind", "braid")
    band = line(path, width + (3 if kind == "fur" else 0))
    if within is not None:
        band &= within
    band &= ~cv.head
    if kind == "fur":
        tuft = np.random.default_rng(len(path)).random((H, W))
        band &= ~(edge(band) & (tuft < 0.45))
        ramp = colours(spec.get("fabric", "fur"))
        cv.lay(band, shade(lit(cv.torso) * 0.6 + 0.3 + (tuft - 0.5) * 0.35, ramp, 0.6), None)
        cv.rgb[edge(band) & (tuft > 0.7)] = ramp[1]
        return
    ramp = colours(spec.get("fabric", "gold"))
    cv.lay(band, shade(lit(cv.torso) * 0.55 + 0.38, ramp, 0.0), None)
    core = line(path, 1) & band
    if kind == "braid":
        cv.rgb[core & (((XX + YY) % 3) == 0)] = ramp[0]
    elif kind == "dots":
        gem = colours(spec.get("gem", "garnet"))
        cv.rgb[core & (((XX + YY) % 4) == 0)] = gem[2]
    elif kind == "diamonds":
        cv.rgb[core & (((XX + YY) % 4) == 0)] = ramp[-1]
        cv.rgb[core & (((XX + YY) % 4) == 2)] = ramp[0]
        cv.rgb[edge(band)] = ramp[0]


# ---------------------------------------------------------------- garments
def sleeves(cv, mask):
    """The arms of a garment that covers `mask`, and the bodice."""
    left, right = cv.arms()
    return mask & left, mask & right


def draw_chemise(cv, p):
    ramp = colours(p.get("fabric", "linen"))
    m = cv.figure & ~opening(cv, p.get("neckline", "round"), p.get("depth", 1.0))
    pleats = 0.06 * np.cos((XX - cv.b["sternum"][0]) * 1.4) * np.clip((YY - cv.b["collar_y"]) / 20.0, 0, 1)
    cv.cloth(m, ramp, cv.normals(), folds=0.25, extra=0.04 + pleats)


def draw_gown(cv, p):
    ramp = colours(p.get("fabric", "woad"))
    neckline = p.get("neckline", "square")
    figure = cv.figure.copy()
    style = p.get("sleeves", "fitted")
    (l0, l1), (r0, r1) = cv.b["arms"]
    if style == "flared":
        # Bell sleeves, widening from the elbow: past the painted arm.
        for (a, b2), sgn in (((l0, l1), -1), ((r0, r1), 1)):
            figure |= poly([(a[0] + sgn * 4, 200), (b2[0] + sgn * 14, 256), (b2[0] - sgn * 10, 256), (a[0] - sgn * 6, 200)])
    m = figure & ~opening(cv, neckline, p.get("depth", 1.0))
    left, right = cv.arms()
    left |= m & (XX < cv.b["shoulders"][0][0] - 2) & (YY > 200)
    right |= m & (XX > cv.b["shoulders"][1][0] + 2) & (YY > 200)
    cv.cloth(m, ramp, cv.normals(left, right), folds=0.35)
    pattern(cv, m, p.get("pattern"), ramp, p.get("spacing", 8))
    # Seams: the armholes, darker.
    for s in (left & m, right & m):
        seam = edge(s) & m & ~edge(m)
        cv.rgb[seam] = ramp[0]
    if style == "flared":
        lining = colours(p.get("lining", "linen"))
        for (a, b2), sgn in (((l0, l1), -1), ((r0, r1), 1)):
            cuff = poly([(b2[0] + sgn * 13, 250), (b2[0] + sgn * 14, 256), (b2[0] - sgn * 10, 256), (b2[0] - sgn * 9, 250)]) & m
            cv.lay(cuff, shade(lit(cv.torso) * 0.5 + 0.3, lining, 0.0), lining[0])
    if style == "hanging":
        # Long sleeves open from the elbow, hanging behind the arm: the outer cloth shows
        # beside the arm, its lining a line down its inner edge.
        lining = colours(p.get("lining", "linen"))
        for (a, b2), sgn in (((l0, l1), -1), ((r0, r1), 1)):
            top = (a[0] + sgn * 2, 186)
            strip = poly([(top[0] - 4, top[1]), (top[0] + 4, top[1]), (b2[0] + sgn * 14, 256), (b2[0] - sgn * 2, 256)])
            strip &= ~(m & ~edge(m))
            cv.cloth(strip, ramp, cv.arm_n[0 if sgn < 0 else 1], folds=0.1, extra=-0.08)
            ln = line([(top[0] + sgn * 2, top[1] + 4), (b2[0] + sgn * 12, 256)], 1) & strip
            cv.rgb[ln] = lining[2]
    trim(cv, neck_edge(cv, neckline, p.get("depth", 1.0)), p.get("trim"), within=grow(m, 2))
    if p.get("lacing"):
        sx, sy = cv.b["sternum"]
        x0, y0, x1, y1 = cv.b["neck"]
        top = y1 + 5 + (sy - y1) * 0.55 if neckline == "square" else sy + 4
        lace = colours(p.get("lacing"))
        for y in range(int(top) + 3, cv.b["waist"] - 6, 5):
            cv.rgb[line([(sx - 3, y), (sx + 3, y + 3)], 1) & m] = lace[-2]
            cv.rgb[line([(sx + 3, y), (sx - 3, y + 3)], 1) & m] = lace[-3]


def lapels(cv, top_gap, bottom_gap, top_y=None):
    """The two front edges of an open garment, from beside the neck to the hem."""
    x0, y0, x1, y1 = cv.b["neck"]
    sx, _ = cv.b["sternum"]
    ty = (y1 - 2) if top_y is None else top_y
    return ([(sx - top_gap, ty), (sx - bottom_gap, H)], [(sx + top_gap, ty), (sx + bottom_gap, H)])


def draw_coat(cv, p):
    ramp = colours(p.get("fabric", "indigo"))
    gap_top, gap_bottom = p.get("open", (16, 26))
    (lt, lb), (rt, rb) = lapels(cv, gap_top, gap_bottom)
    front = (side(lt, lb) < 0) & (side(rt, rb) > 0) & (YY > lt[1] - 4)
    figure = cv.figure.copy()
    m = figure & ~front & ~(poly(cv._neck_poly()) & (YY < cv.b["collar_y"] - 2))
    left, right = cv.arms()
    cv.cloth(m, ramp, cv.normals(left, right), folds=0.45)
    pattern(cv, m, p.get("pattern"), ramp, p.get("spacing", 8))
    if p.get("lining"):
        lining = colours(p["lining"])
        for a, b2 in ((lt, lb), (rt, rb)):
            ln = line([a, b2], 2) & m
            cv.lay(ln, shade(lit(cv.torso) * 0.5 + 0.2, lining, 0.0))
    for a, b2 in ((lt, lb), (rt, rb)):
        trim(cv, [a, b2], p.get("trim"), width=p.get("trim_width", 4), within=grow(m, 3))
    # A standing collar round the back of the neck.
    x0, y0, x1, y1 = cv.b["neck"]
    collar = poly([(x0 - 6, y1 - 7), (x1 + 6, y1 - 7), (x1 + 8, y1 + 1), (x0 - 8, y1 + 1)]) & ~front & cv.figure
    cv.cloth(collar, ramp, folds=0.2, extra=0.05)


def draw_jacket(cv, p):
    """A short open jacket (a haori): wide bands down its front edges."""
    q = dict(p)
    q.setdefault("open", (12, 34))
    q.setdefault("fabric", "charcoal")
    q.setdefault("trim_width", 6)
    if "trim" not in q:
        q["trim"] = {"kind": "band", "fabric": "black"}
    draw_coat(cv, q)


def draw_wrap(cv, p):
    """A robe crossed at the throat, left over right, its collars layered."""
    ramp = colours(p.get("fabric", "charcoal"))
    x0, y0, x1, y1 = cv.b["neck"]
    sx, sy = cv.b["sternum"]
    cross = (sx + 4, sy + 6)
    m = cv.figure & ~(poly(cv._neck_poly()) & (YY < y1 - 2))
    left, right = cv.arms()
    cv.cloth(m, ramp, cv.normals(left, right), folds=0.45)
    pattern(cv, m, p.get("pattern"), ramp, p.get("spacing", 10))
    # The collars: broad bands from behind the neck to where they cross, the wearer's left
    # over her right; the inner collars show as narrower bands above the outer one.
    layers = p.get("collar", ["white", "crimson", "white"])
    total = 12
    for i, c in enumerate(layers):
        r = colours(c)
        w = max(2, total - 3 * i)
        under = line([(x1 + 3 - i, y1 - 9), cross], w)                       # her right, beneath
        over = line([(x0 - 3 + i, y1 - 9), (cross[0] + 8, cross[1] + 14)], w)   # her left, on top
        band = (under | over) & (YY >= y1 - 10) & (cv.figure | poly(cv._neck_poly()))
        cv.lay(band, shade(lit(cv.torso) * 0.45 + 0.4, r, 0.0), None)
        cv.rgb[edge(band) & ~edge(cv.figure) & (cv.owner == -2)] = r[1]
    trim(cv, [(x0 - 3, y1 - 9), (cross[0] + 8, cross[1] + 14)], p.get("trim"), width=2)


def draw_mantle(cv, p):
    """A cape on her shoulders, open in front, hanging over her arms to `length`: it follows
    the figure's own outline (a little outside it), its hem curving up to the opening."""
    ramp = colours(p.get("fabric", "forest"))
    x0, y0, x1, y1 = cv.b["neck"]
    sl, sr = cv.b["shoulders"]
    sx = cv.b["sternum"][0]
    length = {"short": 190, "medium": 214, "long": 236}.get(p.get("length", "medium"), 214)
    gap_top, gap_bottom = 6, 26
    (lt, lb), (rt, rb) = ((sx - (x1 - x0) / 2 - gap_top, y1 - 4), (sx - gap_bottom, length)), \
        ((sx + (x1 - x0) / 2 + gap_top, y1 - 4), (sx + gap_bottom, length))
    front = (side(lt, lb) < 0) & (side(rt, rb) > 0)
    hem = length - 14 * np.clip(1 - np.abs(XX - sx) / 70.0, 0, 1) ** 2
    body = grow(cv.figure, 2) | (poly(cv._neck_poly()) & (YY >= y1 - 9))
    m = body & ~front & (YY >= y1 - 9) & (YY <= hem) & ~cv.head
    cape = ellipsoid(sx, 180, 112, 104)
    swing = np.abs(XX - sx) - 30
    drape = (0.14 * np.cos(swing / 3.4) + 0.06 * np.cos(swing / 1.6 + 1.0)) * np.clip((YY - sl[1]) / 26, 0, 1)
    cv.cloth(m, ramp, cape, folds=0.15, extra=drape - 0.02)
    if p.get("fur"):
        fur_l = curve([(lt[0] + 1, y1 - 7), (sl[0] + 14, sl[1] - 8), (sl[0] - 6, sl[1] + 2), (sl[0] - 16, sl[1] + 22)], 6)
        for path in (fur_l, [((x0 + x1) - x, y) for x, y in fur_l]):
            trim(cv, path, {"kind": "fur", "fabric": p["fur"] if isinstance(p["fur"], str) else "fur"}, width=4)
    if p.get("trim"):
        hem_line = [(x, hem[0, int(np.clip(x, 0, W - 1))]) for x in np.linspace(0, W - 1, 48)]
        trim(cv, hem_line, p["trim"], width=2, within=grow(m, 1) & (YY > hem - 3))
        for a, b2 in ((lt, lb), (rt, rb)):
            trim(cv, [a, b2], p["trim"], width=2, within=grow(m, 1))
    if p.get("clasp"):
        cy = y1 + 2
        metal = colours(p["clasp"])
        chain = line([(lt[0] + 2, cy), (rt[0] - 2, cy)], 1) & ~cv.head
        cv.rgb[chain] = metal[2]
        cv.alpha |= chain
        for x in (lt[0] + 1, rt[0] - 1):
            boss = disc(x, cy, 2.6)
            cv.lay(boss, shade(lit(ellipsoid(x, cy, 3, 3)) + 0.1, metal, 0.0), metal[0])


def draw_cloak(cv, p):
    ramp = colours(p.get("fabric", "brown"))
    x0, y0, x1, y1 = cv.b["neck"]
    sx, sy = cv.b["sternum"]
    (sl, sr) = cv.b["shoulders"]
    gap_top, gap_bottom = 10, 34
    left = [(x0 - 2, y1 - 8), (sl[0] + 6, sl[1] - 12), (sl[0] - 22, sl[1] + 4), (sl[0] - 36, H), (sx - gap_bottom, H),
            (sx - gap_top, y1 + 10)]
    right = [((x0 + x1) - x, y) for x, y in left]
    m = (poly(left) | poly(right)) & (YY >= y1 - 10) & ~cv.head
    cape = ellipsoid(sx, 180, 110, 110)
    swing = np.abs(XX - sx) - 24
    drape = (0.14 * np.cos(swing / 4.2) + 0.06 * np.cos(swing / 2.0 + 0.7)) * np.clip((YY - sl[1]) / 40, 0, 1)
    cv.cloth(m, ramp, cape, folds=0.0, extra=drape - 0.04)
    if p.get("lining"):
        lining = colours(p["lining"])
        for a, b2 in (((sx - gap_top, y1 + 10), (sx - gap_bottom, H)), ((sx + gap_top, y1 + 10), (sx + gap_bottom, H))):
            ln = line([a, b2], 2) & m
            cv.lay(ln, shade(lit(cv.torso) * 0.5 + 0.2, lining, 0.0))
    if p.get("fur"):
        fur_l = curve([(x0 - 4, y1 - 8), (sl[0] + 8, sl[1] - 10), (sl[0] - 18, sl[1] + 6)], 6)
        for path in (fur_l, [((x0 + x1) - x, y) for x, y in fur_l]):
            trim(cv, path, {"kind": "fur", "fabric": p["fur"] if isinstance(p["fur"], str) else "fur"}, width=4)
    if p.get("clasp"):
        draw_brooch(cv, {"metal": p["clasp"], "gem": p.get("gem"), "at": "throat", "size": 3.2})
    if p.get("hood") == "down":
        x0, y0, x1, y1 = cv.b["neck"]
        hood = poly(curve([(x0 - 12, y1 - 8), (x0 - 4, y1 - 14), (x1 + 4, y1 - 14), (x1 + 12, y1 - 8), (x1 + 6, y1 + 2),
                           (x0 - 6, y1 + 2)], 5)) & ~poly(cv._neck_poly())
        cv.cloth(hood, ramp, cape, folds=0.0, extra=0.06)


def head_cover(cv, inner=2, outer=5, down=34):
    """What a hood or scarf covers: her head's outline, a little bigger, down past her neck,
    all but her face."""
    hx, hy, rx, ry = cv.b["head"]
    over = (((XX - hx) / (rx + outer)) ** 2 + ((YY - hy) / (ry + outer)) ** 2 <= 1) | \
        poly([(hx - rx - outer, hy), (hx + rx + outer, hy), (hx + rx + outer - 6, cv.b["collar_y"] + down),
              (hx - rx - outer + 6, cv.b["collar_y"] + down)])
    face = poly(cv.b["face"])
    face = grow(face, 1) if inner > 1 else face
    return over & ~face


def draw_hood(cv, p, lighter=0.0):
    """A hood up over her hair: round over her head, opening round her face, its cowl
    falling onto her shoulders; darker inside, where the face sits back in it."""
    ramp = colours(p.get("fabric", "brown"))
    hx, hy, rx, ry = cv.b["head"]
    face = poly(cv.b["face"])
    dome = ((XX - hx) / (rx + 5 - 2 * (lighter > 0))) ** 2 + ((YY - (hy - 2)) / (ry + 6 - 2 * (lighter > 0))) ** 2 <= 1
    sl, sr = cv.b["shoulders"]
    cy = cv.b["collar_y"]
    cowl = poly(curve([(hx - rx - 4, hy + 6), (hx - rx - 2, cy - 6), (sl[0] + 4, sl[1] + 2), (sl[0] + 26, sl[1] + 12),
                       (hx, cy + 16), (sr[0] - 26, sr[1] + 12), (sr[0] - 4, sr[1] + 2), (hx + rx + 2, cy - 6),
                       (hx + rx + 4, hy + 6)], 5))
    m = (dome | cowl) & ~face
    n = ellipsoid(hx - 6, hy + 30, rx + 30, ry + 60)
    inside = grow(face, 3) & ~face
    deep = np.clip(1 - (np.hypot(XX - hx, YY - hy) - 30) / 30, 0, 1) * 0.0
    t_extra = np.where(inside, -0.35, 0.0) + deep + lighter
    cv.cloth(m, ramp, n, folds=0.0, extra=t_extra, over_head=True)
    cv.rgb[edge(grow(face, 1)) & m] = ramp[0]
    # The hood's own fold over the crown.
    crease = line(curve([(hx - 6, hy - ry - 2), (hx - 2, hy - ry + 10), (hx - 8, hy - ry + 22)], 5), 1) & m & ~inside
    cv.rgb[crease] = ramp[1]
    if p.get("fur"):
        trim(cv, cv.b["face"] + [cv.b["face"][0]], {"kind": "fur", "fabric": p["fur"]}, width=2,
             within=grow(m, 2) & ~poly(cv.b["face"]))


def draw_scarf(cv, p):
    """A scarf wrapped over her hair and round her neck, her face open: the hood's shape,
    in a lighter cloth, patterned and edged."""
    q = dict(p)
    q.setdefault("fabric", "sand")
    draw_hood(cv, q, lighter=0.12)
    m = cv.owner == len(cv.pieces) - 1
    pattern(cv, m, p.get("pattern"), colours(q["fabric"]), p.get("spacing", 7))
    if p.get("trim"):
        face = poly(cv.b["face"])
        rim = edge(grow(face, 2)) & m
        t = colours(p["trim"].get("fabric", "gold"))
        cv.rgb[rim] = t[2]


def draw_sash(cv, p):
    ramp = colours(p.get("fabric", "crimson"))
    width = p.get("width", 12)
    y = cv.b["waist"] - width // 2
    band = poly([(0, y - width // 2), (W, y - width // 2 - 2), (W, y + width // 2 - 2), (0, y + width // 2)]) & cv.figure
    left, right = cv.arms()
    band &= ~left & ~right
    cv.cloth(band, ramp, folds=0.15, extra=0.04)
    for k in range(1, max(2, width // 5)):
        fold = line([(0, y - width // 2 + k * 5), (W, y - width // 2 + k * 5 - 2)], 1) & band
        cv.rgb[fold] = ramp[1]
    pattern(cv, band, p.get("pattern"), ramp, p.get("spacing", 6))
    if p.get("cord"):
        c = colours(p["cord"])
        cord = line([(0, y), (W, y - 2)], 1) & band
        cv.rgb[cord] = c[2]
    if p.get("knot"):
        sx = cv.b["sternum"][0] + 14
        knot = disc(sx, y, width * 0.35) | poly([(sx - 2, y), (sx + 2, y), (sx + 6, y + width + 8), (sx - 1, y + width + 6)])
        knot &= ~left & ~right & ~cv.head
        cv.cloth(knot & (YY < H), ramp, ellipsoid(sx, y, width, width), folds=0.0, extra=0.05)


def draw_belt(cv, p):
    ramp = colours(p.get("fabric", "leather"))
    y = cv.b["waist"]
    band = poly([(0, y - 3), (W, y - 5), (W, y + 1), (0, y + 3)]) & cv.figure
    left, right = cv.arms()
    band &= ~left & ~right
    cv.cloth(band, ramp, folds=0.1, extra=0.05)
    metal = colours(p.get("buckle", "bronze"))
    bx = cv.b["sternum"][0] - 6
    buckle = poly([(bx - 4, y - 5), (bx + 4, y - 6), (bx + 4, y + 2), (bx - 4, y + 3)]) & ~poly([(bx - 2, y - 3), (bx + 2, y - 4), (bx + 2, y), (bx - 2, y + 1)])
    cv.lay(buckle & cv.figure, shade(lit(cv.torso) + 0.15, metal, 0.0), metal[0])


# ---------------------------------------------------------------- jewellery
def gem(cv, cx, cy, r, name):
    g = disc(cx, cy, r)
    ramp = colours(name)
    cv.lay(g, shade(lit(ellipsoid(cx, cy, r + 0.4, r + 0.4)) + 0.05, ramp, 0.0), None, over_head=True)
    cv.rgb[disc(cx - r * 0.35, cy - r * 0.35, max(0.6, r * 0.3)) & g] = ramp[-1]


def draw_necklace(cv, p):
    kind = p.get("kind", "chain")
    metal = colours(p.get("metal", "gold"))
    x0, y0, x1, y1 = cv.b["neck"]
    sx = (x0 + x1) / 2.0
    drop = {"chain": 16, "pearls": 12, "coins": 13, "beads": 10}.get(kind, 14) + p.get("drop", 0)
    path = curve([(x0 + 1, y1 - 4), (sx - 6, y1 + drop - 4), (sx, y1 + drop), (sx + 6, y1 + drop - 4), (x1 - 1, y1 - 4)], 8)
    if kind == "chain":
        ch = line(path, 1) & ~cv.head
        cv.rgb[ch] = metal[2]
        cv.rgb[ch & (((XX + YY) % 2) == 0)] = metal[1]
        cv.alpha |= ch
        if p.get("gem"):
            gem(cv, sx, y1 + drop + 3, 2.4, p["gem"])
            cv.rgb[edge(disc(sx, y1 + drop + 3, 2.6))] = metal[1]
    elif kind in ("pearls", "beads"):
        ramp = colours(p.get("gem", "pearl" if kind == "pearls" else "coral"))
        for i in range(0, len(path), 3):
            x, y = path[i]
            g = disc(x, y, 1.2) & ~cv.head
            cv.lay(g, shade(lit(ellipsoid(x, y, 1.6, 1.6)) + 0.1, ramp, 0.0))
    elif kind == "coins":
        ch = line(path, 1) & ~cv.head
        cv.rgb[ch] = metal[1]
        cv.alpha |= ch
        for i in range(2, len(path) - 2, 4):
            x, y = path[i]
            c = disc(x, y + 2.5, 1.8) & ~cv.head
            cv.lay(c, shade(lit(ellipsoid(x, y + 2.5, 2, 2)) + 0.15, metal, 0.0), metal[0])
        if p.get("gem"):
            gem(cv, sx, y1 + drop + 5, 2.2, p["gem"])


def draw_choker(cv, p):
    ramp = colours(p.get("fabric", "black"))
    x0, y0, x1, y1 = cv.b["neck"]
    y = y1 - 9
    band = poly([(x0 - 1, y - 1), (x1 + 1, y - 2), (x1 + 1, y + 1), (x0 - 1, y + 2)])
    cv.lay(band, shade(lit(cv.torso) * 0.5 + 0.3, ramp, 0.0), ramp[0], over_head=True)
    if p.get("gem"):
        gem(cv, (x0 + x1) / 2.0, y + 3, 1.8, p["gem"])


def draw_brooch(cv, p):
    metal = colours(p.get("metal", "bronze"))
    x0, y0, x1, y1 = cv.b["neck"]
    sx, sy = cv.b["sternum"]
    at = p.get("at", "chest")
    cx, cy = ((x0 + x1) / 2.0, y1 + 2) if at == "throat" else (sx, sy - 8)
    r = p.get("size", 3.4)
    ring = disc(cx, cy, r)
    cv.lay(ring, shade(lit(ellipsoid(cx, cy, r + 0.5, r + 0.5)) + 0.1, metal, 0.0), metal[0], over_head=True)
    cv.rgb[disc(cx, cy, r - 1.4)] = metal[1]
    if p.get("gem"):
        gem(cv, cx, cy, max(1.0, r - 1.8), p["gem"])


def draw_earrings(cv, p):
    metal = colours(p.get("metal", "gold"))
    for (ex, ey) in cv.b["ears"]:
        hook = line([(ex, ey), (ex, ey + 3)], 1)
        cv.rgb[hook] = metal[2]
        if p.get("gem"):
            gem(cv, ex, ey + 4.5, 1.6, p["gem"])
        else:
            cv.rgb[disc(ex, ey + 4.5, 1.4)] = metal[2]


def draw_circlet(cv, p):
    metal = colours(p.get("metal", "gold"))
    arc = curve(cv.b["hairline"], 8)
    band = line(arc, 1) & cv.alpha
    cv.rgb[band] = metal[2]
    under = np.roll(band, 1, 0) & cv.alpha & ~band
    cv.rgb[under] = metal[0]
    hx = cv.b["hairline"][2]
    if p.get("coins"):
        for i in range(2, len(arc) - 2, 5):
            x, y = arc[i]
            c = disc(x, y + 2.5, 1.5)
            cv.rgb[c] = metal[2]
            cv.rgb[c & (YY > y + 2.5)] = metal[1]
    if p.get("gem"):
        gem(cv, hx[0], hx[1], 1.8 if not p.get("coins") else 2.2, p["gem"])


def draw_comb(cv, p):
    metal = colours(p.get("metal", "gold"))
    bx, by = cv.b["bun"]
    spine = curve([(bx - 12, by - 8), (bx - 6, by - 13), (bx + 2, by - 15), (bx + 8, by - 13)], 6)
    for i in range(1, len(spine) - 1, 2):
        x, y = spine[i]
        cv.rgb[line([(x, y), (x + 1.5, y + 3.5)], 1) & cv.alpha] = metal[1]
    s = line(spine, 2) & cv.alpha
    cv.rgb[s] = metal[1]
    cv.rgb[line(spine, 1) & s] = metal[2]
    cv.rgb[line([(x - 0.6, y - 0.8) for x, y in spine[2:-2]], 1) & s] = metal[3]


def draw_pin(cv, p):
    metal = colours(p.get("metal", "gold"))
    bx, by = cv.b["bun"]
    stick = line([(bx - 10, by + 4), (bx + 12, by - 6)], 1)
    cv.lay(stick, np.broadcast_to(metal[1], (H, W, 3)), None, over_head=True)
    head_x, head_y = bx + 12, by - 6
    if p.get("gem"):
        gem(cv, head_x, head_y, 2.2, p["gem"])
    else:
        cv.lay(disc(head_x, head_y, 2.0), np.broadcast_to(metal[2], (H, W, 3)), metal[0], over_head=True)
    if p.get("dangle"):
        d = colours(p["dangle"])
        for k in range(3):
            cv.lay(disc(head_x + 1, head_y + 4 + k * 3, 0.9), np.broadcast_to(d[2], (H, W, 3)), None, over_head=True)


def draw_flowers(cv, p):
    cols = p.get("colours", ["ffffff", "f0c8d0"])
    centre = colours(p.get("centre", "gold"))
    at = cv.b["bun"] if p.get("at", "bun") == "bun" else cv.b["hairline"][-1]
    spots = [(0, 0), (-5, 3), (4, 4), (-2, -5), (6, -3)][:p.get("count", 3)]
    for i, (dx, dy) in enumerate(spots):
        x, y = at[0] + dx, at[1] + dy
        petal = hexc(cols[i % len(cols)])
        shadow = petal * 0.72
        for ox, oy in ((0, -1.5), (1.5, 0), (0, 1.5), (-1.5, 0)):
            cv.lay(disc(x + ox, y + oy, 1.3), np.broadcast_to(petal, (H, W, 3)), None, over_head=True)
        cv.rgb[disc(x + 1.2, y + 1.2, 0.8)] = shadow
        cv.rgb[disc(x, y, 0.8)] = centre[2]


def draw_veil(cv, p):
    """A sheer veil over her hair, falling behind her shoulders; her face open. Over her
    hair it's a faint film; where it falls clear of her it shows on the night."""
    ramp = colours(p.get("fabric", "white"))
    hx, hy, rx, ry = cv.b["head"]
    sl, sr = cv.b["shoulders"]
    over = (((XX - hx) / (rx + 6)) ** 2 + ((YY - (hy - 4)) / (ry + 5)) ** 2 <= 1) & (YY < hy + 6)
    fall = poly([(hx - rx - 6, hy), (hx + rx + 6, hy), (hx + rx + 16, sr[1] + 24), (hx - rx - 16, sl[1] + 24)])
    m = (over | fall) & ~poly(cv.b["face"])
    a = float(p.get("alpha", 0.45))
    veil = shade(lit(ellipsoid(hx, hy, rx + 20, ry + 50)) * 0.6 + 0.35, ramp, 0.0)
    on_hair = m & cv.alpha & cv.head
    cv.rgb[on_hair] = cv.rgb[on_hair] * (1 - a * 0.18) + veil[on_hair] * a * 0.18
    behind = m & ~cv.alpha
    cv.rgb[behind] = veil[behind]
    cv.sheer = getattr(cv, "sheer", np.zeros((H, W), bool)) | behind
    cv.alpha |= behind
    if p.get("trim"):
        edge_path = [(hx - rx - 16, sl[1] + 24), (hx - rx - 6, hy), (hx - rx + 2, hy - ry + 4),
                     (hx, hy - ry - 4), (hx + rx - 2, hy - ry + 4), (hx + rx + 6, hy), (hx + rx + 16, sr[1] + 24)]
        rim = line(curve(edge_path, 6), 1) & (behind | on_hair)
        t = colours(p["trim"].get("fabric", "gold") if isinstance(p["trim"], dict) else p["trim"])
        cv.rgb[rim] = t[2]
        cv.sheer &= ~rim
        cv.alpha |= rim


def draw_layer(cv, p, layers_dir):
    """A hand-drawn piece: assets/portraits/rig/<who>/layers/<name>.png (192x256). With
    `dye`, its greys are dyed along that ramp by their lightness; without, it's laid as
    drawn. Either way it's outlined where it meets her other clothes (in the dye's
    darkest tone, or the drawing's own darkest), unless `"outline": false`. With
    `"over_hair": true` it goes over her loose hair, like a veil."""
    path = os.path.join(layers_dir, "%s.png" % p["name"])
    img = np.array(Image.open(path).convert("RGBA").resize((W, H), Image.NEAREST)).astype(float)
    m = img[..., 3] >= 128
    if not m.any():
        return
    over = p.get("over_hair", False)
    if p.get("dye"):
        ramp = colours(p["dye"])
        t = lum(img[..., :3]) / 255.0
        rgb, dark = shade(t, ramp, p.get("dither", 0.0)), ramp[0]
    else:
        rgb = img[..., :3]
        drawn = rgb[m]
        dark = drawn[np.argmin(lum(drawn))] * 0.6
    cv.lay(m, rgb, dark if p.get("outline", True) else None, over_head=over)


DRAW = {
    "chemise": draw_chemise, "gown": draw_gown, "coat": draw_coat, "jacket": draw_jacket, "wrap": draw_wrap,
    "mantle": draw_mantle, "cloak": draw_cloak, "sash": draw_sash, "belt": draw_belt,
    "necklace": draw_necklace, "choker": draw_choker, "brooch": draw_brooch, "earrings": draw_earrings,
    "circlet": draw_circlet, "comb": draw_comb, "pin": draw_pin, "flowers": draw_flowers,
    "veil": draw_veil, "scarf": draw_scarf, "hood": draw_hood,
}
# What goes over her loose hair (a hood, a scarf, a veil, the hair's own ornaments).
OVER_HAIR = {"veil", "scarf", "hood", "circlet", "comb", "pin", "flowers", "earrings"}


# ---------------------------------------------------------------- dressing
def dress(who, head, labels, folds, skin_tones, regions, pieces, layers_dir=None):
    """Her head (the rig's pixel art of it, H x W x 4 on the grid) dressed in `pieces`.
    Returns the picture on the grid, H x W x 4."""
    cv = Canvas(who, head, labels, folds, skin_tones, regions)
    # What the painting wore is gone: below her head, only her loose hair stays.
    gone = cv.alpha & ~cv.head
    cv.rgb[gone] = 0
    cv.alpha &= cv.head
    cv.alpha |= cv.figure
    draw_skin(cv)
    hair_over = []
    for p in pieces:
        kind = p.get("piece") if "piece" in p else ("layer" if "name" in p else None)
        if kind in OVER_HAIR or (kind == "layer" and p.get("over_hair")):
            hair_over.append((kind, p))
            continue
        if kind == "layer":
            draw_layer(cv, p, layers_dir)
        else:
            DRAW[kind](cv, p)
    # Her loose hair in front of her clothes.
    cv.rgb[cv.front_hair] = cv.front_rgb[cv.front_hair]
    cv.alpha |= cv.front_hair
    for kind, p in hair_over:
        if kind == "layer":
            draw_layer(cv, p, layers_dir)
        else:
            DRAW[kind](cv, p)
    # Outlines: each piece against the next, the figure against the night.
    for i, (m, dark) in enumerate(cv.pieces):
        e = edge(m) & ~cv.head & cv.alpha & (cv.owner == i)
        cv.rgb[e] = np.minimum(cv.rgb[e], dark)
    rim = edge(cv.alpha) & ~cv.head & ~getattr(cv, "sheer", np.zeros((H, W), bool))
    cv.rgb[rim] = OUTLINE
    out = np.dstack([cv.rgb, np.where(cv.alpha, 255.0, 0.0)])
    if hasattr(cv, "sheer"):
        out[cv.sheer, 3] = 255.0 * 0.55
    return out


def template(who, head, labels, skin_tones, regions):
    """Her head as the game draws it, her figure in shaded grey, and marks where the
    wardrobe fits its pieces: a guide to draw a piece of her own over (layers/<name>.png)."""
    cv = Canvas(who, head, labels, None, skin_tones, regions)
    gone = cv.alpha & ~cv.head
    cv.rgb[gone] = 0
    cv.alpha &= cv.head
    figure = cv.figure
    grey = np.array([[70, 70, 74], [110, 110, 116], [150, 150, 156], [190, 190, 196]], float)
    cv.rgb[figure] = shade(lit(cv.torso), grey, 0.0)[figure]
    cv.alpha |= figure
    cv.rgb[cv.front_hair] = cv.front_rgb[cv.front_hair]
    b = cv.b
    def mark(x, y, colour, r=1.2):
        m = disc(x, y, r)
        cv.rgb[m] = colour
        cv.alpha |= m
    x0, y0, x1, y1 = b["neck"]
    for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        mark(x, y, (255, 255, 255))
    for x, y in b["shoulders"]:
        mark(x, y, (255, 40, 40), 1.6)
    mark(*b["sternum"], (40, 90, 255), 1.6)
    waist = line([(0, b["waist"]), (W, b["waist"])], 1) & figure
    cv.rgb[waist] = (0, 220, 220)
    for x, y in b["ears"]:
        mark(x, y, (40, 220, 60))
    hl = line(curve(b["hairline"], 6), 1) & cv.alpha
    cv.rgb[hl] = (255, 220, 0)
    mark(*b["bun"], (255, 0, 220), 1.6)
    return np.dstack([cv.rgb, np.where(cv.alpha, 255.0, 0.0)])

