"""Put kit sprites together the way the game does (lord_portrait.gd): layer by layer, each
pixel taking its material's shade from the lord's palettes, and an outline on every layer's
edge where it meets nothing or something behind it."""
import numpy as np
from PIL import Image
from canvas import W, H, MATERIALS, NO_LINE, LINE


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


def compose(sprites, pal, backdrop=None):
    """sprites: [(x0, y0, rgba)] back to front; pal: material name -> six hex shades."""
    mat = np.zeros((H, W), np.uint8); tone = np.zeros((H, W), np.uint8)
    flag = np.zeros((H, W), np.uint8); layer = np.full((H, W), -1, np.int32)
    for li, (x0, y0, a) in enumerate(sprites):
        h, w = a.shape[:2]
        on = a[..., 3] > 0
        sub = (slice(y0, y0 + h), slice(x0, x0 + w))
        mat[sub][on] = a[..., 0][on]
        tone[sub][on] = a[..., 1][on]
        flag[sub][on] = a[..., 2][on]
        layer[sub][on] = li
    drawn = layer >= 0
    line = np.zeros((H, W), bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nl = np.full((H, W), -1, np.int32)
        ys = slice(max(dy, 0), H + min(dy, 0)); yd = slice(max(-dy, 0), H + min(-dy, 0))
        xs = slice(max(dx, 0), W + min(dx, 0)); xd = slice(max(-dx, 0), W + min(-dx, 0))
        nl[ys, xs] = layer[yd, xd]
        if dy < 0:
            nl[H - 1, :] = layer[H - 1, :]     # the frame's bottom edge cuts the figure; no line there
        line |= drawn & ((nl < 0) | (nl < layer))
    line &= (flag & NO_LINE) == 0
    tone = np.where(line, LINE, tone)
    out = np.zeros((H, W, 4), np.uint8)
    for mi, name in enumerate(MATERIALS):
        if name not in pal:
            continue
        cols = np.array([rgb(h) for h in pal[name]])
        m = drawn & (mat == mi)
        out[m, :3] = cols[np.clip(tone[m], 0, 5)]
        out[m, 3] = 255
    im = Image.fromarray(out, "RGBA")
    if backdrop is not None:
        b = backdrop.copy()
        b.alpha_composite(im)
        return b
    return im
