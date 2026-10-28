"""The ice dragon, level 2 boss (184x96)."""
import math

import palette as P
from draw import Canvas, sink, tint
from sprite import Sprite

SIZE = (184, 96)
GROUND = 94
TAIL_ROOM = 42  # canvas to the left of the old 128-wide frame, so the whole tail fits


def frame(wing: float = 0.0, neck: float = 0.0, jaw: float = 0.0, tail: float = 0.0,
          sway: float = 0.0) -> Canvas:
    """wing -1..1 (down..up), neck 0..1 (reared..lunging low), jaw 0..1, tail 0..1 (resting..swept forward),
    sway 0..1 (tail tip resting..raised)."""
    c = Canvas(*SIZE)
    body = (48.0 + TAIL_ROOM, 64.0)
    base = (body[0] - 24, body[1] + 2)

    # tail: a chain of shrinking discs; `tail` curls it up and forward over the back
    x, y = base
    for i in range(14):
        k = i / 13
        direction = math.radians(200 - tail * 150 * k + math.sin(k * 3) * 20 - (0.35 + sway) * 40 * k * k)
        x += math.cos(direction) * 4.2
        y -= math.sin(direction) * 4.2
        c.ellipse(x, y, 6.5 * (1 - k) + 1, 6.5 * (1 - k) + 1, P.BLUE_L if i % 3 else P.BLUE)
    c.poly([(x - 3, y - 4), (x + 2, y), (x - 3, y + 4), (x - 8, y)], P.BLUE_D)  # tail spade

    # far wing, then legs, body, near wing
    def wing_shape(shoulder, lift, color, bone):
        sx, sy = shoulder
        tip = (sx - 34, sy - 14 - lift * 26)
        mid = (sx - 12, sy - 22 - lift * 16)
        c.poly([shoulder, mid, tip, (sx - 30, sy + 6 - lift * 6), (sx - 18, sy + 2 - lift * 2),
                (sx - 8, sy + 8)], color)
        c.line(shoulder, mid, bone, 2)
        c.line(mid, tip, bone, 2)
        c.line(mid, (sx - 30, sy + 6 - lift * 6), bone)
        c.line(mid, (sx - 18, sy + 2 - lift * 2), bone)

    wing_shape((body[0] + 4, body[1] - 10), wing * 0.8, P.NAVY, P.BLUE_D)
    for lx in (body[0] - 16, body[0] + 16):  # legs
        c.rect(lx - 4, body[1] + 6, lx + 4, GROUND - 3, P.BLUE)
        c.rect(lx - 5, GROUND - 3, lx + 8, GROUND, P.BLUE_D)
        for claw in range(3):
            c.px(lx - 3 + claw * 4, GROUND, P.WHITE)
    c.ellipse(body[0], body[1], 30, 16, P.BLUE_L)
    c.ellipse(body[0] - 2, body[1] + 7, 24, 8, P.WHITE)       # pale belly
    for i in range(6):                                         # back spines
        c.poly([(body[0] - 22 + i * 8, body[1] - 13 + abs(i - 2.5) * 1.5), (body[0] - 19 + i * 8, body[1] - 20 + abs(i - 2.5) * 1.5),
                (body[0] - 16 + i * 8, body[1] - 13 + abs(i - 2.5) * 1.5)], P.BLUE_D)

    # neck: reared up at neck=0, stretched low and forward at neck=1
    nx, ny = body[0] + 24, body[1] - 8
    for i in range(9):
        k = i / 8
        direction = math.radians(70 - neck * 75 - k * 35 * (1 - neck))
        nx += math.cos(direction) * 4.5
        ny -= math.sin(direction) * 4.5
        c.ellipse(nx, ny, 6.5 - k * 2, 6.5 - k * 2, P.BLUE_L if i % 2 else P.WHITE)
    head = (nx + 6, ny - 1)
    c.poly([(head[0] - 8, head[1] - 6), (head[0] - 16, head[1] - 13), (head[0] - 5, head[1] - 4)], P.GREY_L)  # horns
    c.poly([(head[0] - 4, head[1] - 6), (head[0] - 10, head[1] - 15), (head[0] - 1, head[1] - 5)], P.WHITE)
    c.ellipse(head[0], head[1], 9, 6, P.BLUE_L)
    c.poly([(head[0] + 4, head[1] - 5), (head[0] + 19, head[1] - 2), (head[0] + 19, head[1] + 1),
            (head[0] + 4, head[1] + 2)], P.BLUE_L)                                         # upper jaw
    drop = jaw * 7
    if jaw > 0.2:
        # the inside of the open mouth, so the gap between the jaws reads as a throat, not a cut
        c.poly([(head[0] + 3, head[1] + 1), (head[0] + 18, head[1] + 1), (head[0] + 17, head[1] + 2 + drop),
                (head[0] + 3, head[1] + 3)], P.RED_D)
        c.line((head[0] + 5, head[1] + 2 + drop * 0.2), (head[0] + 12, head[1] + 2 + drop * 0.6), P.RED)  # tongue
    c.poly([(head[0] + 2, head[1] + 2), (head[0] + 17, head[1] + 2 + drop), (head[0] + 16, head[1] + 5 + drop),
            (head[0] - 2, head[1] + 6)], P.BLUE)                                           # lower jaw
    if jaw > 0.2:
        for tooth in range(3):
            c.px(head[0] + 8 + tooth * 4, head[1] + 2, P.WHITE)                            # upper fangs
            k = (10 + tooth * 3) / 17
            c.px(head[0] + 10 + tooth * 3, head[1] + 1 + drop * k, P.WHITE)                # lower fangs
    c.rect(head[0] + 2, head[1] - 3, head[0] + 4, head[1] - 2, P.YELLOW)                   # eye
    c.px(head[0] + 4, head[1] - 2, P.BLACK)
    c.px(head[0] + 17, head[1] - 2, P.NAVY)                                                # nostril

    wing_shape((body[0] - 2, body[1] - 10), wing, P.BLUE_D, P.BLUE)
    return c


