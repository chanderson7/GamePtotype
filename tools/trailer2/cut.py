#!/usr/bin/env python3
"""Cuts the "Captains" trailer: 1920x1080, 30 fps, 70 s, H.264 + AAC, for YouTube.

    python3 tools/trailer2/cut.py           # -> $TRAILER_OUT/bannerfall_captains.mp4, .srt, _thumbnail.jpg

The story, on the bars of score.py (a bar is two seconds):

    0:00  a charge in slow motion        "Every company has a captain."
    0:06  the blow, at full speed
    0:08  the warband, a captain's page  "Every captain has a name."
    0:12  two captains at the fire       "They remember every fight."
    0:16  one of them falls              "And any of them can fall."
    0:20  the die lands
    0:22  black                          "Lead them anyway."
    0:24  the name
    0:26  the battles, a bar a shot      real-time battles, sized for your hand; charge, loose, hold; the walls
    0:42  the world                      three realms, the lords, a wedding, a company to build
    0:50  the last charge, a beat a shot
    0:58  victory
    1:00  the name, and "Coming to iPhone"

Every picture is the game, recorded by shoot.sh. A field shot fills the frame. A screen of
the game (it is a phone game, held upright) is shown in a phone, large enough to read, with
the trailer's words beside it. Each frame is drawn here and piped to ffmpeg; the shots' own
sound (the game's, recorded with its music off) is laid under the score.

The moments that must meet the music (the blow, the die landing, VICTORY) are found in each
shot's log, which stage.gd writes as it records, so a re-recorded shot still lands.
Needs ffmpeg, and Python with numpy, Pillow and soundfile.
"""
import os
import re
import subprocess
import sys

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.environ.get("TRAILER_OUT", "/tmp/bannerfall-trailer2")
SHOTS = os.path.join(OUT, "shots")
W, H, FPS, LENGTH = 1920, 1080, 30, 70.0
SR = 48000

NIGHT = (9, 12, 22)
BRASS = (222, 174, 72)
BONE = (240, 233, 216)
EMBER = (226, 96, 78)
CINZEL = os.path.join(ROOT, "assets/fonts/Cinzel-Bold.ttf")
FELL = os.path.join(ROOT, "assets/fonts/IMFellEnglish-Italic.ttf")
WORDMARK = os.path.join(ROOT, "assets/branding/wordmark.png")
NAME = "bannerfall_captains"
END_LINE = "Coming to iPhone"


def bar(n, beat=1.0):
    """Seconds at a beat of a bar of the score (both from 1)."""
    return ((n - 1) * 4 + (beat - 1)) * 0.5


def ease(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


# ------------------------------------------------------------------ the recordings

def mark(shot, word):
    """The second of `shot`'s recording at which its log first says `word`."""
    path = os.path.join(OUT, "logs", shot + ".log")
    for row in open(path, errors="replace"):
        m = re.match(r"fight\s+[\d.]+\s+video\s+([\d.]+)\s+(\w+)", row)
        if m and m.group(2) == word:
            return float(m.group(1))
    sys.exit("%s never logged %s: record it again (tools/trailer2/shoot.sh %s)" % (shot, word, shot))


_frames = {}


def still(shot, secs):
    """The frame of a shot at a second of its recording."""
    n = max(0, int(round(secs * FPS)))
    key = (shot, n)
    if key not in _frames:
        if len(_frames) > 6:
            _frames.pop(next(iter(_frames)))
        path = os.path.join(SHOTS, shot, "f%08d.png" % n)
        if not os.path.exists(path):
            sys.exit("Missing %s: record it (tools/trailer2/shoot.sh %s)" % (path, shot))
        _frames[key] = Image.open(path).convert("RGB")
    return _frames[key]


# ------------------------------------------------------------------ words

def font(path, size):
    return ImageFont.truetype(path, size)


def tracked(draw, xy, text, f, fill, gap, edge=0):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill, stroke_width=edge, stroke_fill=(16, 13, 10, 255))
        x += draw.textlength(ch, font=f) + gap


def tracked_width(text, f, gap):
    d = ImageDraw.Draw(Image.new("L", (4, 4)))
    return sum(d.textlength(ch, font=f) for ch in text) + gap * max(0, len(text) - 1)


