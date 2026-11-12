"""Captains' gear for the portrait kit: four outfits for each land, cut for men's and women's
shoulders; the mark of their troop (a slung shield, a spear rising behind them, a quiver, a
riding cloak); rank (brass at the collar, a short cloak over the shoulder); a role token;
scars and a bandage. cloth_a is the captain's main colour, cloth_b the trim, cloth_c the
accent, as their palette is now."""
import math
import numpy as np
from canvas import *
from garb import panel, band, mail, crest, gem, coin, form, GOLD_EMB, collars

BODY = {"m": [(47, 90), (73, 90), (100, 99), (110, 110), (113, 160), (7, 160), (10, 110), (20, 99)],
        "f": [(50, 89), (70, 89), (91, 96), (102, 105), (106, 160), (14, 160), (18, 105), (29, 96)]}
NECK = {"m": (47, 73), "f": (50, 70)}
SHOULDER = {"m": (10, 110), "f": (18, 102)}


def body(g):
    return poly(BODY[g])


def pattern_panel(cv, mask, mat, pat, light=None, folds=(), deeper=1):
    """A garment piece whose pattern pixels sit a shade darker than the cloth around them."""
    p = panel(cv, mask, mat, light, folds)
    t = cv.tone.copy()
    m = mask & pat
    cv.tone[m] = np.minimum(t[m] + deeper, 4)
    return p


def lace(cv, x, y0, y1, mat="leather"):
    p = cv.new_part(False)
    for y in range(int(y0), int(y1), 4):
        cv.px(x - 2, y, mat, 1, p); cv.px(x - 1, y + 1, mat, 2, p); cv.px(x + 1, y + 1, mat, 2, p); cv.px(x + 2, y, mat, 1, p)
        cv.px(x, y + 2, mat, 3, p)


# =========================================================================== Vardish
def v_gambeson(g, rng):
    cv = Canvas()
    quilt = ((XX + YY) % 6 == 0) | ((XX - YY + 120) % 6 == 0)
    pattern_panel(cv, body(g), "cloth_a", quilt, folds=[([(28, 112), (26, 160)], 0.5), ([(92, 112), (94, 160)], 0.5)])
    nl, nr = NECK[g]
    panel(cv, poly([(nl + 1, 84), (nr - 1, 84), (nr + 1, 92), (60, 95), (nl - 1, 92)]), "cloth_a",
          light=lambda x, y: np.clip(0.8 - (x - 60) / 60, 0.2, 0.95))
    band(cv, [(nl, 92), (60, 95.5), (nr, 92)], 1.6, "cloth_b", line=False)
    tp = cv.new_part(False)
    for y in range(102, 160, 9):
        cv.put(ellipse(60, y, 1.6, 1.2), "cloth_b", 1, tp); cv.px(60.5, y + 0.5, "cloth_b", 3, tp)
    return None, cv


def v_mail_tabard(g, rng):
    cv = Canvas()
    mail(cv, body(g))
    nl, nr = NECK[g]
    mail(cv, poly([(nl - 1, 92), (nl + 2, 82), (60, 80), (nr - 2, 82), (nr + 1, 92), (66, 95), (54, 95)]))
    sl, sr = SHOULDER[g]
    tab = poly([(36 if g == "m" else 39, 101), (48, 95), (60, 98), (72, 95), (84 if g == "m" else 81, 101), (88 if g == "m" else 84, 160),
                (32 if g == "m" else 36, 160)])
    panel(cv, tab, "cloth_a", folds=[([(48, 118), (46, 160)], 0.6), ([(72, 118), (74, 160)], 0.6)])
    cross = tab & ((np.abs(XX + 0.5 - 60) < 3) & (YY > 104) | (np.abs(YY + 0.5 - 122) < 3) & (np.abs(XX + 0.5 - 60) < 14))
    panel(cv, cross, "cloth_c", line=False)
    edge = tab & ~(shift(tab, 0, 2, False) & shift(tab, 0, -2, False))
    cv.put(edge, "cloth_b", 2)
    return None, cv


