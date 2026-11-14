"""The romance portraits: Edda, Farah and Kaede drawn in the lords' style (tools/pixel_kit)
on a grid 1.6 times theirs (192x256, shown at 768x1024), so they have more in them: lids,
lashes and ringed irises, shaded lips, hair lock by lock, cloth with folds and patterns.

    python3 tools/portrait_kit/build.py              the game's portraits (assets/portraits/)
    python3 tools/portrait_kit/build.py sheet [png]  every outfit of all three, side by side
    python3 tools/portrait_kit/build.py faces [png]  every expression and face of each
    python3 tools/portrait_kit/build.py template     assets/portraits/rig/<who>/template.png

Who each woman is (her face, colouring, hair) is PEOPLE below; what she wears is
assets/portraits/rig/outfits.json, a list of pieces per outfit (garb.py draws them). For
each outfit and expression the game gets the portrait, the strip of her face with her eyes
shut, half shut, soft, glancing aside and her brows raised (StoryArt.FACE; the game lays a
strip over the portrait to blink), and a map of what swings when her head moves.
Needs numpy and Pillow.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from canvas import *
import face as F
import garb as G
import hair as Hr

ROOT = os.path.dirname(os.path.dirname(HERE))
GAME = os.path.join(ROOT, "assets", "portraits")
RIG = os.path.join(GAME, "rig")
SCALE = 4                                   # 192x256 drawn at 768x1024
WHO = ["edda", "farid", "kaede"]
EXPRESSIONS = ["neutral", "amused", "thoughtful", "concerned", "warm"]
WEDDING = ["neutral", "warm", "amused"]
FRAMES = ["shut", "half", "soft", "away", "brow1", "brow2"]
# The strip of the face that changes between those: x, y, width, height on the grid.
# StoryArt.FACE says the same in portrait space (384x512: twice these).
FACE_STRIP = (60, 60, 64, 34)
# face.py, hair.py and what garb.py puts on her head are drawn with the chin 17 pixels above
# the shoulders, as the lords are; a woman's neck is shorter, so her head sits this much lower.
HEAD_DROP = 4

PEOPLE = {
    "edda": dict(
        head="heart", eye="almond", brow="soft", nose="fine", mouth="bow", freckles=14, skin="fair",
        hair=hx("d9925a", "b0683a", "864624", "5e2c16", "36180c", "281008"),
        iris=hx("a4b99a", "7d967c", "5d7662", "465a4c", "2c3a30", "1a1214")),
    "farid": dict(
        head="full", eye="round", brow="strong", nose="straight", mouth="full", freckles=0,
        skin={"skin": hx("e3b48a", "c99267", "ab714c", "865139", "5c352d", "361c1e"),
              "lip_f": hx("d98a80", "b85e58", "8f3e42", "662a32", "4a1c24", "361c1e")},
        hair=hx("806454", "58402f", "3c291f", "261914", "150d0b", "100908"), iris="brown"),
    "kaede": dict(
        head="oval", eye="long", brow="fine", nose="soft", mouth="fine", freckles=0, skin="warm",
        hair=hx("6e6672", "443c46", "2b252e", "1a161d", "0e0b11", "0a080c"), iris="dark"),
}

# What each expression does with her eyes (lid, gaze, cheek), her brows (far, near) and mouth.
MOODS = {
    "neutral":    dict(lid=0.0, brows=("rest", "rest"), mouth="rest"),
    "amused":     dict(lid=0.10, cheek=0.7, brows=("rest", "raised"), mouth="wry"),
    "thoughtful": dict(lid=0.30, gaze=(-1.0, 0.9), brows=("knit", "knit"), mouth="pursed"),
    "concerned":  dict(lid=-0.06, brows=("worried", "worried"), mouth="worried"),
    "warm":       dict(lid=0.14, cheek=1.0, brows=("lifted", "lifted"), mouth="smile"),
}


def outfits():
    with open(os.path.join(RIG, "outfits.json")) as f:
        return json.load(f)


def features(who, mood, frame=None):
    """Her eyes, brows, nose and mouth for an expression; `frame` is one of FRAMES, or None
    for the expression as it rests."""
    p = PEOPLE[who]
    m = MOODS[mood]
    lid, gaze, cheek = m.get("lid", 0.0), m.get("gaze", (0.0, 0.0)), m.get("cheek", 0.0)
    lift = 0.0
    if frame == "shut":
        lid = 1.0
    elif frame == "half":
        lid = max(0.58, lid + 0.3)
    elif frame == "soft":
        lid = max(0.32, lid + 0.16)
    elif frame == "away":
        gaze = (gaze[0] - 2.6, gaze[1] * 0.4)
    elif frame == "brow1":
        lift = 1.3
    elif frame == "brow2":
        lift = 2.6
    made = [F.eye("far", p["eye"], lid, gaze, cheek), F.eye("near", p["eye"], lid, gaze, cheek),
            F.brow("far", p["brow"], m["brows"][0], lift), F.brow("near", p["brow"], m["brows"][1], lift),
            F.nose(p["nose"]), F.mouth(p["mouth"], m["mouth"])]
    return [cv.moved(HEAD_DROP) for cv in made]


def lowered(cv):
    return cv.moved(HEAD_DROP) if cv is not None else None


class Figure:
    """One woman in one outfit: everything about the picture that an expression doesn't change."""

    def __init__(self, who, outfit):
        p = PEOPLE[who]
        self.who = who
        self.pal = palette(p["skin"], p["hair"], p["iris"])
        self.outfit = G.dress(outfit.get("pieces", []), np.random.default_rng(11), os.path.join(RIG, who, "layers"))
        o = self.outfit
        back, front, loose = Hr.STYLES[who](np.random.default_rng(7), unbound=outfit.get("hair") == "unbound")
        if o.covers_hair:
            back, loose = None, None
        pin = None
        if who == "kaede" and not o.covers_hair:
            pin = Hr.pin(*(o.pin or ("wood", "jade", None)))
        elif o.pin and not o.covers_hair:
            pin = Hr.pin(*o.pin)
        blush = 1.0 if outfit.get("blush") else 0.9
        self.under = [lowered(o.far_back), lowered(back), o.back, F.neck(chin=125 + HEAD_DROP), o.cv,
                      lowered(F.head(p["head"], freckles=p["freckles"], blush=blush))]
        self.over = [lowered(c) for c in (front, F.ear(p["head"], o.earring), loose, o.hat, pin)]
        # what swings as her head moves: loose strands (their tips most) and a veil's fall
        sway = o.sway.copy()
        if loose is not None:
            ys = np.where(loose.on.any(axis=1))[0]
            if len(ys):
                top = ys.min()
                sway = np.maximum(sway, np.where(loose.on, np.clip((YY - top) / max(30.0, (ys.max() - top) * 0.8), 0.15, 1.0), 0))
        self.sway = shift(sway, HEAD_DROP, 0, 0.0)

    def picture(self, mood, frame=None):
        out, _ = compose(self.under + features(self.who, mood, frame) + self.over, self.pal)
        return out


