"""Cut the delivered 2D art (fearflip_assets.zip) into game-ready strips.

    python -I tool/process_2d_assets.py <fearflip_assets.zip | extracted folder> [out_dir]

Needs Pillow, numpy and scipy (Anaconda ships all three). Writes PNG strips to
assets/images/2d/ (default): every strip is one row of equal frames, the layout
MazeArt (lib/presentation/gameplay/maze_art.dart) reads. Re-run it whenever the
art is re-delivered; the crop boxes below are measured on the Oct 2026 delivery.

The delivery is painted (Nano Banana) art on fake backdrops: a drawn checkerboard,
plain white, a blue sky or dark gutters. Each source gets the keying it needs.
"""
import io
import os
import sys
import zipfile

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2

TILE = 128  # one maze tile in the atlases
RIM = 20  # capstone rim thickness on a wall top, px of TILE
FACE = 48  # rock-face height under a wall top that has floor below, px of TILE

# ── loading ─────────────────────────────────────────────────────────────────

_src = {}


def load_sources(path):
    if os.path.isdir(path):
        for dp, _, fs in os.walk(path):
            for f in fs:
                if f.lower().endswith('.png'):
                    _src[f] = os.path.join(dp, f)
    else:
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if n.lower().endswith('.png'):
                    _src[n.replace('\\', '/').split('/')[-1]] = z.read(n)


def rgb(name):
    s = _src[name]
    im = Image.open(io.BytesIO(s) if isinstance(s, bytes) else s)
    a = np.asarray(im.convert('RGB')).astype(np.float32)
    return unwatermark(a) if name in WATERMARKED else a


# Sources whose generator ✦ mark lands on art we keep (it sits ~38 px in from
# the bottom-right corner). Elsewhere it falls on backdrop that is keyed away.
WATERMARKED = {'obj_start.png', 'obj_exit.png', 'extra_devil_eyes_exit.png',
               'floor_wake_extra.png', 'floor_nightmare_extra.png', 'fx_debris.png'}


def unwatermark(a, r=70):
    """Cover the bottom-right r×r corner with the patch just left of it."""
    h, w = a.shape[:2]
    a = a.copy()
    a[h - r:h, w - r:w] = a[h - r:h, w - 2 * r:w - r]
    return a


# ── keying ──────────────────────────────────────────────────────────────────


def backdrop_tones(a, frame=10):
    """The two colours of a drawn checkerboard, from the image's outer frame."""
    border = np.concatenate([a[:frame].reshape(-1, 3), a[-frame:].reshape(-1, 3),
                             a[:, :frame].reshape(-1, 3), a[:, -frame:].reshape(-1, 3)])
    grey = border[border.max(1) - border.min(1) < 30]  # art touching the border is colourful
    c, _ = kmeans2(grey if len(grey) > 200 else border, 2, minit='++', seed=1)
    return c if c[0].mean() <= c[1].mean() else c[::-1]


def checker_bg(a, tol=16, enclosed=False, min_enclosed=900, flat=False, t_max=1.15):
    """Backdrop mask: pixels on the colour line between the two checker tones,
    connected to the border (plus enclosed checker patches when asked).
    [flat]: only untextured pixels seed it (checker squares are flat, painted
    stone isn't), then it grows into the soft edges between squares."""
    c0, c1 = backdrop_tones(a)
    d = c1 - c0
    t = ((a - c0) @ d) / max(float(d @ d), 1.0)
    dist = np.linalg.norm(a - (c0 + np.clip(t, 0, 1)[..., None] * d), axis=2)
    cand = (dist < tol) & (t > -0.15) & (t < t_max)
    seed = cand
    if flat:
        lum = a.mean(2)
        std = np.sqrt(np.maximum(ndimage.uniform_filter(lum * lum, 3) - ndimage.uniform_filter(lum, 3) ** 2, 0))
        # flat squares plus the thin seams between them; textured paint stays out
        seed = cand & ndimage.binary_dilation(cand & (std < 3), iterations=2)
    lab, n = ndimage.label(seed)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    if enclosed:
        for i, s in enumerate(ndimage.sum(seed, lab, range(1, n + 1)), 1):
            if s >= min_enclosed and i not in edge:
                tt = t[lab == i]
                # a checker patch holds both tones (the light one dimmed when shadowed)
                if (tt < 0.35).mean() > 0.15 and (tt > 0.5).mean() > 0.15:
                    bg |= lab == i
    return bg


