"""Composes and renders Bannerfall's music and sound effects.

Everything is synthesized here from nothing but numpy: plucked strings, winds, drones,
drums, brass and bells, played from the scores below, then written to WAV and encoded
to Ogg Vorbis with ffmpeg into assets/audio/. The same script always renders the same
files.

Music:
  title       The Glass Sea: horn over harp and strings, D minor.
  vardish     Vardmark: lute and recorder over a hurdy-gurdy drone, D dorian, in three.
  kharzani    Kharzan: oud and ney over a frame drum's maqsum, D hijaz.
  ryumon      The Ryumon isles: koto and shakuhachi with taiko, E in-scale.
  battle_low  Battle: war drums and a driving low ostinato. Always on.
  battle_high Battle: horns and snares, the same length, faded in as the fighting grows.
  victory, defeat   Short stingers.
Loops are seamless: each is rendered three times over and the middle pass kept, so
what rings across its ends is what rings across them when it loops.

    python3 tools/music.py            # everything
    python3 tools/music.py sfx        # only the sound effects
    python3 tools/music.py vardish    # one piece
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 32000
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "audio")


def rng_for(name):
    """A random stream of its own for each piece and sound, so they render the same every time."""
    return np.random.default_rng(sum(map(ord, name)) * 7919 + len(name))


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def ramp(n, length):
    """0 to 1 over `length` samples, then 1."""
    r = np.ones(n)
    k = min(n, max(1, int(length)))
    r[:k] = np.linspace(0.0, 1.0, k)
    return r


def fade_out(x, length):
    k = min(len(x), max(1, int(length)))
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


def band(x, lo, hi, order=2):
    """Keep frequencies between lo and hi (Hz), with gentle shoulders, by FFT."""
    spec = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1.0)
    mask = np.ones_like(f)
    if lo > 0:
        mask /= 1.0 + (lo / f) ** (2 * order)
    if hi < SR / 2:
        mask /= 1.0 + (f / hi) ** (2 * order)
    return np.fft.irfft(spec * mask, len(x))


def lowpass(x, hi):
    return band(x, 0, hi)


# ------------------------------------------------------------------ instruments

def pluck(freq, ring, bright=0.6, decay=1.4, inharm=0.0003, glide=0.0, rng=None, partials=16):
    """A plucked string, built from decaying harmonics; upper ones die first."""
    n = int(ring * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + glide * np.exp(-t * 25.0))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for k in range(1, partials + 1):
        stretch = np.sqrt(1.0 + inharm * k * k)
        if freq * k * stretch > SR / 2.3:
            break
        amp = bright ** (k - 1) / k ** 0.6
        out += amp * np.sin(phase * k * stretch + (rng.uniform(0, 6.28) if rng is not None else 0.0)) \
            * np.exp(-t / (decay / (1.0 + 0.5 * (k - 1))))
    if rng is not None:
        m = min(n, int(0.012 * SR))
        out[:m] += rng.standard_normal(m) * np.linspace(0.25, 0.0, m)
    return out * ramp(n, 0.002 * SR)


def wind(freq, dur, breath=0.12, vib=0.006, vib_rate=5.2, bend=0.0, attack=0.06, release=0.15,
         harm=(1.0, 0.35, 0.14, 0.06), rng=None):
    """A flute-like voice: a few harmonics, vibrato that grows in, a breath of noise, and
    an optional bend into the note (in semitones)."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    v = 1.0 + vib * np.sin(2 * np.pi * vib_rate * t) * np.clip(t / 0.35, 0, 1)
    f = freq * 2.0 ** (bend * np.exp(-t / 0.12) / 12.0) * v
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = sum(h * np.sin(phase * (k + 1)) for k, h in enumerate(harm))
    if rng is not None and breath > 0:
        noise = band(rng.standard_normal(n), freq * 0.8, freq * 3.5)
        tone += noise * breath * 3.0 / (np.std(noise) * 10 + 1e-9)
    env = ramp(n, attack * SR)
    rel = int(release * SR)
    env[-rel:] *= np.linspace(1.0, 0.0, rel)
    return tone * env


def pad(freq, dur, bright=0.55, voices=3, detune=0.004, attack=1.2, release=1.2, partials=12, rng=None):
    """A sustained bowed or droning tone: a few detuned, softened sawtooths."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        fv = freq * (1.0 + detune * (v - (voices - 1) / 2.0))
        ph = (rng.uniform(0, 6.28) if rng is not None else 0.0)
        for k in range(1, partials + 1):
            if fv * k > SR / 2.3:
                break
            out += bright ** (k - 1) / k * np.sin(2 * np.pi * fv * k * t + ph * k)
    out /= voices
    env = np.minimum(ramp(n, attack * SR), ramp(n, release * SR)[::-1])
    return out * env


def brass(freq, dur, attack=0.07, release=0.18, vib=0.004, rng=None):
    """A horn: harmonics that brighten as the note swells, with a little vibrato."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    env = ramp(n, attack * SR)
    rel = int(release * SR)
    env[-rel:] *= np.linspace(1.0, 0.0, rel)
    swell = np.clip(t / (attack * 3.0), 0, 1) * 0.6 + 0.4
    f = freq * (1.0 + vib * np.sin(2 * np.pi * 5.0 * t) * np.clip(t / 0.4, 0, 1))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)
    for k in range(1, 14):
        if freq * k > SR / 2.3:
            break
        out += (swell ** (k * 0.5)) / k * np.sin(phase * k)
    return out * env


