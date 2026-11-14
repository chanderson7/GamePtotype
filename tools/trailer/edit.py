#!/usr/bin/env python3
"""Cuts the YouTube trailer (1920x1080, 30 fps, H.264 + AAC) from the clips record_all.sh made.

    python3 tools/trailer/edit.py            # writes $TRAILER_OUT/bannerfall_trailer.mp4 and a thumbnail

The score is the game's main theme (assets/audio/music/title.ogg, 80 s); the cut follows its
shape: the quiet open for the Glass Sea, the swell for the title, the climax for the battles,
the tail for the end card. Under it, each clip keeps its own field sounds (recorded with the
music off). Landscape clips (the battles, the map) fill the frame; portrait clips (the game's
own screens) stand framed over a blurred copy of themselves, a caption beside them.
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.environ.get("TRAILER_OUT", "/tmp/bannerfall-trailer")
CLIPS = os.path.join(OUT, "clips")
WORK = os.path.join(OUT, "edit")
W, H, FPS = 1920, 1080, 30

NIGHT = (14, 19, 34)
BRASS = (217, 169, 68)
TEXT = (236, 229, 211)
MUTED = (166, 173, 200)
DISPLAY = os.path.join(ROOT, "assets/fonts/Cinzel-Bold.ttf")
ITALIC = os.path.join(ROOT, "assets/fonts/IMFellEnglish-Italic.ttf")
MUSIC = os.path.join(ROOT, "assets/audio/music/title.ogg")
WORDMARK = os.path.join(ROOT, "assets/branding/wordmark.png")

# The theme's bars: it moves in bars of 1.667 s from 0.84 s. Cuts land on them: the title
# on the swell (bar 9), the first clash on the climax (bar 23), the end card on the tail.
BAR0, BAR = 0.84, 1.6667


def bar(k):
    return BAR0 + BAR * k


# The cut. Each entry is a card (text on the night), the end card, or a clip, and runs
# until `to` on the timeline (seconds; the previous entry's end is its start):
#   shot: the recorded clip; at: where in it to start (s)
#   frame: for a portrait clip, the part of its 1080x1920 screen to show (x, y, w, h)
#   cap: (title, line, where) where is "left" (beside a portrait), "low" (lower left), "mid"
#   fade: (in, out) seconds through black; sfx: gain on the clip's own sound (0 for none)
#   zoom: for a landscape clip, how far to crop in on its middle
#   bg_y: for a portrait clip, how far down the shown part its blurred backdrop is taken
END_LINE = "Coming to iPhone"  # the end card's line, under the wordmark
LORDS = ("Win the lords' regard", "Every lord remembers what you did.", "left")
EDL = [
    {"card": ("Three realms", "share one inland sea"), "to": bar(2), "fade": (1.0, 0.4)},
    {"shot": "map_fly", "at": 0.5, "to": bar(5), "fade": (0.4, 0.0),
     "cap": ("The Glass Sea", "Stone keeps. Desert courts. Island castles.", "low")},
    {"shot": "map_isles", "at": 2.0, "to": bar(8), "fade": (0.0, 0.3)},
    {"shot": "opening", "at": 0.3, "to": bar(10), "fade": (0.3, 0.0), "frame": (0, 600, 1080, 960)},
    {"shot": "home", "at": 1.0, "sfx": 0.35, "to": bar(12), "frame": (0, 0, 1080, 1420),
     "cap": ("Raise a warband", "Captains, companies, silver and renown.", "left")},
    {"shot": "map_ride", "at": 1.5, "sfx": 0.35, "to": bar(14), "frame": (0, 140, 1080, 1780), "bg_y": 300,
     "cap": ("Ride the roads", "Bandits, raiders and rival lords.", "left")},
    {"shot": "talk_ravensford", "at": 5.2, "sfx": 0.35, "to": bar(15.67), "frame": (0, 0, 1080, 1500), "cap": LORDS},
    {"shot": "talk_qasr", "at": 0.6, "sfx": 0.35, "to": bar(17.33), "frame": (0, 0, 1080, 1500), "cap": LORDS},
    {"shot": "talk_kitayama", "at": 5.0, "sfx": 0.35, "to": bar(19), "frame": (0, 0, 1080, 1500), "cap": LORDS},
    {"shot": "wedding", "at": 14.6, "sfx": 0.35, "to": bar(21), "frame": (0, 0, 1080, 1500),
     "cap": ("Marry into a great house", "Feasts, dances, vows and pacts.", "left")},
    {"shot": "battle_title", "at": 5.0, "to": bar(23), "sfx": 0.45},
    {"shot": "battle_open", "at": 12.5, "to": bar(25), "sfx": 0.4,
     "cap": ("Lead every company", "Real-time squad battles, sized for your hand.", "low")},
    {"shot": "battle_cavalry", "at": 24.8, "to": bar(26.5), "sfx": 0.4},
    {"shot": "battle_woods", "at": 15.5, "to": bar(28), "sfx": 0.4},
    {"shot": "battle_hud", "at": 9.0, "to": bar(30), "sfx": 0.35, "bg_y": 260,
     "cap": ("Shield walls. Volleys. Charges.", "Read the field and give the order.", "left")},
    {"shot": "battle_river", "at": 9.0, "to": bar(31.5), "sfx": 0.4},
    {"shot": "battle_archers", "at": 10.0, "to": bar(33), "sfx": 0.4},
    {"shot": "battle_night", "at": 11.5, "to": bar(34.5), "sfx": 0.4},
    {"shot": "battle_wide", "at": 10.5, "to": bar(36.5), "sfx": 0.4},
    {"shot": "battle_win", "at": 24.2, "to": bar(38.5), "sfx": 0.5, "zoom": 1.5},
    {"shot": "battle_result", "at": 9.2, "to": bar(41), "sfx": 0.35, "fade": (0.0, 0.8),
     "frame": (0, 0, 1080, 1500), "cap": ("Make your name", "Every company's story is told.", "left")},
    {"end": True, "to": 80.0, "fade": (0.8, 1.8)},
]


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(" ".join(cmd) + "\n" + r.stderr[-3000:])
        raise SystemExit(1)


def font(path, size):
    return ImageFont.truetype(path, size)


def spaced(draw, xy, text, f, fill, spacing):
    """Draws `text` with extra letter spacing; returns its width."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + spacing
    return x - xy[0] - spacing


