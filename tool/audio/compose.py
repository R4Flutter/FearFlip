"""FearFlip main theme (menu) + in-game bed.  Horror-action: D minor / Phrygian, 128 BPM.

A driving 16th-note string ostinato on a D pedal (with the b2 Eb stab), a heroic-but-sinister brass hook
(gallop pickup, leaps to A / Bb / D / Eb), pounding taiko, choir stabs, shrieking strings, a demonic scream.
Synth parts are rendered here; hits/instruments are ElevenLabs takes in raw/ (cello + horn are sampled and
re-pitched).  Run: python tool/audio/compose.py [theme|bed]  ->  assets/audio/menu_theme.mp3, background_audio.mp3
"""
import os
import numpy as np
from scipy import signal
from scipy.ndimage import uniform_filter1d
from dsp import *

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "audio")  # writes straight into the game
rng = np.random.default_rng(13)

BPM = 128
BEAT = 60 / BPM
BAR = 4 * BEAT


def at(bar, beat=0.0):
    """1-based bar (+ beat offset) -> sample index."""
    return int(round(((bar - 1) * BAR + beat * BEAT) * SR))


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def raw(name):
    return load(os.path.join(HERE, "raw", name + ".mp3"))


# ------------------------------------------------------------------ oscillators / helpers
def _blep(phase, dt):
    out = np.zeros_like(phase)
    m = phase < dt
    x = phase[m] / dt[m]
    out[m] = x + x - x * x - 1
    m = phase > 1 - dt
    x = (phase[m] - 1) / dt[m]
    out[m] = x * x + x + x + 1
    return out


def saw(freq, n, ph0=0.0):
    dt = np.broadcast_to(np.asarray(freq, float), (n,)) / SR
    phase = (ph0 + np.cumsum(dt)) % 1.0
    return 2 * phase - 1 - _blep(phase, dt)


def square(freq, n, ph0=0.0):
    return 0.5 * (saw(freq, n, ph0) - saw(freq, n, ph0 + 0.5))


def rel_curve(t, dur, rel):
    return np.clip(1 - (t - dur) / rel, 0, 1) ** 2


def pan(mono, p=0.0):
    th = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(th), mono * np.sin(th)], 1) * np.sqrt(2)


