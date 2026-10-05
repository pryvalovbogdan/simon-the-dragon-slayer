"""The undead storm lord, final boss (96x128): a shadow wrapped in red flame, antlered and sword-armed."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, noise, sink, tint
from sprite import Sprite

SIZE = (96, 128)
CX, GROUND = 44, 126
BODY = Body(head=(12, 13), torso=(18, 30), thigh=30, shin=30, upper=19, fore=18, limb=4, robe=True,
            skin=P.BLACK, skin_d=P.BLACK, hair=None, top=P.SLATE, top_d=P.BLACK, legs=P.BLACK, legs_d=P.SLATE,
            eye=P.RED, belt=P.RED_D)


def aura(c: Canvas, seed: int, power: float) -> None:
    """Flame tongues rising behind the figure; `power` scales their height."""
    rnd = noise(seed)
    for i in range(22):
        x = CX - 22 + i * 2 + (rnd() - 0.5) * 3
        base = GROUND - 8 - rnd() * 70
        height = (10 + rnd() * 26) * power
        width = 3 + rnd() * 4
        color = (P.RED_D, P.RED, P.ORANGE)[int(rnd() * 2.4)]
        c.poly([(x - width, base), (x + width, base), (x + (rnd() - 0.5) * 6, base - height)], color)


def bolt(c: Canvas, start, end, seed: int) -> None:
    rnd = noise(seed)
    points = [start]
    for i in range(1, 7):
        t = i / 7
        points.append((start[0] + (end[0] - start[0]) * t + (rnd() - 0.5) * 12,
                       start[1] + (end[1] - start[1]) * t))
    points.append(end)
    for a, b in zip(points, points[1:]):
        c.line(a, b, P.YELLOW, 3)
        c.line(a, b, P.WHITE, 1)


def figure(near_arm, far_arm=(-20, 20), seed: int = 0, power: float = 1.0, sword: float = 20,
           lightning: int = 0) -> Canvas:
    """`sword` is the blade angle measured from straight up, positive leaning forward."""
    c = Canvas(*SIZE)
    aura(c, seed, power)

    def regalia(canvas, joints):
        x, y = joints["head"]
        for side in (-1, 1):                                            # antlers
            root = (x + side * 4, y - 6)
            tip = (root[0] + side * 12, root[1] - 20)
            canvas.line(root, tip, P.GREY_D, 2)
            for k in (0.35, 0.65, 0.9):
                bx, by = root[0] + (tip[0] - root[0]) * k, root[1] + (tip[1] - root[1]) * k
                canvas.line((bx, by), (bx + side * 6, by - 7), P.GREY_D, 2)
        canvas.rect(x + 1, y - 1, x + 4, y, P.RED)                       # burning eyes
        canvas.rect(x - 4, y - 1, x - 2, y, P.RED)
        canvas.px(x + 2, y - 1, P.YELLOW)
        hx, hy = joints["near_hand"]
        rad = math.radians(sword)
        tip = (hx + math.sin(rad) * 44, hy - math.cos(rad) * 44)
        canvas.line((hx, hy), tip, P.GREY, 3)                            # the grey sword
        canvas.line((hx, hy), tip, P.GREY_L, 1)
        cross = (math.cos(rad) * 6, math.sin(rad) * 6)
        canvas.line((hx - cross[0], hy - cross[1]), (hx + cross[0], hy + cross[1]), P.GREY_D, 2)
        for i in range(lightning):
            bolt(canvas, tip, (tip[0] + 14 + i * 16, GROUND), seed * 7 + i)

    humanoid(c, BODY, Pose(near_arm=near_arm, far_arm=far_arm, extras=[regalia]), CX, GROUND)
    return c


def build() -> list[Sprite]:
    king = Sprite("boss_stormking", SIZE, faces_left=True, cx=CX, ground=GROUND)
    king.add("idle", [
        figure((35, 30), seed=i, power=0.9 + 0.1 * math.sin(i / 6 * math.tau), sword=25).outline() for i in range(6)
    ], fps=8)
    raise_arm = [(35, 30), (90, 30), (150, 10), (170, 0), (170, 0), (170, 0), (120, 10), (60, 30)]
    blade = [25, 10, -5, -10, -10, -10, 5, 20]
    bolts = [0, 0, 0, 1, 2, 2, 1, 0]
    king.add("lightning", [
        figure(raise_arm[i], seed=10 + i, power=1.0 + 0.1 * i, sword=blade[i], lightning=bolts[i]).outline()
        for i in range(8)
    ], fps=10, loop=False)
    king.add("phase", [
        tint(figure((150, 10), (-150, -10), seed=30 + i, power=1.2 + 0.25 * i, sword=-10).outline().img,
             P.RED, 0.25 if i % 2 else 0.0)
        for i in range(6)
    ], fps=10, loop=False)
    reel = figure((120, 0), (-110, 0), seed=50, power=0.6, sword=60).outline()
    king.add("hurt", [tint(reel.img, P.WHITE, 0.8), reel.img], fps=10)
    king.add("death", [sink(figure((120, 0), (-110, 0), seed=60 + t, power=max(0.1, 0.8 - t * 0.08), sword=60 + t * 8)
                            .outline().img, t / 9, depth=18) for t in range(10)], fps=8, loop=False)
    return [king]