def spaced_width(draw, text, f, spacing):
    return sum(draw.textlength(ch, font=f) for ch in text) + spacing * max(0, len(text) - 1)


def shadowed(layer, radius=10, alpha=200):
    """`layer` (RGBA) over a soft dark shadow of itself."""
    a = layer.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    a = a.point(lambda v: min(255, v * alpha // 255 * 2))
    shadow = Image.new("RGBA", layer.size, (4, 6, 12, 0))
    shadow.putalpha(a)
    out = Image.alpha_composite(Image.new("RGBA", layer.size, (0, 0, 0, 0)), shadow)
    return Image.alpha_composite(out, layer)


def caption_png(path, title, line, where, panel=None):
    """A full-frame RGBA layer: the title in the display face, brass, the line under it."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ft = font(DISPLAY, 58 if where != "left" else 54)
    fl = font(ITALIC, 38)
    t = title.upper()
    tw = spaced_width(d, t, ft, 4)
    lw = d.textlength(line, font=fl) if line else 0
    if where == "left":
        # Centred in the space left of the framed screen, wrapped to fit it.
        right = panel[0] - 70 if panel else W // 2
        box_w = right - 90
        words, rows, cur = t.split(" "), [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if spaced_width(d, trial, ft, 4) <= box_w:
                cur = trial
            else:
                rows.append(cur)
                cur = w
        rows.append(cur)
        lines, cur = [], ""
        for w in (line.split(" ") if line else []):
            trial = (cur + " " + w).strip()
            if d.textlength(trial, font=fl) <= box_w:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        block_h = len(rows) * 70 + 26 + len(lines) * 48
        y = (H - block_h) // 2
        cx = 90 + box_w // 2
        for r in rows:
            rw = spaced_width(d, r, ft, 4)
            spaced(d, (cx - rw / 2, y), r, ft, BRASS, 4)
            y += 70
        d.line([(cx - 70, y + 6), (cx + 70, y + 6)], fill=BRASS + (150,), width=2)
        y += 26
        for ln in lines:
            d.text((cx - d.textlength(ln, font=fl) / 2, y), ln, font=fl, fill=TEXT)
            y += 48
    elif where == "mid":
        y = H // 2 - 60
        spaced(d, ((W - tw) / 2, y), t, ft, BRASS, 4)
        if line:
            d.text(((W - lw) / 2, y + 84), line, font=fl, fill=TEXT)
    else:
        x, y = 110, H - 210 if line else H - 160
        spaced(d, (x, y), t, ft, BRASS, 4)
        d.line([(x, y + 80), (x + 140, y + 80)], fill=BRASS + (150,), width=2)
        if line:
            d.text((x, y + 96), line, font=fl, fill=TEXT)
        # Over a field or the map the words need dark under them (brass on sand is lost):
        # a shade rising from the lower left corner, fading with the caption.
        down = np.clip((np.arange(H, dtype=np.float32) - (H - 540)) / 540.0, 0, 1)[:, None] ** 1.2
        across = np.clip((1700.0 - np.arange(W, dtype=np.float32)) / 800.0, 0, 1)[None, :]
        shade = Image.new("RGBA", (W, H), (6, 8, 16, 0))
        shade.putalpha(Image.fromarray((down * across * 205).astype(np.uint8)))
        Image.alpha_composite(shade, shadowed(shadowed(img, 3, 255), 12)).save(path)
        return
    shadowed(img, 12).save(path)


def night_bg():
    """The night the cards stand on: a soft glow in the middle, darker at the edges."""
    img = Image.new("RGB", (W, H), NIGHT)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.18, H * 0.05, W * 0.82, H * 0.95], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    lift = Image.new("RGB", (W, H), (30, 38, 66))
    img = Image.composite(lift, img, glow)
    # A little grain, so the glow doesn't fall into bands (here, or after compression).
    px = np.asarray(img, dtype=np.float32)
    px += np.random.default_rng(7).normal(0.0, 1.3, px.shape)
    return Image.fromarray(np.clip(px + 0.5, 0, 255).astype(np.uint8))


def card_png(path, title, line):
    img = night_bg().convert("RGBA")
    d = ImageDraw.Draw(img)
    ft = font(DISPLAY, 76)
    fl = font(ITALIC, 46)
    t = title.upper()
    tw = spaced_width(d, t, ft, 8)
    y = H // 2 - 70
    spaced(d, ((W - tw) / 2, y), t, ft, BRASS, 8)
    d.line([(W / 2 - 90, y + 108), (W / 2 + 90, y + 108)], fill=BRASS + (140,), width=2)
    lw = d.textlength(line, font=fl)
    d.text(((W - lw) / 2, y + 128), line, font=fl, fill=MUTED)
    img.convert("RGB").save(path)


def end_png(path):
    img = night_bg().convert("RGBA")
    mark = Image.open(WORDMARK).convert("RGBA")
    mw = 1400
    mark = mark.resize((mw, round(mark.height * mw / mark.width)), Image.LANCZOS)
    img.alpha_composite(mark, ((W - mw) // 2, H // 2 - mark.height // 2 - 70))
    d = ImageDraw.Draw(img)
    f = font(DISPLAY, 38)
    for i, (t, col) in enumerate([(END_LINE, TEXT)]):
        t = t.upper()
        tw = spaced_width(d, t, f, 6)
        spaced(d, ((W - tw) / 2, H // 2 + 165 + i * 60), t, f, col, 6)
    img.convert("RGB").save(path)


def frame_png(path, rect):
    """Under a framed portrait screen: its shadow, and a thin brass edge round it."""
    x, y, w, h = rect
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle([x - 6, y + 4, x + w + 6, y + h + 18], 18, fill=210)
    sh = sh.filter(ImageFilter.GaussianBlur(22))
    img.paste((0, 0, 0, 255), (0, 0), sh)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x - 5, y - 5, x + w + 4, y + h + 4], 14, outline=BRASS + (230,), width=3)
    img.save(path)


def shape_of(shot):
    with Image.open(os.path.join(CLIPS, shot, "f00000000.png")) as im:
        return "landscape" if im.width > im.height else "portrait"


def seg_video(i, seg, path):
    dur = seg["dur"]
    fi, fo = seg.get("fade", (0.0, 0.0))
    fades = []
    if fi > 0:
        fades.append(f"fade=t=in:st=0:d={fi}")
    if fo > 0:
        fades.append(f"fade=t=out:st={dur - fo:.3f}:d={fo}")
    tail = ("," + ",".join(fades)) if fades else ""
    enc = ["-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS),
           "-frames:v", str(round(dur * FPS)), "-an"]
    if "card" in seg or "end" in seg:
        png = os.path.join(WORK, f"card_{i:02d}.png")
        if "card" in seg:
            card_png(png, *seg["card"])
        else:
            end_png(png)
        # A slow push in on the still, so a card isn't a dead frame.
        n = round(dur * FPS)
        vf = (f"scale=3840:2160,zoompan=z='1+0.03*on/{n}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
              f":d=1:s={W}x{H}:fps={FPS}{tail}")
        run(["ffmpeg", "-y", "-loop", "1", "-framerate", str(FPS), "-i", png, "-vf", vf] + enc + [path])
        return
    shot = seg["shot"]
    start = round(seg["at"] * FPS)
    src = ["-framerate", str(FPS), "-start_number", str(start), "-i", os.path.join(CLIPS, shot, "f%08d.png")]
    inputs, graph = list(src), []
    if shape_of(shot) == "landscape":
        z = float(seg.get("zoom", 1.0))
        crop = f"crop=iw/{z}:ih/{z}:(iw-iw/{z})/2:(ih-ih/{z})/2," if z != 1.0 else ""
        graph.append(f"[0:v]{crop}scale={W}:{H}:flags=lanczos,setsar=1[v]")
    else:
        fx, fy, fw, fh = seg.get("frame", (0, 0, 1080, 1920))
        ph = 1000 if fh > 1600 else 960
        pw = round(fw * ph / fh / 2) * 2
        left = "cap" in seg and seg["cap"][2] == "left"
        px = (W - pw) // 2 + (300 if left else 0)
        px = min(px, W - pw - 90)
        py = (H - ph) // 2
        deco = os.path.join(WORK, f"frame_{i:02d}.png")
        frame_png(deco, (px, py, pw, ph))
        inputs += ["-loop", "1", "-i", deco]
        graph.append("[0:v]split[a][b]")
        # The backdrop is the top of the shown part (its art, not its buttons), blurred.
        bh = round(fw * 9 / 16 / 2) * 2
        by = fy + int(seg.get("bg_y", 0))
        graph.append(f"[a]crop={fw}:{bh}:{fx}:{by},scale={W}:{H},gblur=sigma=40,eq=brightness=-0.26:saturation=0.7,"
                     f"noise=alls=4[bg]")
        graph.append(f"[b]crop={fw}:{fh}:{fx}:{fy},scale={pw}:{ph}:flags=lanczos[fg]")
        graph.append(f"[bg][1:v]overlay=0:0[bgd]")
        graph.append(f"[bgd][fg]overlay={px}:{py},setsar=1[v]")
        seg["_panel"] = (px, py, pw, ph)
    last = "v"
    if "cap" in seg:
        title, line, where = seg["cap"]
        cap = os.path.join(WORK, f"cap_{i:02d}.png")
        caption_png(cap, title, line, where, seg.get("_panel"))
        inputs += ["-loop", "1", "-i", cap]
        idx = sum(1 for a in inputs if a == "-i") - 1
        # The same caption on the shots either side runs on through the cut, unfaded.
        cf = []
        if seg.get("_cap_from_prev") is not True:
            cf.append("fade=t=in:st=0.25:d=0.45:alpha=1")
        if seg.get("_cap_to_next") is not True:
            cf.append(f"fade=t=out:st={dur - 0.65:.3f}:d=0.35:alpha=1")
        graph.append(f"[{idx}:v]format=rgba" + "".join("," + f for f in cf) + "[c]")
        graph.append(f"[{last}][c]overlay=0:0[vc]")
        last = "vc"
    graph.append(f"[{last}]null{tail}[out]")
    run(["ffmpeg", "-y"] + inputs + ["-filter_complex", ";".join(graph), "-map", "[out]"] + enc + [path])


def main():
    os.makedirs(WORK, exist_ok=True)
    parts, t, sfx = [], 0.0, []
    for seg in EDL:
        # Whole frames, so the cuts stay on the bars however the frames round.
        seg["dur"] = round((seg["to"] - t) * FPS) / FPS
        t += seg["dur"]
    for a, b in zip(EDL, EDL[1:]):
        if "cap" in a and a.get("cap") == b.get("cap"):
            a["_cap_to_next"] = b["_cap_from_prev"] = True
    t = 0.0
    for i, seg in enumerate(EDL):
        p = os.path.join(WORK, f"seg_{i:02d}.mp4")
        print(f"{t:6.2f}s  {seg.get('shot', 'card' if 'card' in seg else 'end')}  ({seg['dur']}s)", flush=True)
        seg_video(i, seg, p)
        parts.append(p)
        if seg.get("sfx", 0) > 0:
            sfx.append((os.path.join(CLIPS, seg["shot"], "f.wav"), seg["at"], seg["dur"], t, seg["sfx"]))
        t += seg["dur"]
    total = t
    lst = os.path.join(WORK, "parts.txt")
    with open(lst, "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    video = os.path.join(WORK, "video.mp4")
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", video])

    # The score, and each clip's field sounds where it plays, then loudness for YouTube.
    ins = ["-i", MUSIC]
    graph = [f"[0:a]atrim=0:{total},afade=t=out:st={total - 2.0:.2f}:d=2.0[m]"]
    labels = ["[m]"]
    for k, (wav, at, dur, when, gain) in enumerate(sfx, start=1):
        ins += ["-ss", f"{at}", "-t", f"{dur}", "-i", wav]
        ms = round(when * 1000)
        graph.append(f"[{k}:a]aresample=48000,aformat=channel_layouts=stereo,afade=t=in:d=0.08,"
                     f"afade=t=out:st={dur - 0.15:.2f}:d=0.15,volume={gain},adelay={ms}|{ms}[s{k}]")
        labels.append(f"[s{k}]")
    graph.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0:duration=first[a]")
    mix = os.path.join(WORK, "mix.wav")
    run(["ffmpeg", "-y"] + ins + ["-filter_complex", ";".join(graph), "-map", "[a]", "-c:a", "pcm_s24le", mix])
    # Measured, then turned to -14 LUFS (YouTube's level), peaks held under -1 dB.
    r = subprocess.run(["ffmpeg", "-hide_banner", "-i", mix, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                       capture_output=True, text=True)
    loud = float([ln for ln in r.stderr.splitlines() if ln.strip().startswith("I:")][-1].split()[1])
    gain = -14.0 - loud
    print(f"mix at {loud:.1f} LUFS; {gain:+.1f} dB")
    final = os.path.join(OUT, "bannerfall_trailer.mp4")
    run(["ffmpeg", "-y", "-i", video, "-i", mix, "-filter_complex",
         f"[1:a]volume={gain:.2f}dB,alimiter=limit=0.89:attack=2:release=60:level=disabled[a]",
         "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "320k", "-ar", "48000",
         "-movflags", "+faststart", "-t", f"{total}", final])
    print(f"wrote {final} ({total:.1f}s)")
    subs = os.path.join(OUT, "bannerfall_trailer.srt")
    subtitles(subs)
    print(f"wrote {subs}")
    thumb = os.path.join(OUT, "bannerfall_thumbnail.jpg")
    thumbnail(os.path.join(CLIPS, "battle_river", "f%08d.png" % int(10.5 * FPS)), thumb)
    print(f"wrote {thumb}")


def subtitles(path):
    """The words on screen as an .srt, to upload beside the video: YouTube can then search
    and translate them. A caption that runs on across a cut is one entry."""
    def stamp(t):
        ms = round(t * 1000)
        return "%02d:%02d:%02d,%03d" % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)

    rows, t = [], 0.0
    for seg in EDL:
        if "end" in seg:
            words = ("Bannerfall", END_LINE)
        else:
            words = (seg.get("card") or seg.get("cap") or (None,))[:2]
        if words[0]:
            text = "\n".join(w for w in words if w)
            if rows and rows[-1][2] == text and abs(rows[-1][1] - t) < 0.01:
                rows[-1][1] = t + seg["dur"]
            else:
                rows.append([t, t + seg["dur"], text])
        t += seg["dur"]
    with open(path, "w") as f:
        for n, (a, b, text) in enumerate(rows, start=1):
            f.write(f"{n}\n{stamp(a)} --> {stamp(b)}\n{text}\n\n")


def thumbnail(frame, path):
    """A 1280x720 YouTube thumbnail: a battle with the wordmark over a darkened top."""
    tw, th = 1280, 720
    img = np.asarray(Image.open(frame).convert("RGB").resize((tw, th), Image.LANCZOS), dtype=np.float32)
    shade = np.clip(1 - np.arange(th, dtype=np.float32)[:, None, None] / 330.0, 0, 1) * 0.82
    img = img * (1 - shade) + np.array(NIGHT, dtype=np.float32) * shade
    base = Image.fromarray(img.clip(0, 255).astype(np.uint8)).convert("RGBA")
    mark = Image.open(WORDMARK).convert("RGBA")
    mw = 1000
    mark = mark.resize((mw, round(mark.height * mw / mark.width)), Image.LANCZOS)
    shadow = Image.new("RGBA", mark.size, (0, 0, 0, 0))
    shadow.putalpha(mark.getchannel("A").filter(ImageFilter.GaussianBlur(8)).point(lambda v: v * 3 // 4))
    x = (tw - mw) // 2
    base.alpha_composite(shadow, (x + 3, 22))
    base.alpha_composite(mark, (x, 16))
    base.convert("RGB").save(path, quality=92)


if __name__ == "__main__":
    main()
