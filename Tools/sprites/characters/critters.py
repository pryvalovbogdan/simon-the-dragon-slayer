"""Smaller enemies of the later levels: archer (24x32), hound (32x20), raven (24x20)."""
import math

import palette as P
from draw import Body, Canvas, Pose, humanoid, sink, topple
from sprite import Sprite

ARCHER_SIZE, ARCHER_CX, ARCHER_GROUND = (24, 32), 10, 30
ARCHER = Body(head=(6, 6), torso=(5, 8), thigh=5, shin=5, upper=4, fore=4, skin=P.PALE, skin_d=P.PALE_D,
              hair=P.WHITE, top=P.PURPLE_D, top_d=P.BLACK, legs=P.SLATE, legs_d=P.BLACK, boots=P.BLACK,
              eye=P.BLACK, belt=P.GREY)


def archer_figure(draw: float, loosed: bool = False) -> Canvas:
    """`draw` 0...1 is how far the string is pulled back."""
    c = Canvas(*ARCHER_SIZE)

    def bow(canvas, joints):
        x, y = joints["far_hand"]
        for i in range(-6, 7):  # bow stave bulges forward
            canvas.px(x + 2 - abs(i) * abs(i) / 14, y + i, P.BROWN_L)
        string_x = x - 1 - draw * 4
        canvas.line((x - 1, y - 6), (string_x, y), P.GREY_L)
        canvas.line((string_x, y), (x - 1, y + 6), P.GREY_L)
        if not loosed:
            canvas.line((string_x, y), (string_x + 9, y), P.SAND)

    pose = Pose(near_leg=(14, 6), far_leg=(-14, 6), near_arm=(88 - draw * 25, 60 * draw), far_arm=(88, 0), extras=[bow])
    humanoid(c, ARCHER, pose, ARCHER_CX, ARCHER_GROUND)
    return c


def hound_frame(phase: float, coat=P.WHITE, shade=P.GREY_L, eye=P.RED, shaggy: bool = False) -> Canvas:
    c = Canvas(32, 20)
    stretch = math.sin(phase)
    by = 9 - abs(stretch)
    # legs: far pair darker, drawn first
    for dx, lag, color in ((7, math.pi, shade), (22, 0, shade), (9, math.pi / 2, coat), (24, math.pi * 1.5, coat)):
        angle = math.sin(phase + lag) * 55
        knee = c.limb((dx, by + 2), angle, 4, color, 2)
        c.limb(knee, angle - 30, 4, color, 2)
    c.ellipse(15, by, 9, 4, coat)                         # body
    c.ellipse(11, by + 1, 5, 3, shade)                    # belly shade
    c.line((6, by - 1), (2, by - 4 - stretch), coat, 2 + shaggy)  # tail
    c.ellipse(25, by - 3, 4, 3, coat)                     # head
    c.rect(27, by - 2, 30, by - 1, coat)                  # muzzle
    c.px(30, by - 2, P.BLACK)
    c.poly([(23, by - 5), (24, by - 9), (26, by - 5)], shade)  # ear
    c.px(26, by - 4, eye)
    c.line((27, by), (30, by), P.RED_D)                   # jaw
    if shaggy:                                            # ruff along the neck and back
        for x in range(9, 23, 2):
            c.px(x, by - 4 - (x % 4 == 1), shade)
    return c


SKELETON_SIZE, SKELETON_CX, SKELETON_GROUND = (24, 32), 10, 30
SKELETON = Body(head=(7, 7), torso=(5, 8), thigh=5, shin=5, upper=4, fore=4, limb=1, skin=P.WHITE, skin_d=P.GREY_L,
                hair=None, top=P.GREY_L, top_d=P.GREY, legs=P.WHITE, legs_d=P.GREY_L, boots=P.GREY_L, eye=P.BLACK,
                belt=None)


def skeleton_figure(phase: float) -> Canvas:
    c = Canvas(*SKELETON_SIZE)

    def bones(canvas, joints):
        sx, sy = joints["shoulder"]
        for row in (2, 4, 6):                                      # gaps between the ribs
            canvas.rect(sx - 1, sy + row, sx + 2, sy + row, P.SLATE)
        x, y = joints["head"]
        canvas.rect(x - 1, y - 1, x - 1, y, P.BLACK)                # second eye socket
        canvas.rect(x, y + 2, x + 2, y + 2, P.SLATE)                # teeth line
        hx, hy = joints["near_hand"]
        canvas.line((hx, hy), (hx + 3, hy - 11), P.GREY, 2)         # notched old blade, held high
        canvas.line((hx - 2, hy - 1), (hx + 2, hy + 1), P.BROWN_D)

    legs = (math.sin(phase) * 28, 30 * max(0.0, math.cos(phase)) + 6), (math.sin(phase + math.pi) * 28, 30 * max(0.0, math.cos(phase + math.pi)) + 6)
    humanoid(c, SKELETON, Pose(near_leg=legs[0], far_leg=legs[1], near_arm=(120 + math.sin(phase) * 10, 20),
                               far_arm=(math.sin(phase) * 25, 30), extras=[bones]), SKELETON_CX, SKELETON_GROUND)
    return c


