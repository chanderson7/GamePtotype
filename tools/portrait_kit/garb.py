"""What the three women wear, drawn the lords' way: panels of cloth shaded by the light with
folds (a dark crease, a lit ridge), bands of trim along paths, chains, coins, pearls, gems
and fur. An outfit (assets/portraits/rig/outfits.json) is a list of pieces, drawn in order;
each piece is a function here, with its cloths and trims chosen in the outfit.

Cloths are named in canvas.CLOTHS and canvas.RAMPS; metals are gold, silver, bronze;
stones garnet, jade, pearl, coral, amber, turquoise, sapphire.
"""
import math

import numpy as np

from canvas import *
from face import CX, AXIS, EYE_Y, TOP, rows_of

MID = 96.0
BODY = [(80, 142), (112, 142), (146, 154), (163, 168), (170, 256), (22, 256), (29, 168), (46, 154)]
ARM_L = [(47, 153), (29, 168), (22, 256), (50, 256), (53, 214), (54, 182), (51, 162)]
ARM_R = [(145, 153), (163, 168), (170, 256), (142, 256), (139, 214), (138, 182), (141, 162)]


def mirror(points):
    return [(2 * MID - x, y) for x, y in points]


class Outfit:
    """The layers an outfit is drawn on: behind her (a veil, a hood thrown back), on her body,
    and over her hair."""

    def __init__(self, rng, layers_dir=None):
        self.rng = rng
        self.layers_dir = layers_dir  # where her hand-drawn pieces are
        self.far_back = Canvas()      # behind her hair
        self.back = Canvas()          # behind her neck
        self.cv = Canvas()            # on her body
        self.hat = Canvas()           # over her hair
        self.earring = None
        self.pin = None
        self.sway = np.zeros((H, W))  # what swings with her hair (a veil's fall)
        self.covers_hair = False      # a scarf or hood: no loose strands show


# --------------------------------------------------------------------------- cloth
def form(spread=184.0, top=144.0):
    return lambda x, y: np.clip(0.58 - (x - MID) / spread - (y - top) / 320.0, 0.1, 0.92)


def panel(cv, mask, mat, light=None, folds=(), part=None, dither=0.02, cuts=(0.88, 0.68, 0.46, 0.26), line=True,
          bumps=()):
    """A garment piece shaded by the light, with folds: a dark crease and a lit ridge on the
    side the light comes from. A fold deepens along its first third. `bumps`: (x, y, rx, ry,
    amount) swells of the form under the cloth."""
    light = light or form()
    if part is None:
        part = cv.new_part(line)
    val = light(XX + 0.5, YY + 0.5) * np.ones((H, W))
    for x, y, rx, ry, amt in bumps:
        val = val + blob(x, y, rx, ry, amt)
    for path, depth in folds:
        d, along, side = path_dist(path)
        dep = depth * np.clip(along * 3.2 + 0.12, 0, 1)
        val = val - dep * np.exp(-(d / 1.5) ** 2) * 0.55
        val = val + dep * np.exp(-((d - 3.2) / 1.9) ** 2) * 0.22 * (side < 0)
        val = val - dep * np.exp(-((d - 3.6) / 2.3) ** 2) * 0.12 * (side > 0)
    cv.put(mask, mat, tones(val, cuts=cuts, dither=dither), part)
    return part


MOTIFS = {
    "dot": ["X"],
    "cross": [".X.", "XXX", ".X."],
    "diamond": ["..X..", ".X.X.", "X.o.X", ".X.X.", "..X.."],
    "lozenge": [".X.", "XoX", ".X."],
    "kiku": [".X.X.", "X.X.X", ".XoX.", "X.X.X", ".X.X."],
    "leaf": ["..X", ".XX", "XX.", "X.."],
    "star": ["X.X", ".o.", "X.X"],
}


