"""Authoring tool: gives Bannerfall's painted portraits the faces they weren't painted with.

Edda, Farah and Kaede are paintings, one per expression. None was painted mid-blink,
glancing aside or with a lifted brow. This makes those faces from each painting's own
pixels, so they sit exactly on it:

  shut   the eyes closed: skin mended over them from what surrounds them, the lid lit,
         the lashes resting along the lower lid
  half   the lids halfway down (the middle of a blink)
  soft   the lids a third of the way down (a fond look, the bottom of a nod)
  away   the irises moved further the way they lean (a glance aside)
  brow1  the brows half raised: the skin between brow and lashes stretches, nothing is cut
  brow2  the brows raised

Only the strip of face the eyes and brows are in is saved (FACE_STRIP, the same rectangle
on every painting), one strip per face above, stacked in that order (a face that can't
be made, such as a glance from eyes already lowered, is left clear):
assets/portraits/face/<who>_<expression>.png. The game lays a strip over the painting
when that face is first needed (StoryArt.face_frame).

It also writes assets/portraits/face/<who>_hair.png: how freely each pixel of a
character's loose hair may swing (white swings most), for the shader that moves the head
and hair (assets/shaders/portrait_life.gdshader).

    python3 tools/portrait_faces.py [preview_dir]

Run it again after a portrait is repainted. With a preview_dir it also writes, for each
character, every face side by side, enlarged, to check by eye. Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
WHO = ["edda", "farid", "kaede"]
EXPRESSIONS = ["neutral", "amused", "thoughtful", "concerned", "warm"]
# The paintings dressed for the wedding (tools/portrait_wedding.py): the same faces.
WEDDING = ["wedding_neutral", "wedding_warm", "wedding_amused"]

# The strip that is saved: x, y, width, height. StoryArt.FACE must say the same.
FACE_STRIP = (106, 104, 104, 72)
FRAMES = ["shut", "half", "soft", "away", "brow1", "brow2"]
# How far each face closes the lids, and raises the brows (pixels at the arch).
LIDS = {"half": 0.6, "soft": 0.35}
BROWS = {"brow1": 1.4, "brow2": 2.8}
GLANCE = 3
# Where to look for a face's eyes at all.
FACE = (95, 110, 235, 200)
# The hairline either side of the eyes: an eye is not followed into the hair.
HAIR_LEFT = {"edda": 119, "farid": 123, "kaede": 120}
HAIR_RIGHT = {"edda": 198, "farid": 197, "kaede": 193}
# Eyes the finder can't see (all but shut already): left, right, top, bottom of the opening.
BY_HAND = {("farid", "thoughtful", 0): (124, 141, 160, 167)}
# Lashes are drawn in the painting's own darkest tone, warmed toward this so they read
# as lashes and not as ink.
LASH_BROWN = np.array([70.0, 38.0, 26.0])


def plain(expression):
    """The everyday expression a painting was made from ("wedding_warm" is "warm")."""
    return expression.replace("wedding_", "")


def load(who, expression):
    path = os.path.join(PORTRAITS, "%s_%s.png" % (who, expression))
    return np.array(Image.open(path).convert("RGBA")).astype(float)


def saturation_value(c):
    most = np.max(c[..., :3], axis=-1) / 255.0
    least = np.min(c[..., :3], axis=-1) / 255.0
    return np.where(most > 0, (most - least) / np.maximum(most, 1e-6), 0), most


def blobs(mask):
    """Groups of touching pixels in a mask, each a list of (y, x)."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    out = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            group = []
            while stack:
                cy, cx = stack.pop()
                group.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
            out.append(group)
    return out


def whites(a):
    """The white of each eye as a box (x0, y0, x1, y1), the viewer's left eye first."""
    x0, y0, x1, y1 = FACE
    c = a[y0:y1, x0:x1]
    s, v = saturation_value(c)
    found = sorted(blobs((s < 0.30) & (v > 0.45) & (c[..., 3] > 200)), key=len, reverse=True)[:2]
    boxes = []
    for b in found:
        boxes.append((x0 + min(p[1] for p in b), y0 + min(p[0] for p in b),
                      x0 + max(p[1] for p in b), y0 + max(p[0] for p in b)))
    return sorted(boxes)


