# 전체 재생성 · 프롬프트 전문

오너 결정 2026-08-27: **캐릭터·괴이 전부 같은 규격으로 다시 만든다.** 지금은 시트마다
캔버스도 격자도 인물 크기도 달라서, 자를 때마다 다른 규칙이 필요하고 편차도 제각각이다.

아래 19장이면 움직이는 것 전부다. 프롬프트는 하나의 템플릿에서 뽑아낸 것이라
여백·허용 편차·격자 문장이 시트마다 어긋나지 않는다. **통째로 복사해 쓴다.**
참조 이미지는 각 항목의 파일을 반드시 첨부한다.

---

## 1. 규격 — 전부 이것 하나

| 항목 | 값 |
|---|---|
| 이미지 | **1536 × 1024, 한 장** |
| 격자 | **4 × 4 = 16프레임** |
| 셀 | **384 × 256** |
| 인물 크기 | 자유. **단 16프레임이 서로 같은 크기여야 한다** |
| 여백 | 인물끼리·시트 가장자리와 투명 간격만 확보 (셀의 1/5 정도) |
| 배경 | 투명, 아니면 순수 마젠타 `#FF00FF` |
| 방향 | **한 시트 = 한 방향.** 16프레임 전부 같은 쪽을 본다 (달리기·공격은 오른쪽) |
| 금지 | 프레임 번호 · 격자선 · 워터마크 · 글자 · **좌우 반전 프레임** |

### 왜 이 숫자인가

- **1536×1024가 상한이다.** ChatGPT 이미지 모델이 내주는 크기는 1024×1024 · 1536×1024 ·
  1024×1536 셋뿐이다. 2048은 안 나온다.
- **인물 200px면 충분하다.** `asset/tools/bake_sheets.py` 가 캐릭터를 화면 **38px**, 괴이를
  30~33px로 그린다. 200px는 화면 크기의 5배가 넘는다 — 더 키워도 화면에서 안 보인다.
- **한 장으로 간다.** 8프레임씩 두 장으로 나누면 셀은 커지지만 두 장 사이에 크기·색·자세가
  어긋날 위험이 새로 생긴다. 지금 생성기는 한 장 안에서도 프레임 편차가 30~46px씩 나는
  상태라 장을 쪼개면 더 나빠진다.
- **크기·여백·정렬은 프롬프트가 아니라 커터가 맞춘다.** `asset/tools/bake_sheets.py`
  의 `cut_frames()` 가 알파 밴드로 행·열을 찾아 인물마다 자기 bbox로 크롭하고,
  `bake()` 가 한 접지선에 발을 맞추고 균일 스케일을 건다. 실측(도사 2026-08-27):
  구운 뒤 베이스라인 편차 1px, 중심 x 편차 1px. 그래서 "높이 200px·여백 30px" 같은
  수치는 프롬프트에서 뺐다 — 생성기는 픽셀을 못 재고, 재봐야 소용도 없다.
- **커터가 못 고치는 것 셋만 남겼다.** ① 방향 ② 인물끼리 붙지 않게 투명 간격
  (붙으면 밴드 탐지가 실패하고 폴백이 인물을 가로질러 자른다) ③ 16프레임 크기 동일
  (시트 전체에 스케일 하나가 걸리므로 작게 그린 프레임은 계속 작다).
- **한 방향만 그린다.** 왼쪽은 엔진에서 뒤집어 쓴다 (`CLAUDE.md` §5). 그런데 생성기가
  "9-16은 다리를 좌우 바꿔서"를 *인물 전체를 뒤집으라*는 뜻으로 읽어, 시트마다 오른쪽 8장 +
  왼쪽 8장이 나왔다. 그래서 LAYOUT에 반전 금지를 박고, 두 번째 스트라이드를 "다리 역할만
  맞바꾼다, 몸은 그대로 오른쪽"으로 다시 썼다.
- **잘림이 진짜 문제였다.** 직전 시트들은 인물이 셀을 꽉 채워 머리·발이 경계에서 잘렸다
  (두두리 공격·장군 원혼 공격은 네 변 모두 여백 0). 축소는 되돌릴 수 있어도 잘린 건 못
  되돌린다 — 그래서 "작게 그려라"를 프롬프트에 세 번 박았다.

