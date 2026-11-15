"""Drawing surface for the romance portraits (192x256, shown at 768x1024).

The same way of drawing as the lords' kit (tools/pixel_kit): every pixel records a material
(skin, hair, a cloth, gold...) and a shade 0-4 (light to dark; 5 is the outline), parts are
outlined where they lie over what's behind them, and light falls from the upper left. Here
the grid is 1.6 times the lords', so there is room for more: lashes and lids, shaded lips,
finer locks of hair, more folds and patterns in the cloth.
"""
import math
import os

import numpy as np

import importlib.util

# The lords' colours (skins, hairs, eyes, gold, linen...), loaded by path: the two kits
# have modules of the same names.
_spec = importlib.util.spec_from_file_location(
    "lord_palettes", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pixel_kit", "palettes.py"))
LORDS = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(LORDS)

W, H = 192, 256
YY, XX = np.mgrid[0:H, 0:W]
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
LINE = 5
NO_LINE = 1          # flag: this pixel never takes an outline (jewellery, features)

_MATS = ["none"]


def mat_id(name):
    if name not in _MATS:
        _MATS.append(name)
    return _MATS.index(name)


def mat_name(i):
    return _MATS[i]


class Canvas:
    """One layer of a portrait: what lies in front of the layers before it."""

    def __init__(self):
        self.mat = np.zeros((H, W), np.int16)
        self.tone = np.zeros((H, W), np.uint8)
        self.flag = np.zeros((H, W), np.uint8)
        self.part = np.zeros((H, W), np.int32)
        self.on = np.zeros((H, W), bool)
        self.lined = {}
        self.nparts = 0

    def new_part(self, line=True):
        self.nparts += 1
        self.lined[self.nparts] = line
        return self.nparts

    def put(self, mask, mat, tone, part=None, flag=None):
        mask = np.asarray(mask, bool)
        self.mat[mask] = mat_id(mat)
        t = np.asarray(tone)
        self.tone[mask] = t[mask] if t.ndim else int(t)
        self.on |= mask
        if part is not None:
            self.part[mask] = part
            self.flag[mask] = 0 if self.lined.get(part, True) else NO_LINE
        if flag is not None:
            self.flag[mask] = flag

    def px(self, x, y, mat, tone, part=None, flag=None):
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if 0 <= x < W and 0 <= y < H:
            self.mat[y, x] = mat_id(mat)
            self.tone[y, x] = tone
            self.on[y, x] = True
            if part is not None:
                self.part[y, x] = part
                self.flag[y, x] = 0 if self.lined.get(part, True) else NO_LINE
            if flag is not None:
                self.flag[y, x] = flag

    def shade(self, mask, by):
        """Darken (by > 0) or lighten what's drawn in `mask` by that many shades."""
        m = np.asarray(mask, bool) & self.on & (self.tone < LINE)
        self.tone[m] = np.clip(self.tone[m].astype(int) + by, 0, 4)

    def erase(self, mask):
        self.on[mask] = False
        self.mat[mask] = 0
        self.part[mask] = 0

    def moved(self, dy):
        """This layer set `dy` pixels lower."""
        out = Canvas()
        out.mat = shift(self.mat, dy, 0, 0); out.tone = shift(self.tone, dy, 0, 0); out.flag = shift(self.flag, dy, 0, 0)
        out.part = shift(self.part, dy, 0, 0); out.on = shift(self.on, dy, 0, False)
        out.lined, out.nparts = dict(self.lined), self.nparts
        return out

    def warped(self, rows=None, cols=None):
        """This layer with each row slid sideways by rows[y] pixels and each column slid down
        by cols[x]: whole pixels move together, so nothing is redrawn or blurred. A pose is
        made of these (a head leaning on its neck, a shoulder let down)."""
        out = Canvas()
        out.lined, out.nparts = dict(self.lined), self.nparts
        for name, fill in (("mat", 0), ("tone", 0), ("flag", 0), ("part", 0), ("on", False)):
            setattr(out, name, warp(getattr(self, name), rows, cols, fill))
        return out

    def lines(self):
        """Where one part of this layer lies over an earlier part, it takes a line on its own side."""
        line = np.zeros((H, W), bool)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            op = shift(self.part, dy, dx, 0)
            oon = shift(self.on, dy, dx, False)
            line |= self.on & oon & (op != self.part) & (op < self.part) & (op > 0)
        return line & ((self.flag & NO_LINE) == 0)


def shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0)); yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0)); xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


