"""Heads, necks, ears and the features (eyes, brows, nose, mouth) with their expressions.

As on the lords, the face is turned a little to the viewer's left and lit from the upper
left, and every head shares where the features sit. At this size an eye has a lid, a
crease, lashes, a ringed iris and a catchlight; lips are shaded; the nose is modelled.
"""
import math

import numpy as np

from canvas import *

CX, AXIS, TOP = 96.0, 88.0, 27
BROW_Y, EYE_Y, NOSE_Y, MOUTH_Y = 72, 80, 97, 108
EYES_X = {"far": 75.5, "near": 105.0}
MOUTH_X = 90.0

HEADS = {
    # rows: (y, half-width left (far side), half-width right (near side)); chin row last
    "oval":  [(27, 14.5, 17.5), (32, 23, 26.5), (38, 28, 31), (45, 30.5, 33.5), (58, 31.5, 34.5), (74, 31.5, 34.5),
              (86, 30, 33.5), (96, 27, 31), (106, 22.5, 27), (114, 17.5, 21.5), (120, 12.5, 15), (123, 9, 10.5), (125, 5.5, 7)],
    "heart": [(27, 14.5, 17.5), (32, 23, 26.5), (38, 28, 31), (45, 30.5, 33.5), (58, 31.5, 34.5), (74, 31.5, 34.5),
              (86, 29.5, 33), (96, 26, 30.5), (106, 21, 25.5), (114, 16, 19.5), (120, 11.5, 13.5), (123, 8, 9.5), (125, 5, 6)],
    "full":  [(27, 14.5, 17.5), (32, 23, 26.5), (38, 28, 31), (45, 30.5, 33.5), (58, 31.5, 34.5), (74, 31.5, 34.5),
              (86, 30.5, 34), (96, 28.5, 32.5), (106, 24.5, 28.5), (114, 19.5, 23), (120, 14.5, 17), (123, 10.5, 12), (125, 6.5, 8)],
}


def rows_of(head):
    r = np.array(HEADS[head], float)
    ys = np.arange(H)
    return np.interp(ys, r[:, 0], r[:, 1]), np.interp(ys, r[:, 0], r[:, 2]), int(r[-1, 0])


def head_mask(head):
    L, R, chin = rows_of(head)
    m = np.zeros((H, W), bool)
    for y in range(TOP, chin + 1):
        m[y, int(round(CX - L[y])):int(round(CX + R[y])) + 1] = True
    return m


