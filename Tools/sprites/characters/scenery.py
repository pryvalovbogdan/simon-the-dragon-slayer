"""Backgrounds and ground tiles. Each level theme has a sky, two horizontally tileable parallax layers
and a ground tile."""
import palette as P
from draw import Canvas, noise
from sprite import Sprite

LAYER_W = 320


def single(name: str, canvas: Canvas) -> Sprite:
    sprite = Sprite(name, canvas.size)
    sprite.add("still", [canvas], fps=1)
    return sprite


def sky(theme: str, bands: list) -> Sprite:
    c = Canvas(16, 200)
    step = 200 / len(bands)
    for i, color in enumerate(bands):
        c.rect(0, i * step, 15, (i + 1) * step, color)
    return single(f"bg_{theme}_sky", c)


def wrapped(c: Canvas, draw, x: float) -> None:
    """Calls `draw(x)` at x and one layer-width either side, so shapes crossing an edge tile seamlessly."""
    for offset in (-LAYER_W, 0, LAYER_W):
        draw(x + offset)


def peaks(theme: str, layer: str, height: int, seed: int, count: int, tall: tuple[int, int], width: tuple[int, int],
          color, cap=None) -> Sprite:
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 20
        h = tall[0] + rnd() * (tall[1] - tall[0])
        w = width[0] + rnd() * (width[1] - width[0])

        def one(px, h=h, w=w):
            c.poly([(px - w, height), (px, height - h), (px + w, height)], color)
            if cap:
                c.poly([(px - w * 0.25, height - h * 0.75), (px, height - h), (px + w * 0.25, height - h * 0.75),
                        (px + w * 0.08, height - h * 0.68), (px - w * 0.1, height - h * 0.7)], cap)
        wrapped(c, one, x)
    return single(f"bg_{theme}_{layer}", c)


def trees(theme: str, layer: str, height: int, seed: int, count: int, trunk, leaf, leaf_light) -> Sprite:
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 14
        h = height * (0.55 + rnd() * 0.4)
        spread = 10 + rnd() * 8

        def one(px, h=h, spread=spread):
            c.rect(px - 2, height - h * 0.5, px + 2, height, trunk)
            for k in range(3):
                top = height - h + k * h * 0.18
                c.poly([(px - spread * (0.6 + k * 0.2), top + h * 0.3), (px, top), (px + spread * (0.6 + k * 0.2), top + h * 0.3)], leaf)
            c.poly([(px - spread * 0.3, height - h + h * 0.18), (px, height - h), (px + 2, height - h + h * 0.2)], leaf_light)
        wrapped(c, one, x)
    return single(f"bg_{theme}_{layer}", c)


def spires(theme: str, layer: str, height: int, seed: int, count: int, color, window) -> Sprite:
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 16
        h = height * (0.4 + rnd() * 0.55)
        w = 7 + rnd() * 9

        def one(px, h=h, w=w, lit=rnd() > 0.4):
            c.rect(px - w, height - h, px + w, height, color)
            c.poly([(px - w - 2, height - h), (px, height - h - w * 1.6), (px + w + 2, height - h)], color)
            if window and lit:
                for row in range(int(h // 18)):
                    c.rect(px - 1, height - h + 8 + row * 18, px + 1, height - h + 12 + row * 18, window)
        wrapped(c, one, x)
    return single(f"bg_{theme}_{layer}", c)


def ground(theme: str, top, top_light, fill, speck, seed: int) -> Sprite:
    c = Canvas(32, 48)
    c.rect(0, 0, 31, 47, fill)
    c.rect(0, 0, 31, 4, top)
    c.rect(0, 0, 31, 0, top_light)
    rnd = noise(seed)
    for x in range(0, 32, 4):
        c.rect(x, 5, x + 1, 5 + int(rnd() * 3), top)
    for _ in range(26):
        x, y = int(rnd() * 31), 9 + int(rnd() * 38)
        c.rect(x, y, x + int(rnd() * 2), y, speck)
    return single(f"ground_{theme}", c)


def ground_fill(theme: str, fill) -> Sprite:
    """Plain earth colour; stretched under the ground tile where the scene is taller than the tile."""
    c = Canvas(8, 8)
    c.rect(0, 0, 7, 7, fill)
    return single(f"ground_{theme}_fill", c)


def build() -> list[Sprite]:
    return [
        sky("forest", [P.BLUE, P.BLUE, P.BLUE, P.BLUE_L, P.BLUE_L]),
        trees("forest", "far", 110, 1, 9, P.FOREST, P.FOREST, P.GREEN_D),
        trees("forest", "near", 150, 2, 6, P.BROWN_D, P.GREEN_D, P.GREEN),
        ground("forest", P.GREEN, P.GREEN_L, P.BROWN, P.BROWN_D, 3),
        ground_fill("forest", P.BROWN),

        sky("mountain", [P.BLUE_D, P.BLUE, P.BLUE, P.BLUE_L, P.BLUE_L]),
        peaks("mountain", "far", 150, 4, 5, (80, 145), (50, 80), P.BLUE_D, P.WHITE),
        peaks("mountain", "near", 100, 5, 7, (40, 90), (30, 55), P.GREY_D, P.BLUE_L),
        ground("mountain", P.WHITE, P.WHITE, P.GREY_L, P.BLUE_L, 6),
        ground_fill("mountain", P.GREY_L),

        sky("wastes", [P.NAVY, P.NAVY, P.PURPLE_D, P.PURPLE_D, P.PALE_D]),
        peaks("wastes", "far", 130, 7, 4, (60, 125), (60, 100), P.SLATE, P.PALE_D),
        peaks("wastes", "near", 70, 8, 9, (20, 60), (14, 30), P.GREY_D, None),
        ground("wastes", P.PALE, P.WHITE, P.GREY, P.GREY_D, 9),
        ground_fill("wastes", P.GREY),

        sky("tower", [P.BLACK, P.BLACK, P.RED_D, P.RED_D, P.RED]),
        spires("tower", "far", 150, 10, 8, P.BLACK, None),
        spires("tower", "near", 160, 11, 5, P.SLATE, P.ORANGE),
        ground("tower", P.GREY_D, P.GREY, P.SLATE, P.BLACK, 12),
        ground_fill("tower", P.SLATE),
    ]
