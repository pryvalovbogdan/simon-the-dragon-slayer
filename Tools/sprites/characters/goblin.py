"""Goblin (32x32): small forest raider, tall enough to show over the undergrowth."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, stride, swing, topple
from sprite import Sprite

SIZE = (32, 32)
CX, GROUND = 13, 30
BODY = Body(head=(10, 9), torso=(7, 7), thigh=4, shin=4, upper=4, fore=4, skin=P.GREEN_L, skin_d=P.GREEN,
            hair=None, top=P.BROWN, top_d=P.BROWN_D, legs=P.BROWN_D, legs_d=P.BLACK, boots=P.BLACK,
            eye=P.RED, belt=None)


def gear(c, joints):
    x, y = joints["head"]
    c.poly([(x - 5, y - 1), (x - 9, y - 5), (x - 4, y - 4)], P.GREEN_L)   # ear
    hx, hy = joints["near_hand"]
    c.line((hx, hy), (hx + 5, hy - 5), P.GREY_L)                           # dagger


def figure(pose: Pose) -> Canvas:
    c = Canvas(*SIZE)
    pose.extras.append(gear)
    humanoid(c, BODY, pose, CX, GROUND)
    return c


def build() -> list[Sprite]:
    goblin = Sprite("goblin", SIZE, faces_left=True, cx=CX, ground=GROUND)
    walk = []
    for i in range(6):
        phase = i / 6 * math.tau
        legs, arms = stride(phase, swing=34, bend=40), swing(phase, amount=25, bend=50)
        walk.append(figure(Pose(near_leg=legs[0], far_leg=legs[1], near_arm=(arms[0][0] + 40, 30), far_arm=arms[1],
                                lean=1)).outline())
    goblin.add("walk", walk, fps=10)
    base = walk[0].img
    goblin.add("death", [topple(base, t / 3, (CX, GROUND)) for t in range(4)], fps=10, loop=False)
    return [goblin]