def ghost_frame(step: int) -> Canvas:
    c = Canvas(24, 28)
    bob = (0, 1, 0, -1)[step]
    top = 4 + bob
    c.ellipse(11, top + 7, 7, 7, P.WHITE)                          # head and shoulders
    c.rect(4, top + 7, 18, top + 17, P.WHITE)
    for i in range(4):                                             # ragged hem that ripples
        x = 4 + i * 4
        c.poly([(x, top + 17), (x + 3, top + 17), (x + 1 + (step + i) % 2, top + 22 - (step + i) % 2 * 2)], P.WHITE)
    c.rect(4, top + 9, 5, top + 17, P.BLUE_L)                      # shaded back edge
    c.ellipse(8, top + 13, 2, 3, P.BLUE_L)
    c.rect(11, top + 5, 12, top + 8, P.NAVY)                       # hollow eyes
    c.rect(15, top + 5, 16, top + 8, P.NAVY)
    c.ellipse(13.5, top + 12, 1.5, 2, P.NAVY)                      # wailing mouth
    c.line((17, top + 11), (21, top + 9 + step % 2), P.WHITE, 2)   # reaching arm
    return c


def thorns() -> Canvas:
    c = Canvas(28, 14)
    stems = (((2, 12), (8, 5), (15, 9), (22, 3)), ((4, 12), (12, 7), (19, 10), (26, 6)), ((1, 9), (9, 11), (17, 4), (25, 11)))
    for stem, color in zip(stems, (P.FOREST, P.GREEN_D, P.BROWN_D)):
        for a, b in zip(stem, stem[1:]):
            c.line(a, b, color, 2)
    for x, y, dx, dy in ((8, 5, 0, -3), (22, 3, 2, -2), (17, 4, -2, -3), (12, 7, 1, -3), (4, 9, -2, -2),
                         (25, 9, 2, -2), (15, 9, 0, -3), (19, 10, 2, -2)):
        c.line((x, y), (x + dx, y + dy), P.SAND)                   # thorns catch the light
    c.rect(1, 12, 26, 12, P.FOREST)
    return c


def raven_frame(wing: float) -> Canvas:
    """`wing` -1 (down) ... 1 (up)."""
    c = Canvas(24, 20)
    c.ellipse(11, 11, 5, 3, P.GREY_D)
    c.poly([(4, 10), (0, 12), (5, 13)], P.BLACK)                       # tail
    c.ellipse(16, 9, 3, 3, P.GREY_D)                                   # head
    c.poly([(18, 9), (22, 10), (18, 11)], P.GOLD_D)                    # beak
    c.px(17, 8, P.WHITE)
    tip_y = 11 - wing * 8
    c.poly([(7, 10), (14, 10), (12, tip_y), (6, tip_y + (2 if wing > 0 else -2))], P.BLACK)
    return c


def build() -> list[Sprite]:
    archer = Sprite("archer", ARCHER_SIZE, faces_left=True, cx=ARCHER_CX, ground=ARCHER_GROUND)
    archer.add("idle", [archer_figure(0.2).outline(), archer_figure(0.3).outline()], fps=3)
    archer.add("shoot", [archer_figure(0.4).outline(), archer_figure(1.0).outline(),
                         archer_figure(0.0, loosed=True).outline(), archer_figure(0.1, loosed=True).outline()],
               fps=10, loop=False)
    base = archer_figure(0.2).outline().img
    archer.add("death", [topple(base, t / 3, (ARCHER_CX, ARCHER_GROUND)) for t in range(4)], fps=10, loop=False)

    hound = Sprite("hound", (32, 20), faces_left=True, cx=15, ground=18)
    run = [hound_frame(i / 6 * math.tau).outline() for i in range(6)]
    hound.add("run", run, fps=14)
    hound.add("death", [sink(run[0].img, t / 3, depth=4) for t in range(4)], fps=10, loop=False)

    raven = Sprite("raven", (24, 20), faces_left=True, cx=11, ground=14)
    fly = [raven_frame(w).outline(P.BLACK) for w in (1, 0.3, -0.8, 0.3)]
    raven.add("fly", fly, fps=10)
    raven.add("death", [sink(fly[2].img, t / 2, depth=8) for t in range(3)], fps=10, loop=False)
    wolf = Sprite("wolf", (32, 20), faces_left=True, cx=15, ground=18)
    wolf_run = [hound_frame(i / 6 * math.tau, coat=P.GREY, shade=P.GREY_D, eye=P.YELLOW, shaggy=True).outline()
                for i in range(6)]
    wolf.add("run", wolf_run, fps=12)
    wolf.add("death", [sink(wolf_run[0].img, t / 3, depth=4) for t in range(4)], fps=10, loop=False)

    skeleton = Sprite("skeleton", SKELETON_SIZE, faces_left=True, cx=SKELETON_CX, ground=SKELETON_GROUND)
    walk = [skeleton_figure(i / 6 * math.tau).outline() for i in range(6)]
    skeleton.add("walk", walk, fps=8)
    skeleton.add("death", [sink(walk[0].img, t / 3, depth=10) for t in range(4)], fps=10, loop=False)

    ghost = Sprite("ghost", (24, 28), faces_left=True, cx=11, ground=25)
    floating = [ghost_frame(i).outline(P.BLUE_D) for i in range(4)]
    ghost.add("float", floating, fps=6)
    ghost.add("death", [sink(floating[0].img, t / 2, depth=-6) for t in range(3)], fps=10, loop=False)

    bramble = Sprite("thorns", (28, 14), ground=12)
    bramble.add("still", [thorns().outline()], fps=1)
    return [archer, hound, raven, wolf, skeleton, ghost, bramble]
