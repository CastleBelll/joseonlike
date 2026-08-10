"""Synthesize the M1 sound set without third-party samples.

Higgsfield's configured audio endpoint is speech-only, so procedural synthesis
provides deterministic, royalty-free ambience and effects. All files are mono
22.05 kHz PCM WAV and peak-normalized below -3 dBFS.
"""
from pathlib import Path
import math
import random
import wave

RATE = 22050
PEAK = 10 ** (-3.0 / 20.0)
RNG = random.Random(20260810)


def envelope(t, duration, attack=0.01, release=0.08):
    return min(1.0, t / attack) * min(1.0, (duration - t) / release)


def noise():
    return RNG.uniform(-1.0, 1.0)


def write(path, samples):
    maximum = max(1e-9, max(abs(v) for v in samples))
    scale = min(PEAK / maximum, 1.0)
    pcm = bytearray()
    for value in samples:
        integer = int(max(-1.0, min(1.0, value * scale)) * 32767)
        pcm += integer.to_bytes(2, "little", signed=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)
    print(f"{path}: {len(samples)/RATE:.2f}s peak<=-3dBFS")


def ambience(duration=12.0):
    count = round(duration * RATE)
    phases = [RNG.random() * math.tau for _ in range(18)]
    values = []
    for i in range(count):
        x = i / count
        # Integer cycles over the exact buffer length guarantee loop continuity.
        bed = sum(math.sin(math.tau * (k + 1) * x + phases[k]) / (k + 2) for k in range(12))
        insects = 0.08 * math.sin(math.tau * 2196 * x + phases[12]) * (0.5 + 0.5 * math.sin(math.tau * 7 * x))
        leaves = 0.18 * sum(math.sin(math.tau * k * x + phases[13 + j]) for j, k in enumerate((37, 53, 71, 89, 113))) / 5
        values.append(0.10 * bed + insects + leaves)
    return values


def hit(duration=0.12):
    values = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        decay = math.exp(-32 * t)
        values.append((0.55 * noise() + 0.45 * math.sin(math.tau * (150 - 500*t) * t)) * decay)
    return values


def death(duration=0.34):
    values = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        f = 260 - 520 * t
        values.append((0.7 * math.sin(math.tau * f * t) + 0.18 * noise()) * math.exp(-7 * t))
    return values


def tones(notes, duration, pulse=0.11):
    values = [0.0] * round(duration * RATE)
    for offset, frequency in notes:
        for i in range(round(pulse * RATE)):
            index = round(offset * RATE) + i
            if index >= len(values):
                break
            t = i / RATE
            values[index] += 0.42 * math.sin(math.tau * frequency * t) * envelope(t, pulse, 0.008, 0.07)
            values[index] += 0.16 * math.sin(math.tau * frequency * 2 * t) * envelope(t, pulse, 0.008, 0.06)
    return values


def boss(duration=1.5):
    values = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        drum = math.sin(math.tau * (72 - 18*t) * t) * math.exp(-3.0 * t)
        gong = math.sin(math.tau * 143 * t) + 0.45 * math.sin(math.tau * 211 * t)
        values.append(0.58 * drum + 0.22 * gong * math.exp(-1.7 * t))
    return values


def click(duration=0.07):
    values = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        values.append((0.75 * math.sin(math.tau * 860 * t) + 0.25 * noise()) * math.exp(-55 * t))
    return values


def main():
    root = Path("asset/audio")
    write(root / "ambience/bamboo_forest_loop.wav", ambience())
    write(root / "sfx/combat_hit.wav", hit())
    write(root / "sfx/enemy_death.wav", death())
    write(root / "sfx/level_up.wav", tones([(0.00, 523.25), (0.13, 659.25), (0.26, 783.99), (0.39, 1046.50)], 0.72, 0.22))
    write(root / "sfx/boss_spawn.wav", boss())
    write(root / "sfx/ui_click.wav", click())


if __name__ == "__main__":
    main()