def drop_islands(bg, min_island):
    """Specks of unkeyed backdrop become backdrop."""
    lab, n = ndimage.label(~bg)
    if n == 0:
        return bg
    sizes = ndimage.sum(~bg, lab, range(1, n + 1))
    small = np.isin(lab, [i for i, s in enumerate(sizes, 1) if s < min_island])
    return bg | small


def alpha_from_bg(bg, feather=0.8):
    solid = ndimage.binary_erosion(bg, iterations=2)
    alpha = ndimage.gaussian_filter(1.0 - bg.astype(np.float32), feather)
    alpha[solid] = 0
    return alpha


def rgba(colour, alpha):
    return np.dstack([np.clip(colour, 0, 255), np.clip(alpha * 255, 0, 255)]).astype(np.uint8)


def key_hard(a, tol=16, enclosed=False, min_island=120, min_enclosed=900, flat=False,
             thin=0, t_max=1.15):
    """Hard-edged art (icons, frames, pads) on a drawn checkerboard.
    [thin]: also drop leftover lines up to ~2*thin px wide (checker seams)."""
    bg = drop_islands(checker_bg(a, tol, enclosed, min_enclosed, flat, t_max), min_island)
    if thin:
        bg = ~ndimage.binary_opening(~bg, iterations=thin)
    return rgba(a, alpha_from_bg(bg))


def checker_model(a):
    """Per-pixel backdrop colour of a regular drawn checkerboard: square size and
    phase fitted on the busiest of the top rows / left columns."""
    c0, c1 = backdrop_tones(a)
    lum = a.mean(2)
    mid = (c0.mean() + c1.mean()) / 2

    def fit(lines):
        best = max(lines, key=lambda p: np.abs(np.diff(p > mid)).sum())
        on = best > mid
        edges = np.flatnonzero(on[1:] != on[:-1]) + 1
        p0 = np.median(np.diff(edges))
        k = np.round((edges - edges[0]) / p0)
        p, e0 = np.polyfit(k, edges, 1)
        return e0, p

    x0, px = fit([lum[r] for r in range(16)])
    y0, py = fit([lum[:, c] for c in range(16)])
    h, w = lum.shape
    i = np.floor((np.arange(w) - x0) / px).astype(int)
    j = np.floor((np.arange(h) - y0) / py).astype(int)
    parity = (j[:, None] + i[None, :]) % 2
    cx, cy = int(x0 + px / 2) % w, int(y0 + py / 2) % h
    light_parity = parity[cy, cx] if lum[cy, cx] > mid else 1 - parity[cy, cx]
    return np.where((parity == light_parity)[..., None], c1, c0)


def key_glow_model(a, gain=1.6, floor=35):
    """Light-emitting FX on a big-squared checker: subtract the fitted checker
    (its brighter neighbour at square edges), keep the excess light above
    [floor] (the faint halo was blended over the squares and can't be undone)."""
    back = ndimage.maximum_filter(checker_model(a), size=(5, 5, 1))
    excess = np.clip(a - back, 0, 255)
    alpha = np.clip((excess.max(2) - floor) / (255.0 - floor) * gain, 0, 1)
    alpha = ndimage.gaussian_filter(alpha, 0.8)
    colour = np.where(alpha[..., None] > 0.01, excess * gain / np.maximum(alpha[..., None], 0.01), 0)
    return rgba(colour, alpha)


def key_red(a):
    """The red crack-light of the flip FX, without the stone slab under it."""
    red = np.clip((a[..., 0] - np.maximum(a[..., 1], a[..., 2]) - 25) / 110.0, 0, 1)
    hot = np.clip((a.min(2) - 205) / 45.0, 0, 1)  # the white-hot centre
    alpha = ndimage.gaussian_filter(np.maximum(red, hot), 0.7)
    return rgba(a, alpha)


def key_glow(a, gain=1.5):
    """Light-emitting FX (sparkles, wisps) on a darker checker: keep only the
    light above the checker's bright tone, as straight alpha."""
    _, c1 = backdrop_tones(a)
    excess = np.clip(a - c1, 0, 255)
    alpha = np.clip(excess.max(2) / 255.0 * gain, 0, 1)
    alpha = ndimage.gaussian_filter(alpha, 0.7)
    colour = np.where(alpha[..., None] > 0.01, excess * gain / np.maximum(alpha[..., None], 0.01), 0)
    return rgba(colour, alpha)


def key_dark(a, gain=1.25):
    """Dark FX (smoke) on a lighter checker: opacity is how far a pixel sits
    below the checker's dark tone."""
    c0, _ = backdrop_tones(a)
    ref = c0.mean()
    lum = a.mean(2)
    alpha = np.clip((ref - lum) / ref * gain, 0, 1)
    alpha = ndimage.gaussian_filter(alpha, 0.6)
    colour = np.where(alpha[..., None] > 0.02,
                      (a - (1 - alpha[..., None]) * ref) / np.maximum(alpha[..., None], 0.02), 0)
    return rgba(colour, alpha)


