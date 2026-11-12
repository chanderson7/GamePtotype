"""Hair and beards as locks: clumps that follow a flow over a shape, each shaded round with a
dark parting edge and a band of sheen, as hair is painted in pixel portraits."""
import math
import numpy as np
from canvas import *
from face import CX, AXIS, TOP, HAIR_Y, EYE_Y, NOSE_Y, MOUTH_Y, MOUTH_X, HEADS, rows_of


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
    return np.clip(0.62 - (x - CX) / 55 - (y - 26) / 70, 0, 1)


def locks(cv, mask, flow, seeds, width=4.5, light=lit, sheen=None, rng=None, max_len=60, part=None,
          taper=0.5, edge=0.72, order=None, mat="hair", fill=3):
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
        for i in range(len(L) - 1):
            a, b = L[i], L[i + 1]
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


# --------------------------------------------------------------------------- shapes
def outer_cap(lady, vol_top=2.6, vol_side=1.6, bottom=54):
    """The head's outline grown by the hair's volume, from the crown down to `bottom`."""
    L, R, _ = rows_of("f_round" if lady else "m_broad")
    m = np.zeros((H, W), bool)
    for y in range(TOP - 6, bottom):
        yy = max(y, TOP)
        vol = vol_top if y < 30 else vol_side
        l, r = L[yy] + vol, R[yy] + vol
        if y < TOP + 2:
            shrink = (TOP + 2 - y) * 2.3
            l, r = l - shrink, r - shrink
        if l > 0 and r > 0:
            m[y, int(CX - l):int(CX + r) + 1] = True
    return m


def hairline(recede=0.012, base=30.5, part=AXIS):
    return lambda x: base + recede * (x - part) ** 2


def face_open(hl, temple=(43.5, 75), side_low=58, wide=(40, 81)):
    """The part of the head the hair leaves bare: forehead under the hairline, down the cheeks."""
    return poly([(wide[0], side_low), (wide[0] + 1.5, 46), (temple[0], 38)] +
                [(x, hl(x)) for x in np.linspace(temple[0] + 2.5, temple[1] - 4, 9)] +
                [(temple[1], 37), (wide[1] - 2.5, 44), (wide[1], side_low), (95, 100), (25, 100)])


SHEEN_TOP = lambda x, y: np.exp(-(((y - 19 - 0.004 * (x - CX) ** 2) / 2.6) ** 2))


# --------------------------------------------------------------------------- men
def swept(rng, recede=0.012, vol=2.6, width=5.5):
    cv = Canvas()
    cap = outer_cap(False, vol_top=vol) & ~face_open(hairline(recede))
    locks(cv, cap, lambda x, y: ((x - CX) / 22 * 0.9, -1.0), seeds_in(cap, 4, rng), width=width, sheen=SHEEN_TOP,
          rng=rng, max_len=40, order=lambda x, y: y)
    return cv


def crop(rng):
    cv = Canvas()
    cap = outer_cap(False, vol_top=1.4, vol_side=1.0) & ~face_open(hairline(0.006, 30))
    locks(cv, cap, lambda x, y: ((x - CX) / 30, -1.0), seeds_in(cap, 3, rng), width=3.4, sheen=SHEEN_TOP,
          rng=rng, max_len=7, order=lambda x, y: y, taper=0.8)
    return cv


def side_part(rng):
    """Parted on the near side, swept across the brow toward the far temple."""
    cv = Canvas()
    part = 67.0
    hl = lambda x: 30.5 + 0.010 * (x - 58) ** 2 + np.clip(58 - x, 0, None) * 0.18
    cap = outer_cap(False, vol_top=3.0) & ~face_open(hl, temple=(43, 76))
    def flow(x, y):
        if x < part:
            return (-1.0, 0.55 + (y - 20) / 22)
        return (0.5, 1.0)
    locks(cv, cap, flow, seeds_in(cap, 4, rng), width=5.0, sheen=lambda x, y: np.exp(-(((y - 21) / 2.5) ** 2)),
          rng=rng, max_len=45, order=lambda x, y: -abs(x - part))
    return cv


