"""Turn the raw ElevenLabs takes in raw/ into game-ready clips in assets/audio (same names the game loads).

Run: python tool/audio/build_sfx.py            (every clip)
     python tool/audio/build_sfx.py key_found.mp3 box_empty.mp3   (only those)"""
import os
import sys
from fractions import Fraction

import numpy as np
from scipy import signal
from dsp import *

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = lambda n: load(os.path.join(HERE, "raw", n + ".mp3"))
OUT = os.path.join(HERE, "..", "..", "assets", "audio")  # writes straight into the game
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def oneshot(x, target, fade_out=0.08, end_db=-55):
    x = hp(x, 30)
    x = trim(x, -45, end_db, 0.002, fade_out)
    return normalize(x, target)


def seamless(x, fn):
    """Apply `fn` to a loop without a seam: process 3 copies, keep the middle one."""
    n = len(x)
    return fn(np.vstack([x, x, x]))[n:2 * n]


def phone_whoosh(dur, f_from, f_to, peak_at=0.35):
    """Noise through a resonant band-pass sweeping down: the part of a whoosh a phone speaker can play."""
    n = int(dur * SR)
    noise = rng.normal(0, 1, (n, 2))
    fc = np.geomspace(f_from, f_to, n)
    out = np.zeros_like(noise)
    lo = bd = np.zeros(2)
    q = 0.35
    for i in range(n):  # Chamberlin state-variable filter, swept cutoff
        f = 2 * np.sin(np.pi * fc[i] / SR)
        hi = noise[i] - lo - q * bd
        bd = bd + f * hi
        lo = lo + f * bd
        out[i] = bd
    t = np.linspace(0, 1, n)
    env = np.where(t < peak_at, (t / peak_at) ** 2, np.exp(-(t - peak_at) * 6))
    return out * env[:, None] / (np.abs(out).max() + 1e-9)


def pitch(x, semitones):
    """Resample to shift pitch (and length) by `semitones`."""
    ratio = Fraction(2 ** (-semitones / 12)).limit_denominator(64)
    return signal.resample_poly(x, ratio.numerator, ratio.denominator, axis=0)


def place(x, seconds):
    """`x` starting `seconds` in."""
    return np.vstack([np.zeros((int(seconds * SR), 2)), x])


def bell(notes, decay=0.35, length=1.2):
    """Soft synthesized bell: (start_seconds, hz) partials with a fast attack and an exponential tail."""
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for start, hz in notes:
        tt = t - start
        on = tt >= 0
        env = np.where(on, (1 - np.exp(-np.maximum(tt, 0) * 400)) * np.exp(-np.maximum(tt, 0) / decay), 0)
        tone = np.sin(2 * np.pi * hz * tt) + 0.35 * np.sin(2 * np.pi * hz * 2.76 * tt) * np.exp(-np.maximum(tt, 0) * 6)
        out += (tone * env)[:, None] * 0.3
    return out


