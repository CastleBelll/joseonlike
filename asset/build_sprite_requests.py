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
    ("fx_hit_phoenix", "asset/effect/hit_phoenix.png", "48x48", 5,
     "봉황 타격 표시. 1프레임이 가장 크고 마지막에 흩어져 사라진다"),
    ("fx_swing_arc", "asset/effect/swing_arc.png", "20x20", 2,
     "근접 휘두름 궤적. 초승달이 아니라 베기 자국 — 양끝이 바늘처럼 가늘다"),
    ("travel_hwabu", "asset/weapon/travel/hwabu.png", "18x18", 4,
     "화부 불덩이. 불꽃이 흔들려야 불로 읽힌다"),
    ("travel_hwaryeongbu", "asset/weapon/travel/hwaryeongbu.png", "16x18", 4,
     "화령부 불덩이. 화부보다 세게"),
    ("travel_sal", "asset/weapon/travel/sal.png", "18x18", 4,
     "살 저주 연기. 일렁여야 한다"),
    ("travel_gwisal", "asset/weapon/travel/gwisal.png", "16x18", 4,
     "귀살 저주 연기. 도깨비 얼굴이 일그러진다"),
    ("travel_old_talisman", "asset/weapon/travel/old_talisman.png", "18x10", 4,
     "낡은 부적. 종이가 팔랑이는 것이 이 무기의 정체다"),
    ("travel_fire_talisman", "asset/weapon/travel/fire_talisman.png", "18x10", 4,
     "화염 부적. 불길이 따라 흔들린다"),
    ("travel_beopgeom", "asset/weapon/travel/beopgeom.png", "20x7", 4,
     "법검 검기. 번쩍이면 좋지만 위의 것들보다 급하지 않다"),
    ("travel_bongmageom", "asset/weapon/travel/bongmageom.png", "20x7", 4,
     "봉마검 검기. 보랏빛이 흐른다"),
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

**이펙트**(`asset/effect/…`, `asset/weapon/fx/…`)는 프레임이 정사각이라
`너비 ÷ 높이`로 스스로 선언한다. 데이터에 적을 것이 없다.

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
    for stem, target, cell, frames, note in REQUESTS:
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
