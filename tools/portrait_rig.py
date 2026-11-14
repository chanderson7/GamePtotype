"""Authoring tool: Bannerfall's romance portraits, rebuilt as rigs we can dress.

Edda, Farah and Kaede were painted at 384x512, one painting per expression. This takes
those paintings (assets/portraits/source/) and makes our own version of each at twice the
detail, 768x1024, from a rig:

  - a body: the neutral painting below the neck, so every expression wears the same
    clothes; each expression's own head above it (blended across the neck)
  - a map of what each pixel is (skin, eyes, hair, inner and outer garment, an accent
    panel, trim, a belt or sash, metal, an accessory), made from outlines and colour rules
    below and saved as a picture you can paint over by hand
    (assets/portraits/rig/<who>/regions_<expression>.png, one flat colour per part:
    REGION_COLORS)
  - an outfit (assets/portraits/rig/outfits.json): for each part, "keep" (the painter's
    own colours) or a ramp of colours, dark to light, which the part is dyed with by its
    own light and shade, so the painted folds stay

and paints it at 768x1024 with the detail the doubled size has room for: single strands
in the hair, a twill in wool, a weave in linen, a bright rim on metal.

    python3 tools/portrait_rig.py regions            # (re)make every region map
    python3 tools/portrait_rig.py render             # the game's portraits, everyday dress
    python3 tools/portrait_rig.py preview <who> <outfit> [out_dir]

`render` writes assets/portraits/<who>_<expression>.png (and the wedding paintings,
<who>_wedding_<expression>.png), their other faces at twice the size in
assets/portraits/face/, and copies the hair maps there. Before it, after a painting in
source/ changes: tools/portrait_wedding.py (the wedding gowns, on the 384x512 paintings),
then tools/portrait_faces.py (their blinks and glances). `regions` only writes a map
that isn't there yet, so hand-painted fixes stay; delete a map to make it again.

Needs Pillow and numpy.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "assets", "portraits")
SOURCE = os.path.join(GAME, "source")
RIG = os.path.join(GAME, "rig")
WHO = ["edda", "farid", "kaede"]
EVERYDAY = ["neutral", "amused", "thoughtful", "concerned", "warm"]
WEDDING = ["wedding_neutral", "wedding_warm", "wedding_amused"]
SCALE = 2
# The strip of face the other faces are saved for (StoryArt.FACE), and their order.
FACE_STRIP = (106, 104, 104, 72)
FRAMES = ["shut", "half", "soft", "away", "brow1", "brow2"]
# Where the head meets the body: above it, each expression's own painting; below, the
# neutral one. The same lines tools/portrait_wedding.py dresses below.
NECK = {"edda": 236, "farid": 236, "kaede": 228}
BLEND = 6

REGIONS = ["none", "skin", "eyes", "hair", "inner", "outer", "accent", "trim", "belt", "metal", "accessory"]
REGION_COLORS = {
    "none": (0, 0, 0), "skin": (240, 190, 150), "eyes": (60, 220, 120), "hair": (150, 70, 20),
    "inner": (250, 250, 230), "outer": (30, 90, 200), "accent": (150, 40, 150), "trim": (255, 210, 40),
    "belt": (120, 60, 30), "metal": (255, 120, 0), "accessory": (0, 200, 220),
}

# Each painting's parts, in the 384x512 painting's pixels: outlines (polygons), boxes
# (x0, y0, x1, y1) and the rules that pick a part's pixels out by colour.
RIGS = {
    "edda": {
        "face": [(118, 118), (150, 100), (205, 104), (226, 130), (230, 175), (222, 205), (205, 230),
                 (180, 240), (160, 240), (140, 228), (122, 205), (116, 160)],
        "ear": [(222, 140), (240, 138), (246, 160), (238, 186), (224, 188)],
        "neck": [(160, 225), (205, 228), (222, 200), (238, 190), (246, 214), (250, 250), (240, 275),
                 (200, 300), (170, 330), (150, 300), (150, 260)],
        "inner": [(150, 255), (172, 251), (200, 262), (230, 252), (246, 240), (262, 235), (268, 243),
                  (281, 272), (256, 297), (233, 330), (220, 363), (88, 363), (95, 340), (112, 318),
                  (130, 290), (134, 268)],
        "shoulders": 260,
        "hair": "chestnut",
        "belt": [(84, 478, 262, 504)],
        "metal": [(138, 316, 170, 346), (112, 478, 145, 504)],
        "accessory": [],
        "accent_hue": None,
    },
    "farid": {
        "face": [(120, 112), (150, 100), (200, 104), (222, 125), (226, 165), (220, 200), (200, 225),
                 (170, 238), (150, 232), (130, 212), (122, 180), (118, 140)],
        "ear": [(224, 140), (244, 136), (252, 160), (244, 184), (226, 186)],
        "neck": [(150, 228), (205, 224), (222, 208), (236, 224), (240, 252), (222, 290), (188, 335),
                 (165, 300), (152, 262)],
        "inner": [(150, 250), (165, 246), (174, 272), (184, 334), (208, 318), (216, 262), (232, 242),
                  (266, 256), (262, 300), (234, 350), (210, 382), (204, 472), (100, 472), (100, 382),
                  (118, 330), (135, 284)],
        "shoulders": 262,
        "hair": "dark",
        "belt": [(110, 468, 256, 512)],
        "metal": [(96, 374, 182, 400)],
        "accessory": [],
        "accent_hue": None,
    },
    "kaede": {
        "face": [(118, 115), (150, 100), (205, 105), (232, 130), (234, 170), (225, 205), (205, 228),
                 (175, 236), (150, 228), (130, 208), (120, 175), (116, 140)],
        "ear": [(228, 140), (245, 138), (250, 160), (242, 182), (230, 184)],
        "neck": [(160, 228), (210, 226), (232, 215), (245, 240), (235, 262), (200, 300), (172, 322),
                 (158, 282), (158, 245)],
        "inner": [(163, 240), (176, 252), (196, 296), (236, 246), (250, 234), (254, 246), (232, 282),
                  (200, 322), (160, 358), (136, 372), (118, 372), (122, 330), (138, 284), (152, 256)],
        "shoulders": 258,
        "hair": "dark",
        "belt": [],
        "metal": [(164, 378, 240, 408)],
        "accessory": [(252, 160, 300, 184)],
        "accent_hue": (280, 350),
    },
}


# ---------------------------------------------------------------- pictures
def load(path):
    return np.array(Image.open(path).convert("RGBA")).astype(float)


def save(a, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.clip(np.round(a), 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)


def hsv(a):
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / np.maximum(d, 1e-6)) % 6,
                 np.where(mx == g, (b - r) / np.maximum(d, 1e-6) + 2, (r - g) / np.maximum(d, 1e-6) + 4)) * 60
    return np.where(d > 0, h, 0), s, mx


def lum(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def poly(shape, pts):
    m = Image.new("L", (shape[1], shape[0]), 0)
    if pts:
        ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.array(m) > 0


def boxes(shape, bs):
    m = np.zeros(shape[:2], bool)
    for x0, y0, x1, y1 in bs:
        m[y0:y1, x0:x1] = True
    return m


def body(who, head, base):
    """`head`'s head over `base`'s body: above the neck, head; below it, base."""
    y = np.arange(head.shape[0], dtype=float)[:, None, None]
    k = np.clip((NECK[who] + BLEND - y) / (2.0 * BLEND), 0, 1)
    return head * k + base * (1 - k)


# ---------------------------------------------------------------- the parts
def segment(a, who):
    """What each pixel of a 384x512 painting is: an index into REGIONS."""
    R = RIGS[who]
    h, s, v = hsv(a)
    al = a[..., 3] > 100
    H, W = a.shape[:2]
    yy = np.mgrid[0:H, 0:W][0]
    lab = np.zeros((H, W), np.uint8)
    face = poly(a.shape, R["face"]) | poly(a.shape, R["ear"])
    neck = poly(a.shape, R["neck"])
    warm = (h < 45) | (h > 340)
    blue = (h > 150) & (h < 260)
    # The inner garment's outline is rough; the wool it overlaps (saturated blue) is not it.
    inner = poly(a.shape, R["inner"]) & al & ~face & ~(blue & (s > 0.25))
    below = yy >= R["shoulders"]
    # Garments: blue wool anywhere; the accent panel by its own hue; near-black outlines
    # below the shoulders go with the cloth they edge.
    lab[al & blue & (s > 0.10)] = REGIONS.index("outer")
    lab[al & (v < 0.13) & ~face & below] = REGIONS.index("outer")
    if R["accent_hue"]:
        lo, hi = R["accent_hue"]
        accent = al & (h > lo) & (h < hi) & (s > 0.12) & below
        lab[accent] = REGIONS.index("accent")
        # The panel's woven border: lighter and greyer than the panel it's worked on.
        near = accent.copy()
        for _ in range(4):
            near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
        lab[al & near & ~accent & (v > 0.26) & (s < 0.40) & ~inner & below & ~blue] = REGIONS.index("trim")
    # Hair: above the shoulders, outside the face and neck.
    if R["hair"] == "chestnut":
        hairish = warm & (s > 0.42)
    else:
        hairish = (v < 0.42) & ~(blue & (s > 0.25))
    lab[al & hairish & ~below & ~face & ~neck & ~inner] = REGIONS.index("hair")
    # Skin: face, ear, neck; the strands across them stay hair.
    lab[al & (face | neck) & warm & ~inner] = REGIONS.index("skin")
    skin_v = np.median(v[face & al & warm]) if (face & al & warm).any() else 0.6
    lab[al & (face | neck) & ~inner & (v < skin_v * (0.62 if R["hair"] == "chestnut" else 0.50)) & (s > 0.40)] = REGIONS.index("hair")
    # Eyes: cool or grey pixels in the face.
    lab[al & face & (((h > 60) & (h < 260)) | (s < 0.18)) & (v > 0.2)] = REGIONS.index("eyes")
    # The inner garment: everything in its outline but the skin of the neck's V.
    lab[inner] = REGIONS.index("inner")
    lab[inner & neck & warm & (s >= 0.36) & (v > 0.25)] = REGIONS.index("skin")
    # Gold trim: on the garments, never on skin.
    gold = al & (h > 25) & (h < 70) & (s > 0.35) & (v > 0.22) & below & ~neck & ~face
    lab[gold] = REGIONS.index("trim")
    # A belt or sash (its gold stripes stay trim), metal, an accessory.
    belt = boxes(a.shape, R["belt"]) & al
    lab[belt & ~gold] = REGIONS.index("belt")
    metal = boxes(a.shape, R["metal"]) & al & (((h > 20) & (h < 60) & (s > 0.35) & (v > 0.25)) | ((v < 0.2) & warm))
    lab[metal] = REGIONS.index("metal")
    acc = boxes(a.shape, R["accessory"]) & al & ~face & warm
    lab[acc] = REGIONS.index("accessory")
    # Whatever is left: cloth below the shoulders, hair above.
    rest = al & (lab == 0)
    lab[rest & below] = REGIONS.index("outer")
    lab[rest & ~below] = REGIONS.index("hair")
    return lab


def regions_path(who, expression):
    return os.path.join(RIG, who, "regions_%s.png" % expression)


def write_regions(lab, path):
    out = np.zeros(lab.shape + (3,), np.uint8)
    for i, name in enumerate(REGIONS):
        out[lab == i] = REGION_COLORS[name]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(out, "RGB").save(path, optimize=True)


def read_regions(path):
    """A region map back from its picture: each pixel the part whose colour it's nearest."""
    rgb = np.array(Image.open(path).convert("RGB")).astype(int)
    cols = np.array([REGION_COLORS[n] for n in REGIONS])
    d = ((rgb[..., None, :] - cols[None, None]) ** 2).sum(-1)
    return d.argmin(-1).astype(np.uint8)


