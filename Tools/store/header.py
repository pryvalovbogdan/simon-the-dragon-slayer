#!/usr/bin/env python3
"""Builds the App Store product page header from the game's own sprites.

Usage: Tools/.venv/bin/python Tools/store/header.py [out_dir]   (default: img/store-header)

The scene is laid out in world units like the menu (sky, clouds, hills, bushes, forest ground),
then scaled up with square pixels and centre-cropped to each size App Store Connect accepts.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "App/Resources/Assets.xcassets/Sprites.spriteatlas"
MANIFEST = json.loads((ROOT / "App/Resources/Sprites.json").read_text())

# (width, height) in device pixels, from App Store Connect's header upload.
SIZES = [(5244, 2950), (3840, 1646)]


def frame(sprite: str, anim: str, index: int = 0) -> Image.Image:
    name = f"{sprite}_{anim}_{index}"
    return Image.open(ATLAS / f"{name}.imageset" / f"{name}.png").convert("RGBA")


def tile_row(canvas: Image.Image, tile: Image.Image, top: int, offset: int = 0) -> None:
    x = -(offset % tile.width)
    while x < canvas.width:
        canvas.alpha_composite(tile, (x, top))
        x += tile.width


def place(canvas: Image.Image, sprite: str, anim: str, index: int, x: float, ground: int) -> None:
    """Stands a sprite with its anchor (feet) at world x on the ground line, as the game does."""
    spec = MANIFEST[sprite]
    img = frame(sprite, anim, index)
    left = round(x - spec["anchorX"] * img.width)
    top = round(ground + spec["anchorY"] * img.height) - img.height
    canvas.alpha_composite(img, (left, top))


def scene(width: int, height: int) -> Image.Image:
    c = Image.new("RGBA", (width, height))
    ground = round(height * 0.72)  # ground line, from the top

    sky = frame("bg_menu_sky", "still").resize((width, height), Image.NEAREST)
    c.alpha_composite(sky)
    tile_row(c, frame("bg_menu_puffs", "still"), ground - 70 - 120, offset=40)
    for name, offset in (("clouds", 90), ("horizon", 30), ("bushes", 10)):
        strip = frame(f"bg_menu_{name}", "still")
        tile_row(c, strip, ground - strip.height, offset)

    fill = frame("ground_forest_fill", "still")
    c.alpha_composite(fill.resize((width, height - ground), Image.NEAREST), (0, ground))
    grass = frame("ground_forest", "still")
    tile_row(c, grass, ground, offset=8)
    earth = frame("ground_forest_earth", "still")
    top = ground + grass.height
    while top < height:
        tile_row(c, earth, top, offset=8)
        top += earth.height

    # The hero casts at the ice dragon; the dragon answers with its frost breath.
    mid = width / 2
    # Offsets keep the whole group, tail included, inside the narrowest crop.
    place(c, "hero", "cast", 1, mid - 96, ground)
    place(c, "fireball", "fly", 0, mid - 62, ground - 22)
    place(c, "hazard_frost", "fly", 0, mid - 28, ground)
    place(c, "boss_dragon", "breath", 4, mid + 44, ground)
    return c


def build(out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for w, h in SIZES:
        # Largest whole-pixel scale at which the world still fits a ~180 unit tall view.
        scale = max(1, round(h / 180))
        units = (math.ceil(w / scale), math.ceil(h / scale))
        big = scene(*units).resize((units[0] * scale, units[1] * scale), Image.NEAREST)
        left, top = (big.width - w) // 2, (big.height - h) // 2
        path = out / f"header_{w}x{h}.png"
        big.crop((left, top, left + w, top + h)).convert("RGB").save(path, optimize=True)
        written.append(path)
    return written


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "img/store-header"
    for p in build(target):
        print(p)