def build() -> list[Sprite]:
    dragon = Sprite("boss_dragon", SIZE, faces_left=True, cx=58 + TAIL_ROOM, ground=GROUND)
    dragon.add("idle", [
        frame(wing=math.sin(i / 6 * math.tau), neck=0.08 + 0.06 * math.sin(i / 6 * math.tau),
              sway=0.5 + 0.5 * math.sin(i / 6 * math.tau + 1.2)).outline()
        for i in range(6)
    ], fps=8)

    # Lunges low with the jaw wide; the frost itself is the rolling hazard. A cloud drawn here had no
    # room past the mouth at the canvas edge and piled up into a column under the jaw.
    dragon.add("breath", [
        frame(wing=0.6, neck=min(i / 3, 1.0) if i < 6 else 1.0 - (i - 5) / 3, jaw=min(i / 2, 1.0)).outline()
        for i in range(8)
    ], fps=10, loop=False)

    # Rears back, then snaps the jaw open skyward to spit the ice shards that land as spikes.
    dragon.add("spit", [
        frame(wing=w, neck=n, jaw=j).outline()
        for w, n, j in ((0.2, 0.1, 0.0), (0.4, 0.05, 0.0), (0.6, 0.0, 0.0), (0.8, 0.0, 0.1),
                        (1.0, 0.0, 0.2), (1.0, 0.03, 0.7), (0.8, 0.05, 1.0), (0.6, 0.05, 1.0))
    ], fps=10, loop=False)

    dragon.add("tail", [
        frame(wing=-0.4, neck=0.15, tail=t).outline() for t in (0.1, 0.45, 0.85, 1.0, 0.6, 0.2)
    ], fps=10, loop=False)

    reel = frame(wing=1.0, neck=0.0, jaw=0.8).outline()
    dragon.add("hurt", [tint(reel.img, P.WHITE, 0.8), reel.img], fps=10)
    slump = frame(wing=-1.0, neck=0.9, jaw=0.5, tail=0.0).outline()
    dragon.add("death", [sink(slump.img if t else reel.img, t / 7, depth=10) for t in range(8)], fps=8, loop=False)
    return [dragon]

