# 이미지 생성 프롬프트 · 규격

오너가 이미지를 만들고, 이 문서가 그 이미지가 **게임에 그대로 들어갈 수 있는 모양**인지를 정한다.
아래 "하드 계약"은 취향이 아니라 코드에서 읽은 사실이다 — 어기면 조용히 깨진다.

`ASSET_SPEC.md`는 구 파이프라인(`asset/character/<Name>/Idle/rotations/`, `pixelize.py`,
`slice_sheet.py`) 기준이라 지금 코드와 어긋난다. 스프라이트·아이콘 규격은 **이 문서가 우선**이다.

---

## 1. 하드 계약 (코드에서 온 것)

### 1.1 걷기·공격 시트 — 가로 한 줄, 정사각 프레임

`scripts/combat/sprite_sheet.gd`:

```gdscript
var side: float = strip.get_size().y
var count: int = int(strip.get_size().x / side)
```

프레임 수 = **가로 ÷ 세로**. 그러므로:

- 프레임은 **정사각**이어야 한다. 세로가 긴 셀은 규격 위반이다.
- 시트는 **가로 한 줄**이어야 한다. 2행 이상 격자(8×4 같은 것)는 못 읽는다.
- `1536x1024`짜리 시트는 `1536/1024 = 1` → **한 프레임짜리 애니메이션**이 된다.
  걷기가 정지 그림이 되고 에러는 하나도 안 난다. 실제로 2026-08-26에 캐릭터 2종과
  몬스터 9종이 이 상태였다.

한 변 = 논리 크기 × **16** (`SpriteSheet.EXPORT_SCALE`). 현재 값:

| 대상 | 프레임 수 | 한 변 | 시트 크기 |
|---|---|---|---|
| 도사 · 무사 | 16 | 640 (40논리) | 10240 × 640 |
| 잿귀 · 들개 · 화약 도깨비 | 4 | 704 (44논리) | 2816 × 704 |
| 녹슨 갑주 | 4 | 832 (52논리) | 3328 × 832 |
| 장군 원혼 | 4 | 1408 (88논리) | 5632 × 1408 |
| 죽림 거한 | 16 | 736 (46논리) | 11776 × 736 |
| 두두리 | 16 | 1520 (95논리) | 24320 × 1520 |
| 숲 도깨비 | 16 | 496 (31논리) | 7936 × 496 |
| 숲 정령 | 16 | 544 (34논리) | 8704 × 544 |
| 그슨대 | 16 | 640 (40논리) | 10240 × 640 |

**프레임 수를 바꾸지 말 것.** 한 변도 바꾸지 말 것 — 몬스터는 `collision_radius`가
스프라이트 폭에 묶여 있어 검증기가 막는다.

### 1.2 idle — 단일 정사각 한 장

정사각이어야 한다. 세로가 긴 idle은 걷기 프레임과 크기가 안 맞아 서 있다가 걷는 순간
몸집이 바뀐다.

### 1.3 무기·전리품 아이콘 — 정사각 512

`scripts/ui/ui_icons.gd`:

```gdscript
rect.stretch_mode = TextureRect.STRETCH_SCALE
rect.custom_minimum_size = Vector2(display_size, display_size)
```

**정사각 rect를 채우도록 늘린다.** 세로가 긴 아이콘(1024×1536)은 화면에서 눌려 보인다.
표시 크기는 24~64px이므로 512면 충분하고, 1024는 파일만 커질 뿐 화면에서 이득이 없다 —
오히려 작은 크기로 줄일 때 디테일이 뭉개져 구판보다 못해질 수 있다.

### 1.4 배경 · 앵커 · 금지 사항

- **배경**: 투명(알파 0)이 최선. 안 되면 **순수 마젠타 `#FF00FF`** 한 색으로 깔고,
  피사체에는 마젠타가 한 픽셀도 없어야 한다. 그라디언트 배경은 자동 제거가 안 된다.
- **프레임 번호·격자선·워터마크·설명 글자 금지.** 지금 들어온 걷기 시트에는 각 칸에
  숫자가 박혀 있어 잘라도 그대로 게임에 들어간다.
- **앵커 고정**: 모든 프레임에서 **발바닥 y**와 **몸통 중심 x**가 같아야 한다. 프레임마다
  피사체 위치가 흔들리면 걸을 때 캐릭터가 떤다. "canvas 안에서 위치를 유지, 다리만 움직임"을
  프롬프트에 명시할 것.
- **좌우**: 오른쪽을 보게 그린다. 왼쪽은 엔진이 뒤집는다 — 왼쪽 버전을 따로 만들지 말 것.
- **필터 금지**: `project.godot`가 `default_texture_filter=0`이다. 임포트에서 필터를
  켜지 말 것.

---

## 2. 붙여넣는 프롬프트

