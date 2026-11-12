"""Colours for the kit. Each material has six shades: four from light to dark, a darkest, and
the outline. Fixed materials (gold, ermine...) are the same for everyone; the rest are picked
in the game from the lord's record (skin, hair, eyes, house colours). lord_portrait.gd reads
all of this from kit.json, and makes house colours with the same rule as house_ramp below."""
import colorsys


def hx(*hexes):
    return [h.lstrip("#") for h in hexes]


FIXED = {
    "eye": hx("fffbf3", "f1e8de", "cbbdb4", "a8968e", "7a6862", "3a2a2c"),
    "ink": hx("2a1a1e", "1a1214", "4a3438", "5e4448", "120c0e", "0a0608"),
    "linen": hx("f6f1e6", "ddd4c4", "b6aa97", "857963", "564b3e", "3a3128"),
    "gold": hx("fff1a6", "f1c858", "c8932c", "8a5e1b", "553711", "3a240b"),
    "ermine": hx("fbf7ef", "e8dfd2", "c9bdae", "958a7d", "1d1719", "4a4044"),
    "garnet": hx("ff8f8f", "d0303f", "8a1428", "4e0a1a", "2a0510", "1c040a"),
    "steel": hx("e6ecf0", "b4bdc6", "8a939e", "5d6570", "3a3f48", "23262c"),
    "white": hx("fbf8f0", "eee8da", "d6cebd", "a99f8c", "7a705f", "4a4238"),
    "black": hx("5a5866", "3a3844", "26242e", "18161e", "0e0c12", "07060a"),
    "pearl": hx("ffffff", "f2eee6", "d8d0c6", "aea49a", "7c7268", "4c443e"),
    "jade": hx("a8f0d8", "5cc8a8", "2e9a7e", "1c6a56", "0e3e32", "08261e"),
    "leather": hx("b07a4e", "8a5a36", "6a4226", "4a2c18", "2e1a0e", "1e1008"),
}

# skin: shades, plus lips for men and for women, chosen per land (see lord_portrait.gd)
SKINS = {
    "fair":  {"skin": hx("f7dcc4", "eebf9e", "d99c7e", "b8735e", "8a4b45", "4d2630"),
              "lip_m": hx("e2ad98", "c98c78", "a66a5c", "7e4a44", "5e3434", "4d2630"),
              "lip_f": hx("eba29a", "d0716c", "a84c50", "7e343c", "62262e", "4d2630")},
    "warm":  {"skin": hx("f4d2ae", "e5b089", "c98d68", "a5684f", "774440", "45242a"),
              "lip_m": hx("d9a080", "c08568", "9c6450", "764440", "52302e", "45242a"),
              "lip_f": hx("e69a88", "c9685e", "a04844", "763238", "56242a", "45242a")},
    "olive": {"skin": hx("e9c19a", "d29e74", "b57d57", "8e5a41", "623b33", "3a1f22"),
              "lip_m": hx("c98e70", "ad7258", "8c5444", "663a34", "4a2a28", "3a1f22"),
              "lip_f": hx("e3938c", "c2655f", "984246", "6c2c34", "4e1e26", "3a1f22")},
    "brown": {"skin": hx("d7a27a", "b9805a", "986343", "744832", "4f2f28", "2e1a1c"),
              "lip_m": hx("b0785c", "946048", "764838", "56322a", "3c2220", "2e1a1c"),
              "lip_f": hx("c97a6c", "a85a50", "86403c", "62282c", "461c20", "2e1a1c")},
    "deep":  {"skin": hx("b07b5a", "925f42", "754830", "583424", "3c231c", "241414"),
              "lip_m": hx("946452", "7a4e3e", "603a30", "462822", "321c1a", "241414"),
              "lip_f": hx("a8605a", "8c4842", "6e3432", "502226", "38181c", "241414")},
}

HAIRS = {
    "black":      hx("6a6470", "403a44", "28232c", "18151c", "0d0b10", "0a080c"),
    "dark_brown": hx("8a6250", "62402f", "432a1f", "2b1a14", "180e0c", "120a08"),
    "brown":      hx("b48a62", "8a6242", "64432c", "42291c", "24160f", "1a0f0a"),
    "chestnut":   hx("c8875a", "9e5f38", "743f24", "4e2816", "2c160c", "200f08"),
    "auburn":     hx("d68a5a", "ae5e36", "82401f", "5a2814", "34160c", "260f08"),
    "copper":     hx("f0a066", "d07440", "a44e26", "723018", "44190c", "301008"),
    "blond":      hx("f4dc9c", "d8b86e", "b0904c", "7e6432", "4c3a1c", "382a14"),
    "ash":        hx("e0d2b4", "bca88a", "94806a", "6a5a4c", "40362e", "2e2620"),
    "salt":       hx("cdb8a6", "a8897a", "7d5f50", "573f35", "33231f", "241815"),
    "grey":       hx("e2e0dc", "bdb9b4", "94908c", "6a6664", "42403e", "2e2c2a"),
    "white":      hx("fbfaf6", "e6e3dc", "c4c0b8", "96928c", "62605c", "42403e"),
}

IRISES = {
    "blue":  hx("8fb4cc", "6b8ea6", "4e6e86", "3e5a70", "28394a", "1a1214"),
    "grey":  hx("b0bec4", "8a9aa0", "6a7a80", "56646a", "3a4448", "1a1214"),
    "green": hx("98b07a", "6f8a5a", "56703f", "43573a", "2c3a24", "1a1214"),
    "hazel": hx("c09a5a", "8a6a3a", "6e5228", "56401f", "382810", "1a1214"),
    "brown": hx("c08850", "9a6430", "7a4c22", "5e381a", "3c220e", "1a1214"),
    "dark":  hx("7a5a3a", "5a3a22", "462c18", "33200f", "201408", "1a1214"),
}

# a second and third cloth for each land (the house colour is the first)
SECONDS = {
    "vardish": {"green": "3e5c3e", "navy": "2c3a5a", "russet": "6a3a24", "slate": "4a5058", "black": "2a262c"},
    "kharzani": {"ivory": "d8ccb0", "sand": "b89a6a", "indigo": "2c3466", "crimson": "8a2430", "teal": "2a6a66"},
    "ryumon": {"black": "24222a", "navy": "263050", "moss": "3e4a32", "plum": "4a2a44", "rust": "7a3a22"},
}


def _hue_toward(h, target, amount):
    d = (target - h + 0.5) % 1.0 - 0.5
    step = max(-amount, min(amount, d))
    return (h + step) % 1.0


# shade: (value scale, saturation scale, hue pull toward warm (+) or cool (-))
HOUSE_STEPS = [(1.34, 0.78, 0.030), (1.14, 0.90, 0.014), (0.94, 1.00, 0.0), (0.72, 1.06, -0.016),
               (0.50, 1.10, -0.030), (0.32, 1.10, -0.040)]
WARM, COOL = 0.09, 0.68


def house_ramp(hexcol):
    """Six shades from one colour: lights warmer and paler, darks cooler and richer."""
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    # dyed cloth, not paint: never too bright or too pure
    ss = min(max(ss, 0.18), 0.52)
    vv = min(max(vv, 0.30), 0.68)
    out = []
    for vm, sm, pull in HOUSE_STEPS:
        nh = _hue_toward(hh, WARM if pull > 0 else COOL, abs(pull)) if pull else hh
        nr, ng, nb = colorsys.hsv_to_rgb(nh, min(1.0, ss * sm), min(1.0, vv * vm))
        out.append("%02x%02x%02x" % (round(nr * 255), round(ng * 255), round(nb * 255)))
    return out
