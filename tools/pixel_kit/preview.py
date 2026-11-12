"""Preview lords from the built kit, put together as the game does it. For checking the art:

    python3 tools/pixel_kit/preview.py out.png
"""
import colorsys
import json
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from compose import compose
import palettes as P

KIT = os.path.join(HERE, "..", "..", "assets", "portraits", "kit")


def load():
    data = json.load(open(os.path.join(KIT, "kit.json")))
    atlas = np.array(Image.open(os.path.join(KIT, "kit.png")).convert("RGBA"))
    return data, atlas


def sprite(data, atlas, name):
    ax, ay, w, h, ox, oy = data["sprites"][name]
    return ox, oy, atlas[ay:ay + h, ax:ax + w]


def blend(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]; cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))


def palette(skin, hair, iris, lady, house, second, third, grey=0.0):
    s = P.SKINS[skin]
    d = dict(P.FIXED)
    d["skin"] = s["skin"]
    d["blush"] = [blend(c, "d85a5a", 0.22 if lady else 0.14) for c in s["skin"]]
    d["lip"] = s["lip_f" if lady else "lip_m"]
    hr = P.HAIRS[hair]
    if grey:
        hr = [blend(a, b, grey) for a, b in zip(hr, P.HAIRS["grey"])]
    d["hair"] = hr
    d["iris"] = P.IRISES[iris]
    d["cloth_a"] = P.house_ramp(house)
    d["cloth_b"] = P.house_ramp(second)
    d["cloth_c"] = P.house_ramp(third)
    return d


def lord(data, atlas, spec):
    """spec: dict of the choices the game makes from a lord's record."""
    g = "f" if spec["lady"] else "m"
    head = spec["head"]
    layers = []
    def put(n):
        if n in data["sprites"]:
            layers.append(sprite(data, atlas, n))
    hair = ("f_" if spec["lady"] else "m_") + spec["hair"]
    hat = spec.get("hat", "")
    garb = "garb/%s_%s_%s" % (spec["culture"], g, spec["cut"])
    put("hat/%s/back" % hat)
    put("hair/%s/back" % hair)
    put(garb + "/back")
    put("neck/" + g)
    put(garb + "/front")
    put("head/" + head)
    if spec.get("age", 0):
        put("age/%s%d" % (g, spec["age"]))
    state, mood, bmood = spec.get("eyes", "open"), spec.get("mouth", "rest"), spec.get("brows", "rest")
    put("eye/far/%s/%s/%s" % (spec["eye"], state, g)); put("eye/near/%s/%s/%s" % (spec["eye"], state, g))
    put("brow/far/%s/%s" % (spec["brow"], bmood)); put("brow/near/%s/%s" % (spec["brow"], bmood))
    put("nose/" + spec["nose"])
    put("mouth/%s/%s" % (spec["lips"], mood))
    put("hair/%s/front" % hair)
    if spec.get("beard"):
        put("beard/%s/%s" % (spec["beard"], head))
    if spec.get("ears", True):
        put("ears/" + head)
    if hat:
        put("hat/" + hat)
        put("hat/%s/front" % hat)
    pal = palette(spec["skin"], spec["hair_color"], spec["iris"], spec["lady"], spec["house"], spec["second"],
                  spec["third"], spec.get("grey", 0.0))
    return compose(layers, pal)


SAMPLES = [
    dict(culture="vardish", lady=False, cut="mantle", head="m_square", hair="swept", beard="full", eye="almond", brow="thick",
         nose="straight", lips="thin", skin="fair", hair_color="auburn", grey=0.45, iris="blue", house="8a2030",
         second="3e5c3e", third="d8ccb0", age=2),
    dict(culture="vardish", lady=False, cut="surcoat", head="m_lean", hair="side", beard="short", eye="hooded", brow="medium",
         nose="aquiline", lips="thin", skin="fair", hair_color="blond", iris="grey", house="2c4a8a", second="d8c49a", third="d8ccb0"),
    dict(culture="vardish", lady=True, cut="gown", head="f_heart", hair="braid_crown", eye="almond", brow="arched",
         nose="small", lips="lady", skin="fair", hair_color="copper", iris="green", house="2a5a3a", second="d8c49a", third="d8ccb0"),
    dict(culture="vardish", lady=True, cut="surcoat", head="f_oval", hair="side_braid", eye="round", brow="thin",
         nose="small", lips="lady", skin="warm", hair_color="brown", iris="hazel", house="5a2a6a", second="3e5c3e",
         third="d8ccb0", hat="crown_f"),
    dict(culture="kharzani", lady=False, cut="kaftan", head="m_broad", hair="crop", beard="full", eye="almond", brow="thick",
         nose="aquiline", lips="full", skin="olive", hair_color="black", iris="brown", house="2a6a66", second="8a2430",
         third="d8ccb0", hat="turban", ears=False),
    dict(culture="kharzani", lady=False, cut="cloak", head="m_lean", hair="curls", beard="goatee", eye="hooded", brow="thick",
         nose="aquiline", lips="full", skin="brown", hair_color="black", iris="dark", house="b0703a", second="2c3466",
         third="e0d4b8"),
    dict(culture="kharzani", lady=True, cut="collar", head="f_oval", hair="long", eye="almond", brow="thin",
         nose="small", lips="lady", skin="olive", hair_color="dark_brown", iris="brown", house="2a7a76", second="8a2430",
         third="d8ccb0", hat="circlet", ears=False),
    dict(culture="kharzani", lady=True, cut="coat", head="f_round", hair="sleek", eye="round", brow="arched",
         nose="small", lips="lady", skin="deep", hair_color="black", iris="dark", house="7a2440", second="2c3466",
         third="e8dcc0", hat="veil", ears=False),
    dict(culture="ryumon", lady=False, cut="kamishimo", head="m_soft", hair="topknot", beard="thin", eye="narrow", brow="medium",
         nose="straight", lips="thin", skin="warm", hair_color="black", iris="dark", house="4a6a66", second="263050",
         third="d8ccb0", age=1),
    dict(culture="ryumon", lady=False, cut="armour", head="m_square", hair="shaved", beard="moustache", eye="narrow",
         brow="thick", nose="broad", lips="thin", skin="warm", hair_color="black", iris="dark", house="8a2a2a",
         second="24222a", third="d8ccb0"),
    dict(culture="ryumon", lady=True, cut="uchikake", head="f_oval", hair="shimada", eye="almond", brow="thin",
         nose="small", lips="lady", skin="warm", hair_color="black", iris="dark", house="8a2a3a", second="263050",
         third="c8a050", hat="kanzashi", ears=False),
    dict(culture="ryumon", lady=True, cut="kosode", head="f_heart", hair="straight", eye="round", brow="thin",
         nose="small", lips="lady", skin="fair", hair_color="black", iris="dark", house="3a5a8a", second="4a2a44",
         third="d8ccb0", ears=False),
]


def sheet(specs, path, scale=3, cols=6):
    data, atlas = load()
    ims = [lord(data, atlas, s) for s in specs]
    w, h = 120 * scale, 160 * scale
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (w + 8) + 8, rows * (h + 8) + 8), (34, 30, 38, 255))
    for i, im in enumerate(ims):
        r, c = divmod(i, cols)
        out.alpha_composite(im.resize((w, h), Image.NEAREST), (8 + c * (w + 8), 8 + r * (h + 8)))
    out.save(path)


if __name__ == "__main__":
    sheet(SAMPLES, sys.argv[1] if len(sys.argv) > 1 else "preview.png")