def warp(a, rows=None, cols=None, fill=0):
    """`a` with row y slid right by rows[y] and column x slid down by cols[x] (whole pixels)."""
    out = a
    if rows is not None:
        out = np.full_like(a, fill)
        for y in range(H):
            dx = int(rows[y])
            if dx == 0:
                out[y] = a[y]
            elif dx > 0:
                out[y, dx:] = a[y, :W - dx]
            else:
                out[y, :W + dx] = a[y, -dx:]
        a = out
    if cols is not None:
        out = np.full_like(a, fill)
        for x in range(W):
            dy = int(cols[x])
            if dy == 0:
                out[:, x] = a[:, x]
            elif dy > 0:
                out[dy:, x] = a[:H - dy, x]
            else:
                out[:H + dy, x] = a[-dy:, x]
    return out


def grow(mask, n=1):
    m = mask.copy()
    for _ in range(n):
        m = m | shift(m, 1, 0, False) | shift(m, -1, 0, False) | shift(m, 0, 1, False) | shift(m, 0, -1, False)
    return m


def edge_of(mask):
    """The pixels of `mask` on its rim."""
    inner = shift(mask, 1, 0, False) & shift(mask, -1, 0, False) & shift(mask, 0, 1, False) & shift(mask, 0, -1, False)
    return mask & ~inner


# --------------------------------------------------------------------------- putting layers together
def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


def compose(layers, pal, rim=True):
    """layers: canvases back to front; pal: material -> six hex shades. Each layer is outlined
    where it meets nothing or a layer behind it. With `rim`, a second, fainter light comes
    from behind her on the right: just inside each layer's outline on that side, what's in
    shade is lifted (the lords have only the one light). Returns (rgba H x W x 4, which layer
    shows at each pixel)."""
    mat = np.zeros((H, W), np.int16); tone = np.zeros((H, W), np.uint8)
    flag = np.zeros((H, W), np.uint8); layer = np.full((H, W), -1, np.int32)
    for li, cv in enumerate(layers):
        if cv is None:
            continue
        on = cv.on
        t = np.where(cv.lines(), LINE, cv.tone)
        mat[on] = cv.mat[on]; tone[on] = t[on]; flag[on] = cv.flag[on]; layer[on] = li
    drawn = layer >= 0
    line = np.zeros((H, W), bool)
    hair = mat_id("hair")
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nl = shift(layer, dy, dx, -1)
        if dy < 0:
            nl[H - 1, :] = layer[H - 1, :]     # the frame's bottom edge cuts the figure; no line there
        # hair lying over hair takes no line: its locks are parted by their own shade
        on_hair = (mat == hair) & (shift(mat, dy, dx, 0) == hair) & (nl >= 0)
        line |= drawn & ((nl < 0) | ((nl < layer) & ~on_hair))
    line &= (flag & NO_LINE) == 0
    tone = np.where(line, LINE, tone)
    if rim:
        # the outline's pixels that face right, and the pixel just inside each
        faces_right = line & (shift(layer, 0, -1, -1) < layer)
        inside = drawn & ~line & shift(faces_right, 0, -1, False) & (shift(layer, 0, -1, -1) == layer) & ((flag & NO_LINE) == 0)
        tone = np.where(inside & (tone >= 2) & (tone < LINE), np.maximum(tone.astype(int) - 2, 1), tone).astype(np.uint8)
    out = np.zeros((H, W, 4), np.uint8)
    for mi in np.unique(mat[drawn]):
        name = mat_name(int(mi))
        cols = np.array([rgb(h) for h in pal[name]])
        m = drawn & (mat == mi)
        out[m, :3] = cols[np.clip(tone[m], 0, 5)]
        out[m, 3] = 255
    return out, layer


# --------------------------------------------------------------------------- shapes
def ellipse(cx, cy, rx, ry):
    return ((XX + 0.5 - cx) / rx) ** 2 + ((YY + 0.5 - cy) / ry) ** 2 <= 1.0


