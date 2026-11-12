"""Builds the lord portrait kit: every part drawn, packed into one atlas, and kit.json saying
where each part is and what colours there are. The game puts lords together from it
(scripts/art/lord_portrait.gd).

    python3 tools/pixel_kit/build.py            # writes assets/portraits/kit/
"""
import json
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import canvas as C
import face as F
import hair as Hh
import garb as G
import palettes as P
import soldiers as Sd

OUT = os.path.join(HERE, "..", "..", "assets", "portraits", "kit")

MALE_HEADS = ["m_square", "m_soft", "m_lean", "m_broad"]
FEMALE_HEADS = ["f_oval", "f_heart", "f_round"]
MALE_HAIR = ["swept", "crop", "side", "receding", "curls", "long", "topknot", "shaved"]
FEMALE_HAIR = ["long", "straight", "braid_crown", "side_braid", "bun", "shimada", "sleek"]
BEARDS = ["stubble", "short", "full", "long", "goatee", "moustache", "thin"]


def rng(k):
    return np.random.default_rng(k)


def sprites():
    out = {}

    def add(name, cv):
        if cv is not None and name.startswith("hair/") and name.endswith("/front"):
            Hh.under_shadow(cv)
        if cv is not None:
            cv.inner_lines()
            s = cv.sprite()
            if s is not None:
                out[name] = s

    for h in MALE_HEADS + FEMALE_HEADS:
        add("head/" + h, F.head(h))
        add("ears/" + h, F.ears(h.startswith("f_"), h))
    add("neck/m", F.neck(False)); add("neck/f", F.neck(True))
    for lady, g in ((False, "m"), (True, "f")):
        for lvl in (1, 2):
            add("age/%s%d" % (g, lvl), F.age(lady, lvl))
    for side in ("far", "near"):
        for shape in F.EYE_SHAPES:
            for state in F.EYE_STATES:
                for g in ("m", "f"):
                    add("eye/%s/%s/%s/%s" % (side, shape, state, g), F.eye(side, shape, state, g == "f"))
        for style in F.BROW_STYLES:
            for mood in F.BROW_MOODS:
                add("brow/%s/%s/%s" % (side, style, mood), F.brow(side, style, mood))
    for n in F.NOSES:
        add("nose/" + n, F.nose(n))
    for style in ("thin", "full", "lady"):
        for mood in F.MOUTH_MOODS:
            add("mouth/%s/%s" % (style, mood), F.mouth(style, mood))
    # hair
    single = {"swept": Hh.swept, "crop": Hh.crop, "side": Hh.side_part, "receding": Hh.receding, "curls": Hh.curls,
              "topknot": Hh.topknot, "shaved": lambda r: Hh.topknot(r, shaved=True)}
    for i, st in enumerate(MALE_HAIR):
        if st == "long":
            b, f = Hh.long_male(rng(100 + i))
            add("hair/m_long/back", b); add("hair/m_long/front", f)
        else:
            add("hair/m_%s/front" % st, single[st](rng(100 + i)))
    for i, st in enumerate(FEMALE_HAIR):
        r = rng(200 + i)
        if st == "long":
            b, f = Hh.long_lady(r)
        elif st == "straight":
            b, f = Hh.long_lady(r, waves=False)
        elif st == "bun":
            b, f = Hh.bun(r)
        elif st == "shimada":
            b, f = Hh.shimada(r)
        else:
            b, f = None, {"braid_crown": Hh.braid_crown, "side_braid": Hh.side_braid, "sleek": Hh.sleek}[st](r)
        add("hair/f_%s/back" % st, b); add("hair/f_%s/front" % st, f)
    for i, b in enumerate(BEARDS):
        for h in MALE_HEADS:
            add("beard/%s/%s" % (b, h), Hh.beard(b, h, rng(300 + i)))
    # clothes and headwear
    for (cult, g), cuts in G.OUTFITS.items():
        for cut, fn in cuts.items():
            back, front = fn(rng(400))
            add("garb/%s_%s_%s/back" % (cult, g, cut), back)
            add("garb/%s_%s_%s/front" % (cult, g, cut), front)
    add("hat/crown_m", G.crown(False)); add("hat/crown_f", G.crown(True))
    add("hat/turban", G.turban(rng(500))); add("hat/turban_jewel", G.turban(rng(500), jewel=True))
    vb, vf = G.veil(rng(501))
    add("hat/veil/back", vb); add("hat/veil/front", vf)
    add("hat/circlet", G.circlet()); add("hat/tiara", G.tiara()); add("hat/eboshi", G.eboshi())
    add("hat/kanzashi", G.kanzashi()); add("hat/kanzashi_rich", G.kanzashi(True))
    # captains: four outfits a land for each sex, what their troop carries, rank, role, history
    for cult, fns in Sd.OUTFITS.items():
        for i, fn in enumerate(fns):
            for g in ("m", "f"):
                add("capt/%s_%s_%d" % (cult, g, i), fn(g, rng(600 + i))[1])
    for kind in ("infantry", "spearmen", "archers", "cavalry"):
        for g in ("m", "f"):
            b, f = Sd.troop(kind, g)
            add("troop/%s/%s/back" % (kind, g), b); add("troop/%s/%s/front" % (kind, g), f)
    for lvl in (2, 3):
        for g in ("m", "f"):
            add("rank/%d/%s" % (lvl, g), Sd.rank(lvl, g))
    for spec in ("Scout", "Quartermaster", "Drillmaster", "Champion"):
        add("token/" + spec, Sd.token(spec))
    for i in range(len(Sd.SCARS)):
        add("scar/%d" % i, Sd.scar(i))
    add("mark/bandage", Sd.bandage())
    add("mark/blush", F.blush_mark(False))
    return out


