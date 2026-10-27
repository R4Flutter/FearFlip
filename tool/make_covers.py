"""Builds the store covers for CrazyGames from the game's own art.

    python3 tool/make_covers.py <maze_screenshot.png> [out_dir]

The backdrop is a screenshot of a maze (take one in the game at 1920x1080);
the runner and the Devil come from lib/presentation/gameplay/pixel_sprites.dart
and the title from the bundled fonts, so the covers always match the game.
Writes cover_1920x1080.png, cover_800x1200.png, cover_800x800.png and
icon_512.png into out_dir (default: store/).
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..')
SPRITES = os.path.join(ROOT, 'lib/presentation/gameplay/pixel_sprites.dart')
TITLE_FONT = os.path.join(ROOT, 'assets/fonts/Jacquard12-Regular.ttf')
BODY_FONT = os.path.join(ROOT, 'assets/fonts/Jersey15-Regular.ttf')

INK = (22, 21, 31)
BONE = (240, 230, 210)
BLOOD = (224, 58, 50)
AMBER = (242, 181, 68)

RUNNER = {
    'o': INK, 'H': (201, 138, 46), 'h': (156, 90, 43), 'S': (240, 201, 160),
    's': (201, 148, 106), 'E': INK, 'T': BONE, 'C': (85, 98, 126),
    'c': (59, 70, 96), 'B': (62, 42, 32),
}
DEVIL = {
    'o': (10, 10, 15), 'D': (43, 26, 51), 'd': INK, 'R': BLOOD, 'W': BONE,
    'H': (216, 195, 160), 'h': (138, 107, 80),
}


def sprite_rows(name):
    """The pixel rows of a const list in pixel_sprites.dart."""
    src = open(SPRITES, encoding='utf-8').read()
    block = src[src.index(name):]
    block = block[:block.index('];') + 2]
    return re.findall(r"'([.oHhSsETCcBDdRW]{16})'", block)


def draw_sprite(rows, palette, scale):
    w, h = len(rows[0]), len(rows)
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                img.putpixel((x, y), palette[ch] + (255,))
    return img.resize((w * scale, h * scale), Image.NEAREST)


def glow(size, center, radius, color, alpha):
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
              fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def outlined_text(draw, xy, text, font, fill, outline, width):
    x, y = xy
    for dx in range(-width, width + 1):
        for dy in range(-width, width + 1):
            if dx or dy:
                draw.text((x + dx, y + dy), text, font=font, fill=outline)
    draw.text((x, y), text, font=font, fill=fill)


def cover(background, size, out):
    W, H = size
    # Leave out the HUD strip along the top of the screenshot.
    bg = background.crop((0, int(background.height * 0.12), background.width, background.height))
    # Fill the frame from the middle of the screenshot.
    scale = max(W / bg.width, H / bg.height)
    bg = bg.resize((int(bg.width * scale), int(bg.height * scale)), Image.LANCZOS)
    left, top = (bg.width - W) // 2, (bg.height - H) // 2
    bg = bg.crop((left, top, left + W, top + H)).convert('RGBA')
    bg = bg.filter(ImageFilter.GaussianBlur(2.2))
    shade = Image.new('RGBA', (W, H), (10, 10, 15, 120))
    canvas = Image.alpha_composite(bg, shade)

    # Vignette.
    vig = Image.new('L', (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.25, -H * 0.2, W * 1.25, H * 1.2], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(min(W, H) * 0.12))
    dark = Image.new('RGBA', (W, H), (5, 5, 8, 235))
    canvas = Image.composite(canvas, dark, vig)

    unit = min(W, H)
    tall = H > W * 1.2
    runner = draw_sprite(sprite_rows('_downHead') + sprite_rows('_legs')[:2], RUNNER, max(4, int(unit / 70)))
    devil = draw_sprite(sprite_rows('static const List<List<String>> frames')[:22], DEVIL, max(5, int(unit / 52)))

    if tall:
        runner_at = (int(W * 0.28 - runner.width / 2), int(H * 0.62))
        devil_at = (int(W * 0.72 - devil.width / 2), int(H * 0.52))
    else:
        runner_at = (int(W * 0.30 - runner.width / 2), int(H * 0.52))
        devil_at = (int(W * 0.70 - devil.width / 2), int(H * 0.40))

    canvas = Image.alpha_composite(canvas, glow((W, H), (runner_at[0] + runner.width // 2, runner_at[1] + runner.height // 2),
                                               int(unit * 0.22), AMBER, 120))
    canvas = Image.alpha_composite(canvas, glow((W, H), (devil_at[0] + devil.width // 2, devil_at[1] + devil.height // 2),
                                               int(unit * 0.25), BLOOD, 110))
    canvas.alpha_composite(devil, devil_at)
    canvas.alpha_composite(runner, runner_at)
    # The lantern.
    lx = runner_at[0] + int(runner.width * 0.92)
    ly = runner_at[1] + int(runner.height * 0.62)
    canvas = Image.alpha_composite(canvas, glow((W, H), (lx, ly), int(unit * 0.06), (255, 224, 138), 200))
    d = ImageDraw.Draw(canvas)
    px = max(4, int(unit / 70))
    d.rectangle([lx - px * 2, ly - px * 2, lx + px * 2, ly + px * 3], fill=INK)
    d.rectangle([lx - px * 1.3, ly - px * 1.3, lx + px * 1.3, ly + px * 2.3], fill=(255, 236, 170))

    # Title.
    title_size = int(unit * (0.2 if tall else 0.24))
    tf = ImageFont.truetype(TITLE_FONT, title_size)
    fear, flip = 'Fear', 'Flip'
    fw = d.textlength(fear, font=tf)
    gap = title_size * 0.15
    lw = d.textlength(flip, font=tf)
    total = fw + gap + lw
    tx = (W - total) / 2
    ty = H * (0.08 if tall else 0.06)
    tglow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(tglow)
    gd.text((tx + fw + gap, ty), flip, font=tf, fill=BLOOD + (200,))
    tglow = tglow.filter(ImageFilter.GaussianBlur(title_size * 0.12))
    canvas = Image.alpha_composite(canvas, tglow)
    d = ImageDraw.Draw(canvas)
    ow = max(3, title_size // 28)
    outlined_text(d, (tx, ty), fear, tf, BONE, INK, ow)
    outlined_text(d, (tx + fw + gap, ty), flip, tf, BLOOD, INK, ow)

    sub = 'ESCAPE THE NIGHTMARE'
    sf = ImageFont.truetype(BODY_FONT, int(unit * 0.065))
    sw = d.textlength(sub, font=sf)
    outlined_text(d, ((W - sw) / 2, ty + title_size * 1.02), sub, sf, (216, 195, 160), INK, max(2, ow // 2))

    canvas.convert('RGB').save(out, optimize=True)
    print('wrote', out)


def icon(background, out):
    S = 512
    tile = background.crop((0, int(background.height * 0.12), background.width, background.height)).resize((S * 2, int(background.height * S * 2 / background.width)), Image.LANCZOS)
    tile = tile.crop((S // 2, 0, S // 2 + S, S)).convert('RGBA').filter(ImageFilter.GaussianBlur(2))
    canvas = Image.alpha_composite(tile, Image.new('RGBA', (S, S), (10, 10, 15, 150)))
    canvas = Image.alpha_composite(canvas, glow((S, S), (S // 2, int(S * 0.56)), int(S * 0.35), AMBER, 130))
    runner = draw_sprite(sprite_rows('_downHead') + sprite_rows('_legs')[:2], RUNNER, 20)
    canvas.alpha_composite(runner, ((S - runner.width) // 2, int(S * 0.2)))
    canvas.convert('RGB').save(out, optimize=True)
    print('wrote', out)


if __name__ == '__main__':
    bg = Image.open(sys.argv[1])
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'store')
    os.makedirs(out_dir, exist_ok=True)
    cover(bg, (1920, 1080), os.path.join(out_dir, 'cover_1920x1080.png'))
    cover(bg, (800, 1200), os.path.join(out_dir, 'cover_800x1200.png'))
    cover(bg, (800, 800), os.path.join(out_dir, 'cover_800x800.png'))
    icon(bg, os.path.join(out_dir, 'icon_512.png'))
