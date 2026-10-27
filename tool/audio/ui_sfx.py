"""Synthesises the menu and pickup sounds into assets/audio/ui/.

Run: python3 tool/audio/ui_sfx.py   (needs numpy and ffmpeg)

Every sound is built from sines, noise and envelopes here, so there is
nothing to license. Dark-fantasy palette: bells, wood and stone.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio', 'ui')


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack=0.004, decay=0.2):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / max(decay, 1e-4))


def bell(freq, seconds=0.6, decay=0.18, bright=1.0):
    x = t(seconds)
    partials = [(1.0, 1.0), (2.76, 0.45 * bright), (5.40, 0.22 * bright), (8.93, 0.08 * bright)]
    s = sum(a * np.sin(2 * np.pi * freq * r * x) * np.exp(-x / (decay / (1 + r * 0.25))) for r, a in partials)
    return s * env(len(x), 0.002, decay * 2)


def noise(seconds, color=0.0):
    n = np.random.default_rng(3).standard_normal(int(SR * seconds))
    if color > 0:
        # simple one-pole low-pass for darker noise
        y = np.zeros_like(n)
        for i in range(1, len(n)):
            y[i] = y[i - 1] + (1 - color) * (n[i] - y[i - 1])
        n = y / (np.max(np.abs(y)) + 1e-9)
    return n


def place(total, clip, at):
    start = int(at * SR)
    end = min(len(total), start + len(clip))
    total[start:end] += clip[: end - start]
    return total


def finish(x, peak=0.85):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        with wave.open(tmp.name, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dst = os.path.join(OUT, name + '.mp3')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp.name, '-codec:a', 'libmp3lame',
                        '-b:a', '96k', dst], check=True)
    os.unlink(tmp.name)
    print('wrote', dst, os.path.getsize(dst), 'bytes')


def click():
    x = t(0.09)
    thump = np.sin(2 * np.pi * 140 * x * np.exp(-x * 30)) * env(len(x), 0.001, 0.03)
    tick = noise(0.09, 0.6) * env(len(x), 0.0005, 0.012) * 0.6
    return finish(thump + tick, 0.7)


def wisp():
    total = np.zeros(int(SR * 0.5))
    place(total, bell(1318, 0.45, 0.10), 0)
    place(total, bell(1976, 0.4, 0.09) * 0.7, 0.05)
    shimmer = noise(0.3) * env(int(SR * 0.3), 0.01, 0.06) * 0.08
    place(total, shimmer * np.sin(2 * np.pi * 7000 * t(0.3)), 0.02)
    return finish(total, 0.6)


def coins():
    total = np.zeros(int(SR * 0.9))
    for i, f in enumerate([1046, 1318, 1568, 2093]):
        place(total, bell(f, 0.5, 0.12), i * 0.06)
    return finish(total, 0.75)


def star(step):
    base = [1046, 1318, 1568][step]
    total = np.zeros(int(SR * 0.8))
    place(total, bell(base, 0.7, 0.22, 1.2), 0)
    place(total, bell(base * 2, 0.5, 0.12) * 0.4, 0.01)
    whoosh = noise(0.25, 0.3) * env(int(SR * 0.25), 0.05, 0.05) * 0.15
    place(total, whoosh, 0)
    return finish(total, 0.8)


def chest():
    total = np.zeros(int(SR * 1.3))
    x = t(0.18)
    thunk = np.sin(2 * np.pi * 90 * x * np.exp(-x * 8)) * env(len(x), 0.002, 0.06)
    place(total, thunk, 0)
    creak = np.sin(2 * np.pi * (300 + 120 * np.sin(2 * np.pi * 9 * t(0.3))) * t(0.3)) * env(int(SR * 0.3), 0.05, 0.12) * 0.25
    place(total, creak, 0.05)
    for i, f in enumerate([784, 988, 1175, 1568, 1976, 2349]):
        place(total, bell(f, 0.5, 0.1) * 0.8, 0.28 + i * 0.05)
    return finish(total, 0.8)


def denied():
    total = np.zeros(int(SR * 0.35))
    for i, f in enumerate([220, 165]):
        x = t(0.14)
        tone = np.sign(np.sin(2 * np.pi * f * x)) * 0.4 + np.sin(2 * np.pi * f * x)
        place(total, tone * env(len(x), 0.003, 0.06), i * 0.12)
    return finish(total, 0.5)


def purchase():
    total = np.zeros(int(SR * 1.0))
    place(total, coins()[: int(SR * 0.6)], 0)
    place(total, bell(2637, 0.6, 0.2) * 0.6, 0.22)
    return finish(total, 0.8)


def powerup():
    x = t(0.6)
    f = 300 + 900 * (x / x[-1]) ** 1.5
    phase = 2 * np.pi * np.cumsum(f) / SR
    sweep = (np.sin(phase) + 0.3 * np.sin(2 * phase)) * env(len(x), 0.02, 0.35)
    total = np.zeros(int(SR * 0.9))
    place(total, sweep * 0.6, 0)
    place(total, bell(1568, 0.5, 0.15), 0.42)
    place(total, bell(2093, 0.4, 0.12) * 0.7, 0.48)
    return finish(total, 0.75)


def shield():
    x = t(0.7)
    clang = sum(np.sin(2 * np.pi * f * x) * np.exp(-x / d) for f, d in [(523, 0.3), (1307, 0.18), (2240, 0.1), (3517, 0.06)])
    hit = noise(0.7, 0.2) * env(len(x), 0.0005, 0.02)
    return finish(clang * env(len(x), 0.001, 0.5) + hit * 0.5, 0.75)


def swoosh():
    x = t(0.32)
    n = noise(0.32, 0.4)
    e = np.sin(np.pi * x / x[-1]) ** 2
    return finish(n * e, 0.35)


def levelup():
    total = np.zeros(int(SR * 1.6))
    for i, f in enumerate([523, 659, 784, 1046]):
        place(total, bell(f, 0.9, 0.25, 1.3), i * 0.11)
    place(total, bell(1568, 1.0, 0.4, 1.3) * 0.8, 0.5)
    return finish(total, 0.85)


if __name__ == '__main__':
    write('click', click())
    write('wisp', wisp())
    write('coins', coins())
    for i in range(3):
        write('star%d' % (i + 1), star(i))
    write('chest', chest())
    write('denied', denied())
    write('purchase', purchase())
    write('powerup', powerup())
    write('shield', shield())
    write('swoosh', swoosh())
    write('levelup', levelup())
