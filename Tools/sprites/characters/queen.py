"""The masked sorceress queen, level 3 boss (64x96)."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, sink, tint
from sprite import Sprite

SIZE = (64, 96)
CX, GROUND = 30, 94
BODY = Body(head=(10, 11), torso=(12, 22), thigh=22, shin=22, upper=13, fore=12, limb=3, robe=True,
            skin=P.GREY_L, skin_d=P.GREY, hair=None, top=P.WHITE, top_d=P.PALE, legs=P.PALE, legs_d=P.PALE_D,
            eye=P.BLACK, belt=P.PURPLE)


def figure(near_arm, far_arm, glow: float = 0.0, orb: float = 0.0, sway: float = 0.0) -> Canvas:
    c = Canvas(*SIZE)

    def hair_behind(canvas):
        x, y = CX + 0.5 + sway, GROUND - 44 - 22 - 6
        canvas.poly([(x - 6, y - 5), (x + 3, y - 6), (x - 2 - sway * 2, y + 34), (x - 12 - sway * 3, y + 38)], P.WHITE)
        canvas.poly([(x - 6, y - 5), (x - 3, y - 5), (x - 9 - sway * 3, y + 36), (x - 12 - sway * 3, y + 38)], P.PALE)

    def regalia(canvas, joints):
        x, y = joints["head"]
        for spike in (-4, -1, 2):                                  # crown
            canvas.poly([(x + spike - 1, y - 5), (x + spike, y - 10 - (spike == -1) * 2), (x + spike + 1, y - 5)], P.GOLD)
        canvas.rect(x - 5, y - 6, x + 4, y - 5, P.GOLD_D)
        canvas.rect(x + 1, y - 1, x + 3, y - 1, P.BLACK)           # mask eye slit
        canvas.rect(x - 3, y - 1, x - 2, y - 1, P.BLACK)
        canvas.rect(x, y + 3, x + 2, y + 3, P.GREY)                # mask mouth line
        for name, amount in (("near_hand", glow), ("far_hand", glow)):
            if amount > 0:
                hx, hy = joints[name]
                canvas.ellipse(hx, hy - 1, 2 + amount * 3, 2 + amount * 3, P.PURPLE)
                canvas.ellipse(hx, hy - 1, 1 + amount * 1.5, 1 + amount * 1.5, P.PURPLE_L)
        if orb > 0:
            hx, hy = joints["near_hand"]
            canvas.ellipse(hx + 4, hy, 2 + orb * 5, 2 + orb * 5, P.PURPLE_D)
            canvas.ellipse(hx + 4, hy, 1 + orb * 3.5, 1 + orb * 3.5, P.PURPLE)
            canvas.ellipse(hx + 5, hy - 1, orb * 1.5, orb * 1.5, P.WHITE)

    hair_behind(c)
    humanoid(c, BODY, Pose(near_arm=near_arm, far_arm=far_arm, head_dx=sway, extras=[regalia]), CX, GROUND)
    return c


def build() -> list[Sprite]:
    queen = Sprite("boss_queen", SIZE, faces_left=True, cx=CX, ground=GROUND)
    queen.add("idle", [
        figure((12 + s * 3, 20), (-10 - s * 3, 15), sway=s).outline() for s in (0, 1, 0, -1)
    ], fps=4)
    queen.add("summon", [
        figure((30 + t * 120, 20 - t * 20), (-30 - t * 120, -20 + t * 20), glow=t).outline()
        for t in (0.0, 0.35, 0.7, 1.0, 1.0, 0.5)
    ], fps=9, loop=False)
    queen.add("cast", [
        figure((20 + t * 68, 30 - t * 30), (-15, 25), orb=o).outline()
        for t, o in ((0.0, 0.0), (0.5, 0.3), (1.0, 0.7), (1.0, 1.0), (1.0, 0.0), (0.4, 0.0))
    ], fps=10, loop=False)
    reel = figure((120, 0), (-110, 0), sway=-2).outline()
    queen.add("hurt", [tint(reel.img, P.WHITE, 0.8), reel.img], fps=10)
    queen.add("death", [sink(reel.img, t / 7, depth=14) for t in range(8)], fps=8, loop=False)
    return [queen]