def build():
    clips = {}

    # World flip: sub thump (headphones) + swish/hit (phone speakers) + glassy shimmer on top
    low = trim(lp(RAW("flip"), 220, 4), -45, -60, 0.002, 0.1)
    mid = trim(bp(RAW("flip_c"), 220, 6000), -45, -60, 0.002, 0.08)
    top = trim(hp(RAW("flip_b"), 2500), -45, -60, 0.002, 0.1)
    flip = lowshelf(mix(exciter(low, 1.0), mid, top * db(-9)), 140, -5)
    clips["fahhhhh_flippingtime.mp3"] = oneshot(flip[:int(0.85 * SR)], -14, 0.15)

    # Devil near: continuous growl bed + raspy whispers, loudness-matched, gap-free loop
    a, b = RAW("devil_loop"), RAW("devil_loop_b")
    n = min(len(a), len(b))
    a, b = a[:n], b[:n]
    b = b * db(lufs(a) - lufs(b) - 1)

    def devil_chain(x):
        return exciter(lowshelf(hp(x, 38), 140, -4), 1.0, 200, 3.0)

    devil = seamless(a + b, devil_chain)
    clips["devil_approach.wav"] = normalize(devil, -15, "integrated")

    # Low time: ticking + pulse, seamless
    alarm = seamless(RAW("alarm_loop"), lambda x: hp(x, 70))
    clips["low_time_alarm.wav"] = normalize(alarm, -16, "integrated")

    # Maze walls shifting: rumble gets phone-audible harmonics
    clips["maze_shift_audio.mp3"] = oneshot(exciter(lowshelf(hp(RAW("maze_shift"), 38), 140, -6), 1.0), -12, 0.4)
    clips["safe_zone_sound.mp3"] = oneshot(RAW("safe_zone"), -15, 0.3)
    clips["winning_soundeffect.mp3"] = oneshot(RAW("win"), -12, 0.5, -60)
    clips["gamelost_soundeffect.mp3"] = oneshot(exciter(RAW("lose"), 0.3), -12, 0.5, -60)
    clips["glass_break.mp3"] = oneshot(RAW("crack"), -14, 0.08)

    # New trap cues (were faked with pitched-down copies of other clips)
    clips["trap_creak.mp3"] = oneshot(RAW("creak"), -18, 0.08)
    fall = lowshelf(mix(exciter(trim(RAW("fall"), -45, -60), 0.5), phone_whoosh(0.75, 2600, 380) * 0.8), 140, -6)
    clips["trap_fall.mp3"] = oneshot(fall, -14, 0.12)
    clips["trap_impact.mp3"] = oneshot(exciter(lowshelf(hp(RAW("impact"), 38), 140, -5), 1.2, 250, 5.0), -12, 0.2)

    # Key hunt. A lid creak, then a key's clink and a rising bell (C6 E6 G6): the reward.
    creak = trim(hp(RAW("creak"), 180), -45, -60, 0.002, 0.05)
    clink = trim(hp(pitch(RAW("metal_hit"), 7), 900), -45, -60, 0.001, 0.08)
    found = mix(creak[:int(0.28 * SR)] * db(-6), place(clink * db(-3), 0.12),
                place(bell([(0, 1047), (0.07, 1319), (0.14, 1568)], 0.32, 0.9), 0.16))
    clips["key_found.mp3"] = oneshot(found, -14, 0.25)
    # Empty: the lid's creak, lower, and a hollow breath of air.
    hollow = lp(phone_whoosh(0.55, 900, 220), 1800) * db(-8)
    clips["box_empty.mp3"] = oneshot(mix(pitch(creak, -3), place(hollow, 0.18)), -18, 0.15)
    # The exit opens: a heavy hit, a chain snapping and a bell rising an octave (C5 G5 C6).
    hit = lowshelf(hp(RAW("impact"), 38), 140, -4)
    snap = trim(hp(pitch(RAW("metal_hit"), -2), 400), -45, -60, 0.001, 0.1)
    unsealed = mix(hit[:int(1.1 * SR)] * db(-4), place(snap, 0.04),
                   place(bell([(0, 523), (0.12, 784), (0.24, 1047)], 0.5, 1.5), 0.1))
    clips["exit_unsealed.mp3"] = oneshot(unsealed, -12, 0.4)
    # Bump into the sealed exit: a dull iron clunk.
    clunk = trim(lp(pitch(RAW("metal_hit"), -9), 1800), -45, -60, 0.001, 0.08)
    clips["exit_sealed.mp3"] = oneshot(clunk[:int(0.45 * SR)], -16, 0.1)
    return clips


def report(name, x):
    ph = bp(x, 400, 10000)
    print(f"{name:28s} {len(x)/SR:6.2f}s  Mmax {momentary_max(x):6.1f}  I {lufs(x):6.1f}  TP {true_peak_db(x):5.1f}"
          f"  phone-band loss {momentary_max(x) - momentary_max(ph):5.1f} LU")


if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, x in build().items():
        if only and name not in only:
            continue
        save(os.path.join(OUT, name), x)
        report(name, load(os.path.join(OUT, name)))