def big(a):
    return Image.fromarray(a, "RGBA").resize((W * SCALE, H * SCALE), Image.NEAREST)


def game_name(who, outfit_name, expression):
    return "%s_%s.png" % (who, expression) if outfit_name == "everyday" else "%s_%s_%s.png" % (who, outfit_name, expression)


def render():
    """Every portrait the game shows, its face strips and its sway map."""
    data = outfits()
    x, y, w, h = FACE_STRIP
    os.makedirs(os.path.join(GAME, "face"), exist_ok=True)
    for who in WHO:
        for outfit_name in data["_game"] + ["wedding"]:
            fig = Figure(who, data[who][outfit_name])
            for mood in (WEDDING if outfit_name == "wedding" else EXPRESSIONS):
                rest = fig.picture(mood)
                name = game_name(who, outfit_name, mood)
                big(rest).save(os.path.join(GAME, name), optimize=True)
                strips = np.zeros((h * len(FRAMES), w, 4), np.uint8)
                for i, frame in enumerate(FRAMES):
                    pic = fig.picture(mood, frame)
                    changed = np.any(pic != rest, axis=-1)
                    outside = changed.copy()
                    outside[y:y + h, x:x + w] = False
                    if outside.any():
                        raise SystemExit("%s %s: the %s face changes outside FACE_STRIP" % (name, mood, frame))
                    strips[h * i:h * (i + 1)] = pic[y:y + h, x:x + w]
                Image.fromarray(strips, "RGBA").resize((w * SCALE, h * SCALE * len(FRAMES)), Image.NEAREST).save(
                    os.path.join(GAME, "face", name), optimize=True)
                print("drew", name)
            hair_name = {"everyday": "%s_hair.png" % who}.get(outfit_name, "%s_%s_hair.png" % (who, outfit_name))
            Image.fromarray(np.round(fig.sway * 255).astype(np.uint8), "L").resize((W * 2, H * 2), Image.BILINEAR).save(
                os.path.join(GAME, "face", hair_name), optimize=True)


