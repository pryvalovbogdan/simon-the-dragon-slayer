"""The start and end screens' theme: an original, loopable 8-bit track (standard library only).

Bright and driving with a warm, slightly worn sound: F sharp major at 164 BPM, pulse-wave lead,
sixteenth-note arpeggios, a pumping triangle bass and noise drums, with a slow tape wobble and an
echo on the lead. The loop is rendered so its end runs straight into its start.
"""
import math

RATE = 22050
BPM = 164
EIGHTH = 60 / BPM / 2
BAR = EIGHTH * 8

# Chords as (bass root midi, chord tones for the arpeggio).
CHORDS = {
    "F#": (42, [66, 70, 73, 78]),
    "C#": (37, [61, 65, 68, 73]),
    "D#m": (39, [63, 66, 70, 75]),
    "B": (35, [59, 63, 66, 71]),
    "A#m": (34, [58, 61, 65, 70]),
}

# Lead melody, one bar per line: (midi note or None for a rest, length in eighths).
A = [
    [(73, 2), (70, 1), (73, 1), (78, 3), (77, 1)],
    [(75, 2), (73, 1), (68, 1), (73, 2), (77, 2)],
    [(70, 1), (73, 1), (75, 2), (78, 2), (75, 2)],
    [(73, 3), (71, 1), (70, 2), (66, 2)],
    [(73, 2), (70, 1), (73, 1), (78, 2), (80, 2)],
    [(77, 2), (75, 1), (73, 1), (80, 4)],
    [(78, 2), (77, 1), (75, 1), (70, 2), (73, 2)],
    [(75, 3), (73, 1), (70, 4)],
]
A2 = A[:4] + [
    [(78, 2), (73, 1), (78, 1), (82, 4)],
    [(80, 2), (77, 2), (75, 2), (73, 2)],
    [(75, 1), (78, 1), (82, 2), (80, 2), (78, 2)],
    [(75, 2), (73, 2), (71, 2), (73, 2)],
]
B = [
    [(75, 4), (78, 4)],
    [(77, 4), (80, 4)],
    [(77, 2), (78, 2), (77, 2), (73, 2)],
    [(75, 6), (73, 2)],
    [(71, 2), (75, 2), (78, 2), (83, 2)],
    [(82, 2), (80, 2), (77, 2), (73, 2)],
    [(78, 4), (73, 2), (70, 2)],
    [(78, 6), (None, 1), (73, 1)],
]
VERSE = ["F#", "C#", "D#m", "B"] * 2
BRIDGE = ["B", "C#", "A#m", "D#m", "B", "C#", "F#", "F#"]
SONG = [(A, VERSE, False), (A2, VERSE, False), (B, BRIDGE, True)]


def hz(midi: float) -> float:
    return 440 * 2 ** ((midi - 69) / 12)


class Noise:
    """A fixed-seed generator, so the track is identical on every build."""

    def __init__(self, seed: int):
        self.state = seed

    def __call__(self) -> float:
        self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
        return self.state / 0x3FFFFFFF - 1


def wobble(t: float) -> float:
    """Slow tape warble in semitones, shared by every pitched voice."""
    return 0.06 * math.sin(2 * math.pi * 0.35 * t) + 0.03 * math.sin(2 * math.pi * 1.7 * t)


