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


EARTH_TOP = 12


def ground(theme: str, top, top_light, fill, speck, seed: int) -> list[Sprite]:
    """The ground tile, and its grassless lower part as a tile of its own for stacking underneath
    where the earth runs deeper than one tile. The game never cuts pieces out of a texture itself:
    on a device the atlas packs textures together and a cut-out shows its neighbours."""
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
    earth = Canvas(32, 48 - EARTH_TOP)
    earth.paste(c.img.crop((0, EARTH_TOP, 32, 48)))
    return [single(f"ground_{theme}", c), single(f"ground_{theme}_earth", earth)]


def flat(name: str, color) -> Sprite:
    """One plain colour, for the game to stretch over an area."""
    c = Canvas(8, 8)
    c.rect(0, 0, 7, 7, color)
    return single(name, c)


def ground_fill(theme: str, fill) -> Sprite:
    """Plain earth colour; stretched under the ground tile where the scene is taller than the tile."""
    c = Canvas(8, 8)
    c.rect(0, 0, 7, 7, fill)
    return single(f"ground_{theme}_fill", c)


def ravine(theme: str, top, top_light, rock, rock_dark, seed: int) -> Sprite:
    """Left wall of a ravine, as tall as the ground tile; the game mirrors it for the right wall."""
    c = Canvas(8, 48)
    rnd = noise(seed)
    for y in range(5, 48):
        # Ragged rock that thins out as it drops into the dark.
        reach = 1 + int(rnd() * 3) if y < 30 else int(rnd() * 2)
        c.rect(0, y, reach, y, rock if y < 18 else rock_dark)
        if y < 18:
            c.px(reach, y, rock_dark)
    # The turf curls over the rim.
    for y, reach in enumerate((5, 5, 4, 3, 2)):
        c.rect(0, y, reach, y, top)
    c.rect(0, 0, 4, 0, top_light)
    return single(f"ravine_{theme}", c)


def ravine_fill(theme: str, deep) -> Sprite:
    """The dark between the walls: horizontal bands only, so the game can stretch it to any width."""
    c = Canvas(8, 48)
    c.rect(0, 0, 7, 47, P.BLACK)
    c.rect(0, 0, 7, 15, deep)
    return single(f"ravine_{theme}_fill", c)


def clouds(theme: str, height: int, seed: int, color) -> Sprite:
    """A bank of cloud: puffs along the top, solid below, so it can stand on the horizon."""
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    top = height * 0.42
    c.rect(0, top, LAYER_W - 1, height - 1, color)
    count = 13
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 10
        radius = 12 + rnd() * 16
        y = top + rnd() * 8
        wrapped(c, lambda px, y=y, radius=radius: c.ellipse(px, y, radius, radius * 0.8, color), x)
    return single(f"bg_{theme}_clouds", c)


def puffs(theme: str, seed: int, color) -> Sprite:
    """Small clouds on their own, for the open sky above the horizon."""
    height = 120
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    count = 5
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 30
        y = 24 + rnd() * (height - 44)
        w = 13 + rnd() * 11

        def one(px, y=y, w=w):
            c.ellipse(px, y, w, w * 0.32, color)
            c.ellipse(px - w * 0.35, y - w * 0.22, w * 0.42, w * 0.36, color)
            c.ellipse(px + w * 0.2, y - w * 0.32, w * 0.5, w * 0.46, color)
        wrapped(c, one, x)
    return single(f"bg_{theme}_puffs", c)


def bushes(theme: str, height: int, seed: int, leaf, leaf_light) -> Sprite:
    c = Canvas(LAYER_W, height)
    rnd = noise(seed)
    c.rect(0, height * 0.7, LAYER_W - 1, height - 1, leaf)
    count = 20
    for i in range(count):
        x = i * LAYER_W / count + rnd() * 8
        radius = height * (0.27 + rnd() * 0.23)
        y = height - radius * 0.6

        def one(px, y=y, radius=radius):
            c.ellipse(px, y, radius, radius, leaf)
            c.ellipse(px - radius * 0.25, y - radius * 0.35, radius * 0.45, radius * 0.35, leaf_light)
        wrapped(c, one, x)
    return single(f"bg_{theme}_bushes", c)


