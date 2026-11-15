#!/usr/bin/env python3
"""The "Captains" trailer as a YouTube Short: 1080x1920, 30 fps, 46 s, from the title on.

    SHAPE=tall tools/trailer2/shoot.sh clash wood bows night ford gate wall sea dusk charge won
    python3 tools/trailer2/short.py          # -> $TRAILER_OUT/vaskaria_short.mp4, .srt, _cover.jpg
    python3 tools/trailer2/short.py --frame 1.9   # one frame, at that second of the Short

It is the trailer from its title card (0:24) to its end, on the same music from the same
bar, with every picture laid out upright:

    0:00  the name slams onto the armies as they close
    0:02  the battles, a bar a shot; "Sized for your hand" over the game as it is on a phone
    0:18  the realms: the map, the lords, the wedding, a town, each screen filling the frame
    0:26  the last charge, a beat a shot
    0:34  victory
    0:36  the end card

The battles and the map are recorded upright (shoot.sh with SHAPE=tall, into
$TRAILER_OUT/tall), the soldiers the same size as in the wide trailer; the game's own
screens (the hand, the lords, the wedding, the town) were recorded upright already. Words
stay inside the part of the frame YouTube's Shorts buttons and captions leave clear:
roughly 90 to 930 across and 220 to 1460 down (third-party figures; YouTube publishes none).
The drawing (the logo in lit brass, the backdrops, embers, glint, words) is cut.py's.
"""
import os
import subprocess
import sys

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFilter, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut  # noqa: E402  (the trailer: its pieces, its shots' moments, its words)
from cut import BONE, BRASS, CINZEL, FELL, FPS, SR, bar, ease, words, put, said  # noqa: E402

W, H = 1080, 1920
START = bar(13)                 # the trailer's second the Short begins at: the title's slam
LENGTH = cut.LENGTH - START     # 46 s
OUT = cut.OUT
TALL = os.path.join(OUT, "tall", "shots")
NAME = "vaskaria_short"

# Where words go: clear of the Shorts buttons (right), title and channel (bottom), search (top).
SAFE_W = 840
MID = (W / 2, 900)
LOWER = 1290            # captions over the game's screens, over their least important part
LOGO_AT = 880           # the title card's logo
END_LOGO_AT = 800       # the end card's logo
END_DIM = 0.34          # the end card's backdrop, a little brighter than the wide card's 0.26
LOGO_SCALE = 0.52       # the cards' logo at 0.52 is 811 wide, its name about 755

# The trailer's drawing works at whatever size these say.
cut.W, cut.H = W, H

_frames = {}


def still(shot, secs):
    """The frame of a shot at a second of its recording: the upright recording where there
    is one, else the shot as recorded (the game's own screens, upright already)."""
    n = max(0, int(round(secs * FPS)))
    key = (shot, n)
    if key not in _frames:
        if len(_frames) > 6:
            _frames.pop(next(iter(_frames)))
        for base in (TALL, cut.SHOTS):
            path = os.path.join(base, shot, "f%08d.png" % n)
            if os.path.exists(path):
                img = Image.open(path).convert("RGB")
                if img.size != (W, H):
                    sys.exit("%s is %dx%d, not upright: record it with SHAPE=tall tools/trailer2/shoot.sh %s"
                             % (path, img.width, img.height, shot))
                _frames[key] = img
                break
        else:
            sys.exit("Missing %s at %.2f s: record it (SHAPE=tall tools/trailer2/shoot.sh %s)" % (shot, secs, shot))
    return _frames[key]


cut.still = still  # cut's backdrops and field shots draw through this one