_words = {}


def words(rows, align="left", shade=14):
    """Lines of type as one RGBA picture over a soft dark shadow.

    rows: (text, face, size, colour, letter gap). Returns (image, (width, height)).
    """
    key = (tuple(rows), align, shade)
    if key in _words:
        return _words[key]
    fonts = [font(face, size) for _, face, size, _, _ in rows]
    widths = [tracked_width(t, f, gap) for (t, _, _, _, gap), f in zip(rows, fonts)]
    heights = [int(size * 1.22) for _, _, size, _, _ in rows]
    pad = 60
    w, h = int(max(widths)) + pad * 2, sum(heights) + pad * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = pad
    for (text, _, size, colour, gap), f, tw, th in zip(rows, fonts, widths, heights):
        x = pad if align == "left" else (w - tw) / 2
        # The big words stand over a busy field: a dark edge keeps their letters whole.
        tracked(d, (x, y), text, f, colour + (255,), gap, edge=size // 40 if size >= 100 else 0)
        y += th
    alpha = img.getchannel("A")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for radius, weight in ((shade, 1.6), (3, 2.2)):
        soft = Image.new("RGBA", (w, h), (2, 3, 8, 0))
        soft.putalpha(alpha.filter(ImageFilter.GaussianBlur(radius)).point(lambda v, k=weight: min(255, int(v * k))))
        out = Image.alpha_composite(out, soft)
    out = Image.alpha_composite(out, img)
    _words[key] = out
    return out


def put(canvas, layer, centre, opacity=1.0, scale=1.0):
    """`layer` (RGBA) onto `canvas`, its middle at `centre`."""
    if opacity <= 0.003:
        return
    if abs(scale - 1.0) > 0.002:
        layer = layer.resize((max(2, int(layer.width * scale)), max(2, int(layer.height * scale))), Image.BILINEAR)
    if opacity < 0.997:
        layer = layer.copy()
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * opacity)))
    canvas.paste(layer, (int(centre[0] - layer.width / 2), int(centre[1] - layer.height / 2)), layer)


def said(canvas, t, t0, t1, rows, where, align="left", slam=False, hold_out=0.25):
    """Type on screen from t0 to t1. A line rises in; a slammed word lands from large."""
    if not t0 <= t < t1:
        return
    layer = words(tuple(rows), align)
    u = t - t0
    out = ease((t1 - t) / hold_out) if hold_out > 0 else 1.0
    if slam:
        land = ease(u / 0.12)
        scale = 1.0 + 0.55 * (1.0 - land) + 0.03 * (u / max(0.01, t1 - t0))
        put(canvas, layer, where, opacity=min(1.0, 0.25 + land) * out, scale=scale)
        return
    rise = ease(u / 0.35)
    x, y = where
    if align == "left":
        x += layer.width / 2 - 60
    put(canvas, layer, (x, y + 26 * (1.0 - rise)), opacity=rise * out)


def line(text, size=74, colour=BONE, gap=3):
    return (text.upper(), CINZEL, size, colour, gap)


def aside(text, size=44):
    return (text, FELL, size, (198, 201, 214), 0)


# ------------------------------------------------------------------ pictures

_vignette = None


def graded(img, lift=1.0):
    """A field shot's grade: a touch more contrast, and the corners drawn in."""
    global _vignette
    if _vignette is None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
        _vignette = (1.0 - 0.34 * np.clip(r - 0.45, 0, 1) ** 1.6)[..., None]
    px = np.asarray(img, dtype=np.float32) / 255.0
    px = (px - 0.5) * 1.1 + 0.5
    px = px * _vignette * lift
    return Image.fromarray((np.clip(px, 0, 1) * 255).astype(np.uint8))


def wide(shot, secs, u=0.0, push=(1.0, 1.06), shake=0.0, t=0.0):
    """A field shot filling the frame, pushing slowly in; `shake` jolts it."""
    img = still(shot, secs)
    z = push[0] + (push[1] - push[0]) * u
    cw, ch = W / z, H / z
    ox = (W - cw) / 2 + shake * 26 * np.sin(t * 71.0)
    oy = (H - ch) / 2 + shake * 20 * np.cos(t * 93.0)
    ox = min(max(ox, 0), W - cw)
    oy = min(max(oy, 0), H - ch)
    img = img.resize((W, H), Image.BILINEAR, box=(ox, oy, ox + cw, oy + ch))
    return graded(img)


