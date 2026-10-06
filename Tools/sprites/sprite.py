"""Data model shared by character modules and the exporter."""
from __future__ import annotations

from dataclasses import dataclass, field

from PIL import Image


@dataclass
class Anim:
    frames: list[Image.Image]
    fps: int = 10
    loop: bool = True


@dataclass
class Sprite:
    name: str
    size: tuple[int, int]
    anims: dict[str, Anim] = field(default_factory=dict)
    # Characters are drawn facing right; enemies are mirrored on export so they face the hero.
    faces_left: bool = False
    # Where the figure stands inside the frame: x of its centre and y of its lowest pixel row.
    # None means horizontally centred / sitting on the bottom edge.
    cx: float | None = None
    ground: int | None = None

    def add(self, name: str, frames: list, fps: int = 10, loop: bool = True) -> None:
        images = [f.img if hasattr(f, "img") else f for f in frames]
        for image in images:
            if image.size != self.size:
                raise ValueError(f"{self.name}/{name}: frame is {image.size}, expected {self.size}")
        self.anims[name] = Anim(images, fps, loop)
