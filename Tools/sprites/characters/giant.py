"""Shaggy white giants: the roaming giant (48x64) and the level 1 boss (96x96)."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, stride, swing, tint, topple
from sprite import Sprite

GIANT = dict(size=(48, 64), cx=15, ground=62, club=12, horns=False,
             body=Body(head=(12, 11), torso=(16, 20), thigh=11, shin=11, upper=10, fore=10, limb=5,
                       skin=P.PALE, skin_d=P.PALE_D, hair=P.WHITE, top=P.WHITE, top_d=P.GREY_L,
                       legs=P.GREY_L, legs_d=P.GREY, boots=P.GREY_D, eye=P.RED, belt=P.BROWN))
CHIEF = dict(size=(96, 96), cx=30, ground=94, club=24, horns=True,
             body=Body(head=(18, 16), torso=(26, 30), thigh=17, shin=17, upper=16, fore=16, limb=8,
                       skin=P.PALE_D, skin_d=P.GREY, hair=P.GREY_L, top=P.GREY_L, top_d=P.GREY,
                       legs=P.GREY, legs_d=P.GREY_D, boots=P.SLATE, eye=P.RED, belt=P.BROWN_D))


def figure(kind: dict, pose: Pose, club_angle: float = -20, impact: int = 0) -> Canvas:
    c = Canvas(*kind["size"])
    body: Body = kind["body"]

    def gear(canvas, joints):
        hx, hy = joints["near_hand"]
        rad = math.radians(club_angle)
        tip = (hx + math.sin(rad) * kind["club"], hy - math.cos(rad) * kind["club"])
        canvas.line((hx, hy), tip, P.BROWN, max(2, body.limb - 2))
        canvas.ellipse(tip[0], tip[1], body.limb * 0.8, body.limb * 0.8, P.BROWN_D)
        x, y = joints["head"]
        hw, hh = body.head
        # shaggy fringe under the chin and across the shoulders
        for i in range(0, hw + 4, 2):
            canvas.px(x - hw / 2 - 2 + i, y + hh / 2 + (i % 4 == 0), body.hair)
        if kind["horns"]:
            canvas.line((x - hw / 2 + 1, y - hh / 2), (x - hw / 2 - 5, y - hh / 2 - 8), P.SAND, 3)
            canvas.line((x + hw / 2 - 2, y - hh / 2), (x + hw / 2 + 4, y - hh / 2 - 8), P.SAND, 3)
        for i in range(impact):  # dust and cracks where the club lands
            canvas.rect(tip[0] - 6 + i * 5, kind["ground"] - 1 - (i % 2) * 3, tip[0] - 4 + i * 5, kind["ground"], P.SAND)

    pose.extras.append(gear)
    humanoid(c, body, pose, kind["cx"], kind["ground"])
    return c


def walk(kind: dict, frames: int) -> list[Canvas]:
    out = []
    for i in range(frames):
        phase = i / frames * math.tau
        legs, arms = stride(phase, swing=26, bend=30), swing(phase, amount=18, bend=25)
        out.append(figure(kind, Pose(near_leg=legs[0], far_leg=legs[1], near_arm=(arms[0][0] + 20, 40),
                                     far_arm=arms[1], lean=1)).outline())
    return out


def swing_frames(kind: dict, frames: int) -> list[Canvas]:
    """Club goes back over the head, then crashes down in front."""
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        if t < 0.5:  # wind-up: arm travels backward and up
            angle, lean = -10 - 120 * t * 2, -2 * t * 2
        else:        # strike: over the top (230 is the same direction as -130) and down in front
            u = min((t - 0.5) * 2 * 1.6, 1)
            angle, lean = 230 - 150 * u, -2 + 5 * u
        landed = t >= 0.8
        # The club continues the line of the arm; club angles are measured from straight up.
        out.append(figure(kind, Pose(near_leg=(22, 14), far_leg=(-22, 10), near_arm=(angle, 0), far_arm=(-25, 30),
                                     lean=lean, crouch=2 if landed else 0),
                          club_angle=180 - angle, impact=3 if landed else 0).outline())
    return out


def build() -> list[Sprite]:
    giant = Sprite("giant", GIANT["size"], faces_left=True, cx=GIANT["cx"], ground=GIANT["ground"])
    giant.add("walk", walk(GIANT, 6), fps=7)
    giant.add("swing", swing_frames(GIANT, 6), fps=10, loop=False)
    stagger = figure(GIANT, Pose(near_leg=(25, 10), far_leg=(-10, 25), near_arm=(120, 0), far_arm=(-100, 0), lean=-3)).outline()
    giant.add("hurt", [tint(stagger.img, P.WHITE, 0.8), stagger.img], fps=10)
    giant.add("death", [topple(stagger.img, t / 5, (GIANT["cx"], GIANT["ground"])) for t in range(6)], fps=8, loop=False)

    chief = Sprite("boss_giant", CHIEF["size"], faces_left=True, cx=CHIEF["cx"], ground=CHIEF["ground"])
    chief.add("idle", [
        figure(CHIEF, Pose(near_leg=(14, 8), far_leg=(-14, 8), near_arm=(25, 40), far_arm=(-15, 25), head_dy=dy,
                           crouch=dy), club_angle=-25 + dy * 4).outline()
        for dy in (0, 1, 2, 1)
    ], fps=5)
    chief.add("slam", swing_frames(CHIEF, 8), fps=10, loop=False)
    chief.add("stunned", [
        figure(CHIEF, Pose(near_leg=(30, 30), far_leg=(-20, 30), near_arm=(60, 30), far_arm=(-30, 40), lean=3 + sway,
                           crouch=6, head_dy=3, head_dx=sway), club_angle=100).outline()
        for sway in (0, 1, 0, -1)
    ], fps=6)
    reel = figure(CHIEF, Pose(near_leg=(25, 10), far_leg=(-10, 25), near_arm=(120, 0), far_arm=(-100, 0), lean=-5)).outline()
    chief.add("hurt", [tint(reel.img, P.WHITE, 0.8), reel.img], fps=10)
    chief.add("death", [topple(reel.img, t / 7, (CHIEF["cx"], CHIEF["ground"])) for t in range(8)], fps=8, loop=False)
    return [giant, chief]