_phone_parts = {}


def _phone(sw, sh):
    """A phone's body, its shadow, and the screen's rounded mask, for a screen sw x sh."""
    key = (sw, sh)
    if key not in _phone_parts:
        rim = max(10, int(sw * 0.024))
        radius = int(sw * 0.105)
        bw, bh = sw + rim * 2, sh + rim * 2
        body = Image.new("RGBA", (bw + 16, bh), (0, 0, 0, 0))
        d = ImageDraw.Draw(body)
        # Side buttons, then the body with a pale edge that catches the light at the top left.
        d.rounded_rectangle([bw + 2, int(bh * 0.2), bw + 9, int(bh * 0.2) + int(sh * 0.085)], 4, fill=(38, 41, 52, 255))
        d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius + rim, fill=(12, 13, 18, 255), outline=(92, 96, 112, 255), width=2)
        d.rounded_rectangle([3, 3, bw - 4, bh - 4], radius + rim - 3, outline=(30, 32, 42, 255), width=3)
        mask = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius, fill=255)
        pad = 110
        shadow = Image.new("L", (bw + pad * 2, bh + pad * 2), 0)
        ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + 26, pad + bw, pad + bh + 26], radius + rim, fill=215)
        shadow = shadow.filter(ImageFilter.GaussianBlur(44))
        dark = Image.new("RGBA", shadow.size, (0, 0, 4, 0))
        dark.putalpha(shadow)
        _phone_parts[key] = (body, mask, dark, rim, pad)
    return _phone_parts[key]


def backdrop(img, focus_y, dim=0.34):
    """Behind a phone: what is on its screen, out of focus and dark, tinted to the night."""
    w, h = img.size
    ch = w * 9 / 16
    top = min(max(focus_y - ch / 2, 0), h - ch)
    small = img.resize((192, 108), Image.BILINEAR, box=(0, top, w, top + ch)).filter(ImageFilter.GaussianBlur(7))
    px = np.asarray(small.resize((W, H), Image.BILINEAR), dtype=np.float32) * dim
    px = px * np.array([0.82, 0.9, 1.12], dtype=np.float32) + np.array(NIGHT, dtype=np.float32) * 0.9
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))


def phone(shot, secs, zoom=0.5, focus_y=960, cx=1430, lean=0.0, behind=None):
    """A screen of the game in a phone. `zoom`: screen pixels per recorded pixel; `focus_y`:
    the recorded row held at the frame's middle (so a large phone may run off the frame)."""
    img = still(shot, secs)
    sw, sh = int(img.width * zoom), int(img.height * zoom)
    body, mask, shadow, rim, pad = _phone(sw, sh)
    canvas = backdrop(img, focus_y) if behind is None else behind
    x = int(cx - sw / 2 + lean)
    y = int(H / 2 - focus_y * zoom)
    canvas.paste(shadow, (x - rim - pad, y - rim - pad), shadow)
    canvas.paste(body, (x - rim, y - rim), body)
    canvas.paste(img.resize((sw, sh), Image.LANCZOS), (x, y), mask)
    return canvas


_night = None


def night():
    """The black the cards stand on: not quite black, lighter at its middle, with a grain."""
    global _night
    if _night is None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.75)) ** 2)
        glow = np.clip(1.0 - r, 0, 1)[..., None] ** 1.8
        px = np.array(NIGHT, dtype=np.float32) + glow * np.array([20, 24, 40], dtype=np.float32)
        px += np.random.default_rng(3).normal(0.0, 1.2, px.shape)
        _night = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    return _night.copy()


_mark = {}


def wordmark(width):
    if width not in _mark:
        m = Image.open(WORDMARK).convert("RGBA")
        m = m.resize((width, round(m.height * width / m.width)), Image.LANCZOS)
        soft = Image.new("RGBA", m.size, (0, 0, 0, 0))
        soft.putalpha(m.getchannel("A").filter(ImageFilter.GaussianBlur(10)).point(lambda v: min(255, v * 2)))
        _mark[width] = Image.alpha_composite(soft, m)
    return _mark[width]