def skin(a, box):
    """The colour of the cheek just under this eye."""
    x0, _y0, x1, y1 = box
    return np.median(a[y1 + 8:y1 + 16, x0:x1 + 10, :3].reshape(-1, 3), axis=0)


def open_eye(a, box, who):
    """The pixels of the open eye (lashes, white, iris): grown from the white inside a
    window, then filled column by column so a mid-brown iris leaves no hole."""
    x0, y0, x1, y1 = box
    up = 5 if x0 < 150 else 6
    wx0, wx1 = max(HAIR_LEFT[who], x0 - 20), min(HAIR_RIGHT[who], x1 + 20)
    wy0, wy1 = y0 - up, y1 + 4
    c = a[wy0:wy1 + 1, wx0:wx1 + 1]
    s, v = saturation_value(c)
    like = (v < 0.30 * skin(a, box).max() / 255.0) | ((s < 0.33) & (v > 0.3))
    m = np.zeros(a.shape[:2], bool)
    for b in blobs(like):
        if any(x0 <= wx0 + p[1] <= x1 and y0 <= wy0 + p[0] <= y1 for p in b):
            for p in b:
                m[wy0 + p[0], wx0 + p[1]] = True
            break
    for x in range(wx0, wx1 + 1):
        ys = np.nonzero(m[:, x])[0]
        if len(ys):
            m[ys[0]:ys[-1] + 1, x] = True
    return m


def opening(a, box, who, key):
    """The eye's two corners (x) and its upper and lower edge, each a smooth curve of x."""
    if key in BY_HAND:
        xa, xb, top, bottom = BY_HAND[key]
        mid, half, edge = (xa + xb) / 2.0, (xb - xa) / 2.0, (top + bottom) / 2.0
        return (xa, xb,
                lambda x: edge + (top - edge) * (1 - ((x - mid) / half) ** 2),
                lambda x: edge + (bottom - edge) * (1 - ((x - mid) / half) ** 2))
    m = open_eye(a, box, who)
    xs = [x for x in range(m.shape[1]) if m[:, x].any()]
    if len(xs) < 6:
        raise SystemExit("no eye found for %s: add it to BY_HAND" % (key,))
    tops = np.array([np.nonzero(m[:, x])[0][0] for x in xs], float)
    bottoms = np.array([np.nonzero(m[:, x])[0][-1] for x in xs], float)
    X = np.array(xs, float)
    upper, lower = np.polyfit(X, tops, 2), np.polyfit(X, bottoms, 2)
    # The found edge is ragged: sit each curve on the outside of it.
    lift = np.percentile(tops - np.polyval(upper, X), 10)
    drop = np.percentile(bottoms - np.polyval(lower, X), 90)
    return (xs[0], xs[-1],
            lambda x: np.polyval(upper, x) + lift,
            lambda x: np.polyval(lower, x) + drop)


def mend(img, hole, floor, rounds=500):
    """Fill the hole with the skin around it: each pixel settles to the mean of its
    neighbours. Dark neighbours (lashes left behind, hair, brow) are not listened to."""
    out = img.copy()
    ys, xs = np.nonzero(hole)
    y0, y1, x0, x1 = ys.min() - 1, ys.max() + 2, xs.min() - 1, xs.max() + 2
    sub = out[y0:y1, x0:x1, :3]
    h = hole[y0:y1, x0:x1]
    heard = (h | (sub.max(axis=-1) / 255.0 > floor)).astype(float)
    sub[h] = sub[(~h) & (heard > 0)].mean(axis=0)
    for _ in range(rounds):
        total = np.zeros_like(sub)
        n = np.zeros(sub.shape[:2])
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            total += np.roll(sub * heard[..., None], shift, axis)
            n += np.roll(heard, shift, axis)
        mean = total / np.maximum(n, 1)[..., None]
        sub[h & (n > 0)] = mean[h & (n > 0)]
    return out


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def grow(mask, n=1):
    for _ in range(n):
        mask = mask | np.roll(mask, 1, 0) | np.roll(mask, -1, 0) | np.roll(mask, 1, 1) | np.roll(mask, -1, 1)
    return mask


