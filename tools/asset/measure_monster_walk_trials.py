"""Measure representative monster walk trials against each monster's south idle."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
TRIALS = {
    "blue_dokkaebi": "humanoid",
    "gumiho_scout": "quadruped",
    "wonhon": "floating_spirit",
    "ancient_imugi": "serpentine_boss",
}


def pixels(image: Image.Image):
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def changed(first: Image.Image, second: Image.Image, box=(0, 0, 92, 92)) -> tuple[int, int]:
    a = first.crop(box)
    b = second.crop(box)
    rgba = sum(pixel != (0, 0, 0, 0) for pixel in pixels(ImageChops.difference(a, b)))
    alpha = sum(left[3] != right[3] for left, right in zip(pixels(a), pixels(b)))
    return rgba, alpha


def main() -> None:
    results = {
        "method": "exact RGBA comparison against each entity's reviewed south idle",
        "acceptance": {
            "lower_change_share_percent_min": 60,
            "head_alpha_changed_pixels_max": 2,
            "frame_pair_changed_pixels_min": 8,
        },
        "trials": {},
    }
    for monster_id, body_plan in TRIALS.items():
        idle = Image.open(
            ROOT / f"asset/monster/{monster_id}/rotations/south.png"
        ).convert("RGBA")
        bbox = idle.getbbox()
        if bbox is None:
            raise SystemExit(f"{monster_id}: idle is empty")
        height = bbox[3] - bbox[1]
        head_box = (0, bbox[1], 92, bbox[1] + round(height * 0.45))
        lower_box = (0, bbox[1] + round(height * 0.62), 92, 92)
        frames = [
            Image.open(
                ROOT / f"asset/monster/{monster_id}/raw/walk_trial/cut/{index}.png"
            ).convert("RGBA")
            for index in range(2)
        ]
        frame_results = []
        accepted = True
        for frame in frames:
            total, alpha = changed(idle, frame)
            lower, lower_alpha = changed(idle, frame, lower_box)
            head, head_alpha = changed(idle, frame, head_box)
            lower_share = lower * 100 / total if total else 100.0
            frame_accepted = lower_share >= 60 and head_alpha <= 2
            accepted = accepted and frame_accepted
            frame_results.append({
                "changed_pixels": total,
                "alpha_changed_pixels": alpha,
                "lower_changed_pixels": lower,
                "lower_alpha_changed_pixels": lower_alpha,
                "lower_share_percent": round(lower_share, 2),
                "head_changed_pixels": head,
                "head_alpha_changed_pixels": head_alpha,
                "accepted": frame_accepted,
            })
        pair_changed, pair_alpha = changed(frames[0], frames[1])
        accepted = accepted and pair_changed >= 8
        results["trials"][monster_id] = {
            "body_plan": body_plan,
            "frames": frame_results,
            "frame_pair_changed_pixels": pair_changed,
            "frame_pair_alpha_changed_pixels": pair_alpha,
            "accepted": accepted,
        }
        print(
            f"{monster_id}: accepted={accepted} "
            f"changed={[frame['changed_pixels'] for frame in frame_results]} "
            f"lower_share={[frame['lower_share_percent'] for frame in frame_results]} "
            f"head_alpha={[frame['head_alpha_changed_pixels'] for frame in frame_results]} "
            f"pair={pair_changed}"
        )
    results["summary"] = {
        "accepted_trials": sum(int(trial["accepted"]) for trial in results["trials"].values()),
        "total_trials": len(results["trials"]),
        "generated_walk_accepted": all(trial["accepted"] for trial in results["trials"].values()),
    }
    output = ROOT / "asset/monster/raw/walk_trial_metrics.json"
    output.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