# ------------------------------------------------------------------ the cut

CHARGE_HIT = mark("charge", "IMPACT") - 2.5   # where the two lines are seen to meet
CHARGE_FULL = mark("charge", "IMPACT")        # where the recording is back at full speed
DIE_LANDS = mark("fall", "CAPTAIN") + 1.53    # the roll takes a second and a half
STAMP = mark("won", "OVER") + 0.13            # VICTORY stamps as the last company breaks

TEXT_X = 120
SLAM_AT = (W / 2, H / 2 + 10)

# The battles, a bar each (bars 14-21): shot, where its two seconds start, and its word.
BATTLES = [
    ("clash", mark("clash", "CLASH") - 0.9, None),
    ("hand", mark("hand", "CLASH") - 0.4, None),
    ("wood", mark("wood", "CLASH") - 0.7, "Charge."),
    ("bows", 5.0, "Loose."),
    ("night", mark("night", "CLASH") - 1.2, "Hold."),
    ("ford", mark("ford", "CLASH") - 1.3, None),
    ("gate", 11.0, None),
    ("wall", 12.0, None),
]
# The last charge, a beat each (bars 26-29): shot and where its second starts.
LAST = [("dusk", mark("dusk", "CLASH") - 0.3), ("bows", 6.6), ("gate", 14.6), ("night", mark("night", "CLASH") + 0.7),
        ("charge", CHARGE_FULL + 0.4), ("wall", 15.0), ("ford", mark("ford", "CLASH") + 0.7), ("won", STAMP - 1.0)]
LAST_PUSH = {"won": (1.5, 1.6)}  # the last shot is already close on where VICTORY will stamp


