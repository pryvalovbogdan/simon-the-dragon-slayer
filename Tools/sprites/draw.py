"""Pixel drawing primitives and the part-based humanoid used by most characters."""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable

from PIL import Image, ImageDraw

import palette as P

Color = tuple[int, int, int, int]
Point = tuple[float, float]


def r(value: float) -> int:
    return int(math.floor(value + 0.5))


class Canvas:
    def __init__(self, width: int, height: int):
        self.img = Image.new("RGBA", (width, height), P.CLEAR)
        self.d = ImageDraw.Draw(self.img)

    @property
    def size(self) -> tuple[int, int]:
        return self.img.size

    def px(self, x: float, y: float, color: Color) -> None:
        x, y = r(x), r(y)
        if 0 <= x < self.img.width and 0 <= y < self.img.height:
            self.img.putpixel((x, y), color)

    def rect(self, x0: float, y0: float, x1: float, y1: float, color: Color) -> None:
        self.d.rectangle([r(min(x0, x1)), r(min(y0, y1)), r(max(x0, x1)), r(max(y0, y1))], fill=color)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, color: Color) -> None:
        self.d.ellipse([r(cx - rx), r(cy - ry), r(cx + rx), r(cy + ry)], fill=color)

    def line(self, a: Point, b: Point, color: Color, width: int = 1) -> None:
        if width <= 1:
            self.d.line([r(a[0]), r(a[1]), r(b[0]), r(b[1])], fill=color)
            return
        # Stamp squares along the segment: crisper at tiny sizes than PIL's wide lines.
        steps = max(1, r(max(abs(b[0] - a[0]), abs(b[1] - a[1]))))
        half = (width - 1) / 2
        for i in range(steps + 1):
            t = i / steps
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            self.rect(x - half, y - half, x - half + width - 1, y - half + width - 1, color)

    def poly(self, points: list[Point], color: Color) -> None:
        self.d.polygon([(r(x), r(y)) for x, y in points], fill=color)

    def limb(self, start: Point, angle: float, length: float, color: Color, width: int = 2) -> Point:
        """Segment from `start`; angle in degrees, 0 = straight down, positive = forward (right)."""
        rad = math.radians(angle)
        end = (start[0] + math.sin(rad) * length, start[1] + math.cos(rad) * length)
        self.line(start, end, color, width)
        return end

    def paste(self, other: "Canvas | Image.Image", x: float = 0, y: float = 0) -> None:
        image = other.img if isinstance(other, Canvas) else other
        self.img.alpha_composite(image, (r(x), r(y)))
        self.d = ImageDraw.Draw(self.img)

    def outline(self, color: Color = P.OUTLINE) -> "Canvas":
        """Adds a 1px outline around everything drawn so far."""
        src = self.img.load()
        w, h = self.img.size
        edge = []
        for y in range(h):
            for x in range(w):
                if src[x, y][3] != 0:
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                        edge.append((x, y))
                        break
        for x, y in edge:
            src[x, y] = color
        return self


def end_of(start: Point, angle: float, length: float) -> Point:
    rad = math.radians(angle)
    return (start[0] + math.sin(rad) * length, start[1] + math.cos(rad) * length)


def tint(image: Image.Image, color: Color, amount: float) -> Image.Image:
    """Blends every opaque pixel toward `color` (used for hurt flashes)."""
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            pr, pg, pb, pa = px[x, y]
            if pa:
                px[x, y] = (r(pr + (color[0] - pr) * amount), r(pg + (color[1] - pg) * amount),
                            r(pb + (color[2] - pb) * amount), pa)
    return out


def topple(image: Image.Image, t: float, pivot: tuple[float, float]) -> Image.Image:
    """Death frame: falls onto its back about `pivot` (the feet), then dissolves; t in 0...1.

    The fallen figure is slid back inside the frame, so tall sprites are never clipped.
    """
    progress = min(t / 0.7, 1.0)
    pad = max(image.size)
    big = Image.new("RGBA", (image.width + pad * 2, image.height + pad * 2), P.CLEAR)
    big.alpha_composite(image, (pad, pad))
    big = big.rotate(progress * 90, resample=Image.NEAREST, center=(pivot[0] + pad, pivot[1] + pad))
    box = big.getbbox() or (pad, pad, pad + image.width, pad + image.height)
    left = min(pad, box[0] - 1) if box[2] - box[0] < image.width else box[0]
    top = min(pad, max(box[3] + 1 - image.height, 0))
    out = big.crop((left, top, left + image.width, top + image.height))
    if t > 0.7:
        out = fade(out, 1.0 - (t - 0.7) / 0.3 * 0.6)
    return out


