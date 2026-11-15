"""Hair that flows: each woman's is a mass of hair with large tapered locks laid over it, every
lock curving along a path, round across its width, with strand lines and a band of sheen
(`lock`). Edda's falls in long waves with a ribbon-tied plait among them, Farah's in
ringlets, Kaede's straight and glossy under a pinned top knot. What hangs loose is drawn
on its own layer, and the game swings it when her head moves (StoryArt.life_material).
The lords' way of drawing hair (`locks`: clumps along a flow) is kept for knots."""
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
    if sheen is not None:
        # glints: where the sheen is strongest, a lit lock takes the brightest shade
        t = np.where((sheen(XX + 0.5, YY + 0.5) > 0.72) & (t == 1), 0, t)
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


# --------------------------------------------------------------------------- hair that flows
def ribbon(path):
    """For every pixel: its distance from a path, how far along it (0..1), the vector to it
    from the nearest point on the path, and which side of the path it's on."""
    pts = np.array(path, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    best = np.full((H, W), 1e9); along = np.zeros((H, W)); vx = np.zeros((H, W)); vy = np.zeros((H, W))
    side = np.zeros((H, W))
    px, py = XX + 0.5, YY + 0.5
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
        ab = p1 - p0; ll = ab @ ab
        if ll < 1e-12:
            continue
        t = np.clip(((px - p0[0]) * ab[0] + (py - p0[1]) * ab[1]) / ll, 0, 1)
        dx = px - (p0[0] + ab[0] * t); dy = py - (p0[1] + ab[1] * t)
        d = np.hypot(dx, dy)
        closer = d < best
        best = np.where(closer, d, best)
        along = np.where(closer, (cum[i] + t * math.sqrt(ll)) / max(cum[-1], 1e-9), along)
        vx = np.where(closer, dx, vx); vy = np.where(closer, dy, vy)
        side = np.where(closer, np.sign(ab[0] * dy - ab[1] * dx), side)
    return best, along, vx, vy, side, cum[-1]


def lock(cv, pts, width, part, mat="hair", root=0.6, tip=0.3, sheen=(0.3,), light=0.0, strands=3, seed=0, mask=None,
         blunt=False):
    """A lock of hair: a long tapered shape curving along `pts`, round across its width (lit
    on the side the light comes from, a dark edge on the other), with strand lines running
    its length and a band of sheen where it turns to the light. `root`: how wide it starts
    (of `width`); `tip`: the last part of its length, over which it thins to a point (a
    `blunt` one is cut square); `light`: lighter or darker than its place would make it."""
    path = spline(pts, 10)
    d, along, vx, vy, side, total = ribbon(path)
    prof = np.minimum(1.0, root + (1 - root) * along / 0.18)
    if not blunt:
        prof = prof * (1 - np.clip((along - (1 - tip)) / max(tip, 1e-6), 0, 1) ** 1.7)
    half = width / 2 * prof
    m = (d <= half) & (half > 0.35)
    if mask is not None:
        m &= mask
    a = np.clip(d / np.maximum(half, 0.35), 0, 1)
    toward = (vx * -0.72 + vy * -0.69) / np.maximum(d, 1e-3)        # +1 on the side facing the light
    val = 0.50 + 0.25 * toward * a - 0.10 * a * a + light + lit(XX, YY) * 0.28
    for s in sheen:
        val = val + 0.26 * np.exp(-((along - s) / 0.055) ** 2) * (1 - a ** 1.5) * (0.65 + 0.35 * toward)
    t = tones(val, cuts=(0.90, 0.70, 0.50, 0.32))
    if strands:
        u = np.round(side * d)
        gaps = np.sin(along * total / 4.3 + seed * 1.7 + u * 2.1) > -0.25
        t = np.where((u % strands == 0) & gaps & (a < 0.82) & (np.abs(u) > 0), np.minimum(t + 1, 4), t)
    t = np.where((d > half - 1.0) & (toward < 0.15), 4, t)
    cv.put(m, mat, t, part)
    return m


def mass(cv, mask, part, mat="hair", light=0.0, flow=None, rng=None, spacing=5):
    """Hair seen as a whole (what lies under the locks, or behind her): shaded by where the
    light falls, with a few strands along `flow`."""
    val = 0.34 + lit(XX, YY) * 0.36 + light
    cv.put(mask, mat, tones(val, cuts=(0.90, 0.70, 0.50, 0.32)), part)
    if flow is not None:
        rng = rng or np.random.default_rng(1)
        for s in seeds_in(mask, spacing, rng):
            L = streamline(s, flow, mask, max_len=40)
            for x, y in line_pixels(L[::3]) if len(L) > 6 else []:
                if 0 <= x < W and 0 <= y < H and mask[y, x] and cv.tone[y, x] < 4:
                    cv.tone[y, x] += 1


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


def face_open(hl, temple=(70, 120), side_low=92, wide=(64, 130)):
    """The part of the head the hair leaves bare: the brow under the hairline, down the cheeks."""
    return poly([(wide[0], side_low), (wide[0] + 2.4, 74), (temple[0], 61)] +
                [(x, hl(x)) for x in np.linspace(temple[0] + 4, temple[1] - 6.5, 11)] +
                [(temple[1], 59), (wide[1] - 4, 70), (wide[1], side_low), (152, 170), (40, 170)])


# --------------------------------------------------------------------------- Edda
def edda(rng, ribbon_cloth="teal"):
    """Chestnut, long and loose: parted on her left, a wave swept across the brow, falling
    in waves behind her shoulders and forward over the near one; one slender plait among
    them, tied with a ribbon. (A bride wears it the same, under her crown.)"""
    back = Canvas()
    bp = back.new_part()
    behind = ellipse(97.5, 67, 42, 47) | poly([(58, 62), (52, 104), (47, 140), (44, 170), (60, 176), (88, 172), (88, 100)]) \
        | poly([(136, 62), (143, 104), (150, 140), (154, 172), (140, 178), (108, 172), (108, 100)])
    mass(back, behind, bp, light=-0.16, flow=lambda x, y: (0.25 * math.sin(y / 8.0) + (x - 97) / 160, 1.0), rng=rng)
    front = Canvas()
    fp = front.new_part()
    part_x = 107.0
    hl = lambda x: 49.5 + 0.0065 * (x - part_x) ** 2 + np.clip(part_x - 6 - x, 0, None) * 0.16
    cap = (outer_cap(vol_top=6.6, vol_side=5.0, bottom=90) & ellipse(97.5, 68, 40.5, 49.5)) \
        & ~face_open(hl, temple=(69, 122), wide=(65.5, 130.5), side_low=92)
    mass(front, cap, fp, light=0.02)
    # from the parting across the crown and brow to the far temple, furthest back first
    lock(front, [(104, 24.5), (86, 23), (70, 32), (60.5, 50), (57.5, 72)], 14, fp, sheen=(0.32,), light=-0.05, seed=1, tip=0.25)
    lock(front, [(106, 31), (90, 28.5), (75, 37), (65, 53), (61, 76)], 13, fp, sheen=(0.3,), seed=2, tip=0.25)
    lock(front, [(108, 40), (95, 37.5), (81, 44), (71, 56), (65.5, 71), (63.5, 84)], 11.5, fp, sheen=(0.28,), light=0.04, seed=3, tip=0.3)
    # and from it back over the near ear
    lock(front, [(107, 25), (121, 28), (131, 42), (135.5, 60), (136, 80)], 13, fp, sheen=(0.3,), light=-0.08, seed=4, tip=0.25)
    lock(front, [(109, 33), (120, 36), (128, 48), (131.5, 64), (133, 82)], 11, fp, sheen=(0.3,), light=-0.03, seed=5, tip=0.25)
    lock(front, [(110, 42), (118, 45), (124.5, 55), (127.5, 68), (128.5, 78)], 7.5, fp, sheen=(0.3,), seed=6, tip=0.35)
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    # the fall over the near shoulder: it carries on from the locks over the ear, waving
    # forward over the collarbone and down the breast; the furthest back first
    lock(loose, [(137, 62), (150, 94), (157, 120), (154.5, 146), (160, 170), (156.5, 194), (160, 210), (155, 222)], 15, lp,
         sheen=(0.2, 0.55), light=-0.12, seed=7, tip=0.22, root=0.4)
    lock(loose, [(135.5, 64), (145.5, 96), (151.5, 118), (148.5, 142), (154, 166), (150, 190), (153.5, 208), (147, 224)], 15.5, lp,
         sheen=(0.24, 0.6), light=-0.04, seed=8, tip=0.22, root=0.4)
    lock(loose, [(137.5, 90), (142.5, 110), (139, 134), (144.5, 158), (140, 182), (143.5, 202), (136.5, 219)], 13, lp,
         sheen=(0.2, 0.62), seed=9, tip=0.25, root=0.5)
    lock(loose, [(136.5, 112), (133, 128), (137, 144), (131.5, 160), (134.5, 174), (129, 185)], 7.0, lp, sheen=(0.3,), light=0.05,
         seed=13, tip=0.45)
    # the fall on the far side, and a curl before it that frames the face
    lock(loose, [(58, 60), (49, 96), (44.5, 124), (47, 150), (41, 176), (44.5, 198), (40.5, 212)], 14, lp, sheen=(0.22, 0.6),
         light=-0.10, seed=14, tip=0.22, root=0.4)
    lock(loose, [(59.5, 62), (53.5, 94), (50, 116), (54.5, 140), (47.5, 164), (51.5, 186), (46, 204), (51, 217)], 15, lp,
         sheen=(0.25, 0.63), seed=10, tip=0.22, root=0.4)
    lock(loose, [(61.5, 84), (58.5, 97), (62, 110), (58.5, 123), (60.5, 135)], 5.5, lp, sheen=(0.4,), light=0.05, seed=11, tip=0.5)
    # the plait among them, tied with a ribbon, a tuft below the tie
    braid(loose, spline([(140, 100), (142, 124), (140.5, 148), (142.5, 170), (140.5, 190)], 6), 6.4, taper=0.12, period=5.2, part=lp)
    lock(loose, [(140.5, 196), (139.5, 204), (141.5, 212)], 5.0, lp, sheen=(), seed=12, tip=0.7, root=0.9)
    if ribbon_cloth:
        rp = loose.new_part()
        loose.put(poly([(136.5, 189.5), (144.5, 189.5), (144.5, 195), (136.5, 195)]), ribbon_cloth, 2, rp)
        loose.put(poly([(136.5, 189.5), (144.5, 189.5), (144.5, 191), (136.5, 191)]), ribbon_cloth, 1, rp)
        for pts, tone in (([(136.5, 193), (132, 199), (133.5, 206), (137.5, 196)], 2), ([(144.5, 193), (148.5, 200), (146, 207), (143, 196)], 3)):
            loose.put(poly(pts), ribbon_cloth, tone, rp)
    return back, front, loose


# --------------------------------------------------------------------------- Farah
def _curl_flow(x, y):
    return (math.sin(x / 3.6 + y / 5.0) * 1.4, math.cos(x / 4.3 - y / 3.7) * 1.4 + 0.25)


def wavy(p0, p1, amp, waves, phase=0.0, grow_=0.0):
    """Points from p0 to p1 swinging from side to side `waves` times: a curl's path."""
    p0, p1 = np.array(p0, float), np.array(p1, float)
    d = p1 - p0
    n = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-9)
    out = []
    steps = max(4, int(waves * 4))
    for i in range(steps + 1):
        t = i / steps
        out.append(tuple(p0 + d * t + n * amp * (1 + grow_ * t) * math.sin(phase + t * waves * math.pi * 2)))
    return out


