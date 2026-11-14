"""Hair as locks, the lords' way: clumps that follow a flow over a shape, each shaded round
with a dark parting edge and a band of sheen. Then each woman's own: Edda's braided crown
and bun, Farah's curls, Kaede's parted hair drawn back to a pinned knot, and the loose
strands that swing (the game moves them: StoryArt.life_material)."""
import math

import numpy as np

from canvas import *
from face import CX, AXIS, TOP, EYE_Y, rows_of


def streamline(seed, flow, mask, step=0.6, max_len=60):
    out = [np.array(seed, float)]
    for sgn in (1, -1):
        p = np.array(seed, float)
        line = []
        for _ in range(int(max_len / step)):
            d = np.asarray(flow(p[0], p[1]), float) * sgn
            n = np.linalg.norm(d)
            if n < 1e-6:
                break
            p = p + d / n * step
            x, y = int(math.floor(p[0] + 0.5)), int(math.floor(p[1] + 0.5))
            if not (0 <= x < W and 0 <= y < H and mask[y, x]):
                break
            line.append(p.copy())
        out = out + line if sgn == 1 else line[::-1] + out
    return np.array(out)


def lit(x, y):
    return np.clip(0.62 - (x - CX) / 88 - (y - 42) / 112, 0, 1)


def locks(cv, mask, flow, seeds, width=7.0, light=lit, sheen=None, rng=None, max_len=90, part=None,
          taper=0.5, edge=0.74, order=None, mat="hair", fill=3):
    """Fill `mask` with locks along `flow`, each shaded round and lit on one side."""
    rng = rng or np.random.default_rng(0)
    if part is None:
        part = cv.new_part()
    cv.put(mask, mat, fill, part)
    val = np.full((H, W), -1.0)
    seq = list(seeds)
    rng.shuffle(seq)
    if order is not None:
        seq.sort(key=lambda p: order(p[0], p[1]))
    for s in seq:
        L = streamline(s, flow, mask, max_len=max_len)
        if len(L) < 3:
            continue
        cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(L, axis=0), axis=1))]
        tot = cum[-1]
        if tot < 2:
            continue
        x0, y0 = np.floor(L.min(0) - width).astype(int)
        x1, y1 = np.ceil(L.max(0) + width).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, W - 1), min(y1, H - 1)
        sy, sx = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        px, py = sx + 0.5, sy + 0.5
        best = np.full(px.shape, 9e9); acr = np.zeros(px.shape); along = np.zeros(px.shape)
        for i in range(0, len(L) - 1, 2):
            a, b = L[i], L[min(i + 2, len(L) - 1)]
            ab = b - a; ll = ab @ ab
            if ll < 1e-9:
                continue
            t = np.clip(((px - a[0]) * ab[0] + (py - a[1]) * ab[1]) / ll, 0, 1)
            dx, dy = px - (a[0] + ab[0] * t), py - (a[1] + ab[1] * t)
            d2 = dx * dx + dy * dy
            closer = d2 < best
            side = np.sign(ab[0] * dy - ab[1] * dx)
            best = np.where(closer, d2, best)
            acr = np.where(closer, side * np.sqrt(d2), acr)
            along = np.where(closer, (cum[i] + t * math.sqrt(ll)) / tot, along)
        wid = width * (1 - taper * np.abs(along * 2 - 1) ** 3) / 2
        inside = (np.abs(acr) <= wid) & mask[y0:y1 + 1, x0:x1 + 1]
        a_n = np.clip(acr / np.maximum(wid, 0.3), -1, 1)
        v = 0.55 + 0.35 * (1 - a_n ** 2) - 0.25 * a_n
        v = v * 0.55 + light(px, py) * 0.6 - 0.12
        if sheen is not None:
            v = v + sheen(px, py) * 0.35 * (1 - a_n ** 2)
        v = v + (rng.random() - 0.5) * 0.18
        v = np.where(np.abs(a_n) > edge, v - 0.45, v)
        tgt = val[y0:y1 + 1, x0:x1 + 1]
        tgt[inside] = v[inside]
    has = (val > -1) & mask
    t = tones(np.clip(val, 0, 1), cuts=(0.92, 0.72, 0.5, 0.3))
    cv.put(has, mat, t, part)
    return part


