"""Authoring tool: gives Bannerfall's painted portraits a picture of their eyes shut.

Edda, Farah and Kaede are paintings, one per expression, and none was painted with
closed eyes. This reads each painting, finds the two eyes (the whites are the only grey
on a face), paints skin over them from what surrounds them, and draws the lashes resting
along the lower lid. Because the shut eyes are made from the open painting, they sit
exactly on it: swapping one for the other is a blink.

Only the strip of face the eyes are in is saved (EYES, the same rectangle on every
painting): assets/portraits/blink/<who>_<expression>.png. The game lays that strip over
the painting when it needs the shut face (StoryArt.eyes_shut), so fifteen blinks cost a
few KB each instead of fifteen more paintings.

    python3 tools/portrait_blink.py [preview_dir]

Run it again after a portrait is repainted. With a preview_dir it also writes, for each
character, the open and shut eyes side by side, enlarged, to check by eye. Needs Pillow
and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
WHO = ["edda", "farid", "kaede"]
EXPRESSIONS = ["neutral", "amused", "thoughtful", "concerned", "warm"]

# The strip that is saved: x, y, width, height. StoryArt.EYES must say the same.
EYES = (112, 136, 96, 40)
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


def shut(who, expression):
    """The painting with both eyes closed, as an RGBA float array."""
    a = load(who, expression)
    out = a.copy()
    boxes = whites(a)
    if len(boxes) != 2:
        raise SystemExit("%s %s: found %d eyes, not 2" % (who, expression, len(boxes)))
    for i, box in enumerate(boxes):
        xa, xb, upper, lower = opening(a, box, who, (who, expression, i))
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
        k = (hole * fade[None, :])[..., None]
        out[..., :3] = out[..., :3] * (1 - k) + lid[..., :3] * k
        # The lashes, resting along the lower lid, thickest in the middle, with the lid
        # shaded a little toward them.
        for x in range(xa, xb + 1):
            t = (x - xa) / max(1.0, xb - xa)
            line = lower(x) - 1.0
            thick = 1.2 + 1.5 * np.sin(np.pi * t) ** 0.6
            for y in range(int(line) - 5, int(line) + 3):
                d = y - line
                if d < 0:
                    shade = 0.10 * max(0.0, 1.0 + d / 4.0)
                    out[y, x, :3] = out[y, x, :3] * (1 - shade) + lash * shade
                cover = 0.92 * max(0.0, min(1.0, thick / 2.0 + 0.5 - abs(d)))
                out[y, x, :3] = out[y, x, :3] * (1 - cover) + lash * cover
    return out


def picture(a):
    return Image.fromarray(np.clip(np.round(a), 0, 255).astype("uint8"), "RGBA")


def main():
    preview = sys.argv[1] if len(sys.argv) > 1 else ""
    out_dir = os.path.join(PORTRAITS, "blink")
    os.makedirs(out_dir, exist_ok=True)
    ex, ey, ew, eh = EYES
    for who in WHO:
        k = 5
        sheet = Image.new("RGB", (ew * k * 2, eh * k * len(EXPRESSIONS)), (40, 36, 32))
        for row, expression in enumerate(EXPRESSIONS):
            a = load(who, expression)
            b = np.clip(np.round(shut(who, expression)), 0, 255)
            changed = np.argwhere(np.any(np.round(a) != b, axis=-1))
            (y0, x0), (y1, x1) = changed.min(axis=0), changed.max(axis=0)
            if x0 < ex or y0 < ey or x1 >= ex + ew or y1 >= ey + eh:
                raise SystemExit("%s %s: the eyes reach outside EYES (%d,%d..%d,%d)" % (who, expression, x0, y0, x1, y1))
            strip = picture(b).crop((ex, ey, ex + ew, ey + eh))
            strip.save(os.path.join(out_dir, "%s_%s.png" % (who, expression)), optimize=True)
            if preview:
                for col, face in enumerate((picture(a), picture(b))):
                    on = Image.new("RGBA", face.size, (40, 36, 32, 255))
                    on.alpha_composite(face)
                    part = on.crop((ex, ey, ex + ew, ey + eh)).resize((ew * k, eh * k), Image.NEAREST)
                    sheet.paste(part, (col * ew * k, row * eh * k))
        if preview:
            os.makedirs(preview, exist_ok=True)
            sheet.save(os.path.join(preview, "blink_%s.png" % who))
    print("wrote %d strips to %s" % (len(WHO) * len(EXPRESSIONS), out_dir))


if __name__ == "__main__":
    main()