def receding(rng):
    """Bald on top, kept short at the sides and back."""
    cv = Canvas()
    cap = outer_cap(False, vol_top=1.2, vol_side=2.6) & ~face_open(hairline(0.012, 31), wide=(41, 79.5))
    top = ellipse(CX - 0.5, 21, 20.5, 12.5)
    cap &= ~top
    locks(cv, cap, lambda x, y: (np.sign(x - CX) * 0.8, -1.0), seeds_in(cap, 3, rng), width=3.6, rng=rng, max_len=10)
    return cv


def curls(rng):
    cv = Canvas()
    cap = outer_cap(False, vol_top=3.4, vol_side=2.2) & ~face_open(hairline(0.010, 30))
    locks(cv, cap, lambda x, y: (math.sin(x / 2.2 + y / 3.1) * 1.4, math.cos(x / 2.7 - y / 2.3) * 1.4 - 0.3),
          seeds_in(cap, 3, rng), width=3.2, rng=rng, max_len=6, taper=0.7, sheen=SHEEN_TOP)
    return cv


def long_male(rng):
    """Loose to the shoulders, parted in the middle."""
    back = Canvas()
    m = poly([(40, 28), (36, 52), (33, 76), (31, 96), (38, 100), (82, 100), (89, 96), (87, 76), (84, 52), (80, 28)])
    part_x = AXIS + 2
    locks(back, m, lambda x, y: (np.sign(x - part_x + 0.01) * 0.12, 1.0), seeds_in(m, 4, rng), width=5.0,
          light=lambda x, y: lit(x, y) * 0.6, rng=rng, max_len=60)
    front = Canvas()
    cap = outer_cap(False, vol_top=2.6) & ~face_open(hairline(0.014, 31, part_x), temple=(44, 74))
    far = poly([(37, 40), (42, 44), (42.5, 60), (41.5, 80), (39, 94), (34, 96), (33, 80), (34, 60)])
    near = poly([(83, 40), (79, 44), (80, 60), (82, 80), (85, 96), (90, 94), (88, 70), (86, 50)])
    mm = cap | far | near
    def flow(x, y):
        k = np.clip((40 - y) / 16, 0.1, 1.6)
        return (np.sign(x - part_x + 0.01) * k, 1.0)
    locks(front, mm, flow, seeds_in(mm, 4, rng), width=5.0, sheen=SHEEN_TOP, rng=rng, max_len=80,
          order=lambda x, y: -abs(x - part_x))
    return back, front


def topknot(rng, shaved=False):
    """Oiled back to a knot at the crown; the queue folded forward over the top."""
    cv = Canvas()
    hl = hairline(0.006, 30.5)
    cap = outer_cap(False, vol_top=1.6, vol_side=1.2) & ~face_open(hl)
    if shaved:
        pate = poly([(43, 31), (45, 22), (52, 16), (60, 14.5), (68, 16), (75, 22), (77, 31)])
        cap &= ~pate
    locks(cv, cap, lambda x, y: ((x - CX) / 18, -1.0), seeds_in(cap, 3, rng), width=4.0,
          sheen=lambda x, y: np.exp(-(((y - 20 - 0.004 * (x - CX) ** 2) / 2.0) ** 2)) * 1.3, rng=rng, max_len=40,
          order=lambda x, y: y)
    p = cv.new_part()
    if shaved:
        q = poly([(55, 22), (55, 13), (57, 9), (61, 8.5), (63.5, 11), (63.5, 22), (61.5, 26), (57, 26)])
        val = 0.5 - (XX - 59) / 9 + np.exp(-(((YY - 14) / 2.0) ** 2)) * 0.35
    else:
        q = poly([(53.5, 15), (53.5, 9), (55.5, 5.5), (59, 4), (62.5, 5.5), (64, 9), (63.5, 15)])
        val = 0.5 - (XX - 58.5) / 10 + np.exp(-(((YY - 7.5) / 1.6) ** 2)) * 0.35
    cv.put(q, "hair", tones(val, cuts=(0.92, 0.72, 0.5, 0.3)), p)
    tie = cv.new_part()
    ty = 12 if not shaved else 22
    for x in range(54 if not shaved else 55, 64):
        cv.px(x, ty, "white", 1, tie); cv.px(x, ty + 1, "white", 2, tie)
    return cv