def seeds_in(mask, spacing, rng, jitter=0.45):
    ys, xs = np.where(mask)
    out = []
    if len(xs) == 0:
        return out
    for y in range(int(ys.min()), int(ys.max()) + 1, spacing):
        for x in range(int(xs.min()), int(xs.max()) + 1, spacing):
            px = x + (rng.random() - 0.5) * spacing * jitter * 2
            py = y + (rng.random() - 0.5) * spacing * jitter * 2
            ix, iy = int(px), int(py)
            if 0 <= ix < W and 0 <= iy < H and mask[iy, ix]:
                out.append((px, py))
    return out


def under_shadow(cv):
    """The shadow hair casts on the brow and temples: a line of shade just under the hairline."""
    hair = cv.on.copy()
    zone = (YY >= 38) & (YY <= 78) & (np.abs(XX + 0.5 - 95) < 31)
    below = shift(hair, 1, 0, False) & ~hair & zone
    cv.put(below, "skin", 3, cv.new_part(False))
    return cv


def braid(cv, path, width, taper=0.35, period=6.6, part=None):
    """A plait: lobes crossing along a path in a herringbone, each lit on its upper side."""
    p = part or cv.new_part()
    d, along, side = path_dist(path)
    total = path_length(path)
    wid = width / 2 * (1 - taper * along)
    m = d <= wid
    dn = d / np.maximum(wid, 0.5)
    s = along * total / period
    lobe = (s + side * 0.25 - dn * 0.42) % 1.0
    val = 0.98 - lobe * 0.72 + 0.10 * (side < 0) - dn * 0.22 + lit(XX, YY) * 0.25 - 0.1
    t = tones(val, cuts=(0.94, 0.72, 0.5, 0.3))
    t = np.where((lobe > 0.86) | (d > wid - 0.9) | (d < 0.55), 4, t)
    cv.put(m, "hair", t, p)
    return m


def strand(cv, pts, width=3.2, part=None, taper=0.7):
    """A loose strand: a narrow lock along a path, thinning to its tip."""
    p = part or cv.new_part()
    path = spline(pts)
    d, along, side = path_dist(path)
    wid = width / 2 * (1 - taper * along ** 1.5)
    m = d <= wid
    t = np.where(d > wid - 0.85, 4, np.where(side < 0, 1, 2))
    t = np.where((np.sin(along * path_length(path) / 3.0) > 0.6) & (t < 4), np.maximum(t - 1, 0), t)
    if width < 2.6:
        t = np.where(m, np.where(side < 0, 2, 4), t)
    cv.put(m, "hair", t, p)
    return m


def coil(cv, cx, cy, rx, ry, rng, width=6.0, part=None, lift=0.12):
    """A knot of hair: locks wound round its middle, a plait coiled over it."""
    m = ellipse(cx, cy, rx, ry)
    part = locks(cv, m, lambda x, y: (-(y - cy) / ry, (x - cx) / rx), seeds_in(m, 4, rng), width=width, rng=rng,
                 max_len=50, part=part, light=lambda x, y: lit(x, y) * 0.6 + lift)
    return m, part


# --------------------------------------------------------------------------- the shape of a head of hair
def outer_cap(vol_top=4.2, vol_side=2.6, bottom=86):
    """The head's outline grown by the hair's volume, from the crown down to `bottom`."""
    L, R, _ = rows_of("full")
    m = np.zeros((H, W), bool)
    for y in range(TOP - 12, bottom):
        yy = max(y, TOP)
        vol = vol_top if y < 48 else vol_side
        l, r = L[yy] + vol, R[yy] + vol
        if y < TOP + 3:
            shrink = (TOP + 3 - y) * 2.3
            l, r = l - shrink, r - shrink
        if l > 0 and r > 0:
            m[y, int(CX - l):int(CX + r) + 1] = True
    return m


def hairline(recede=0.0075, base=49.0, part=AXIS):
    return lambda x: base + recede * (x - part) ** 2


def face_open(hl, temple=(70, 120), side_low=92, wide=(64, 130)):
    """The part of the head the hair leaves bare: the brow under the hairline, down the cheeks."""
    return poly([(wide[0], side_low), (wide[0] + 2.4, 74), (temple[0], 61)] +
                [(x, hl(x)) for x in np.linspace(temple[0] + 4, temple[1] - 6.5, 11)] +
                [(temple[1], 59), (wide[1] - 4, 70), (wide[1], side_low), (152, 170), (40, 170)])