def build() -> list[Sprite]:
    return [
        sky("forest", [P.BLUE, P.BLUE, P.BLUE, P.BLUE_L, P.BLUE_L]),
        trees("forest", "far", 110, 1, 9, P.FOREST, P.FOREST, P.GREEN_D),
        trees("forest", "near", 150, 2, 6, P.BROWN_D, P.GREEN_D, P.GREEN),
        *ground("forest", P.GREEN, P.GREEN_L, P.BROWN, P.BROWN_D, 3),
        flat("bg_forest_sky_top", P.BLUE),
        flat("ravine_forest_deep", P.BLACK),
        ground_fill("forest", P.BROWN),
        ravine("forest", P.GREEN, P.GREEN_L, P.BROWN_D, P.OUTLINE, 13),
        ravine_fill("forest", P.OUTLINE),
        clouds("forest", 170, 20, P.WHITE),
        puffs("forest", 21, P.WHITE),
        bushes("forest", 18, 22, P.GREEN_D, P.GREEN),

        sky("mountain", [P.BLUE_D, P.BLUE, P.BLUE, P.BLUE_L, P.BLUE_L]),
        peaks("mountain", "far", 150, 4, 5, (80, 145), (50, 80), P.BLUE_D, P.WHITE),
        peaks("mountain", "near", 100, 5, 7, (40, 90), (30, 55), P.GREY_D, P.BLUE_L),
        *ground("mountain", P.WHITE, P.WHITE, P.GREY_L, P.BLUE_L, 6),
        flat("bg_mountain_sky_top", P.BLUE_D),
        flat("ravine_mountain_deep", P.BLACK),
        ground_fill("mountain", P.GREY_L),
        ravine("mountain", P.WHITE, P.WHITE, P.GREY, P.GREY_D, 14),
        ravine_fill("mountain", P.NAVY),
        clouds("mountain", 170, 23, P.WHITE),
        puffs("mountain", 24, P.WHITE),
        bushes("mountain", 18, 25, P.GREY_L, P.WHITE),

        sky("wastes", [P.NAVY, P.NAVY, P.PURPLE_D, P.PURPLE_D, P.PALE_D]),
        peaks("wastes", "far", 130, 7, 4, (60, 125), (60, 100), P.SLATE, P.PALE_D),
        peaks("wastes", "near", 70, 8, 9, (20, 60), (14, 30), P.GREY_D, None),
        *ground("wastes", P.PALE, P.WHITE, P.GREY, P.GREY_D, 9),
        flat("bg_wastes_sky_top", P.NAVY),
        flat("ravine_wastes_deep", P.BLACK),
        ground_fill("wastes", P.GREY),
        ravine("wastes", P.PALE, P.WHITE, P.GREY_D, P.SLATE, 15),
        ravine_fill("wastes", P.OUTLINE),
        clouds("wastes", 170, 26, P.PALE_D),
        puffs("wastes", 27, P.PALE_D),
        bushes("wastes", 18, 28, P.GREY_D, P.GREY),

        sky("tower", [P.BLACK, P.BLACK, P.RED_D, P.RED_D, P.RED]),
        spires("tower", "far", 150, 10, 8, P.BLACK, None),
        spires("tower", "near", 160, 11, 5, P.SLATE, P.ORANGE),
        *ground("tower", P.GREY_D, P.GREY, P.SLATE, P.BLACK, 12),
        flat("bg_tower_sky_top", P.BLACK),
        flat("ravine_tower_deep", P.BLACK),
        ground_fill("tower", P.SLATE),
        ravine("tower", P.GREY_D, P.GREY, P.OUTLINE, P.BLACK, 16),
        ravine_fill("tower", P.OUTLINE),
        clouds("tower", 150, 29, P.PURPLE_D),
        puffs("tower", 30, P.PURPLE_D),
        bushes("tower", 18, 31, P.BLACK, P.SLATE),

        # The start screen: a bright morning for the hero to run through.
        sky("menu", [P.BLUE]),
        clouds("menu", 110, 17, P.WHITE),
        puffs("menu", 32, P.WHITE),
        trees("menu", "horizon", 80, 18, 12, P.BLUE_L, P.BLUE_L, P.BLUE_L),
        bushes("menu", 26, 19, P.GREEN, P.GREEN_L),
    ]