def diffuse(img, hole, heard, rounds=400):
    """Fill `hole` from the `heard` pixels around it (and from itself as it fills)."""
    out = img.copy()
    ys, xs = np.nonzero(hole)
    y0, y1, x0, x1 = ys.min() - 2, ys.max() + 3, xs.min() - 2, xs.max() + 3
    sub = out[y0:y1, x0:x1, :3]
    h = hole[y0:y1, x0:x1]
    w = (h | heard[y0:y1, x0:x1]).astype(float)
    source = (~h) & (w > 0)
    if source.any():
        sub[h] = sub[source].mean(axis=0)
    for _ in range(rounds):
        total = np.zeros_like(sub)
        n = np.zeros(sub.shape[:2])
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            total += np.roll(sub * w[..., None], shift, axis)
            n += np.roll(w, shift, axis)
        mean = total / np.maximum(n, 1)[..., None]
        sub[h & (n > 0)] = mean[h & (n > 0)]
    return out


def sample(a, sx, sy):
    """The picture read at (sx, sy) everywhere: bilinear, weighted by alpha."""
    h, w = a.shape[:2]
    sx = np.clip(sx, 0, w - 1.001)
    sy = np.clip(sy, 0, h - 1.001)
    x0 = np.floor(sx).astype(int)
    y0 = np.floor(sy).astype(int)
    fx = (sx - x0)[..., None]
    fy = (sy - y0)[..., None]
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    v = (pm[y0, x0] * (1 - fx) * (1 - fy) + pm[y0, x0 + 1] * fx * (1 - fy)
         + pm[y0 + 1, x0] * (1 - fx) * fy + pm[y0 + 1, x0 + 1] * fx * fy)
    alpha = np.maximum(v[..., 3:4], 1e-6)
    v[..., :3] = v[..., :3] * 255.0 / alpha
    return v