def regions_for(who, expression, painting):
    path = regions_path(who, expression)
    if os.path.exists(path):
        lab = read_regions(path)
        if lab.shape == painting.shape[:2]:
            return lab
    return segment(painting, who)


# ---------------------------------------------------------------- painting it again
def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], float)


def ramp(t, stops):
    cols = np.array([hexc(c) for c in stops])
    n = len(cols) - 1
    x = np.clip(t, 0, 1) * n
    i = np.minimum(np.floor(x).astype(int), n - 1)
    f = (x - i)[..., None]
    return cols[i] * (1 - f) + cols[i + 1] * f


def bleed(a, passes=8):
    """The figure's edge colours spread out into the clear pixels round it, so resizing
    doesn't draw in whatever colour the clear background happened to keep."""
    out = a.copy()
    known = a[..., 3] >= 128
    rgb = out[..., :3]
    for _ in range(passes):
        total = np.zeros_like(rgb)
        n = np.zeros(known.shape)
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            total += np.roll(rgb * known[..., None], shift, axis)
            n += np.roll(known, shift, axis)
        grow = ~known & (n > 0)
        rgb[grow] = total[grow] / n[grow][:, None]
        known = known | grow
    return out


def doubled(a):
    """The painting at twice the size: smooth inside, crisp at its edges and silhouette."""
    img = Image.fromarray(np.clip(np.round(bleed(a)), 0, 255).astype(np.uint8), "RGBA")
    w, h = img.size
    big = img.resize((w * SCALE, h * SCALE), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.0, percent=95, threshold=1))
    out = np.array(big).astype(float)
    out[..., 3] = np.array(img.split()[3].resize((w * SCALE, h * SCALE), Image.NEAREST)).astype(float)
    return out


