# 이미지 생성 프롬프트 · 규격

오너가 이미지를 만들고, 이 문서가 그 이미지가 **게임에 그대로 들어갈 수 있는 모양**인지를 정한다.
아래 규칙은 취향이 아니라 코드에서 읽었거나 실측으로 얻은 것이다.

**오너 지시 (2026-08-26): 앞으로 모든 스프라이트 요청 — 달리기·공격·숨쉬기 무엇이든 —
§3의 공통 블록을 빠짐없이 넣는다.**

`ASSET_SPEC.md`는 구 파이프라인(`asset/character/<Name>/Idle/rotations/`, `pixelize.py`,
`slice_sheet.py`) 기준이라 지금 코드와 어긋난다. 스프라이트·아이콘 규격은 **이 문서가 우선**이다.

---

## 1. 하드 계약 (코드에서 온 것)

### 1.1 아이콘 — 정사각 512

`scripts/ui/ui_icons.gd`가 정사각 rect를 `STRETCH_SCALE`로 채운다. **세로가 긴 아이콘은
화면에서 눌린다.** 표시 크기가 24~64px이므로 512면 충분하고 1024는 이득이 없다 — 오히려
작은 크기로 줄일 때 디테일이 뭉개져 구판보다 못해진다.

### 1.2 스프라이트 시트 — 지금은 격자, 엔진은 아직 스트립만 안다

`scripts/combat/sprite_sheet.gd`가 프레임 수를 `가로 ÷ 세로`로 센다. 그래서
**1254×1254 격자 시트는 프레임 1개로 읽힌다** — 애니메이션이 정지 그림이 되고 에러는 안 난다.
격자 읽기는 미구현(TASKS.md 큐). 그때까지 시트는 잘라서 넣는다.

크기 계약: 한 변 = 논리 크기 × 16 (`SpriteSheet.EXPORT_SCALE`)이었으나, 지금 들어오는
그림은 **1:1 네이티브 픽셀아트**(런 길이의 98~99%가 1px)라 이 계약과 해상도 클래스가 다르다.
화면 표시 배율은 미결(A/B/C, 아래 §6).

---

## 2. 시트 규격

| 항목 | 값 |
|---|---|
| 시트 크기 | **2048 × 2048** |
| 격자 | **4 × 4 = 16프레임** |
| 셀 | **512 × 512 정사각** |
| 읽는 순서 | 왼쪽→오른쪽, 윗줄 먼저 |
| 배경 | 투명, 아니면 순수 마젠타 `#FF00FF` |
| 금지 | 프레임 번호·격자선·워터마크·글자 |

행이 캔버스에 조금씩 다른 높이로 얹혀도 된다 — **자를 때 발 기준으로 정렬한다**(오너 결정
2026-08-26). 그 규칙은 프롬프트에 넣지 않는다.

---

## 3. 공통 블록 — 모든 요청에 그대로 넣는다

`{}`만 대상에 맞게 바꾼다.

```
HOW TO BUILD IT — this is the important part
{조립 지시: 숨쉬기는 "복사", 달리기·공격은 "재포즈" — §4 참조}

LAYOUT
- One image, 2048 x 2048 pixels.
- An exact 4 x 4 grid: 16 cells, each exactly 512 x 512 pixels.
- Reading order is left to right, top row first.
- One frame per cell. No frame numbers, no labels, no grid lines, no borders,
  no captions anywhere on the image.
- Fully transparent background. If transparency is not possible, a solid
  #FF00FF magenta and no magenta anywhere on the character.

HARD CONSTRAINTS — measured, not approximate
- The character must occupy no more than 80% of the cell height. There must be
  visible empty space above the head and below the feet in EVERY cell.
- Leave at least 60 pixels of empty space ABOVE the {머리 장식} and 40 pixels on
  the left and right in EVERY cell. Nothing — not the {소품 나열} — may touch
  or cross a cell edge.
- The character's total HEIGHT stays within {숨쉬기 2 / 움직임 16} pixels across
  all 16 frames. The silhouette must NOT shrink and grow.
- The vertical travel of the HEAD across the whole cycle is at most
  {숨쉬기 5 / 움직임 16} pixels.
- The character's total WIDTH stays within {숨쉬기 4 / 움직임 12} pixels across
  all 16 frames.
- The horizontal CENTRE of the body stays at the same x in all 16 frames,
  within {숨쉬기 2 / 움직임 4} pixels. It must not drift sideways.
- {발 규칙: §4 참조}

STYLE
{Side-view }pixel art at native resolution — 1 pixel is 1 pixel, no upscaled
blocks. 1px black outline, flat cel shading, no gradients, no anti-aliasing,
no drop shadow on the background.
```