def farah(rng, ribbon_cloth=None):
    """Dark curls, parted off-centre: waves over the crown, then ringlets falling by her
    face, over her shoulders and down her back."""
    back = Canvas()
    bp = back.new_part()
    behind = ellipse(98, 68, 43, 47) | poly([(56, 64), (48, 110), (44, 150), (48, 176), (88, 172), (88, 100)]) \
        | poly([(138, 64), (148, 110), (153, 150), (150, 178), (108, 172), (108, 100)])
    mass(back, behind, bp, light=-0.14, flow=_curl_flow, rng=rng, spacing=6)
    for k, (p0, p1) in enumerate([((54, 86), (41, 168)), ((147, 84), (160, 176)), ((50, 110), (46, 184)), ((152, 112), (156, 190))]):
        lock(back, wavy(p0, p1, 4.0, 3.5, phase=k * 1.3), 10, bp, sheen=(0.14, 0.42, 0.7), light=-0.12, seed=20 + k, tip=0.2, root=0.7)
    front = Canvas()
    fp = front.new_part()
    part_x = 104.0
    hl = lambda x: 51.0 + 0.010 * (x - part_x) ** 2 + np.clip(part_x - 8 - x, 0, None) * 0.08
    cap = (outer_cap(vol_top=7.5, vol_side=6.0, bottom=90) & ellipse(98, 68, 42, 50)) \
        & ~face_open(hl, temple=(69, 122), wide=(65.5, 130.5), side_low=90)
    mass(front, cap, fp, light=0.0)
    # waves from the parting over the crown, to the far side and to the near
    lock(front, wavy((102, 23), (56, 66), 3.0, 2.5, 0.4), 13, fp, sheen=(0.2, 0.6), light=-0.05, seed=1, tip=0.2)
    lock(front, wavy((104, 30), (60, 70), 3.0, 2.5, 2.2), 12, fp, sheen=(0.22, 0.62), seed=2, tip=0.2)
    lock(front, wavy((105.5, 39), (64, 76), 2.6, 2.5, 0.9), 10.5, fp, sheen=(0.2, 0.6), light=0.04, seed=3, tip=0.25)
    lock(front, wavy((105, 24), (139, 70), 3.0, 2.5, 3.6), 13, fp, sheen=(0.2, 0.6), light=-0.08, seed=4, tip=0.2)
    lock(front, wavy((106.5, 32), (135, 74), 2.8, 2.5, 1.5), 11.5, fp, sheen=(0.22, 0.62), light=-0.03, seed=5, tip=0.2)
    lock(front, wavy((108, 41), (129.5, 74), 2.2, 2.0, 4.4), 8, fp, sheen=(0.3,), seed=6, tip=0.3)
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    # ringlets: behind the ear and over the near shoulder, longest furthest back
    for k, (p0, p1, w, light) in enumerate([((141, 66), (158, 172), 10.5, -0.10), ((138.5, 72), (150, 186), 10.5, -0.04),
                                            ((137.5, 96), (141, 178), 9.5, 0.0), ((135.5, 108), (133, 160), 7.0, 0.05)]):
        lock(loose, wavy(p0, p1, 4.4, 3.5 if k < 3 else 2.5, phase=k * 2.0 + 0.5, grow_=0.25), w, lp, sheen=(0.13, 0.41, 0.69, 0.93),
             light=light, seed=30 + k, tip=0.16, root=0.45)
    # and on the far side, with one that frames her face
    for k, (p0, p1, w, light) in enumerate([((58, 62), (42, 170), 10.5, -0.10), ((60.5, 66), (49, 180), 10.5, -0.02),
                                            ((63.5, 80), (60.5, 138), 6.5, 0.05)]):
        lock(loose, wavy(p0, p1, 4.4, 3.5 if k < 2 else 2.5, phase=k * 2.3 + 2.0, grow_=0.25), w, lp, sheen=(0.13, 0.41, 0.69, 0.93),
             light=light, seed=40 + k, tip=0.16, root=0.45)
    return back, front, loose


