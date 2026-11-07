#!/usr/bin/env python3
"""Draws the app icon and splash logo from scratch.

Lâjvard background with a faint Persian eight-point-star (khatam) tile pattern;
foreground: a cream paper card with a firuzeh brush swoosh and a saffron sun,
crossed by a saffron pencil. Writes Android adaptive + legacy icons, a splash
logo and a 512 px store icon.

    python3 -I tool/icon/make_icon.py <repo root>
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 1024  # working canvas = 108 dp adaptive icon
LAJVARD = (18, 35, 63)
LAJVARD_DEEP = (11, 23, 48)
LAJVARD_LIGHT = (36, 66, 118)
FIRUZEH = (42, 181, 166)
FIRUZEH_DARK = (27, 131, 120)
ZAFERAN = (242, 169, 59)
ZAFERAN_DARK = (185, 118, 26)
ANAR = (225, 77, 99)
KAGHAZ = (251, 243, 228)
INK = (34, 48, 63)


def radial_bg(size):
    img = Image.new('RGB', (size, size), LAJVARD_DEEP)
    px = img.load()
    cx, cy = size * .5, size * .38
    rmax = size * .85
    for y in range(size):
        for x in range(size):
            d = min(1, math.hypot(x - cx, y - cy) / rmax)
            if d < .55:
                t = d / .55
                c = tuple(int(LAJVARD_LIGHT[i] * (1 - t) + LAJVARD[i] * t) for i in range(3))
            else:
                t = (d - .55) / .45
                c = tuple(int(LAJVARD[i] * (1 - t) + LAJVARD_DEEP[i] * t) for i in range(3))
            px[x, y] = c
    return img.convert('RGBA')


def star8(draw, cx, cy, r, color, width):
    """Eight-point star: two squares, one turned 45 degrees."""
    for rot in (0, math.pi / 4):
        pts = [(cx + r * math.cos(rot + k * math.pi / 2), cy + r * math.sin(rot + k * math.pi / 2)) for k in range(4)]
        draw.polygon(pts, outline=color, width=width)


def background(size=S):
    img = radial_bg(size)
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = size // 4
    for gy in range(-1, 6):
        for gx in range(-1, 6):
            cx = gx * step + (step // 2 if gy % 2 else 0)
            cy = gy * step * .87
            star8(d, cx, cy, step * .34, (255, 255, 255, 20), max(2, size // 220))
    return Image.alpha_composite(img, layer)


def rotated(layer, angle, center):
    return layer.rotate(angle, resample=Image.BICUBIC, center=center)


def foreground(size=S):
    k = size / 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    # paper card with a soft shadow
    card = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    box = (int(300 * k), int(268 * k), int(712 * k), int(742 * k))
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((box[0] + 14 * k, box[1] + 26 * k, box[2] + 14 * k, box[3] + 26 * k), radius=int(46 * k), fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22 * k))
    cd.rounded_rectangle(box, radius=int(46 * k), fill=KAGHAZ + (255,))
    # the doodle on the paper: a saffron sun and a firuzeh brush wave
    cd.ellipse((int(560 * k), int(320 * k), int(660 * k), int(420 * k)), fill=ZAFERAN + (255,))
    wave = []
    for i in range(61):
        t = i / 60
        x = 340 + t * 330
        y = 560 + math.sin(t * math.pi * 2.2) * 62 - t * 40
        wave.append((x * k, y * k))
    for w, col in ((70, FIRUZEH_DARK), (58, FIRUZEH)):
        cd.line(wave, fill=col + (255,), width=int(w * k), joint='curve')
        r = w * k / 2
        for (x, y) in (wave[0], wave[-1]):
            cd.ellipse((x - r, y - r, x + r, y + r), fill=col + (255,))
    # a few ink marks: little rays for the sun
    for a in range(8):
        ang = a * math.pi / 4
        x0, y0 = 610 + math.cos(ang) * 68, 370 + math.sin(ang) * 68
        x1, y1 = 610 + math.cos(ang) * 92, 370 + math.sin(ang) * 92
        cd.line((x0 * k, y0 * k, x1 * k, y1 * k), fill=ZAFERAN_DARK + (255,), width=int(12 * k))
    card = rotated(card, 8, (size / 2, size / 2))
    shadow = rotated(shadow, 8, (size / 2, size / 2))
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, card)

    # pencil, drawn horizontally then turned
    pen = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pen)
    cy = size / 2
    h = 86 * k
    x0, x1 = 312 * k, 712 * k  # eraser end .. tip end
    pd.rounded_rectangle((x0, cy - h / 2, x0 + 70 * k, cy + h / 2), radius=int(22 * k), fill=ANAR + (255,))
    pd.rectangle((x0 + 55 * k, cy - h / 2, x0 + 105 * k, cy + h / 2), fill=(200, 210, 222, 255))
    pd.line((x0 + 72 * k, cy - h / 2, x0 + 72 * k, cy + h / 2), fill=(150, 160, 175, 255), width=int(6 * k))
    pd.line((x0 + 88 * k, cy - h / 2, x0 + 88 * k, cy + h / 2), fill=(150, 160, 175, 255), width=int(6 * k))
    pd.rectangle((x0 + 105 * k, cy - h / 2, x1 - 100 * k, cy + h / 2), fill=ZAFERAN + (255,))
    pd.rectangle((x0 + 105 * k, cy - h / 6, x1 - 100 * k, cy + h / 6), fill=(247, 190, 92, 255))
    pd.rectangle((x0 + 105 * k, cy + h / 6, x1 - 100 * k, cy + h / 2), fill=ZAFERAN_DARK + (255,))
    pd.polygon([(x1 - 100 * k, cy - h / 2), (x1 - 100 * k, cy + h / 2), (x1, cy)], fill=(240, 214, 170, 255))
    pd.polygon([(x1 - 36 * k, cy - h * .18), (x1 - 36 * k, cy + h * .18), (x1, cy)], fill=INK + (255,))
    pen_shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(pen_shadow).rounded_rectangle((x0 + 10 * k, cy - h / 2 + 22 * k, x1 + 10 * k, cy + h / 2 + 22 * k), radius=int(30 * k), fill=(0, 0, 0, 120))
    pen_shadow = pen_shadow.filter(ImageFilter.GaussianBlur(16 * k))
    # tip points down-right and lands on the end of the brush wave, as if drawing it
    angle = -38
    shift = (1, 0, 4 * k, 0, 1, 95 * k)
    pen = rotated(pen, angle, (size / 2, size / 2)).transform((size, size), Image.AFFINE, shift)
    pen_shadow = rotated(pen_shadow, angle, (size / 2, size / 2)).transform((size, size), Image.AFFINE, shift)
    img = Image.alpha_composite(img, pen_shadow)
    img = Image.alpha_composite(img, pen)
    # keep everything inside the adaptive-icon safe zone
    inner = int(size * .86)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    return out


def monochrome(fg):
    alpha = fg.split()[3]
    out = Image.new('RGBA', fg.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def rounded_mask(size, radius):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return m


def legacy(bg, fg, size):
    """Pre-Android-8 icon: the adaptive layers cropped to the visible 72/108 and rounded."""
    full = Image.alpha_composite(bg, fg)
    inset = int(S * 18 / 108)
    crop = full.crop((inset, inset, S - inset, S - inset)).resize((size, size), Image.LANCZOS)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(crop, (0, 0), rounded_mask(size, int(size * .22)))
    return out


DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def main(root):
    root = Path(root)
    res = root / 'android/app/src/main/res'
    big = 2048  # supersample, then downscale everything for clean edges
    bg = background(big).resize((S, S), Image.LANCZOS)
    fg = foreground(big).resize((S, S), Image.LANCZOS)
    mono = monochrome(fg)
    for name, m in DENSITIES.items():
        d = res / f'mipmap-{name}'
        d.mkdir(parents=True, exist_ok=True)
        adaptive = int(108 * m)
        fg.resize((adaptive, adaptive), Image.LANCZOS).save(d / 'ic_launcher_foreground.png', optimize=True)
        bg.resize((adaptive, adaptive), Image.LANCZOS).convert('RGB').save(d / 'ic_launcher_background.png', optimize=True)
        mono.resize((adaptive, adaptive), Image.LANCZOS).save(d / 'ic_launcher_monochrome.png', optimize=True)
        legacy(bg, fg, int(48 * m)).save(d / 'ic_launcher.png', optimize=True)
    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n')
    nodpi = res / 'drawable-nodpi'
    nodpi.mkdir(exist_ok=True)
    fg.resize((384, 384), Image.LANCZOS).save(nodpi / 'splash_logo.png', optimize=True)
    store = root / 'store'
    store.mkdir(exist_ok=True)
    legacy(bg, fg, 512).save(store / 'icon-512.png', optimize=True)
    print('icons written')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