def blur(f, n):
    for _ in range(n):
        f = (f + np.roll(f, 1, 0) + np.roll(f, -1, 0) + np.roll(f, 1, 1) + np.roll(f, -1, 1)) / 5.0
    return f


def strands(L, seed):
    """Fine strands of hair: noise drawn out along the way the painted hair runs."""
    gy, gx = np.gradient(blur(L, 1))
    jxx, jyy, jxy = blur(gx * gx, 4), blur(gy * gy, 4), blur(gx * gy, 4)
    ang = 0.5 * np.arctan2(2 * jxy, jxx - jyy)
    dy, dx = np.cos(ang), -np.sin(ang)
    H, W = L.shape
    noise = np.random.default_rng(seed).random((H, W))
    acc = noise.copy()
    n = 1
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    for sign in (1, -1):
        py, px = yy.copy(), xx.copy()
        for _ in range(7):
            iy = np.clip(np.round(py).astype(int), 0, H - 1)
            ix = np.clip(np.round(px).astype(int), 0, W - 1)
            py = py + sign * dy[iy, ix]
            px = px + sign * dx[iy, ix]
            iy = np.clip(np.round(py).astype(int), 0, H - 1)
            ix = np.clip(np.round(px).astype(int), 0, W - 1)
            acc += noise[iy, ix]
            n += 1
    return acc / n


