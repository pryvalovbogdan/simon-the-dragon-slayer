"""The hero (32x32) and his fireballs."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, stride, swing, tint, topple
from sprite import Sprite

SIZE = (48, 48)
CX, GROUND = 16, 46
HAIR, HAIR_LIGHT = P.GREY_D, P.GREY
# Chibi proportions: a head as tall as the body, short limbs.
BODY = Body(head=(16, 15), torso=(9, 9), thigh=4.5, shin=4.5, upper=4.5, fore=4.5, limb=3, hair=None,
            eye=P.SKIN, top=P.BROWN, top_d=P.BROWN_D, legs=P.SLATE, legs_d=P.BLACK, boots=P.BROWN_D,
            belt=P.SAND)
BLADE = 14


def figure(pose: Pose, sword: float = 35, fire: float = 0, dust: int = 0) -> Canvas:
    """`sword` is the blade angle from straight up (positive leans forward); `fire` is the size of
    the flame gathering at its tip."""
    c = Canvas(*SIZE)

    def face_and_hair(canvas, joints):
        x, y = joints["head"]
        left, top = x - 8, y - 7.5
        canvas.rect(left, top, left + 15, top + 5, HAIR)             # crown
        canvas.rect(left, top, left + 3, top + 12, HAIR)             # back of the head
        for sx, tip_x, tip_y in ((2, -1, -6), (6, 5, -8), (10, 11, -7), (14, 17, -5)):   # spikes on top
            canvas.poly([(left + sx - 3, top + 1), (left + tip_x, top + tip_y), (left + sx + 3, top + 1)], HAIR)
        for sy, tip in ((3, -5), (9, -5)):                           # spikes at the back
            canvas.poly([(left + 1, top + sy - 3), (left + tip, top + sy), (left + 1, top + sy + 3)], HAIR)
        canvas.poly([(left + 6, top + 5), (left + 9, top + 9), (left + 12, top + 5)], HAIR)   # fringe
        canvas.poly([(left + 12, top + 5), (left + 16, top + 8), (left + 16, top + 5)], HAIR)
        for hx, hy in ((4, 0), (5, -2), (9, -1), (10, -3), (14, 0), (1, 5), (2, 9)):
            canvas.px(left + hx, top + hy, HAIR_LIGHT)
        for eye in (9, 13):                                          # tall cartoon eyes
            canvas.rect(left + eye, top + 9, left + eye + 1, top + 12, P.BLACK)
            canvas.px(left + eye, top + 9, P.WHITE)
        canvas.rect(left + 4, top + 9, left + 5, top + 11, P.SKIN_D)  # ear
        for i in range(3):                                           # the scar across his cheek
            canvas.px(left + 5 + i, top + 12 + i, P.RED)
        canvas.rect(left + 11, top + 14, left + 12, top + 14, P.BROWN_D)   # mouth
        hip_x, hip_y = joints["hip"]                                 # buckle on the belt
        canvas.rect(hip_x + 1, hip_y - 2, hip_x + 2, hip_y - 1, P.GOLD)

    def blade(canvas, joints):
        hx, hy = joints["near_hand"]
        rad = math.radians(sword)
        dx, dy = math.sin(rad), -math.cos(rad)
        tip = (hx + dx * BLADE, hy + dy * BLADE)
        canvas.line((hx - dx * 3, hy - dy * 3), (hx, hy), P.BROWN_D, 2)                 # grip
        canvas.line((hx + dx, hy + dy), tip, P.GREY_L, 3)
        canvas.line((hx + dx * 2, hy + dy * 2), tip, P.WHITE, 1)
        canvas.line((hx - dy * 3, hy + dx * 3), (hx + dy * 3, hy - dx * 3), P.GOLD_D, 2)  # crossguard
        if fire > 0:
            canvas.ellipse(tip[0] + dx, tip[1] + dy, fire, fire, P.ORANGE)
            canvas.ellipse(tip[0] + dx, tip[1] + dy, fire * 0.55, fire * 0.55, P.YELLOW)
        for i in range(dust):
            canvas.rect(CX + 9 + i * 4, GROUND - 2 - (i % 2) * 3, CX + 11 + i * 4, GROUND - (i % 2) * 3, P.GREY_L)

    pose.extras = [face_and_hair, blade, *pose.extras]
    humanoid(c, BODY, pose, CX, GROUND)
    return c


def build() -> list[Sprite]:
    hero = Sprite("hero", SIZE, cx=CX, ground=GROUND)

    run = []
    for i in range(8):
        phase = i / 8 * math.tau
        legs = stride(phase, swing=48, bend=60)
        # The sword arm stays forward and only bobs; the free arm swings against the legs.
        run.append(figure(Pose(near_leg=legs[0], far_leg=legs[1], near_arm=(35 + math.sin(phase) * 12, 40),
                               far_arm=(math.sin(phase) * 45, 50), lean=1),
                          sword=40 + math.sin(phase) * 10).outline())
    hero.add("run", run, fps=14)

    hero.add("stop", [
        figure(Pose(near_leg=(40, 5), far_leg=(-5, 35), near_arm=(50, 30), far_arm=(-40, 30), lean=-step),
               sword=60, dust=step).outline()
        for step in (1, 2, 2, 1)
    ], fps=10, loop=False)

    hero.add("idle", [
        figure(Pose(near_leg=(8, 4), far_leg=(-8, 4), near_arm=(25, 40), far_arm=(-6, 12), head_dy=dy),
               sword=25 + dy * 3).outline()
        for dy in (0, 0, 1, 1)
    ], fps=4)

    hero.add("jump", [
        figure(Pose(near_leg=(55, 80), far_leg=(-5, 55), near_arm=(120, 20), far_arm=(-140, -10), lean=1), sword=10).outline(),
        figure(Pose(near_leg=(45, 65), far_leg=(5, 45), near_arm=(110, 20), far_arm=(-130, -10), lean=1), sword=15).outline(),
    ], fps=8)

    hero.add("fall", [
        figure(Pose(near_leg=(20, 12), far_leg=(-22, 8), near_arm=(80, 30), far_arm=(-110, -20)), sword=50).outline(),
        figure(Pose(near_leg=(14, 8), far_leg=(-16, 12), near_arm=(85, 25), far_arm=(-120, -15)), sword=55).outline(),
    ], fps=8)

    # The fireball is thrown off the blade: draw back, thrust level, flame flares at the tip.
    cast_arm = [(-30, 60), (20, 50), (75, 15), (88, 2), (88, 2), (60, 25)]
    cast_sword = [-30, 20, 80, 90, 90, 70]
    cast_fire = [0, 0, 2, 4, 3, 0]
    hero.add("cast", [
        figure(Pose(near_leg=(20, 8), far_leg=(-20, 8), near_arm=cast_arm[i], far_arm=(-30, 40),
                    lean=1 if i in (2, 3, 4) else 0), sword=cast_sword[i], fire=cast_fire[i]).outline()
        for i in range(6)
    ], fps=16, loop=False)

    hurt_pose = figure(Pose(near_leg=(30, 10), far_leg=(-10, 30), near_arm=(120, 0), far_arm=(-130, 0), lean=-2),
                       sword=-20).outline()
    hero.add("hurt", [tint(hurt_pose.img, P.WHITE, 0.8), hurt_pose.img], fps=10)
    hero.add("death", [topple(hurt_pose.img, t / 5, (CX, GROUND)) for t in range(6)], fps=8, loop=False)

    return [hero, fireball("fireball", 16, 3.0), fireball("fireball_charged", 24, 5.5)]


def fireball(name: str, size: int, radius: float) -> Sprite:
    sprite = Sprite(name, (size, size))
    mid = size / 2 - 0.5

    fly = []
    for i in range(4):
        c = Canvas(size, size)
        for k in range(3):  # trailing tongues flicker behind the core
            length = radius * (1.6 - k * 0.35) + (1 if (i + k) % 2 else 0)
            y = mid + (k - 1) * radius * 0.6 + (0.5 if (i + k) % 3 == 0 else 0)
            c.line((mid - length, y), (mid, y), P.RED if k != 1 else P.ORANGE, 1 + int(radius > 4))
        c.ellipse(mid + 1, mid, radius, radius, P.ORANGE)
        c.ellipse(mid + 1.5, mid, radius * 0.6, radius * 0.6, P.YELLOW)
        if radius > 4:
            c.ellipse(mid + 2, mid, radius * 0.3, radius * 0.3, P.WHITE)
        fly.append(c.outline(P.RED_D))
    sprite.add("fly", fly, fps=14)

    impact = []
    for i in range(5):
        c = Canvas(size, size)
        reach = radius * (0.8 + i * 0.35)
        for k in range(8):
            angle = k / 8 * math.tau + 0.3
            inner, outer = reach * (0.3 + i * 0.15), reach
            if outer > mid:
                outer = mid
            c.line((mid + math.cos(angle) * inner, mid + math.sin(angle) * inner),
                   (mid + math.cos(angle) * outer, mid + math.sin(angle) * outer),
                   P.YELLOW if i < 2 else P.ORANGE if i < 4 else P.RED)
        if i < 3:
            c.ellipse(mid, mid, radius * (1 - i * 0.3), radius * (1 - i * 0.3), P.YELLOW if i < 2 else P.ORANGE)
        impact.append(c)
    sprite.add("impact", impact, fps=18, loop=False)
    return sprite