def drum(freq, decay, dur=None, noise=0.4, drop=1.2, rng=None, noise_hi=3000.0):
    """A struck skin: a sine falling in pitch, with a slap of noise."""
    dur = dur or decay * 5
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + drop * np.exp(-t * 45.0))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)
    if rng is not None and noise > 0:
        slap = lowpass(rng.standard_normal(n), noise_hi) * np.exp(-t / (decay * 0.18))
        body += slap * noise
    return body * ramp(n, 0.001 * SR)


def bell(freq, dur, rng=None):
    ratios = [0.56, 0.92, 1.19, 1.71, 2.0, 2.74, 3.0, 3.76, 4.07]
    amps = [1.0, 0.67, 1.0, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33]
    decays = [1.0, 0.9, 0.65, 0.55, 0.33, 0.25, 0.2, 0.15, 0.1]
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (d * dur * 0.45))
              for r, a, d in zip(ratios, amps, decays))
    return out * ramp(n, 0.001 * SR)


# ------------------------------------------------------------------ mixing

class Track:
    """A stereo buffer that notes are dropped into, by time in seconds."""

    def __init__(self, seconds):
        self.buf = np.zeros((2, int(seconds * SR) + SR * 8))

    def add(self, sound, at, gain=1.0, pan=0.0):
        start = int(at * SR)
        if start < 0:
            sound = sound[-start:]
            start = 0
        end = min(self.buf.shape[1], start + len(sound))
        if end <= start:
            return
        left = np.cos((pan + 1) * np.pi / 4)
        right = np.sin((pan + 1) * np.pi / 4)
        self.buf[0, start:end] += sound[:end - start] * gain * left
        self.buf[1, start:end] += sound[:end - start] * gain * right