`{}` 안만 바꿔 쓴다. 스타일 기준은 `new_asset/owner/`의 현재 PNG다 — 그 그림을 참조
이미지로 함께 넣는다. 말로만 "레퍼런스에 맞춰"는 안 통한다.

### 2.1 걷기 시트

```
Side-view pixel art walk cycle of {대상}, {특징 두세 개}.
ONE HORIZONTAL ROW of exactly {N} square frames, left to right, no second row.
Each frame is a perfect square of identical size; the full sheet is {N}:1 wide.
Solid #FF00FF magenta background, no magenta anywhere on the subject.
No frame numbers, no grid lines, no borders, no text, no drop shadow on the background.
The character stays in the SAME position in every frame — same foot baseline,
same body centre — only the legs, arms and cloth move. Facing RIGHT in all frames.
Chunky proportions, 1px black outline, flat cel shading, no gradients, no anti-aliasing.
```

### 2.2 공격 시트

걷기와 같되 이 두 줄을 바꾼다:

```
ONE HORIZONTAL ROW of exactly {N} square frames: wind-up, strike, follow-through, recovery.
The body may lunge, but the feet return to the same baseline in the first and last frame.
```

### 2.3 idle 한 장

```
Side-view pixel art of {대상}, standing still, facing RIGHT.
ONE single square image. Solid #FF00FF magenta background.
No text, no numbers, no border. Margin of empty background on all four sides —
do not crop the feet or the {머리 장식/무기}.
Chunky proportions, 1px black outline, flat cel shading.
```

### 2.4 무기 아이콘

```
Pixel art item icon of {무기 이름 — 한국어 이름과 영어 설명}, {재질·색}.
ONE single SQUARE image, the object centred with even margin on all four sides.
Transparent background (or solid #FF00FF magenta).
No text, no numbers, no frame, no pedestal, no hand holding it.
Diagonal three-quarter presentation, 1px black outline, flat cel shading,
readable as a silhouette at 32 pixels.
```

### 2.5 UI 아이콘 모음

UI 아이콘은 모음으로 받아도 된다 — 잘못 잘리면 눈에 바로 보이기 때문이다. 단:

```
{N} separate icons on ONE image, laid out on an exact {열}x{행} grid,
each icon centred in its own cell with even margin, cells all the same size.
Solid #FF00FF magenta background filling every cell.
No numbers, no labels, no grid lines drawn on the image.
```

---

## 3. 지금 필요한 것

### 3.1 무기 아이콘 8종 — 임시 그림이 들어가 있음

무사 (N10-7):

| id | 이름 | 프롬프트 핵심 |
|---|---|---|
| `wolto` | 월도 | 긴 나무 자루 끝에 초승달처럼 휜 외날, 자루에 붉은 술. 강철빛, 소박함 |
| `cheongryong_wolto` | 청룡언월도 | 같은 형태에 더 크고 화려한 날, 청록 옥빛 도신, 자루에 금빛 용 장식 |
| `pyeongon` | 편곤 | 짧은 손잡이 + 쇠사슬 두 마디 + 못이 박힌 타격봉, 나무와 무쇠 |
| `masang_pyeongon` | 마상편곤 | 같은 형태, 전부 강철, 타격봉에 금빛 못, 손잡이에 붉은 손목끈 |

궁수 (N10-8, 예정):

| id | 이름 | 프롬프트 핵심 |
|---|---|---|
| `soenoe` | 쇠뇌 | 나무 몸통 + 강철 활 + 방아쇠, 굵고 묵직함 |
| `sunogi` | 수노기 | 연발 쇠뇌 — 위에 화살통 상자가 얹힌 형태, 놋쇠 부속 |
| `pyeonjeon` | 편전 | 짧은 애기살 세 대와 통아(덧살대) 한 개가 나란히 |
| `yungnyangjeon` | 육량전 | 굵고 무거운 화살 한 대, 큰 쇠촉과 흰 깃 |

### 3.2 궁수 캐릭터 — 스프라이트가 아예 없음

`asset/characters/archer/`가 없어 지금은 PlaceholderArt로 선다. 필요한 것:

- `idle.png` — 정사각 한 장
- `walk.png` — 정사각 16프레임 가로 스트립, 한 변 640

기준: 도사·무사와 같은 2등신, 어리고 단정한 얼굴(늙은 남자 금지). 녹색 계열 배색
(`archer_green`), 각궁과 화살통, 시위를 당기지 않은 평상 자세.

---

## 4. 받은 뒤 이쪽에서 하는 일

- 모음 → 가로 스트립 분해: `python asset/tools/split_contact_sheet.py <파일>`
- 아이콘 이름·정사각 정규화: `python asset/ui/adopt_weapon_icons.py`
- 확인: `godot --headless --path . --script tools/validate_data.gd`
  그리고 `godot --headless --path . --script tests/run_tests.gd`