# --------------------------------------------------------------------------- women
def long_lady(rng, waves=True, tie=False):
    """Parted in the middle and falling past the shoulders: a mass behind, and the crown and
    the curtains that frame the face in front."""
    back = Canvas()
    part_x = AXIS + 2
    wave = (lambda y: 0.45 * math.sin(y / 6.0)) if waves else (lambda y: 0.0)
    m = poly([(40, 26), (35, 50), (31, 80), (26, 108), (24, 124), (30, 131), (36, 127), (42, 134), (50, 130),
              (70, 130), (78, 134), (85, 128), (91, 132), (96, 124), (94, 108), (89, 80), (85, 50), (80, 26)])
    if not waves:
        m = poly([(40, 26), (36, 50), (33, 80), (30, 108), (29, 128), (36, 134), (84, 134), (91, 128), (90, 108),
                  (87, 80), (84, 50), (80, 26)])
    locks(back, m, lambda x, y: (np.sign(x - part_x + 0.01) * 0.15 + wave(y), 1.0), seeds_in(m, 4, rng), width=5.5,
          light=lambda x, y: lit(x, y) * 0.6, rng=rng, max_len=80)
    front = Canvas()
    cap = outer_cap(True, vol_top=2.8, vol_side=2.8, bottom=46) & ~face_open(
        lambda x: 31 + 0.016 * (x - part_x) ** 2, temple=(44, 74), wide=(42.5, 80), side_low=100)
    if waves:
        far = poly([(36, 40), (42.5, 44), (43.5, 60), (43.5, 80), (41.5, 98), (38, 106), (35, 101), (32, 108), (30, 96),
                    (31, 80), (33, 60)])
        near = poly([(84, 40), (78.5, 44), (79.5, 60), (81, 80), (83.5, 98), (86, 114), (88.5, 124), (91, 117), (94, 122),
                     (95, 110), (92, 96), (89, 72), (87, 50)])
    else:
        far = poly([(36, 40), (42.5, 44), (43.5, 60), (43.5, 80), (42, 100), (34, 104), (32, 80), (33, 60)])
        near = poly([(84, 40), (78.5, 44), (79.5, 60), (81, 80), (83, 100), (86, 122), (93, 122), (91, 96), (89, 72), (87, 50)])
    mm = cap | far | near
    def flow(x, y):
        k = np.clip((40 - y) / 16, 0.12, 1.6)
        return (np.sign(x - part_x + 0.01) * k + wave(y) * (y > 44), 1.0)
    locks(front, mm, flow, seeds_in(mm, 4, rng), width=5.0, sheen=lambda x, y: np.exp(-(((y - 22 - 0.006 * (x - part_x) ** 2) / 2.6) ** 2)),
          rng=rng, max_len=90, order=lambda x, y: -abs(x - part_x))
    return back, front


def sleek(rng, vol=1.8):
    """Combed back from the face, smooth."""
    cv = Canvas()
    part_x = AXIS + 2
    cap = outer_cap(True, vol_top=vol, vol_side=1.4, bottom=50) & ~face_open(
        lambda x: 31 + 0.014 * (x - part_x) ** 2, temple=(44, 74), wide=(42.5, 80), side_low=52)
    locks(cv, cap, lambda x, y: ((x - part_x) / 20 * 1.2, -0.6), seeds_in(cap, 4, rng), width=4.6,
          sheen=lambda x, y: np.exp(-(((y - 21 - 0.005 * (x - part_x) ** 2) / 2.2) ** 2)), rng=rng, max_len=40,
          order=lambda x, y: y)
    return cv


def braid(cv, path, width, rng, taper=0.35):
    """A plait: overlapping lobes along a path, each lit on its upper side."""
    p = cv.new_part()
    d, along, side = path_dist(path)
    total = np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.array(path, float), axis=0), axis=1))][-1]
    wid = width / 2 * (1 - taper * along)
    m = d <= wid
    s = along * total / 4.4
    lobe = (s + side * 0.5) % 1.0
    val = 0.95 - lobe * 0.7 + 0.12 * (side < 0) - d / np.maximum(wid, 0.5) * 0.25
    t = tones(val, cuts=(0.92, 0.7, 0.48, 0.28))
    t = np.where((lobe > 0.84) | (d > wid - 0.8), 4, t)
    cv.put(m, "hair", t, p)
    return m


