"""Collect every asset that still needs FRAMES into one hand-off folder.

The owner builds the sprite sheets; this project's job is to hand over a clean
base image and say exactly what shape the sheet has to be. So each entry here
takes the generated render, cuts its flat backdrop to transparent, trims to the
drawing, and writes it to new_asset/needs_sprite/ next to a README that states
the target path, the cell size and how many frames are worth drawing.

Nothing under asset/ is touched. These are requests, not installs — a single
still cannot replace an animation, which is the whole reason they are here.

Run: python asset/build_sprite_requests.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "new_asset" / "generated"
OUT_DIR = ROOT / "new_asset" / "needs_sprite"

# Same cut as asset/build_from_generated.py: flood-fill inward from the corners
# rather than matching a colour globally, so a pale subject on a pale backdrop
# keeps its middle.
BACKGROUND_TOLERANCE = 26
MARKER = (255, 0, 255)

# (generated stem, target path, cell size, suggested frames, what it is)
REQUESTS = [
    ("fx_swing_arc", "asset/effect/swing_arc.png", "20x20", 2,
     "근접 휘두름 궤적. 초승달이 아니라 베기 자국 — 양끝이 바늘처럼 가늘다"),
    ("travel_hwabu", "asset/weapon/travel/hwabu.png", "18x18", 4,
     "화부 불덩이. 불꽃이 흔들려야 불로 읽힌다"),
    ("travel_hwaryeongbu", "asset/weapon/travel/hwaryeongbu.png", "16x18", 4,
     "화령부 불덩이. 화부보다 세게"),
    ("travel_old_talisman", "asset/weapon/travel/old_talisman.png", "18x10", 4,
     "낡은 부적. 종이가 팔랑이는 것이 이 무기의 정체다"),
    ("travel_fire_talisman", "asset/weapon/travel/fire_talisman.png", "18x10", 4,
     "화염 부적. 불길이 따라 흔들린다"),
]


# N9-85 per-weapon impacts. Twenty-seven weapons shared five hit effects, so
# a 법검 pierce and a 환도 slash flashed the same sprite. Each of these carries
# both the weapon's element (its colour) and its mechanic (the shape the hit
# makes), which one shared effect cannot do. Area weapons take a bigger cell
# than a point hit.
IMPACT_REQUESTS = [
    ("impact_old_talisman", "asset/effect/impact_old_talisman.png", "32x32", 5,
     "낡은 부적 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_gyeolgye", "asset/effect/impact_gyeolgye.png", "44x44", 5,
     "결계 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_divine_bow", "asset/effect/impact_divine_bow.png", "32x32", 5,
     "신궁 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_fire_talisman", "asset/effect/impact_fire_talisman.png", "32x32", 5,
     "화염 부적 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_hwabu", "asset/effect/impact_hwabu.png", "32x32", 5,
     "화부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_hwaryeongbu", "asset/effect/impact_hwaryeongbu.png", "32x32", 5,
     "화령부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_honbul", "asset/effect/impact_honbul.png", "32x32", 5,
     "혼불 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_flame_honbul", "asset/effect/impact_flame_honbul.png", "32x32", 5,
     "화령 혼불 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_hwayeom_gyeolgye", "asset/effect/impact_hwayeom_gyeolgye.png", "44x44", 5,
     "화염 결계 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_flame_sword", "asset/effect/impact_flame_sword.png", "32x32", 5,
     "화염검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_noebu", "asset/effect/impact_noebu.png", "32x32", 5,
     "뇌부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_noejeongbu", "asset/effect/impact_noejeongbu.png", "32x32", 5,
     "뇌정부 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_noe_sinjang", "asset/effect/impact_noe_sinjang.png", "32x32", 5,
     "뇌신장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_jineon", "asset/effect/impact_jineon.png", "44x44", 5,
     "진언 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_bongin_jineon", "asset/effect/impact_bongin_jineon.png", "44x44", 5,
     "봉인 진언 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_sal", "asset/effect/impact_sal.png", "32x32", 5,
     "살 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_gwisal", "asset/effect/impact_gwisal.png", "32x32", 5,
     "귀살 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_ghost_staff", "asset/effect/impact_ghost_staff.png", "32x32", 5,
     "귀철 석장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_ghost_sword", "asset/effect/impact_ghost_sword.png", "32x32", 5,
     "귀철검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_beopgeom", "asset/effect/impact_beopgeom.png", "32x32", 5,
     "법검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_bongmageom", "asset/effect/impact_bongmageom.png", "32x32", 5,
     "봉마검 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_seokjang", "asset/effect/impact_seokjang.png", "32x32", 5,
     "석장 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_sinjang", "asset/effect/impact_sinjang.png", "32x32", 5,
     "신장 소환 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_sword", "asset/effect/impact_sword.png", "32x32", 5,
     "환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_twin_sword", "asset/effect/impact_twin_sword.png", "32x32", 5,
     "쌍환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_sharp_sword", "asset/effect/impact_sharp_sword.png", "32x32", 5,
     "예리한 환도 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("impact_bow", "asset/effect/impact_bow.png", "32x32", 5,
     "각궁 타격. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
]

README_HEAD = """# 스프라이트 프레임이 필요한 것들