def v_cloak(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(60, 104), (60, 160)], 0.4)])
    nl, nr = NECK[g]
    band(cv, [(nl + 1, 92), (60, 96), (nr - 1, 92)], 2.2, "cloth_b", line=False)
    sl, sr = SHOULDER[g]
    left = poly([(nl + 2, 89), (sl + 26, 92), (sl + 6, 98), (sl, 108), (sl - 3, 160), (sl + 30, 160), (40, 124), (48, 100)])
    right = poly([(nr - 2, 89), (sr - 26, 92), (sr - 6, 98), (sr, 108), (sr + 3, 160), (sr - 22, 160), (82, 126), (76, 100)])
    panel(cv, left, "cloth_b", folds=[([(26, 102), (20, 160)], 1.0), ([(36, 110), (32, 160)], 0.7)])
    panel(cv, right, "cloth_b", folds=[([(94, 102), (100, 160)], 1.0), ([(86, 112), (90, 160)], 0.7)])
    p = cv.new_part()
    cv.put(ellipse(77, 99, 4, 4), "gold", 1, p); cv.put(ellipse(77, 99, 2.2, 2.2), "gold", 3, p); cv.px(76, 98, "gold", 0, p)
    return None, cv


def v_jerkin(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(20, 112), (16, 160)], 0.6), ([(100, 112), (104, 160)], 0.6)])
    nl, nr = NECK[g]
    jer = poly([(nl - 2, 92), (54, 97), (60, 104), (66, 97), (nr + 2, 92), (88 if g == "m" else 84, 100),
                (90 if g == "m" else 86, 160), (30 if g == "m" else 34, 160), (32 if g == "m" else 36, 100)])
    seam = (np.abs(XX + 0.5 - 44) < 0.6) | (np.abs(XX + 0.5 - 76) < 0.6) | ((YY % 14) == 0)
    pattern_panel(cv, jer, "leather", seam & (YY > 104), deeper=1)
    lace(cv, 60, 106, 150)
    sl, sr = SHOULDER[g]
    for cx, flip in ((sl + 13, -1), (sr - 13, 1)):
        pp = cv.new_part()
        # three overlapping lames, each a rounded plate lit from the upper left
        for k, (dy, r) in enumerate(((0, 12), (5, 11), (10, 10))):
            m = ellipse(cx, 102 + dy, r, 5.5) & (YY >= 98 + dy)
            u = (XX + 0.5 - cx) / r
            light = 0.62 - u * 0.35 - k * 0.1 + np.clip(0.3 - np.abs(u + 0.35), 0, 1) * 0.6
            cv.put(m, "steel", np.clip(tones(light), 1, 4), pp)
            cv.put(m & ~shift(m, 1, 0, False), "steel", 4)
        cv.put(ellipse(cx - 4 * flip, 103, 0.9, 0.9), "steel", 0, pp)
    return None, cv


# =========================================================================== Kharzani
def k_robe(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(30, 112), (26, 160)], 0.7), ([(90, 112), (94, 160)], 0.7)])
    for side in (-1, 1):
        band(cv, [(60 + side * 12, 89), (60 + side * 7, 104), (60, 124)], 4.2, "gold", pattern=GOLD_EMB)
    stripes = ((YY // 2) % 3)
    sash = poly([(10 if g == "m" else 16, 146), (110 if g == "m" else 104, 146), (112 if g == "m" else 105, 160), (8 if g == "m" else 15, 160)])
    p = cv.new_part()
    cv.put(sash, "cloth_c", np.where(stripes == 0, 1, np.where(stripes == 1, 2, 3)), p)
    cv.put(sash & (stripes == 2), "cloth_b", 2)
    return None, cv


def k_scales(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(20, 112), (16, 160)], 0.6), ([(100, 112), (104, 160)], 0.6)])
    nl, nr = NECK[g]
    vest = poly([(nl - 2, 92), (60, 97), (nr + 2, 92), (88 if g == "m" else 84, 100), (90 if g == "m" else 86, 160),
                 (30 if g == "m" else 34, 160), (32 if g == "m" else 36, 100)])
    p = cv.new_part()
    light = form()(XX + 0.5, YY + 0.5)
    row = (YY - 96) // 4
    u = (XX + (row % 2) * 2) % 4
    v = (YY - 96) % 4
    t = tones(light * 0.85 + 0.1)
    tone = np.where(v == 0, np.maximum(t - 1, 0), np.where((u == 0) | (v == 3), np.minimum(t + 1, 4), t))
    cv.put(vest, "steel", tone, p)
    cv.put(vest & (v == 0) & (u != 0), "gold", np.clip(t, 1, 3))
    lace(cv, 33 if g == "m" else 37, 104, 156); lace(cv, 87 if g == "m" else 83, 104, 156)
    return None, cv