## 2. 정지 그림(idle)은 다시 만들지 않는다

`idle.png` 단독 그림은 디자인 기준이고 위 프롬프트들의 참조 이미지다. 이걸 새로 뽑으면
얼굴과 색이 갈리므로 그대로 둔다. **예외 하나** — 숲 정령 정지만 342×498로 혼자 작다
(나머지 아홉은 1100~1250px). 이건 나중에 단독으로 다시 뽑는 게 맞다.

---
## 3. 도사 숨쉬기

참조 이미지: `asset/characters/taoist/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same spiky red
hair, same large conical straw hat worn ON THE BACK hanging from a cord across
the chest with its long red tassel, same indigo robe with blue trim over the
teal inner layer, same brown sash with the small pouch and the green tassel
ornament, same brown trousers, same dark navy shoes, same colour palette.
There is no staff.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw frame 1 once. Then produce frames 2 to 16 by COPYING frame 1 and moving
ONLY the chest, shoulders, head, the hair and the hat's red tassel and the hem. Everything else is
the identical drawing, pixel for pixel, in the identical position. This is not
16 drawings of the same character — it is one drawing with a few parts moved.
Below the chest nothing moves at all.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the straw hat, not its brim,
  not its red tassel. A limb cut off by the edge cannot be recovered;
  everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The soles of both feet sit on one ground line, at the same height in all 16
  frames.

POSE — the reference pose, held
- Keep exactly the standing pose and the exact facing of the reference image.
  Do not turn the character to the side.
- The feet, legs and hips are IDENTICAL in all 16 frames — copy them, do not
  redraw them.
- The straw hat STAYS ON THE BACK in every frame. It never moves to the head,
  never changes side, never flies off — it rides the shoulders, tipping a few
  degrees.

THE CYCLE — one slow breath, and it must LOOP
  1-8   inhale: chest and shoulders rise gradually, the head lifts a little.
        Frame 8 is the top of the breath.
  9-16  exhale: everything settles back down, slightly past neutral on frame
        14, then eases back so frame 16 leads into frame 1 with no jump.

AMPLITUDE — a breath, not a jump
- Shoulders and chest move about 4 pixels total between the lowest and the
  highest frame. Nothing moves more than that.
- The hair and the hat's red tassel ride the body, moving 2 pixels at most.
- The hem drifts about one frame BEHIND the body.
- The hips, legs and feet do not move at all.

EYES
- The eyes stay open, identical, and in the same position in every frame,
  EXCEPT a single blink: frame 13 half-closed, frame 14 fully closed, frame 15
  half-closed again. Nothing else about the face changes.

STYLE
Pixel art. 1px black outline, flat cel shading, no gradients, no drop shadow on
the background. Keep the palette tight and readable at small size — this is a
game sprite, not an illustration.
```

## 4. 도사 달리기

참조 이미지: `asset/characters/taoist/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same spiky red
hair, same large conical straw hat worn ON THE BACK hanging from a cord across
the chest with its long red tassel, same indigo robe with blue trim over the
teal inner layer, same brown sash with the small pouch and the green tassel
ornament, same brown trousers, same dark navy shoes, same colour palette.
There is no staff.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the character ONCE, then pose that same drawing 16 times. Head, body,
clothing, the hat, the sash and the pouch and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one character
re-posed, not 16 separate drawings.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the straw hat, not its brim,
  not its red tassel. A limb cut off by the edge cannot be recovered;
  everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- The straw hat STAYS ON THE BACK in every frame. It never moves to the head,
  never changes side, never flies off — it rides the shoulders, tipping a few
  degrees.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 5. 무사 숨쉬기

참조 이미지: `asset/characters/warrior/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same brown
topknot with the navy headband and the two red ribbons, same cream jeogori with
the crimson collar and sash, same brown trousers, same white socks and tan
shoes, same black sheathed sword at the left hip, same colour palette.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw frame 1 once. Then produce frames 2 to 16 by COPYING frame 1 and moving
ONLY the chest, shoulders, head, the topknot and the two red ribbons and the hem. Everything else is
the identical drawing, pixel for pixel, in the identical position. This is not
16 drawings of the same character — it is one drawing with a few parts moved.
Below the chest nothing moves at all.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the topknot, not the
  ribbons, not the sheathed sword or its tip. A limb cut off by the edge cannot
  be recovered; everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The soles of both feet sit on one ground line, at the same height in all 16
  frames.

