"""File and normalise the author's seven delivered audio files.

The originals are retained byte-for-byte under asset/audio/raw. Music is copied
without re-encoding; effects are downmixed, trimmed, resampled to the project's
mono 22.05 kHz PCM contract, faded to zero, and peak-normalised below -3 dBFS.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import wave

import numpy as np
from scipy.signal import resample_poly


ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "asset/audio"
DELIVERY = AUDIO / "bgm"
RAW = AUDIO / "raw"
SFX = AUDIO / "sfx"
RATE = 22_050
TARGET_PEAK = 10 ** (-3.01 / 20.0)

MUSIC = {
    "Joseonlike.mp3": "joseonlike.mp3",
    "Moonlit Sanctuary.mp3": "moonlit_sanctuary.mp3",
    "Bamboo Forest Spirits.mp3": "bamboo_forest_spirits.mp3",
}
EFFECTS = {
    "button_click.wav": "ui_click.wav",
    "Monster_Die.wav": "enemy_death.wav",
    "Chracter_Die.wav": "player_death.wav",
    "energy_sound.wav": "energy_sound.wav",
}
RUNTIME_CAPS = {
    # Combat has eight round-robin death voices and can recycle each in ~0.13s.
    # The delivered effect puts 41.17% of its energy and its full peak in the
    # first 150 ms, so retain that recognisable transient instead of shipping a
    # 1.73 s tail that is inaudible during dense play.
    "Monster_Die.wav": 0.150,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def retain_original(name: str) -> Path:
    """Move the delivery to raw exactly once, then return the retained source."""
    delivered = DELIVERY / name
    retained = RAW / name
    RAW.mkdir(parents=True, exist_ok=True)
    if delivered.exists():
        delivered_hash = sha256(delivered)
        if retained.exists() and sha256(retained) != delivered_hash:
            raise RuntimeError(f"refusing to overwrite different retained original: {retained}")
        if not retained.exists():
            shutil.move(str(delivered), str(retained))
        else:
            delivered.unlink()
    if not retained.exists():
        raise FileNotFoundError(f"missing delivered and retained original: {name}")
    return retained


def read_wav(path: Path) -> tuple[np.ndarray, dict[str, float | int]]:
    with wave.open(str(path), "rb") as stream:
        channels = stream.getnchannels()
        width = stream.getsampwidth()
        rate = stream.getframerate()
        frames = stream.getnframes()
        if width != 2:
            raise ValueError(f"{path}: expected 16-bit PCM input, got {width * 8}-bit")
        values = np.frombuffer(stream.readframes(frames), dtype="<i2").astype(np.float64)
    shaped = values.reshape(-1, channels)
    mono = shaped.mean(axis=1) / 32768.0
    peak = float(np.max(np.abs(values)) / 32768.0)
    return mono, {
        "channels": channels,
        "sample_rate": rate,
        "duration_seconds": frames / rate,
        "peak": peak,
        "peak_dbfs": 20 * math.log10(max(peak, 1e-12)),
    }


def content_end(samples: np.ndarray, rate: int) -> tuple[int, dict[str, float]]:
    """Find the last sustained 20 ms window above the delivered noise floor."""
    window = round(0.020 * rate)
    rms = np.array([
        math.sqrt(float(np.mean(samples[start : start + window] ** 2)))
        for start in range(0, len(samples), window)
    ])
    tail = rms[max(0, round(len(rms) * 0.9)) :]
    noise_floor = float(np.median(tail))
    threshold = max(float(np.max(rms)) * 0.02, noise_floor * 6.0)
    active = rms >= threshold
    sustained = [
        index
        for index, value in enumerate(active)
        if value and (
            (index > 0 and active[index - 1])
            or (index + 1 < len(active) and active[index + 1])
        )
    ]
    if not sustained:
        raise ValueError("could not find sustained audio content")
    tail_padding = round(0.030 * rate)
    end = min(len(samples), (sustained[-1] + 1) * window + tail_padding)
    return end, {
        "window_seconds": window / rate,
        "noise_floor_rms": noise_floor,
        "activity_threshold_rms": threshold,
        "last_sustained_window": sustained[-1],
    }


def write_wav(path: Path, samples: np.ndarray) -> dict[str, float | int]:
    peak = float(np.max(np.abs(samples)))
    if peak <= 0:
        raise ValueError(f"{path}: no signal")
    samples = samples * (TARGET_PEAK / peak)
    pcm = np.rint(np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    measured_peak = float(np.max(np.abs(pcm.astype(np.int32))) / 32767.0)
    return {
        "channels": 1,
        "sample_rate": RATE,
        "duration_seconds": len(pcm) / RATE,
        "peak": measured_peak,
        "peak_dbfs": 20 * math.log10(max(measured_peak, 1e-12)),
    }


def process_effect(
    source: Path,
    destination: Path,
    runtime_cap_seconds: float | None = None,
) -> dict[str, object]:
    samples, before = read_wav(source)
    source_rate = int(before["sample_rate"])
    natural_end, gate = content_end(samples, source_rate)
    end = natural_end
    if runtime_cap_seconds is not None:
        end = min(end, round(runtime_cap_seconds * source_rate))
    retained_energy = float(
        np.sum(samples[:end] ** 2) / max(float(np.sum(samples ** 2)), 1e-12)
    )
    trimmed = samples[:end].copy()
    fade = min(len(trimmed), round(0.010 * source_rate))
    trimmed[-fade:] *= np.linspace(1.0, 0.0, fade, endpoint=True)
    converted = resample_poly(trimmed, RATE, source_rate)
    after = write_wav(destination, converted)
    return {
        "source": str(source.relative_to(ROOT)).replace("\\", "/"),
        "destination": str(destination.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": sha256(source),
        "natural_trim_end_seconds": natural_end / source_rate,
        "runtime_cap_seconds": runtime_cap_seconds,
        "trim_end_seconds": end / source_rate,
        "source_energy_retained": retained_energy,
        "gate": gate,
        "before": before,
        "after": after,
    }


def main() -> None:
    retained = {name: retain_original(name) for name in (*MUSIC, *EFFECTS)}
    metrics: dict[str, object] = {"music": {}, "effects": {}}

    for original, final in MUSIC.items():
        destination = DELIVERY / final
        shutil.copy2(retained[original], destination)
        if sha256(destination) != sha256(retained[original]):
            raise RuntimeError(f"music was not copied losslessly: {destination}")
        metrics["music"][final] = {
            "source": f"asset/audio/raw/{original}",
            "destination": f"asset/audio/bgm/{final}",
            "sha256": sha256(destination),
            "reencoded": False,
        }

    for original, final in EFFECTS.items():
        result = process_effect(
            retained[original],
            SFX / final,
            RUNTIME_CAPS.get(original),
        )
        metrics["effects"][final] = result
        before = result["before"]
        after = result["after"]
        print(
            f"{final}: {before['duration_seconds']:.3f}s {before['peak_dbfs']:.2f} dBFS -> "
            f"{after['duration_seconds']:.3f}s {after['peak_dbfs']:.2f} dBFS"
        )

    metrics_path = RAW / "author_audio_metrics.json"
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {metrics_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
