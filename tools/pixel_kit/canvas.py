"""Drawing surface for the lord portrait kit (120x160, see scripts/art/lord_portrait.gd).

Every pixel records a material (skin, hair, house cloth, gold...) and a shade 0-4 (light to
dark; 5 is the outline). Colours are chosen in the game from the lord's record, so one set of
parts serves every house, skin and hair colour.
"""
import math
import numpy as np

W, H = 120, 160
YY, XX = np.mgrid[0:H, 0:W]
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
LINE = 5

# materials (ids are stored in the atlas; keep in step with lord_portrait.gd via kit.json)
MATERIALS = ["none", "skin", "blush", "lip", "hair", "eye", "iris", "ink", "cloth_a", "cloth_b", "cloth_c",
             "linen", "gold", "ermine", "garnet", "steel", "white", "black", "pearl", "jade", "leather"]
M = {name: i for i, name in enumerate(MATERIALS)}
NO_LINE = 1          # flag: this pixel never takes an outline (jewellery, crests, features)


class Canvas:
    def __init__(self):
        self.mat = np.zeros((H, W), np.uint8)
        self.tone = np.zeros((H, W), np.uint8)
        self.flag = np.zeros((H, W), np.uint8)
        self.part = np.zeros((H, W), np.int32)
        self.on = np.zeros((H, W), bool)
        self.lined = {}                  # part -> takes an outline
        self.nparts = 0

    def new_part(self, line=True):
        self.nparts += 1
        self.lined[self.nparts] = line
        return self.nparts

    def put(self, mask, mat, tone, part=None, flag=None):
        mask = np.asarray(mask, bool)
        self.mat[mask] = M[mat] if isinstance(mat, str) else np.asarray(mat)[mask] if np.ndim(mat) else mat
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
            self.mat[y, x] = M[mat] if isinstance(mat, str) else mat
            self.tone[y, x] = tone
            self.on[y, x] = True
            if part is not None:
                self.part[y, x] = part
                self.flag[y, x] = 0 if self.lined.get(part, True) else NO_LINE
            if flag is not None:
                self.flag[y, x] = flag

    def erase(self, mask):
        self.on[mask] = False
        self.mat[mask] = 0

    def inner_lines(self):
        """Where one piece of this sprite lies over an earlier piece, it takes a line on its own
        side (the sprite's outer edge is outlined in the game, against whatever is behind)."""
        line = np.zeros((H, W), bool)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            op = shift(self.part, dy, dx, 0)
            oon = shift(self.on, dy, dx, False)
            line |= self.on & oon & (op != self.part) & (op < self.part) & (op > 0)
        line &= (self.flag & NO_LINE) == 0
        self.tone[line] = LINE

    def sprite(self):
        """(x0, y0, w, h, rgba) cropped to what is drawn: R material, G shade, B flags."""
        if not self.on.any():
            return None
        ys, xs = np.where(self.on)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        a = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        sub = (slice(y0, y1), slice(x0, x1))
        a[..., 0] = self.mat[sub]
        a[..., 1] = self.tone[sub]
        a[..., 2] = self.flag[sub]
        a[..., 3] = np.where(self.on[sub], 255, 0)
        a[self.on[sub] == False] = 0
        return int(x0), int(y0), a


def shift(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0)); yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0)); xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


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