def paint(a, lab, outfit, who, cloth=True):
    """`a` (a 384x512 painting) at twice the size, dressed in `outfit` ({part: "keep" or a
    ramp}), with the doubled size's detail. `cloth` False leaves cloth unwoven (the wedding
    gowns, which aren't mapped)."""
    big = doubled(a)
    lab2 = np.repeat(np.repeat(lab, SCALE, 0), SCALE, 1)
    rgb = big[..., :3]
    L = lum(big[..., :3])
    H, W = L.shape
    yy, xx = np.mgrid[0:H, 0:W]
    for i, name in enumerate(REGIONS):
        m = lab2 == i
        if name == "none" or not m.any():
            continue
        spec = outfit.get(name, "keep")
        woven = cloth and name in ("outer", "accent", "belt", "inner")
        if spec == "keep" and not woven:
            continue
        lo, hi = np.percentile(L[m], 2), np.percentile(L[m], 99)
        t0 = np.clip((L - lo) / max(1.0, hi - lo), 0, 1)
        t = t0.copy()
        if woven and name != "inner":
            t = t + ((((xx + yy) // 2) % 2) - 0.5) * 0.05 * (0.4 + t0)   # a twill, finer in the light
        elif woven:
            t = t + (((xx % 2) ^ (yy % 2)) - 0.5) * 0.035                 # linen's plain weave
        if spec == "keep":
            rgb[m] = np.clip(rgb[m] + ((t - t0) * (hi - lo))[m][:, None], 0, 255)
        else:
            rgb[m] = ramp(t, spec)[m]
    hair = lab2 == REGIONS.index("hair")
    if hair.any():
        s = strands(L, seed=WHO.index(who) + 1)
        light = np.clip((L - 40) / 140, 0, 1)
        rgb[hair] = np.clip(rgb[hair] + (((s - 0.5) * 2.2 * (0.35 + light)) * 18)[hair][:, None], 0, 255)
    metal = lab2 == REGIONS.index("metal")
    if metal.any():
        Lm = lum(rgb)
        rim = metal & (np.roll(Lm, 1, 0) + 25 < Lm) & (np.roll(Lm, 1, 1) + 25 < Lm)
        rgb[rim] = np.clip(rgb[rim] * 1.18 + 20, 0, 255)
    big[..., :3] = rgb
    return big


# ---------------------------------------------------------------- the game's portraits
def outfits():
    with open(os.path.join(RIG, "outfits.json")) as f:
        return json.load(f)


def painting(who, expression):
    """The 384x512 painting a rig is made from: this expression's head on the neutral
    (or the neutral wedding painting's) body, with its pinholes mended."""
    head = load(os.path.join(SOURCE, "%s_%s.png" % (who, expression)))
    neutral = "wedding_neutral" if expression.startswith("wedding_") else "neutral"
    base = load(os.path.join(SOURCE, "%s_%s.png" % (who, neutral)))
    return mend_holes(body(who, head, base))


def mend_holes(a, largest=400):
    """Small clear holes inside the figure (the generator left a few in the cloth), filled
    with the colour around them. A clear patch that reaches the picture's edge is the
    background, and stays."""
    clear = a[..., 3] < 128
    H, W = clear.shape
    seen = np.zeros_like(clear)
    out = a.copy()
    for y0 in range(H):
        for x0 in range(W):
            if not clear[y0, x0] or seen[y0, x0]:
                continue
            stack, group, edge = [(y0, x0)], [], False
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop()
                group.append((y, x))
                edge = edge or y in (0, H - 1) or x in (0, W - 1)
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < H and 0 <= nx < W and clear[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if edge or len(group) > largest:
                continue
            ys = np.array([p[0] for p in group])
            xs = np.array([p[1] for p in group])
            y1, y2 = max(0, ys.min() - 2), min(H, ys.max() + 3)
            x1, x2 = max(0, xs.min() - 2), min(W, xs.max() + 3)
            ring = ~clear[y1:y2, x1:x2]
            colour = a[y1:y2, x1:x2, :3][ring].mean(axis=0) if ring.any() else a[ys, xs, :3].mean(axis=0)
            out[ys, xs, :3] = colour
            out[ys, xs, 3] = 255
    return out


def make_regions():
    for who in WHO:
        for expression in EVERYDAY:
            path = regions_path(who, expression)
            if os.path.exists(path):
                print("kept", os.path.relpath(path, ROOT))
                continue
            write_regions(segment(painting(who, expression), who), path)
            print("wrote", os.path.relpath(path, ROOT))


def render(outfit_name="everyday"):
    dress = outfits()
    x, y, w, h = FACE_STRIP
    for who in WHO:
        outfit = dress[who][outfit_name]
        for expression in EVERYDAY + WEDDING:
            src = os.path.join(SOURCE, "%s_%s.png" % (who, expression))
            if not os.path.exists(src):
                continue
            a = painting(who, expression)
            wedding = expression.startswith("wedding_")
            lab = segment(a, who) if wedding else regions_for(who, expression, a)
            fit = {} if wedding else outfit
            save(paint(a, lab, fit, who, cloth=not wedding), os.path.join(GAME, "%s_%s.png" % (who, expression)))
            # Its other faces, painted the same way and cut from the doubled painting.
            strips_path = os.path.join(SOURCE, "face", "%s_%s.png" % (who, expression))
            if os.path.exists(strips_path):
                strips = load(strips_path)
                out = np.zeros((h * SCALE * len(FRAMES), w * SCALE, 4))
                for i in range(len(FRAMES)):
                    strip = strips[h * i:h * (i + 1)]
                    if strip[..., 3].max() == 0:
                        continue
                    face = a.copy()
                    face[y:y + h, x:x + w] = strip
                    # The strip's own parts (a raised brow is hair where skin was); the
                    # map's everywhere else, hand-painted fixes and all.
                    flab = lab.copy()
                    flab[y:y + h, x:x + w] = segment(face, who)[y:y + h, x:x + w]
                    done = paint(face, flab, fit, who, cloth=not wedding)
                    out[h * SCALE * i:h * SCALE * (i + 1)] = done[y * SCALE:(y + h) * SCALE, x * SCALE:(x + w) * SCALE]
                save(out, os.path.join(GAME, "face", "%s_%s.png" % (who, expression)))
            print("painted", who, expression)
        for hair in ("%s_hair.png" % who, "%s_wedding_hair.png" % who):
            src = os.path.join(SOURCE, "face", hair)
            if os.path.exists(src):
                Image.open(src).save(os.path.join(GAME, "face", hair), optimize=True)


def preview(who, outfit_name, out_dir):
    outfit = outfits()[who][outfit_name]
    os.makedirs(out_dir, exist_ok=True)
    for expression in EVERYDAY:
        a = painting(who, expression)
        lab = regions_for(who, expression, a)
        save(paint(a, lab, outfit, who), os.path.join(out_dir, "%s_%s_%s.png" % (who, outfit_name, expression)))
    print("wrote", out_dir)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "render"
    if what == "regions":
        make_regions()
    elif what == "render":
        render(sys.argv[2] if len(sys.argv) > 2 else "everyday")
    elif what == "preview":
        preview(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "/tmp/bannerfall-outfits")
    else:
        raise SystemExit(__doc__)
