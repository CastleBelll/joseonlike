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
화면에서 눌린다.** 게임에 넣는 파일은 512다 — 표시 크기가 24~64px이라 그 이상은 용량만 는다.

**단, 만들 때는 1024로 뽑아서 512로 줄인다 (오너 지적 2026-08-27).** 이전 판에는
"1024는 이득이 없다"고 적혀 있었는데 그건 틀렸다. 실측하면 축소가 손해가 아니라 이득이다:
무사 정지를 512 높이로 LANCZOS 축소했을 때 색 수가 78,925 → 34,602로 절반이 되면서
실루엣과 윤곽은 그대로였다. 축소가 곧 안티앨리어싱이라 512로 직접 뽑은 것보다 가장자리가
깨끗하다. **시트에는 이 방법을 못 쓴다** — 시트는 이미 1536×1024가 상한이라 2배로 뽑을
여지가 없다(§2).

### 1.2 스프라이트 시트 — 지금은 격자, 엔진은 아직 스트립만 안다

`scripts/combat/sprite_sheet.gd`가 프레임 수를 `가로 ÷ 세로`로 센다. 그래서
**1254×1254 격자 시트는 프레임 1개로 읽힌다** — 애니메이션이 정지 그림이 되고 에러는 안 난다.
격자 읽기는 미구현(TASKS.md 큐). 그때까지 시트는 잘라서 넣는다.

크기 계약: 한 변 = 논리 크기 × 16 (`SpriteSheet.EXPORT_SCALE`)이었으나, 지금 들어오는
그림은 해상도 클래스가 다르다. 화면 표시 배율은 미결(A/B/C, 아래 §6).

**"네이티브 픽셀아트"라는 판정은 틀렸다 (2026-08-27 재측정).** 이전 판은 1px 런 비율만 보고
98~99%면 네이티브라고 적었는데, 색 수를 같이 보면 이야기가 반대다:

| 샘플 | 1px 런 | 색 수 | 실제 성격 |
|---|---|---|---|
| 무사 정지 | 86.6% | **78,927** | 부드러운 렌더 |
| 궁수 정지 | 90.8% | **173,925** | 부드러운 렌더 |
| 뇌정부 아이콘 | 96.6% | **67,450** | 부드러운 렌더 |
| 장군 원혼 정지 | 0.0% | 236 | 진짜 블록 픽셀아트 |
| 환도 아이콘 | 60.9% | 97 | 진짜 클린 픽셀아트 |

픽셀마다 색이 미세하게 달라서 1px 런이 높게 나온 것뿐이다. **수만 색짜리 그림은 픽셀아트가
아니라 일러스트**이고, 그런 그림은 축소해도 잃을 "1px 윤곽"이 애초에 없다 — 그래서 §1.1의
1024→512 축소가 통한다. 반대로 색이 수백 개인 진짜 픽셀아트(장군 원혼 정지·환도 아이콘)는
정수배가 아닌 축소를 하면 블록이 깨진다. **판정은 1px 런이 아니라 색 수로 한다.**

---

## 2. 시트 규격

| 항목 | 값 |
|---|---|
| 시트 크기 | **1536 × 1024, 한 장** |
| 격자 | **4 × 4 = 16프레임** |
| 셀 | **384 × 256** |
| 인물 최대 | **높이 200px · 폭 320px** |
| 최소 여백 | 위 30 · 아래 20 · 좌우 30 |
| 읽는 순서 | 왼쪽→오른쪽, 윗줄 먼저 |
| 배경 | 투명, 아니면 순수 마젠타 `#FF00FF` |
| 금지 | 프레임 번호·격자선·워터마크·글자 |

**이 숫자가 나온 경위 (2026-08-27).** 원래 계약은 2048×2048 한 장에 셀 512였는데, 그림을
만드는 ChatGPT 이미지 모델이 내주는 크기는 **1024×1024 · 1536×1024 · 1024×1536** 셋뿐이라
2048은 애초에 나올 수 없었다. 그 사이 들어온 시트는 1536×1024 한 장에 16프레임이었고 셀이
384×256이 되어 인물이 세로로 꽉 차 머리·발이 잘렸다(두두리 공격·장군 원혼 공격은 네 변 모두
여백 0).

중간에 "8프레임씩 두 장으로 나눠 셀을 384×512로 키우자"고 적었다가 되물렸다. 두 장으로
나누면 장 사이에 크기·색·자세가 어긋나는 새 실패 모드가 생기는데, 지금 생성기는 한 장 안에서도
프레임 편차가 30~46px씩 나기 때문이다. 그리고 **디테일은 애초에 문제가 아니었다** —
`asset/tools/bake_sheets.py`가 캐릭터를 화면 38px, 괴이를 30~33px로 그린다. 셀 256 안의
200px 인물도 화면 크기의 5배가 넘는다. 잘림만 막으면 되고, 잘림은 셀을 키워서가 아니라
**인물을 작게 그리게 해서** 막는다.