POSE — the reference pose, held
- Keep exactly the standing pose and the exact facing of the reference image.
  Do not turn the character to the side.
- The feet, legs and hips are IDENTICAL in all 16 frames — copy them, do not
  redraw them.
- The sword STAYS SHEATHED at the left hip in every frame. It never changes
  side, never leaves the sash, and never swings freely — it rides the hip,
  tilting a few degrees. Its tip never swings behind the heel of the trailing
  foot.

THE CYCLE — one slow breath, and it must LOOP
  1-8   inhale: chest and shoulders rise gradually, the head lifts a little.
        Frame 8 is the top of the breath.
  9-16  exhale: everything settles back down, slightly past neutral on frame
        14, then eases back so frame 16 leads into frame 1 with no jump.

AMPLITUDE — a breath, not a jump
- Shoulders and chest move about 4 pixels total between the lowest and the
  highest frame. Nothing moves more than that.
- The topknot and the two red ribbons ride the body, moving 2 pixels at most.
- The hem drifts about one frame BEHIND the body.
- The hips, legs and feet do not move at all.

EYES
- The eyes stay open, identical, and in the same position in every frame,
  EXCEPT a single blink: frame 13 half-closed, frame 14 fully closed, frame 15
  half-closed again. Nothing else about the face changes.

STYLE
Pixel art. 1px black outline, flat cel shading, no gradients, no drop shadow on
the background. Keep the palette tight and readable at small size — this is a
game sprite, not an illustration.
```

## 6. 무사 달리기

참조 이미지: `asset/characters/warrior/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same brown
topknot with the navy headband and the two red ribbons, same cream jeogori with
the crimson collar and sash, same brown trousers, same white socks and tan
shoes, same black sheathed sword at the left hip, same colour palette.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the character ONCE, then pose that same drawing 16 times. Head, body,
clothing, the topknot, the ribbons and the sheathed sword and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one character
re-posed, not 16 separate drawings.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the topknot, not the
  ribbons, not the sheathed sword or its tip. A limb cut off by the edge cannot
  be recovered; everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- The sword STAYS SHEATHED at the left hip in every frame. It never changes
  side, never leaves the sash, and never swings freely — it rides the hip,
  tilting a few degrees. Its tip never swings behind the heel of the trailing
  foot.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 7. 궁수 숨쉬기

참조 이미지: `asset/characters/archer/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same red-brown
eyes, same very long dark plum-brown hair in a high ponytail, same purple ribbon
bow and white blossom hairpin with its gold beads and purple tassel, same cream
jeogori with the crimson inner collar, same purple sash and skirt panels with
the gold blossom embroidery, same brown pouch and chest strap, same dark quiver
on the back with its white-fletched arrows and red tassel, same dark plum
trousers, same white socks with red bead ties, same dark shoes with gold trim,
same recurve bow with its ornate gold tips, purple grip wrap, white string and
the hanging charm of a teal bead, a white blossom and a purple tassel, same
colour palette.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw frame 1 once. Then produce frames 2 to 16 by COPYING frame 1 and moving
ONLY the chest, shoulders, head, the ponytail, the ribbon tails and the tassels and the hem. Everything else is
the identical drawing, pixel for pixel, in the identical position. This is not
16 drawings of the same character — it is one drawing with a few parts moved.
Below the chest nothing moves at all.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the ponytail, not the bow or
  its tips, not the quiver arrows. A limb cut off by the edge cannot be
  recovered; everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The soles of both feet sit on one ground line, at the same height in all 16
  frames.

POSE — the reference pose, held
- Keep exactly the standing pose and the exact facing of the reference image.
  Do not turn the character to the side.
- The feet, legs and hips are IDENTICAL in all 16 frames — copy them, do not
  redraw them.
- The bow STAYS GRIPPED in the same hand in every frame, held low and angled
  back along the run. It never changes hand, never leaves the hand, never is
  drawn, never is aimed. Its lower tip never swings behind the hips.
- The quiver STAYS ON THE BACK with the same arrows in it in every frame.
- The ponytail never streams wider than the character is tall.

THE CYCLE — one slow breath, and it must LOOP
  1-8   inhale: chest and shoulders rise gradually, the head lifts a little.
        Frame 8 is the top of the breath.
  9-16  exhale: everything settles back down, slightly past neutral on frame
        14, then eases back so frame 16 leads into frame 1 with no jump.

AMPLITUDE — a breath, not a jump
- Shoulders and chest move about 4 pixels total between the lowest and the
  highest frame. Nothing moves more than that.
- The ponytail, the ribbon tails and the tassels ride the body, moving 2 pixels at most.
- The hem drifts about one frame BEHIND the body.
- The hips, legs and feet do not move at all.

EYES
- The eyes stay open, identical, and in the same position in every frame,
  EXCEPT a single blink: frame 13 half-closed, frame 14 fully closed, frame 15
  half-closed again. Nothing else about the face changes.

STYLE
Pixel art. 1px black outline, flat cel shading, no gradients, no drop shadow on
the background. Keep the palette tight and readable at small size — this is a
game sprite, not an illustration.
```

