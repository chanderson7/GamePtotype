"""Heads, necks, ears, age lines, and the hand-set features (eyes, brows, nose, mouth) with
their expressions. The face is turned a little to the viewer's left, lit from the upper left;
all heads share where the features sit, so any feature fits any head."""
import math
import numpy as np
from canvas import *

CX, AXIS, TOP, HAIR_Y, BROW_Y, EYE_Y, NOSE_Y, MOUTH_Y = 60.0, 55.0, 17, 31, 44, 50, 60, 67
EYES_X = {"far": 47.0, "near": 65.5}
MOUTH_X = 56.5

HEADS = {
    # rows: (y, half-width left (far side), half-width right (near side)); chin row last
    "m_square": [(17, 10, 12), (20, 15.5, 17.5), (24, 18.5, 20.5), (28, 19.5, 21.5), (36, 20, 22.5), (46, 20, 22.5),
                 (54, 19, 22), (60, 18, 21), (66, 16.5, 19.5), (71, 13.5, 16), (75, 9.5, 11.5), (78, 6, 7.5), (79, 3.5, 4.5)],
    "m_soft":   [(17, 10, 12), (20, 15.5, 17.5), (24, 18.5, 20.5), (28, 19.5, 21.5), (36, 20, 22.5), (46, 20, 22.5),
                 (54, 19, 22), (60, 17.5, 20.5), (66, 15, 18), (71, 11.5, 14), (75, 8, 9.5), (78, 4.5, 5.5), (79, 2.5, 3)],
    "m_lean":   [(17, 9.5, 11.5), (20, 14.5, 16.5), (24, 17.5, 19.5), (28, 18.5, 20.5), (36, 19, 21), (46, 19, 21),
                 (54, 18, 20.5), (60, 16.5, 19.5), (66, 14.5, 17), (71, 11, 13.5), (75, 8, 9.5), (78, 5, 6), (80, 2.5, 3)],
    "m_broad":  [(17, 10, 12), (20, 15.5, 17.5), (24, 18.5, 20.5), (28, 20, 22), (36, 20.5, 23), (46, 20.5, 23),
                 (54, 20, 23), (60, 19.5, 22.5), (66, 18.5, 21), (71, 16, 18), (75, 12, 13.5), (78, 8, 9), (79, 5, 6)],
    "f_oval":   [(17, 9, 11), (20, 14.5, 16.5), (24, 17.5, 19.5), (28, 19, 21), (36, 19.5, 21.5), (46, 19.5, 21.5),
                 (54, 18.5, 21), (60, 16.5, 19.5), (66, 13.5, 16.5), (71, 10, 12.5), (75, 6.5, 8), (77, 4, 5), (78, 2, 3)],
    "f_heart":  [(17, 9, 11), (20, 14.5, 16.5), (24, 17.5, 19.5), (28, 19, 21), (36, 19.5, 21.5), (46, 19.5, 21.5),
                 (54, 18, 20.5), (60, 15.5, 18.5), (66, 12, 14.5), (71, 8.5, 10.5), (75, 5, 6.5), (77, 2.5, 3.5), (78, 1.5, 2)],
    "f_round":  [(17, 9.5, 11.5), (20, 15, 17), (24, 18, 20), (28, 19.5, 21.5), (36, 20, 22), (46, 20, 22),
                 (54, 19.5, 21.5), (60, 18, 20.5), (66, 15.5, 18), (71, 12, 14), (75, 8, 9.5), (77, 5, 6), (78, 3, 3.5)],
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


def head(head):
    """Face and skull, shaded as a rounded form turned to the viewer's left."""
    cv = Canvas()
    lady = head.startswith("f_")
    p = cv.new_part()
    m = head_mask(head)
    L, R, chin = rows_of(head)
    xs, ys = XX + 0.5, YY + 0.5
    hw = np.where(xs < CX, L[YY], R[YY])
    u = np.clip((xs - CX) / np.maximum(hw, 1), -1, 1)
    u = np.where(u < 0, -(np.abs(u) ** 0.8), np.abs(u) ** 1.15)
    v = np.clip((ys - 50) / 36, -1, 1)
    nz = np.sqrt(np.clip(1 - u ** 2 * 0.85 - v ** 2 * 0.35, 0.02, 1))
    n = np.stack([u * 0.95, v * 0.55, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    val = (n @ LIGHT) * 0.75 + 0.25
    ex0, ex1 = EYES_X["far"], EYES_X["near"]
    val = val - blob(ex0, EYE_Y - 0.5, 7.5, 4.5, 0.22) - blob(ex1, EYE_Y - 0.5, 8, 4.5, 0.16)
    val = val + blob(ex0 - 1, EYE_Y - 6, 6, 2.5, 0.07) + blob(ex1 - 1, EYE_Y - 6, 6, 2.5, 0.05)
    val = val + blob(AXIS - 1, EYE_Y + 5, 1.6, 6, 0.10)
    val = val - blob(AXIS + 3, EYE_Y + 7, 2.2, 5, 0.22)
    val = val - blob(AXIS + 0.5, NOSE_Y + 1.5, 4, 1.4, 0.22)
    val = val + blob(ex0 - 4, NOSE_Y - 2, 5, 4, 0.06)
    val = val - blob(ex1 + 8, NOSE_Y + 3, 6, 5, 0.12 if not lady else 0.08)
    val = val - blob(MOUTH_X, MOUTH_Y + 3.5, 5, 1.6, 0.16)
    val = val + blob(MOUTH_X - 1, chin - 4, 4, 2.5, 0.06)
    cv.put(m, "skin", tones(val, dither=0.012), p)
    # blush on the cheeks and the tip of the nose, dithered in at its edges
    bl = blob(ex0 - 2, NOSE_Y - 1, 5, 3.5) + blob(ex1 + 3, NOSE_Y - 1, 6, 3.5) + blob(AXIS, NOSE_Y - 1, 2, 1.5, 0.6)
    bl = np.clip(bl, 0, 1) * (0.9 if lady else 0.55)
    on = m & ((bl > 0.5) | ((bl > 0.28) & (BAYER4[YY % 4, XX % 4] < 0.5)))
    cv.mat[on] = M["blush"]
    return cv


def neck(lady):
    cv = Canvas()
    p = cv.new_part()
    width = (7, 8) if lady else (9, 10)
    chin = 78 if lady else 79
    x0, x1 = CX - width[0], CX + width[1]
    flare = np.clip(YY - 88, 0, None) * 0.6
    m = (YY >= chin - 12) & (YY <= 100) & (XX >= x0 - flare) & (XX <= x1 + flare)
    u = (XX - (x0 + x1) / 2) / ((x1 - x0) / 2)
    val = 0.55 - u * 0.25 - np.clip(1 - (YY - chin) / 6, 0, 1) * 0.35
    cv.put(m, "skin", tones(val, dither=0.02), p)
    return cv


def ears(lady, head="m_square"):
    cv = Canvas()
    p = cv.new_part()
    L, R, _ = rows_of(head)
    y = EYE_Y
    x = CX + R[y + 2]
    sc = 0.85 if lady else 1.0
    m = ellipse(x + 1.5, y + 4.5, 3.2 * sc, 7 * sc) & (XX + 0.5 >= x - 0.5)
    cv.put(m, "skin", 2, p)
    cv.put(ellipse(x + 2.0, y + 5, 1.4, 4.2 * sc) & m, "skin", 3)
    cv.put(ellipse(x + 2.7, y + 3.5, 1, 3 * sc) & m, "skin", 1)
    cv.px(x + 1.5, y + 6.5, "skin", 4)
    return cv


def age(lady, level):
    """Lines that come with years, in the skin's own shades."""
    cv = Canvas()
    flag = NO_LINE
    ax = AXIS
    t = 3 if not lady else 2
    draw_line(cv, [(ax - 5, NOSE_Y), (ax - 6, NOSE_Y + 3), (ax - 6.5, MOUTH_Y + 1)], "skin", t, flag=flag)
    draw_line(cv, [(ax + 6, NOSE_Y), (ax + 7, NOSE_Y + 3), (ax + 7, MOUTH_Y + 1)], "skin", t, flag=flag)
    if level >= 2:
        draw_line(cv, [(ax - 3, HAIR_Y + 8), (ax + 2, HAIR_Y + 7.5)], "skin", 2, flag=flag)
        cv.px(EYES_X["near"] + 7, EYE_Y, "skin", 3, flag=flag)
        cv.px(EYES_X["near"] + 7, EYE_Y + 2, "skin", 3, flag=flag)
        for x in range(int(EYES_X["far"]) - 3, int(EYES_X["far"]) + 3):
            cv.px(x, EYE_Y + 4, "skin", 3, flag=flag)
        for x in range(int(EYES_X["near"]) - 3, int(EYES_X["near"]) + 3):
            cv.px(x, EYE_Y + 4, "skin", 3, flag=flag)
    return cv


# --------------------------------------------------------------------------- eyes
EYE_SHAPES = {
    # open rows: row -> (inset from the left end, inset from the right end)
    "almond": {-1: (1, 1), 0: (1, 1), 1: (2, 2)},
    "hooded": {-1: (2, 1), 0: (1, 1), 1: (2, 2)},
    "narrow": {0: (1, 1), 1: (2, 2)},
    "round":  {-1: (1, 1), 0: (1, 1), 1: (1, 1)},
}
EYE_STATES = ["open", "half", "shut", "away", "wide", "smile", "laugh", "squint", "down"]


def eye(which, shape, state, lady):
    """A hand-set eye. Colours: white (eye 1/2, catchlight eye 0), iris (iris 1/3), pupil and
    lashes (ink), lids and crease (skin). The iris sits a little toward the viewer's right so the
    eyes meet the viewer while the head turns away."""
    cv = Canvas()
    F = NO_LINE
    w = 11 if which == "near" else 10
    cx = EYES_X[which]
    x0 = int(round(cx - (w - 1) / 2)); x1 = x0 + w - 1
    y = EYE_Y
    outer = x0 if which == "far" else x1
    inner = x1 if which == "far" else x0
    step = 1 if outer == x1 else -1

    def px(x, yy, mat, tone):
        cv.px(x, yy, mat, tone, flag=F)

    if state == "shut":
        for x in range(x0 + 1, x1):
            px(x, y - 2, "skin", 3); px(x, y - 1, "skin", 2); px(x, y, "skin", 2)
            px(x, y + 1, "ink", 0)
        px(inner, y + 1, "skin", 4); px(outer, y + 1, "ink", 0)
        if lady:
            px(outer + step, y + 1, "ink", 0); px(outer + step, y + 2, "ink", 0)
        for x in range(x0 + 2, x1 - 1):
            px(x, y - 3, "skin", 3)
        return cv
    if state == "laugh":
        # shut tight in a smile: the lash line arched up, the cheek pushed under it
        for x in range(x0 + 1, x1):
            t = (x - x0) / (x1 - x0)
            arc = y + 1 - int(round(1.8 * math.sin(math.pi * t)))
            for yy in range(y - 2, arc):
                px(x, yy, "skin", 2 if yy > y - 2 else 3)
            px(x, arc, "ink", 0)
            for yy in range(arc + 1, y + 2):
                px(x, yy, "skin", 2)
        px(inner, y + 1, "skin", 4); px(outer, y + 1, "ink", 0)
        for x in range(x0 + 3, x1 - 2):
            px(x, y + 2, "skin", 3)
        if lady:
            px(outer + step, y, "ink", 0)
        return cv
    rows = dict(EYE_SHAPES[shape])
    if state in ("half", "down"):
        rows.pop(min(rows))
    if state == "smile" and len(rows) > 1:
        rows.pop(max(rows))
    if state == "squint":
        rows = {0: (2, 2)}
    if state == "wide":
        rows[min(rows) - 1] = (2, 2)
    top = min(rows)
    ic = (x0 + x1) / 2 + 0.6
    if state == "away":
        ic = (x0 + x1) / 2 - 2.2
    for r, (ia, ib) in rows.items():
        a, b = x0 + ia, x1 - ib
        for x in range(a, b + 1):
            d = abs(x - ic)
            if d <= 1.7 and not (state == "wide" and r == top):
                if state == "down":
                    m, t = (("ink", 1) if d <= 0.6 else ("iris", 1)) if r == max(rows) else ("iris", 3)
                elif r == top or (state == "wide" and r == top + 1):
                    m, t = ("ink", 1) if d <= 0.6 else ("iris", 3)
                elif r == 0:
                    m, t = ("ink", 1) if d <= 0.6 else ("iris", 1)
                else:
                    m, t = ("iris", 1) if d <= 1.0 else ("iris", 3)
            else:
                m, t = ("eye", 2) if x in (a, b) or (r == top and abs(x - ic) < 2.8) else ("eye", 1)
            px(x, y + r, m, t)
    hx_ = int(math.floor(ic)) - (1 if (ic % 1) < 0.5 else 0)
    hy = top + (1 if state in ("open", "away") and top < 0 else 0) + (1 if state == "wide" else 0)
    px(hx_, y + hy, "eye", 0)
    lid = y + top - 1
    for x in range(x0, x1 + 1):
        px(x, lid, "ink", 0)
    px(inner, y + top, "skin", 4)
    px(outer, y + top, "ink", 0)
    if lady:
        px(outer + step, lid, "ink", 0); px(outer + step, lid - 1, "ink", 0); px(outer, y + top + 1, "ink", 0)
    if state in ("half", "down", "squint"):
        for x in range(x0 + 1, x1):
            px(x, lid - 1, "skin", 3)
    if state == "squint":
        for x in range(x0 + 1, x1):
            px(x, lid, "ink", 0)
            px(x, lid - 1, "ink", 2 if x0 + 2 < x < x1 - 2 else 0)
    low = y + max(rows) + 1
    for x in range(x0 + 2, x1 - 1):
        px(x, low, "skin", 4)
    px(x0 + 1, low - 1, "skin", 4); px(x1 - 1, low - 1, "skin", 4)
    if state in ("smile", "squint"):
        # the cheek rises under a smiling or narrowed eye
        for x in range(x0 + 1, x1):
            px(x, low, "skin", 4 if x0 + 1 < x < x1 - 1 else 3)
        for x in range(x0 + 2, x1 - 1):
            px(x, low + 1, "skin", 3)
    if shape == "hooded":
        for x in range(x0 + 1, x1):
            px(x, lid - 1, "skin", 3)
    else:
        for x in range(x0 + 2, x1 - 1):
            px(x, lid - 2, "skin", 3)
    return cv


# --------------------------------------------------------------------------- brows
BROW_STYLES = {"thick": 1.25, "medium": 1.0, "thin": 0.72, "arched": 0.78}
BROW_MOODS = {"rest": (0.0, 0.0), "raised": (1.6, 0.0), "stern": (-0.6, -0.35), "worried": (0.6, 0.38),
              "angry": (-1.2, -0.75), "sad": (0.9, 0.75)}


def brow(which, style, mood, lean=0.0):
    """Tapered brow in the hair's darker shades: thickest at the inner end, arched."""
    cv = Canvas()
    w = 13 if which == "near" else 12
    cx = EYES_X[which]
    flip = which == "far"
    weight = BROW_STYLES[style]
    arch = 2.4 if style == "arched" else 1.6
    lift, angle = BROW_MOODS[mood]
    angle += lean
    y0 = BROW_Y - lift
    for col in range(w):
        t = col / (w - 1)
        x = cx - w / 2 + (w - 1 - col if flip else col) + (0.5 if not flip else -0.5)
        yc = y0 - arch * math.sin(t * math.pi * 0.9) + angle * (t - 0.3) * 3
        thick = (3.0 - 1.6 * t) * weight
        for k in range(int(math.ceil(thick))):
            if t > 0.8 and k > 0:
                continue
            cv.px(x, yc + 1 - k, "hair", 4 if k == 0 else (3 if k == 1 else 2), flag=NO_LINE)
    return cv


# --------------------------------------------------------------------------- nose
NOSES = {
    "straight": ["....s...",
                 "..L.s...",
                 "..L.s...",
                 "..L..s..",
                 "..L..s..",
                 "...L.s..",
                 "...L.ss.",
                 ".s.H..s.",
                 "s..L...d",
                 ".ds.sdd.",
                 "..sss..."],
    "aquiline": ["....s...",
                 "..L.s...",
                 "..L.s...",
                 "..HL.s..",
                 "..HL.s..",
                 "...L.s..",
                 "...L..s.",
                 ".s.H..s.",
                 "s.LL...d",
                 ".ds.sdd.",
                 "..sss..."],
    "small":    ["........",
                 "........",
                 "...L.s..",
                 "...L.s..",
                 "...L.s..",
                 "...L.s..",
                 "...L.ss.",
                 "...H..s.",
                 ".s.L..d.",
                 "..d.sd..",
                 "..sss..."],
    "broad":    ["....s...",
                 "..L.s...",
                 "..L.s...",
                 "..L..s..",
                 "..L..s..",
                 "..LL.s..",
                 "..LL.ss.",
                 "ss.H..ss",
                 "s..L...d",
                 "dds.sddd",
                 ".sssss.."],
}


def nose(style):
    cv = Canvas()
    tone = {"L": 1, "H": 0, "s": 3, "d": 4}
    for r, row in enumerate(NOSES[style]):
        for c, ch in enumerate(row):
            if ch in tone:
                cv.px(AXIS - 3 + c, NOSE_Y - 9 + r, "skin", tone[ch], flag=NO_LINE)
    return cv


# --------------------------------------------------------------------------- mouth
def _mouth_more(px, mood, mx, my, lady, full, lip):
    """Mouths that move: talking (open, or open in a smile), a laugh, a surprised o, bared teeth,
    a pout, a smirk."""
    def lips_row(y, dxs, tone_l, tone_r):
        for dx in dxs:
            m, t = lip(tone_l if dx <= 0 else tone_r)
            px(mx + dx, y, m, t)
    if mood == "talk":
        lips_row(my - 1, range(-4, 5), 2, 3)
        for dx in range(-2, 3):
            px(mx + dx, my, "ink", 2); px(mx + dx, my + 1, "ink", 2)
        for dx in (-3, 3):
            px(mx + dx, my, "lip", 4); px(mx + dx, my + 1, "lip", 4)
        lips_row(my + 2, range(-3, 4), 2, 3)
        m, t = lip(1); px(mx - 1, my + 2, m, t)
        for dx in range(-2, 3):
            px(mx + dx, my + 3, "skin", 3)
    elif mood == "talk_smile":
        lips_row(my - 1, range(-3, 4), 2, 3)
        px(mx - 4, my - 1, "lip", 4); px(mx + 4, my - 1, "lip", 4)
        for dx in range(-3, 4):
            px(mx + dx, my, "white" if abs(dx) <= 1 else "ink", 1 if abs(dx) <= 1 else 2)
            px(mx + dx, my + 1, "ink", 2)
        lips_row(my + 2, range(-2, 3), 2, 3)
        px(mx - 5, my - 2, "skin", 3); px(mx + 5, my - 2, "skin", 3)
    elif mood == "laugh":
        lips_row(my - 1, range(-4, 5), 2, 3)
        px(mx - 5, my - 1, "lip", 4); px(mx + 5, my - 1, "lip", 4)
        for dx in range(-4, 5):
            for r in range(3):
                if r == 2 and abs(dx) > 2:
                    continue
                if r == 0 and abs(dx) <= 3:
                    px(mx + dx, my + r, "white", 1 if dx <= 0 else 2)
                else:
                    px(mx + dx, my + r, "ink", 2 if r < 2 else 3)
        px(mx - 1, my + 2, "lip", 2); px(mx, my + 2, "lip", 2)
        lips_row(my + 3, range(-2, 3), 2, 3)
        px(mx - 6, my - 1, "skin", 3); px(mx + 6, my - 1, "skin", 3); px(mx - 6, my, "skin", 3); px(mx + 6, my, "skin", 3)
    elif mood == "o":
        px(mx - 1, my, "ink", 2); px(mx, my, "ink", 2); px(mx - 1, my + 1, "ink", 2); px(mx, my + 1, "ink", 3)
        for x, y in ((mx - 2, my), (mx - 2, my + 1), (mx + 1, my), (mx + 1, my + 1)):
            m, t = lip(3); px(x, y, m, t)
        for x in (mx - 1, mx):
            m, t = lip(2); px(x, my - 1, m, t)
            m, t = lip(2); px(x, my + 2, m, t)
        for dx in (-1, 0):
            px(mx + dx, my + 3, "skin", 3)
    elif mood == "teeth":
        for dx in range(-4, 5):
            px(mx + dx, my - 1, "lip", 4)
            px(mx + dx, my + 1, "lip", 4)
        for dx in range(-3, 4):
            px(mx + dx, my, "white", 1 if dx < 2 else 2)
        px(mx - 5, my + 1, "lip", 4); px(mx + 5, my + 1, "lip", 4)
        for dx in range(-2, 3):
            px(mx + dx, my + 3, "skin", 3)
    elif mood == "pout":
        for dx in range(-4, 5):
            yy = my + (1 if abs(dx) >= 3 else 0) + (1 if abs(dx) >= 4 else 0)
            px(mx + dx, yy, "lip", 4)
        lips_row(my + 1, range(-2, 3), 1, 2)
        lips_row(my + 2, range(-1, 2), 2, 3)
        for dx in range(-2, 3):
            px(mx + dx, my + 3, "skin", 3)
    elif mood == "smirk":
        for dx in range(-5, 6):
            yy = my - (1 if dx >= 3 else 0) - (1 if dx >= 5 else 0)
            px(mx + dx, yy, "lip", 4)
        lips_row(my - 1, range(-3, 3), 2, 3)
        lips_row(my + 1, range(-2, 3), 2, 3)
        px(mx + 6, my - 3, "skin", 3)
        for dx in range(-2, 3):
            px(mx + dx, my + 2, "skin", 3)


def blush_mark(lady):
    """A colour in the cheeks (shy, embarrassed, flustered)."""
    cv = Canvas()
    m = blob(EYES_X["far"] - 1, NOSE_Y - 1, 5.5, 3) + blob(EYES_X["near"] + 3, NOSE_Y - 1, 6.5, 3.2)
    on = ((m > 0.45) | ((m > 0.15) & (BAYER4[YY % 4, XX % 4] < 0.5))) & head_mask("f_heart") & ~shift(~head_mask("f_heart"), 0, 1, True)
    cv.put(on, "blush", np.where(m > 0.6, 1, 2), flag=NO_LINE)
    for dx in (-2, 0, 2):
        cv.px(EYES_X["near"] + 3 + dx, NOSE_Y - 1, "blush", 0, flag=NO_LINE)
    return cv
MOUTH_MOODS = ["rest", "smile", "slight", "flat", "frown", "grimace", "open",
               "talk", "talk_smile", "laugh", "o", "teeth", "pout", "smirk"]


def mouth(style, mood):
    """Men: a quiet mouth, lips near the skin; women: fuller, coloured lips."""
    cv = Canvas()
    F = NO_LINE
    lady = style == "lady"
    full = style == "full"
    mx, my = int(round(MOUTH_X)), MOUTH_Y
    half = 5
    curve = {"smile": -1.0, "slight": -0.5, "frown": 1.0, "grimace": 1.0}.get(mood, 0.0)

    def px(x, y, m, t):
        cv.px(x, y, m, t, flag=F)

    lip = (lambda t: ("lip", t)) if (lady or full) else (lambda t: ("skin", t))
    if mood in ("talk", "talk_smile", "laugh", "o", "teeth", "pout", "smirk"):
        _mouth_more(px, mood, mx, my, lady, full, lip)
        return cv

    if mood == "open":
        for dx in range(-3, 4):
            px(mx + dx, my - 1, "lip", 2 if lady else 3)
            px(mx + dx, my + 2, "lip", 1 if lady else 2)
        for dx in range(-2, 3):
            px(mx + dx, my, "ink", 2); px(mx + dx, my + 1, "ink", 2)
        px(mx - 3, my, "lip", 4); px(mx + 3, my, "lip", 4); px(mx - 3, my + 1, "lip", 4); px(mx + 3, my + 1, "lip", 4)
        for dx in range(-2, 3):
            px(mx + dx, my + 3, "skin", 3)
        return cv
    for dx in range(-half, half + 1):
        t = abs(dx) / half
        lift = curve * t * t if abs(dx) >= half - 2 else 0
        if mood == "slight" and dx < 0:
            lift = 0
        px(mx + dx, round(my + lift), "lip", 4 if abs(dx) < half else 4)
        if mood == "grimace" and abs(dx) < half - 1:
            px(mx + dx, my - 1, "white", 2 if dx > 0 else 1)
    if mood in ("smile", "slight"):
        px(mx + half + 1, my - 1 + (0 if mood == "smile" else 0), "skin", 3)
        if mood == "smile":
            px(mx - half - 1, my - 1, "skin", 3)
    if mood == "grimace":
        px(mx - half - 1, my + 1, "skin", 3); px(mx + half + 1, my + 1, "skin", 3)
    upper = mood not in ("flat", "grimace")
    if upper:
        for dx in range(-half + 1, half):
            if lady or abs(dx) < half - 1:
                px(mx + dx, my - 1, "lip", 3 if dx > 0 else 2)
        if lady or full:
            for dx in (-2, -1, 1, 2):
                px(mx + dx, my - 2, "lip", 2 if dx < 0 else 3)
    lw = half - 1 if lady else half - 2
    if lady or full:
        for dx in range(-lw, lw + 1):
            px(mx + dx, my + 1, "lip", 2 if dx < 1 else 3)
        for dx in range(-lw + 1, lw):
            px(mx + dx, my + 2, "lip", 2 if dx < 0 else 3)
        px(mx - 1, my + 1, "lip", 1); px(mx - 2, my + 1, "lip", 1)
        for dx in range(-2, 3):
            px(mx + dx, my + 3, "skin", 3)
    else:
        for dx in range(-lw, lw + 1):
            px(mx + dx, my + 1, "skin", 2 if dx < 1 else 3)
        px(mx - 1, my + 1, "skin", 1)
        for dx in range(-2, 3):
            px(mx + dx, my + 2, "skin", 3)
    lift = 1 if (lady or full) and upper else 0
    px(mx - 1, my - 2 - lift, "skin", 3); px(mx + 1, my - 2 - lift, "skin", 3)
    return cv