def picture(t):
    """The trailer's frame at second t."""
    # ---- bars 1-3: the charge, slowly
    if t < bar(4):
        img = wide("charge", CHARGE_HIT - (bar(4) - t), u=t / 6.0, push=(1.0, 1.1))
        said(img, t, 2.0, 5.7, [("EVERY COMPANY HAS A CAPTAIN.", CINZEL, 62, BONE, 9)], (W / 2, 880), align="centre", hold_out=0.5)
        return img
    # ---- bar 4: the blow: the last slow frames run at four times their speed, then full speed
    if t < bar(5):
        u = t - bar(4)
        ramp = (CHARGE_FULL - CHARGE_HIT) / 4.0
        src = CHARGE_HIT + u * 4.0 if u < ramp else CHARGE_FULL + (u - ramp)
        return wide("charge", src, u=1.0, push=(1.1, 1.1), shake=max(0.0, 1.0 - u / 0.5), t=t)
    # ---- bars 5-6: the warband, then one captain's page
    if t < bar(7):
        u = t - bar(5)
        if u < 2.0:
            img = phone("roster", 1.0 + u, zoom=0.74, focus_y=640 + 40 * ease(u / 2.0))
        else:
            img = phone("captain", 1.0 + (u - 2.0), zoom=0.84, focus_y=440 + 60 * ease((u - 2.0) / 2.0))
        said(img, t, bar(5) + 0.1, bar(7), [line("Every captain"), line("has a name.", colour=BRASS)], (TEXT_X, 500))
        return img
    # ---- bars 7-8: the fire
    if t < bar(9):
        u = t - bar(7)
        img = phone("fire", 6.9 + u, zoom=0.78, focus_y=700 + 90 * ease(u / 4.0))
        said(img, t, bar(7) + 0.1, bar(9), [line("They remember"), line("every fight.", colour=BRASS)], (TEXT_X, 500))
        return img
    # ---- bars 9-11: a captain falls; the die lands on bar 11
    if t < bar(12):
        src = DIE_LANDS + (t - bar(11))
        u = (t - bar(9)) / 6.0
        img = phone("fall", src, zoom=0.7 + 0.14 * ease((t - bar(9) - 1.6) / 3.0), focus_y=700 - 60 * ease(u * 1.5))
        said(img, t, bar(9) + 0.2, bar(11) - 0.15, [line("And any of them"), line("can fall.", colour=EMBER)], (TEXT_X, 500))
        return img
    # ---- bar 12: black
    if t < bar(13):
        u = t - bar(12)
        img = night()
        layer = words((("LEAD THEM ANYWAY.", CINZEL, 104, BONE, 12),), "centre")
        put(img, layer, (W / 2, H / 2), opacity=ease(u / 0.5), scale=0.94 + 0.09 * (u / 2.0))
        return img
    # ---- bar 13: the name
    if t < bar(14):
        u = t - bar(13)
        img = night()
        put(img, wordmark(1500), (W / 2, H / 2), opacity=1.0, scale=1.0 + 0.28 * (1.0 - ease(u / 0.16)) + 0.02 * u)
        return img
    # ---- bars 14-21: the battles
    if t < bar(22):
        k = int((t - bar(14)) / 2.0)
        u = t - (bar(14) + 2.0 * k)
        shot, start, word = BATTLES[k]
        if shot == "hand":
            img = phone(shot, start + u, zoom=0.54, focus_y=960, cx=1330)
            said(img, t, bar(15) + 0.1, bar(16), [line("Sized for", 104), line("your hand.", 104, BRASS)], (TEXT_X + 60, 500))
            return img
        img = wide(shot, start + u, u=u / 2.0, shake=max(0.0, 0.6 - u / 0.3) if k in (0, 4) else 0.0, t=t)
        if k == 0:
            said(img, t, bar(14) + 0.15, bar(15), [("REAL-TIME BATTLES", CINZEL, 118, BONE, 10)], SLAM_AT, align="centre", slam=True)
        if word:
            said(img, t, bar(14) + 2.0 * k + 0.02, bar(14) + 2.0 * k + 1.5, [(word.upper(), CINZEL, 190, BRASS, 14)], SLAM_AT,
                 align="centre", slam=True)
        if shot == "gate":
            said(img, t, bar(20) + 0.1, bar(22), [("TAKE THEIR WALLS.", CINZEL, 118, BONE, 10)], (W / 2, 880), align="centre", slam=True)
        return img
    # ---- bars 22-25: the world
    if t < bar(23):
        u = t - bar(22)
        img = wide("sea", 5.3 + u, u=u / 2.0, push=(1.0, 1.04))
        said(img, t, bar(22) + 0.1, bar(23), [line("Three realms.", 110), line("One sea.", 110, BRASS)], (W / 2, H / 2 + 10), align="centre")
        return img
    if t < bar(24):
        u = t - bar(23)
        shot = "emir" if u < 1.0 else "daimyo"
        img = phone(shot, 1.2 + (u % 1.0), zoom=0.84, focus_y=530)
        said(img, t, bar(23) + 0.05, bar(24), [line("Win the lords'"), line("regard.", colour=BRASS)], (TEXT_X, 500))
        return img
    if t < bar(25):
        u = t - bar(24)
        img = phone("vows", 4.6 + u, zoom=0.8, focus_y=560 + 50 * ease(u / 2.0))
        said(img, t, bar(24) + 0.05, bar(25), [line("Marry into"), line("a great house.", colour=BRASS)], (TEXT_X, 500))
        return img
    if t < bar(26):
        u = t - bar(25)
        img = phone("town", 1.5 + u, zoom=0.8, focus_y=600 + 50 * ease(u / 2.0))
        said(img, t, bar(25) + 0.05, bar(26), [line("Build a company", 68), line("worth following.", 68, BRASS)], (TEXT_X, 500))
        return img
    # ---- bars 26-29: the last charge, a beat a shot
    if t < bar(30):
        k = int(t - bar(26))
        u = t - bar(26) - k
        shot, start = LAST[k]
        return wide(shot, start + u, u=u, push=LAST_PUSH.get(shot, (1.04, 1.1)), shake=max(0.0, 0.5 - u / 0.2), t=t)
    # ---- bar 30: victory, then down to the night
    if t < bar(31):
        u = t - bar(30)
        img = wide("won", min(STAMP + u, STAMP + 1.7), u=u / 2.0, push=(1.6, 1.75))
        # The game stamps its own small VICTORY here; the trailer's word stands on a dark band over it.
        band = np.asarray(img, dtype=np.float32)
        rows = np.clip(1.0 - np.abs(np.arange(H, dtype=np.float32) - SLAM_AT[1]) / 190.0, 0, 1)[:, None, None] ** 0.7
        img = Image.fromarray((band * (1.0 - 0.72 * rows * ease(u / 0.1))).astype(np.uint8))
        said(img, t, bar(30) + 0.02, bar(30) + 1.6, [("VICTORY.", CINZEL, 210, BRASS, 16)], SLAM_AT, align="centre", slam=True)
        if u > 1.3:
            img = Image.blend(img, night(), ease((u - 1.3) / 0.7))
        return img
    # ---- bars 31-35: the name
    u = t - bar(31)
    img = night()
    put(img, wordmark(1320), (W / 2, H / 2 - 70), opacity=ease(u / 1.2), scale=1.0 + 0.012 * u)
    rows = ((END_LINE.upper(), CINZEL, 46, BONE, 9),)
    put(img, words(rows, "centre"), (W / 2, H / 2 + 185), opacity=ease((u - 2.0) / 0.9))
    return img