def pack(sprs, width=1024):
    """Shelf-pack the parts; returns the atlas and name -> [ax, ay, w, h, ox, oy]."""
    names = sorted(sprs, key=lambda n: (-sprs[n][2].shape[0], n))
    x = y = shelf = 0
    rects = {}
    for n in names:
        ox, oy, a = sprs[n]
        h, w = a.shape[:2]
        if x + w > width:
            x, y, shelf = 0, y + shelf + 1, 0
        rects[n] = [x, y, w, h, ox, oy]
        x += w + 1
        shelf = max(shelf, h)
    atlas = np.zeros((y + shelf + 1, width, 4), np.uint8)
    for n, (ax, ay, w, h, ox, oy) in rects.items():
        atlas[ay:ay + h, ax:ax + w] = sprs[n][2]
    return atlas, rects


def main():
    sprs = sprites()
    atlas, rects = pack(sprs)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(atlas, "RGBA").save(os.path.join(OUT, "kit.png"), optimize=True)
    data = {
        "w": C.W, "h": C.H, "materials": C.MATERIALS, "line": C.LINE, "no_line": C.NO_LINE,
        "sprites": {k: rects[k] for k in sorted(rects)},
        "fixed": P.FIXED, "skins": P.SKINS, "hairs": P.HAIRS, "irises": P.IRISES, "seconds": P.SECONDS,
        "house_steps": P.HOUSE_STEPS, "warm": P.WARM, "cool": P.COOL,
        "heads": {"m": MALE_HEADS, "f": FEMALE_HEADS}, "beards": BEARDS,
        "eye_shapes": list(F.EYE_SHAPES), "brow_styles": list(F.BROW_STYLES), "noses": list(F.NOSES),
        "scars": len(Sd.SCARS),
    }
    with open(os.path.join(OUT, "kit.json"), "w") as f:
        json.dump(data, f, separators=(",", ":"), sort_keys=True)
    print("%d parts, atlas %dx%d" % (len(rects), atlas.shape[1], atlas.shape[0]))


if __name__ == "__main__":
    main()