## 8. 궁수 달리기

참조 이미지: `asset/characters/archer/idle.png`

```
Pixel art sprite sheet of the character in the attached reference image.
Keep the character EXACTLY as drawn in the reference: same face, same red-brown
eyes, same very long dark plum-brown hair in a high ponytail, same purple ribbon
bow and white blossom hairpin with its gold beads and purple tassel, same cream
jeogori with the crimson inner collar, same purple sash and skirt panels with
the gold blossom embroidery, same brown pouch and chest strap, same dark quiver
on the back with its white-fletched arrows and red tassel, same dark plum
trousers, same white socks with red bead ties, same dark shoes with gold trim,
same recurve bow with its ornate gold tips, purple grip wrap, white string and
the hanging charm of a teal bead, a white blossom and a purple tassel, same
colour palette.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the character ONCE, then pose that same drawing 16 times. Head, body,
clothing, the ponytail, the bow, the quiver and the tassels and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one character
re-posed, not 16 separate drawings.

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
- NOTHING REACHES THE OUTER EDGE of the image, not the ponytail, not the bow or
  its tips, not the quiver arrows. A limb cut off by the edge cannot be
  recovered; everything else can.
- THE CHARACTER IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the character visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- The bow STAYS GRIPPED in the same hand in every frame, held low and angled
  back along the run. It never changes hand, never leaves the hand, never is
  drawn, never is aimed. Its lower tip never swings behind the hips.
- The quiver STAYS ON THE BACK with the same arrows in it in every frame.
- The ponytail never streams wider than the character is tall.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 9. 숲 도깨비 걷기

참조 이미지: `asset/monsters/forest_goblin/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 10. 숲 정령 걷기

참조 이미지: `asset/monsters/forest_spirit/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 11. 죽림 거한 걷기

참조 이미지: `asset/monsters/bamboo_brute/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 12. 그슨대 걷기

참조 이미지: `asset/monsters/geuseundae/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 13. 두두리 걷기

참조 이미지: `asset/monsters/dudueori/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 14. 잿귀 걷기

참조 이미지: `asset/monsters/ash_wraith/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 15. 녹슨 갑주 망령 걷기

참조 이미지: `asset/monsters/rusted_armor/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 16. 들개 요괴 걷기

참조 이미지: `asset/monsters/cursed_hound/idle.png`

네 발 짐승이라 사이클이 다르다 — 대각선 쌍으로 움직인다.

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The GROUND LINE is at the same height in every frame. Whenever a paw is
  planted, it lands on that line.

- Strict side view, facing RIGHT in all 16 frames.

THE CYCLE — two full four-legged strides, eight frames each, and it must LOOP
  1  contact: front-right paw strikes ahead, hind-left pushing off behind
  2  down: weight settles, the spine compresses SLIGHTLY — it does not crouch
  3  pass: front-right straightens under the body, hind legs gathering forward
  4  up: push-off, body at its highest point, no more than 11 pixels above the
     down frame
  5  suspension: all four paws off the ground, body extended
  6  reach: front-left reaches forward, hind legs fully behind
  7  pre-contact: front-left almost down, head lowering
  8  transition: front-left about to strike — this pose leads into frame 9