def braid_crown(rng):
    cv = sleek(rng, vol=1.2)
    braid(cv, [(81, 38), (79, 27), (71, 18.5), (60, 15.5), (49, 17.5), (41, 25), (39, 35)], 9.0, rng, taper=0.1)
    return cv


def side_braid(rng):
    cv = sleek(rng)
    braid(cv, [(80, 46), (83, 60), (85, 78), (86, 96), (87, 112), (88, 126)], 8.0, rng, taper=0.45)
    p = cv.new_part()
    for x in range(85, 91):
        cv.px(x, 124, "gold", 1, p); cv.px(x, 125, "gold", 3, p)
    return cv


def bun(rng):
    back = Canvas()
    m = ellipse(81, 24, 9.5, 9)
    locks(back, m, lambda x, y: (-(y - 24), (x - 81)), seeds_in(m, 3, rng), width=4.0, rng=rng, max_len=30)
    return back, sleek(rng)


def shimada(rng):
    """Raised at the front, wings at the sides, a loop at the top; a comb and pins."""
    back = Canvas()
    loop = ellipse(61, 10, 12.5, 6.5)
    locks(back, loop, lambda x, y: (1.0, (x - 61) * 0.05), seeds_in(loop, 3, rng), width=4.4, rng=rng, max_len=30,
          sheen=lambda x, y: np.exp(-(((y - 7) / 1.8) ** 2)))
    front = Canvas()
    part_x = AXIS + 2
    cap = outer_cap(True, vol_top=1.6, vol_side=1.4, bottom=50) & ~face_open(
        lambda x: 31.5 + 0.012 * (x - part_x) ** 2, temple=(44, 74), wide=(42.5, 80), side_low=52)
    bulb = ellipse(59, 22, 15, 8.5)
    wings = ellipse(39, 38, 5.5, 10) | ellipse(82.5, 38, 6, 11)
    m = (cap | bulb | wings) & ~face_open(lambda x: 31.5 + 0.012 * (x - part_x) ** 2, temple=(44, 74),
                                          wide=(42.5, 80), side_low=52)
    m |= wings & (YY > 30)
    locks(front, m, lambda x, y: ((x - part_x) / 18, -1.0) if y < 30 else (0.0, -1.0), seeds_in(m, 4, rng),
          width=4.8, sheen=lambda x, y: np.exp(-(((y - 19) / 2.2) ** 2)), rng=rng, max_len=40, order=lambda x, y: y)
    return back, front


# --------------------------------------------------------------------------- beards
def beard_outline(head, drop=7, mouth_gap=True):
    """The jaw from ear to ear, a little outside the face, down past the chin by `drop`."""
    L, R, chin = rows_of(head)
    ys = np.arange(53, chin - 2)
    right = [(CX + R[y] + 0.6, y) for y in ys]
    left = [(CX - L[y] - 0.6, y) for y in ys[::-1]]
    bottom = [(CX + R[chin - 3] * 0.8, chin + drop * 0.55), (CX + 2, chin + drop), (CX - 4, chin + drop),
              (CX - L[chin - 3] * 0.8, chin + drop * 0.55)]
    return right + bottom + left


