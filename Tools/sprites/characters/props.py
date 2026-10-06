"""Obstacles, pickups, HUD icons and boss hazards."""
import math

import palette as P
from draw import Canvas, noise
from sprite import Sprite


def single(name: str, canvas: Canvas, anim: str = "still", cx: float | None = None,
           ground: int | None = None) -> Sprite:
    sprite = Sprite(name, canvas.size, cx=cx, ground=ground)
    sprite.add(anim, [canvas], fps=1)
    return sprite


def tree() -> Sprite:
    """A young tree across the path: 12x24 hitbox inside a 20x30 frame."""
    c = Canvas(20, 30)
    c.rect(8, 12, 11, 28, P.BROWN)
    c.rect(8, 12, 8, 28, P.BROWN_D)
    c.line((10, 18), (14, 14), P.BROWN, 2)
    c.rect(6, 27, 13, 28, P.BROWN_D)
    for cx, cy, rad, color in ((9, 8, 6, P.GREEN_D), (13, 10, 5, P.GREEN_D), (6, 11, 4, P.FOREST),
                               (10, 6, 4, P.GREEN), (12, 8, 3, P.GREEN), (8, 5, 2, P.GREEN_L)):
        c.ellipse(cx, cy, rad, rad, color)
    return single("tree", c.outline(), cx=9.5, ground=28)


def root() -> Sprite:
    c = Canvas(24, 10)
    for i in range(18):
        y = 8 - math.sin(i / 17 * math.pi) * 6
        c.rect(3 + i, y, 3 + i, 8, P.BROWN)
        c.px(3 + i, y, P.BROWN_L)
    c.rect(8, 6, 14, 8, P.CLEAR)  # the gap under the arch
    c.line((6, 8), (2, 8), P.BROWN_D)
    c.line((19, 8), (22, 8), P.BROWN_D)
    return single("root", c.outline(), ground=8)


def icicle() -> Sprite:
    """Hangs from above; the frame's top is the ceiling end."""
    c = Canvas(14, 42)
    c.rect(1, 0, 12, 2, P.BLUE)
    for x, length, color in ((3, 22, P.BLUE), (7, 40, P.BLUE_L), (10, 28, P.BLUE)):
        c.poly([(x - 2, 2), (x + 2, 2), (x, length)], color)
    c.line((7, 4), (7, 30), P.WHITE)
    return single("icicle", c.outline(P.BLUE_D))


def coin() -> Sprite:
    sprite = Sprite("coin", (12, 12))
    frames = []
    for half_width in (4.5, 3.2, 1.2, 0.4, 1.2, 3.2):
        c = Canvas(12, 12)
        c.ellipse(5.5, 5.5, half_width, 4.5, P.GOLD)
        if half_width > 2:
            c.ellipse(5.5, 5.5, half_width - 1.6, 2.8, P.YELLOW)
            c.px(5.5 - half_width + 1.5, 3.5, P.WHITE)
        frames.append(c.outline(P.GOLD_D))
    sprite.add("spin", frames, fps=10)
    return sprite


def medal() -> Sprite:
    """The end-screen award: a struck disc with a sword on it, in three metals."""
    sprite = Sprite("medal", (32, 32))
    for name, face, shade, shine in (("bronze", P.BROWN_L, P.BROWN, P.SAND), ("silver", P.GREY_L, P.GREY, P.WHITE),
                                     ("gold", P.GOLD, P.GOLD_D, P.YELLOW)):
        c = Canvas(32, 32)
        c.ellipse(15.5, 15.5, 13, 13, shade)
        c.ellipse(15.5, 15.5, 10.5, 10.5, face)
        c.line((10, 8), (14, 6), shine)
        # Sword, point up.
        c.rect(15, 7, 16, 19, shade)
        c.px(15.5, 6, shade)
        c.rect(12, 20, 19, 20, shade)
        c.rect(15, 21, 16, 24, shade)
        c.rect(15, 8, 15, 18, shine)
        sprite.add(name, [c.outline(P.OUTLINE)], fps=1)
    return sprite


def shrine() -> Sprite:
    """A standing stone whose runes pulse; passing it grants the level-up."""
    sprite = Sprite("shrine", (24, 48), ground=46)
    frames = []
    for glow in (0, 1, 2, 1):
        c = Canvas(24, 48)
        c.poly([(6, 46), (5, 14), (9, 4), (15, 3), (19, 13), (18, 46)], P.GREY)
        c.poly([(6, 46), (5, 14), (9, 4), (11, 4), (9, 14), (9, 46)], P.GREY_D)
        c.rect(3, 44, 21, 46, P.GREY_D)
        rune = (P.BLUE_D, P.BLUE, P.BLUE_L)[glow]
        for y in (12, 20, 28, 36):
            c.line((11, y), (15, y + 3), rune)
            c.line((15, y), (12, y + 4), rune)
        if glow == 2:
            c.px(12, 1, P.BLUE_L)
            c.px(21, 20, P.BLUE_L)
            c.px(2, 28, P.BLUE_L)
        frames.append(c.outline())
    sprite.add("glow", frames, fps=5)
    return sprite


def heart(name: str, fill, shade) -> Sprite:
    c = Canvas(11, 10)
    c.ellipse(2.5, 2.5, 2, 2, fill)
    c.ellipse(6.5, 2.5, 2, 2, fill)
    c.poly([(0.5, 3.5), (8.5, 3.5), (4.5, 8)], fill)
    c.px(2, 2, shade)
    return single(name, c.outline())