def sheen_at(y0, part_x, bend=0.003, soft=3.6):
    return lambda x, y: np.exp(-(((y - y0 - bend * (x - part_x) ** 2) / soft) ** 2))


# --------------------------------------------------------------------------- Edda
def edda(rng, unbound=False):
    """Chestnut, drawn back from a soft parting under a plait laid over the crown, wound
    into a low knot behind the near ear; curls loose at the temples. Unbound (a bride's):
    the plait still crowns it, the rest falls in waves over her shoulders."""
    back = Canvas()
    part_x = AXIS + 9
    wave = lambda y: 0.5 * math.sin(y / 9.5)
    if unbound:
        m = poly([(64, 42), (56, 80), (50, 128), (43, 173), (39, 198), (48, 210), (58, 203), (67, 214), (80, 208), (112, 208),
                  (125, 214), (136, 205), (146, 211), (154, 198), (150, 173), (142, 128), (136, 80), (128, 42)])
        locks(back, m, lambda x, y: (np.sign(x - part_x + 0.01) * 0.15 + wave(y), 1.0), seeds_in(m, 6, rng), width=8.5,
              light=lambda x, y: lit(x, y) * 0.6, rng=rng, max_len=130)
    else:
        knot, kp = coil(back, 139, 101, 13.5, 15, rng)
        braid(back, [(139 + 8.5 * math.cos(a), 101 + 10 * math.sin(a)) for a in np.linspace(-2.2, 3.6, 30)], 7.5, taper=0.1,
              period=6.0, part=kp)
    front = Canvas()
    hl = lambda x: 51.0 + 0.012 * (x - part_x) ** 2 + np.clip(part_x - 6 - x, 0, None) * 0.10
    cap = outer_cap(vol_top=4.6, vol_side=3.2, bottom=86) & ~face_open(hl, temple=(69, 122), wide=(65.5, 130), side_low=88)
    def flow(x, y):
        return ((x - part_x) / 30 * 1.2 + 0.18 * math.sin(y / 5.0), -0.62)
    locks(front, cap, flow, seeds_in(cap, 5, rng), width=7.0, sheen=sheen_at(35, part_x), rng=rng, max_len=64,
          order=lambda x, y: y)
    braid(front, spline([(131, 68), (129, 48), (118, 33), (99, 26.5), (80, 29), (67, 41), (62.5, 58)], 6), 12.5, taper=0.12)
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    if unbound:
        far = poly([(61, 60), (67.5, 66), (68, 96), (66, 128), (62, 160), (57, 190), (51, 207), (45, 197), (40, 206), (37, 180),
                    (43, 140), (51, 100), (56, 76)])
        near = poly([(131, 64), (126.5, 72), (128, 100), (131, 130), (136, 160), (141, 188), (147, 205), (151, 195), (156, 203),
                     (157, 176), (151, 140), (144, 100), (138, 76)])
        mm = far | near
        locks(loose, mm, lambda x, y: (wave(y) + (0.12 if x > CX else -0.12), 1.0), seeds_in(mm, 5, rng), width=7.5, rng=rng,
              max_len=160, part=lp, order=lambda x, y: -abs(x - CX))
    else:
        strand(loose, [(66, 60), (62, 71), (65.5, 82), (61, 93), (64.5, 103), (61, 111)], 3.4, lp)
        strand(loose, [(68.5, 58), (66.5, 67), (69, 76), (67, 84)], 2.4, lp)
        strand(loose, [(128, 72), (131.5, 83), (128, 93), (131, 103), (128.5, 110)], 3.0, lp)
    return back, front, loose


# --------------------------------------------------------------------------- Farah
def _curl_flow(x, y):
    return (math.sin(x / 3.6 + y / 5.0) * 1.4, math.cos(x / 4.3 - y / 3.7) * 1.4 + 0.25)


def _scallop(mask, rng, r=(3.5, 5.5), every=6, keep=None):
    """A curly outline: rounds added along a shape's rim."""
    ys, xs = np.where(edge_of(mask))
    out = mask.copy()
    idx = rng.permutation(len(xs))[::every]
    for i in idx:
        if keep is not None and not keep(xs[i], ys[i]):
            continue
        rr = rng.uniform(*r)
        out |= ellipse(xs[i] + 0.5, ys[i] + 0.5, rr, rr)
    return out


