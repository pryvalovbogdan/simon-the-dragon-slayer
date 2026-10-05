"""Goblin (24x24): small forest raider."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, stride, swing, topple
from sprite import Sprite

SIZE = (24, 24)
CX, GROUND = 10, 22
BODY = Body(head=(8, 7), torso=(5, 5), thigh=3, shin=3, upper=3, fore=3, skin=P.GREEN_L, skin_d=P.GREEN,
            hair=None, top=P.BROWN, top_d=P.BROWN_D, legs=P.BROWN_D, legs_d=P.BLACK, boots=P.BLACK,
            eye=P.RED, belt=None)


def gear(c, joints):
    x, y = joints["head"]
    c.poly([(x - 4, y - 1), (x - 7, y - 4), (x - 3, y - 3)], P.GREEN_L)   # ear
    hx, hy = joints["near_hand"]
    c.line((hx, hy), (hx + 4, hy - 4), P.GREY_L)                           # dagger


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