def render() -> list[float]:
    length = int(RATE * BAR * sum(len(bars) for bars, _, _ in SONG))
    lead = [0.0] * length
    rest = [0.0] * length

    def add(buffer, start_s, samples):
        start = int(start_s * RATE)
        for i, value in enumerate(samples):
            buffer[(start + i) % length] += value  # wraps, so tails ring into the loop's start

    def pulse(midi, seconds, start_s, duty, volume, attack=0.005, release=0.06, vibrato=0.0):
        count = int(seconds * RATE)
        out, phase = [], 0.0
        for i in range(count):
            t = i / RATE
            bend = wobble(start_s + t) + (vibrato * math.sin(2 * math.pi * 5.5 * t) * min(1, t / 0.15))
            phase += hz(midi + bend) / RATE
            env = min(1, t / attack) * min(1, (seconds - t) / release) * (0.75 + 0.25 * math.exp(-t * 6))
            out.append((1 if phase % 1 < duty else -1) * volume * env)
        return out

    def triangle(midi, seconds, start_s, volume):
        count = int(seconds * RATE)
        out, phase = [], 0.0
        for i in range(count):
            t = i / RATE
            phase += hz(midi + wobble(start_s + t)) / RATE
            env = min(1, t / 0.004) * min(1, (seconds - t) / 0.02)
            out.append((4 * abs(phase % 1 - 0.5) - 1) * volume * env)
        return out

    noise = Noise(0x5EED)

    def drum(kind, start_s):
        if kind == "kick":
            count, out, phase = int(0.16 * RATE), [], 0.0
            for i in range(count):
                t = i / RATE
                phase += (50 + 110 * math.exp(-t * 35)) / RATE
                out.append(math.sin(2 * math.pi * phase) * 0.55 * math.exp(-t * 18))
        else:
            seconds, volume, decay = {"snare": (0.14, 0.32, 22), "hat": (0.03, 0.08, 120), "open": (0.12, 0.08, 25)}[kind]
            count, out, held = int(seconds * RATE), [], 0.0
            for i in range(count):
                t = i / RATE
                if kind != "snare" or i % 2 == 0:
                    held = noise()
                out.append(held * volume * math.exp(-t * decay))
        add(rest, start_s, out)

    bar_start = 0.0
    for melody, chords, bridge in SONG:
        for bar, (notes, chord) in enumerate(zip(melody, chords)):
            root, tones = CHORDS[chord]
            # lead
            at = bar_start
            for midi, eighths in notes:
                seconds = eighths * EIGHTH
                if midi is not None:
                    add(lead, at, pulse(midi, seconds * 0.95, at, 0.25, 0.22, vibrato=0.12 if eighths >= 3 else 0))
                at += seconds
            # arpeggio in sixteenths, up and back down
            order = [0, 1, 2, 3, 2, 1, 0, 1]
            for step in range(16):
                start = bar_start + step * EIGHTH / 2
                add(rest, start, pulse(tones[order[step % 8]] - 12 if not bridge else tones[order[step % 8]],
                                       EIGHTH / 2 * 0.8, start, 0.125, 0.07, release=0.02))
            # bass: pumping eighths with an octave jump on the off-beats of beats 2 and 4
            for step in range(8):
                start = bar_start + step * EIGHTH
                add(rest, start, triangle(root + (12 if step in (3, 7) else 0), EIGHTH * 0.85, start, 0.32))
            # drums: kick on 1 and 3 (every beat in the bridge), snare on 2 and 4, hats on the eighths
            for step in range(8):
                start = bar_start + step * EIGHTH
                if step in ((0, 2, 4, 6) if bridge else (0, 4, 5)):
                    drum("kick", start)
                if step in (2, 6):
                    drum("snare", start)
                drum("open" if step == 7 else "hat", start)
            bar_start += BAR

    # echo on the lead: a dotted-eighth delay, run twice round the loop so the start hears the end
    delay = int(EIGHTH * 1.5 * RATE)
    echo = [0.0] * length
    for _ in range(2):
        for i in range(length):
            echo[i] = lead[i] + 0.35 * echo[(i - delay) % length]
    mix = [echo[i] + rest[i] for i in range(length)]

    # gentle low-pass for the worn, nostalgic tone, also run round the loop
    smoothed, value = [0.0] * length, 0.0
    for _ in range(2):
        for i in range(length):
            value += 0.45 * (mix[i] - value)
            smoothed[i] = value
    peak = max(abs(s) for s in smoothed) or 1
    return [s / peak * 0.85 for s in smoothed]