def k_scarf(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(30, 112), (26, 160)], 0.6), ([(90, 112), (94, 160)], 0.6)])
    nl, nr = NECK[g]
    scarf = poly([(nl - 6, 92), (nl, 84), (60, 82), (nr, 84), (nr + 6, 92), (nr + 18, 98), (74, 106), (72, 150), (64, 152),
                   (64, 104), (56, 104), (56, 152), (48, 150), (46, 106), (nl - 18, 98)])
    check = (((XX // 3) + (YY // 3)) % 2) == 0
    p = panel(cv, scarf, "cloth_b", folds=[([(52, 108), (52, 150)], 0.5), ([(68, 108), (68, 150)], 0.5)])
    t = cv.tone.copy()
    cv.put(scarf & check, "cloth_c", np.clip(t, 0, 4))
    fp = cv.new_part(False)
    for x in range(48, 74, 2):
        if not (56 <= x < 64):
            cv.px(x, 152, "cloth_b", 3, fp); cv.px(x, 153, "cloth_b", 4, fp)
    return None, cv


def k_kaftan(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_b", folds=[([(60, 104), (60, 160)], 0.4)])
    nl, nr = NECK[g]
    sl, sr = SHOULDER[g]
    left = poly([(nl + 1, 89), (sl + 26, 92), (sl + 6, 98), (sl, 108), (sl - 3, 160), (55, 160), (55, 104), (52, 94)])
    right = poly([(nr - 1, 89), (sr - 26, 92), (sr - 6, 98), (sr, 108), (sr + 3, 160), (65, 160), (65, 104), (68, 94)])
    panel(cv, left, "cloth_a", folds=[([(28, 104), (24, 160)], 0.8)])
    panel(cv, right, "cloth_a", folds=[([(92, 104), (96, 160)], 0.8)])
    band(cv, [(52, 92), (55, 104), (55, 160)], 2.2, "gold", line=False)
    band(cv, [(68, 92), (65, 104), (65, 160)], 2.2, "gold", line=False)
    fp = cv.new_part(False)
    for y in range(106, 154, 8):
        for x in range(51, 70):
            if x in (51, 52, 68, 69) or (x - 51) % 3 == 0:
                cv.px(x, y, "gold", 1 if x < 60 else 2, fp)
        cv.px(56, y + 1, "gold", 3, fp); cv.px(64, y + 1, "gold", 3, fp)
    return None, cv


# =========================================================================== Ryumon
def r_kimono(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_a", folds=[([(30, 112), (26, 160)], 0.8), ([(90, 112), (94, 160)], 0.8)])
    collars(cv, [("cloth_a", 4.2), ("cloth_b", 2.8), ("white", 2.6)], depth=116)
    cp = cv.new_part(False)
    crest(cv, 40 if g == "m" else 42, 116, cp); crest(cv, 80 if g == "m" else 78, 116, cp)
    return None, cv


def r_armour(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_b")
    collars(cv, [("cloth_b", 4.0), ("white", 3.0)], depth=108)
    dou = poly([(34, 104), (48, 98), (60, 102), (72, 98), (86, 104), (90, 160), (30, 160)])
    light = form()(XX + 0.5, YY + 0.5)
    t = tones(light * 0.9 + 0.05)
    p = cv.new_part()
    cv.put(dou, "black", np.minimum(t + 1, 4), p)
    cv.put(dou & (((YY - 104) % 7) < 3) & (((XX + (YY // 7) * 2) % 4) < 2), "cloth_a", np.maximum(t - 1, 0))
    cv.put(dou & (((YY - 104) % 7) == 6), "black", 4)
    sl, sr = SHOULDER[g]
    for side in (-1, 1):
        sode = poly([(46, 94), (24, 97), (10, 106), (8, 130), (30, 132), (36, 112)]) if side < 0 else \
            poly([(74, 94), (96, 97), (110, 106), (112, 130), (90, 132), (84, 112)])
        if g == "f":
            sode = sode & (XX > 14) & (XX < 106)
        sp = cv.new_part()
        cv.put(sode, "black", np.minimum(t + 1, 4), sp)
        cv.put(sode & (((YY - 97) % 6) < 3) & (((XX + (YY // 6) * 2) % 4) < 2), "cloth_a", np.maximum(t - 1, 0))
        cv.put(sode & (((YY - 97) % 6) == 5), "black", 4)
    return None, cv


def r_haori(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_b", folds=[([(60, 112), (60, 160)], 0.4)])
    collars(cv, [("cloth_b", 3.6), ("white", 2.6)], depth=112)
    nl, nr = NECK[g]
    sl, sr = SHOULDER[g]
    left = poly([(nl + 1, 89), (sl + 26, 92), (sl + 6, 98), (sl, 108), (sl - 3, 160), (50, 160), (49, 110), (50, 94)])
    right = poly([(nr - 1, 89), (sr - 26, 92), (sr - 6, 98), (sr, 108), (sr + 3, 160), (70, 160), (71, 110), (70, 94)])
    panel(cv, left, "cloth_a", folds=[([(28, 104), (24, 160)], 0.8)])
    panel(cv, right, "cloth_a", folds=[([(92, 104), (96, 160)], 0.8)])
    band(cv, [(50, 92), (49, 110), (50, 160)], 2.6, "cloth_a", pattern=lambda i, j: np.where(j == 0, 1, 3))
    band(cv, [(70, 92), (71, 110), (70, 160)], 2.6, "cloth_a", pattern=lambda i, j: np.where(j == 0, 1, 3))
    cp = cv.new_part(False)
    crest(cv, 34 if g == "m" else 38, 110, cp); crest(cv, 86 if g == "m" else 82, 110, cp)
    kp = cv.new_part(False)
    for x in range(50, 71):
        cv.px(x, 124, "cloth_c", 1, kp)
    cv.put(ellipse(60, 125, 2.4, 2), "cloth_c", 2, kp)
    for k in range(5):
        cv.px(59, 127 + k, "cloth_c", 2, kp); cv.px(61, 127 + k, "cloth_c", 3, kp)
    return None, cv


def r_cuirass(g, rng):
    cv = Canvas()
    panel(cv, body(g), "cloth_b", folds=[([(20, 112), (16, 160)], 0.6), ([(100, 112), (104, 160)], 0.6)])
    collars(cv, [("cloth_b", 3.6), ("white", 2.4)], depth=104)
    dou = poly([(32, 102), (46, 97), (60, 100), (74, 97), (88, 102), (91, 160), (29, 160)])
    light = form()(XX + 0.5, YY + 0.5)
    p = cv.new_part()
    cv.put(dou, "black", tones(light * 0.85 + 0.12), p)
    cv.put(dou & ((YY - 102) % 12 == 11), "black", 4)
    cv.put(dou & (np.abs(XX + 0.5 - 40) < 2) & (YY > 104), "black", 1)
    mon = ellipse(60, 126, 10, 10) & ~ellipse(60, 126, 7.6, 7.6)
    cv.put(mon, "gold", 1)
    for k in range(3):
        a = k * 2 * math.pi / 3 - math.pi / 2
        cv.put(ellipse(60 + math.cos(a) * 3.4, 126 + math.sin(a) * 3.4, 2.6, 2.6), "gold", 2)
    return None, cv


OUTFITS = {"vardish": [v_gambeson, v_mail_tabard, v_cloak, v_jerkin],
           "kharzani": [k_robe, k_scales, k_scarf, k_kaftan],
           "ryumon": [r_kimono, r_armour, r_haori, r_cuirass]}


# =========================================================================== troop, rank, role
def troop(kind, g):
    """(back, front) for what a captain of `kind` carries."""
    back, front = Canvas(), Canvas()
    sl, sr = SHOULDER[g]
    if kind == "spearmen":
        p = back.new_part()
        for y in range(18, 160):
            back.px(104, y, "leather", 2 if y % 7 else 3, p); back.px(105, y, "leather", 3, p)
        back.put(poly([(104.5, 4), (107.5, 12), (106.5, 18), (102.5, 18), (101.5, 12)]), "steel", 1, p)
        back.put(poly([(104.5, 4), (107.5, 12), (106.5, 18), (104.5, 18)]), "steel", 3, p)
        tp = front.new_part()
        front.put(poly([(101, 19), (109, 19), (110, 30), (107, 34), (103, 34), (100, 30)]), "garnet", 1, tp)
        front.put(poly([(105, 19), (109, 19), (110, 30), (107, 34), (105, 34)]), "garnet", 2, tp)
        front.px(104, 20, "garnet", 0, tp)
    elif kind == "archers":
        p = back.new_part()
        for i in range(3):
            x = 34 + i * 4
            for y in range(76 - i * 2, 96):
                back.px(x, y, "leather", 3, p)
            back.put(poly([(x - 1.5, 76 - i * 2), (x + 2.5, 76 - i * 2), (x + 2.5, 82 - i * 2), (x - 1.5, 82 - i * 2)]), "white", 1, p)
            back.px(x, 77 - i * 2, "garnet", 1, p); back.px(x + 1, 78 - i * 2, "garnet", 2, p)
        back.put(poly([(30, 86), (46, 84), (48, 100), (32, 102)]), "leather", 2, p)
        band(front, [(sr - 22, 94), (60, 122), (sl + 22, 158)], 4.4, "leather", pattern=lambda i, j: np.where(j == 0, 1, np.where(j == 1, 2, 3)))
        bp = front.new_part()
        front.put(poly([(58, 118), (64, 118), (64, 125), (58, 125)]), "gold", 1, bp)
        front.put(poly([(60, 120), (62, 120), (62, 123), (60, 123)]), "leather", 3, bp)
    elif kind == "cavalry":
        p = back.new_part()
        back.put(poly([(sl - 4, 104), (sl + 8, 94), (sr - 8, 94), (sr + 4, 104), (sr + 7, 160), (sl - 7, 160)]), "cloth_c",
                 tones(form()(XX + 0.5, YY + 0.5) * 0.8), p)
        cp = front.new_part()
        front.put(ellipse(60, 96, 4, 3.4), "gold", 1, cp); front.put(ellipse(60, 96, 2, 1.7), "gold", 3, cp)
        for x in range(46, 75):
            y = 95 + 0.015 * (x - 60) ** 2
            if abs(x - 60) > 3:
                front.px(x, y, "gold", 2 if x % 2 else 3, cp)
    else:
        p = front.new_part()
        cx, cy, r = sr - 8, 136, 15
        m = ellipse(cx, cy, r, r)
        light = np.clip(0.75 - (XX - cx) / (r * 2.4) - (YY - cy) / (r * 2.6), 0, 1)
        front.put(m, "cloth_c", tones(light), p)
        rim = m & ~ellipse(cx, cy, r - 2, r - 2)
        front.put(rim, "steel", tones(light))
        front.put(ellipse(cx, cy, 3.2, 3.2), "steel", 1)
        front.px(cx - 1, cy - 1, "steel", 0)
        front.put(m & (np.abs(XX + 0.5 - cx) < 1.2) & ~ellipse(cx, cy, 3.2, 3.2), "cloth_b", 2)
    return back, front


def rank(level, g):
    cv = Canvas()
    nl, nr = NECK[g]
    if level >= 2:
        p = cv.new_part(False)
        for x in range(int(nl) + 1, int(nr)):
            y = 92 + 0.02 * (x - 60) ** 2
            cv.px(x, y, "gold", 1 if x % 3 else 3, p)
        cv.put(ellipse(nl + 1, 92, 1.5, 1.5), "gold", 1, p); cv.put(ellipse(nr - 1, 92, 1.5, 1.5), "gold", 2, p)
    if level >= 3:
        sl, _ = SHOULDER[g]
        cloak = poly([(nl + 1, 89), (sl + 24, 91), (sl + 4, 98), (sl - 2, 110), (sl - 1, 150), (sl + 14, 146), (32, 124),
                      (42, 104), (50, 96)])
        panel(cv, cloak, "cloth_c", folds=[([(24, 100), (16, 146)], 0.9), ([(34, 104), (28, 136)], 0.6)])
        bp = cv.new_part()
        cv.put(ellipse(46, 98, 3.4, 3.4), "gold", 1, bp); cv.put(ellipse(46, 98, 1.6, 1.6), "garnet", 1, bp)
    return cv


def token(spec):
    cv = Canvas()
    p = cv.new_part(False)
    x0, y0 = 46, 118
    if spec == "Scout":
        for i in range(10):
            cv.px(x0 + i * 0.6, y0 + 12 - i, "leather", 1 if i % 2 else 3, p)
            cv.px(x0 + 1 + i * 0.6, y0 + 12 - i, "white", 2, p)
        cv.px(x0 - 0.5, y0 + 13, "white", 1, p)
    elif spec == "Quartermaster":
        for y in range(y0 - 4, y0 + 4):
            cv.px(x0 + 3, y, "leather", 3, p)
        cv.put(ellipse(x0 + 3, y0 + 6, 3, 2.6) & ~ellipse(x0 + 3, y0 + 6, 1.6, 1.4), "gold", 1, p)
        for dx in (-1, 3, 7):
            cv.px(x0 + dx, y0 + 9, "gold", 2, p); cv.px(x0 + dx, y0 + 10, "gold", 3, p); cv.px(x0 + dx + 1, y0 + 11, "gold", 3, p)
    elif spec == "Drillmaster":
        for i in range(7):
            cv.px(x0 + i, y0 - 2 + i, "garnet", 1, p)
        cv.put(poly([(x0 + 6, y0 + 4), (x0 + 9, y0 + 4), (x0 + 9, y0 + 11), (x0 + 6, y0 + 11)]), "gold", 1, p)
        cv.px(x0 + 8, y0 + 5, "gold", 0, p); cv.px(x0 + 8, y0 + 10, "gold", 3, p)
    elif spec == "Champion":
        for k in range(6):
            a = math.pi * (0.15 + 0.7 * k / 5)
            cv.px(x0 + 4 - math.cos(a) * 5, y0 + 5 + math.sin(a) * 4, "gold", 1, p)
            cv.px(x0 + 4 + math.cos(a) * 5, y0 + 5 + math.sin(a) * 4, "gold", 2, p)
            cv.px(x0 + 3 - math.cos(a) * 6, y0 + 4 + math.sin(a) * 4, "gold", 2, p)
            cv.px(x0 + 5 + math.cos(a) * 6, y0 + 4 + math.sin(a) * 4, "gold", 3, p)
        cv.put(ellipse(x0 + 4, y0 + 9, 1.6, 1.6), "garnet", 1, p)
    return cv


SCARS = [  # healed cuts on the face: from, to
    ((43, 40), (49, 47)), ((69, 41), (73, 48)), ((71, 56), (77, 61)), ((44, 57), (47, 63)), ((58, 73), (62, 77)),
    ((53, 34), (58, 39))]


def scar(i):
    cv = Canvas()
    (x0, y0), (x1, y1) = SCARS[i]
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for k in range(n):
        t = k / (n - 1)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        cv.px(x, y, "skin", 0, flag=NO_LINE)
        if k % 2 == 0:
            cv.px(x + 1, y, "skin", 4, flag=NO_LINE)
    return cv


def bandage():
    cv = Canvas()
    p = cv.new_part()
    for x in range(37, 84):
        y = 31 + 0.009 * (x - 60) ** 2
        for k in range(4):
            cv.px(x, y + k, "white", 1 if k == 0 else (2 if x < 72 else 3), p)
    cv.put(ellipse(70, 33, 1.6, 1.4), "garnet", 1); cv.px(71, 34, "garnet", 2)
    return cv