def head(shape, freckles=0, rng=None, blush=0.9):
    """Face and skull, shaded as a rounded form turned to the viewer's left."""
    cv = Canvas()
    p = cv.new_part()
    m = head_mask(shape)
    L, R, chin = rows_of(shape)
    xs, ys = XX + 0.5, YY + 0.5
    hw = np.where(xs < CX, L[YY], R[YY])
    u = np.clip((xs - CX) / np.maximum(hw, 1), -1, 1)
    u = np.where(u < 0, -(np.abs(u) ** 0.8), np.abs(u) ** 1.15)
    v = np.clip((ys - 80) / 58, -1, 1)
    nz = np.sqrt(np.clip(1 - u ** 2 * 0.85 - v ** 2 * 0.35, 0.02, 1))
    n = np.stack([u * 0.95, v * 0.55, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    val = (n @ LIGHT) * 0.75 + 0.25
    ex0, ex1 = EYES_X["far"], EYES_X["near"]
    # the sockets, the brow bone over them
    val = val - blob(ex0, EYE_Y - 1, 12, 7, 0.20) - blob(ex1, EYE_Y - 1, 13, 7, 0.15)
    val = val + blob(ex0 - 1.5, EYE_Y - 10.5, 10, 3.6, 0.07) + blob(ex1 - 1.5, EYE_Y - 10.5, 10, 3.6, 0.05)
    # the nose: its bridge lit, its near side and underside in shade
    val = val + blob(AXIS - 1.5, EYE_Y + 8, 2.4, 10, 0.10)
    val = val - blob(AXIS + 5, EYE_Y + 11, 3.2, 8, 0.20)
    val = val - blob(AXIS + 1, NOSE_Y + 3, 6.5, 2.0, 0.20)
    # cheeks: the far one catches the light, the near one turns away
    val = val + blob(ex0 - 6, NOSE_Y - 3, 8, 6.5, 0.07)
    val = val + blob(ex1 + 3, NOSE_Y - 5, 7, 4, 0.04)
    val = val - blob(ex1 + 14, NOSE_Y + 6, 10, 9, 0.09)
    # under the lower lip, the chin's own light, the jaw's shadow on the near side
    val = val - blob(MOUTH_X, MOUTH_Y + 7, 7, 2.2, 0.16)
    val = val + blob(MOUTH_X - 1.5, chin - 7, 6.5, 3.6, 0.07)
    val = val - blob(CX + 14, chin - 6, 12, 5, 0.08)
    cv.put(m, "skin", tones(val, dither=0.012), p)
    # blush on the cheeks and the tip of the nose, dithered in at its edges
    bl = blob(ex0 - 3, NOSE_Y - 2, 8, 5.2) + blob(ex1 + 5, NOSE_Y - 2, 9.5, 5.2) + blob(AXIS, NOSE_Y - 1, 3, 2.2, 0.6)
    bl = np.clip(bl, 0, 1) * blush
    on = m & ((bl > 0.5) | ((bl > 0.42) & ((XX + YY) % 2 == 0)))
    cv.mat[on] = mat_id("blush")
    if freckles:
        # a scatter over the nose and the tops of the cheeks, clear of the blush's edge
        rng = rng or np.random.default_rng(3)
        zone = m & ~on & ~grow(on, 1) & (blob(AXIS - 1, NOSE_Y - 9, 27, 7) > 0.12) & (YY > EYE_Y + 6)
        ys_, xs_ = np.where(zone)
        taken = np.zeros((H, W), bool)
        for i in rng.permutation(len(xs_)):
            x, y = xs_[i], ys_[i]
            if taken[y, x] or freckles <= 0:
                continue
            cv.tone[y, x] = min(4, cv.tone[y, x] + 1)
            taken |= ellipse(x + 0.5, y + 0.5, 2.6, 2.6)
            freckles -= 1
    return cv


def neck(width=(13, 15), chin=125):
    """Her neck and the top of her chest, bare: clothes cover what they cover."""
    cv = Canvas()
    p = cv.new_part()
    x0, x1 = CX - width[0], CX + width[1]
    flare = np.clip(YY - 141, 0, None) * 0.9
    m = (YY >= chin - 19) & (YY <= 162) & (XX >= x0 - flare) & (XX <= x1 + flare)
    # shoulders and chest under what she wears
    bust = poly([(80, 141), (112, 141), (147, 154), (164, 168), (170, 256), (22, 256), (29, 168), (46, 154)])
    u = (XX - (x0 + x1) / 2) / ((x1 - x0) / 2)
    val = 0.56 - u * 0.24 - np.clip(1 - (YY - chin) / 10, 0, 1) * 0.36
    cv.put(m, "skin", tones(val, dither=0.02), p)
    cval = 0.62 - (XX - 96) / 150 - (YY - 142) / 260
    # the hollow of the throat and the collarbones
    cval = cval - blob(96, 147, 4, 3.5, 0.2)
    for sgn in (-1, 1):
        d, _, _ = path_dist([(96 + sgn * 6, 150), (96 + sgn * 22, 148), (96 + sgn * 40, 151)])
        cval = cval + np.exp(-(d / 1.3) ** 2) * 0.10 - np.exp(-((d - 2.5) / 1.5) ** 2) * 0.07 * (YY > 149)
    cv.put(bust & ~m, "skin", tones(cval, dither=0.02), p)
    return cv


def ear(shape, earring=None):
    """The near ear, with an earring if she wears one: (metal, gem) or None."""
    cv = Canvas()
    p = cv.new_part()
    L, R, _ = rows_of(shape)
    y = EYE_Y
    x = CX + R[y + 3]
    m = ellipse(x + 2.2, y + 7, 4.6, 10) & (XX + 0.5 >= x - 0.5)
    cv.put(m, "skin", 2, p)
    cv.put(ellipse(x + 2.8, y + 7.5, 2.2, 6.4) & m, "skin", 3)
    cv.put(ellipse(x + 3.6, y + 5, 1.3, 4.2) & m, "skin", 1)
    cv.put(ellipse(x + 2.4, y + 13.5, 2.2, 2.6) & m, "skin", 2)
    cv.px(x + 2, y + 9.5, "skin", 4); cv.px(x + 1.5, y + 8.5, "skin", 4)
    if earring:
        metal, stone = earring
        ep = cv.new_part(False)
        ex, ey = x + 2.5, y + 18
        cv.px(ex, ey, metal, 1, ep); cv.px(ex, ey + 1, metal, 2, ep)
        if stone:
            cv.put(ellipse(ex + 0.5, ey + 4.2, 1.8, 2.4), stone, 2, ep)
            cv.px(ex - 0.4, ey + 3.4, stone, 0, ep); cv.px(ex + 1, ey + 5, stone, 3, ep)
        else:
            cv.put(ellipse(ex + 0.5, ey + 3.6, 1.8, 1.8), metal, 2, ep)
            cv.px(ex - 0.2, ey + 3, metal, 0, ep)
    return cv


# --------------------------------------------------------------------------- eyes
EYES = {
    # w: width of the near eye; up/low: how far the lids open above and below the eye's line;
    # tilt: how much higher the outer corner sits; peak: where the upper lid is highest
    # (under 1: toward the inner corner; over 1: toward the outer); iris: its radius.
    "almond": dict(w=17, up=3.6, low=2.2, tilt=1.0, peak=1.0, iris=3.8),
    "round":  dict(w=17, up=3.9, low=2.4, tilt=0.6, peak=0.95, iris=3.9),
    "long":   dict(w=18, up=3.1, low=1.9, tilt=1.5, peak=1.15, iris=3.6),
}
def eye(which, shape, lid=0.0, gaze=(0.0, 0.0), cheek=0.0):
    """One eye. `lid`: how far the upper lid is down (0 open, 1 shut; under 0, wide); `gaze`:
    where the iris sits from its rest (pixels); `cheek`: how far a smile lifts the lower lid."""
    cv = Canvas()
    F = NO_LINE
    e = EYES[shape]
    st = {"lid": lid, "gaze": gaze, "cheek": cheek}
    near = which == "near"
    w = e["w"] if near else e["w"] - 2
    cx = EYES_X[which]
    x0 = int(round(cx - (w - 1) / 2)); x1 = x0 + w - 1
    y = EYE_Y
    closed = st["lid"] >= 0.999
    cheek = st.get("cheek", 0.0)

    def tt(x):
        t = (x - x0) / (w - 1)
        return t if near else 1 - t          # 0 at the inner corner, 1 at the outer

    def upper(t):
        return -e["up"] * math.sin(math.pi * min(1.0, t ** e["peak"])) ** 0.75 - e["tilt"] * t

    def lower(t):
        return (e["low"] - cheek) * math.sin(math.pi * t ** 0.9) ** 0.9 - e["tilt"] * t

    def px(x, yy, mat, tone):
        cv.px(x, yy, mat, tone, flag=F)

    step = 1 if near else -1
    outer_x = x1 if near else x0
    inner_x = x0 if near else x1
    tops, bots, rest_tops = {}, {}, {}
    for x in range(x0, x1 + 1):
        t = tt(x)
        yu, yl = y + upper(t), y + lower(t)
        rest_tops[x] = int(round(yu))
        yu = yu + max(st["lid"], -0.3) * (yl - yu + 1)
        tops[x], bots[x] = int(round(yu)), int(round(yl))
    gx, gy = st.get("gaze", (0.0, 0.0))
    icx = (x0 + x1) / 2 + 0.9 + gx
    icy = y + (upper(0.5) + lower(0.5)) / 2 + 0.2 + gy
    r = e["iris"]
    if closed:
        # the lashes rest along the lower lid; the lid above them is lit, the crease stays
        for x in range(x0, x1 + 1):
            t = tt(x)
            ly = int(round(y + lower(t) * 0.75 + 0.6))
            for yy in range(rest_tops[x] - 1, ly):
                px(x, yy, "skin", 1 if rest_tops[x] + 1 <= yy <= ly - 2 and 0.2 < t < 0.8 else 2)
            px(x, ly, "ink", 0 if t > 0.12 else 2)
            if t > 0.55:
                px(x, ly + 1, "ink", 2)
            if 0.1 < t < 0.93:
                px(x, rest_tops[x] - 3, "skin", 3)
        px(outer_x + step, int(round(y + lower(1.0) * 0.75 + 0.6)) + 1, "ink", 0)
        px(outer_x + 2 * step, int(round(y + lower(1.0) * 0.75 + 0.6)) + 2, "ink", 2)
        return cv
    for x in range(x0, x1 + 1):
        t = tt(x)
        top, bot = tops[x], bots[x]
        if top > bot:
            top = bot
        # the lid, from where it rests when open down to the lashes
        for yy in range(rest_tops[x] - 1, top - 1):
            px(x, yy, "skin", 1 if 0.25 < t < 0.75 and yy > rest_tops[x] - 1 else 2)
        for yy in range(top, bot + 1):
            d = math.hypot(x - icx, (yy - icy) * 1.05)
            if d <= r:
                if d <= 1.45:
                    m, tn = "ink", 1
                elif d > r - 1.05:
                    m, tn = "iris", 4 if yy < icy else 3
                elif yy <= top + 1:
                    m, tn = "iris", 3
                elif yy > icy + 0.4 and x < icx + 0.5:
                    m, tn = "iris", 0
                elif yy > icy - 0.5:
                    m, tn = "iris", 1
                else:
                    m, tn = "iris", 2
            else:
                shade = yy == top or t < 0.1 or t > 0.9
                m, tn = "eye", 2 if shade else 1
                if t > 0.82 and yy == top:
                    tn = 3
            px(x, yy, m, tn)
    # the catchlight, upper left of the pupil
    hx_, hy = int(round(icx - 1.7)), int(round(icy - 1.6))
    if st["lid"] < 0.5:
        hy = max(hy, tops.get(hx_, hy) + (0 if st["lid"] > 0.2 else 0))
        px(hx_, hy, "eye", 0)
        if st["lid"] < 0.2:
            px(hx_ + 1, hy, "eye", 0)
    # lashes along the upper lid, heavier toward the outer corner, with a flick past it
    for x in range(x0, x1 + 1):
        t = tt(x)
        ly = min(tops[x], bots[x]) - 1
        px(x, ly, "ink", 0)
        if t > 0.5:
            px(x, ly - 1, "ink", 0 if t > 0.78 else 2)
        if t < 0.08:
            px(x, ly, "ink", 2)
    oy = min(tops[outer_x], bots[outer_x]) - 1
    px(outer_x + step, oy - 1, "ink", 0); px(outer_x + step, oy, "ink", 0)
    px(outer_x + 2 * step, oy - 2, "ink", 0)
    px(outer_x, bots[outer_x], "ink", 0)
    # the crease above the lid
    if st["lid"] < 0.25:
        for x in range(x0, x1 + 1):
            t = tt(x)
            if 0.1 < t < 0.93:
                px(x, rest_tops[x] - 3 - (1 if st["lid"] < -0.05 else 0), "skin", 3)
    else:
        for x in range(x0, x1 + 1):
            t = tt(x)
            if 0.1 < t < 0.93:
                px(x, rest_tops[x] - 3, "skin", 3)
    # the lower lid: a line under the outer two thirds, softer toward the nose
    for x in range(x0, x1 + 1):
        t = tt(x)
        if 0.3 <= t <= 0.94:
            px(x, bots[x] + 1, "skin", 4)
        elif 0.1 < t < 0.3:
            px(x, bots[x] + 1, "skin", 3)
    if cheek:
        for x in range(x0 + 2, x1 - 1):
            px(x, bots[x] + 2, "skin", 3)
    px(inner_x, bots[inner_x], "blush", 3)
    return cv


# --------------------------------------------------------------------------- brows
BROWS = {
    # weight: how thick; arch: how high the arch; w: length of the near brow
    "soft":   dict(weight=0.95, arch=2.6, w=21),
    "arched": dict(weight=0.85, arch=3.6, w=21),
    "strong": dict(weight=1.25, arch=2.6, w=22),
    "fine":   dict(weight=0.72, arch=2.2, w=20),
}
# (lift, angle): lifted whole, and tipped (plus: the inner end up, as in worry)
BROW_MOODS = {"rest": (0.0, 0.0), "raised": (2.4, 0.0), "lifted": (1.2, 0.0), "stern": (-0.9, -0.5),
              "knit": (-0.6, -0.3), "worried": (1.0, 0.62), "sad": (1.4, 1.0)}


def brow(which, style, mood="rest", lift=0.0):
    """A tapered brow in the hair's darker shades: thickest toward the nose, arched, thinning out."""
    cv = Canvas()
    b = BROWS[style]
    near = which == "near"
    w = b["w"] if near else b["w"] - 2
    cx = EYES_X[which] + (1.0 if near else -1.0)
    up, angle = BROW_MOODS[mood]
    y0 = BROW_Y - up - lift
    for col in range(w):
        t = col / (w - 1)                               # 0 by the nose, 1 at the temple
        x = (cx - w / 2 + col + 0.5) if near else (cx + w / 2 - col - 0.5)
        # rising from the nose to its arch two thirds of the way out, then falling to the temple
        rise = math.sin(math.pi / 2 * t / 0.64) if t < 0.64 else 1 - 0.8 * ((t - 0.64) / 0.36) ** 1.5
        yc = y0 - b["arch"] * rise
        yc += -angle * (1 - t) * 3.2 + angle * 0.8
        thick = (3.5 - 2.4 * t ** 1.3) * b["weight"]
        if t < 0.08:
            thick *= 0.7
        rows = max(1, int(round(thick)))
        for k in range(rows):
            tone = 4 if k == 0 else (3 if k < rows - 1 or rows == 2 else 2)
            if t > 0.85:
                tone = max(tone - 1, 2) if k else 3
            cv.px(x, yc + 1 - k, "hair", tone, flag=NO_LINE)
    return cv


# --------------------------------------------------------------------------- nose
NOSES = {
    # L lit, H highlight, s shade, d dark (the nostrils), . untouched; 13 wide, from AXIS-6
    "fine": [".............",
             "......L..s...",
             "......L..s...",
             "......L..s...",
             "......L...s..",
             "......L...s..",
             "......L...s..",
             "......LL..s..",
             ".....LLL...s.",
             ".....LHH...s.",
             ".....LHH...ss",
             "..s..LLL....s",
             ".s....L...d.s",
             ".s.dd....ddds",
             "..sddd.s.dds.",
             "...sssssss..."],
    "straight": ["......L..s...",
                 "......L..s...",
                 "......L..s...",
                 "......L..s...",
                 "......L...s..",
                 ".....LL...s..",
                 ".....LL...s..",
                 ".....LLL..s..",
                 ".....LLL...s.",
                 ".....LHH...s.",
                 "....LLHH...ss",
                 ".ss..LLL....s",
                 ".s....L...d.s",
                 "s..ddd...dddd",
                 ".sdddd.s.dds.",
                 "..sssssssss.."],
    "soft": [".............",
             ".............",
             "......L..s...",
             "......L..s...",
             "......L..s...",
             "......L...s..",
             "......L...s..",
             "......LL..s..",
             ".....LLL..s..",
             ".....LHH...s.",
             ".....LHH...s.",
             "..s..LLL...s.",
             ".s....L...d.s",
             "..sdd....dds.",
             "...sdd.s.ds..",
             "....sssss...."],
}


def nose(style):
    cv = Canvas()
    tone = {"L": 1, "H": 0, "s": 3, "d": 4}
    rows = NOSES[style]
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch in tone:
                cv.px(AXIS - 6 + c, NOSE_Y - len(rows) + 3 + r, "skin", tone[ch], flag=NO_LINE)
    return cv


# --------------------------------------------------------------------------- mouth
MOUTHS = {
    # hw: half the mouth's width; up/low: how full each lip is
    "full":  dict(hw=10, up=3.3, low=4.6),
    "bow":   dict(hw=9, up=3.0, low=4.0),
    "fine":  dict(hw=9, up=2.5, low=3.5),
}
# curve: how far the corners lift (minus) or fall; near: extra lift of the near corner alone
# (a wry smile); wide: the mouth broadens; part: the lips open that many pixels (teeth show
# in a smile); press: the lips thin (held together).
MOUTH_MOODS = {
    "rest":    dict(curve=-0.3),
    "slight":  dict(curve=-0.9, wide=0.5),
    "wry":     dict(curve=-0.5, near=-1.6, wide=0.5),
    "smile":   dict(curve=-1.9, wide=1.5),
    "grin":    dict(curve=-2.2, wide=2.0, part=2),
    "flat":    dict(curve=0.0, press=0.6),
    "pursed":  dict(curve=0.1, press=0.3, wide=-1.0),
    "worried": dict(curve=0.9, press=0.2),
    "parted":  dict(curve=0.2, part=1),
}


def mouth(style, mood="rest"):
    cv = Canvas()
    F = NO_LINE
    m = MOUTHS[style]
    md = MOUTH_MOODS[mood]
    mx, my = int(round(MOUTH_X)), MOUTH_Y
    hw = int(round(m["hw"] + md.get("wide", 0)))
    press = md.get("press", 0.0)
    up, low = m["up"] * (1 - press * 0.5), m["low"] * (1 - press * 0.35)
    part = md.get("part", 0)
    smile = md.get("curve", 0) < -1.2

    def px(x, y, mat, tone):
        cv.px(x, y, mat, tone, flag=F)

    def line_y(dx):
        t = dx / hw
        lift = md.get("curve", 0.0) * abs(t) ** 2.2
        if dx > 0:
            lift += md.get("near", 0.0) * abs(t) ** 2
        # a smile dips a little in the middle of the lips
        return my + lift + (0.5 if smile and abs(t) < 0.35 else 0.0)

    for dx in range(-hw, hw + 1):
        t = abs(dx) / hw
        ly = int(round(line_y(dx)))
        # upper lip: a bow, dipped in the middle, tapering to the corners; it faces down, so darker
        tu = up * (1 - t ** 1.7)
        if abs(dx) <= 1:
            tu -= 0.9
        elif abs(dx) <= 3:
            tu += 0.2
        tu = int(round(max(0, tu)))
        for k in range(1, tu + 1):
            px(mx + dx, ly - k, "lip", 3 if dx > 1 or k == 1 else 2)
        # lower lip: fuller in the middle, lit on the far side
        tl = int(round(max(0, low * (1 - t ** 2.4) - (0.6 if t > 0.75 else 0))))
        for k in range(1, tl + 1):
            yy = ly + part + k
            tone = 2
            if dx > hw * 0.35:
                tone = 3
            elif k <= max(1, tl - 2) and dx < hw * 0.2:
                tone = 1
            if k == tl and tl > 1:
                tone = min(tone + 1, 3)
            px(mx + dx, yy, "lip", tone)
        # between the lips
        if part and abs(dx) < hw - 1:
            for k in range(part):
                if smile:
                    px(mx + dx, ly + k, "white", 1 if dx < hw * 0.3 else 2)
                else:
                    px(mx + dx, ly + k, "ink", 2)
            px(mx + dx, ly + part, "lip", 4)
            if smile:
                px(mx + dx, ly - 0, "white", 1 if dx < hw * 0.3 else 2)
        else:
            px(mx + dx, ly, "lip", 4)
    # the light on the lower lip
    hy = int(round(line_y(-2))) + part + 2
    px(mx - 3, hy, "lip", 0); px(mx - 2, hy, "lip", 0)
    # corners: a dimple of shade, and the cheek's crease in a smile
    for sgn in (-1, 1):
        cy = int(round(line_y(sgn * hw)))
        px(mx + sgn * (hw + 1), cy, "skin", 4)
        if md.get("curve", 0) < -0.6 or (sgn > 0 and md.get("near", 0) < -1):
            px(mx + sgn * (hw + 2), cy - 1, "skin", 3)
        if smile:
            px(mx + sgn * (hw + 3), cy - 2, "skin", 3); px(mx + sgn * (hw + 3), cy - 3, "skin", 3)
        if md.get("curve", 0) > 0.5:
            px(mx + sgn * (hw + 1), cy + 1, "skin", 3)
    # the shadow under the lower lip, and the groove above the upper
    base = int(round(line_y(0))) + part + int(round(low)) + 1
    for dx in range(-4, 5):
        px(mx + dx, base + (0 if abs(dx) < 3 else -1), "skin", 3)
    top = int(round(line_y(0))) - int(round(up)) - 1
    px(mx - 2, top, "skin", 3); px(mx + 2, top, "skin", 3); px(mx - 2, top - 1, "skin", 3); px(mx + 2, top - 1, "skin", 3)
    return cv