def hazard(name: str, size: tuple[int, int], frames: list[Canvas], fps: int = 10) -> Sprite:
    sprite = Sprite(f"hazard_{name}", size)
    sprite.add("fly", frames, fps=fps)
    return sprite


def hazards() -> list[Sprite]:
    out = []

    # Hazards travel toward the hero, i.e. to the left: draw them leading with their left edge.
    shock = []
    for i in range(3):
        c = Canvas(20, 12)
        for k in range(4):
            height = (9, 7, 5, 3)[k] - (i + k) % 2
            c.rect(2 + k * 4, 11 - height, 4 + k * 4, 11, (P.SAND, P.BROWN_L, P.BROWN, P.BROWN_D)[k])
        shock.append(c.outline())
    out.append(hazard("shockwave", (20, 12), shock, fps=12))

    boulder = []
    for i in range(4):
        c = Canvas(16, 16)
        c.ellipse(7.5, 7.5, 6.5, 6.5, P.GREY)
        angle = i / 4 * math.tau
        c.ellipse(7.5 + math.cos(angle) * 3, 7.5 + math.sin(angle) * 3, 2, 2, P.GREY_D)
        c.px(7.5 - math.cos(angle) * 3, 7.5 - math.sin(angle) * 3, P.GREY_L)
        boulder.append(c.outline())
    out.append(hazard("boulder", (16, 16), boulder, fps=12))

    frost = []
    for i in range(3):
        c = Canvas(44, 14)
        rnd = noise(100 + i)
        for k in range(9):
            x = 4 + k * 4.4
            radius = 5.5 - k * 0.45 + rnd()
            c.ellipse(x, 13 - radius, radius, radius, (P.WHITE, P.BLUE_L)[(k + i) % 2])
        frost.append(c.outline(P.BLUE))
    out.append(hazard("frost", (44, 14), frost, fps=10))

    tail = []
    for i in range(2):
        c = Canvas(64, 14)
        for k in range(15):
            x = 4 + k * 4
            c.ellipse(x, 7 + math.sin(k / 2 + i * math.pi) * 1.5, 5 - k * 0.2, 5 - k * 0.2, P.BLUE_L if k % 3 else P.BLUE)
        c.poly([(0, 7), (6, 2), (6, 12)], P.BLUE_D)
        tail.append(c.outline())
    out.append(hazard("tail", (64, 14), tail, fps=8))

    spike = []
    for height in (16, 15):
        c = Canvas(12, 18)
        c.poly([(1, 17), (5.5, 17 - height), (10, 17)], P.BLUE_L)
        c.poly([(1, 17), (5.5, 17 - height), (4, 17)], P.BLUE)
        c.line((6, 17 - height + 3), (7, 15), P.WHITE)
        spike.append(c.outline(P.BLUE_D))
    out.append(hazard("icespike", (12, 18), spike, fps=6))

    orb = []
    for i in range(4):
        c = Canvas(14, 14)
        c.ellipse(6.5, 6.5, 5.5, 5.5, P.PURPLE_D)
        c.ellipse(6.5, 6.5, 4, 4, P.PURPLE)
        angle = i / 4 * math.tau
        c.ellipse(6.5 + math.cos(angle) * 2, 6.5 + math.sin(angle) * 2, 1.2, 1.2, P.PURPLE_L)
        c.px(6.5 + math.cos(angle) * 2, 6.5 + math.sin(angle) * 2, P.WHITE)
        orb.append(c.outline())
    out.append(hazard("orb", (14, 14), orb, fps=12))

    lightning = []
    for i in range(3):
        c = Canvas(12, 20)
        rnd = noise(200 + i)
        x = 6.0
        for y in range(0, 19, 3):
            nx = min(9.0, max(2.0, x + (rnd() - 0.5) * 7))
            c.line((x, y), (nx, y + 3), P.YELLOW, 2)
            c.line((x, y), (nx, y + 3), P.WHITE)
            x = nx
        c.rect(2, 18, 9, 19, P.ORANGE)
        lightning.append(c)
    out.append(hazard("lightning", (12, 20), lightning, fps=14))

    wave = []
    for i in range(3):
        c = Canvas(34, 14)
        for k in range(8):
            height = 12 - k * 1.2 - (i + k) % 2
            c.rect(2 + k * 4, 13 - height, 5 + k * 4, 13, (P.RED, P.ORANGE, P.RED_D)[(k + i) % 3])
            c.px(3 + k * 4, 13 - height, P.YELLOW)
        wave.append(c.outline(P.BLACK))
    out.append(hazard("wave", (34, 14), wave, fps=12))

    blade = []
    for i in range(2):
        c = Canvas(72, 16)
        c.poly([(1, 8), (30, 2 + i), (70, 5), (70, 10), (30, 13 - i)], P.GREY)
        c.poly([(1, 8), (30, 5), (70, 7), (30, 10)], P.GREY_L)
        c.line((6, 8), (60, 8), P.WHITE)
        blade.append(c.outline(P.RED_D))
    out.append(hazard("blade", (72, 16), blade, fps=10))

    c = Canvas(12, 5)
    c.line((2, 2), (10, 2), P.SAND)
    c.poly([(0, 2), (3, 0), (3, 4)], P.GREY_L)
    c.line((9, 1), (11, 0), P.WHITE)
    c.line((9, 3), (11, 4), P.WHITE)
    out.append(hazard("arrow", (12, 5), [c.outline()]))
    return out


def build() -> list[Sprite]:
    return [tree(), root(), icicle(), coin(), medal(), shrine(), heart("heart_full", P.RED, P.WHITE),
            heart("heart_empty", P.SLATE, P.GREY_D), *hazards()]