**이 블록이 실제로 산 것** (무사 숨쉬기 전후 실측):

| | 넣기 전 | 넣은 뒤 |
|---|---|---|
| 중심 x 편차 | 30px | **5px** |
| 폭 편차 | 21px | **10px** |

가장 효과가 큰 한 줄은 `HOW TO BUILD IT`이다. "일관되게 유지해라"는 안 통하고
**"프레임 1을 복사해라"**가 통한다.

---

## 4. 동작별 블록

### 4.1 숨쉬기 (idle)

조립 지시:
```
Draw frame 1 once. Then produce frames 2 to 16 by COPYING frame 1 and moving
ONLY the chest, shoulders, head, {흔들리는 소품} and hem. Everything else is the
identical drawing, pixel for pixel, in the identical position. This is not
16 drawings of the same character — it is one drawing with a few parts moved.
```

발 규칙 · 자세 · 사이클:
```
- The soles of both feet sit on the same baseline in all 16 frames, within
  1 pixel.

POSE — the reference pose, held
- Keep exactly the standing pose and the exact facing of the reference image.
  Do not turn the character to the side.
- The feet, legs and hips are IDENTICAL in all 16 frames — copy them, do not
  redraw them.
- {소품 고정: 예 "The sword stays sheathed at the left hip, in the same place,
  in every frame."}

THE CYCLE — one slow breath, and it must LOOP
  1-8   inhale: chest and shoulders rise gradually, the head lifts a little.
        Frame 8 is the top of the breath.
  9-16  exhale: everything settles back down, slightly past neutral on frame
        14, then eases back so frame 16 leads into frame 1 with no jump.

AMPLITUDE — a breath, not a jump
- Shoulders and chest move about 5 pixels total between the lowest and the
  highest frame. Nothing moves more than that.
- The {머리 장식} rides the head, moving 2-3 pixels.
- The {트레일 소품} and the hem drift about one frame BEHIND the body.
- The hips, legs and feet do not move at all.

EYES
- The eyes stay open, identical, and in the same position in every frame,
  EXCEPT a single blink: frame 13 half-closed, frame 14 fully closed, frame 15
  half-closed again. Nothing else about the face changes.
```

STYLE에서 `Side-view`를 **뺀다** — idle은 참조의 정면 자세를 유지한다.

### 4.2 달리기 (run)

조립 지시:
```
Draw the character ONCE at the size and proportions of the reference, then
pose that same drawing 16 times. The head, torso, clothing, {소품} and limbs
are the same shapes and the same number of pixels in every frame — only their
angles and positions change. This is one character re-posed, not 16 separate
drawings.
```

발 규칙 · 사이클:
```
- The GROUND LINE is the same in every frame: whenever a foot is planted, its
  sole lands on that one line, within 2 pixels. Only the airborne frames sit
  above it, and by no more than 12 pixels.
- Strict side view, facing RIGHT in all 16 frames.

THE CYCLE — two full strides, eight frames each, and it must LOOP
Frames 1-8, right leg leading:
  1  contact: right foot strikes ground ahead, left leg extended behind, torso
     leaning forward, both arms mid-swing
  2  down: weight settles onto the right leg, the knee bends SLIGHTLY — the
     body dips only a few pixels, it does not crouch
  3  pass: right leg straightens under the body, left knee drives forward past
     it, body rising
  4  up: right foot pushes off the toe, body at its highest point, no more
     than 16 pixels above the down frame
  5  airborne: both feet off the ground, left leg swinging forward, right leg
     trailing back
  6  reach: left leg extends forward preparing to land, right leg fully behind
  7  pre-contact: left foot almost down, torso leaning further forward
  8  transition: left foot about to strike — this pose leads into frame 9
Frames 9-16 repeat 1-8 with the legs and arms swapped (left leg leading).
Frame 16 must lead back into frame 1 with no jump.

MOTION DETAIL
- Arms swing opposite the legs, elbows bent, hands loose and empty.
- {소품 고정 — 달리기에서 가장 잘 깨진다}
- The {트레일 소품} and the hem trail BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.
```

**2번·4번 줄이 핵심이다.** `bends SLIGHTLY / does not crouch`가 없으면 실루엣 높이가
14%까지 흔들려 뛰는 게 아니라 통통 튀어 보인다(무사 달리기 실측 40px).

### 4.3 공격 (attack)

