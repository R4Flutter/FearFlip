"""Small offline DSP kit: load/save, BS.1770 loudness, true-peak limiter, filters, exciter, loop wrap."""
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100


def load(path, sr=SR):
    x, r = sf.read(path, always_2d=True, dtype="float64")
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = x[:, :2]
    if r != sr:
        g = np.gcd(r, sr)
        x = signal.resample_poly(x, sr // g, r // g, axis=0)
    return x


def save(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    if path.endswith(".mp3"):
        sf.write(path, x, sr, format="MP3", subtype="MPEG_LAYER_III", compression_level=0.45, bitrate_mode="CONSTANT")
    else:
        sf.write(path, x, sr, subtype="PCM_16")


# ---------- loudness (ITU-R BS.1770) ----------
def kweight(x, sr=SR):
    """BS.1770 K-weighting (libebur128 derivation, exact at 48 kHz and valid at other rates)."""
    K = np.tan(np.pi * 1681.974450955533 / sr)
    Q = 0.7071752369554196
    Vh = 10 ** (3.999843853973347 / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = np.array([Vh + Vb * K / Q + K * K, 2 * (K * K - Vh), Vh - Vb * K / Q + K * K]) / a0
    a1 = np.array([1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0])
    K = np.tan(np.pi * 38.13547087602444 / sr)
    Q = 0.5003270373238773
    a2 = np.array([1, 2 * (K * K - 1) / (1 + K / Q + K * K), (1 - K / Q + K * K) / (1 + K / Q + K * K)])
    return signal.lfilter([1, -2, 1], a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def _blocks(x, sr, win):
    k = kweight(x, sr)
    n, hop = int(win * sr), int(win * sr / 4)
    if len(k) < n:
        k = np.vstack([k, np.zeros((n - len(k), k.shape[1]))])
    p = np.array([(k[i:i + n] ** 2).mean(0).sum() for i in range(0, len(k) - n + 1, hop)])
    return p


def lufs(x, sr=SR):
    p = _blocks(x, sr, 0.4)
    l = -0.691 + 10 * np.log10(p + 1e-12)
    p = p[l > -70]
    if not len(p):
        return -70.0
    rel = -0.691 + 10 * np.log10(p.mean()) - 10
    p = p[-0.691 + 10 * np.log10(p) > rel]
    return -0.691 + 10 * np.log10(p.mean())


def momentary_max(x, sr=SR):
    return -0.691 + 10 * np.log10(_blocks(x, sr, 0.4).max() + 1e-12)


def true_peak_db(x):
    up = signal.resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(np.abs(up).max() + 1e-12)


# ---------- dynamics ----------
def limit(x, ceiling_db=-1.0, lookahead=0.005, release=0.08, sr=SR):
    """Look-ahead limiter (stereo linked): hold+ramp attack over the look-ahead, exponential release."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    ceil = 10 ** (ceiling_db / 20) * 0.98
    up = np.abs(signal.resample_poly(x, 4, 1, axis=0)).max(1)[:len(x) * 4]
    pk = np.maximum(np.abs(x).max(1), up.reshape(-1, 4).max(1))  # true-peak aware
    raw = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    la = max(2, int(lookahead * sr))
    g = uniform_filter1d(minimum_filter1d(raw, size=2 * la + 1), size=la)
    a = np.exp(-1 / (release * sr))
    out = np.empty_like(g)
    prev = 1.0
    for i, v in enumerate(g):  # ponytail: per-sample loop, ~1 s/min of audio; vectorize if it ever matters
        prev = v if v < prev else a * prev + (1 - a) * v
        out[i] = prev
    return x * out[:, None]


def normalize(x, target, measure="momentary", ceiling_db=-1.0, max_gr_db=3.0):
    """Gain to the loudness target, but never push peaks more than `max_gr_db` into the limiter."""
    cur = momentary_max(x) if measure == "momentary" else lufs(x)
    gain = min(target - cur, ceiling_db + max_gr_db - true_peak_db(x))
    y = x * 10 ** (gain / 20)
    if true_peak_db(y) > ceiling_db:
        y = limit(y, ceiling_db)
    return y


# ---------- filters / tone ----------
def hp(x, fc, order=2, sr=SR):
    return signal.sosfilt(signal.butter(order, fc, "hp", fs=sr, output="sos"), x, axis=0)


def lp(x, fc, order=2, sr=SR):
    return signal.sosfilt(signal.butter(order, fc, "lp", fs=sr, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2, sr=SR):
    return signal.sosfilt(signal.butter(order, [lo, hi], "bp", fs=sr, output="sos"), x, axis=0)


def lowshelf(x, fc, gain_db, sr=SR):
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / sr
    al = np.sin(w0) / (2 * 0.707)
    c = np.cos(w0)
    b = [A * ((A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al), 2 * A * ((A - 1) - (A + 1) * c),
         A * ((A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al)]
    a = [(A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al, -2 * ((A - 1) + (A + 1) * c),
         (A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def exciter(x, amount=0.5, xover=250, drive=4.0):
    """Psychoacoustic bass: saturate the low band, keep only the generated harmonics (audible on phone speakers)."""
    low = lp(x, xover, 4)
    h = np.tanh(drive * low / (np.abs(low).max() + 1e-9))
    h = bp(h, xover * 1.2, 3500, 2)
    h *= (np.sqrt((low ** 2).mean()) / (np.sqrt((h ** 2).mean()) + 1e-12))
    return x + amount * h


def width(x, amount=1.3):
    m, s = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
    s = s * amount
    return np.stack([m + s, m - s], 1)


# ---------- edits ----------
def trim(x, start_db=-50, end_db=-60, fade_in=0.002, fade_out=0.05, sr=SR):
    env = np.abs(x).max(1)
    pk = env.max()
    s = max(0, np.argmax(env > pk * 10 ** (start_db / 20)) - int(0.002 * sr))
    e = len(env) - np.argmax(env[::-1] > pk * 10 ** (end_db / 20))
    y = x[s:max(e, s + 1)].copy()
    return fades(y, fade_in, fade_out, sr)


def fades(y, fade_in, fade_out, sr=SR):
    y = y.copy()
    fi, fo = int(fade_in * sr), int(fade_out * sr)
    if fi:
        y[:fi] *= np.linspace(0, 1, fi)[:, None]
    if fo:
        y[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo))[:, None] ** 2
    return y


def loop_wrap(x, xfade=0.25, sr=SR):
    """Make a seamless loop: overlap-add the last `xfade` seconds onto the start (equal-power)."""
    n = int(xfade * sr)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    t = np.linspace(0, 1, n)[:, None]
    mixed = head * np.sin(t * np.pi / 2) + tail * np.cos(t * np.pi / 2)
    return np.vstack([mixed, body])


def mix(*layers):
    n = max(len(l) for l in layers)
    out = np.zeros((n, 2))
    for l in layers:
        out[:len(l)] += l
    return out


def db(v):
    return 10 ** (v / 20)


if __name__ == "__main__":  # self-check
    t = np.arange(5 * SR) / SR
    s = np.sin(2 * np.pi * 997 * t)
    ref = lufs(np.stack([s, np.zeros_like(s)], 1))
    assert abs(ref - -3.01) < 0.1, ref  # BS.1770 reference: 0 dBFS 997 Hz sine, one channel
    noisy = np.random.default_rng(0).normal(0, 0.5, (SR * 2, 2))
    lim = limit(noisy, -1.0)
    assert true_peak_db(lim) <= -0.9, true_peak_db(lim)
    lw = loop_wrap(np.stack([t[:SR], t[:SR]], 1), 0.1)
    assert len(lw) == SR - int(0.1 * SR)
    print("dsp ok", round(ref, 2), round(true_peak_db(lim), 2))
