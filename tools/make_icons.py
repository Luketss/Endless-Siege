#!/usr/bin/env python3
"""Generates placeholder app icons (PNG + Windows .ico). Run: python3 tools/make_icons.py"""
from PIL import Image, ImageDraw

BG, GOLD, PURPLE, CRYSTAL, STONE = (15, 17, 22), (242, 193, 78), (106, 63, 122), (139, 233, 255), (125, 122, 118)


def icon(size):
    img = Image.new("RGBA", (size, size), BG + (255,))
    d = ImageDraw.Draw(img)
    s = size / 256
    d.ellipse([18 * s, 18 * s, 238 * s, 238 * s], fill=PURPLE)
    d.ellipse([34 * s, 34 * s, 222 * s, 222 * s], fill=(30, 27, 40))
    # Tower silhouette
    d.rectangle([92 * s, 92 * s, 164 * s, 200 * s], fill=STONE)
    for i in range(4):
        d.rectangle([(88 + i * 22) * s, 76 * s, (100 + i * 22) * s, 96 * s], fill=STONE)
    d.polygon([(128 * s, 40 * s), (110 * s, 78 * s), (146 * s, 78 * s)], fill=CRYSTAL)
    d.rectangle([118 * s, 160 * s, 138 * s, 200 * s], fill=BG)
    # Arrow across
    d.line([(52 * s, 196 * s), (204 * s, 64 * s)], fill=GOLD, width=max(2, int(8 * s)))
    d.polygon([(204 * s, 64 * s), (180 * s, 70 * s), (198 * s, 88 * s)], fill=GOLD)
    return img


base = icon(1024)
base.save("assets/icons/icon_1024.png")
base.resize((256, 256), Image.LANCZOS).save("assets/icons/icon_256.png")
base.resize((256, 256), Image.LANCZOS).save("assets/icons/icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("icons written")