# White for a frame or two on the hits; the first second comes up from black, the last goes down.
FLASHES = [(bar(4), 0.85), (bar(13), 1.0), (bar(14), 0.5), (bar(18), 0.35), (bar(22), 0.4), (bar(26), 0.8), (bar(30), 1.0)]


def finished(t):
    img = picture(t)
    for when, strength in FLASHES:
        if 0.0 <= t - when < 0.2:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 250, 238)), strength * (1.0 - (t - when) / 0.2) ** 2)
    if t < 1.2:
        img = Image.blend(Image.new("RGB", (W, H), (0, 0, 0)), img, ease(t / 1.2))
    if t > LENGTH - 0.9:
        img = Image.blend(img, Image.new("RGB", (W, H), (0, 0, 0)), ease((t - (LENGTH - 0.9)) / 0.8))
    return img


# ------------------------------------------------------------------ sound

# (trailer second, shot, the shot's second, how long, level): the game's own sound under the score.
def field_sound():
    rows = [(0.0, "charge", CHARGE_HIT - 6.0, 6.0, 0.4), (6.0, "charge", CHARGE_FULL - 0.1, 2.0, 0.9),
            (bar(9), "fall", DIE_LANDS - 4.0, 6.0, 0.75)]
    for k, (shot, start, _) in enumerate(BATTLES):
        rows.append((bar(14) + 2.0 * k, shot, start, 2.0, 0.42))
    for k, (shot, start) in enumerate(LAST):
        rows.append((bar(26) + k, shot, start, 1.0, 0.42))
    rows.append((bar(30), "won", STAMP, 2.2, 0.6))
    return rows


def soundtrack(path):
    score, sr = sf.read(os.path.join(OUT, "score.wav"), dtype="float32", always_2d=True)
    if sr != SR:
        sys.exit("score.wav should be %d Hz: run tools/trailer2/score.py" % SR)
    mix = np.zeros((int(LENGTH * SR), 2), dtype=np.float32)
    mix[: len(score)] += score[: len(mix)]
    for when, shot, start, secs, level in field_sound():
        x, sr = sf.read(os.path.join(SHOTS, shot, "f.wav"), dtype="float32", always_2d=True,
                        start=max(0, int(start * SR)), frames=int(secs * SR))
        if sr != SR or len(x) < 2400:
            continue
        x = x[:, :2] * level
        edge = int(0.04 * SR)
        x[:edge] *= np.linspace(0, 1, edge, dtype=np.float32)[:, None]
        x[-edge:] *= np.linspace(1, 0, edge, dtype=np.float32)[:, None]
        i = int(when * SR)
        n = min(len(x), len(mix) - i)
        mix[i:i + n] += x[:n]
    sf.write(path, mix, SR, subtype="PCM_24")


def loudness(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                       capture_output=True, text=True)
    return float([row for row in r.stderr.splitlines() if row.strip().startswith("I:")][-1].split()[1])


# ------------------------------------------------------------------ what is written

