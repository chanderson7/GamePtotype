"""What lords wear, two cuts for each land for men and for women, and headwear (crowns,
turbans, veils, pins). cloth_a is the house colour, cloth_b and cloth_c the land's second and
third cloths; gold, ermine, linen and the rest are the same for everyone."""
import math
import numpy as np
from canvas import *
from face import CX, AXIS, EYE_Y, MOUTH_Y, MOUTH_X
from hair import locks, seeds_in

MAN = [(47, 90), (73, 90), (100, 99), (110, 110), (113, 160), (7, 160), (10, 110), (20, 99)]
LADY = [(50, 89), (70, 89), (91, 96), (102, 105), (106, 160), (14, 160), (18, 105), (29, 96)]


def form(spread=115.0, top=90.0):
    return lambda x, y: np.clip(0.58 - (x - 60) / spread - (y - top) / 200.0, 0.1, 0.92)


def panel(cv, mask, mat, light=None, folds=(), part=None, dither=0.02, cuts=(0.88, 0.68, 0.46, 0.26), line=True):
    """A garment piece shaded by the light, with folds: a dark crease and a lit ridge on the
    side the light comes from."""
    light = light or form()
    if part is None:
        part = cv.new_part(line)
    val = light(XX + 0.5, YY + 0.5) * np.ones((H, W))
    for path, depth in folds:
        d, _, side = path_dist(path)
        val = val - depth * np.exp(-(d / 1.1) ** 2) * 0.55
        val = val + depth * np.exp(-((d - 2.2) / 1.3) ** 2) * 0.22 * (side < 0)
        val = val - depth * np.exp(-((d - 2.5) / 1.6) ** 2) * 0.12 * (side > 0)
    cv.put(mask, mat, tones(val, cuts=cuts, dither=dither), part)
    return part


def ermine(cv, mask, rng, spots=0.06):
    """White fur with black tail-tips and a ruffled edge."""
    part = cv.new_part()
    m = mask.copy()
    edge = m & ~(shift(m, 1, 0, False) & shift(m, -1, 0, False) & shift(m, 0, 1, False) & shift(m, 0, -1, False))
    m[edge & (rng.random((H, W)) < 0.35)] = False
    val = 0.62 - (XX - 60) / 120 + (rng.random((H, W)) - 0.5) * 0.35
    cv.put(m, "ermine", np.minimum(tones(val, cuts=(0.8, 0.55, 0.32, 0.15)), 3), part)
    ys, xs = np.where(m)
    for i in rng.choice(len(xs), size=max(int(len(xs) * spots / 3), 1), replace=False):
        x, y = xs[i], ys[i]
        for dy in (0, 1, 2):
            if y + dy < H and m[y + dy, x]:
                cv.px(x, y + dy, "ermine", 4 if dy < 2 else 3, part)
    return part


def chain(cv, path, spacing=2.4):
    part = cv.new_part(False)
    pts = np.array(path, float)
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    for k, s in enumerate(np.arange(0, cum[-1], spacing)):
        x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
        if k % 2 == 0:
            for dx, dy, t in ((-1, 0, 2), (0, -1, 0), (1, 0, 3), (0, 1, 3), (-1, -1, 1), (1, 1, 4)):
                cv.px(x + dx, y + dy, "gold", t, part)
        else:
            cv.px(x, y, "gold", 1, part); cv.px(x + 1, y, "gold", 3, part)
    return part


def coin(cv, x, y, part, r=1.6, mat="gold"):
    cv.put(ellipse(x, y, r, r), mat, 2, part)
    cv.px(x - 0.5, y - 0.5, mat, 0, part)
    cv.px(x + 0.6, y + 0.6, mat, 3, part)


def gem(cv, x, y, mat="garnet", r=1.4, part=None):
    part = part or cv.new_part(False)
    cv.put(ellipse(x, y, r, r * 1.15), mat, 2, part)
    cv.px(x - 0.6, y - 0.6, mat, 0, part)
    cv.px(x + 0.6, y + 0.6, mat, 3, part)
    return part