def same_fight():
    """The cut's moments are read from the wide recordings' logs; an upright recording must be
    the same fight at the same seconds, or the Short's cuts would miss them."""
    for shot in os.listdir(TALL) if os.path.isdir(TALL) else []:
        for word in ("CLASH", "IMPACT", "OVER"):
            times = []
            for logs in (os.path.join(OUT, "tall", "logs"), os.path.join(OUT, "logs")):
                path = os.path.join(logs, shot + ".log")
                found = None
                if os.path.exists(path):
                    for row in open(path, errors="replace"):
                        parts = row.split()
                        if len(parts) > 4 and parts[0] == "fight" and parts[4] == word:
                            found = float(parts[3])
                            break
                times.append(found)
            if None not in times and abs(times[0] - times[1]) > 0.04:
                sys.exit("The upright %s is not the same fight (%s at %.2f s, wide %.2f s): record both again"
                         % (shot, word, times[0], times[1]))


# ------------------------------------------------------------------ helpers for the upright frame

def fitted(rows, width=SAFE_W):
    """Rows of type (text, face, size, colour, gap) shrunk together until the widest fits."""
    widest = max(cut.tracked_width(text, cut.font(face, size), gap) for text, face, size, _, gap in rows)
    k = min(1.0, width / widest)
    return tuple((text, face, max(10, int(size * k)), colour, max(0, int(round(gap * k)))) for text, face, size, colour, gap in rows)


def caps(*lines, size=96, colour_last=BRASS):
    """Title lines for a caption, the last in brass, fitted to the safe width."""
    rows = [(text.upper(), CINZEL, size, BONE if i < len(lines) - 1 else colour_last, 4) for i, text in enumerate(lines)]
    return list(fitted(rows))


def shade(img, centre, half, strength):
    """Darkens a band of rows, most at `centre`, so words over a busy picture read."""
    rows = np.clip(1.0 - np.abs(np.arange(H, dtype=np.float32) - centre) / half, 0, 1) ** 0.6
    px = np.asarray(img, dtype=np.float32) * (1.0 - strength * rows)[:, None, None]
    return Image.fromarray(px.astype(np.uint8))


def screen(shot, secs, u=0.0, push=(1.0, 1.03)):
    """One of the game's own screens filling the frame, pushing slowly in, ungraded."""
    img = still(shot, secs)
    z = push[0] + (push[1] - push[0]) * u
    cw, ch = W / z, H / z
    return img.resize((W, H), Image.BILINEAR, box=((W - cw) / 2, (H - ch) / 2, (W + cw) / 2, (H + ch) / 2))


def caption(img, t, t0, t1, rows):
    """A caption over a screen of the game: the lower part darkened, the words rising in."""
    img = shade(img, LOWER, 330, 0.78 * min(1.0, ease((t - t0) / 0.3)))
    said(img, t, t0, t1, rows, (W / 2, LOWER), align="centre")
    return img


def embers(img, T, strength):
    """cut's embers, and a second set mirrored, so the taller frame has as many in the air."""
    img = cut.embers(img, T, strength)
    return ImageOps.mirror(cut.embers(ImageOps.mirror(img), T + 3.7, strength * 0.8))


def slam(img, t, t0, t1, rows, at=MID):
    said(img, t, t0, t1, list(fitted(tuple(rows))), at, align="centre", slam=True)


_cta = None