전체 재생성용 프롬프트 19장은 [new_asset/REGEN_PROMPTS.md](../new_asset/REGEN_PROMPTS.md)에
있고, 하나의 템플릿에서 생성해 규격 문장이 시트마다 어긋나지 않는다.

행이 캔버스에 조금씩 다른 높이로 얹혀도 된다 — **자를 때 발 기준으로 정렬한다**(오너 결정
2026-08-26). 그 규칙은 프롬프트에 넣지 않는다.

---

## 3. 공통 블록 — 모든 요청에 그대로 넣는다

`{}`만 대상에 맞게 바꾼다.

```
HOW TO BUILD IT — this is the important part
{조립 지시: 숨쉬기는 "복사", 달리기·공격은 "재포즈" — §4 참조}

LAYOUT
- One image, 1536 x 1024 pixels. Do not produce any other size.
- An exact 4 x 4 grid: 16 cells, each exactly 384 x 256 pixels.
- Reading order is left to right, top row first.
- ONE FACING FOR THE WHOLE SHEET. Every cell shows the character facing the
  SAME way. Never mirror, flip or turn the character in any frame. Do NOT split
  the sheet into a right-facing half and a left-facing half — the game flips the
  sprite in engine, so a left-facing frame is a wasted frame and it makes the
  animation snap back and forth.
- One frame per cell. No frame numbers, no labels, no grid lines, no borders,
  no captions anywhere on the image.
- Fully transparent background. If transparency is not possible, a solid
  #FF00FF magenta and no magenta anywhere on the character.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image, not {소품 나열}. A limb cut off by
  the edge cannot be recovered; everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The character's total HEIGHT stays within {숨쉬기 2 / 움직임 11} pixels across
  all 16 frames. The silhouette must NOT shrink and grow.
- The vertical travel of the HEAD across the whole cycle is at most
  {숨쉬기 4 / 움직임 11} pixels.
- The character's total WIDTH stays within {숨쉬기 3 / 움직임 8} pixels across
  all 16 frames.
- {발 규칙: §4 참조}

STYLE
{Side-view }pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
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
- The soles of both feet sit on one ground line, at the same height in all 16
  frames.

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
- The GROUND LINE is at the same height in every frame. Whenever a foot is
  planted, its sole lands on that line. Only the airborne frames sit above it,
  and only slightly.

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
Frames 9-16 are the SECOND STRIDE of the same run, still facing RIGHT. Pose 9
is pose 1, pose 10 is pose 2, and so on through pose 16 which is pose 8 — with
ONLY the two legs exchanging roles (the leg that led in frames 1-8 now trails,
the trailing one now leads) and the two arms exchanging with them. The body is
NOT mirrored and the character does NOT turn around: it keeps running to the
RIGHT for all 16 frames.
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
- The GROUND LINE is at the same height in every frame, and both feet stay planted on it. The character may lunge, but it does not leave
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

### 무사 — `asset/characters/warrior/idle_reference.png`

`warrior/idle.png`를 쓰지 마라 — 그건 이제 16프레임 인게임 스트립(10896×681)이다.
`idle_reference.png`는 `breath.png` 1번 프레임을 잘라낸 것(인물 220×305, 리터칭 0)이고,
지금 남아 있는 그 자세의 최고 해상도 사본이다.

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

0. **백업 — 받는 즉시 `new_asset/source/sheets/<name>-<action>.png` 로 사본을 뜬다.**
   실측보다 먼저 한다.
1. 실측 — 폭·높이·발바닥·중심 x 편차, 셀 경계 접촉
2. 컷 — 격자대로 자르고 **발 기준 정렬**(행 어긋남은 여기서 없어진다), 리터칭 0
3. 확인 — 아티팩트에 32프레임 애니메이션으로 올려 눈으로 본다
4. 검증 — `godot --headless --path . --script tools/validate_data.gd`
   그리고 `godot --headless --path . --script tests/run_tests.gd`

**0번이 왜 0번인가 (2026-08-26).** 오너가 준 무사 HD idle이 `asset/characters/warrior/idle.png`
에만 있고 커밋되지 않은 상태였는데, 다른 세션의 굽기 작업(`asset/tools/bake_sheets.py`,
커밋 `7fafdd8`)이 스트립 출력 파일명으로 같은 `idle.png`를 써서 덮어썼다. 그 작업은 4×4 시트는
`new_asset/source/sheets/`에 백업했지만 단독 idle은 백업 대상이 아니었다. git에도 없고 디스크에도
없고 Godot import 캐시(경로 해시가 같아 함께 덮어써짐)에도 없어 복구가 불가능했고, 오너가 다시
넣어야 했다. **오너가 준 파일은 이 저장소에서 유일본으로 취급한다.**

**리터칭은 하지 않는다.** 한때 프레임 번호를 지우려고 셀 좌상단의 흰 픽셀을 지웠는데,
눈 하이라이트가 같은 조건에 걸려 캐릭터들의 눈이 날아갔다. 번호 없는 시트를 받는 것으로
바꿨고 지우는 단계는 삭제했다.