def farah(rng, unbound=False):
    """Dark curls, parted off-centre and caught loosely behind: full round the head,
    ringlets falling by the face and to the nape."""
    back = Canvas()
    mass = ellipse(99, 70, 38, 40) | ellipse(135, 102, 15, 24) | ellipse(62, 96, 9, 14) | ellipse(141, 126, 11, 13)
    mass = _scallop(mass, rng, keep=lambda x, y: y < 142)
    locks(back, mass, _curl_flow, seeds_in(mass, 4, rng), width=5.4, rng=rng, max_len=13, taper=0.7,
          light=lambda x, y: lit(x, y) * 0.7)
    front = Canvas()
    part_x = AXIS + 5
    hl = lambda x: 51.5 + 0.012 * (x - part_x) ** 2
    opening = face_open(hl, temple=(69, 122), wide=(65.5, 130.5), side_low=90)
    cap = outer_cap(vol_top=4.6, vol_side=4.6, bottom=90)
    cap = _scallop(cap, rng, r=(3.0, 4.6), keep=lambda x, y: y < 84) & ~opening
    locks(front, cap, _curl_flow, seeds_in(cap, 4, rng), width=5.4, rng=rng, max_len=13, taper=0.7,
          sheen=sheen_at(34, part_x, soft=5.0))
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    strand(loose, [(66, 66), (61, 74), (66.5, 82), (61, 90), (66, 98), (61.5, 106), (65, 113)], 4.2, lp, taper=0.55)
    strand(loose, [(70, 60), (67, 68), (70.5, 75), (68, 82)], 3.0, lp)
    strand(loose, [(128, 70), (133, 79), (128, 88), (133.5, 97), (129, 106), (133, 114)], 4.0, lp, taper=0.55)
    return back, front, loose


# --------------------------------------------------------------------------- Kaede
def kaede(rng, unbound=False):
    """Black, parted in the middle and drawn smooth to a knot low behind the near ear, held
    by a wooden pin; two fine strands left to fall by the face."""
    back = Canvas()
    knot, kp = coil(back, 138, 104, 12.5, 12.5, rng, width=5.0, lift=0.34)
    front = Canvas()
    part_x = AXIS + 3
    hl = lambda x: 51.0 + 0.012 * (x - part_x) ** 2
    cap = outer_cap(vol_top=3.6, vol_side=2.6, bottom=88) & ~face_open(hl, temple=(69.5, 121.5), wide=(65.5, 130), side_low=90)
    def flow(x, y):
        k = np.clip((66 - y) / 26, 0.14, 1.6)
        return (np.sign(x - part_x + 0.01) * k, 1.0)
    locks(front, cap, flow, seeds_in(cap, 5, rng), width=6.4, sheen=sheen_at(36, part_x, bend=0.004, soft=4.0), rng=rng,
          max_len=110, order=lambda x, y: -abs(x - part_x))
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    strand(loose, [(69, 57), (65.5, 70), (66.5, 84), (64, 97), (65, 106)], 2.4, lp)
    strand(loose, [(124.5, 58), (128.5, 72), (127, 87), (129.5, 100), (128, 112)], 2.4, lp)
    return back, front, loose


def pin(metal="wood", stone="jade", dangle=None):
    """Kaede's hairpin, through the knot: a stick with a bead at its end."""
    cv = Canvas()
    p = cv.new_part()
    d, along, side = path_dist([(129, 99), (160, 91)])
    m = (d <= 1.2) & ~((along > 0.18) & (along < 0.52))          # it passes behind the knot's coil
    cv.put(m, metal, np.where(side < 0, 1, 3), p)
    cv.put(ellipse(161, 90.5, 2.6, 2.6), stone, 2, p)
    cv.px(160, 89.5, stone, 0, p); cv.px(162, 91.5, stone, 3, p)
    if dangle:
        dp = cv.new_part(False)
        for k in range(1, 9):
            cv.px(158, 92 + k, dangle, 1 if k % 3 else 3, dp)
        cv.put(ellipse(158.5, 103, 1.8, 2.2), stone, 2, dp)
    return cv


STYLES = {"edda": edda, "farid": farah, "kaede": kaede}