def sink(image: Image.Image, t: float, depth: float | None = None) -> Image.Image:
    """Death frame for creatures that collapse and dissolve instead of toppling; t in 0...1."""
    depth = image.height * 0.25 if depth is None else depth
    out = Image.new("RGBA", image.size, P.CLEAR)
    out.alpha_composite(image, (0, r(t * depth)))
    return fade(out, 1.0 - t * 0.75)


def fade(image: Image.Image, keep: float) -> Image.Image:
    """Checkerboard dissolve: pixel art has no partial alpha, so drop a share of the pixels."""
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] and ((x * 7 + y * 13) % 10) / 10 >= keep:
                px[x, y] = P.CLEAR
    return out


def noise(seed: int) -> Callable[[], float]:
    """Deterministic pseudo-random stream in 0...1 (output must be identical on every run)."""
    state = (seed * 2654435761 + 1013904223) & 0xFFFFFFFF

    def next_value() -> float:
        nonlocal state
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        return (state >> 8) / float(1 << 24)

    return next_value


@dataclass
class Body:
    """Proportions and colours of a humanoid, in pixels."""
    head: tuple[int, int] = (7, 7)
    torso: tuple[int, int] = (6, 8)
    thigh: float = 5
    shin: float = 5
    upper: float = 4
    fore: float = 4
    limb: int = 2
    skin: Color = P.SKIN
    skin_d: Color = P.SKIN_D
    hair: Color | None = P.HAIR_RED
    top: Color = P.GREEN
    top_d: Color = P.GREEN_D
    legs: Color = P.BROWN
    legs_d: Color = P.BROWN_D
    boots: Color = P.BROWN_D
    eye: Color = P.BLACK
    belt: Color | None = P.BROWN_D
    robe: bool = False  # draws a long robe instead of legs


@dataclass
class Pose:
    """Angles in degrees (0 = down, positive = forward). Near limbs are drawn in front."""
    near_leg: tuple[float, float] = (0, 0)   # thigh angle, knee bend (shin swings back by this much)
    far_leg: tuple[float, float] = (0, 0)
    near_arm: tuple[float, float] = (0, 0)   # upper arm angle, elbow bend (forearm swings forward)
    far_arm: tuple[float, float] = (0, 0)
    lean: float = 0      # shoulders shift forward by this many pixels
    lift: float = 0      # pixels above the ground (jumps)
    crouch: float = 0    # hips lowered by this many pixels
    head_dx: float = 0
    head_dy: float = 0
    extras: list = field(default_factory=list)