def repitch(x, semis):
    r = 2 ** (semis / 12)
    src = np.arange(int(len(x) / r)) * r
    return np.stack([np.interp(src, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], 1)


def peak1(x):
    return x / (np.abs(x).max() + 1e-12)


class Bus:
    def __init__(self, n):
        self.x = np.zeros((n, 2))

    def add(self, sig, start, gain=1.0, p=0.0):
        if sig.ndim == 1:
            sig = pan(sig, p)
        start += int(rng.normal(0, 0.0015) * SR) if start > 0 else 0  # tiny humanize
        start = max(0, start)
        end = min(len(self.x), start + len(sig))
        if end > start:
            k = min(len(sig), int(0.004 * SR))
            sig = sig.copy()
            sig[-k:] *= np.linspace(1, 0, k)[:, None]  # no truncation clicks at the end of any event
            self.x[start:end] += sig[:end - start] * gain


# ------------------------------------------------------------------ synth instruments
def brass(m, dur, vel=1.0, bright=4500.0, rel=0.18, grit=0.0):
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
    f = hz(m) * vib
    osc = 0.6 * saw(f, n) + 0.4 * saw(f * 1.0035, n, 0.3) + 0.5 * square(f * 0.5, n)
    e = np.clip(t / 0.04, 0, 1) * (0.55 + 0.45 * np.exp(-np.maximum(t - 0.04, 0) / 0.3))
    y = lp(osc, 650) * (1 - e) + lp(osc, bright) * e
    if grit:
        y = np.tanh((1 + 4 * grit) * y) / np.tanh(1 + 4 * grit)
    return y * np.clip(t / 0.02, 0, 1) * rel_curve(t, dur, rel) * vel


def pad(midis, dur, vel=1.0, attack=0.4, rel=0.9, cutoff=1900.0):
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for m in midis:
        for i, c in enumerate((-13, -6, 0, 6, 13)):
            out += pan(saw(hz(m) * 2 ** (c / 1200), n, rng.uniform()), (i - 2) * 0.4) * 0.2
    out = lp(out, cutoff)
    env = np.clip(t / attack, 0, 1) ** 1.5 * rel_curve(t, dur, rel)
    return out * env[:, None] * vel / np.sqrt(len(midis))


def tremolo(midis, dur, vel=1.0, rate=13.0, attack=0.6):
    """Shivering high string cluster (bowed tremolo) - the fear layer."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for j, m in enumerate(midis):
        for c in (-9, 0, 9):
            out += pan(saw(hz(m) * 2 ** (c / 1200), n, rng.uniform()), (j - 1) * 0.6) * 0.3
    out = hp(lp(out, 5500), 350)
    trem = (0.55 + 0.45 * np.sin(2 * np.pi * rate * t + rng.uniform(0, 6.28))) ** 2
    env = np.clip(t / attack, 0, 1) * rel_curve(t, dur, 0.5)
    return out * (trem * env)[:, None] * vel / np.sqrt(len(midis))


def pluck(m, dur, vel=1.0, cutoff=2000.0):
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    osc = 0.7 * saw(hz(m), n) + 0.6 * square(hz(m), n, 0.1)
    amp = np.clip(t / 0.002, 0, 1) * np.exp(-t * 11) * rel_curve(t, dur, 0.04)
    return lp(osc, cutoff) * amp * vel


def bass(m, dur, vel=1.0):
    n = int((dur + 0.05) * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * hz(m) * t) + 0.35 * lp(saw(hz(m), n), 900)
    amp = np.clip(t / 0.004, 0, 1) * (0.7 + 0.3 * np.exp(-t * 8)) * rel_curve(t, dur, 0.04)
    return np.tanh(1.4 * y) * amp * vel


def bell(m, vel=1.0, dur=4.5):
    """Church/funeral bell: hum, prime, minor-third tierce, quint, nominal... (why bells sound ominous)."""
    f, n = hz(m), int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for r, a, k in ((0.5, 0.45, 0.5), (1, 1.0, 0.8), (1.19, 0.5, 1.2), (1.5, 0.3, 1.5), (2.0, 0.45, 1.9),
                    (2.51, 0.22, 2.8), (2.66, 0.18, 3.2), (3.01, 0.15, 4.0), (4.07, 0.1, 6.0)):
        if f * r < 17000:
            y += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.28)) * np.exp(-t * k)
    y = y * (1 - np.exp(-t * 2000)) + 0.08 * hp(rng.normal(0, 1, n), 2500) * np.exp(-t * 180)
    return y * vel


def kick(vel=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 46 + 130 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    click = lp(hp(rng.normal(0, 1, n), 2000), 8000) * np.exp(-t * 250) * 0.25
    return np.tanh(2.0 * (body + click)) * vel


def hat(vel=1.0, open_=False):
    n = int((0.3 if open_ else 0.07) * SR)
    t = np.arange(n) / SR
    return lp(hp(rng.normal(0, 1, n), 7000, 4), 11000) * np.exp(-t * (11 if open_ else 60)) * vel * 0.5


def heartbeat(vel=1.0):
    def thump(f0, decay, amp):
        n = int(0.3 * SR)
        t = np.arange(n) / SR
        f = f0 * (1 + 0.6 * np.exp(-t * 30))
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay) * (1 - np.exp(-t * 600)) * amp

    a, b = thump(55, 0.08, 1.0), thump(48, 0.1, 0.75)
    off = int(0.17 * SR)
    y = np.zeros(off + len(b))
    y[:len(a)] += a
    y[off:] += b
    return lp(np.tanh(2.2 * y), 900) * vel


# ------------------------------------------------------------------ ElevenLabs takes
def _cut(x, end_db=-60):
    return trim(hp(x, 30), -50, end_db, 0.001, 0.05)


def _to_peak(x):
    """Cut a swell so it ends exactly at its loudest point (it then lands on a downbeat)."""
    e = uniform_filter1d(np.abs(x).max(1), int(0.02 * SR))
    return fades(x[:int(np.argmax(e)) + 1], 0.02, 0.015)


TAIKO_LO = peak1(_cut(raw("taiko_low")))
TAIKO_HI = peak1(_cut(raw("taiko_high")))
SNARE = peak1(_cut(raw("snare")))
CRASH = peak1(_cut(raw("cymbal")))
REVCYM = peak1(hp(CRASH[::-1], 400))
BRAAM = peak1(_cut(raw("braam")))  # F1 fundamental: sits on Dm/Bb
BOOM = peak1(_cut(raw("boom")))
METAL = peak1(_cut(raw("metal_hit")))
TICK = peak1(hp(_cut(raw("tick")), 500))
_r = _cut(raw("riser"), -70)
_e = np.abs(_r).max(1)
RISER = peak1(fades(_r[:len(_e) - np.argmax(_e[::-1] > _e.max() * 0.25)], 0.01, 0.01))  # up to the abrupt stop
SCREECH = peak1(fades(_cut(raw("screech"))[int(0.55 * SR):], 0.05, 0.3))
SCREAM = peak1(_cut(raw("scream")))
SCREAM_REV = peak1(fades(SCREAM[::-1], 0.05, 0.01))
STRINGS_RISE = peak1(_to_peak(_cut(raw("strings_rise"))))
AMB = loop_wrap(raw("ambience"), 0.5)  # the take's own loop point clicks; crossfade it
WHISPER = peak1(bp(raw("devil_loop_b")[:int(4.6 * SR)], 900, 6500))
CELLO = peak1(_cut(raw("cello")))  # staccato G2, 98.5 Hz
HORN = peak1(_cut(raw("horn")))  # horn section G3, 196 Hz

# choir: one sustained "ah" at 137.3 Hz -> looped sustain, re-pitched per chord tone
_c = raw("choir")[int(0.25 * SR):int(2.45 * SR)]
_xf = int(0.5 * SR)
_loop = _c
for _ in range(3):
    _loop = np.vstack([_loop[:-_xf], _loop[-_xf:] * np.linspace(1, 0, _xf)[:, None] + _c[:_xf] * np.linspace(0, 1, _xf)[:, None], _c[_xf:]])
CHOIR_SRC = peak1(_loop)


def sampled(src, src_hz, m, dur, vel=1.0, rel=0.12, attack=0.0):
    y = repitch(src, 12 * np.log2(hz(m) / src_hz))
    n = min(len(y), int((dur + rel) * SR))
    t = np.arange(n) / SR
    env = rel_curve(t, dur, rel) * (np.clip(t / attack, 0, 1) if attack else 1.0)
    return y[:n] * env[:, None] * vel


def cello(m, vel=1.0):
    return sampled(CELLO, 98.5, m, 0.16, vel, 0.05)


def horn(m, dur, vel=1.0):
    return sampled(HORN, 196.0, m, dur, vel, 0.15)


def choir(m, dur, vel=1.0, attack=0.3, rel=0.7):
    return sampled(CHOIR_SRC, 137.3, m, dur, vel, rel, attack)


def taiko(lo=True, vel=1.0):
    return repitch(TAIKO_LO if lo else TAIKO_HI, rng.normal(0, 0.25)) * vel


# ------------------------------------------------------------------ space / dynamics
def make_ir(rt=2.4, length=3.2, pre=0.02):
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        nz = rng.normal(0, 1, n)
        ir[:, c] = (lp(nz, 500) * np.exp(-6.91 * t / (rt * 1.25)) + bp(nz, 500, 4000) * np.exp(-6.91 * t / rt)
                    + hp(nz, 4000) * np.exp(-6.91 * t / (rt * 0.45)))
    ir *= np.clip(t / 0.03, 0, 1)[:, None]
    for _ in range(12):  # early reflections
        ir[int(rng.uniform(0.004, 0.07) * SR), rng.integers(2)] += rng.uniform(1.5, 3.5)
    ir = np.vstack([np.zeros((int(pre * SR), 2)), ir])
    return ir / np.sqrt((ir ** 2).sum(0).mean())


def reverb(x, ir):
    return np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1)


def pingpong(x, d=0.75 * BEAT, fb=0.38, taps=6):
    n, D = len(x), int(d * SR)
    src = bp(x.mean(1), 280, 3800)
    out = np.zeros((n, 2))
    for k in range(1, taps + 1):
        if k * D >= n:
            break
        out[k * D:, (k - 1) % 2] += src[:n - k * D] * fb ** (k - 1)
    return out


def duck_env(n, hits, depth_db=-4.0, rel=0.12):
    env = np.ones(n)
    seg = int(0.5 * SR)
    t = np.arange(seg) / SR
    g = 1 - (1 - db(depth_db)) * np.clip(t / 0.004, 0, 1) * np.exp(-np.maximum(t - 0.004, 0) / rel)
    for h in hits:
        k = max(0, min(seg, n - h))
        env[h:h + k] = np.minimum(env[h:h + k], g[:k])
    return env


def glue(x, ratio=2.0, att=0.02, rel=0.25, pct=75):
    p = (x ** 2).mean(1)
    hop = 64
    lvl = 10 * np.log10(uniform_filter1d(p, int(0.01 * SR))[::hop] + 1e-12)
    thresh = np.percentile(lvl[lvl > lvl.max() - 40], pct)
    target = np.minimum(0, (thresh - lvl) * (1 - 1 / ratio))
    aa, ar = np.exp(-hop / (att * SR)), np.exp(-hop / (rel * SR))
    g, prev = np.empty_like(target), 0.0
    for i, v in enumerate(target):
        a = aa if v < prev else ar
        prev = a * prev + (1 - a) * v
        g[i] = prev
    return x * db(np.interp(np.arange(len(p)), np.arange(len(g)) * hop, g))[:, None]


def highshelf(x, fc, gain_db):
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / SR
    al = np.sin(w0) / (2 * 0.707)
    c = np.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c),
         (A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def peak_eq(x, fc, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / SR
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b = [1 + al * A, -2 * c, 1 - al * A]
    a = [1 + al / A, -2 * c, 1 - al / A]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def master(x, target_lufs, pre_s=10.0):
    """Master a loop without a seam: process with wrap-around pre-roll so compressor/limiter state is continuous."""
    P, Q = int(pre_s * SR), int(1.0 * SR)
    y = np.vstack([x[-P:], x, x[:Q]])
    y = glue(highshelf(lowshelf(peak_eq(hp(y, 28), 380, -1.5, 0.8), 90, -1.5), 5000, 2.5), 1.8, pct=80)
    y = normalize(y, target_lufs, "integrated", -1.0, 4.0)
    return y[P:P + len(x)]


def wrap(x, length):
    """Fold everything past `length` (reverb/delay tails) back onto the start so the file loops cleanly."""
    y = x[:length].copy()
    tail = x[length:]
    y[:len(tail)] += tail[:length]
    return y


# ------------------------------------------------------------------ music
VOICING = {"Dm": [50, 53, 57, 62], "Bb": [46, 50, 53, 58], "Gm": [43, 50, 55, 58], "A": [45, 52, 57, 61],
           "Eb": [51, 55, 58, 63]}
ROOT = {"Dm": 38, "Bb": 34, "Gm": 31, "A": 33, "Eb": 39}
CHOIR_V = {"Dm": [45, 50, 53], "Bb": [46, 50, 53], "Gm": [46, 50, 55], "A": [45, 49, 52], "Eb": [46, 51, 55]}
# 16th ostinato on a D pedal (Eb / A when the harmony demands); 3-3-2 accents; the b2 stab at step 14
OST_ROOT = {"Dm": 38, "Bb": 38, "Gm": 38, "A": 45, "Eb": 39}
OST_OFFS = [0, 0, 12, 0, 0, 12, 0, 12, 0, 0, 12, 0, 0, 12, 1, 7]
OST_ACC = {0, 3, 6, 8, 11, 14}
HOOK_PROG = ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "Eb", "A"]

# The hook: (midi, beat, beats).  Gallop pickup (D-D) into a leap that climbs bar by bar: A, Bb, D, ... Eb (the b9 shock).
HOOK = [(62, 0, .75), (62, .75, .25), (69, 1, 1), (67, 2, .5), (65, 2.5, .5), (64, 3, .5), (65, 3.5, .5),
        (62, 4, .75), (62, 4.75, .25), (70, 5, 1), (69, 6, .75), (67, 6.75, .25), (69, 7, 1),
        (62, 8, .75), (62, 8.75, .25), (74, 9, 1), (72, 10, .5), (70, 10.5, .5), (69, 11, .5), (67, 11.5, .5),
        (69, 12, 2), (64, 14, .5), (65, 14.5, .5), (67, 15, .5), (68, 15.5, .5),
        (62, 16, .75), (62, 16.75, .25), (69, 17, 1), (67, 18, .5), (65, 18.5, .5), (64, 19, .5), (65, 19.5, .5),
        (62, 20, .75), (62, 20.75, .25), (70, 21, 1), (69, 22, .75), (67, 22.75, .25), (69, 23, 1),
        (62, 24, .75), (62, 24.75, .25), (75, 25, 1.5), (74, 26.5, .5), (72, 27, .5), (70, 27.5, .5),
        (69, 28, 1), (73, 29, 1), (74, 30, 2)]
HOOK_A = [n for n in HOOK if n[1] < 16]
HOOK_B = [(m, b - 16, d) for m, b, d in HOOK if b >= 16]

PROG = []
RESOLVE = set()  # bars where the answer phrase lands on D at beat 2 (A -> Dm mid-bar)


def chord_at(bar, beat=0.0):
    return "Dm" if bar in RESOLVE and beat >= 2 else PROG[bar - 1]


def play_melody(bus, notes, bar0, inst, transpose=0, vel=1.0, p=0.0):
    for m, b, d in notes:
        bus.add(inst(m + transpose, d * BEAT, vel), at(bar0, b), p=p)


def chords(bus, bars, cutoff, vel=1.0, attack=0.4):
    for bar in bars:
        if bar in RESOLVE:
            bus.add(pad(VOICING["A"], BAR / 2, vel, attack, 0.5, cutoff), at(bar))
            bus.add(pad(VOICING["Dm"], BAR / 2, vel, 0.15, 0.9, cutoff), at(bar, 2))
        else:
            bus.add(pad(VOICING[chord_at(bar)], BAR, vel, attack, 0.9, cutoff), at(bar))


def choir_pad(bus, bars, vel):
    for bar in bars:
        halves = ((0, "A", 0.5), (2, "Dm", 0.5)) if bar in RESOLVE else ((0, chord_at(bar), 1.0),)
        for b, c, frac in halves:
            for m in CHOIR_V[c]:
                bus.add(choir(m, BAR * frac, vel), at(bar, b))


def choir_stab(bus, bar, vel=1.0):
    for m in CHOIR_V[chord_at(bar)]:
        bus.add(choir(m, 0.3, vel, 0.008, 0.35), at(bar))


def ostinato(syn, cel, bars, cut_from, cut_to, vel=1.0, step=0.25, use_cello=True):
    for i, bar in enumerate(bars):
        for k in range(int(4 / step)):
            beat = k * step
            idx = int(round(beat / 0.25))
            c = chord_at(bar, beat)
            m = OST_ROOT[c] + OST_OFFS[idx]
            v = vel * (1.0 if idx in OST_ACC else 0.6)
            frac = (i + beat / 4) / max(1, len(bars))
            syn.add(pluck(m, step * BEAT * 0.85, v, cut_from * (cut_to / cut_from) ** frac), at(bar, beat),
                    p=0.25 if k % 2 else -0.25)
            if use_cello and OST_OFFS[idx] in (0, 1, 7):
                cel.add(cello(m, v), at(bar, beat), p=-0.2)


def bassline(bus, bars, vel=1.0):
    for bar in bars:
        for k in range(8):
            bus.add(bass(ROOT[chord_at(bar, k * 0.5)], BEAT * 0.42, vel * (1.0 if k % 2 == 0 else 0.7)),
                    at(bar, k * 0.5))


def taiko_roll(bus, bar, beat_from, beat_to, v0=0.3, v1=1.0):
    steps = int((beat_to - beat_from) / 0.25)
    for k in range(steps):
        bus.add(taiko(k % 2 == 0, v0 + (v1 - v0) * k / max(1, steps - 1)), at(bar, beat_from + k * 0.25),
                p=-0.3 if k % 2 else 0.3)


def pulse(B, kicks, bar, vel=1.0, snare=(1, 3), hats=0.5, fill=False, metal=False, till=4.0):
    """Four-on-the-floor heartbeat kick + taiko 3-3-2 + snare + hats.  `till` cuts the bar short (suck-out)."""
    for b in (0, 1, 2, 3):
        if b < till:
            B["drums"].add(kick(0.85 * vel), at(bar, b))
            kicks.append(at(bar, b))
    for b in snare:
        if b < till:
            B["drums"].add(SNARE * 0.85 * vel, at(bar, b))
    for b in (0, 1.5, 3):
        if b < till:
            B["drums"].add(taiko(True, (0.95 if b == 0 else 0.7) * vel), at(bar, b), p=0.15)
    if fill:
        for b in (3, 3.25, 3.5, 3.75):
            if b < till:
                B["drums"].add(taiko(False, 0.65 * vel), at(bar, b), p=-0.3)
    for i in range(int(4 / hats)):
        b = i * hats
        if b < till:
            B["drums"].add(hat((0.8 if b % 1 == 0 else 0.5) * vel), at(bar, b), p=0.4)
    if metal and 2.5 < till:
        B["drums"].add(METAL * 0.6 * vel, at(bar, 2.5), p=-0.5)


def big_hit(B, kicks, bar, beat=0, braam=True):
    if braam:
        B["fx"].add(BRAAM, at(bar, beat), 0.9)
    B["fx"].add(BOOM, at(bar, beat), 0.9)
    B["fx"].add(CRASH, at(bar, beat), 0.8, p=0.2)
    B["drums"].add(taiko(True, 1.0), at(bar, beat))
    B["drums"].add(kick(1.0), at(bar, beat))
    kicks.append(at(bar, beat))


def into(B, bar, riser=True, scream=False, strings=False):
    """Swells that land exactly on the downbeat of `bar`."""
    B["fx"].add(REVCYM, at(bar) - len(REVCYM), 0.6)
    if riser:
        B["fx"].add(RISER, at(bar) - len(RISER), 0.5)
    if scream:
        B["horror"].add(SCREAM_REV, at(bar) - len(SCREAM_REV), 0.8)
    if strings:
        B["horror"].add(STRINGS_RISE, at(bar) - len(STRINGS_RISE), 0.8)


def ticks(B, bars, vel=0.6):
    for bar in bars:
        for k in range(8):
            B["heart"].add(TICK * vel * (1.0 if k % 2 == 0 else 0.7), at(bar, k * 0.5), p=0.5 if k % 2 else -0.5)


STEMS = ("lead", "ost", "cello", "pad", "choir", "strings", "bass", "drums", "heart", "fx", "horror", "bell", "amb")


# ------------------------------------------------------------------ arrangements
def theme():
    PROG[:] = (["Dm", "Dm", "Eb", "A"] + HOOK_PROG + HOOK_PROG + ["Dm", "Eb", "Dm", "A"] + HOOK_PROG
               + ["Dm", "Bb", "Eb", "A"] + ["Dm", "Dm", "Eb", "A"])
    RESOLVE.clear()
    RESOLVE.update({12, 20, 32, 36})
    L = at(len(PROG) + 1)
    B = {k: Bus(L + int(6 * SR)) for k in STEMS}
    K = []

    # 1-4  cold open: the hit, the ostinato starts at once, the pulse races in, strings shiver, a shriek
    big_hit(B, K, 1)
    ostinato(B["ost"], B["cello"], range(1, 5), 900, 2600, 1.15, use_cello=False)
    for bar in range(1, 5):
        B["bass"].add(bass(ROOT[chord_at(bar)], BAR * 0.98, 0.4), at(bar))
    chords(B["pad"], range(1, 5), 1300, 0.7)
    for i, bar in enumerate(range(2, 5)):
        for b in range(4):
            B["drums"].add(kick(0.5 + 0.15 * i), at(bar, b))
            K.append(at(bar, b))
    ticks(B, range(1, 5), 0.55)
    B["strings"].add(tremolo([74, 75, 81], 2 * BAR, 0.8), at(3))
    B["horror"].add(SCREECH, at(4), 0.75)
    taiko_roll(B["drums"], 4, 2, 4, 0.3, 0.9)
    into(B, 5, riser=False)

    # 5-12  theme A: low horns announce the hook over the pounding groove
    play_melody(B["lead"], HOOK, 5, horn, -12, 1.45)
    play_melody(B["lead"], HOOK, 5, lambda m, d, v: brass(m, d, v, 2600), -12, 0.65)
    play_melody(B["lead"], HOOK, 5, lambda m, d, v: brass(m, d, v, 4200), 0, 0.45)
    ostinato(B["ost"], B["cello"], range(5, 13), 2600, 3400, 0.85)
    chords(B["pad"], range(5, 13), 2400, 0.85)
    bassline(B["bass"], range(5, 13), 0.7)
    for bar in range(5, 13):
        pulse(B, K, bar, 0.8, snare=(2,), hats=0.25, fill=bar % 2 == 0, till=4.0 if bar != 12 else 2.0)
    for bar in (5, 7, 9, 11):
        choir_stab(B["choir"], bar, 0.9)
    B["fx"].add(CRASH, at(9), 0.6, p=-0.2)
    taiko_roll(B["drums"], 12, 2, 4, 0.4, 1.0)
    into(B, 13)

    # 13-20  theme B: the hook up an octave on brass, choir, shivering strings, full drums
    big_hit(B, K, 13, braam=False)
    play_melody(B["lead"], HOOK, 13, lambda m, d, v: brass(m, d, v, 4800, grit=0.3), 0, 1.0)
    play_melody(B["lead"], HOOK, 13, horn, -12, 0.8)
    play_melody(B["lead"], HOOK, 13, lambda m, d, v: brass(m, d, v, 6500), 12, 0.25)
    ostinato(B["ost"], B["cello"], range(13, 21), 3000, 3600, 1.0)
    chords(B["pad"], range(13, 21), 3500, 1.0)
    choir_pad(B["choir"], range(13, 21), 0.5)
    for bar in range(13, 21):
        choir_stab(B["choir"], bar, 0.7)
    bassline(B["bass"], range(13, 21))
    B["strings"].add(tremolo([74, 75, 81], 8 * BAR, 0.7, attack=2.0), at(13))
    for bar in range(13, 21):
        pulse(B, K, bar, 1.0, snare=(1, 3), hats=0.25, fill=True, metal=True, till=4.0 if bar != 20 else 3.0)
    B["fx"].add(CRASH, at(17), 0.6, p=-0.2)
    into(B, 17, riser=False)

    # 21-24  fear break: the floor drops - heartbeat, clock, funeral bells, whispers, the scream
    B["horror"].add(SCREAM, at(21), 0.7, p=0.3)
    B["fx"].add(BOOM, at(21), 0.7)
    ostinato(B["ost"], B["cello"], range(21, 25), 650, 900, 0.75, step=0.5, use_cello=False)
    chords(B["pad"], range(21, 25), 900, 0.6)
    for bar in range(21, 25):
        B["bass"].add(bass(ROOT[chord_at(bar)], BAR * 0.98, 0.45), at(bar))
        for b in (0, 2):
            B["heart"].add(heartbeat(1.0), at(bar, b))
        B["bell"].add(bell(50, 0.9), at(bar))
        B["bell"].add(bell(57, 0.5), at(bar, 2), p=0.4)
    ticks(B, range(21, 25), 0.7)
    B["amb"].add(WHISPER, at(21, 1), p=-0.6)
    B["amb"].add(WHISPER[::-1] * 0.7, at(23), p=0.6)
    B["strings"].add(tremolo([74, 75, 80], 4 * BAR, 0.75, rate=16.0, attack=6.0), at(21))
    B["horror"].add(SCREECH, at(24), 0.8)
    taiko_roll(B["drums"], 24, 0, 3.5, 0.15, 1.0)
    into(B, 25, scream=True, strings=True)

    # 25-36  climax: everything, the hook in three octaves, braams, choir, backbeat, a 4-bar tag
    big_hit(B, K, 25)
    for notes, bar0 in ((HOOK, 25), (HOOK_B, 33)):
        play_melody(B["lead"], notes, bar0, lambda m, d, v: brass(m, d, v, 5200, grit=0.5), 0, 1.0)
        play_melody(B["lead"], notes, bar0, horn, -12, 0.9)
        play_melody(B["lead"], notes, bar0, lambda m, d, v: brass(m, d, v, 7000), 12, 0.35)
    ostinato(B["ost"], B["cello"], range(25, 37), 3600, 4200, 1.05)
    chords(B["pad"], range(25, 37), 4500, 1.0)
    choir_pad(B["choir"], range(25, 37), 0.65)
    for bar in range(25, 37):
        choir_stab(B["choir"], bar, 0.8)
    bassline(B["bass"], range(25, 37))
    B["strings"].add(tremolo([74, 75, 81, 86], 12 * BAR, 0.8, attack=1.0), at(25))
    for bar in range(25, 36):
        pulse(B, K, bar, 1.15, snare=(1, 3), hats=0.25, fill=True, metal=True)
        if bar % 4 == 0:
            for k in range(4):
                B["drums"].add(SNARE * (0.4 + 0.15 * k), at(bar, 3 + k * 0.25))
    for bar in (27, 29, 31, 35):
        B["fx"].add(CRASH, at(bar), 0.6, p=0.2 if bar % 4 == 3 else -0.2)
    big_hit(B, K, 33)
    into(B, 33, riser=False)
    big_hit(B, K, 36, 2, braam=False)  # lands with the final D
    B["drums"].add(kick(0.9), at(36))

    # 37-40  run-out: the ostinato and the racing pulse alone, then everything sucks back into the top
    ostinato(B["ost"], B["cello"], range(37, 41), 2800, 1500, 1.1)
    for bar in range(37, 41):
        B["bass"].add(bass(ROOT[chord_at(bar)], BAR * 0.98, 0.45), at(bar))
        for b in range(4):
            B["drums"].add(kick(0.7 + 0.05 * (bar - 37)), at(bar, b))
            K.append(at(bar, b))
    chords(B["pad"], range(37, 41), 1300, 0.75)
    ticks(B, range(37, 41), 0.6)
    B["horror"].add(SCREECH, at(39), 0.6, p=-0.3)
    taiko_roll(B["drums"], 40, 1, 4, 0.2, 1.0)
    into(B, 41, scream=True, strings=True)  # = bar 1 of the next loop
    return B, L, K


def bed():
    """In-game loop: the same pulse and hook, held down low and dark so the game's SFX stay on top."""
    PROG[:] = ["Dm", "Dm", "Eb", "Dm", "Dm", "Bb", "Gm", "A", "Dm", "Dm", "Eb", "A", "Dm", "Bb", "Eb", "A"]
    RESOLVE.clear()
    L = at(len(PROG) + 1)
    B = {k: Bus(L + int(6 * SR)) for k in STEMS}
    X = int(2 * SR)
    amb = np.vstack([AMB] * (L // len(AMB) + 2))[:L + X].copy()
    amb[:X] *= np.sin(np.linspace(0, np.pi / 2, X))[:, None]  # wrap() folds the faded tail over this
    amb[-X:] *= np.cos(np.linspace(0, np.pi / 2, X))[:, None]
    B["amb"].add(amb, 0)
    ostinato(B["ost"], B["cello"], range(1, 17), 850, 1400, 0.7, step=0.5, use_cello=False)
    chords(B["pad"], range(1, 17), 900, 0.75)
    for bar in range(1, 17):
        B["bass"].add(bass(ROOT[chord_at(bar)], BAR * 0.98, 0.6), at(bar))
        B["heart"].add(heartbeat(0.8), at(bar))
        B["heart"].add(heartbeat(0.55), at(bar, 2))
    play_melody(B["lead"], HOOK_A, 5, horn, -12, 0.8)
    for bar in range(9, 17):
        B["bell"].add(bell(50, 0.7), at(bar))
    B["strings"].add(tremolo([74, 75, 81], 4 * BAR, 0.6, attack=3.0), at(13))
    B["amb"].add(WHISPER * 0.6, at(11), p=-0.6)
    B["drums"].add(taiko(True, 0.7), at(1))
    B["drums"].add(taiko(True, 0.6), at(9))
    return B, L, []


# loudness each stem should sit at where it is featured (bars) - or, with None, at its loudest moment
THEME_BAL = {"lead": ((13, 20), -13.2), "ost": ((13, 20), -19.5), "cello": ((13, 20), -22), "pad": ((13, 20), -22.5),
             "choir": ((13, 20), -21.5), "strings": ((13, 20), -26), "bass": ((13, 20), -21.5),
             "drums": ((13, 20), -16), "heart": ((21, 24), -22.5), "fx": (None, -11.5), "horror": (None, -14),
             "bell": ((21, 24), -22.5), "amb": ((21, 24), -26)}
BED_BAL = {"lead": ((5, 8), -21), "ost": ((1, 16), -22.5), "pad": ((1, 16), -24.5), "strings": ((13, 16), -28),
           "bass": ((1, 16), -26.5), "drums": (None, -20), "heart": ((1, 16), -25), "bell": ((9, 16), -24),
           "amb": ((1, 16), -25)}
STEM_HP = {"ost": 110, "cello": 75, "pad": 120, "choir": 120, "strings": 300, "bell": 60, "lead": 90}
SENDS = {"lead": (0.28, 0.12), "ost": (0.10, 0.0), "cello": (0.15, 0.0), "pad": (0.35, 0.0), "choir": (0.45, 0.0),
         "strings": (0.40, 0.0), "bass": (0.0, 0.0), "drums": (0.14, 0.0), "heart": (0.10, 0.0),
         "fx": (0.22, 0.0), "horror": (0.35, 0.0), "bell": (0.5, 0.2), "amb": (0.3, 0.0)}


def render(B, L, kicks_at, bal, target):
    ir = make_ir()
    N = len(B["pad"].x)
    duck = duck_env(N, kicks_at)
    stems = {}
    for k, (bars, lvl) in bal.items():
        x = B[k].x
        if not np.any(x):
            continue
        if k in ("pad", "ost", "bass", "choir", "strings"):
            x = x * duck[:, None]
        if k in STEM_HP:
            x = hp(x, STEM_HP[k])
        cur = momentary_max(x) if bars is None else lufs(x[at(bars[0]):at(bars[1] + 1)])
        stems[k] = x * db(lvl - cur)
    send = sum(stems[k] * SENDS[k][0] for k in stems)
    dly = sum(pingpong(stems[k]) * SENDS[k][1] for k in stems if SENDS[k][1])
    wet = reverb(send + dly * 0.5, ir) * db(-4)
    mix_ = sum(stems.values()) + dly + wet
    return master(wrap(mix_, L), target), stems


def overview(x, path, bars):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(16, 6), sharex=True)
    m = x.mean(1)
    t = np.arange(len(m)) / SR
    a1.plot(t[::20], m[::20], lw=0.3)
    a2.specgram(m, NFFT=2048, Fs=SR, noverlap=1536, cmap="magma", vmin=-110)
    a2.set_ylim(0, 8000)
    for b in range(1, bars + 2):
        for a in (a1, a2):
            a.axvline((b - 1) * BAR, color="w" if a is a2 else "k", lw=0.4 if (b - 1) % 4 else 1.0, alpha=0.6)
    fig.tight_layout()
    fig.savefig(path, dpi=60)


def section_report(x, sections):
    for name, (a, b) in sections.items():
        seg = x[at(a):at(b + 1)]
        print(f"  {name:10s} bars {a:2d}-{b:2d}  {lufs(seg):6.1f} LUFS")


THEME_SECTIONS = {"cold open": (1, 4), "theme A": (5, 12), "theme B": (13, 20), "fear break": (21, 24),
                  "climax": (25, 36), "run-out": (37, 40)}

if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["theme", "bed"]
    if "theme" in which:
        B, L, k = theme()
        x, _ = render(B, L, k, THEME_BAL, -14.0)
        save(os.path.join(OUT, "menu_theme.mp3"), x)
        print(f"menu_theme  {len(x)/SR:.1f}s  I {lufs(x):.1f}  TP {true_peak_db(x):.1f}")
        section_report(x, THEME_SECTIONS)
        pass
    if "bed" in which:
        B, L, k = bed()
        x, _ = render(B, L, k, BED_BAL, -16.0)
        save(os.path.join(OUT, "background_audio.mp3"), x)
        print(f"background  {len(x)/SR:.1f}s  I {lufs(x):.1f}  TP {true_peak_db(x):.1f}")
        pass