def sheet(path, scale=3, mood="neutral"):
    data = outfits()
    names = [n for n in data[WHO[0]] if not n.startswith("_")]
    tw, th = W * scale, H * scale
    out = Image.new("RGBA", (len(names) * (tw + 8) + 8, len(WHO) * (th + 8) + 8), (34, 30, 38, 255))
    for r, who in enumerate(WHO):
        for c, n in enumerate(names):
            if n not in data[who]:
                continue
            pic = Image.fromarray(Figure(who, data[who][n]).picture(mood), "RGBA").resize((tw, th), Image.NEAREST)
            out.alpha_composite(pic, (8 + c * (tw + 8), 8 + r * (th + 8)))
    out.save(path)
    print("wrote", path, names)


def faces(path, scale=3):
    """Each woman's five expressions, then the six faces of her neutral one."""
    data = outfits()
    crop = (40, 14, 160, 150)
    cw, ch = (crop[2] - crop[0]) * scale, (crop[3] - crop[1]) * scale
    cols = len(EXPRESSIONS) + len(FRAMES)
    out = Image.new("RGBA", (cols * (cw + 6) + 6, len(WHO) * (ch + 6) + 6), (34, 30, 38, 255))
    for r, who in enumerate(WHO):
        fig = Figure(who, data[who]["everyday"])
        pics = [fig.picture(m) for m in EXPRESSIONS] + [fig.picture("neutral", f) for f in FRAMES]
        for c, pic in enumerate(pics):
            im = Image.fromarray(pic, "RGBA").crop(crop).resize((cw, ch), Image.NEAREST)
            out.alpha_composite(im, (6 + c * (cw + 6), 6 + r * (ch + 6)))
    out.save(path)
    print("wrote", path)


def template(who):
    """Her figure with nothing on it, and marks where clothes sit: a guide to draw a piece
    of her own over (assets/portraits/rig/<who>/layers/<name>.png)."""
    fig = Figure(who, {"pieces": []})
    pic = fig.picture("neutral")
    marks = {
        (255, 60, 60): [(46, 154), (146, 154), (29, 168), (163, 168)],      # shoulders
        (255, 255, 255): [(80, 142), (112, 142)],                           # the base of the neck
        (60, 140, 255): [(96, 176)],                                        # the breastbone
        (60, 220, 90): [(133, 99 + HEAD_DROP)],                             # the near ear's lobe
        (255, 220, 40): [(x, int(round(51 + HEAD_DROP + 0.012 * (x - 97) ** 2))) for x in range(72, 123, 5)],   # the hairline
        (0, 220, 220): [(x, 244) for x in range(24, 170, 4)],               # the waist
    }
    for colour, points in marks.items():
        for x, y in points:
            pic[y - 1:y + 2, x - 1:x + 2] = (*colour, 255)
    os.makedirs(os.path.join(RIG, who, "layers"), exist_ok=True)
    path = os.path.join(RIG, who, "template.png")
    Image.fromarray(pic, "RGBA").save(path, optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "render"
    if what == "render":
        render()
    elif what == "sheet":
        sheet(sys.argv[2] if len(sys.argv) > 2 else "/tmp/bannerfall-outfits.png")
    elif what == "template":
        for who in (sys.argv[2:] or WHO):
            template(who)
    elif what == "faces":
        faces(sys.argv[2] if len(sys.argv) > 2 else "/tmp/bannerfall-faces.png")
    else:
        raise SystemExit(__doc__)