CAPTIONS = [
    (2.0, 5.7, "Every company has a captain."), (8.0, 12.0, "Every captain has a name."),
    (12.0, 16.0, "They remember every fight."), (16.2, 21.8, "And any of them can fall."),
    (22.0, 24.0, "Lead them anyway."), (24.0, 26.0, "Bannerfall"), (26.1, 28.0, "Real-time battles"),
    (28.1, 30.0, "Sized for your hand."), (30.0, 31.5, "Charge."), (32.0, 33.5, "Loose."), (34.0, 35.5, "Hold."),
    (38.1, 42.0, "Take their walls."), (42.1, 44.0, "Three realms. One sea."), (44.0, 46.0, "Win the lords' regard."),
    (46.0, 48.0, "Marry into a great house."), (48.0, 50.0, "Build a company worth following."),
    (58.0, 59.6, "Victory."), (60.5, 70.0, "Bannerfall\n" + END_LINE),
]


def write_captions(path):
    def stamp(s):
        ms = round(s * 1000)
        return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
    with open(path, "w") as f:
        for n, (a, b, text) in enumerate(CAPTIONS, start=1):
            f.write("%d\n%s --> %s\n%s\n\n" % (n, stamp(a), stamp(b), text))


def thumbnail(path):
    """1280x720: the die landed on a captain, in a phone, over a battle; the name beside it."""
    back = wide("dusk", mark("dusk", "CLASH") + 0.6, u=1.0, push=(1.25, 1.25))
    px = np.asarray(back, dtype=np.float32)
    fall = np.linspace(0.35, 0.72, W, dtype=np.float32)[::-1][None, :, None]
    px = px * (1.0 - fall) + np.array(NIGHT, dtype=np.float32) * fall
    img = phone("fall", DIE_LANDS + 0.6, zoom=0.84, focus_y=690, cx=1440, behind=Image.fromarray(px.clip(0, 255).astype(np.uint8)))
    put(img, wordmark(840), (490, 330))
    put(img, words((("EVERY CAPTAIN", CINZEL, 92, BONE, 4), ("CAN FALL.", CINZEL, 92, EMBER, 4)), "left"), (490, 650))
    img.resize((1280, 720), Image.LANCZOS).save(path, quality=92)


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--frame" in sys.argv:  # one frame, to look at: cut.py --frame 20.5
        t = float(sys.argv[sys.argv.index("--frame") + 1])
        path = os.path.join(OUT, "frame_%06.2f.jpg" % t)
        finished(t).save(path, quality=90)
        print(path)
        return
    if "--thumbnail" in sys.argv:
        thumbnail(os.path.join(OUT, NAME + "_thumbnail.jpg"))
        return
    silent = os.path.join(OUT, "picture.mp4")
    enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
                            "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
                            "-movflags", "+faststart", silent], stdin=subprocess.PIPE)
    total = int(LENGTH * FPS)
    for n in range(total):
        enc.stdin.write(finished(n / FPS).tobytes())
        if n % 150 == 0:
            print("  %2d s of %d" % (n // FPS, LENGTH), flush=True)
    enc.stdin.close()
    if enc.wait() != 0:
        sys.exit("ffmpeg failed")
    mix = os.path.join(OUT, "mix.wav")
    soundtrack(mix)
    # Measured, then set to -14 LUFS, YouTube's level, with the peaks held under -1 dB.
    gain = -14.0 - loudness(mix)
    final = os.path.join(OUT, NAME + ".mp4")
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", silent, "-i", mix, "-filter_complex",
                        "[1:a]volume=%.2fdB,alimiter=limit=0.89:attack=2:release=60:level=disabled[a]" % gain,
                        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "320k", "-ar", str(SR),
                        "-movflags", "+faststart", "-t", str(LENGTH), final])
    if r.returncode != 0:
        sys.exit("ffmpeg failed")
    print("wrote %s (mix %+.1f dB to -14 LUFS)" % (final, gain))
    write_captions(os.path.join(OUT, NAME + ".srt"))
    thumbnail(os.path.join(OUT, NAME + "_thumbnail.jpg"))
    print("wrote %s.srt and %s_thumbnail.jpg" % (NAME, NAME))


if __name__ == "__main__":
    main()