def medallion(cv, x, y, r=5.5, stone="garnet"):
    part = cv.new_part()
    m = ellipse(x, y, r, r)
    val = 0.75 - (XX - x) / (r * 2.2) - (YY - y) / (r * 2.2)
    cv.put(m, "gold", tones(val, cuts=(0.95, 0.72, 0.45, 0.2)), part)
    ring = m & ~ellipse(x, y, r - 1.2, r - 1.2)
    cv.put(ring & (XX > x), "gold", 3)
    cv.put(ellipse(x, y, r * 0.45, r * 0.5), stone, 2)
    cv.px(x - 1, y - 1, stone, 0); cv.px(x, y - 1, stone, 1); cv.px(x + 1, y + 1, stone, 3)
    return part


def band(cv, path, width, mat, pattern=None, part=None, line=True):
    """A strip of trim along a path; pattern(i, j) -> shade, i along (pixels), j across (0..2)."""
    if part is None:
        part = cv.new_part(line)
    d, along, side = path_dist(path)
    total = np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.array(path, float), axis=0), axis=1))][-1]
    m = d <= width / 2
    j = np.clip(((side * d + width / 2) / width * 3).astype(int), 0, 2)
    i = np.floor(along * total).astype(int)
    t = np.where(j == 0, 1, np.where(j == 1, 2, 3)) if pattern is None else pattern(i, j)
    cv.put(m, mat, t, part)
    return part, m


def catenary(x0, x1, y_end, y_low, n=40):
    xs = np.linspace(x0, x1, n)
    m, h = (x0 + x1) / 2, (x1 - x0) / 2
    return list(zip(xs, y_low + (y_end - y_low) * ((xs - m) / h) ** 2))


def coin_strand(cv, x0, x1, y_end, y_low, spacing=3.9, r=1.7, part=None):
    part = part or cv.new_part(False)
    pts = np.array(catenary(x0, x1, y_end, y_low, 60))
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    for s in np.arange(1.5, cum[-1] - 1, spacing):
        coin(cv, np.interp(s, cum, pts[:, 0]), np.interp(s, cum, pts[:, 1]), part, r=r)
    return part


def pearls(cv, x0, x1, y_end, y_low, spacing=2.2):
    part = cv.new_part(False)
    pts = np.array(catenary(x0, x1, y_end, y_low, 60))
    cum = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    for s in np.arange(0.5, cum[-1], spacing):
        x = np.interp(s, cum, pts[:, 0]); y = np.interp(s, cum, pts[:, 1])
        cv.px(x, y, "pearl", 1, part); cv.px(x + 1, y, "pearl", 3, part)
    return part


GOLD_EMB = lambda i, j: np.where(j == 1, np.where(i % 4 == 0, 3, 1), np.where(j == 0, 2, 3))