def scatter(cv, mask, motif, grid=(13, 11), mat=None, core=None, lighten=1, rng=None, keep=1.0, part=None):
    """A woven or embroidered pattern: `motif` repeated on a staggered grid over `mask`. With
    `mat` it's stitched in that material (`core` for its centre); without, it's the cloth's
    own colour a shade lighter (damask). `keep` under 1 leaves some out (scattered blossoms)."""
    rows = MOTIFS[motif]
    h, w = len(rows), len(rows[0])
    if mat and part is None:
        part = cv.new_part(False)
    gx, gy = grid
    for j, y in enumerate(range(140, H + gy, gy)):
        for x in range(10 + (gx // 2 if j % 2 else 0), W, gx):
            if keep < 1.0 and rng is not None and rng.random() > keep:
                continue
            ox, oy = (rng.integers(-1, 2), rng.integers(-1, 2)) if (rng is not None and keep < 1.0) else (0, 0)
            cells = [(x + ox + c - w // 2, y + oy + r - h // 2, ch) for r, row in enumerate(rows) for c, ch in enumerate(row) if ch != "."]
            if not all(0 <= px < W and 0 <= py < H and mask[py, px] for px, py, _ in cells):
                continue
            for px, py, ch in cells:
                if mat:
                    cv.px(px, py, core if (ch == "o" and core) else mat, 1 if ch == "X" else 0, part)
                elif cv.tone[py, px] < LINE:
                    cv.tone[py, px] = max(0, int(cv.tone[py, px]) - lighten)


def stripes(cv, mask, period=6, width=2, lighten=1, across=True, mat=None):
    """Woven stripes: every `period` pixels, `width` of them a shade lighter (or in `mat`)."""
    on = ((XX if across else YY) % period) < width
    m = mask & on & cv.on & (cv.tone < LINE)
    if mat:
        cv.mat[m] = mat_id(mat)
    else:
        cv.tone[m] = np.clip(cv.tone[m].astype(int) - lighten, 0, 4)


def fur(cv, mask, rng, mat="ermine", spots=0.06):
    """Fur with a ruffled edge; ermine has its black tail-tips."""
    part = cv.new_part()
    m = mask.copy()
    m[edge_of(m) & (rng.random((H, W)) < 0.35)] = False
    val = 0.62 - (XX - MID) / 190 + (rng.random((H, W)) - 0.5) * 0.35
    cv.put(m, mat, np.minimum(tones(val, cuts=(0.8, 0.55, 0.32, 0.15)), 3), part)
    if mat == "ermine" and spots:
        ys, xs = np.where(m)
        for i in rng.choice(len(xs), size=max(int(len(xs) * spots / 4), 1), replace=False):
            x, y = xs[i], ys[i]
            for dy in (0, 1, 2, 3):
                if y + dy < H and m[y + dy, x]:
                    cv.px(x, y + dy, "ermine", 4 if dy < 3 else 3, part)
    return part


# --------------------------------------------------------------------------- trim
def band(cv, path, width, mat, pattern=None, part=None, line=True, mask=None):
    """A strip of trim along a path; pattern(i, j) -> shade, i along (pixels), j across (0..2)."""
    if part is None:
        part = cv.new_part(line)
    d, along, side = path_dist(path)
    total = path_length(path)
    m = d <= width / 2
    if mask is not None:
        m &= mask
    j = np.clip(((side * d + width / 2) / width * 3).astype(int), 0, 2)
    i = np.floor(along * total).astype(int)
    t = np.where(j == 0, 1, np.where(j == 1, 2, 3)) if pattern is None else pattern(i, j)
    cv.put(m, mat, t, part)
    return part, m


PATTERNS = {
    # along a band: i pixels along, j 0..2 across
    "plain": None,
    "embroidered": lambda i, j: np.where(j == 1, np.where(i % 4 == 0, 3, 1), np.where(j == 0, 2, 3)),
    "dotted": lambda i, j: np.where((j == 1) & (i % 5 < 2), 0, np.where(j == 0, 1, np.where(j == 1, 2, 3))),
    "braid": lambda i, j: np.where((i + j * 2) % 6 < 3, 1, 3),
    "diamonds": lambda i, j: np.where(np.abs((i % 8) - 4) + np.abs(j - 1) * 3 < 3, 0, np.where(j == 1, 2, 3)),
    "key": lambda i, j: np.where(j == 1, np.where(i % 6 < 3, 1, 3), np.where((i % 6 == 0) | (i % 6 == 3), 1, 3)),
    "edge": lambda i, j: np.where(j == 0, 1, 2),
}


def trim(cv, path, spec, default_width=5.0, mask=None):
    """A band from an outfit's `trim`: {mat, width, pattern, gems} or just a material."""
    if not spec:
        return None
    if isinstance(spec, str):
        spec = {"mat": spec}
    part, m = band(cv, path, spec.get("width", default_width), spec.get("mat", "gold"),
                   pattern=PATTERNS[spec.get("pattern", "embroidered")], line=spec.get("line", False), mask=mask)
    if spec.get("gems"):
        gp = cv.new_part(False)
        pts = np.array(path, float)
        cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
        for k, s in enumerate(np.arange(spec.get("every", 12) / 2, cum[-1], spec.get("every", 12))):
            x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
            if mask is None or mask[int(np.clip(y, 0, H - 1)), int(np.clip(x, 0, W - 1))]:
                stones = spec["gems"] if isinstance(spec["gems"], list) else [spec["gems"]]
                gem(cv, x, y, stones[k % len(stones)], 1.5, gp)
    return m


# --------------------------------------------------------------------------- jewellery
def chain(cv, path, spacing=3.4, mat="gold"):
    part = cv.new_part(False)
    pts = np.array(path, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    for k, s in enumerate(np.arange(0, cum[-1], spacing)):
        x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
        if k % 2 == 0:
            for dx, dy, t in ((-1, 0, 2), (0, -1, 0), (1, 0, 3), (0, 1, 3), (-1, -1, 1), (1, 1, 4)):
                cv.px(x + dx, y + dy, mat, t, part)
        else:
            cv.px(x, y, mat, 1, part); cv.px(x + 1, y, mat, 3, part)
    return part


def fine_chain(cv, path, mat="gold", part=None):
    part = part or cv.new_part(False)
    for k, (x, y) in enumerate(line_pixels(path)):
        cv.px(x, y, mat, 1 if k % 3 else 3, part)
    return part


def coin(cv, x, y, part, r=2.4, mat="gold"):
    cv.put(ellipse(x, y, r, r), mat, 2, part)
    cv.put(ellipse(x - 0.5, y - 0.5, r * 0.55, r * 0.55), mat, 1, part)
    cv.px(x - 1, y - 1, mat, 0, part)
    cv.px(x + r * 0.5, y + r * 0.5, mat, 3, part)


def gem(cv, x, y, mat="garnet", r=2.0, part=None):
    part = part or cv.new_part(False)
    cv.put(ellipse(x, y, r, r * 1.15), mat, 2, part)
    cv.px(x - r * 0.4, y - r * 0.45, mat, 0, part)
    cv.px(x + r * 0.4, y + r * 0.5, mat, 3, part)
    return part


def medallion(cv, x, y, r=7.0, stone="garnet", mat="gold"):
    part = cv.new_part()
    m = ellipse(x, y, r, r)
    val = 0.75 - (XX - x) / (r * 2.2) - (YY - y) / (r * 2.2)
    cv.put(m, mat, tones(val, cuts=(0.95, 0.72, 0.45, 0.2)), part)
    ring = m & ~ellipse(x, y, r - 1.5, r - 1.5)
    cv.put(ring & (XX > x), mat, 3)
    if stone:
        cv.put(ellipse(x, y, r * 0.45, r * 0.5), stone, 2)
        cv.px(x - 1, y - 1, stone, 0); cv.px(x, y - 1, stone, 1); cv.px(x + 1, y + 1, stone, 3)
    else:
        for a in np.linspace(0, math.pi * 2, 8, endpoint=False):
            cv.px(x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, mat, 4)
        cv.px(x, y, mat, 0)
    return part


def catenary(x0, x1, y_end, y_low, n=40):
    xs = np.linspace(x0, x1, n)
    m, h = (x0 + x1) / 2, (x1 - x0) / 2
    return list(zip(xs, y_low + (y_end - y_low) * ((xs - m) / h) ** 2))


def strand_of(cv, path, what="pearls", spacing=None, mat="gold", part=None):
    """Pearls, beads or coins strung along a path."""
    part = part or cv.new_part(False)
    pts = np.array(path, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    spacing = spacing or {"pearls": 3.2, "coins": 5.6, "beads": 4.0}[what]
    for k, s in enumerate(np.arange(spacing / 2, cum[-1], spacing)):
        x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
        if what == "coins":
            coin(cv, x, y + 1.5, part, r=2.3, mat=mat)
        elif what == "beads":
            gem(cv, x, y, mat, 1.5, part)
        else:
            cv.px(x, y, "pearl", 0, part); cv.px(x + 1, y, "pearl", 2, part)
            cv.px(x, y + 1, "pearl", 1, part); cv.px(x + 1, y + 1, "pearl", 3, part)
    return part


def lacing(cv, x, y0, y1, mat="leather", step=7, half=3):
    part = cv.new_part(False)
    for y in range(int(y0), int(y1), step):
        for k in range(half * 2 + 1):
            cv.px(x - half + k, y + k * step / (half * 2 + 1) * 0.9, mat, 1, part)
            cv.px(x + half - k, y + k * step / (half * 2 + 1) * 0.9, mat, 2, part)
        cv.px(x - half - 1, y, mat, 4, part); cv.px(x + half + 1, y, mat, 4, part)
    return part


# =========================================================================== the body of a garment
def sleeved(o, mat, opening=None, folds=1.0, pattern=None, bust=True, cuts=(0.88, 0.68, 0.46, 0.26)):
    """A garment's body and sleeves over her whole figure, less `opening` (her neckline)."""
    cv = o.cv
    body = poly(BODY)
    if opening is not None:
        body &= ~opening
    arm_l, arm_r = poly(ARM_L) & body, poly(ARM_R) & body
    torso = body & ~arm_l & ~arm_r
    bumps = [(79, 196, 17, 13, 0.05), (114, 197, 17, 13, 0.035)] if bust else []
    tp = panel(cv, torso, mat, folds=[([(73, 206), (71, 232), (70, 256)], 0.6 * folds), ([(120, 206), (122, 232), (123, 256)], 0.6 * folds),
                                      ([(96, 216), (96, 256)], 0.3 * folds)], bumps=bumps, cuts=cuts)
    panel(cv, arm_l, mat, folds=[([(42, 166), (35, 204), (31, 256)], 0.9 * folds), ([(49, 190), (45, 256)], 0.5 * folds),
                                 ([(24, 222), (36, 229), (49, 224)], 0.5 * folds)], cuts=cuts)
    panel(cv, arm_r, mat, folds=[([(150, 166), (157, 204), (161, 256)], 0.9 * folds), ([(143, 190), (147, 256)], 0.5 * folds),
                                 ([(168, 222), (156, 229), (143, 224)], 0.5 * folds)], cuts=cuts)
    if pattern:
        apply_pattern(o, body, pattern)
    return body


def apply_pattern(o, mask, pattern):
    """A cloth's pattern from an outfit: a motif's name, or {motif, grid, mat, core, keep} or
    {stripes: period, width, mat}."""
    if isinstance(pattern, str):
        pattern = {"motif": pattern}
    if "stripes" in pattern:
        stripes(o.cv, mask, pattern["stripes"], pattern.get("width", 2), across=pattern.get("across", True), mat=pattern.get("mat"))
    else:
        scatter(o.cv, mask, pattern.get("motif", "lozenge"), tuple(pattern.get("grid", (13, 11))), pattern.get("mat"),
                pattern.get("core"), rng=o.rng, keep=pattern.get("keep", 1.0))


NECKS = {
    # what a neckline leaves bare
    "square": lambda d: poly([(73, 136), (119, 136), (119, 156 + 20 * d), (73, 156 + 20 * d)]),
    "round": lambda d: ellipse(MID, 143, 22, 12 + 20 * d) | poly([(74, 130), (118, 130), (118, 143), (74, 143)]),
    "v": lambda d: poly([(76, 136), (116, 136), (MID, 162 + 34 * d)]),
    "boat": lambda d: ellipse(MID, 146, 36, 5 + 9 * d) | poly([(60, 130), (132, 130), (132, 146), (60, 146)]),
    "high": lambda d: poly([(84, 130), (108, 130), (108, 143), (84, 143)]),
}
NECK_EDGES = {
    # the path a trim follows along a neckline
    "square": lambda d: [(72.5, 146.5), (72.5, 157 + 20 * d), (119.5, 157 + 20 * d), (119.5, 146.5)],
    "round": lambda d: [(MID + 22.5 * math.cos(a), 143 + (12.5 + 20 * d) * math.sin(a)) for a in np.linspace(math.pi * 0.97, math.pi * 0.03, 24)],
    "v": lambda d: [(75, 144.5), (MID, 163 + 34 * d), (117, 144.5)],
    "boat": lambda d: [(MID + 36.5 * math.cos(a), 146 + (5.5 + 9 * d) * math.sin(a)) for a in np.linspace(math.pi * 0.96, math.pi * 0.04, 24)],
    "high": lambda d: [(83, 143.5), (MID, 145), (109, 143.5)],
}


# =========================================================================== Vardish
def chemise(o, p):
    """The linen shift under everything: gathered at the neck, or high with a tie."""
    cv = o.cv
    neck, d = p.get("neck", "round"), p.get("depth", 0.4)
    mat = p.get("cloth", "linen")
    body = sleeved(o, mat, NECKS[neck](d), folds=0.6, bust=False)
    edge = NECK_EDGES[neck](d)
    # gathers falling from the neckline
    pts = np.array(edge, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    gp = cv.new_part(False)
    for s in np.arange(3, cum[-1] - 2, 5.0):
        x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
        if y < 148 and neck != "high":
            continue
        for k in range(2, 11):
            px_, py_ = int(round(x + (x - MID) * 0.012 * k)), int(round(y + k))
            if 0 <= px_ < W and py_ < H and body[py_, px_]:
                cv.px(px_, py_, mat, 3 if k < 8 else 2, gp)
    band(cv, edge, 2.6, mat, pattern=PATTERNS["edge"], line=True, mask=grow(body, 1))
    if neck == "high":
        tp = cv.new_part(False)
        for k in range(7):
            cv.px(MID - 1 - k * 0.5, 146 + k, mat, 3, tp); cv.px(MID + 1 + k * 0.6, 146 + k, mat, 3, tp)


def kirtle(o, p):
    """A woollen gown over the shift: its neckline edged with trim, laced down the front."""
    cv = o.cv
    neck, d = p.get("neck", "square"), p.get("depth", 0.75)
    mat = p.get("cloth", "teal")
    body = sleeved(o, mat, NECKS[neck](d), pattern=p.get("pattern"))
    if p.get("sleeves") == "hanging":
        lining = p.get("lining", "gold")
        for pts, fold in ((([(28, 196), (18, 214), (10, 256), (40, 256), (38, 214)]), [(24, 214), (20, 256)]),
                          (mirror([(28, 196), (18, 214), (10, 256), (40, 256), (38, 214)]), [(168, 214), (172, 256)])):
            panel(cv, poly(pts), mat, folds=[(fold, 0.8)])
        for pts in ([(30, 236), (22, 256), (38, 256), (37, 240)], mirror([(30, 236), (22, 256), (38, 256), (37, 240)])):
            panel(cv, poly(pts), lining, line=True)
    trim(cv, NECK_EDGES[neck](d), p.get("trim"), 4.4, mask=grow(body, 2))
    if p.get("lacing"):
        y0 = {"square": 160 + 20 * d, "round": 158 + 20 * d, "v": 166 + 34 * d}.get(neck, 150)
        seam = cv.new_part(False)
        for y in range(int(y0), H):
            cv.px(MID, y, mat, 4, seam)
        lacing(cv, MID, y0 + 4, H - 4, p["lacing"])
    if p.get("cuffs"):
        for pts in ([(22.5, 246), (49.5, 244)], [(169.5, 246), (142.5, 244)]):
            trim(cv, pts, p["cuffs"], 4.0, mask=body)


def mantle(o, p):
    """A mantle on the shoulders, open in front and edged with fur, held by a chain."""
    cv = o.cv
    mat = p.get("cloth", "forest")
    left = [(79, 141), (60, 147), (44, 153), (27, 166), (18, 186), (13, 256), (57, 256), (62, 210), (68, 172), (74, 152)]
    panel(cv, poly(left), mat, folds=[([(50, 164), (43, 208), (40, 256)], 1.0), ([(31, 178), (25, 216), (22, 256)], 0.9),
                                      ([(60, 176), (55, 256)], 0.5)])
    panel(cv, poly(mirror(left)), mat, folds=[([(142, 164), (149, 208), (152, 256)], 1.0), ([(161, 178), (167, 216), (170, 256)], 0.9),
                                              ([(132, 176), (137, 256)], 0.6)])
    if p.get("fur"):
        strip = [(76, 139), (82, 145), (76, 166), (70, 205), (65, 256), (52, 256), (57, 204), (64, 165), (68, 148)]
        fur(cv, poly(strip), o.rng, p["fur"])
        fur(cv, poly(mirror(strip)), o.rng, p["fur"])
    elif p.get("trim"):
        trim(cv, [(77, 142), (71, 170), (65, 210), (60, 256)], p["trim"], 4.4)
        trim(cv, mirror([(77, 142), (71, 170), (65, 210), (60, 256)]), p["trim"], 4.4)
    if p.get("chain", True):
        metal = p.get("metal", "gold")
        chain(cv, catenary(70, 122, 155, 174), mat=metal)
        medallion(cv, 70, 155, r=4.2, stone=p.get("stone", "garnet"), mat=metal)
        medallion(cv, 122, 155, r=4.2, stone=p.get("stone", "garnet"), mat=metal)


def cloak(o, p):
    """A travelling cloak: the hood thrown back and bunched behind the neck, the cloak falling
    from the shoulders and pinned at the throat."""
    cv = o.cv
    mat = p.get("cloth", "brown")
    lining = p.get("lining")
    hood = poly([(64, 149), (70, 132), (84, 126), (MID, 124), (108, 126), (122, 132), (128, 149), (114, 145), (MID, 143), (78, 145)])
    panel(o.back, hood, lining or mat, light=lambda x, y: np.clip(0.5 - (x - MID) / 120 - (y - 126) / 90, 0.1, 0.9),
          folds=[([(72, 134), (MID, 130), (120, 134)], 0.5)])
    left = [(78, 143), (58, 148), (33, 157), (17, 170), (10, 192), (6, 256), (55, 256), (62, 204), (72, 166), (82, 152)]
    panel(cv, poly(left), mat, folds=[([(46, 164), (38, 208), (34, 256)], 1.0), ([(27, 180), (20, 220), (17, 256)], 0.9),
                                      ([(60, 176), (54, 256)], 0.7)])
    panel(cv, poly(mirror(left)), mat, folds=[([(146, 164), (154, 208), (158, 256)], 1.0), ([(165, 180), (172, 220), (175, 256)], 0.9),
                                              ([(132, 176), (138, 256)], 0.7)])
    # the cowl: the hood's edge lying round the neck
    cowl = poly([(63, 147), (72, 139), (84, 143), (MID, 150), (108, 143), (120, 139), (129, 147), (124, 160), (110, 164),
                 (MID, 168), (82, 164), (68, 160)]) & ~poly([(84, 130), (108, 130), (106, 146), (MID, 150), (86, 146)])
    panel(cv, cowl, mat, light=lambda x, y: np.clip(0.72 - (x - MID) / 110 - (y - 140) / 60, 0.1, 0.95),
          folds=[([(66, 150), (82, 157), (MID, 160), (110, 157), (126, 150)], 0.7), ([(70, 157), (MID, 165), (122, 157)], 0.5)])
    if lining:
        band(cv, [(80, 153), (71, 168), (62, 204), (56, 256)], 2.6, lining, pattern=PATTERNS["edge"], line=False)
        band(cv, mirror([(80, 153), (71, 168), (62, 204), (56, 256)]), 2.6, lining, pattern=PATTERNS["edge"], line=False)
    if p.get("fur"):
        fur(cv, poly([(66, 146), (74, 138), (85, 142), (MID, 148), (107, 142), (118, 138), (126, 146), (118, 150), (MID, 156), (74, 150)])
            & ~poly([(84, 130), (108, 130), (106, 146), (MID, 150), (86, 146)]), o.rng, p["fur"], spots=0)
    if p.get("clasp", True):
        medallion(cv, MID, 163, r=5.0, stone=p.get("stone"), mat=p.get("metal", "bronze"))


def belt(o, p):
    cv = o.cv
    mat = p.get("mat", "leather")
    y = p.get("y", 244)
    part, m = band(cv, [(21, y + 1.5), (60, y), (MID, y - 0.5), (132, y), (171, y + 1.5)], 6.0, mat, line=True, mask=poly(BODY))
    metal = p.get("buckle", "bronze")
    bp = cv.new_part()
    cv.put(poly([(MID - 5, y - 5), (MID + 5, y - 5), (MID + 5, y + 5), (MID - 5, y + 5)]), metal, 2, bp)
    cv.put(poly([(MID - 3, y - 3), (MID + 3, y - 3), (MID + 3, y + 3), (MID - 3, y + 3)]), mat, 3, bp)
    cv.px(MID - 4, y - 4, metal, 0, bp); cv.px(MID, y, metal, 1, bp); cv.px(MID + 1, y, metal, 1, bp)


# =========================================================================== Kharzani
def shirt(o, p):
    """A fine shirt with a standing collar, embroidered at the collar and down the front."""
    cv = o.cv
    mat = p.get("cloth", "linen")
    slit = poly([(89, 132), (103, 132), (MID + 0.5, 164)])
    body = sleeved(o, mat, slit, folds=0.6, bust=False)
    pp = cv.new_part(False)
    for x in range(70, 124, 6):
        if abs(x - MID) > 8:
            for y in range(168, H, 2):
                cv.px(x + (y - 168) * (x - MID) * 0.002, y, mat, 3, pp)
    emb = p.get("trim")
    # the collar: two bands standing round the neck, open at the throat
    for pts in ([(80, 137), (84, 145), (90.5, 152)], [(112, 137), (108, 145), (102.5, 152)]):
        band(cv, pts, 7.0, mat, pattern=PATTERNS["edge"], line=True)
        trim(cv, pts, emb, 3.0)
    trim(cv, [(91, 153), (MID, 166), (MID, 256)], emb, 3.4, mask=body)
    trim(cv, [(101, 153), (MID, 166)], emb, 3.4, mask=body)
    bp = cv.new_part(False)
    for y in range(176, H, 13):
        cv.px(MID, y, p.get("buttons", "gold"), 0, bp); cv.px(MID, y + 1, p.get("buttons", "gold"), 3, bp)


def kaftan(o, p):
    """A long coat worn open over the shirt, its edges banded with braid."""
    cv = o.cv
    mat = p.get("cloth", "indigo")
    gap = p.get("open", 14)
    left = [(80, 142), (64, 147), (46, 154), (29, 168), (22, 256), (MID - gap, 256), (MID - gap + 2, 196), (MID - gap + 5, 164), (84, 150)]
    for pts, arm, fl in ((left, ARM_L, [([(64, 176), (60, 216), (58, 256)], 0.6)]),
                         (mirror(left), ARM_R, [([(128, 176), (132, 216), (134, 256)], 0.7)])):
        m = poly(pts)
        a = poly(arm) & m
        sgn = -1 if arm is ARM_L else 1
        panel(cv, m & ~a, mat, folds=fl, bumps=[(MID + sgn * 20, 196, 15, 12, 0.04)])
        panel(cv, a, mat, folds=[([(MID + sgn * 54, 166), (MID + sgn * 61, 204), (MID + sgn * 65, 256)], 0.9),
                                 ([(MID + sgn * 47, 190), (MID + sgn * 51, 256)], 0.5),
                                 ([(MID + sgn * 72, 222), (MID + sgn * 60, 229), (MID + sgn * 47, 224)], 0.5)])
    whole = poly(left) | poly(mirror(left))
    if p.get("pattern"):
        apply_pattern(o, whole, p["pattern"])
    edge = [(81, 143), (86, 152), (MID - gap + 5.5, 166), (MID - gap + 2.5, 198), (MID - gap + 0.5, 256)]
    trim(cv, edge, p.get("trim"), 6.0, mask=whole)
    trim(cv, mirror(edge), p.get("trim"), 6.0, mask=whole)
    if p.get("cuffs"):
        for pts in ([(22.5, 246), (49.5, 244)], [(169.5, 246), (142.5, 244)]):
            trim(cv, pts, p["cuffs"], 4.6, mask=whole)
    if p.get("shoulders"):
        for pts in ([(50, 156), (30, 170)], [(142, 156), (162, 170)]):
            trim(cv, pts, p["shoulders"], 4.0, mask=whole)


def sash(o, p):
    """A sash wound at the waist, its knot hanging at the near side."""
    cv = o.cv
    mat = p.get("cloth", "saffron")
    y0 = p.get("y", 240)
    m = poly([(20.5, y0), (171.5, y0), (173, 256), (19, 256)]) & poly(BODY)
    part = panel(cv, m, mat, light=lambda x, y: np.clip(0.72 - (x - MID) / 260, 0.2, 0.9),
                 folds=[([(22, y0 + 5.5), (170, y0 + 5.5)], 0.6), ([(22, y0 + 11), (170, y0 + 11)], 0.5)])
    if p.get("pattern"):
        apply_pattern(o, m, p["pattern"])
    if p.get("knot", True):
        knot = poly([(124, y0 - 2), (138, y0 - 3), (141, 256), (126, 256)])
        panel(cv, knot, mat, folds=[([(132, y0), (133, 256)], 0.7)])
        cv.put(ellipse(131, y0 + 3, 6, 5), mat, 2, cv.new_part())
        cv.px(129, y0 + 1, mat, 0)
    if p.get("cord"):
        band(cv, [(21, y0 + 8.5), (171, y0 + 8.5)], 2.4, p["cord"], pattern=PATTERNS["braid"], line=False, mask=m)


def jewelled_collar(o, p):
    """A broad collar of gold laid on the breast, set with stones, coins hanging from it."""
    cv = o.cv
    metal = p.get("metal", "gold")
    path = [(MID + 28 * math.cos(a), 146 + 19 * math.sin(a)) for a in np.linspace(math.pi * 0.93, math.pi * 0.07, 26)]
    band(cv, path, 9.5, metal, pattern=PATTERNS["embroidered"], line=True)
    gp = cv.new_part(False)
    stones = p.get("gems", ["garnet", "turquoise"])
    for k, a in enumerate(np.linspace(math.pi * 0.85, math.pi * 0.15, 7)):
        gem(cv, MID + 28 * math.cos(a), 146 + 19 * math.sin(a), stones[k % len(stones)], 1.8, gp)
    if p.get("coins", True):
        strand_of(cv, [(MID + 30 * math.cos(a), 150 + 24 * math.sin(a)) for a in np.linspace(math.pi * 0.84, math.pi * 0.16, 20)],
                  "coins", mat=metal)


# =========================================================================== Ryumon
def collars(cv, layers, depth=186, spread=19.0, top=138):
    """Crossed collars, outermost first: [(material, width)], each a little inside the last. Her
    left side (the viewer's right) lies over her right, as a robe is worn."""
    made = np.zeros((H, W), bool)
    n = len(layers)
    for over in (False, True):
        for k in range(n - 1, -1, -1):
            mat, wd = layers[k]
            inset = k * 4.4
            if over:
                pts = [(MID + (spread - inset), top), (MID + (spread - 6 - inset * 0.75), 160), (MID - 3, depth - k * 5.5 + 2),
                       (MID - 30 + k * 2.5, 232)]
            else:
                pts = [(MID - (spread - inset), top), (MID - (spread - 6 - inset * 0.75), 160), (MID + 4 + (n - 1 - k) * 0.8, depth - k * 5.5)]
            _, m = band(cv, pts, wd, mat, pattern=PATTERNS["edge"], line=True)
            made |= m
    return made


def robe_opening(spread=19.0, depth=186, top=132):
    return poly([(MID - spread, top), (MID + spread, top), (MID + spread - 6, 160), (MID, depth - 6), (MID - spread + 6, 160)])


def kosode(o, p):
    """A robe crossed at the breast over under-collars, each showing a finger's width."""
    cv = o.cv
    mat = p.get("cloth", "slate")
    layers = [(mat, 6.4)] + [(c, 4.6) for c in p.get("collars", ["white"])]
    spread = 19.0 + (len(layers) - 1) * 0.5
    depth = p.get("depth", 186)
    inner = len(layers) - 1
    body = sleeved(o, mat, robe_opening(spread - inner * 4.4 - 2, depth - inner * 5.5 - 8), pattern=p.get("pattern"), folds=0.9, bust=False)
    collars(cv, layers, depth=depth, spread=spread)
    if p.get("crests"):
        cp = cv.new_part(False)
        for x in (48, 144):
            crest(cv, x, 188, cp, p["crests"] if isinstance(p["crests"], str) else "white")


CREST = ["...XXXXX...", "..X.....X..", ".X..X.X..X.", "X..XXXXX..X", "X.XX.X.XX.X", "X..XXXXX..X", "X.XX.X.XX.X",
         "X..XXXXX..X", ".X..X.X..X.", "..X.....X..", "...XXXXX..."]


def crest(cv, x, y, part=None, mat="white"):
    part = part or cv.new_part(False)
    for r, row in enumerate(CREST):
        for c, ch in enumerate(row):
            if ch == "X":
                cv.px(x - 5 + c, y - 5 + r, mat, 1, part)
    return part


def overrobe(o, p):
    """A robe worn open over the kosode (a haori, a vest, an uchikake): straight fronts with a
    broad collar band, tied with cords or left to hang."""
    cv = o.cv
    mat = p.get("cloth", "plum")
    gap = p.get("open", 22)
    sleeves = p.get("sleeves", True)
    if sleeves:
        left = [(77, 141), (60, 147), (44, 153), (27, 166), (20, 256), (MID - gap - 2, 256), (MID - gap, 200), (MID - gap + 3, 166), (80, 150)]
    else:
        left = [(77, 141), (60, 147), (48, 152), (46, 168), (48, 256), (MID - gap - 2, 256), (MID - gap, 200), (MID - gap + 3, 166), (80, 150)]
    for pts, sgn in ((left, -1), (mirror(left), 1)):
        m = poly(pts)
        folds = [([(MID + sgn * 34, 172), (MID + sgn * 36, 256)], 0.6)]
        if sleeves:
            folds += [([(MID + sgn * 54, 166), (MID + sgn * 62, 208), (MID + sgn * 66, 256)], 0.9),
                      ([(MID + sgn * 46, 184), (MID + sgn * 49, 256)], 0.6)]
        panel(cv, m, mat, folds=folds)
    whole = poly(left) | poly(mirror(left))
    if p.get("pattern"):
        apply_pattern(o, whole, p["pattern"])
    edge = [(78, 142), (MID - gap + 3.5, 166), (MID - gap + 0.5, 200), (MID - gap - 1.5, 256)]
    band_mat = p.get("band", mat)
    for pts in (edge, mirror(edge)):
        band(cv, pts, p.get("band_width", 7.0), band_mat, pattern=PATTERNS["edge"], line=True, mask=grow(whole, 1))
        if p.get("lining"):
            inner = [(x + (1 if x < MID else -1) * 4.6, y) for x, y in pts]
            band(cv, inner, 2.2, p["lining"], pattern=PATTERNS["edge"], line=False)
        if p.get("trim"):
            trim(cv, pts, p["trim"], 3.0, mask=whole)
    if p.get("ties"):
        tp = cv.new_part(False)
        y = 204
        for x, yy in catenary(MID - gap + 2, MID + gap - 2, y, y + 7, 60):
            cv.px(x, yy, p["ties"], 1, tp); cv.px(x, yy + 1, p["ties"], 3, tp)
        cv.put(ellipse(MID, y + 7.5, 3.4, 3.0), p["ties"], 2, cv.new_part())
        for k in range(10):
            cv.px(MID - 1.5, y + 10 + k, p["ties"], 1 if k < 7 else 3, tp); cv.px(MID + 1.5, y + 10 + k, p["ties"], 2 if k < 7 else 3, tp)
    if p.get("crests"):
        cp = cv.new_part(False)
        for x in (50, 142):
            crest(cv, x, 186, cp, p["crests"] if isinstance(p["crests"], str) else "white")


def obi(o, p):
    """A broad sash, with a cord tied over it."""
    cv = o.cv
    mat = p.get("cloth", "moss")
    y0 = p.get("y", 230)
    m = poly([(22, y0), (170, y0), (172, 256), (20, 256)]) & poly(BODY)
    panel(cv, m, mat, light=lambda x, y: np.clip(0.72 - (x - MID) / 300, 0.2, 0.9),
          folds=[([(22, y0 + 4), (170, y0 + 4)], 0.25)])
    if p.get("pattern"):
        apply_pattern(o, m, p["pattern"])
    if p.get("cord"):
        cy = y0 + (256 - y0) * 0.52
        band(cv, [(21, cy), (171, cy)], 3.4, p["cord"], pattern=PATTERNS["braid"], line=True, mask=m)
        if p.get("clasp"):
            gem(cv, MID, cy, p["clasp"], 2.6)


# =========================================================================== jewellery
def necklace(o, p):
    cv = o.cv
    kind = p.get("kind", "chain")
    metal = p.get("metal", "gold")
    low = p.get("low", 160)
    path = catenary(MID - 15, MID + 15, 141, low, 50)
    if kind == "pearls":
        strand_of(cv, path, "pearls")
    elif kind == "coins":
        fine_chain(cv, path, metal)
        strand_of(cv, [(x, y) for x, y in path if abs(x - MID) < 13], "coins", mat=metal)
    elif kind == "beads":
        strand_of(cv, path, "beads", mat=p.get("gem", "coral"))
    else:
        fine_chain(cv, path, metal)
    if p.get("gem") and kind in ("chain", "pearls"):
        gp = cv.new_part(False)
        cv.px(MID, low + 1, metal, 2, gp)
        gem(cv, MID, low + 4, p["gem"], 2.4, gp)


def brooch(o, p):
    x, y = {"chest": (MID, 176), "throat": (MID, 150), "shoulder": (130, 158)}[p.get("at", "chest")]
    x, y = p.get("x", x), p.get("y", y)
    medallion(o.cv, x, y, r=p.get("r", 4.6), stone=p.get("gem"), mat=p.get("metal", "bronze"))


def earrings(o, p):
    o.earring = (p.get("metal", "gold"), p.get("gem"))


# =========================================================================== on the head
def circlet(o, p):
    """A band of metal across the brow, a stone at its middle, coins hanging if she likes."""
    cv = o.hat
    metal = p.get("metal", "gold")
    part = cv.new_part(False)
    ax = AXIS + 1.5
    y0 = p.get("y", 55.0)
    for x in range(66, 130):
        y = y0 + 0.008 * (x - ax) ** 2
        cv.px(x, y, metal, 1 if x < ax else 2, part)
        cv.px(x, y + 1, metal, 3, part)
    if p.get("coins"):
        for x in range(71, 127, 7):
            coin(cv, x, y0 + 0.008 * (x - ax) ** 2 + 4.2, part, r=1.9, mat=metal)
    if p.get("gem"):
        cv.put(ellipse(ax, y0 + 4.5, 2.2, 3.0), p["gem"], 2, part)
        cv.px(ax - 0.8, y0 + 3.2, p["gem"], 0, part); cv.px(ax + 0.8, y0 + 6, p["gem"], 3, part)


def crown(o, p):
    """A bridal crown set on the hair: a band with leaves and stones."""
    cv = o.hat
    metal = p.get("metal", "gold")
    part = cv.new_part()
    cx = 97.0
    stones = p.get("gems", ["garnet", "pearl"])
    arc = lambda x: p.get("y", 37.0) + 0.011 * (x - cx) ** 2
    for x in range(66, 129):
        yb = arc(x)
        for k in range(4):
            cv.px(x, yb - k, metal, 1 if k == 3 else (2 if x < cx else 3), part)
    for i, x in enumerate(range(70, 127, 9)):
        yb = arc(x) - 4
        hgt = 7 if i % 2 == 0 else 5
        for k in range(hgt):
            w = max(0, 2 - k // 2)
            for dx in range(-w, w + 1):
                cv.px(x + dx, yb - k, metal, 1 if dx <= 0 else 3, part)
        cv.put(ellipse(x + 0.5, yb - hgt - 0.5, 1.5, 1.5), stones[i % len(stones)], 1, part)
    for i, x in enumerate(range(74, 124, 9)):
        cv.px(x + 0.5, arc(x) - 1.5, stones[(i + 1) % len(stones)], 1, part)


def comb(o, p):
    """A comb set in the hair above the knot."""
    cv = o.hat
    metal = p.get("metal", "gold")
    part = cv.new_part()
    path = [(108 + 12 * math.cos(a), 44 + 9 * math.sin(a)) for a in np.linspace(-2.3, -0.5, 12)]
    band(cv, path, 4.0, metal, pattern=PATTERNS["embroidered"], part=part)
    tp = cv.new_part(False)
    for k, (x, y) in enumerate(path[1:-1]):
        for j in range(1, 5):
            cv.px(x - (x - 108) * 0.08 * j, y + j + 1.5, metal, 2 if k % 2 else 3, tp)


def pin(o, p):
    o.pin = (p.get("metal", "wood"), p.get("gem", "jade"), p.get("dangle"))


def flowers(o, p):
    """Blossoms pinned in the hair by the knot, a spray of them hanging."""
    cv = o.hat
    part = cv.new_part()
    mat = p.get("mat", "blossom")
    spots = [(126, 62, 4.6), (132, 70, 3.8), (121, 55, 3.6)] if p.get("at", "side") == "side" else \
        [(76, 36, 4.2), (88, 30, 4.6), (101, 29, 4.6), (113, 33, 4.2), (123, 40, 3.8)]
    for x, y, r in spots:
        for a in np.linspace(0, math.pi * 2, 5, endpoint=False):
            cv.put(ellipse(x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55, r * 0.5, r * 0.5), mat, 1 if math.cos(a) < 0.2 else 2, part)
        cv.put(ellipse(x, y, 1.3, 1.3), p.get("core", "gold"), 1, part)
    if p.get("leaves", True):
        lp = cv.new_part(False)
        for x, y, r in spots:
            cv.px(x + r, y + r - 1, "leaf", 2, lp); cv.px(x + r + 1, y + r, "leaf", 3, lp)
    if p.get("spray"):
        sp = cv.new_part(False)
        for k in range(12):
            cv.px(134 + (k % 2), 74 + k, mat, 1 if k % 3 else 3, sp)
        cv.px(134, 87, p.get("core", "gold"), 1, sp)


def veil(o, p):
    """A fine veil pinned at the crown, lying over the back of her hair and falling behind
    her shoulders, its edge worked in gold."""
    mat = p.get("cloth", "sheer")
    fall = poly([(60, 44), (51, 80), (41, 120), (30, 160), (22, 214), (172, 214), (163, 160), (152, 120), (142, 80), (134, 44),
                 (118, 26), (97, 20), (76, 26)])
    panel(o.far_back, fall, mat, light=lambda x, y: np.clip(0.6 - (x - MID) / 150 - (y - 60) / 330, 0.1, 0.92),
          folds=[([(56, 80), (44, 140), (36, 214)], 0.8), ([(140, 80), (152, 140), (160, 214)], 0.8), ([(70, 150), (64, 214)], 0.5),
                 ([(128, 150), (134, 214)], 0.5)])
    o.sway = np.maximum(o.sway, np.where(fall, np.clip((YY - 110) / 100.0, 0, 1) * 0.7, 0))
    front = poly([(58, 62)] + [(97 + 41 * math.cos(a), 52 - 34 * math.sin(a)) for a in np.linspace(math.pi * 0.96, math.pi * 0.04, 18)]
                 + [(136, 62)] + [(97 + 39 * math.cos(a), 60 - 22 * math.sin(a)) for a in np.linspace(math.pi * 0.04, math.pi * 0.96, 18)])
    panel(o.hat, front, mat, light=lambda x, y: np.clip(0.85 - (x - 90) / 110 - (y - 20) / 110, 0.1, 0.95),
          folds=[([(70, 30), (64, 56)], 0.5), ([(124, 30), (131, 56)], 0.5), ([(97, 20), (97, 36)], 0.3)])
    edge = [(97 + 39.5 * math.cos(a), 60 - 22 * math.sin(a)) for a in np.linspace(math.pi * 0.97, math.pi * 0.03, 24)]
    trim(o.hat, edge, p.get("trim", {"mat": "gold", "pattern": "dotted"}), 2.6)
    tr = p.get("trim", {"mat": "gold"})
    tmat = tr if isinstance(tr, str) else tr.get("mat", "gold")
    for pts in ([(51.5, 80), (41.5, 120), (30.5, 160), (22.5, 214)], mirror([(51.5, 80), (41.5, 120), (30.5, 160), (22.5, 214)])):
        band(o.far_back, pts, 2.2, tmat, pattern=PATTERNS["dotted"], line=False)


def scarf(o, p):
    """A scarf over the hair, framing the face and falling to the shoulders, its edge banded."""
    mat = p.get("cloth", "indigo")
    o.covers_hair = True
    bm = poly([(58, 54), (50, 96), (42, 160), (36, 204), (156, 204), (150, 160), (142, 96), (134, 54)])
    panel(o.far_back, bm, mat, light=lambda x, y: np.clip(0.5 - (x - MID) / 144 - (y - 96) / 320, 0.1, 0.9),
          folds=[([(54, 112), (45, 204)], 0.8), ([(138, 112), (147, 204)], 0.8)])
    face = poly([(67.5, 76), (69, 63), (74, 54.5), (84, 50), (97, 49), (110, 51.5), (119, 58), (124, 70), (127.5, 96), (120, 124),
                 (108, 133), (97, 137), (84, 133), (73, 122), (66, 98)])
    dome = [(96 + 41 * math.cos(a), 50 - 31 * math.sin(a)) for a in np.linspace(math.pi * 0.98, 0.02, 18)]
    m = poly([(55, 54)] + dome + [(137.5, 54), (140, 84), (146, 128), (155, 178), (136, 186), (125, 160), (116, 148), (77, 148),
              (64, 160), (53, 186), (37, 178), (46, 128), (52, 84)]) & ~face
    cv = o.hat
    panel(cv, m, mat, light=lambda x, y: np.clip(0.75 - (x - 93) / 112 - (y - 32) / 256, 0.1, 0.95),
          folds=[([(64, 64), (57, 112), (48, 176)], 0.9), ([(128, 64), (136, 112), (147, 176)], 0.9), ([(90, 15), (77, 32)], 0.4),
                 ([(110, 18), (120, 36)], 0.4), ([(72, 150), (84, 156), (97, 158), (110, 156), (122, 150)], 0.6)])
    if p.get("pattern"):
        saved = o.cv
        o.cv = cv
        scatter(cv, m, p["pattern"] if isinstance(p["pattern"], str) else p["pattern"].get("motif", "dot"), (11, 9),
                None if isinstance(p["pattern"], str) else p["pattern"].get("mat"), rng=o.rng)
        o.cv = saved
    rim = [(66, 98), (67.5, 76), (69, 63), (74, 54.5), (84, 50), (97, 49), (110, 51.5), (119, 58), (124, 70), (127.5, 96)]
    trim(cv, rim, p.get("trim", {"mat": "gold", "pattern": "dotted"}), 3.2)
    low = [(66, 98), (73, 122), (84, 133), (97, 137), (108, 133), (120, 124), (127.5, 96)]
    trim(cv, low, p.get("trim", {"mat": "gold", "pattern": "dotted"}), 3.2)


def layer(o, p):
    """A hand-drawn piece: assets/portraits/rig/<who>/layers/<name>.png, 192x256, drawn over
    her template (build.py template). With `dye` its greys become that cloth's shades, light
    where it's drawn light; without, it's worn in its own colours. `over_hair` puts it over
    her hair, `behind` behind her neck; it's outlined like any piece unless `outline` is false."""
    from PIL import Image
    import os
    img = np.array(Image.open(os.path.join(o.layers_dir, p["name"] + ".png")).convert("RGBA").resize((W, H), Image.NEAREST)).astype(int)
    on = img[..., 3] >= 128
    cv = o.hat if p.get("over_hair") else (o.back if p.get("behind") else o.cv)
    part = cv.new_part(p.get("outline", True))
    if p.get("dye"):
        lum = (img[..., 0] * 299 + img[..., 1] * 587 + img[..., 2] * 114) / 255000.0
        cv.put(on, p["dye"], tones(lum, cuts=(0.86, 0.66, 0.46, 0.26)), part)
    else:
        key = img[..., 0] * 65536 + img[..., 1] * 256 + img[..., 2]
        for k in np.unique(key[on]):
            cv.put(on & (key == k), "=%06x" % k, 2, part)


PIECES = {
    "chemise": chemise, "kirtle": kirtle, "mantle": mantle, "cloak": cloak, "belt": belt,
    "shirt": shirt, "kaftan": kaftan, "sash": sash, "collar": jewelled_collar,
    "kosode": kosode, "overrobe": overrobe, "obi": obi,
    "necklace": necklace, "brooch": brooch, "earrings": earrings,
    "circlet": circlet, "crown": crown, "comb": comb, "pin": pin, "flowers": flowers, "veil": veil, "scarf": scarf,
    "layer": layer,
}


def dress(pieces, rng, layers_dir=None):
    """An outfit's layers, from its list of pieces."""
    o = Outfit(rng, layers_dir)
    for p in pieces:
        PIECES[p["piece"]](o, p)
    return o