def beard(style, head, rng):
    cv = Canvas()
    mx, my = MOUTH_X, MOUTH_Y
    L, R, chin = rows_of(head)
    top = [(CX - L[53] - 0.5, 53), (43, 60), (47, 65.5), (mx - 7.5, my + 0.5), (mx - 6, my + 3.2), (mx - 2.5, my + 4.0),
           (mx + 3, my + 4.0), (mx + 7, my + 3.2), (mx + 8.5, my + 0.5), (70, 65), (76, 60), (CX + R[53] + 0.5, 53)]
    must = poly([(mx - 9, my + 1.5), (mx - 7.5, my - 1.5), (mx - 3.5, my - 3.3), (mx - 0.5, my - 3.2),
                 (mx + 0.5, my - 3.2), (mx + 3.5, my - 3.3), (mx + 8, my - 1.5), (mx + 9.5, my + 1.5),
                 (mx + 6, my - 0.3), (mx + 0.5, my - 1.4), (mx - 0.5, my - 1.4), (mx - 5.5, my - 0.3)])
    mflow = lambda x, y: (np.sign(x - mx + 0.01) * 1.0, 0.55)
    if style in ("full", "long", "short"):
        drop = {"full": 7, "long": 18, "short": 3}[style]
        out = beard_outline(head, drop)
        jaw = poly(out)
        region = jaw & ~poly(top[:1] + top + top[-1:] + [(CX + R[53] + 3, 40), (CX - L[53] - 3, 40)])
        region &= ~ellipse(mx, my + 0.8, 7.0, 2.6)
        if style == "short":
            # close along the jaw: keep only a band near the outline and the chin
            inner = poly([(CX - L[56] + 4.5, 56), (CX - L[66] + 4, 66), (mx - 4, my + 5.5), (mx + 4, my + 5.5),
                          (CX + R[66] - 4, 66), (CX + R[56] - 4.5, 56)])
            region &= ~(inner & (YY < my + 5))
        if style == "long":
            region |= poly([(CX - 12, chin), (CX + 12, chin), (CX + 6, chin + 22), (CX + 1, chin + 26), (CX - 5, chin + 21)])
        flow = lambda x, y: ((x - CX) / 40 + 0.12 * math.sin(y / 3.0), 1.0)
        locks(cv, region, flow, seeds_in(region, 3, rng), width=4.2 if style != "short" else 3.0,
              sheen=lambda x, y: np.exp(-(((y - (chin - 3)) / 3) ** 2)) * 0.6, rng=rng,
              max_len=16 if style != "long" else 30, order=lambda x, y: y)
        locks(cv, must, mflow, seeds_in(must, 2, rng), width=3.2, rng=rng, max_len=12)
    elif style == "goatee":
        g = poly([(mx - 5, my + 3), (mx + 6, my + 3), (mx + 6, my + 8), (mx + 3, chin + 4), (mx - 2, chin + 4), (mx - 5, my + 8)])
        g &= ~ellipse(mx, my + 0.8, 6.0, 2.4)
        locks(cv, g, lambda x, y: (0.0, 1.0), seeds_in(g, 2, rng), width=3.4, rng=rng, max_len=14)
        locks(cv, must, mflow, seeds_in(must, 2, rng), width=3.0, rng=rng, max_len=12)
    elif style == "moustache":
        big = poly([(mx - 11, my + 3.5), (mx - 8, my - 1.5), (mx - 3.5, my - 3.6), (mx + 3.5, my - 3.6), (mx + 8.5, my - 1.5),
                    (mx + 11.5, my + 3.5), (mx + 7, my + 0.2), (mx + 0.5, my - 1.4), (mx - 0.5, my - 1.4), (mx - 6.5, my + 0.2)])
        locks(cv, big, mflow, seeds_in(big, 2, rng), width=3.4, rng=rng, max_len=14)
    elif style == "thin":
        p = cv.new_part()
        for dx in range(-6, 7):
            if dx == 0:
                continue
            y = my - 2 + (0 if abs(dx) < 4 else (abs(dx) - 3) * 0.7)
            cv.px(mx + dx, y, "hair", 3 if abs(dx) < 5 else 2, p)
            if abs(dx) < 4:
                cv.px(mx + dx, y - 1, "hair", 2, p)
        tuft = poly([(mx - 2.5, my + 4), (mx + 3.5, my + 4), (mx + 2.5, my + 11), (mx + 0.5, my + 14), (mx - 1.5, my + 11)])
        locks(cv, tuft, lambda x, y: (0.0, 1.0), seeds_in(tuft, 2, rng), width=3.0, rng=rng, max_len=14, part=p)
    elif style == "stubble":
        out = beard_outline(head, 2)
        region = poly(out) & ~poly(top[:1] + top + top[-1:] + [(CX + R[53] + 3, 40), (CX - L[53] - 3, 40)])
        region &= ~ellipse(mx, my + 0.8, 6.5, 2.4)
        region |= must
        shade = region & (BAYER4[YY % 4, XX % 4] < np.where(must, 0.45, 0.22))
        cv.put(shade, "skin", 3, cv.new_part(False))
        cv.put(region & (BAYER4[YY % 4, XX % 4] < np.where(must, 0.2, 0.07)), "hair", 3)
    return cv