Frames 9-16 are the SECOND STRIDE of the same run, still facing RIGHT. Pose 9
is pose 1, pose 10 is pose 2, and so on through pose 16 which is pose 8 — with
ONLY the two diagonal leg pairs exchanging roles. The body is NOT mirrored and
the beast does NOT turn around: it keeps running to the RIGHT for all 16 frames.
Frame 16 must lead back into frame 1 with no jump.

MOTION DETAIL
- The head bobs no more than 6 pixels; it does not swing side to side.
- The tail trails BEHIND the motion by about one frame and never rises above the
  line of the back.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 17. 화약 도깨비 걷기

참조 이미지: `asset/monsters/powder_dokkaebi/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 18. 장군 원혼 걷기

참조 이미지: `asset/monsters/general_wraith/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, every carried item and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image. A limb cut off by the edge
  cannot be recovered; everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
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
  4  up: right foot pushes off the toe, body at its highest point, no more than
     11 pixels above the down frame
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
- Arms swing opposite the legs, elbows bent.
- Every carried or worn item stays in the same hand and on the same side in
  every frame. Nothing is picked up, dropped or swapped mid-cycle.
- Trailing cloth and hanging ornaments lag BEHIND the motion by about one frame:
  they are still catching up when the body has already moved. They never fly
  forward.
- The eyes stay open and identical in every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 19. 두두리 공격

참조 이미지: `asset/monsters/dudueori/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, the heavy wooden club and the cloth and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image, not the heavy wooden club at the
  widest point of the swing. A limb cut off by the edge cannot be recovered;
  everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The GROUND LINE is at the same height in every frame, and both feet stay planted on it. The creature may lunge, but it does not leave the
  ground and does not travel forward across the frames.
- Strict side view, facing RIGHT in all 16 frames.

THE CYCLE — one swing, and it must return to the start
  1-4    wind-up: the heavy wooden club winds back and the weight settles onto the back foot.
         The body twists away from the target.
  5-6    strike: the fastest two frames — the heavy wooden club sweeps across the front of the
         body and the arms extend fully.
  7-10   follow-through: the heavy wooden club carries past on its own momentum and the
         shoulders turn after it.
  11-16  recovery: the pose returns slowly to frame 1. Frame 16 leads into
         frame 1 with no jump.
- Frames 5 and 6 are the impact: the pose changes MOST between 4 and 5, and
  between 5 and 6. Everywhere else the change per frame is small. Do not space
  the swing evenly — an even swing reads as waving, not striking.

MOTION DETAIL
- The eyes stay open and identical in every frame.
- Cloth and any hanging ornament trail BEHIND the motion by about one frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 20. 장군 원혼 공격

참조 이미지: `asset/monsters/general_wraith/idle.png`

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Draw the creature ONCE, then pose that same drawing 16 times. Head, body,
clothing, the ghostly halberd and the cloth and limbs are the same shapes and the same number of pixels in
every frame — only their angles and positions change. This is one creature
re-posed, not 16 separate drawings.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them.
- NOTHING REACHES THE OUTER EDGE of the image, not the ghostly halberd at the
  widest point of the swing. A limb cut off by the edge cannot be recovered;
  everything else can.
- THE CREATURE IS THE SAME SIZE IN EVERY ONE OF THE 16 FRAMES. This is the one
  thing the cutter cannot repair: a single scale is applied to the whole sheet,
  so a frame drawn smaller stays smaller and the creature visibly shrinks and
  grows while it animates. Same head, same body, same limbs, same proportions,
  every frame. Draw all 16 at one comfortable size with room to spare — there
  is nothing to gain from drawing big.

HARD CONSTRAINTS — the cutter cannot fix these
- The GROUND LINE is at the same height in every frame, and both feet stay planted on it. The creature may lunge, but it does not leave the
  ground and does not travel forward across the frames.
- Strict side view, facing RIGHT in all 16 frames.

THE CYCLE — one swing, and it must return to the start
  1-4    wind-up: the ghostly halberd winds back and the weight settles onto the back foot.
         The body twists away from the target.
  5-6    strike: the fastest two frames — the ghostly halberd sweeps across the front of the
         body and the arms extend fully.
  7-10   follow-through: the ghostly halberd carries past on its own momentum and the
         shoulders turn after it.
  11-16  recovery: the pose returns slowly to frame 1. Frame 16 leads into
         frame 1 with no jump.
- Frames 5 and 6 are the impact: the pose changes MOST between 4 and 5, and
  between 5 and 6. Everywhere else the change per frame is small. Do not space
  the swing evenly — an even swing reads as waving, not striking.

MOTION DETAIL
- The eyes stay open and identical in every frame.
- Cloth and any hanging ornament trail BEHIND the motion by about one frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

## 21. 화약 도깨비 자폭

참조 이미지: `asset/monsters/powder_dokkaebi/idle.png`

터지는 시트라 루프하지 않는다. 뒤 네 프레임은 연기와 파편만 남는다.

```
Pixel art sprite sheet of the creature in the attached reference image.
Keep the creature EXACTLY as drawn in the reference: same silhouette, same body,
same horns, armour, cloth and ornaments, same eyes, same colour palette. Every
part that exists in the reference exists in every frame, with the same number of
pixels.
Do not redesign, restyle or simplify anything.