def mail(cv, mask):
    """Riveted rings: a scale of small arcs, lit from the left."""
    part = cv.new_part()
    light = form()(XX + 0.5, YY + 0.5)
    ring = ((XX + (YY // 2) % 2) % 2 == 0) & (YY % 2 == 0)
    t = tones(light * 0.9 + 0.08)
    t = np.where(ring, np.maximum(t - 1, 0), np.minimum(t + 1, 4))
    cv.put(mask, "steel", t, part)
    return part


# =========================================================================== Vardish
def vardish_m_mantle(rng):
    back, cv = Canvas(), Canvas()
    ermine(back, poly([(44, 93), (49, 86), (60, 84.5), (72, 86), (77, 93), (70, 92), (60, 90), (50, 92)]), rng)
    panel(cv, poly(MAN), "cloth_b", folds=[([(60, 112), (60, 160)], 0.6), ([(52, 130), (50, 160)], 0.5),
                                           ([(69, 132), (71, 160)], 0.5)])
    panel(cv, poly([(50.5, 85), (70, 85), (72, 92), (61, 94.5), (49, 92)]), "linen")
    bp = cv.new_part(False)
    for y in range(137, 160, 7):
        coin(cv, 60, y, bp, r=1.2)
    left = poly([(49, 89), (38, 92), (22, 97), (12, 105), (8, 118), (5, 160), (36, 160), (39.5, 128), (43.5, 104), (47, 94)])
    right = poly([(71, 89), (82, 92), (98, 97), (108, 105), (112, 118), (115, 160), (84, 160), (80.5, 128), (76.5, 104), (73, 94)])
    panel(cv, left, "cloth_a", folds=[([(31, 104), (27, 130), (25, 160)], 1.0), ([(19, 112), (15, 135), (13, 160)], 0.9)])
    panel(cv, right, "cloth_a", folds=[([(90, 104), (94, 130), (96, 160)], 1.0), ([(101, 112), (105, 135), (107, 160)], 0.9),
                                       ([(84, 112), (86, 160)], 0.6)])
    ermine(cv, poly([(47, 88), (51, 91), (47.5, 104), (43.5, 128), (40.5, 160), (32, 160), (35.5, 127), (39.5, 103), (42, 93)]), rng)
    ermine(cv, poly([(73, 88), (69, 91), (72.5, 104), (76.5, 128), (79.5, 160), (88, 160), (84.5, 127), (80.5, 103), (78, 93)]), rng)
    chain(cv, catenary(45, 75, 95, 123))
    medallion(cv, 60, 129)
    return back, cv


def vardish_m_surcoat(rng):
    cv = Canvas()
    mail(cv, poly(MAN))
    # the coif's collar round the neck
    mail(cv, poly([(46, 92), (49, 84), (60, 82), (72, 84), (75, 92), (66, 95), (54, 95)]))
    sc = poly([(36, 101), (48, 95), (60, 98), (72, 95), (84, 101), (88, 160), (32, 160)])
    panel(cv, sc, "cloth_a", folds=[([(48, 118), (46, 160)], 0.7), ([(73, 118), (75, 160)], 0.7)])
    chev = poly([(36, 138), (60, 116), (84, 138), (84, 147), (60, 125), (36, 147)]) & sc
    panel(cv, chev, "cloth_b", line=False)
    band(cv, [(37, 101), (48, 95.5), (60, 98.5), (72, 95.5), (83, 101)], 2.6, "gold", line=False)
    # a cloak pinned at the near shoulder, thrown back over the far one
    cloak = poly([(84, 98), (100, 98), (110, 108), (114, 160), (92, 160), (88, 130), (86, 108)])
    panel(cv, cloak, "cloth_b", folds=[([(98, 110), (102, 160)], 0.8)])
    cloak2 = poly([(36, 98), (22, 98), (11, 108), (6, 160), (26, 160), (32, 130), (34, 108)])
    panel(cv, cloak2, "cloth_b", folds=[([(22, 110), (18, 160)], 0.8)])
    medallion(cv, 86, 101, r=3.5)
    return None, cv


def vardish_f_gown(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_a", folds=[([(36, 118), (32, 160)], 0.8), ([(84, 118), (88, 160)], 0.8),
                                            ([(26, 112), (22, 160)], 0.6), ([(95, 112), (99, 160)], 0.6)])
    chem = poly([(44, 96), (76, 96), (76, 110), (44, 110)])
    panel(cv, chem, "linen", folds=[([(50, 98), (50, 108)], 0.3), ([(60, 98), (60, 108)], 0.3), ([(70, 98), (70, 108)], 0.3)])
    band(cv, [(42.5, 95), (42.5, 111), (77.5, 111), (77.5, 95)], 3.2, "gold", pattern=GOLD_EMB)
    # laced bodice
    lp = cv.new_part(False)
    for y in range(115, 150, 4):
        cv.px(58, y, "linen", 1, lp); cv.px(59, y + 1, "linen", 2, lp); cv.px(61, y + 1, "linen", 2, lp); cv.px(62, y, "linen", 1, lp)
    pearls(cv, 49, 71, 90, 101)
    gem(cv, 60, 103, "garnet", 1.6)
    return None, cv


def vardish_f_surcoat(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_b", folds=[([(26, 112), (22, 160)], 0.7), ([(95, 112), (99, 160)], 0.7)])
    sc = poly([(38, 96), (50, 92), (60, 96), (70, 92), (82, 96), (86, 160), (34, 160)])
    panel(cv, sc, "cloth_a", folds=[([(42, 120), (40, 160)], 0.7), ([(78, 120), (80, 160)], 0.7)])
    ermine(cv, poly([(46, 97), (60, 100), (74, 97), (73, 160), (47, 160)]), rng)
    band(cv, [(39, 96.5), (50, 92.5), (60, 96.5), (70, 92.5), (81, 96.5)], 2.4, "gold", pattern=GOLD_EMB)
    for y in range(108, 160, 9):
        gem(cv, 60, y, "jade" if (y // 9) % 2 else "garnet", 1.3)
    pearls(cv, 50, 70, 90, 98)
    return None, cv


# =========================================================================== Kharzani
def kharzani_m_kaftan(rng):
    cv = Canvas()
    panel(cv, poly(MAN), "cloth_c", folds=[([(60, 105), (60, 160)], 0.5)])
    panel(cv, poly([(52, 85), (68, 85), (70, 92), (60, 96), (50, 92)]), "linen")
    left = poly([(48, 89), (38, 92), (22, 97), (12, 105), (8, 118), (6, 160), (52, 160), (54, 120), (56, 100), (50, 93)])
    right = poly([(72, 89), (82, 92), (98, 97), (108, 105), (112, 118), (114, 160), (66, 160), (64, 120), (63, 100), (70, 93)])
    panel(cv, left, "cloth_a", folds=[([(30, 104), (26, 160)], 0.9), ([(18, 112), (14, 160)], 0.8), ([(42, 115), (40, 160)], 0.6)])
    panel(cv, right, "cloth_a", folds=[([(90, 104), (94, 160)], 0.9), ([(101, 112), (105, 160)], 0.8), ([(78, 115), (80, 160)], 0.6)])
    band(cv, [(49, 90), (55, 100), (53.5, 120), (52, 160)], 3.6, "gold", pattern=GOLD_EMB)
    band(cv, [(71, 90), (64.5, 100), (65.5, 120), (67, 160)], 3.6, "gold", pattern=GOLD_EMB)
    # a sash at the waist, its knot hanging on the near side
    sash = poly([(9, 151), (111, 151), (112, 160), (8, 160)])
    panel(cv, sash, "cloth_b", folds=[([(14, 155.5), (106, 155.5)], 0.6)])
    panel(cv, poly([(78, 150), (86, 149), (88, 160), (79, 160)]), "cloth_b", folds=[([(83, 151), (83, 160)], 0.6)])
    gem(cv, 60, 112, "jade", 1.8)
    return None, cv


def kharzani_m_cloak(rng):
    cv = Canvas()
    panel(cv, poly(MAN), "cloth_b", folds=[([(50, 115), (48, 160)], 0.6), ([(70, 115), (72, 160)], 0.6)])
    band(cv, [(60, 92), (60, 160)], 3.0, "gold", pattern=GOLD_EMB)
    # the hood thrown back, bunched behind the neck
    hood = poly([(42, 92), (46, 84), (60, 81), (74, 84), (78, 92), (70, 90), (60, 88), (50, 90)])
    panel(cv, hood, "cloth_c", folds=[([(48, 88), (72, 88)], 0.6)])
    left = poly([(48, 90), (36, 93), (20, 98), (10, 106), (6, 120), (4, 160), (34, 160), (38, 126), (44, 104)])
    right = poly([(72, 90), (84, 93), (100, 98), (110, 106), (114, 120), (116, 160), (86, 160), (82, 126), (76, 104)])
    panel(cv, left, "cloth_c", folds=[([(28, 102), (22, 160)], 1.0), ([(16, 112), (11, 160)], 0.9), ([(36, 112), (33, 160)], 0.7)])
    panel(cv, right, "cloth_c", folds=[([(92, 102), (98, 160)], 1.0), ([(104, 112), (109, 160)], 0.9), ([(84, 112), (87, 160)], 0.7)])
    band(cv, [(44, 104), (38, 126), (34, 160)], 2.4, "gold", line=False)
    band(cv, [(76, 104), (82, 126), (86, 160)], 2.4, "gold", line=False)
    medallion(cv, 60, 101, r=3.8, stone="jade")
    return None, cv


def kharzani_f_collar(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_a", folds=[([(42, 112), (38, 160)], 0.8), ([(78, 112), (83, 160)], 0.9),
                                            ([(30, 108), (26, 160)], 0.7), ([(92, 108), (96, 160)], 0.7),
                                            ([(52, 124), (51, 160)], 0.5), ([(69, 124), (70, 160)], 0.5)])
    band(cv, [(43, 90), (47, 97), (54, 101.5), (60, 102.5), (66, 101.5), (73, 97), (77, 90)], 6.5, "gold", pattern=GOLD_EMB)
    gp = cv.new_part(False)
    for x, y in [(48, 95), (54, 99), (60, 100.5), (66, 99), (72, 95)]:
        cv.px(x, y, "garnet", 1, gp)
    band(cv, [(60, 105), (60, 160)], 5, "gold", pattern=lambda i, j: np.where(j == 1, np.where(i % 5 == 0, 3, 1), 2))
    for y in range(110, 160, 10):
        cv.px(60, y, "garnet", 1, gp)
    coin_strand(cv, 45, 75, 102, 118)
    coin_strand(cv, 45, 75, 103, 129)
    return None, cv


def kharzani_f_coat(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_c", folds=[([(56, 110), (55, 160)], 0.4), ([(64, 110), (65, 160)], 0.4)])
    left = poly([(50, 89), (40, 92), (29, 96), (18, 105), (14, 160), (50, 160), (52, 120), (54, 100), (52, 93)])
    right = poly([(70, 89), (80, 92), (91, 96), (102, 105), (106, 160), (70, 160), (68, 120), (66, 100), (68, 93)])
    panel(cv, left, "cloth_a", folds=[([(30, 108), (26, 160)], 0.8), ([(42, 116), (40, 160)], 0.6)])
    panel(cv, right, "cloth_a", folds=[([(90, 108), (94, 160)], 0.8), ([(78, 116), (80, 160)], 0.6)])
    band(cv, [(51, 90), (54, 100), (52, 120), (50.5, 160)], 3.4, "gold", pattern=GOLD_EMB)
    band(cv, [(69, 90), (66, 100), (68, 120), (69.5, 160)], 3.4, "gold", pattern=GOLD_EMB)
    pearls(cv, 50, 70, 91, 103)
    coin_strand(cv, 47, 73, 94, 112, spacing=3.4, r=1.5)
    gem(cv, 60, 113.5, "jade", 1.5)
    # jewelled belt
    bp, bm = band(cv, [(14, 150), (106, 150)], 4, "gold", pattern=lambda i, j: np.where(i % 6 == 0, 3, np.where(j == 1, 1, 2)))
    for x in range(20, 104, 12):
        gem(cv, x, 150, "garnet" if (x // 12) % 2 else "jade", 1.2)
    return None, cv


# =========================================================================== Ryumon
MON = ["...WWW...",
       ".WW...WW.",
       ".W..W..W.",
       "W..WWW..W",
       "W.WW.WW.W",
       "W..WWW..W",
       ".W..W..W.",
       ".WW...WW.",
       "...WWW..."]


def crest(cv, x, y, part=None, mat="white"):
    part = part or cv.new_part(False)
    for r, row in enumerate(MON):
        for c, ch in enumerate(row):
            if ch == "W":
                cv.px(x - 4 + c, y - 4 + r, mat, 1, part)
    return part


def collars(cv, layers, depth=113):
    """Crossed collars, outermost first: [(material, shade pattern)], each a V a little inside the last."""
    for k, (mat, wd) in enumerate(layers):
        inset = k * 2.6
        for side in (-1, 1):
            band(cv, [(60 + side * (11 - inset), 88), (60 + side * (7.5 - inset * 0.7), 100), (60, depth - k * 2)], wd, mat,
                 pattern=lambda i, j: np.where(j == 0, 1, 2))


def ryumon_m_kamishimo(rng):
    cv = Canvas()
    panel(cv, poly(MAN), "cloth_b", folds=[([(30, 112), (26, 160)], 0.8), ([(90, 112), (94, 160)], 0.8)])
    band(cv, [(52, 88), (55.5, 100), (60, 113)], 3.2, "white")
    band(cv, [(68, 88), (64.5, 100), (60, 113)], 3.2, "white")
    band(cv, [(49, 89), (53, 101), (60, 117)], 4.2, "cloth_b", pattern=lambda i, j: np.where(j == 0, 1, 2))
    band(cv, [(71, 89), (67, 101), (60, 117)], 4.2, "cloth_b", pattern=lambda i, j: np.where(j == 0, 1, 2))
    left = poly([(47, 91), (51, 103), (57, 120), (54, 160), (34, 160), (36, 118), (38, 100)])
    right = poly([(73, 91), (69, 103), (63, 120), (66, 160), (86, 160), (84, 118), (82, 100)])
    panel(cv, left, "cloth_a", folds=[([(45, 120), (44, 160)], 0.6)])
    panel(cv, right, "cloth_a", folds=[([(75, 120), (76, 160)], 0.6)])
    for side in (-1, 1):
        if side < 0:
            wing = poly([(49, 89), (32, 89.5), (14, 87), (5, 85), (8, 92), (22, 102), (36, 108), (46, 106)])
        else:
            wing = poly([(71, 89), (88, 89.5), (106, 87), (115, 85), (112, 92), (98, 102), (84, 108), (74, 106)])
        xs = range(12, 46, 5) if side < 0 else range(78, 110, 5)
        folds = [([(x, 88.5 - abs(x - 60) * 0.08), (x + side * 2, 103 - abs(x - 60) * 0.15)], 0.7) for x in xs]
        panel(cv, wing, "cloth_a", light=lambda x, y: np.clip(0.78 - (x - 60) / 150 - (y - 88) / 28, 0.1, 0.95), folds=folds)
    cp = cv.new_part(False)
    crest(cv, 44, 120, cp); crest(cv, 76, 120, cp)
    return None, cv


def ryumon_m_armour(rng):
    cv = Canvas()
    panel(cv, poly(MAN), "cloth_b")
    collars(cv, [("cloth_b", 4.0), ("white", 3.0)], depth=108)
    # the cuirass: lacquered plates in rows, laced in the house colour
    dou = poly([(34, 104), (48, 98), (60, 102), (72, 98), (86, 104), (90, 160), (30, 160)])
    rows = ((YY - 104) // 7) % 2
    light = form()(XX + 0.5, YY + 0.5)
    t = tones(light * 0.9 + 0.05)
    p = cv.new_part()
    cv.put(dou, "black", np.minimum(t + 1, 4), p)
    lace = dou & (((YY - 104) % 7) < 3) & (((XX + (YY // 7) * 2) % 4) < 2)
    cv.put(lace, "cloth_a", np.maximum(t - 1, 0))
    cv.put(dou & (((YY - 104) % 7) == 6), "black", 4)
    # shoulder guards
    for side in (-1, 1):
        if side < 0:
            sode = poly([(46, 94), (24, 97), (10, 106), (8, 130), (30, 132), (36, 112)])
        else:
            sode = poly([(74, 94), (96, 97), (110, 106), (112, 130), (90, 132), (84, 112)])
        sp = cv.new_part()
        cv.put(sode, "black", np.minimum(t + 1, 4), sp)
        lace_s = sode & (((YY - 97) % 6) < 3) & (((XX + (YY // 6) * 2) % 4) < 2)
        cv.put(lace_s, "cloth_a", np.maximum(t - 1, 0))
        cv.put(sode & (((YY - 97) % 6) == 5), "black", 4)
    cp = cv.new_part(False)
    crest(cv, 60, 122, cp, mat="gold")
    return None, cv


def ryumon_f_uchikake(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_a", folds=[([(30, 108), (26, 160)], 0.8), ([(90, 108), (94, 160)], 0.8),
                                            ([(44, 120), (42, 160)], 0.6), ([(76, 120), (78, 160)], 0.6)])
    collars(cv, [("cloth_a", 4.6), ("cloth_c", 3.0), ("cloth_b", 3.0), ("white", 2.6)], depth=118)
    # scattered blossoms on the outer robe
    fp = cv.new_part(False)
    r2 = np.random.default_rng(7)
    lady = poly(LADY)
    for _ in range(26):
        x, y = r2.uniform(16, 104), r2.uniform(100, 158)
        if not lady[int(y), int(x)] or abs(x - 60) < 16:
            continue
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.px(x + dx, y + dy, "white" if (dx or dy) else "gold", 1 if (dx or dy) else 1, fp)
    obi = poly([(20, 146), (100, 146), (101, 160), (19, 160)])
    panel(cv, obi, "gold", light=lambda x, y: np.clip(0.7 - (x - 60) / 200, 0.2, 0.9))
    band(cv, [(19, 152), (101, 152)], 2, "cloth_b", line=False)
    return None, cv


def ryumon_f_kosode(rng):
    cv = Canvas()
    panel(cv, poly(LADY), "cloth_a", folds=[([(30, 108), (26, 160)], 0.8), ([(90, 108), (94, 160)], 0.8)])
    collars(cv, [("cloth_a", 4.0), ("white", 3.0)], depth=116)
    obi = poly([(18, 136), (102, 136), (103, 160), (17, 160)])
    panel(cv, obi, "cloth_b", light=lambda x, y: np.clip(0.7 - (x - 60) / 200, 0.2, 0.9))
    band(cv, [(17, 146), (103, 146)], 2.2, "gold", line=False)
    gem(cv, 60, 146, "jade", 1.6)
    cp = cv.new_part(False)
    crest(cv, 34, 118, cp); crest(cv, 86, 118, cp)
    return None, cv


OUTFITS = {
    ("vardish", "m"): {"mantle": vardish_m_mantle, "surcoat": vardish_m_surcoat},
    ("vardish", "f"): {"gown": vardish_f_gown, "surcoat": vardish_f_surcoat},
    ("kharzani", "m"): {"kaftan": kharzani_m_kaftan, "cloak": kharzani_m_cloak},
    ("kharzani", "f"): {"collar": kharzani_f_collar, "coat": kharzani_f_coat},
    ("ryumon", "m"): {"kamishimo": ryumon_m_kamishimo, "armour": ryumon_m_armour},
    ("ryumon", "f"): {"uchikake": ryumon_f_uchikake, "kosode": ryumon_f_kosode},
}


# =========================================================================== headwear
def crown(lady):
    """A gold crown over the hair: a jewelled band and points."""
    cv = Canvas()
    p = cv.new_part()
    y0 = 19 if not lady else 18
    xs = np.arange(39, 82) if not lady else np.arange(41, 80)
    cx = 60.5
    for x in xs:
        yb = y0 + 0.010 * (x - cx) ** 2
        for k in range(4 if not lady else 3):
            cv.px(x, yb - k, "gold", 1 if k == 0 else (2 if x < cx else 3) if k < 3 else 3, p)
    pts = [44, 52, 60, 68, 76] if not lady else [46, 53, 60, 67, 74]
    for i, px in enumerate(pts):
        yb = y0 + 0.010 * (px - cx) ** 2 - 3
        hgt = (6 if i % 2 == 0 else 4) if not lady else (4 if i % 2 == 0 else 3)
        for k in range(hgt):
            w = max(0, 1 - k // 2)
            for dx in range(-w, w + 1):
                cv.px(px + dx, yb - k, "gold", 1 if dx <= 0 else 3, p)
        top_mat = "pearl" if (lady or i % 2) else "garnet"
        cv.px(px, yb - hgt, top_mat, 1, p)
    for i, x in enumerate(range(44, 78, 8)):
        cv.px(x, y0 + 0.010 * (x - cx) ** 2 - 1.5, "garnet" if i % 2 == 0 else "jade", 1, p)
    return cv


def turban(rng, jewel=False, mat="cloth_c"):
    cv = Canvas()
    m = poly([(37, 34), (36, 24), (40, 14), (48, 8), (60, 6), (72, 8), (80, 14), (84, 24), (83, 34), (72, 32), (60, 31.5), (48, 32)])
    folds = [([(38, 30), (52, 16), (66, 8)], 0.8), ([(40, 33), (60, 18), (80, 12)], 0.8), ([(52, 32), (72, 20), (83, 18)], 0.7),
             ([(64, 32), (78, 24), (84, 26)], 0.6)]
    panel(cv, m, mat, light=lambda x, y: np.clip(0.75 - (x - 58) / 70 - (y - 10) / 60, 0.1, 0.95), folds=folds)
    if jewel:
        gp = cv.new_part(False)
        medallion(cv, 58, 22, r=3.4, stone="jade")
        for k, (dx, dy) in enumerate([(0, -4), (1, -6), (2, -8), (2, -10), (3, -12), (2, -14)]):
            cv.px(58 + dx, 22 + dy, "white", 1 if k % 2 else 2, gp)
            cv.px(59 + dx, 22 + dy, "white", 2, gp)
    return cv


def veil(rng, lady_head=True):
    """A veil over the hair, framing the face and falling to the shoulders, edged in gold."""
    back = Canvas()
    bm = poly([(36, 34), (31, 60), (26, 100), (22, 128), (98, 128), (94, 100), (89, 60), (84, 34)])
    panel(back, bm, "cloth_c", light=lambda x, y: np.clip(0.55 - (x - 60) / 90 - (y - 60) / 200, 0.1, 0.9),
          folds=[([(34, 70), (28, 128)], 0.8), ([(86, 70), (92, 128)], 0.8)])
    cv = Canvas()
    face = poly([(43, 46), (44, 38), (48, 33), (55, 31), (61, 31), (68, 33), (74, 38), (77, 46), (79, 62), (74, 80), (60, 86),
                 (46, 80), (41, 62)])
    dome = [(60 + 25.5 * math.cos(a), 31 - 19 * math.sin(a)) for a in np.linspace(math.pi * 0.98, 0.02, 15)]
    m = poly([(34.5, 34)] + dome + [(86, 34), (87.5, 52), (91, 80), (97, 112), (85, 116), (78, 100), (72, 92), (48, 92),
              (40, 100), (33, 116), (23, 112), (29, 80), (32.5, 52)]) & ~face
    panel(cv, m, "cloth_c", light=lambda x, y: np.clip(0.75 - (x - 58) / 70 - (y - 20) / 160, 0.1, 0.95),
          folds=[([(40, 40), (36, 70), (30, 110)], 0.9), ([(80, 40), (85, 70), (92, 110)], 0.9), ([(56, 9), (48, 20)], 0.4)])
    band(cv, [(41, 62), (43, 46), (44, 38), (48, 33), (55, 31), (61, 31), (68, 33), (74, 38), (77, 46), (79, 62)], 2.0, "gold",
         pattern=lambda i, j: np.where(i % 3 == 0, 3, 1), line=False)
    return back, cv


def circlet(coins=True):
    cv = Canvas()
    p = cv.new_part(False)
    ax = AXIS + 1
    for x in range(43, 79):
        y = 33.5 + 0.012 * (x - ax) ** 2
        cv.px(x, y, "gold", 1 if x < ax else 2, p)
        cv.px(x, y + 1, "gold", 3, p)
    if coins:
        for x in range(46, 77, 4):
            coin(cv, x, 33.5 + 0.012 * (x - ax) ** 2 + 2.5, p, r=1.1)
    cv.put(ellipse(ax, 37.5, 1.3, 2.0), "garnet", 2, p)
    cv.px(ax - 0.5, 36.5, "garnet", 0, p)
    return cv


def tiara():
    """A tall jewelled tiara over a veil."""
    cv = Canvas()
    p = cv.new_part()
    m = poly([(44, 30), (48, 20), (54, 14), (60, 10), (66, 14), (72, 20), (76, 30), (68, 27), (60, 26), (52, 27)])
    panel(cv, m, "gold", light=lambda x, y: np.clip(0.8 - (x - 58) / 60 - (y - 14) / 50, 0.1, 0.95), part=p)
    gem(cv, 60, 17, "garnet", 2.0)
    gem(cv, 52, 23, "jade", 1.2); gem(cv, 68, 23, "jade", 1.2)
    pp = cv.new_part(False)
    for x in range(46, 75, 3):
        cv.px(x, 28.5 + 0.02 * (x - 60) ** 2 * 0.3, "pearl", 1, pp)
    return cv


def eboshi():
    """A lord's tall black lacquered cap, tied under the chin."""
    cv = Canvas()
    m = poly([(46, 22), (47, 8), (52, 0), (62, -2), (70, 2), (73, 10), (74, 22), (66, 24), (54, 24)])
    panel(cv, m, "black", light=lambda x, y: np.clip(0.8 - (x - 56) / 40, 0.1, 0.95),
          folds=[([(52, 6), (60, 14), (68, 10)], 0.7)])
    cp = cv.new_part(False)
    for y in range(24, 75):
        t = (y - 24) / 50
        cv.px(78.5 - t * 1.5, y, "white", 2, cp)
    for x in range(45, 76):
        cv.px(x, 23, "white", 1, cp)
    return cv


def kanzashi(rich=False):
    """Pins and a comb in a raised hairstyle."""
    cv = Canvas()
    p = cv.new_part(False)
    for x in range(52, 68):
        cv.px(x, 15, "gold" if rich else "leather", 1, p)
        cv.px(x, 16, "gold" if rich else "leather", 2, p)
        if x % 2 == 0:
            cv.px(x, 17, "gold" if rich else "leather", 3, p)
    for (x, y, dx) in ((44, 20, -1), (76, 20, 1)):
        for k in range(9):
            cv.px(x + dx * k, y - k * 0.6, "gold", 1 if k % 3 else 2, p)
        gem(cv, x + dx * 9, y - 6, "garnet", 1.5, p)
    if rich:
        for k, x in enumerate(range(48, 74, 4)):
            for j in range(5):
                cv.px(x, 13 - j * 1.5, "gold", 2, p)
            cv.px(x, 13 - 7, "pearl" if k % 2 else "garnet", 1, p)
    return cv