def poly(points):
    """Filled polygon (even-odd rule, pixel centres)."""
    pts = np.array(points, float)
    inside = np.zeros((H, W), bool)
    px, py = XX + 0.5, YY + 0.5
    for i in range(len(pts)):
        x1, y1 = pts[i - 1]; x2, y2 = pts[i]
        cond = (y1 > py) != (y2 > py)
        xin = (x2 - x1) * (py - y1) / np.where(y2 - y1 == 0, 1e-12, y2 - y1) + x1
        inside ^= cond & (px < xin)
    return inside


def bezier(*pts, n=40):
    t = np.linspace(0, 1, n)[:, None]
    p = [np.array(q, float) for q in pts]
    if len(p) == 3:
        return (1 - t) ** 2 * p[0] + 2 * (1 - t) * t * p[1] + t ** 2 * p[2]
    return (1 - t) ** 3 * p[0] + 3 * (1 - t) ** 2 * t * p[1] + 3 * (1 - t) * t ** 2 * p[2] + t ** 3 * p[3]


def spline(pts, n=8):
    """A smooth path through `pts` (Catmull-Rom)."""
    p = np.array(pts, float)
    if len(p) < 3:
        return [tuple(q) for q in p]
    q = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(q) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            a, b, c, d = q[i - 1], q[i], q[i + 1], q[i + 2]
            out.append(tuple(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3)))
    out.append(tuple(p[-1]))
    return out


def line_pixels(path):
    """1px line through a polyline, without doubled corners."""
    pts = []
    path = np.asarray(path, float)
    for a, b in zip(path, path[1:]):
        n = int(max(abs(b - a)) * 2) + 1
        for t in np.linspace(0, 1, n):
            q = a + (b - a) * t
            p = (int(math.floor(q[0] + 0.5)), int(math.floor(q[1] + 0.5)))
            if not pts or pts[-1] != p:
                pts.append(p)
    clean = []
    for i, p in enumerate(pts):
        if 0 < i < len(pts) - 1:
            a, b = pts[i - 1], pts[i + 1]
            if abs(a[0] - b[0]) == 1 and abs(a[1] - b[1]) == 1:
                continue
        clean.append(p)
    return clean


def draw_line(cv, path, mat, tone, part=None, mask=None, flag=None):
    for x, y in line_pixels(path):
        if 0 <= x < W and 0 <= y < H and (mask is None or mask[y, x]):
            cv.px(x, y, mat, tone, part, flag)


def path_dist(path):
    """Distance from every pixel to a polyline, how far along it (0..1), and which side."""
    pts = np.array(path, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    best = np.full((H, W), 1e9); along = np.zeros((H, W)); side = np.zeros((H, W))
    px, py = XX + 0.5, YY + 0.5
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        ab = b - a; ll = ab @ ab
        if ll < 1e-12:
            continue
        t = np.clip(((px - a[0]) * ab[0] + (py - a[1]) * ab[1]) / ll, 0, 1)
        dx = px - (a[0] + ab[0] * t); dy = py - (a[1] + ab[1] * t)
        d = np.hypot(dx, dy)
        closer = d < best
        best = np.where(closer, d, best)
        along = np.where(closer, (cum[i] + t * math.sqrt(ll)) / max(cum[-1], 1e-9), along)
        side = np.where(closer, np.sign(ab[0] * dy - ab[1] * dx), side)
    return best, along, side


def path_length(path):
    return float(np.sum(np.linalg.norm(np.diff(np.array(path, float), axis=0), axis=1)))


# --------------------------------------------------------------------------- light
LIGHT = np.array([-0.55, -0.5, 0.67])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def tones(value, cuts=(0.86, 0.66, 0.46, 0.28), dither=0.0):
    """Light 0 (dark)..1 (bright) -> shade 0 (lightest)..4 (darkest), with a narrow band of
    ordered dither where two shades meet."""
    v = value + (BAYER4[YY % 4, XX % 4] - 0.5) * 2 * dither
    idx = np.zeros(np.shape(value), int)
    for c in cuts:
        idx += (v < c)
    return np.clip(idx, 0, 4)


def blob(cx, cy, rx, ry, amt=1.0):
    return amt * np.clip(1 - (((XX + 0.5 - cx) / rx) ** 2 + ((YY + 0.5 - cy) / ry) ** 2), 0, 1)


# --------------------------------------------------------------------------- colours
def hx(*hexes):
    return [h.lstrip("#") for h in hexes]


def blend(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]; cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))