HOW TO BUILD IT — this is the important part
Frames 1 to 6 are ONE drawing of the creature re-posed — same shapes, same
number of pixels, only angles change. From frame 7 the creature is replaced by
the blast, and from frame 13 only smoke and falling debris remain.

HARD CONSTRAINTS — the cutter cannot fix these
- The blast, its sparks, its smoke and every piece of flying debris must stay
  well inside its own cell, with clear transparent space to the neighbours.
  In the previous sheet the debris crossed the top edge into the cell above, so
  cutting the sheet put one frame's fragments on top of another. If the blast
  does not fit, draw the blast smaller.
- The centre of the explosion stays at the same x in every frame, within 6
  pixels. It does not travel sideways.
- Frames 1 to 6: the creature is the same size throughout and its feet stay on
  one ground line.
- Strict side view, facing RIGHT in frames 1 to 6.

THE CYCLE — one detonation, and it does NOT loop
  1-3    the creature lifts the keg and the fuse catches — small, quick motion
  4-6    it hunches over the keg, the fuse burning down, the body tensing
  7-8    detonation: the two brightest frames, a white-hot core with the
         creature's silhouette vanishing inside it
  9-12   the fireball expands and cools from white to orange to deep red, with
         debris thrown outward
  13-16  only smoke and falling debris remain, thinning frame by frame. Frame 16
         is nearly empty — a few last embers.

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
  #FF00FF magenta and no magenta anywhere on the creature.

LAYING THE FRAMES OUT — read this, the last two sheets failed here
This sheet is cut by software. It finds each figure by the transparent space
around it, crops it, then rescales and re-aligns every frame on one baseline.
So the size you draw at, the margins and the exact centring DO NOT MATTER and
you should not fuss over them. Only these three things matter:
- LEAVE A CLEAR TRANSPARENT GAP around every figure — between neighbours, and
  between the figures and the outer edge of the image. Roughly a fifth of a cell
  on every side. Two figures that touch cannot be told apart, and the cut then
  slices through both of them. In the previous sheet the debris crossed into the
  cell above, which put one frame's fragments on top of another.
- NOTHING REACHES THE OUTER EDGE of the image, not a single spark or fragment.
  If the blast does not fit, draw the blast smaller.
- THE CREATURE IS THE SAME SIZE IN EVERY FRAME. This is the one thing the cutter
  cannot repair: a single scale is applied to the whole sheet, so a frame drawn
  smaller stays smaller and the creature visibly shrinks and grows while it
  animates. Same head, same body, same limbs, every frame.

STYLE
Side-view pixel art. 1px black outline, flat cel shading, no gradients, no
drop shadow on the background. Keep the palette tight and readable at small
size — this is a game sprite, not an illustration.
```

---

## 22. 받고 나서

1. 백업 — `new_asset/source/sheets/<name>-<action>.png` 로 사본 (ART_PROMPTS §7의 0번)
2. 실측 — 셀 경계 접촉 · 발바닥 편차 · 폭/높이 편차
3. 컷 — 4×4 격자를 명시해서 자르고 발 기준 정렬, 리터칭 0
4. 아티팩트 갱신