def humanoid(c: Canvas, body: Body, pose: Pose, cx: float, ground: float) -> dict[str, Point]:
    """Draws a right-facing figure standing on `ground` (the y of the lowest foot pixel)."""
    leg_len = body.thigh + body.shin

    def leg_points(hip: Point, leg: tuple[float, float]) -> tuple[Point, Point]:
        knee = end_of(hip, leg[0], body.thigh)
        return knee, end_of(knee, leg[0] - leg[1], body.shin)

    probe = (cx, 0.0)
    lowest = max(leg_points(probe, pose.near_leg)[1][1], leg_points(probe, pose.far_leg)[1][1])
    hip_y = ground - lowest - pose.lift + pose.crouch if not body.robe else ground - leg_len - pose.lift
    if pose.crouch:
        hip_y = min(hip_y, ground - body.shin - pose.lift)
    hip = (cx, hip_y)
    tw, th = body.torso
    shoulder = (cx + pose.lean, hip_y - th + 1)
    hw, hh = body.head
    head_c = (shoulder[0] + pose.head_dx + 0.5, shoulder[1] - hh / 2 - 0.5 + pose.head_dy)

    def arm(spec: tuple[float, float], upper_c: Color, lower_c: Color) -> Point:
        start = (shoulder[0], shoulder[1] + 1)
        elbow = c.limb(start, spec[0], body.upper, upper_c, body.limb)
        hand = c.limb(elbow, spec[0] + spec[1], body.fore, lower_c, body.limb)
        return hand

    def leg(spec: tuple[float, float], color: Color, boot: Color) -> Point:
        knee, foot = leg_points(hip, spec)
        c.line(hip, knee, color, body.limb)
        c.line(knee, foot, color, body.limb)
        c.rect(foot[0] - body.limb / 2, foot[1] - 0.5, foot[0] + body.limb, foot[1] + 0.5, boot)
        return foot

    far_hand = arm(pose.far_arm, body.top_d, body.skin_d)
    feet = []
    if body.robe:
        hem = ground
        c.poly([(hip[0] - tw / 2 - 1, hip[1]), (hip[0] + tw / 2 + 1, hip[1]),
                (hip[0] + tw / 2 + 4, hem), (hip[0] - tw / 2 - 4, hem)], body.legs)
        c.poly([(hip[0] - tw / 2 - 1, hip[1]), (hip[0] - 1, hip[1]), (hip[0] - tw / 2, hem),
                (hip[0] - tw / 2 - 4, hem)], body.legs_d)
    else:
        feet.append(leg(pose.far_leg, body.legs_d, body.boots))

    c.poly([(shoulder[0] - tw / 2, shoulder[1]), (shoulder[0] + tw / 2 - 0.5, shoulder[1]),
            (hip[0] + tw / 2 - 0.5, hip[1]), (hip[0] - tw / 2, hip[1])], body.top)
    c.poly([(shoulder[0] - tw / 2, shoulder[1]), (shoulder[0] - tw / 2 + max(1, tw // 4), shoulder[1]),
            (hip[0] - tw / 2 + max(1, tw // 4), hip[1]), (hip[0] - tw / 2, hip[1])], body.top_d)
    if body.belt:
        c.rect(hip[0] - tw / 2, hip[1] - 1, hip[0] + tw / 2 - 0.5, hip[1] - 1, body.belt)
    if not body.robe:
        feet.append(leg(pose.near_leg, body.legs, body.boots))

    hx0, hy0 = head_c[0] - hw / 2, head_c[1] - hh / 2
    c.rect(hx0, hy0 + 1, hx0 + hw - 1, hy0 + hh - 2, body.skin)
    c.rect(hx0 + 1, hy0, hx0 + hw - 2, hy0 + hh - 1, body.skin)
    c.rect(hx0, hy0 + hh - 3, hx0 + 1, hy0 + hh - 2, body.skin_d)
    if body.hair:
        c.rect(hx0 + 1, hy0, hx0 + hw - 2, hy0 + max(1, hh // 4), body.hair)
        c.rect(hx0, hy0 + 1, hx0 + max(1, hw // 3), hy0 + hh // 2, body.hair)
    eye_x, eye_y = hx0 + hw - 2 - max(0, hw // 8), hy0 + hh // 2
    c.rect(eye_x, eye_y, eye_x, eye_y + max(0, hh // 8), body.eye)

    near_hand = arm(pose.near_arm, body.top, body.skin)
    joints = {"hip": hip, "shoulder": shoulder, "head": head_c, "near_hand": near_hand, "far_hand": far_hand,
              "head_top": (head_c[0], hy0), "eye": (eye_x, eye_y)}
    for extra in pose.extras:
        extra(c, joints)
    return joints


def stride(phase: float, swing: float = 38, bend: float = 45) -> tuple[tuple[float, float], tuple[float, float]]:
    """Leg angles for a walk/run cycle at `phase` radians: (near, far)."""
    def one(p: float) -> tuple[float, float]:
        return (math.sin(p) * swing, bend * max(0.0, math.cos(p)) + 8)
    return one(phase), one(phase + math.pi)


def swing(phase: float, amount: float = 40, bend: float = 45) -> tuple[tuple[float, float], tuple[float, float]]:
    """Arm angles opposing the legs: (near, far)."""
    return (-math.sin(phase) * amount, bend), (math.sin(phase) * amount, bend)