이 폴더의 PNG는 **배경을 날린 원본**이다. 프레임을 만들어 각자의 목표 경로에
넣으면 게임이 바로 읽는다.

## 시트 규약

가로로 셀을 이어 붙인 스트립. 셀 크기는 아래 표의 값 그대로다 —
4프레임이면 `18x10`이 `72x10`이 된다.

**투사체**(`asset/weapon/travel/…`)는 프레임 수를 `data/weapons.json`에
적어야 한다. 그 무기 항목에 한 줄 넣으면 된다:

```json
"travel_frames": 4
```

키를 빼면 1프레임(정지)으로 읽는다. 숫자가 폭을 나누지 못하면
`validate_data`가 실패한다. 투사체 그림은 정사각이 아니라서 파일 모양만으로는
프레임 수를 알 수 없기 때문에 적는 것이다.

**이펙트**(`asset/effect/…`)는 프레임이 정사각이라 `너비 ÷ 높이`로 스스로
선언한다. 프레임 수는 데이터에 적지 않는다.

다만 `impact_*`는 **새로운 이펙트 id**라 등록이 한 번 필요하다.
`data/effects.json`의 `sprite_effects`에 한 항목, 그리고 그 무기의
`hit_effect`를 새 id로 바꾼다:

```json
"impact_beopgeom": {
  "file": "res://asset/effect/impact_beopgeom.png",
  "fps": 32.0,
  "logical_px": 32.0
}
```

`logical_px`는 아래 표의 셀 크기와 같은 숫자다. 기존 `hit_*` 다섯 종은
그대로 두면 되고, 무기가 하나씩 새 id로 옮겨갈 때마다 쓰이지 않게 된다.

투사체는 12fps로 돌고 비행이 1초 미만이라 4프레임이면 충분하다.
그보다 많으면 플레이어가 못 본다.

## 목록

| 파일 | 목표 경로 | 셀 크기 | 권장 프레임 | 무엇 |
|---|---|---|---|---|
"""


def cut_background(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    for corner in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        ImageDraw.floodfill(rgb, corner, MARKER, thresh=BACKGROUND_TOLERANCE)
    out = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    source = rgb.load()
    target = out.load()
    for y in range(height):
        for x in range(width):
            pixel = source[x, y]
            if pixel != MARKER:
                target[x, y] = (*pixel, 255)
    return out


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f"drop folder missing: {SOURCE_DIR}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows: list[str] = []
    for stem, target, cell, frames, note in REQUESTS + IMPACT_REQUESTS:
        source = SOURCE_DIR / f"{stem}.png"
        if not source.exists():
            print(f"  {stem}: source missing, skipped")
            continue
        cut = cut_background(Image.open(source).convert("RGBA"))
        bounds = cut.split()[3].getbbox()
        if bounds is None:
            print(f"  {stem}: nothing left after the cut, skipped")
            continue
        # Trimmed to the subject so the owner starts from the drawing, not from
        # whatever margin the render happened to leave around it.
        trimmed = cut.crop(bounds)
        out_name = f"{stem}.png"
        trimmed.save(OUT_DIR / out_name)
        opaque = sum(1 for a in trimmed.split()[3].getdata() if a > 0)
        share = opaque / float(trimmed.size[0] * trimmed.size[1]) * 100.0
        print(f"  {out_name}: {trimmed.size}, {share:.0f}% opaque -> {target}")
        rows.append(f"| `{out_name}` | `{target}` | {cell} | {frames} | {note} |")
    (OUT_DIR / "README.md").write_text(
        README_HEAD + "\n".join(rows) + "\n", encoding="utf-8"
    )
    print(f"{len(rows)} requests written to {OUT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