# --------------------------------------------------------------------------- Kaede
KNOT = (126.0, 33.0)


def kaede(rng, ribbon_cloth=None):
    """Black, straight and glossy: parted in the middle, the top of it caught up in a knot
    at the back of her crown (pinned, with her brush through it), the rest falling straight
    behind her shoulders and over the near one, cut square by her cheeks."""
    back = Canvas()
    knot, kp = coil(back, KNOT[0], KNOT[1], 11.5, 10.5, rng, width=5.0, lift=0.34)
    bp = back.new_part()
    behind = ellipse(97.5, 68, 38.5, 45) | poly([(62, 64), (58, 110), (56, 150), (56, 176), (88, 172), (88, 100)]) \
        | poly([(132, 64), (137, 110), (140, 150), (141, 178), (108, 172), (108, 100)])
    mass(back, behind, bp, light=-0.2, flow=lambda x, y: ((x - 97) / 300, 1.0), rng=rng, spacing=6)
    front = Canvas()
    fp = front.new_part()
    part_x = AXIS + 4
    hl = lambda x: 50.5 + 0.011 * (x - part_x) ** 2
    cap = (outer_cap(vol_top=4.6, vol_side=3.6, bottom=90) & ellipse(97.5, 68, 38.5, 47.5)) \
        & ~face_open(hl, temple=(69.5, 121.5), wide=(65.5, 130), side_low=92)
    mass(front, cap, fp, light=0.16)
    # smooth from the parting down each side; the sheen lies in a band across them
    for k, pts in enumerate([[(90, 23), (75, 28), (65.5, 44), (62, 64), (61.5, 82)], [(91, 29), (78, 34), (68.5, 48), (64.5, 66), (63.5, 82)],
                             [(92, 37), (82, 41), (74, 51), (69.5, 62)]]):
        lock(front, pts, [13, 11, 8][k], fp, sheen=(0.36,), light=0.10 + 0.03 * k, seed=k, tip=0.2, strands=4)
    for k, pts in enumerate([[(93, 23), (111, 26), (124.5, 40), (131, 60), (132.5, 82)], [(93.5, 29), (109, 32), (121.5, 45), (127.5, 62), (129.5, 82)],
                             [(94, 37), (105, 40), (114, 49), (120.5, 60)]]):
        lock(front, pts, [13, 11, 8][k], fp, sheen=(0.36,), light=0.04 + 0.03 * k, seed=3 + k, tip=0.2, strands=4)
    under_shadow(front)
    loose = Canvas()
    lp = loose.new_part()
    # straight falls, the near one forward over the shoulder; then the locks cut square by her cheeks
    lock(loose, [(137, 68), (142.5, 110), (145.5, 160), (145, 206), (143, 224)], 13, lp, sheen=(0.3, 0.7), light=0.02, seed=7, tip=0.08,
         root=0.4, strands=4)
    lock(loose, [(135.5, 86), (138, 124), (138.5, 170), (137, 214)], 11, lp, sheen=(0.28, 0.68), light=0.08, seed=8, tip=0.08, root=0.5,
         strands=4)
    lock(loose, [(60.5, 66), (55, 110), (52, 160), (51.5, 204)], 12, lp, sheen=(0.3, 0.7), light=0.04, seed=9, tip=0.08, root=0.4, strands=4)
    lock(loose, [(64, 62), (62, 92), (62.5, 126)], 7.5, lp, sheen=(0.45,), light=0.16, seed=10, root=0.7, blunt=True, strands=4)
    lock(loose, [(128.5, 62), (130.5, 92), (130, 128)], 7.5, lp, sheen=(0.45,), light=0.10, seed=11, root=0.7, blunt=True, strands=4)
    return back, front, loose


def pin(metal="wood", stone="jade", dangle=None):
    """Kaede's hairpin, through the knot: a stick with a bead at its end."""
    cv = Canvas()
    p = cv.new_part()
    kx, ky = KNOT
    d, along, side = path_dist([(kx - 9, ky + 2), (kx + 22, ky - 7)])
    m = (d <= 1.2) & ~((along > 0.16) & (along < 0.56))          # it passes behind the knot's coil
    cv.put(m, metal, np.where(side < 0, 1, 3), p)
    cv.put(ellipse(kx + 23, ky - 7.5, 2.6, 2.6), stone, 2, p)
    cv.px(kx + 22, ky - 8.5, stone, 0, p); cv.px(kx + 24, ky - 6.5, stone, 3, p)
    if dangle:
        dp = cv.new_part(False)
        for k in range(1, 9):
            cv.px(kx + 20, ky - 6 + k, dangle, 1 if k % 3 else 3, dp)
        cv.put(ellipse(kx + 20.5, ky + 5, 1.8, 2.2), stone, 2, dp)
    return cv


STYLES = {"edda": edda, "farid": farah, "kaede": kaede}