def key_light(a, protect=None, gain=1.6):
    """Colour-to-alpha against a white/light-grey backdrop, but only inside the
    light area that touches the border, so pale parts of the art stay solid.
    [protect] marks pixels that must stay opaque (e.g. flame cores)."""
    bg_lum = float(np.median(np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3)]).min(1)))
    light = a.min(2) > bg_lum - 90
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    region = ndimage.binary_dilation(np.isin(lab, list(edge)), iterations=2)
    ca = np.clip(np.clip((bg_lum - a) / max(bg_lum, 1.0), 0, 1).max(2) * gain, 0, 1)
    alpha = np.where(region, ca, 1.0)
    if protect is not None:
        alpha = np.maximum(alpha, protect.astype(np.float32))
    a3 = alpha[..., None]
    colour = np.where(a3 > 0.02, (a - (1 - a3) * bg_lum) / np.maximum(a3, 0.02), 0)
    colour = np.where(protect[..., None], a, colour) if protect is not None else colour
    return rgba(colour, alpha)


def key_sky(a):
    """White puffs on a blue sky: opacity from how far red rises above the sky."""
    base = float(np.median(a[..., 0][a[..., 2] - a[..., 0] > 60]))
    alpha = np.clip((a[..., 0] - base - 20) / (235 - base), 0, 1)
    lum = np.clip(a.mean(2) * 1.05, 0, 255)
    return rgba(np.dstack([lum, lum, lum]), alpha)


def largest_only(t):
    """Single-object art: keep the biggest opaque blob (and what it encloses)."""
    solid = t[..., 3] > 25
    lab, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        keep = ndimage.binary_fill_holes(lab == 1 + int(np.argmax(sizes)))
        keep = ndimage.binary_dilation(keep, iterations=2)  # its soft edge
        t = t.copy()
        t[..., 3] = np.where(keep, t[..., 3], 0)
    return t


def only_saturated(t, lo=25, span=35):
    """Blood FX: grey leftovers of the backdrop fade out, red stays."""
    c = t[..., :3].astype(np.float32)
    keep = np.clip((c.max(2) - c.min(2) - lo) / span, 0, 1)
    t = t.copy()
    t[..., 3] = (t[..., 3] * keep).astype(np.uint8)
    return t


# ── cutting ─────────────────────────────────────────────────────────────────


def crop(arr, box):
    x0, y0, x1, y1 = box
    return arr[y0:y1 + 1, x0:x1 + 1]


def centre_square(arr):
    h, w = arr.shape[:2]
    s = min(h, w)
    y, x = (h - s) // 2, (w - s) // 2
    return arr[y:y + s, x:x + s]