def reverb(buf, seconds=2.2, wet=0.28, seed=5, tone=3500.0):
    """Convolve with a decaying burst of noise, a little different in each ear."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(buf)
    size = 1 << int(np.ceil(np.log2(buf.shape[1] + n)))
    for ch in range(2):
        ir = lowpass(rng.standard_normal(n), tone) * np.exp(-t * 6.9 / seconds)
        ir[: int(0.012 * SR)] = 0.0  # pre-delay
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        wetsig = np.fft.irfft(np.fft.rfft(buf[ch], size) * np.fft.rfft(ir, size), size)[: buf.shape[1]]
        out[ch] = buf[ch] * (1.0 - wet * 0.5) + wetsig * wet
    return out


def master(buf, loudness=-16.0, ceiling=0.95):
    """Bring a piece to a common loudness (RMS, in dBFS), rounding off any peaks that
    would pass the ceiling."""
    rms = np.sqrt(np.mean(buf ** 2)) + 1e-9
    buf = buf * (10 ** (loudness / 20.0) / rms)
    return np.tanh(buf / ceiling) * ceiling


def render_loop(name, length, score, wet=0.28, verb=2.2):
    """Play `score(track, offset)` three times over, add reverb, and keep the middle pass:
    whatever rings across its ends is exactly what rings across them when it loops."""
    track = Track(length * 3 + verb)
    for k in range(3):
        score(track, length * k)
    buf = reverb(track.buf, verb, wet, seed=len(name))
    loop = buf[:, int(length * SR): int(length * SR) + int(length * SR)]
    return master(loop)


def render_once(length, score, wet=0.25, verb=2.0):
    track = Track(length + verb)
    score(track, 0.0)
    buf = reverb(track.buf, verb, wet)[:, : int((length + verb * 0.8) * SR)]
    for ch in range(2):
        fade_out(buf[ch], 0.6 * SR)
    return master(buf, loudness=-15.0)


def write(path, buf, quality=3):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(buf, -1, 1)
    if data.ndim == 1:
        data = data[None, :]
    pcm = (data.T * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "wb") as w:
        w.setnchannels(data.shape[0])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality), path],
                   check=True)
    os.unlink(wav)
    print("wrote", os.path.relpath(path, os.path.join(HERE, "..")), "%.1fs" % (data.shape[1] / SR))


# ------------------------------------------------------------------ helpers for scores

def triad(root_midi, scale, degree):
    """The triad on `degree` of `scale` (semitone offsets), as MIDI notes from root_midi."""
    def note(d):
        octave, i = divmod(d, len(scale))
        return root_midi + scale[i] + 12 * octave
    return [note(degree), note(degree + 2), note(degree + 4)]


def play_line(track, line, start, beat, voice, gain, pan, rng, transpose=0):
    """A melody: [(midi or None, beats), ...] played by `voice(freq, seconds, rng)`."""
    t = start
    for midi, beats in line:
        if midi is not None:
            track.add(voice(hz(midi + transpose), beats * beat, rng), t, gain, pan)
        t += beats * beat
    return t


# ------------------------------------------------------------------ the pieces

D_DORIAN = [0, 2, 3, 5, 7, 9, 10]
D_MINOR = [0, 2, 3, 5, 7, 8, 10]


def vardish():
    """Vardmark: a ballad in three. Lute arpeggios over a hurdy-gurdy drone, a recorder
    sings the tune, a tabor keeps time. A, B, A again, then the lute alone."""
    bpm = 92
    beat = 60.0 / bpm
    bar = beat * 3
    # chord roots as scale degrees of D dorian (0 = Dm, 6 = C, 4 = Am, 2 = F, 3 = G)
    chords = [0, 6, 0, 4, 0, 2, 6, 0,
              2, 6, 0, 0, 2, 3, 4, 4,
              0, 6, 0, 4, 0, 2, 6, 0,
              0, 4, 0, 6, 0, 4, 3, 0]
    a = [(69, 1), (74, 1), (76, 1), (77, 1.5), (76, 0.5), (72, 1), (74, 2), (69, 1), (72, 1), (76, 1), (81, 1),
         (81, 1.5), (79, 0.5), (77, 1), (81, 1), (84, 1), (81, 1), (79, 1), (76, 1), (72, 1), (74, 3)]
    b = [(84, 1), (81, 1), (77, 1), (79, 1.5), (81, 0.5), (79, 1), (77, 1), (76, 1), (74, 1), (81, 3),
         (84, 1), (86, 1), (84, 1), (83, 1.5), (81, 0.5), (79, 1), (81, 1), (76, 1), (84, 1), (81, 3)]
    length = bar * len(chords)

    def lute(f, s, r):
        return pluck(f, max(s, 0.3) + 1.6, bright=0.55, decay=1.1, rng=r)

    def recorder(f, s, r):
        return wind(f, s * 0.96, breath=0.1, vib=0.005, rng=r)

    def score(tr, off):
        rng = rng_for("vardish")
        # drone, crossfading at each section so the loop never dips
        for sec in range(4):
            for m, g in ((38, 0.11), (45, 0.08)):
                tr.add(pad(hz(m), bar * 8 + 1.0, bright=0.5, attack=1.0, release=1.0, rng=rng),
                       off + sec * bar * 8 - 0.5, g, -0.2)
        for i, deg in enumerate(chords):
            t0 = off + i * bar
            notes = triad(50, D_DORIAN, deg)
            pattern = [notes[0], notes[2], notes[0] + 12, notes[1] + 12, notes[2], notes[0] + 12]
            for j, m in enumerate(pattern):
                tr.add(lute(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.008),
                       0.16 if j else 0.2, 0.25)
            if i < 24:
                tr.add(drum(110, 0.18, noise=0.5, rng=rng), t0, 0.22, -0.1)
                tr.add(drum(190, 0.06, noise=0.8, rng=rng, drop=0.3), t0 + beat * 2, 0.1, 0.1)
        play_line(tr, a, off, beat, recorder, 0.2, -0.15, rng)
        play_line(tr, b, off + bar * 8, beat, recorder, 0.2, -0.15, rng)
        play_line(tr, a, off + bar * 16, beat, recorder, 0.2, -0.15, rng)
        # the last section: the tune on the lute, an octave down, quietly
        play_line(tr, a, off + bar * 24, beat, lute, 0.15, 0.1, rng, transpose=-12)

    return render_loop("vardish", length, score)


D_HIJAZ = [0, 1, 4, 5, 7, 8, 10]


def kharzani():
    """Kharzan: maqam hijaz over the maqsum rhythm. The oud plays the tune with tremolo
    on its long notes, the ney answers, a drone holds the tonic and fifth."""
    bpm = 84
    beat = 60.0 / bpm
    bar = beat * 4
    a = [(62, 1), (63, 0.5), (66, 0.5), (67, 1), (66, 1), (63, 1), (62, 1), (62, 2),
         (69, 1), (67, 0.5), (66, 0.5), (67, 1), (69, 1), (70, 1), (69, 1), (69, 2),
         (72, 1), (70, 0.5), (69, 0.5), (70, 1), (69, 0.5), (67, 0.5), (66, 1), (67, 1), (69, 2),
         (67, 0.5), (66, 0.5), (63, 1), (66, 1), (63, 1), (62, 4)]
    b = [(69, 2), (70, 1), (69, 1), (67, 1), (69, 1), (70, 2), (72, 2), (74, 1), (72, 1), (70, 4),
         (69, 1), (70, 1), (72, 1), (74, 1), (75, 2), (74, 2), (72, 1), (70, 1), (69, 1), (67, 1), (69, 4)]
    hold = [(74, 8), (69, 8), (72, 4), (69, 4), (67, 4), (62, 4)]
    length = bar * 24

    def oud(f, s, r):
        if s >= beat * 1.9:
            # tremolo: the long note picked again and again
            reps = int(s / (beat / 4))
            out = np.zeros(int((s + 1.2) * SR))
            for k in range(reps):
                p = pluck(f, 0.5, bright=0.45, decay=0.35, glide=0.0, rng=r) * (0.75 + 0.25 * (k == 0))
                st = int(k * beat / 4 * SR)
                out[st:st + len(p)] += p[: len(out) - st]
            return out
        return pluck(f, s + 1.0, bright=0.45, decay=0.8, glide=-0.012, rng=r)

    def ney(f, s, r):
        return wind(f, s * 0.97, breath=0.35, vib=0.007, vib_rate=4.6, bend=-0.6, attack=0.12,
                    harm=(1.0, 0.25, 0.08, 0.03), rng=r)

    def score(tr, off):
        rng = rng_for("kharzani")
        for sec in range(3):
            for m, g in ((38, 0.1), (45, 0.06)):
                tr.add(pad(hz(m), bar * 8 + 1.0, bright=0.62, partials=16, attack=1.0, release=1.0, rng=rng),
                       off + sec * bar * 8 - 0.5, g, 0.0)
        # the maqsum: DUM tek . tek DUM . tek .
        for i in range(24):
            t0 = off + i * bar
            if i == 15:
                tr.add(drum(95, 0.3, noise=0.3, rng=rng), t0, 0.32, -0.1)
                continue
            for b_, kind in ((0, "D"), (0.5, "T"), (1.5, "T"), (2, "D"), (3, "T")):
                if kind == "D":
                    tr.add(drum(95, 0.22, noise=0.3, rng=rng, drop=0.8), t0 + b_ * beat, 0.3, -0.1)
                else:
                    tr.add(drum(420, 0.04, noise=1.0, rng=rng, drop=0.2, noise_hi=6000), t0 + b_ * beat, 0.09, 0.15)
        play_line(tr, a, off, beat, oud, 0.24, 0.2, rng)
        # B: the ney sings, the oud answers with low notes
        play_line(tr, b, off + bar * 8, beat, ney, 0.2, -0.2, rng)
        for i in range(8):
            tr.add(oud(hz(50 if i % 2 == 0 else 45), beat * 0.9, rng), off + (8 + i) * bar, 0.2, 0.2)
            tr.add(oud(hz(50), beat * 0.9, rng), off + (8 + i) * bar + beat * 2, 0.15, 0.2)
        play_line(tr, a, off + bar * 16, beat, oud, 0.24, 0.2, rng)
        play_line(tr, hold, off + bar * 16, beat, ney, 0.11, -0.25, rng)

    return render_loop("kharzani", length, score, wet=0.32, verb=2.6)


def ryumon():
    """The isles: koto figures in the in-scale, a shakuhachi bending into its long notes,
    taiko marking the sections and a wooden clap at the ends of phrases."""
    bpm = 66
    beat = 60.0 / bpm
    bar = beat * 4
    figures = {
        1: [52, 59, 64, 65, 64, 59, 57, 59],
        2: [57, 60, 64, 65, 64, 60, 59, 57],
        3: [53, 57, 60, 64, 60, 57, 53, 52],
        4: [52, 59, 64, 71, 69, 65, 64, 59],
    }
    order = [1, 1, 2, 1, 3, 2, 4, 1, 1, 2, 1, 3, 3, 2, 4, 1, 1, 3, 2, 1]
    a = [(71, 3), (69, 1), (71, 2), (72, 2), (71, 1), (69, 1), (65, 2), (64, 4),
         (69, 2), (71, 1), (72, 1), (76, 3), (72, 1), (71, 2), (69, 1), (65, 1), (64, 4)]
    b = [(76, 1), (72, 1), (71, 2), (69, 1), (71, 1), (72, 2), (71, 1), (69, 1), (65, 1), (64, 1), (65, 4),
         (69, 1), (71, 1), (76, 2), (77, 1), (76, 1), (72, 2), (71, 1), (72, 1), (69, 1), (65, 1), (64, 4)]
    length = bar * len(order)

    def koto(f, s, r):
        return pluck(f, max(s, 0.3) + 2.2, bright=0.72, decay=1.6, inharm=0.0006, rng=r)

    def koto_bend(f, s, r):
        return pluck(f, max(s, 0.3) + 2.2, bright=0.72, decay=1.6, inharm=0.0006, glide=-0.03, rng=r)

    def shakuhachi(f, s, r):
        return wind(f, s * 0.95, breath=0.4, vib=0.009, vib_rate=4.2, bend=-1.0, attack=0.18,
                    harm=(1.0, 0.18, 0.06, 0.02), rng=r)

    def score(tr, off):
        rng = rng_for("ryumon")
        for i, fig in enumerate(order):
            t0 = off + i * bar
            for j, m in enumerate(figures[fig]):
                tr.add(koto(hz(m), beat * 0.5, rng), t0 + j * beat * 0.5 + rng.uniform(0, 0.012),
                       0.12 if j else 0.15, 0.3)
            if i % 8 == 0:
                tr.add(drum(62, 0.5, noise=0.25, rng=rng, drop=0.6), t0, 0.45, 0.0)
            elif 8 <= i < 16 and i % 2 == 0:
                tr.add(drum(70, 0.35, noise=0.2, rng=rng, drop=0.5), t0, 0.22, 0.0)
            if i % 8 == 7:
                clap = band(rng.standard_normal(int(0.08 * SR)), 1200, 4000) * np.exp(-np.arange(int(0.08 * SR)) / SR / 0.015)
                tr.add(clap / (np.max(np.abs(clap)) + 1e-9), t0 + beat * 3, 0.2, -0.3)
                tr.add(clap / (np.max(np.abs(clap)) + 1e-9), t0 + beat * 3.5, 0.16, -0.3)
        play_line(tr, a, off, beat, shakuhachi, 0.2, -0.2, rng)
        play_line(tr, b, off + bar * 8, beat, koto_bend, 0.2, 0.05, rng)

    return render_loop("ryumon", length, score, wet=0.38, verb=3.0)


def title():
    """The Glass Sea: a horn over harp arpeggios and strings, D minor."""
    bpm = 72
    beat = 60.0 / bpm
    bar = beat * 4
    # roots per half bar: Dm Bb F C Dm Gm (Bb A) Dm
    chords = [[0, 0], [5, 5], [2, 2], [6, 6], [0, 0], [3, 3], [5, 4], [0, 0]] * 2
    horn1 = [(62, 1.5), (64, 0.5), (65, 1), (69, 1), (74, 2), (72, 1), (70, 1), (69, 3), (65, 1),
             (67, 2), (64, 2), (65, 1.5), (67, 0.5), (69, 1), (74, 1), (70, 2), (69, 1), (67, 1),
             (65, 1), (67, 1), (64, 1), (61, 1), (62, 4)]
    horn2 = [(69, 2), (74, 2), (77, 2), (76, 1), (74, 1), (72, 3), (69, 1), (67, 2), (72, 2),
             (69, 1.5), (70, 0.5), (72, 1), (74, 1), (74, 2), (70, 2), (69, 2), (73, 2), (74, 4)]
    length = bar * len(chords)

    def harp(f, s, r):
        return pluck(f, 2.4, bright=0.5, decay=1.5, rng=r)

    def horn(f, s, r):
        return brass(f, s * 0.97, attack=0.12, release=0.3, rng=r)

    def score(tr, off):
        rng = rng_for("title")
        for i, halves in enumerate(chords):
            for h, deg in enumerate(halves):
                t0 = off + i * bar + h * beat * 2
                notes = triad(50, D_MINOR, deg)
                if deg == 4:   # A major on the way home
                    notes = [57, 61, 64]
                for j, m in enumerate([notes[0], notes[1], notes[2], notes[1] + 12]):
                    tr.add(harp(hz(m + 12), beat * 0.5, rng), t0 + j * beat * 0.5, 0.12, 0.35)
                for m in notes:
                    tr.add(pad(hz(m), beat * 2 + 0.6, bright=0.45, attack=0.5, release=0.6, rng=rng),
                           t0 - 0.2, 0.06, -0.3)
                tr.add(pad(hz(notes[0] - 12), beat * 2 + 0.6, bright=0.4, attack=0.4, release=0.6, rng=rng),
                       t0 - 0.2, 0.09, 0.0)
        play_line(tr, horn1, off, beat, horn, 0.2, -0.1, rng)
        play_line(tr, horn2, off + bar * 8, beat, horn, 0.2, -0.1, rng)
        for i in (0, 8):
            tr.add(drum(55, 0.6, noise=0.2, rng=rng, drop=0.5), off + i * bar, 0.4, 0.0)

    return render_loop("title", length, score, wet=0.35, verb=2.8)


BATTLE_BPM = 132
BATTLE_BARS = 16


def battle(layer):
    """Battle, in two layers of the same length. Low: war drums and a driving ostinato.
    High: horns and snare rolls, faded in as more of the field is fighting."""
    beat = 60.0 / BATTLE_BPM
    bar = beat * 4
    roots = [38, 38, 34, 34, 36, 36, 33, 33] * 2
    horns = [(62, 1.5), (62, 0.5), (65, 1), (69, 1), (74, 3), (72, 1),
             (70, 1.5), (69, 0.5), (67, 1), (65, 1), (62, 4),
             (64, 1.5), (65, 0.5), (67, 1), (72, 1), (76, 3), (74, 1),
             (73, 2), (69, 2), (64, 2), (69, 2),
             (69, 1.5), (69, 0.5), (74, 1), (77, 1), (81, 3), (79, 1),
             (77, 1.5), (76, 0.5), (74, 1), (70, 1), (74, 4),
             (79, 1.5), (77, 0.5), (76, 1), (72, 1), (76, 3), (77, 1),
             (76, 2), (73, 2), (69, 4)]
    length = bar * BATTLE_BARS

    def horn(f, s, r):
        return brass(f, s * 0.92, attack=0.04, release=0.12, rng=r)

    def score(tr, off):
        rng = rng_for("battle_" + layer)
        for i, root in enumerate(roots):
            t0 = off + i * bar
            if layer == "low":
                for b_, f, g in ((0, 52, 0.55), (1.5, 52, 0.35), (2, 52, 0.45), (3, 80, 0.3), (3.5, 80, 0.25)):
                    tr.add(drum(f, 0.35 if f < 60 else 0.2, noise=0.35, rng=rng, drop=0.9), t0 + b_ * beat, g, 0.0)
                for k in range(8):
                    m = root + (12 if k in (2, 6) else 0) + (3 if k == 5 and root == 38 else 0)
                    note = pad(hz(m), beat * 0.42, bright=0.6, voices=2, attack=0.01, release=0.08, partials=14, rng=rng)
                    tr.add(note, t0 + k * beat * 0.5, 0.16, -0.15 if k % 2 else 0.15)
            else:
                if i % 2 == 1:
                    for k in range(8):
                        tr.add(drum(330, 0.05, noise=1.2, rng=rng, drop=0.1, noise_hi=7000),
                               t0 + beat * 3 + k * beat / 8, 0.05 + 0.02 * k, 0.2)
                tr.add(drum(200, 0.08, noise=1.0, rng=rng, drop=0.2, noise_hi=6000), t0 + beat, 0.12, 0.2)
                tr.add(drum(200, 0.08, noise=1.0, rng=rng, drop=0.2, noise_hi=6000), t0 + beat * 3, 0.12, 0.2)
        if layer == "high":
            play_line(tr, horns, off, beat, horn, 0.22, -0.1, rng)
            play_line(tr, horns, off, beat, horn, 0.12, 0.25, rng, transpose=-12)

    return render_loop("battle_" + layer, length, score, wet=0.22, verb=1.8)


def victory():
    rng = rng_for("victory")
    beat = 60.0 / 120

    def score(tr, off):
        t = 0.0
        for m, b in [(62, 0.5), (69, 0.5), (74, 0.5), (78, 1.5), (81, 3)]:
            tr.add(brass(hz(m), b * beat * 0.95, attack=0.04, release=0.4, rng=rng), off + t, 0.25, -0.1)
            tr.add(brass(hz(m - 12), b * beat * 0.95, attack=0.04, release=0.4, rng=rng), off + t, 0.12, 0.2)
            t += b * beat
        for m in (50, 57, 62, 66):
            tr.add(pad(hz(m), beat * 4, bright=0.5, attack=0.3, release=1.0, rng=rng), off + beat * 1.5, 0.08, 0.0)
        for k in range(12):
            tr.add(drum(70, 0.15, noise=0.4, rng=rng, drop=0.4), off + beat * 1.5 + k * beat / 6, 0.08 + k * 0.012, 0.0)
        tr.add(drum(55, 0.8, noise=0.3, rng=rng, drop=0.5), off + beat * 3, 0.5, 0.0)

    return render_once(beat * 6, score)


def defeat():
    rng = rng_for("defeat")
    beat = 60.0 / 60

    def score(tr, off):
        t = 0.0
        for m, b in [(62, 1), (60, 1), (58, 1), (57, 2.5)]:
            tr.add(brass(hz(m - 12), b * beat * 0.95, attack=0.15, release=0.6, rng=rng), off + t, 0.26, 0.0)
            t += b * beat
        for m in (38, 45):
            tr.add(pad(hz(m), beat * 5, bright=0.45, attack=1.0, release=1.5, rng=rng), off, 0.1, 0.0)
        tr.add(drum(50, 1.0, noise=0.3, rng=rng, drop=0.4), off, 0.5, 0.0)
        tr.add(drum(50, 1.0, noise=0.3, rng=rng, drop=0.4), off + beat * 3, 0.5, 0.0)

    return render_once(beat * 5.5, score)


# ------------------------------------------------------------------ sound effects

def sfx_click():
    rng = rng_for("click")
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    x = band(rng.standard_normal(n), 1500, 6000) * np.exp(-t / 0.006) * 0.6
    x += np.sin(2 * np.pi * 1400 * t) * np.exp(-t / 0.012) * 0.5
    return x


def sfx_coins():
    rng = rng_for("coins")
    n = int(0.6 * SR)
    x = np.zeros(n)
    t0 = 0.0
    for k in range(6):
        m = int(0.12 * SR)
        t = np.arange(m) / SR
        f = rng.uniform(2800, 4200)
        clink = sum(np.sin(2 * np.pi * f * r * t) * a for r, a in ((1.0, 1.0), (1.47, 0.6), (2.09, 0.35)))
        clink *= np.exp(-t / rng.uniform(0.03, 0.06)) * rng.uniform(0.5, 1.0)
        s = int(t0 * SR)
        x[s:s + m] += clink[: n - s]
        t0 += rng.uniform(0.04, 0.09)
    return x


def sfx_horn(notes=((50, 0.25), (57, 1.3))):
    rng = rng_for("horn")
    t = 0.0
    tr = Track(3.0)
    for m, d in notes:
        tr.add(brass(hz(m), d, attack=0.08, release=0.35, vib=0.006, rng=rng), t, 0.5, 0.0)
        tr.add(brass(hz(m + 12), d, attack=0.08, release=0.35, vib=0.006, rng=rng), t, 0.15, 0.0)
        t += d
    return reverb(tr.buf, 1.6, 0.3)[0, : int((t + 0.9) * SR)]


def sfx_clash(seed):
    rng = rng_for("clash%d" % seed)
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    x = band(rng.standard_normal(n), 900, 7000) * np.exp(-t / 0.03) * 0.8
    for k in range(5):
        f = rng.uniform(1100, 4800)
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / rng.uniform(0.04, 0.12)) * rng.uniform(0.2, 0.5)
    x += np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03) * 0.5   # the thud of the blow
    return x * ramp(n, 0.0005 * SR)


def sfx_arrows():
    """A volley: a rising rush of air, swept from high to low."""
    rng = rng_for("arrows")
    n = int(1.1 * SR)
    x = rng.standard_normal(n)
    out = np.zeros(n)
    hop = 512
    win = np.hanning(hop * 2)
    for s in range(0, n - hop * 2, hop):
        frac = s / n
        lo = 3800 - 2900 * frac
        out[s:s + hop * 2] += band(x[s:s + hop * 2] * win, lo, lo * 2.2)
    env = np.sin(np.pi * np.clip(np.arange(n) / n, 0, 1)) ** 1.5
    # a few close arrows, hissing past
    for k in range(5):
        st = int(rng.uniform(0.1, 0.8) * SR)
        m = int(0.12 * SR)
        hiss = band(rng.standard_normal(m), 3000, 9000) * np.hanning(m) * 0.5
        out[st:st + m] += hiss[: n - st]
    return out * env


def sfx_charge():
    """Hooves thundering in, then the crash of the charge."""
    rng = rng_for("charge")
    n = int(1.5 * SR)
    t = np.arange(n) / SR
    rumble = lowpass(rng.standard_normal(n), 220) * 3.0
    pulses = 0.55 + 0.45 * np.sin(2 * np.pi * 9.5 * t) ** 2
    env = np.clip(t / 0.9, 0, 1) ** 1.5
    x = rumble * pulses * env
    for k in range(14):
        st = int(rng.uniform(0.2, 1.1) * SR)
        thump = drum(rng.uniform(90, 140), 0.05, noise=0.6, rng=rng)[: n - st]
        x[st:st + len(thump)] += thump * 0.4 * (st / n)
    hit = sfx_clash(7)
    st = int(1.12 * SR)
    x[st:st + len(hit)] += hit[: n - st] * 1.4
    return fade_out(x, 0.1 * SR)


def sfx_rout():
    """A ragged shout of men breaking: noise through vowel formants, several voices."""
    rng = rng_for("rout")
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(6):
        f0 = rng.uniform(110, 190)
        src = np.sign(np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(3, 6) * t))) / SR))
        src = src * 0.3 + rng.standard_normal(n) * 0.4
        voice = band(src, 600, 1300) + band(src, 2300, 3000) * 0.4
        start = rng.uniform(0.0, 0.3)
        env = np.clip((t - start) / 0.12, 0, 1) * np.exp(-np.clip(t - start - 0.4, 0, None) / 0.35)
        out += voice * env * rng.uniform(0.6, 1.0)
    return out


def sfx_dice():
    rng = rng_for("dice")
    n = int(0.9 * SR)
    x = np.zeros(n)
    t0 = 0.0
    gap = 0.05
    for k in range(9):
        m = int(0.03 * SR)
        t = np.arange(m) / SR
        tick = band(rng.standard_normal(m), 1800, 7000) * np.exp(-t / 0.004)
        tick += np.sin(2 * np.pi * rng.uniform(2000, 3200) * t) * np.exp(-t / 0.01) * 0.4
        s = int(t0 * SR)
        x[s:s + m] += tick[: n - s] * (1.0 - k * 0.07)
        t0 += gap
        gap *= 1.22
    return x


def sfx_bell():
    rng = rng_for("bell")
    tr = Track(4.0)
    tr.add(bell(196.0, 3.5, rng), 0.0, 0.6, 0.0)
    return reverb(tr.buf, 2.2, 0.3)[0, : int(3.8 * SR)]


def sfx_hooves():
    """A loop of a horse trotting on a dirt road: two pairs of footfalls a second."""
    rng = rng_for("hooves")
    n = int(1.0 * SR)
    x = np.zeros(n)
    for at in (0.0, 0.12, 0.5, 0.62):
        clop = drum(rng.uniform(170, 210), 0.025, noise=0.9, rng=rng, drop=0.3, noise_hi=2500)
        clop = clop[: int(0.15 * SR)]
        s = int(at * SR)
        e = min(n, s + len(clop))
        x[s:e] += clop[: e - s] * rng.uniform(0.7, 1.0)
    return x


def sfx_page():
    """A soft rustle, for opening a sheet or a screen."""
    rng = rng_for("page")
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    return band(rng.standard_normal(n), 1500, 8000) * np.sin(np.pi * t / t[-1]) ** 2 * 0.5


def sfx_crossbow():
    """A mechanical latch release, tensioned twang and sharp thunk."""
    rng = rng_for("crossbow")
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    click = band(rng.standard_normal(n), 2000, 7000) * np.exp(-t / 0.006)
    twang = np.sin(2 * np.pi * 380.0 * np.exp(-t * 8.0) * t) * np.exp(-t / 0.08)
    thunk = drum(140.0, 0.03, noise=0.5, rng=rng)[:n]
    x = click * 0.8 + twang * 0.6 + thunk * 0.7
    return fade_out(x, int(0.05 * SR))


def sfx_water():
    """A soft, rushing water ripple for river fords."""
    rng = rng_for("water")
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    hiss = band(noise, 400, 3200)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * 1.5 * t)
    return lowpass(hiss * swell, 2400) * 0.5


def sfx_birds():
    """Gentle birds chirping in the canopy."""
    rng = rng_for("birds")
    n = int(1.5 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for at in (0.1, 0.35, 0.8, 1.05):
        m = int(0.12 * SR)
        chirp_t = np.arange(m) / SR
        f = np.linspace(rng.uniform(2800, 3600), rng.uniform(4200, 5200), m)
        sine = np.sin(2 * np.pi * f * chirp_t) * np.sin(np.pi * chirp_t / chirp_t[-1]) ** 2
        s = int(at * SR)
        e = min(n, s + m)
        out[s:e] += sine[:e - s] * 0.4
    return out


def sfx_objective():
    """A clear brass fanfare cue announcing an objective."""
    return sfx_horn(((62, 0.25), (65, 0.25), (69, 0.6)))


SFX = {
    "click": sfx_click, "coins": sfx_coins, "horn": sfx_horn,
    "alarm": lambda: sfx_horn(((57, 0.22), (57, 0.22), (62, 0.7))),
    "clash1": lambda: sfx_clash(1), "clash2": lambda: sfx_clash(2), "clash3": lambda: sfx_clash(3),
    "arrows": sfx_arrows, "charge": sfx_charge, "rout": sfx_rout, "dice": sfx_dice, "bell": sfx_bell,
    "hooves": sfx_hooves, "page": sfx_page,
    "crossbow": sfx_crossbow, "water": sfx_water, "birds": sfx_birds, "objective": sfx_objective,
}
MUSIC = {
    "title": title, "vardish": vardish, "kharzani": kharzani, "ryumon": ryumon,
    "battle_low": lambda: battle("low"), "battle_high": lambda: battle("high"),
    "victory": victory, "defeat": defeat,
}


def main(which):
    for name, fn in MUSIC.items():
        if which in ("all", "music", name):
            write(os.path.join(OUT, "music", name + ".ogg"), fn(), quality=3)
    for name, fn in SFX.items():
        if which in ("all", "sfx", name):
            x = fn()
            x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
            write(os.path.join(OUT, "sfx", name + ".ogg"), x, quality=4)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")
