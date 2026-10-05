#!/usr/bin/env python3
"""Generates every sprite. Usage: build.py [all | <sprite name>...]"""
from __future__ import annotations

import importlib
import pkgutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import characters  # noqa: E402
import export  # noqa: E402
from sprite import Sprite  # noqa: E402


def all_sprites() -> list[Sprite]:
    sprites: list[Sprite] = []
    for module in sorted(pkgutil.iter_modules(characters.__path__), key=lambda m: m.name):
        sprites += importlib.import_module(f"characters.{module.name}").build()
    names = [s.name for s in sprites]
    duplicates = {n for n in names if names.count(n) > 1}
    if duplicates:
        raise SystemExit(f"duplicate sprite names: {sorted(duplicates)}")
    return sprites


def main(argv: list[str]) -> int:
    sprites = all_sprites()
    wanted = set(argv) - {"all"}
    unknown = wanted - {s.name for s in sprites}
    if unknown:
        print(f"unknown sprite(s): {sorted(unknown)}; known: {sorted(s.name for s in sprites)}")
        return 1
    manifest = export.export(sprites, only=wanted or None)
    built = [s for s in sprites if not wanted or s.name in wanted]
    for sprite in built:
        export.contact_sheet([sprite], export.OUT / "contact" / f"{sprite.name}.png")
    if not wanted:
        by_name = {s.name: s for s in sprites}
        export.app_icon(by_name["hero"], by_name["fireball_charged"])
    frames = sum(len(a.frames) for s in built for a in s.anims.values())
    print(f"built {len(built)} sprite(s), {frames} frames; manifest has {len(manifest)} sprites")
    print(f"previews: {export.OUT / 'preview'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