def eyes(a, who, expression):
    """Everything known about each eye: its opening, and the lid that would cover it."""
    boxes = whites(a)
    if len(boxes) != 2:
        raise SystemExit("%s %s: found %d eyes, not 2" % (who, expression, len(boxes)))
    parts = []
    out = a.copy()
    for i, box in enumerate(boxes):
        xa, xb, upper, lower = opening(a, box, who, (who, plain(expression), i))
        left, right = HAIR_LEFT[who], HAIR_RIGHT[who]
        tone = skin(a, box)
        # Everything the lid covers, a little wider toward the nose to take the tear duct.
        reach = (5, 3) if box[0] > 150 else (3, 5)
        hole = np.zeros(a.shape[:2], bool)
        for x in range(max(left, xa - reach[0]), min(right, xb + reach[1]) + 1):
            xc = min(max(x, xa), xb)
            hole[int(np.floor(upper(xc))) - 3:int(np.ceil(lower(xc))) + 3, x] = True
        dark = a[hole][:, :3]
        lash = dark[np.argsort(dark.sum(axis=1))[:max(4, len(dark) // 8)]].mean(axis=0)
        lash = lash * 0.55 + LASH_BROWN * 0.45
        lid = mend(out, hole, 0.62 * tone.max() / 255.0)
        # A shut lid is a lit dome of skin, not the socket's shadow: lighter to its middle.
        deep = np.zeros(a.shape[:2])
        core = hole.copy()
        while core.any():
            deep[core] += 1
            core = core & np.roll(core, 1, 0) & np.roll(core, -1, 0) & np.roll(core, 1, 1) & np.roll(core, -1, 1)
        lit = (np.clip((deep - 1) / 2.5, 0, 1) * 0.76)[..., None]
        lid[..., :3] = lid[..., :3] * (1 - lit) + tone * 0.97 * lit
        # Where the eye runs under the hair, the painting keeps its own edge.
        fade = np.ones(a.shape[1])
        if xa - reach[0] <= left:
            fade[:left + 4] = np.clip((np.arange(left + 4) - left + 1) / 4.0, 0, 1)
        if xb + reach[1] >= right:
            fade[right - 3:] = np.clip((right + 1 - np.arange(right - 3, a.shape[1])) / 4.0, 0, 1)
        parts.append(dict(box=box, xa=xa, xb=xb, upper=upper, lower=lower, hole=hole,
                          k=hole * fade[None, :], lid=lid, lash=lash, tone=tone,
                          inner_right=box[0] < 150, by_hand=(who, plain(expression), i) in BY_HAND))
    return parts


def lashes(out, p, line_of, amount):
    """The lashes along `line_of(x)`, thickest in the middle, the lid shaded toward them.
    Thicker while the lid is still up, where lashes and lid crease lie together."""
    xa, xb = p["xa"], p["xb"]
    for x in range(xa, xb + 1):
        t = (x - xa) / max(1.0, xb - xa)
        line = line_of(x)
        thick = (1.2 + 1.5 * np.sin(np.pi * t) ** 0.6) * (1.0 + 0.45 * (1 - amount))
        for y in range(int(line) - 5, int(line) + 4):
            d = y - line
            if d < 0:
                shade = 0.10 * max(0.0, 1.0 + d / 4.0)
                out[y, x, :3] = out[y, x, :3] * (1 - shade) + p["lash"] * shade
            cover = 0.92 * max(0.0, min(1.0, thick / 2.0 + 0.5 - abs(d)))
            out[y, x, :3] = out[y, x, :3] * (1 - cover) + p["lash"] * cover


def shut(a, parts):
    """Both eyes closed: the whole opening is lid, the lashes rest along the lower lid."""
    out = a.copy()
    for p in parts:
        k = p["k"][..., None]
        out[..., :3] = out[..., :3] * (1 - k) + p["lid"][..., :3] * k
        lashes(out, p, lambda x, p=p: p["lower"](x) - 1.0, 1.0)
    return out


def close(a, parts, amount):
    """The upper lids brought down by `amount` (1 = shut) over the open eye."""
    out = a.copy()
    for p in parts:
        xa, xb, upper, lower = p["xa"], p["xb"], p["upper"], p["lower"]
        def line_of(x):
            xc = min(max(x, xa), xb)
            top = upper(xc) + 1.0
            return top + amount * (lower(xc) - 1.0 - top)
        ys, xs = np.nonzero(p["hole"])
        for x in range(xs.min(), xs.max() + 1):
            line = line_of(x)
            for y in range(ys.min(), ys.max() + 1):
                if p["hole"][y, x]:
                    cover = np.clip(line - y + 0.5, 0, 1) * p["k"][y, x]
                    out[y, x, :3] = out[y, x, :3] * (1 - cover) + p["lid"][y, x, :3] * cover
        lashes(out, p, line_of, amount)
    return out


def irises(a, parts):
    """Each eye's visible ball, its whites and its iris, found in the painting."""
    s, v = saturation_value(a)
    found = []
    for p in parts:
        xa, xb, upper, lower = p["xa"], p["xb"], p["upper"], p["lower"]
        ball = np.zeros(a.shape[:2], bool)
        for x in range(xa + 1, xb):
            ball[int(np.ceil(upper(x) + 2.5)):int(np.floor(lower(x) - 0.5)) + 1, x] = True
        pale = ball & (s < 0.40)
        if pale.sum() < 4:
            return None
        white = pale & (v > 0.60 * np.percentile(v[pale], 95))
        rest = ball & ~white
        ys, xs = np.nonzero(rest)
        if not len(ys):
            return None
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        best, score = None, 1e9
        for b in blobs(rest[y0:y1, x0:x1]):
            if len(b) < 12:
                continue
            d = min(v[y0 + q[0], x0 + q[1]] for q in b) - 0.002 * len(b)
            if d < score:
                best, score = b, d
        if best is None:
            return None
        iris = np.zeros(a.shape[:2], bool)
        for q in best:
            iris[y0 + q[0], x0 + q[1]] = True
        found.append(dict(ball=ball, white=white, iris=iris))
    return found


def glance_side(found):
    """Which way the irises move (+1 the viewer's right, -1 left): the way they already
    lean, so the white they leave behind shows. A glance the other way, into the white,
    hardly reads."""
    lean = 0.0
    for e in found:
        lean += np.nonzero(e["iris"])[1].mean() - np.nonzero(e["white"])[1].mean()
    return 1 if lean >= 0 else -1


def glance(a, parts):
    """The irises moved aside. None where a glance wouldn't read: eyes lowered or nearly
    shut, with too little white to move across."""
    found = irises(a, parts)
    if found is None or any(p["by_hand"] for p in parts) or min(e["white"].sum() for e in found) < 12:
        return None                                    # eyes lowered or all but shut
    dx = glance_side(found) * GLANCE
    out = a.copy()
    for e in found:
        ball, white, iris = e["ball"], e["white"], e["iris"]
        bare = diffuse(a, iris, white)                     # the eye with no iris in it
        ratio = np.ones_like(a[..., :3])
        ratio[iris] = a[iris][:, :3] / np.maximum(bare[iris][:, :3], 1.0)
        # Where the iris runs under a lid or into a corner, there is more of it out of sight.
        ys = np.nonzero(iris.any(axis=1))[0]
        for y in ys:
            cols = np.nonzero(iris[y])[0]
            lo, hi = cols[0], cols[-1]
            if not white[y, max(0, lo - 1)]:
                ratio[y, lo - abs(dx):lo] = ratio[y, lo]
            if not white[y, min(a.shape[1] - 1, hi + 1)]:
                ratio[y, hi + 1:hi + 1 + abs(dx)] = ratio[y, hi]
        moved = np.roll(ratio, dx, axis=1)
        area = ball & (iris | np.roll(iris, dx, axis=1) | grow(iris, 1))
        out[area, :3] = np.clip((bare[..., :3] * moved)[area], 0, 255)
        keep = area & ~iris & ~np.roll(iris, dx, axis=1) & ~white   # shading that was never iris
        out[keep, :3] = a[keep][:, :3]
    return out


def brows(a, parts, who, lift):
    """Each brow raised `lift` pixels, most at its inner end. Nothing is cut out: the brow
    moves whole, the forehead above it gives, and only the thin strip of plain skin just
    under it stretches, so the lid's crease stays where it was."""
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    _s, v = saturation_value(a)
    move = np.zeros((h, w))
    for p in parts:
        xa, xb, upper = p["xa"], p["xb"], p["upper"]
        tone = p["tone"].max() / 255.0
        top = int(min(upper(x) for x in range(xa, xb + 1)))
        x0, x1 = max(HAIR_LEFT[who] + 2, xa - 10), min(HAIR_RIGHT[who] - 5, xb + 8)
        ya, yb = top - 17, top - 2
        found = blobs(v[ya:yb, x0:x1 + 1] < 0.70 * tone)
        if not found:
            return None
        cols = {}
        for (y, x) in max(found, key=len):
            cols.setdefault(x0 + x, []).append(ya + y)
        if len(cols) < 8:
            return None
        bx = np.array(sorted(cols))
        bx0, bx1 = bx.min(), bx.max()
        # The brow's upper and lower edge in every column, held level past its ends.
        cx = np.clip(np.arange(w), bx0, bx1)
        upper_edge = np.interp(cx, bx, [min(cols[x]) for x in bx])[None, :]
        lower_edge = np.interp(cx, bx, [max(cols[x]) for x in bx])[None, :]
        t = np.clip((xx - bx0) / max(1.0, bx1 - bx0), 0, 1)
        if p["inner_right"]:
            t = 1 - t                                         # t = 0 at the inner end
        # The far brow is seen at a slant: it moves less.
        far = 0.8 if p["inner_right"] else 1.0
        along = -lift * far * (1.0 - 0.35 * t)
        along = along * smooth(bx0 - 8, bx0, xx) * (1 - smooth(bx1, bx1 + 8, xx))
        weight = np.where(yy < upper_edge - 2, smooth(upper_edge - 14, upper_edge - 2, yy),
                          np.where(yy <= lower_edge + 1, 1.0, 1 - smooth(lower_edge + 1, lower_edge + 4, yy)))
        move += along * weight
    moved = np.abs(move) > 1e-4
    out = a.copy()
    out[moved, :3] = sample(a, xx, yy - move)[moved, :3]
    return out


def faces(who, expression):
    """Every face made from one painting, by name; a face that can't be made is the
    painting itself (so it changes nothing)."""
    a = load(who, expression)
    parts = eyes(a, who, expression)
    made = {"shut": shut(a, parts)}
    for name, amount in LIDS.items():
        made[name] = close(a, parts, amount)
    away = glance(a, parts)
    made["away"] = away if away is not None else a.copy()
    for name, lift in BROWS.items():
        raised = brows(a, parts, who, lift)
        made[name] = raised if raised is not None else a.copy()
    return a, made


# Where each character's loose hair hangs (x0, y0, x1, y1): the shader may swing hair
# found there. Strands are held where they leave the head and free toward their tips.
HAIR_HANGS = {
    "edda": [(72, 140, 136, 264)],
    "farid": [(72, 128, 136, 272), (196, 186, 252, 254)],
    "kaede": [(84, 128, 136, 276), (200, 194, 224, 258)],
}
HAIR_FREE = (145.0, 245.0)


def hair(who):
    """How freely each pixel may swing (0..1), as an 8-bit picture of the painting's size."""
    a = load(who, "neutral")
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    _s, v = saturation_value(a)
    tone = skin(a, whites(a)[0])
    hairy = (a[..., 3] > 128) & (v < 0.72 * tone.max() / 255.0)
    region = np.zeros((h, w), bool)
    for x0, y0, x1, y1 in HAIR_HANGS[who]:
        region[y0:y1, x0:x1] = True
    # Skin (face, neck) never moves, and the hair beside it hardly does.
    near = np.abs(a[..., :3] - tone).max(axis=-1) < 40
    held = near.copy()
    room = np.zeros((h, w))
    for step in range(1, 8):
        held = grow(held, 1)
        room[~held] = step
    free = (grow(hairy & region, 2) & region).astype(float) * smooth(0, 7, room)
    free *= smooth(HAIR_FREE[0], HAIR_FREE[1], yy)
    for _ in range(3):                                         # soft, so nothing tears
        free = (free + np.roll(free, 1, 0) + np.roll(free, -1, 0) + np.roll(free, 1, 1) + np.roll(free, -1, 1)) / 5.0
    free *= ~near
    return Image.fromarray(np.clip(np.round(free / max(free.max(), 1e-6) * 255), 0, 255).astype("uint8"), "L")


def picture(a):
    return Image.fromarray(np.clip(np.round(a), 0, 255).astype("uint8"), "RGBA")


def main():
    preview = sys.argv[1] if len(sys.argv) > 1 else ""
    out_dir = os.path.join(PORTRAITS, "face")
    os.makedirs(out_dir, exist_ok=True)
    fx, fy, fw, fh = FACE_STRIP
    missing = []
    for who in WHO:
        k = 3
        sheet = Image.new("RGB", (fw * k * (len(FRAMES) + 1), fh * k * (len(EXPRESSIONS) + len(WEDDING))), (40, 36, 32))
        for row, expression in enumerate(EXPRESSIONS + WEDDING):
            if not os.path.exists(os.path.join(PORTRAITS, "%s_%s.png" % (who, expression))):
                continue
            a, made = faces(who, expression)
            atlas = Image.new("RGBA", (fw, fh * len(FRAMES)))
            for i, name in enumerate(FRAMES):
                b = np.clip(np.round(made[name]), 0, 255)
                changed = np.argwhere(np.any(np.round(a) != b, axis=-1))
                if len(changed) == 0:
                    # Left clear: the game reads a clear strip as "no such face".
                    missing.append("%s %s %s" % (who, expression, name))
                    continue
                (y0, x0), (y1, x1) = changed.min(axis=0), changed.max(axis=0)
                if x0 < fx or y0 < fy or x1 >= fx + fw or y1 >= fy + fh:
                    raise SystemExit("%s %s %s: the change reaches outside FACE_STRIP (%d,%d..%d,%d)"
                                     % (who, expression, name, x0, y0, x1, y1))
                atlas.paste(picture(b).crop((fx, fy, fx + fw, fy + fh)), (0, fh * i))
            atlas.save(os.path.join(out_dir, "%s_%s.png" % (who, expression)), optimize=True)
            if preview:
                for col, face in enumerate([a] + [made[n] for n in FRAMES]):
                    on = Image.new("RGBA", (a.shape[1], a.shape[0]), (40, 36, 32, 255))
                    on.alpha_composite(picture(face))
                    part = on.crop((fx, fy, fx + fw, fy + fh)).resize((fw * k, fh * k), Image.NEAREST)
                    sheet.paste(part, (col * fw * k, row * fh * k))
        hair(who).save(os.path.join(out_dir, "%s_hair.png" % who), optimize=True)
        if preview:
            os.makedirs(preview, exist_ok=True)
            sheet.save(os.path.join(preview, "faces_%s.png" % who))
    print("wrote face strips and %d hair maps to %s" % (len(WHO), out_dir))
    if missing:
        print("not made (the painting is used instead):", ", ".join(missing))


if __name__ == "__main__":
    main()
