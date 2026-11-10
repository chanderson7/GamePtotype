#!/usr/bin/env python3
"""Builds assets/fonts/BannerfallText.ttf, the face for everything that isn't a title or a
letter, from Alegreya Sans Medium (SIL Open Font License; no Reserved Font Name).

Alegreya Sans sits with Cinzel and IM FELL English where Godot's default face did not, but
set at the same pixel size it reads about 15% smaller (x-height 0.46 em against Open Sans
SemiBold's 0.54). So the face is drawn larger on its em rather than every size in the game
being changed: the em shrinks from 1000 to 893 units, every glyph and metric is 1.12 times
the size, and at a given font size it has Open Sans's x-height and line height while still
taking about a tenth less width. The default digits are mapped to the tabular lining ones
(".tf"): numbers stand on the line, and a count that ticks up doesn't wobble.

Hinting is dropped (the scaled em would no longer match it; Godot hints lightly itself) and
the family is renamed, as the licence asks of a modified version. Reproduce with:

    curl -LO https://raw.githubusercontent.com/google/fonts/main/ofl/alegreyasans/AlegreyaSans-Medium.ttf
    python3 tools/body_font.py AlegreyaSans-Medium.ttf

Needs fontTools (pip install fonttools).
"""
import os
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "fonts", "BannerfallText.ttf")
SCALE = 1.12
FAMILY = "Bannerfall Text"


def build(src: str) -> None:
    f = TTFont(src)
    f.recalcTimestamp = False
    head = f["head"]
    head.unitsPerEm = round(head.unitsPerEm / SCALE)
    # Hinting was written for the old em.
    for tag in ("fpgm", "prep", "cvt ", "DSIG", "hdmx", "LTSH", "VDMX"):
        if tag in f:
            del f[tag]
    glyf = f["glyf"]
    for name in f.getGlyphOrder():
        g = glyf[name]
        if hasattr(g, "program"):
            g.program.fromBytecode(b"")
    if "maxp" in f:
        maxp = f["maxp"]
        for attr in ("maxFunctionDefs", "maxInstructionDefs", "maxStackElements", "maxSizeOfInstructions", "maxTwilightPoints", "maxStorage"):
            if hasattr(maxp, attr):
                setattr(maxp, attr, 0)
    # Tabular lining digits by default.
    order = set(f.getGlyphOrder())
    for table in f["cmap"].tables:
        for cp in range(ord("0"), ord("9") + 1):
            if cp in table.cmap and table.cmap[cp] + ".tf" in order:
                table.cmap[cp] = table.cmap[cp] + ".tf"
    # A modified version goes by its own name.
    name = f["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 16):
            rec.string = FAMILY
        elif rec.nameID == 4:
            rec.string = FAMILY + " Medium"
        elif rec.nameID == 6:
            rec.string = "BannerfallText-Medium"
        elif rec.nameID == 3:
            rec.string = "1.0;BannerfallText-Medium (from Alegreya Sans 2.004)"
    f.save(OUT)
    print("wrote", os.path.relpath(OUT, os.path.join(HERE, "..")), "upem", head.unitsPerEm)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    build(sys.argv[1])
