#!/usr/bin/env python3
"""Generates the game's sound effects as small 8-bit-style WAV files (standard library only)."""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "App" / "Resources" / "Sounds"


def tone(start_hz: float, end_hz: float, seconds: float, shape: str = "square", volume: float = 0.5) -> list[float]:
    """A pitch sweep with a linear fade-out. `shape` is square, triangle or noise."""
    samples, phase = [], 0.0
    count = int(RATE * seconds)
    state = 0x1234
    held = 0.0
    for i in range(count):
        t = i / count
        hz = start_hz + (end_hz - start_hz) * t
        phase += hz / RATE
        if shape == "square":
            value = 1.0 if phase % 1 < 0.5 else -1.0
        elif shape == "triangle":
            value = 4 * abs(phase % 1 - 0.5) - 1
        else:  # noise, resampled at `hz` so lower pitch sounds rougher
            if int(phase) != int(phase - hz / RATE):
                state = (state * 1103515245 + 12345) & 0x7FFFFFFF
                held = state / 0x3FFFFFFF - 1
            value = held
        samples.append(value * volume * (1 - t))
    return samples


def write(name: str, *parts: list[float]) -> None:
    samples = [s for part in parts for s in part]
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def main() -> None:
    write("jump", tone(300, 620, 0.12))
    write("double_jump", tone(450, 900, 0.12))
    write("fire", tone(900, 200, 0.14, "noise"), tone(500, 250, 0.06))
    write("charged", tone(200, 900, 0.1), tone(1200, 150, 0.25, "noise", 0.7))
    write("impact", tone(700, 80, 0.12, "noise"))
    write("stomp", tone(260, 90, 0.1, "triangle", 0.8))
    write("coin", tone(988, 988, 0.05), tone(1319, 1319, 0.12))
    write("hurt", tone(400, 120, 0.25, "square", 0.6))
    write("block", tone(1500, 1400, 0.06, "triangle"))
    write("boss_hit", tone(180, 60, 0.18, "noise", 0.8))
    write("level_up", tone(523, 523, 0.09), tone(659, 659, 0.09), tone(784, 784, 0.09), tone(1047, 1047, 0.22))
    write("win", tone(523, 523, 0.12), tone(784, 784, 0.12), tone(1047, 1047, 0.12), tone(1319, 1319, 0.35))
    write("lose", tone(392, 392, 0.16), tone(330, 330, 0.16), tone(262, 180, 0.4))
    write("boss_roar", tone(140, 60, 0.5, "noise", 0.8))
    print(f"wrote sounds to {OUT}")


if __name__ == "__main__":
    main()