def call_to_action():
    """The end card's one thing to do between two short brass rules, sized for the upright frame."""
    global _cta
    if _cta is None:
        text = cut.END_LINE.upper()
        size, gap, rule, room = 54, 10, 70, 28
        f = cut.font(CINZEL, size)
        while cut.tracked_width(text, f, gap) + 2 * (rule + room) > SAFE_W:
            size -= 2
            f = cut.font(CINZEL, size)
        tw = cut.tracked_width(text, f, gap)
        layer = words(((text, CINZEL, size, BONE, gap),), "centre")
        w = int(tw + 2 * (rule + room) + 160)
        out = Image.new("RGBA", (w, layer.height), (0, 0, 0, 0))
        out.alpha_composite(layer, ((w - layer.width) // 2, 0))
        bb = ImageDraw.Draw(Image.new("L", (4, 4))).textbbox((0, 0), text, font=f)
        mid = 60 + (bb[1] + bb[3]) / 2
        d = ImageDraw.Draw(out)
        for x in ((w - tw) / 2 - room - rule, (w + tw) / 2 + room):
            d.rectangle([x, mid - 1.5, x + rule, mid + 1.5], fill=BRASS + (255,))
        _cta = out
    return _cta


def warm_core():
    """The warm glow cut.behind keeps where the logo stands, shaped for the upright frame."""
    core = Image.new("L", (W, H), 0)
    ImageDraw.Draw(core).ellipse([W / 2 - 430, LOGO_AT - 380, W / 2 + 430, LOGO_AT + 380], fill=255)
    core = np.asarray(core.filter(ImageFilter.GaussianBlur(170)), dtype=np.float32)
    return (core / core.max())[..., None] * np.array([60, 40, 14], dtype=np.float32)


cut._core = warm_core()


# ------------------------------------------------------------------ the Short

def picture(T):
    """The Short's frame at the trailer's second T (from bar 13 on)."""
    # ---- bar 13: the name slams onto the armies as they close, then a glint crosses it
    if T < bar(14):
        u = T - bar(13)
        img = cut.behind("clash", cut.mark("clash", "CLASH") - 2.9 + u, 0.42, 2)
        centre = (W / 2, LOGO_AT)
        if u < 0.5:
            img = cut.ring(img, centre, 150 + 750 * u / 0.5, 0.5 * (1.0 - u / 0.5))
        img = embers(img, T, 1.0)
        scale = LOGO_SCALE * (1.30 - 0.30 * ease(u / 0.16) + 0.02 * (u / 2.0))
        jolt = max(0.0, 1.0 - u / 0.35)
        at = (centre[0] + np.sin(T * 90) * 10 * jolt, centre[1] + np.cos(T * 70) * 8 * jolt)
        return cut.draw_lockup(img, scale, at, 1.0, (u - 0.35) / 0.65 if 0.35 <= u <= 1.0 else None)
    # ---- bars 14-21: the battles
    if T < bar(22):
        k = int((T - bar(14)) / 2.0)
        u = T - (bar(14) + 2.0 * k)
        shot, start, word = cut.BATTLES[k]
        if shot == "hand":
            # The game as it is on a phone, filling the phone.
            img = shade(screen(shot, start + u, u / 2.0), 560, 300, 0.7 * min(1.0, ease(u / 0.3)))
            said(img, T, bar(15) + 0.1, bar(16), caps("Sized for", "your hand.", size=110), (W / 2, 560), align="centre")
            return img
        img = cut.wide(shot, start + u, u=u / 2.0, shake=max(0.0, 0.6 - u / 0.3) if k in (0, 4) else 0.0, t=T)
        if k == 0:
            slam(img, T, bar(14) + 0.15, bar(15), [("REAL-TIME", CINZEL, 150, BONE, 10), ("BATTLES", CINZEL, 150, BONE, 10)])
        if word:
            slam(img, T, bar(14) + 2.0 * k + 0.02, bar(14) + 2.0 * k + 1.5, [(word.upper(), CINZEL, 190, BRASS, 14)])
        if shot in ("gate", "wall"):
            slam(img, T, bar(20) + 0.1, bar(22), [("TAKE THEIR", CINZEL, 130, BONE, 10), ("WALLS.", CINZEL, 130, BONE, 10)],
                 at=(W / 2, 1300))
        return img
    # ---- bars 22-25: the realms
    if T < bar(23):
        u = T - bar(22)
        img = cut.wide("sea", 5.3 + u, u=u / 2.0, push=(1.0, 1.04))
        said(img, T, bar(22) + 0.1, bar(23), caps("The Three", "Realms.", "One crown.", size=120), MID, align="centre")
        return img
    if T < bar(24):
        u = T - bar(23)
        img = screen("emir" if u < 1.0 else "daimyo", 1.2 + (u % 1.0), u / 2.0)
        return caption(img, T, bar(23) + 0.05, bar(24), caps("Win the lords'", "regard."))
    if T < bar(25):
        u = T - bar(24)
        return caption(screen("vows", 4.6 + u, u / 2.0), T, bar(24) + 0.05, bar(25), caps("Marry into", "a great house."))
    if T < bar(26):
        u = T - bar(25)
        return caption(screen("town", 1.5 + u, u / 2.0), T, bar(25) + 0.05, bar(26), caps("Build a company", "worth following."))
    # ---- bars 26-29: the last charge, a beat a shot
    if T < bar(30):
        k = int(T - bar(26))
        u = T - bar(26) - k
        shot, start = cut.LAST[k]
        return cut.wide(shot, start + u, u=u, push=cut.LAST_PUSH.get(shot, (1.04, 1.1)), shake=max(0.0, 0.5 - u / 0.2), t=T)
    # ---- bar 30: victory, then into the end card's backdrop
    if T < bar(31):
        u = T - bar(30)
        img = cut.wide("won", min(cut.STAMP + u, cut.STAMP + 1.7), u=u / 2.0, push=(1.6, 1.75))
        img = shade(img, MID[1], 220, 0.72 * ease(u / 0.1))
        slam(img, T, bar(30) + 0.02, bar(30) + 1.6, [("VICTORY.", CINZEL, 210, BRASS, 16)])
        if u > 1.3:
            img = Image.blend(img, cut.behind("dusk", 7.5, END_DIM, 5), ease((u - 1.3) / 0.7))
        return img
    # ---- bars 31-35: the end card; the glint on the horn (62.0) and, fainter, the harp (66.0)
    u = T - bar(31)
    img = embers(cut.behind("dusk", 7.5 + u * 0.5, END_DIM, 5), T, 0.8)
    if u >= 0.4:
        arrive = ease((u - 0.4) / 1.2)
        scale = LOGO_SCALE * (1.0 + 0.03 * max(0.0, (u - 1.6) / (cut.LENGTH - bar(31) - 1.6)))
        shine, strength = None, 0.75
        if 2.0 <= u <= 2.7:
            shine = (u - 2.0) / 0.7
        elif 6.0 <= u <= 6.6:
            shine, strength = (u - 6.0) / 0.6, 0.375
        cut.draw_lockup(img, scale, (W / 2, END_LOGO_AT + 30 * (1.0 - arrive)), arrive, shine, strength)
    put(img, call_to_action(), (W / 2, 1220), opacity=ease((u - 2.6) / 0.8))
    if cut.STORE_BADGE:
        if u >= 3.4:
            # Apple's badge as it comes: resized only, a plain cut in, nothing done to it.
            badge = Image.open(cut.STORE_BADGE).convert("RGBA")
            badge = badge.resize((round(badge.width * 96 / badge.height), 96), Image.LANCZOS)
            img.paste(badge, (int(W / 2 - badge.width / 2), 1330 - 48), badge)
    elif cut.END_ACTION:
        put(img, words(fitted(((cut.END_ACTION, FELL, 44, (198, 201, 214), 0),)), "centre"), (W / 2, 1310),
            opacity=ease((u - 3.2) / 0.8))
    return img


# The trailer's flashes from the title on. The first, on the very first frame, is gentler: it
# is the first thing a viewer scrolling past sees.
FLASHES = [(when, 0.6 if when == START else strength) for when, strength in cut.FLASHES if when >= START]


def finished(t):
    """The Short's frame at its own second t. No fade at either end: it opens on the slam and
    holds the end card, and a Short plays round again."""
    T = START + t
    img = picture(T)
    for when, strength in FLASHES:
        if 0.0 <= T - when < 0.2:
            img = Image.blend(img, Image.new("RGB", (W, H), (255, 250, 238)), strength * (1.0 - (T - when) / 0.2) ** 2)
    return img


# ------------------------------------------------------------------ sound, words, cover

def soundtrack(path):
    """The score from the title's hit on, with each shot's own sound under it where it plays."""
    score, sr = sf.read(os.path.join(OUT, "score.wav"), dtype="float32", always_2d=True)
    if sr != SR:
        sys.exit("score.wav should be %d Hz: run tools/trailer2/score.py" % SR)
    n = int(round(LENGTH * SR))
    mix = np.zeros((n, 2), dtype=np.float32)
    piece = score[int(round(START * SR)):][:n]
    mix[: len(piece)] += piece
    # Three milliseconds in, so the very first sample is not a click.
    edge = int(0.003 * SR)
    mix[:edge] *= np.linspace(0, 1, edge, dtype=np.float32)[:, None]
    for when, shot, start, secs, level in cut.field_sound():
        if when < START:
            continue
        wav = os.path.join(TALL, shot, "f.wav")
        if not os.path.exists(wav):
            wav = os.path.join(cut.SHOTS, shot, "f.wav")
        x, sr = sf.read(wav, dtype="float32", always_2d=True, start=max(0, int(start * SR)), frames=int(secs * SR))
        if sr != SR or len(x) < 2400:
            continue
        x = x[:, :2] * level
        e = int(0.04 * SR)
        x[:e] *= np.linspace(0, 1, e, dtype=np.float32)[:, None]
        x[-e:] *= np.linspace(1, 0, e, dtype=np.float32)[:, None]
        i = int((when - START) * SR)
        k = min(len(x), n - i)
        mix[i:i + k] += x[:k]
    sf.write(path, mix, SR, subtype="PCM_24")


def write_captions(path):
    def stamp(s):
        ms = round(s * 1000)
        return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)
    rows = [(a - START, b - START, text) for a, b, text in cut.CAPTIONS if a >= START]
    with open(path, "w") as f:
        for n, (a, b, text) in enumerate(rows, start=1):
            f.write("%d\n%s --> %s\n%s\n\n" % (n, stamp(a), stamp(b), text))


def main():
    same_fight()
    os.makedirs(OUT, exist_ok=True)
    if "--frame" in sys.argv:  # one frame, to look at: short.py --frame 1.9
        t = float(sys.argv[sys.argv.index("--frame") + 1])
        path = os.path.join(OUT, "short_%06.2f.jpg" % t)
        finished(t).save(path, quality=90)
        print(path)
        return
    silent = os.path.join(OUT, "short_picture.mp4")
    enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
                            "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
                            "-movflags", "+faststart", silent], stdin=subprocess.PIPE)
    total = int(round(LENGTH * FPS))
    for n in range(total):
        enc.stdin.write(finished(n / FPS).tobytes())
        if n % 150 == 0:
            print("  %2d s of %d" % (n // FPS, LENGTH), flush=True)
    enc.stdin.close()
    if enc.wait() != 0:
        sys.exit("ffmpeg failed")
    mix = os.path.join(OUT, "short_mix.wav")
    soundtrack(mix)
    gain = -14.0 - cut.loudness(mix)
    final = os.path.join(OUT, NAME + ".mp4")
    r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", silent, "-i", mix, "-filter_complex",
                        "[1:a]volume=%.2fdB,alimiter=limit=0.89:attack=2:release=60:level=disabled[a]" % gain,
                        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "320k", "-ar", str(SR),
                        "-movflags", "+faststart", "-t", str(LENGTH), final])
    if r.returncode != 0:
        sys.exit("ffmpeg failed")
    print("wrote %s (%.0f s, mix %+.1f dB to -14 LUFS)" % (final, LENGTH, gain))
    write_captions(os.path.join(OUT, NAME + ".srt"))
    # A cover to choose in YouTube: the name settled over the armies, the glint gone by.
    finished(1.9).save(os.path.join(OUT, NAME + "_cover.jpg"), quality=92)
    print("wrote %s.srt and %s_cover.jpg" % (NAME, NAME))


if __name__ == "__main__":
    main()