조립 지시는 달리기와 같다. 사이클만 바꾼다:
```
- The GROUND LINE is the same in every frame: both feet stay planted on that
  one line, within 2 pixels. The character may lunge, but it does not leave
  the ground and does not travel forward across the frames.

THE CYCLE — one swing, and it must return to the start
  1-4    wind-up: {무기}가 뒤로 감기고, 무게가 뒷발로 실린다. 몸이 반대로 비틀린다
  5-6    strike: 가장 빠른 두 장 — {무기}가 몸 앞을 지나며 팔이 완전히 펴진다
  7-10   follow-through: {무기}가 관성으로 더 나가고 어깨가 따라 돌아간다
  11-16  recovery: 천천히 1번 자세로 돌아온다. 프레임 16은 프레임 1로 이어진다
- Frames 5 and 6 are the impact: the pose changes MOST between 4 and 5, and
  between 5 and 6. Everywhere else the change per frame is small.
```

공격은 **타이밍이 불균등해야** 한다 — 준비는 느리고 타격은 두 장이다. 등속으로 그리면
휘두르는 게 아니라 손을 젓는 것으로 보인다.

---

## 5. 캐릭터 디자인 잠금

참조 이미지는 **반드시 첨부한다.** 말로만 "레퍼런스에 맞춰"는 통하지 않는다.
**참조는 그 캐릭터의 idle을 쓴다** — 이미 만든 다른 동작 시트를 참조로 쓰면 디자인이 갈린다
(오너 지적 2026-08-26).

### 도사 — `asset/characters/taoist/taoist_idle_hd_sprite.png`

```
same face, same spiky red hair, same large conical straw hat worn ON THE BACK
hanging from a cord across the chest with its long red tassel, same indigo
robe with blue trim over the teal inner layer, same brown sash with the small
pouch and the green tassel ornament, same brown trousers, same dark navy
shoes, same colour palette.
```
소품 고정: `The straw hat STAYS ON THE BACK in every frame. It never moves to
the head, never changes side — it rides the shoulders, tipping a few degrees.`
지팡이는 **없다.**

### 무사 — `asset/characters/warrior/idle.png`

```
same face, same brown topknot with the navy headband and the two red ribbons,
same cream jeogori with the crimson collar and sash, same brown trousers, same
white socks and tan shoes, same black sheathed sword at the left hip, same
colour palette.
```
소품 고정: `The sword STAYS SHEATHED at the left hip in every frame. It never
changes side, never leaves the sash, and never swings freely — it rides the
hip, tilting a few degrees as the hips rotate.`

### 궁수 — 아직 없음

`asset/characters/archer/` 폴더가 없어 PlaceholderArt로 선다. idle 한 장이 먼저 필요하고,
그것이 이후 모든 동작의 참조가 된다. 기준: 도사·무사와 같은 비율, 어리고 단정한 얼굴
(늙은 남자 금지), 녹색 계열(`archer_green`), 각궁과 화살통.

---

## 6. 아직 안 정해진 것

새 그림은 1:1 네이티브라 캐릭터가 약 225px 높이다. 엔진은 `1/16`로 그려서 화면 14px이 된다
(구판은 32px). 셋 중 하나를 골라야 한다:

- **A** 캐릭터를 화면에서 크게 (32 → 64px). 새 그림이 보인다. 적 밀도·카메라·히트박스 체감이
  바뀌어 밸런스 재측정 필요, 몬스터도 같이 커져야 한다
- **B** 지금 크기 유지, 그림을 1/6로 축소. 코드 변경 0, 얼굴·술·주름은 사라짐
- **C** 논리 40×40에 16배 블록으로 재생성. 기존 계약 그대로, 지금 정보량을 못 씀

---

## 7. 받은 뒤 이쪽에서 하는 일

1. 실측 — 폭·높이·발바닥·중심 x 편차, 셀 경계 접촉
2. 컷 — 격자대로 자르고 **발 기준 정렬**(행 어긋남은 여기서 없어진다), 리터칭 0
3. 확인 — 아티팩트에 32프레임 애니메이션으로 올려 눈으로 본다
4. 검증 — `godot --headless --path . --script tools/validate_data.gd`
   그리고 `godot --headless --path . --script tests/run_tests.gd`

**리터칭은 하지 않는다.** 한때 프레임 번호를 지우려고 셀 좌상단의 흰 픽셀을 지웠는데,
눈 하이라이트가 같은 조건에 걸려 캐릭터들의 눈이 날아갔다. 번호 없는 시트를 받는 것으로
바꿨고 지우는 단계는 삭제했다.