# Cloth by name: one colour each, made into six shades by the lords' rule (lights warmer
# and paler, darks cooler and richer), so the women's clothes are dyed like the lords'.
CLOTHS = {
    "teal": "2a6a6c", "deep_teal": "1f4f58", "wine": "7a2238", "crimson": "9a2430", "forest": "2f5a3c",
    "moss": "566a3a", "woad": "2c4a8a", "indigo": "2c3466", "navy": "263050", "plum": "5a2a52",
    "rust": "8a4a26", "russet": "6a3a24", "saffron": "c08a2c", "sand": "b89a6a", "brown": "5a4030",
    "charcoal": "34323a", "slate": "4a5564", "rose": "a85a6a", "maple": "a8402c", "sky": "5a88b0",
    "ivory": "d8ccb0", "cream": "e4d8bc", "straw": "c8ac6a", "black": "24222a", "violet": "4a3a7a",
}
# Cloths too pale or too dark for that rule keep ramps of their own.
RAMPS = {
    "white": hx("ffffff", "f3efe6", "dbd4c6", "b3ab9c", "857d70", "4c463e"),
    "silk_white": hx("ffffff", "f6f2ea", "e2dccf", "bfb7a8", "8f8778", "544c42"),
    "sheer": hx("f4f1ea", "e2ddd2", "c9c3b6", "a7a194", "837d72", "5a554c"),
    "fur": hx("d2bc9c", "b09472", "86694c", "5e4632", "3a2a1e", "241812"),
    "sable": hx("6a5a50", "4c3e38", "342a26", "221a18", "140e0e", "0c0808"),
    "wood": hx("c09060", "9a6c40", "74502c", "50361e", "301f10", "1e1208"),
    "coral": hx("ffb09a", "ee6e5a", "c0443a", "8a2a28", "561a1a", "381012"),
    "amber": hx("ffe08a", "eeb040", "c07a1c", "865010", "523008", "341e06"),
    "turquoise": hx("b0f0e8", "58cfc8", "2a9a98", "1a6a6c", "0e4044", "08282c"),
    "sapphire": hx("a0c4ff", "4a7ae0", "2a4eaa", "1a3274", "0e1c46", "08122e"),
    "silver": hx("f4f6f8", "ccd2d8", "9aa2ac", "6a727c", "42484f", "282c32"),
    "bronze": hx("f0c890", "c89450", "9a6a30", "6a441c", "40280e", "2a1a08"),
    "blossom": hx("fff0f2", "f8c8d0", "e89aaa", "c06a80", "8a4258", "5a2a3a"),
    "leaf": hx("c8e09a", "8ab85a", "5a8a3a", "3a6026", "203a16", "14260e"),
}


class Palette(dict):
    """Material -> six shades. Besides the named ones: "#rrggbb" is a cloth of that colour
    (dyed by the lords' rule), "=rrggbb" is that colour flat (a hand-drawn layer's own)."""

    def __missing__(self, name):
        if name.startswith("#"):
            ramp = LORDS.house_ramp(name)
        elif name.startswith("="):
            ramp = [name[1:]] * 5 + [blend(name[1:], "0a0608", 0.6)]
        else:
            raise KeyError("no colours for material %r" % name)
        self[name] = ramp
        return ramp


def palette(skin, hair, iris, lip=None):
    """The colours of one woman: her skin, lips, hair and eyes, with every cloth and metal."""
    s = LORDS.SKINS[skin] if isinstance(skin, str) else skin
    d = Palette(LORDS.FIXED)
    d.update(RAMPS)
    d["skin"] = s["skin"]
    d["blush"] = [blend(c, "d85a5a", 0.24) for c in s["skin"]]
    d["lip"] = lip or s["lip_f"]
    d["hair"] = LORDS.HAIRS[hair] if isinstance(hair, str) else hair
    d["iris"] = LORDS.IRISES[iris] if isinstance(iris, str) else iris
    for name, colour in CLOTHS.items():
        d[name] = LORDS.house_ramp(colour)
    return d