def to_img(arr):
    if arr.dtype != np.uint8:
        arr = np.clip(arr, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def resized(arr, w, h):
    return to_img(arr).resize((w, h), Image.LANCZOS)


def content_boxes(alpha, min_area=400, gap=6):
    """Bounding boxes of opaque blobs, nearby blobs merged, left to right."""
    mask = ndimage.binary_dilation(alpha > 0.1, iterations=gap)
    lab, n = ndimage.label(mask)
    out = []
    for sl in ndimage.find_objects(lab):
        ys, xs = sl
        if (ys.stop - ys.start) * (xs.stop - xs.start) >= min_area:
            out.append((xs.start + gap, ys.start + gap, xs.stop - 1 - gap, ys.stop - 1 - gap))
    return sorted(out, key=lambda b: (b[0]))


def fit_frames(frames, w, h, pad=0.06, anchor='centre'):
    """Scale every frame by one shared factor (so sizes stay relative) and
    place it in a w×h cell."""
    sizes = [(f.shape[1], f.shape[0]) for f in frames]
    k = min((w * (1 - 2 * pad)) / max(s[0] for s in sizes), (h * (1 - 2 * pad)) / max(s[1] for s in sizes))
    out = []
    for f in frames:
        im = to_img(f)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        cell = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        x = (w - im.width) // 2
        y = (h - im.height) // 2 if anchor == 'centre' else h - im.height - round(h * pad)
        cell.alpha_composite(im.convert('RGBA'), (x, y))
        out.append(cell)
    return out


def align(frames):
    """Shift frames 1..n onto frame 0 (phase correlation on grey), so a looping
    animation doesn't jitter. Frames are equal-size uint8 arrays."""
    ref = frames[0][..., :3].mean(2)
    out = [frames[0]]
    F = np.fft.fft2(ref - ref.mean())
    for f in frames[1:]:
        g = f[..., :3].mean(2)
        cross = F * np.conj(np.fft.fft2(g - g.mean()))
        peak = np.fft.ifft2(cross / (np.abs(cross) + 1e-9)).real
        dy, dx = np.unravel_index(np.argmax(peak), ref.shape)
        dy = dy - ref.shape[0] if dy > ref.shape[0] // 2 else dy
        dx = dx - ref.shape[1] if dx > ref.shape[1] // 2 else dx
        if abs(dx) > 16 or abs(dy) > 16:
            dx = dy = 0
        out.append(np.roll(np.roll(f, dy, axis=0), dx, axis=1))
    return out


def strip(cells):
    w, h = cells[0].size
    out = Image.new('RGBA', (w * len(cells), h), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.alpha_composite(c.convert('RGBA'), (i * w, 0))
    return out


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def opaque_frames(name, boxes, size=TILE, do_align=False):
    """Full-tile frames (dark gutters between them): crop, square, resize."""
    a = rgb(name)
    side = min(min(b[2] - b[0], b[3] - b[1]) for b in boxes) + 1
    frames = []
    for b in boxes:
        cx, cy = (b[0] + b[2]) // 2, (b[1] + b[3]) // 2
        frames.append(a[cy - side // 2:cy - side // 2 + side, cx - side // 2:cx - side // 2 + side].astype(np.uint8))
    if do_align:
        frames = align(frames)
        # trim the wrapped border the shifts may have rolled in
        m = 14
        frames = [f[m:-m, m:-m] for f in frames]
    return [resized(f, size, size).convert('RGBA') for f in frames]


# ── tiles ───────────────────────────────────────────────────────────────────

FLOOR_COLS = [(23, 188), (193, 342), (347, 513), (519, 684)]
WAKE_FLOOR = [(x0, y0, x1, y1) for (y0, y1) in [(386, 564), (570, 753)] for (x0, x1) in FLOOR_COLS]
NIGHT_FLOOR = ([(x0, 14, x1, 192) for (x0, x1) in FLOOR_COLS[:3]]
               + [(x0, 198, x1, 381) for (x0, x1) in FLOOR_COLS[:3]]
               + [(x0, 386, x1, 564) for (x0, x1) in FLOOR_COLS]
               + [(x0, 570, x1, 753) for (x0, x1) in FLOOR_COLS])
# clean floors first (the gore ones show up as extras)
NIGHT_FLOOR_CLEAN = [NIGHT_FLOOR[i] for i in (0, 1, 2, 3, 7, 8)]
NIGHT_FLOOR_GORE = [NIGHT_FLOOR[i] for i in (6, 9)]  # flesh, bones


def tile_from(a, box):
    return resized(centre_square(crop(a, box)).astype(np.uint8), TILE, TILE).convert('RGBA')


def cold(img, amount=0.35):
    """Pull olive/green moss towards cold slate (the art direction bans green)."""
    a = np.asarray(img).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    greenish = np.clip((g - (r + b) / 2) / 20.0, 0, 1) * amount
    grey = (r + g + b) / 3
    a[..., 0] = r + (grey * 0.95 - r) * greenish
    a[..., 1] = g + (grey * 0.97 - g) * greenish
    a[..., 2] = b + (grey * 1.12 - b) * greenish
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA' if a.shape[2] == 4 else 'RGB')


def match_tone(img, refs, amount=0.75):
    """Shift an image's per-channel mean/spread towards the reference tiles'."""
    a = np.asarray(img).astype(np.float32)
    ref = np.stack([np.asarray(r).astype(np.float32)[..., :3] for r in refs])
    mean, std = a[..., :3].mean((0, 1)), a[..., :3].std((0, 1)) + 1e-6
    rmean, rstd = ref.mean((0, 1, 2)), ref.std((0, 1, 2))
    moved = (a[..., :3] - mean) / std * rstd + rmean
    a[..., :3] = a[..., :3] + (moved - a[..., :3]) * amount
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


def rim_pieces(h_strip, corner):
    """Wall-top rim slots: full TILE cells, transparent except the rim along
    one edge, plus corner caps. h_strip: TILE×RIM image; corner: RIM×RIM."""
    v_strip = h_strip.rotate(90, expand=True)  # RIM×TILE
    cells = []
    for edge in ('top', 'bottom', 'left', 'right'):
        c = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
        if edge == 'top':
            c.alpha_composite(h_strip, (0, 0))
        elif edge == 'bottom':
            c.alpha_composite(h_strip.transpose(Image.FLIP_TOP_BOTTOM), (0, TILE - RIM))
        elif edge == 'left':
            c.alpha_composite(v_strip, (0, 0))
        else:
            c.alpha_composite(v_strip.transpose(Image.FLIP_LEFT_RIGHT), (TILE - RIM, 0))
        cells.append(c)
    for x, y in ((0, 0), (TILE - RIM, 0), (0, TILE - RIM), (TILE - RIM, TILE - RIM)):
        c = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
        c.alpha_composite(corner, (x, y))
        cells.append(c)
    return cells


def face_cell(face_band, h_strip):
    """The front of a wall whose tile below is floor: capstones over a rock face
    with a dark foot, in the lower part of the tile."""
    c = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
    band = face_band.resize((TILE, FACE), Image.LANCZOS)
    foot = np.asarray(band).astype(np.float32)
    shade = np.linspace(1.0, 0.55, FACE)[:, None, None]
    foot[..., :3] *= shade
    c.alpha_composite(Image.fromarray(foot.astype(np.uint8), 'RGBA'), (0, TILE - FACE))
    c.alpha_composite(h_strip, (0, TILE - FACE - RIM))
    return c


def build_tiles():
    for world in ('wake', 'nightmare'):
        a = rgb(f'tileset_{world}.png')
        extra = rgb(f'floor_{world}_extra.png')
        if world == 'wake':
            floors = [cold(tile_from(a, b), 0.2) for b in WAKE_FLOOR[:6]]
            # rubble tops of the free-standing blocks, inside their rims
            # (cut well inside the rim, whose inner shadow would grid long walls)
            fills = [cold(tile_from(a, b), 0.6) for b in [(722, 46, 813, 147), (892, 46, 979, 147)]]
            rim_src = a[12:34, 712:823]  # top rim of block 1
            corner_src = a[12:36, 688:712]
            face_src = a[255:316, 690:849]
        else:
            floors = [tile_from(a, b) for b in NIGHT_FLOOR_CLEAN]
            # the bone cubes are drawn in perspective: take their front faces
            fills = [tile_from(a, b) for b in [(712, 52, 818, 162), (1205, 52, 1315, 162)]]
            rim_src = a[202:236, 694:845]  # the long bones capping row-2 wall
            corner_src = a[200:236, 688:724]
            face_src = a[246:318, 690:849]
        extras = [tile_from(extra, b) for b in [(14, 10, 343, 329), (354, 10, 683, 331),
                                                 (696, 10, 1023, 329), (1036, 10, 1365, 331)]]
        # the delivered extras sit on their own (paler) slabs: tone them to the floor
        extras = [match_tone(e, floors) for e in extras]
        if world == 'nightmare':
            extras = extras + [tile_from(a, b) for b in NIGHT_FLOOR_GORE]
        else:
            # the sunken stone reads as a pit (a trap) in play: a mirrored crack instead
            extras[1] = extras[0].transpose(Image.FLIP_LEFT_RIGHT)
            extras = [cold(e, 0.2) for e in extras] + [floors[0], floors[1]]  # keep 6 slots
        h_strip = resized(rim_src.astype(np.uint8), TILE, RIM).convert('RGBA')
        corner = resized(corner_src.astype(np.uint8), RIM, RIM).convert('RGBA')
        if world == 'wake':
            h_strip, corner = cold(h_strip, 0.6), cold(corner, 0.6)
        face_band = resized(face_src.astype(np.uint8), TILE, FACE).convert('RGBA')
        faces = [face_cell(face_band, h_strip),
                 face_cell(face_band.transpose(Image.FLIP_LEFT_RIGHT), h_strip)]
        cells = floors + extras + fills + rim_pieces(h_strip, corner) + faces
        assert len(cells) == 24, len(cells)
        save(strip(cells), f'tiles/{world}_tiles.png')


# ── objects ─────────────────────────────────────────────────────────────────


def build_objects():
    save(strip(opaque_frames('obj_start.png', [(12, 10, 331, 329), (358, 10, 667, 329),
                                               (700, 10, 1019, 329), (1044, 10, 1361, 329)], do_align=True)),
         'objects/start.png')
    save(strip(opaque_frames('obj_exit.png', [(8, 24, 317, 337), (352, 24, 663, 337),
                                              (700, 24, 1007, 337), (1040, 24, 1353, 337)], do_align=True)),
         'objects/exit_wake.png')
    save(strip(opaque_frames('extra_devil_eyes_exit.png', [(12, 24, 335, 331), (356, 24, 679, 331),
                                                           (698, 24, 1009, 331), (1042, 24, 1357, 331)],
                             do_align=True)),
         'objects/exit_nightmare.png')
    save(strip(opaque_frames('obj_spirit_candle.png', [(12, 10, 335, 331), (356, 10, 679, 329),
                                                       (698, 10, 1023, 331), (1042, 10, 1365, 329)],
                             do_align=True)),
         'objects/safe.png')
    # WAKE trap: 4 raised slabs on white
    t = key_light(rgb('trap_wake.png'))
    boxes = content_boxes(t[..., 3] / 255.0, min_area=20000, gap=4)
    frames = [crop(t, b) for b in boxes]
    save(strip(fit_frames(frames, TILE, TILE, pad=0.0)), 'objects/trap_wake.png')
    # NIGHTMARE trap: 8 tiles in a 4×2 grid on dark stone
    cols = [(55, 360), (388, 693), (721, 1027), (1055, 1359)]
    boxes = [(x0, y0, x1, y1) for (y0, y1) in [(62, 366), (399, 703)] for (x0, x1) in cols]
    save(strip(opaque_frames('trap_nightmare.png', boxes)), 'objects/trap_nightmare.png')
    # Torch: 8 flame frames on white; the flame (hot, saturated) stays solid
    a = rgb('obj_torch.png')
    hot = ndimage.binary_fill_holes((a[..., 0] - a[..., 2] > 70) & (a[..., 0] > 170))
    hot = ndimage.binary_opening(hot, iterations=1)
    t = key_light(a, protect=hot)
    w = t.shape[1] / 8.0
    frames = [t[:, int(i * w):int((i + 1) * w)] for i in range(8)]
    save(strip(fit_frames(frames, 64, 128, pad=0.02, anchor='bottom')), 'objects/torch.png')
    # Props: 4×2 sheets of loose objects on white/light grey
    for world in ('wake', 'nightmare'):
        t = key_light(rgb(f'props_{world}.png'))
        h, w = t.shape[:2]
        frames = []
        for row in range(2):
            for col in range(4):
                cell = t[row * h // 2:(row + 1) * h // 2, col * w // 4:(col + 1) * w // 4]
                b = content_boxes(cell[..., 3] / 255.0, min_area=900, gap=10)
                x0 = min(bb[0] for bb in b); y0 = min(bb[1] for bb in b)
                x1 = max(bb[2] for bb in b); y1 = max(bb[3] for bb in b)
                frames.append(crop(cell, (x0, y0, x1, y1)))
        save(strip(fit_frames(frames, TILE, TILE, pad=0.04)), f'objects/props_{world}.png')


# ── effects ─────────────────────────────────────────────────────────────────


def split_columns(t, n):
    """Equal-width slices (for FX whose vertical position matters)."""
    w = t.shape[1] / float(n)
    return [t[:, int(i * w):int((i + 1) * w)] for i in range(n)]


def despeckle(t, min_area):
    """Soft FX: drop isolated specks (checker leftovers) below min_area px."""
    solid = t[..., 3] > 30
    lab, n = ndimage.label(solid)
    if n:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        keep = ndimage.binary_dilation(
            np.isin(lab, [i for i, s in enumerate(sizes, 1) if s >= min_area]), iterations=3)
        t = t.copy()
        t[..., 3] = np.where(keep, t[..., 3], 0)
    return t


def tight(frame, pad=4, keep_height=False):
    """Crop a frame to its visible content (only sideways when keep_height,
    for FX whose height in the frame matters, like a falling drop)."""
    solid = frame[..., 3] > 20
    xs = np.flatnonzero(solid.any(0))
    ys = np.flatnonzero(solid.any(1))
    if len(xs) == 0:
        return frame
    x0, x1 = max(0, xs.min() - pad), xs.max() + pad + 1
    if keep_height:
        return frame[:, x0:x1]
    return frame[max(0, ys.min() - pad):ys.max() + pad + 1, x0:x1]


def blobs(t, n, min_area=300, gap=14):
    boxes = content_boxes(t[..., 3] / 255.0, min_area=min_area, gap=gap)
    boxes = sorted(boxes, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]), reverse=True)[:n]
    boxes = sorted(boxes, key=lambda b: b[0])
    return [crop(t, b) for b in boxes]


def build_fx():
    t = key_dark(rgb('fx_smoke.png'))
    save(strip(fit_frames(blobs(t, 5, gap=10), 160, 160)), 'fx/smoke.png')
    t = key_hard(rgb('fx_debris.png'), tol=10, min_island=60, thin=1)
    save(strip(fit_frames(split_columns(t, 5), 128, 128, pad=0.02)), 'fx/debris.png')
    t = key_glow(rgb('fx_sparkle.png'))
    save(strip(fit_frames(split_columns(t, 4), 96, 96, pad=0.0)), 'fx/sparkle.png')
    # only the bright bodies (the halo was blended over the squares), and the
    # faint fourth wisp is all leftovers: loop 1-2-3-2 instead
    t = despeckle(key_glow_model(rgb('fx_wisp.png'), gain=1.8, floor=45), 1200)
    w = [tight(f) for f in split_columns(t, 4)[:3]]
    save(strip(fit_frames(w + [w[1]], 96, 96, pad=0.04)), 'fx/wisp.png')
    t = only_saturated(key_hard(rgb('fx_drip.png'), tol=20, min_island=60, flat=True, thin=1))
    frames = [tight(f, pad=6, keep_height=True) for f in split_columns(t, 4)]
    save(strip(fit_frames(frames, 48, 128, pad=0.0)), 'fx/drip.png')
    t = key_red(rgb('fx_flip.png'))
    save(strip(fit_frames(split_columns(t, 6), 128, 128, pad=0.0)), 'fx/flip.png')
    # dust: the four boxed puffs of the top row; the box outlines stay out
    a = rgb('fx_dust.png')
    t = key_sky(a)
    boxes = [(48, 52, 315, 340), (398, 52, 668, 340), (742, 52, 1015, 340), (1090, 52, 1360, 340)]
    save(strip(fit_frames([crop(t, b) for b in boxes], 64, 64, pad=0.0)), 'fx/dust.png')


# ── UI ──────────────────────────────────────────────────────────────────────

# ui_icons.png, left to right, top row then bottom row
ICONS = ['pause', 'play', 'maze', 'hourglass', 'flag', 'heart', 'heart_empty', 'skull',
         'trophy', 'house', 'retry', 'film', 'check', 'cross', 'sound_on', 'sound_off']


def build_ui():
    t = key_hard(rgb('ui_icons.png'), enclosed=True, min_enclosed=300)
    h, w = t.shape[:2]
    frames = []
    for row in range(2):
        band = t[row * h // 2:(row + 1) * h // 2]
        for col in range(8):
            cell = band[:, col * w // 8:(col + 1) * w // 8]
            b = content_boxes(cell[..., 3] / 255.0, min_area=600, gap=4)
            x0 = min(bb[0] for bb in b); y0 = min(bb[1] for bb in b)
            x1 = max(bb[2] for bb in b); y1 = max(bb[3] for bb in b)
            frames.append(crop(cell, (x0, y0, x1, y1)))
    # every icon fits its own 96 px cell (they're read one at a time)
    cells = [fit_frames([f], 96, 96, pad=0.04)[0] for f in frames]
    for icon, cell in zip(ICONS, cells):
        save(cell, f'ui/icon_{icon}.png')

    t = key_hard(rgb('ui_button.png'), tol=18)
    up, down = fit_frames(blobs(t, 2, min_area=5000), 128, 128, pad=0.02)
    save(up, 'ui/button.png')
    save(down, 'ui/button_pressed.png')
    t = largest_only(key_hard(rgb('ui_knob.png'), tol=18))
    save(fit_frames(blobs(t, 1, min_area=5000), 160, 160, pad=0.02)[0], 'ui/knob.png')
    t = largest_only(key_hard(rgb('ui_joystick.png'), enclosed=True))
    save(fit_frames(blobs(t, 1, min_area=5000), 384, 384, pad=0.01)[0], 'ui/joystick.png')
    t = largest_only(key_hard(rgb('ui_textbox.png'), enclosed=True))
    save(fit_frames(blobs(t, 1, min_area=5000), 320, 320, pad=0.01)[0], 'ui/medallion.png')
    t = key_hard(rgb('ui_timebar.png'), tol=18)
    bar = blobs(t, 1, min_area=5000)[0]
    save(fit_frames([bar], 512, 128, pad=0.0)[0], 'ui/timebar.png')
    a = rgb('extra_bloody_bone.png')
    # left copy, clear of the divider; its glow tinted the squares, so brighter-than-
    # backdrop flat squares count as backdrop too
    t = largest_only(key_hard(a[:, :a.shape[1] // 2 - 20], tol=70, flat=True, enclosed=True, thin=2,
                              t_max=2.2, min_island=400))
    save(fit_frames(blobs(t, 1, min_area=5000), 160, 96, pad=0.02)[0], 'ui/bone_arrow.png')
    # D-pad: the art is the up-pressed pad. Idle = the down arm mirrored over
    # the up socket; pressed = the art as-is (the game rotates it).
    t = largest_only(key_hard(rgb('ui_dpad.png'), tol=16, flat=True, enclosed=True, thin=2))
    pressed = np.asarray(fit_frames(blobs(t, 1, min_area=5000), 384, 384, pad=0.01)[0]).copy()
    # Measure the plus: the up arm's columns (top rows only) and the left arm's
    # rows (left columns only); anything outside the plus is backdrop.
    solid = pressed[..., 3] > 128
    xs = np.flatnonzero(solid[:384 // 8].any(0))
    ys = np.flatnonzero(solid[:, :384 // 8].any(1))
    (x0, x1), (y0, y1) = (xs.min(), xs.max()), (ys.min(), ys.max())
    plus = np.zeros_like(solid)
    plus[:, x0:x1 + 1] = True
    plus[y0:y1 + 1, :] = True
    # exact, not widened: a sliver of checker hugs the up arm's left bevel
    plus = ndimage.gaussian_filter(plus.astype(np.float32), 0.8)
    pressed[..., 3] = (pressed[..., 3] * plus).astype(np.uint8)
    idle = pressed.copy()
    arm = pressed[y1 + 1:y1 + 1 + y0, x0:x1 + 1]  # the down arm next to the centre
    idle[0:arm.shape[0], x0:x1 + 1] = arm[::-1]
    save(Image.fromarray(idle), 'ui/dpad.png')
    save(Image.fromarray(pressed), 'ui/dpad_pressed.png')


# ── self-check ──────────────────────────────────────────────────────────────

EXPECT = {  # rel path: (frame width, frame height, frames)
    'tiles/wake_tiles.png': (TILE, TILE, 24), 'tiles/nightmare_tiles.png': (TILE, TILE, 24),
    'objects/start.png': (TILE, TILE, 4), 'objects/exit_wake.png': (TILE, TILE, 4),
    'objects/exit_nightmare.png': (TILE, TILE, 4), 'objects/safe.png': (TILE, TILE, 4),
    'objects/trap_wake.png': (TILE, TILE, 4), 'objects/trap_nightmare.png': (TILE, TILE, 8),
    'objects/torch.png': (64, 128, 8), 'objects/props_wake.png': (TILE, TILE, 8),
    'objects/props_nightmare.png': (TILE, TILE, 8),
    'fx/smoke.png': (160, 160, 5), 'fx/debris.png': (128, 128, 5), 'fx/sparkle.png': (96, 96, 4),
    'fx/wisp.png': (96, 96, 4), 'fx/drip.png': (48, 128, 4), 'fx/flip.png': (128, 128, 6),
    'fx/dust.png': (64, 64, 4),
    **{f'ui/icon_{i}.png': (96, 96, 1) for i in ICONS},
    'ui/button.png': (128, 128, 1), 'ui/button_pressed.png': (128, 128, 1), 'ui/knob.png': (160, 160, 1),
    'ui/joystick.png': (384, 384, 1), 'ui/medallion.png': (320, 320, 1), 'ui/timebar.png': (512, 128, 1),
    'ui/bone_arrow.png': (160, 96, 1), 'ui/dpad.png': (384, 384, 1), 'ui/dpad_pressed.png': (384, 384, 1),
}
KEYED = [p for p in EXPECT if not p.startswith('tiles/') and p not in (
    'objects/start.png', 'objects/exit_wake.png', 'objects/exit_nightmare.png',
    'objects/safe.png', 'objects/trap_nightmare.png')]


def self_check():
    for rel, (fw, fh, n) in EXPECT.items():
        im = Image.open(os.path.join(OUT, rel))
        assert im.mode == 'RGBA', rel
        assert im.size == (fw * n, fh), (rel, im.size, (fw * n, fh))
        if rel in KEYED:
            a = np.asarray(im)[..., 3]
            if rel != 'ui/timebar.png':  # the bar fills its frame
                assert (a == 0).mean() > 0.15, f'{rel}: backdrop not keyed out'
            corners = [a[1, 1], a[1, fw - 2], a[fh - 2, 1], a[fh - 2, fw - 2]]
            assert max(corners) < 40, f'{rel}: opaque frame corner {corners}'
    print(f'self-check ok: {len(EXPECT)} strips')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    load_sources(sys.argv[1])
    OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', '2d')
    build_tiles()
    build_objects()
    build_fx()
    build_ui()
    self_check()
