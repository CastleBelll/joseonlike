# JOSEONLIKE — Asset Requirements

**Asset production is frozen.** The owner supplies art and audio. Do not generate, cut,
commission or "temporarily improve" assets during a feature session.

## Drop box layout (정리 2026-08-26)

```
new_asset/
  owner/      오너가 그렸거나 받아온 것 — 팩 하나에 폴더 하나
  generated/  생성 모델로 뽑은 원본. 파일명이 곧 설치 대상 id
  sheets/     스프라이트 시트 요청·수령분
  needs_sprite/ 아직 시트가 없는 것들의 참고 그림
  source/     게임 밖 원본 (지금은 오너의 BGM 원본)
  archive/    이제 쓰지 않는 것 — 지우지 않고 여기 둔다
```

폴더별로 무엇을 어떤 스크립트가 읽는지는 [new_asset/README.md](new_asset/README.md)에
표로 있다. 넷은 성격이 다르다: 오너 팩은 자체 라이선스가 붙은 원자재고, 생성물은
프롬프트로 다시 만들 수 있는 이 프로젝트의 산출물이며, `source/`는 게임 밖 원본,
`archive/`는 더 쓰지 않지만 버리지 않은 것이다 (오너 지시 2026-08-26: 삭제는 하지
말고 정리만). 어느 폴더의 것도 게임이 직접 읽지 않는다 — `.gdignore`가 임포트를
막고, 빌드 스크립트만 여기서 읽어 `asset/`으로 내보낸다.

## Owner drop box (2026-08-14)

The owner sources art himself and drops it into `new_asset/owner/`. Features ship with rough
placeholders and the art is wired in afterwards as its own commit.

- Drop raw files anywhere under `new_asset/owner/` — any resolution, green screen or
  transparent, sheet or single frame. Naming hint only: `<subject>.png`,
  `<subject>_walk.png`.
- Processing to game-ready assets (chroma key, area downscale, palette quantization,
  frame strip assembly) happens in a separate asset commit; the source file stays in
  `new_asset/owner/` untouched.
- Game-ready output lives at `asset/characters/<id>/{idle,walk,portrait}.png`,
  `asset/weapon/...`, `asset/drop/...`. Reference pipeline:
  `asset/characters/taoist/build_assets.py`.
- Nothing in `new_asset/owner/` is ever loaded by the game directly.

When a feature needs art that does not exist:

1. Ship the feature with `PlaceholderArt` (`scripts/combat/placeholder_art.gd`) or an
   existing sprite.
2. Add a `[MISSING]` entry below.
3. Continue. A missing asset never blocks or delays a gameplay feature.

Style, sizes, direction naming and set rules: [ASSET_SPEC.md](ASSET_SPEC.md).

Entry format:

```
[MISSING] <asset_id>
Size:      <WxH px>
Members:   <frames / rotations / states required>
Used by:   <feature or data id that references it>
Fallback:  <what ships until it arrives>
```

[MISSING] weapon_gyeolgye_ward
Size:      ~170x170 px (radius-scaled)
Members:   ward circle ground decal + placement flash, fire variant (화염 결계)
Used by:   weapons.json gyeolgye / hwayeom_gyeolgye (N4-4b)
Fallback:  palette-token rotating sigil — dashed ring + eight-point star (scripts/combat/ward.gd, N3-18)

[DELIVERED N9-8] summon_sinjang — asset/weapon/fx/sinjang.png (20x32,
           authored in asset/weapon/build_fx.py: helmed spirit-general in
           luminance, engine-modulated for the thunder variant), wired in
           scripts/combat/summon.gd. Idle/walk animation frames remain a
           nice-to-have for a future art pass.

[MISSING] fx_jineon_shockwave
Size:      ~270x270 px expanding ring
Members:   3-4 frame pulse ring, sealing-gold variant (봉인 진언)
Used by:   weapons.json jineon / bongin_jineon (N4-4b)
Fallback:  reused DeathPuff disc flash

[MISSING] fx_sal_curse_mark
Size:      ~16x16 px overhead mark
Members:   cursed-enemy marker (projectile variant shipped N9-3f)
Used by:   weapons.json sal / gwisal (N4-4b)
Fallback:  no on-enemy marker yet

[MISSING] ui_active_buttons
Size:      64x64 px each
Members:   축지/벽사진 icon discs, ready + cooling states (AC-3 scope)
Used by:   CombatHud active cluster (N4-4b)
Fallback:  wood-token drawn discs with the skill name

---

## 생성 프롬프트 틀 (오너 지시 2026-08-26: 프롬프트는 일관성 있게)

이미지 생성은 오너가 외부 서비스에서 돌린다 (higgsfield 종료, 이 PC는 내장 GPU라
로컬 생성 불가). 그래서 프롬프트는 **매번 새로 쓰지 않는다** — 아래 뼈대에 대상
문단만 갈아 끼운다. 뼈대가 흔들리면 화풍이 흔들리고, 화풍이 흔들리면 다시 만든다.

**A. 공통 스타일 줄 (모든 프롬프트 끝에 그대로 붙는다)**

```
Match the reference images exactly: chunky readable shapes, crisp 1-pixel dark
outline around the whole silhouette, flat cel shading with three tones per
material, small limited palette, no gradients, no anti-aliasing, no glow, no
texture noise. One subject only, fully inside the frame, no cropping.
Background must be pure bright magenta RGB 255 0 255 filling every pixel that
is not the subject. No shadow, no ground, no text, no border.
```

**B. 대상별로 바뀌는 것 — 이 네 줄만 채운다**

| 항목 | 내용 |
|---|---|
| 무엇 | 한 문장. 한국 전승 근거를 포함한다 (예: 세시풍속의 신발 도둑) |
| 자세·방향 | 옆모습/정면, 좌우 어느 쪽을 보는지, 무엇을 들고 있는지 |
| 색 | 재질별 색 이름, 3톤까지. 강조색은 하나만 |
| 하지 말 것 | 이 대상에서 반복해서 틀렸던 것 (예: 초승달 금지, 서양 브로드소드 금지) |

**C. 레퍼런스 이미지 (2장, 항상 함께 올린다)**

- `asset/monsters/forest_goblin/idle.png` — 괴이 밀도 기준
- `asset/characters/taoist/idle.png` — 캐릭터 밀도 기준
- 아이콘이면 대신 `asset/ui/loot_icons/ghost_iron.png` + `cinnabar.png`
- 진화형이면 **기본형 결과물**을 레퍼런스로 넣는다 (실루엣 연속성 규칙)

**D. 크기는 프롬프트가 아니라 여기서 정해진다**

생성물은 1024 정사각이면 충분하다. 논리 크기·그리드는 설치 스크립트가 맞춘다
(`asset/monsters/build_night2_sheets.py`, `asset/build_from_generated.py`).
프롬프트에 픽셀 수를 적지 않는다 — 적어도 지켜지지 않고, 지켜지면 오히려
그리드가 어긋난다.

**E. 받는 자리**

`new_asset/generated/<파일명>.png`. 파일명이 곧 데이터 id다.

---

## 새 무기 아이콘 대기 (B2 로스터 작업 중 계속 늘어남)

`validate_data`가 무기마다 `asset/ui/weapon_icons/<id>.png`를 **필수**로 요구하므로,
새 뿌리가 들어올 때마다 임시 아이콘을 같이 만든다. 전부 32 논리px · x16 NEAREST 계약.

| 무기 | 임시 아이콘 | 생성기 | 원하는 그림 |
|---|---|---|---|
| **검륜** 劍輪 (무사, orbit) | ○ 있음 | `asset/ui/build_geomryun_icon.py` | 검기 세 자락이 몸 주위를 도는 것. 지금은 링에 날 셋이 물린 도식이라 "돈다"는 읽히지만 검기 느낌은 없다 |

앞으로 들어올 것: 당파(thrust) · 등패(bulwark) · 철퇴(returning) · 돌격창(charge) ·
화전 · 철질려 · 비격진천뢰 · 노포 · 비도. 각각 같은 방식으로 임시본을 먼저 넣는다.

## 2차 애셋 재세팅 적용 (2026-08-27 저녁)

오너가 전 애셋을 다시 세팅하고 **캐릭터 이동을 walk / run으로 분리**했다.

- 시트 규격이 4×4(16프레임) → **5×5(25프레임)**, 1280×1280으로 바뀌었다.
- **25프레임은 논리 36px까지만 한 줄에 들어간다** (645px × 25 = 16125, 한계 16384).
  플레이어(38)와 큰 몹은 전부 초과라, 베이커가 **한계에서 역산해 자동으로 솎는다**
  (`fits_the_row`). 손으로 보스 목록을 관리하던 것을 없앴다 — 아트가 바뀔 때마다 낡는 목록이었다.
  결과: 캐릭터 24 · 그슨대 22 · 죽림거한 20 · 두두어리 10프레임.
- **run은 장소로 갈린다** — 본거지에서 걷고 출정에서 뛴다(오너 지시).
  조이스틱 세기가 아니다. 본거지는 아직 메뉴형이라 플레이어 노드가 없고,
  기본값이 걷기라 **맵형 본거지가 생기면 자동으로 맞는다.**
- `powder_dokkaebi/bombing.png`(자폭 25프레임)도 구웠지만 **아직 재생하는 곳이 없다** — 큐.

### 오너가 고쳐야 하는 것

| 파일 | 문제 |
|---|---|
| `asset/monsters/general_wraith/walk.png` | **없음.** `walk (2).png`만 있다 — 다운로드 중복 파일명이라 엔진이 못 읽는다. 이름만 바꾸면 된다 |
| `asset/monsters/rusted_armor/walk.png` | 혼자 옛 규격 1536×1024(4×4)로 남아 있다. 지금은 16프레임으로 구워지지만 다른 몹과 프레임 수가 다르다 |

## 몬스터 드롭 적용 완료 (2026-08-27)

오너가 몬스터 열 마리를 다시 만들어 넣었고, 캐릭터와 같은 방식으로 구웠다.
**원본은 건드리지 않았다** — `bake_sheets.py`는 `build/` 아래로만 쓰고, 산출물 경로가
소스로 해석되면 거부한다. 실행 후 수정 시각으로 확인했다: 가장 최근 소스가
가장 오래된 빌드 산출물보다 앞선다.

| | idle | walk | 논리 높이 |
|---|---|---|---|
| 숲 도깨비 | 단일 | 16프레임 | 30 |
| 저주받은 들개 | 단일 | 16프레임 | 30 |
| 숲 정령 | 단일 | 16프레임 | 32 |
| 가루 도깨비 | 단일 | 16프레임 | 32 |
| 잿귀 | 단일 | 16프레임 | 33 |
| 녹슨 갑주 | 단일 | 16프레임 | 36 |
| 그슨대 | 단일 | 16프레임 | 40 |
| 죽림 거한 | 단일 | 16프레임 | 44 |
| 장수 원귀 | 단일 | 16프레임 | 46 |
| **두두어리(보스)** | 단일 | **8프레임** | 84 |

**보스만 8프레임인 이유**: 84 논리px면 프레임이 1505px이고 16장이면 24080px —
GLES3 한계 16384를 절반 넘게 초과한다. 16프레임 가로 스트립에 들어가는 최대 논리
높이는 64px(1024×16=16384)라, **84px 보스는 물리적으로 16프레임이 불가능하다**.
크기를 지키고 프레임을 반으로 줄였다. 베이커는 이제 한계를 넘는 스트립을 만들려 하면
**만들지 않고 멈춘다**(무엇을 낮춰야 하는지 말한다).

`attack.png`는 두두어리·장수 원귀에 있지만 **굽지 않았다** — 엔진에 attack 애니메이션이
아직 없어서, 아무도 안 읽는 스트립은 조용히 낡는다. 엔진에 붙일 때 같이 굽는다.

### 남은 것 — 스테이지 프롭 4종 (오너 교체 중)

`water_puddle` · `prop_flame` · `anvil` · `stone_marker` — `props.json`이 참조하는데
파일이 없어 `validate_data`가 4건 FAIL이다. 몬스터 쪽은 전부 해소됐다.

## QA가 잡은 애셋 결함 (2026-08-27, 오너: 애셋은 내가 생성중이니 체크만)

자동 검사 QA · 시각 QA가 독립 worktree에서 찾은 것. 코드 쪽은 임시 가드까지 넣어뒀고
(아래 "코드가 이미 한 것"), 남은 것은 그림 자체를 다시 만들어야 한다.

### 막힌 것 — 재생성 필요

| 대상 | 지금 | 있어야 하는 것 | 왜 |
|---|---|---|---|
| **두두어리 walk** | **24320 × 1520** (16프레임 × 1520) | **가로 16384px 이하.** 셀 1024px면 16프레임이 정확히 16384로 딱 맞는다 | GLES3가 16384를 넘는 텍스처를 거부한다. `project.godot`은 데스크톱·모바일 둘 다 `gl_compatibility`라 **실기에서 못 읽는다**. 전 스프라이트 중 한계를 넘는 것은 이 한 장뿐 (다음이 죽림 거한 11776, 잿귀 9456 — 안전) |
| **가루 도깨비 idle/walk** | idle 셀 512 · walk 셀 704 | **한 변을 맞출 것** (다른 12개 디렉터리는 전부 일치) | 스케일이 고정 제수(`EXPORT_SCALE 16`)라 idle 32px → walk 44px, 걷기 시작 순간 **37.5% 크기 점프**가 보인다. CLAUDE.md §5 "walk cycles must be frame-consistent" 위반 |

### 규격에서 벗어난 것 — 다음 생성 때 반영

| 대상 | 관측 | ASSET_SPEC 계약 |
|---|---|---|
| 몬스터 스프라이트 전반 | 색 수가 계약의 **35~70배**, 논리 크기 약 2배, 알파 안티에일리어싱 4~6% | 52색 · 44~58 논리px · 1px 외곽선 · 플랫 셀 셰이딩 |
| 도사 | 논리 340px 그림을 화면 42.6px로 **8배 다운샘플** → 눈 한쪽이 사라지고 하반신이 배경에 녹는다. 같은 크기에서 무사는 또렷하다 | 화면 크기에 맞는 논리 해상도로 그릴 것 |
| 대나무 잎 | 얼음빛 파랑 | 대숲 팔레트 |
| 새 HUD 아이콘 5종 (엽전·해골·모래시계·정보·톱니) | 바깥 글로우, 면 그라데이션, 회색 안티에일리어싱 획 — 32px에서 뭉갠다 | 1px 외곽선 · 플랫 셀 셰이딩. **일시정지 1종만 채택했고 나머지는 안 쓰는 중** |

### 코드가 이미 한 것 (애셋을 기다리는 동안)

- `SpriteSheet.MAX_STRIP_PX` 가드 — 한계를 넘는 스트립은 **들어가는 프레임까지만** 쓰고,
  드라이버 어설션 대신 파일명·현재 폭·고칠 값을 말하는 경고를 낸다. 캐릭터가 사라지지는 않는다.
- 아이콘 슬라이서 `CONTENT_SCALE` — 잘라낸 글리프에 여백을 줘 원반 링에 파고들지 않게 했다.
- 미커밋 상태의 두두어리 교체본(1536×1024) 때문에 `test_enemy_sprite` 2건이 로컬에서
  실패 중이다. **그 두 파일만 빼면 전부 PASS**인 것을 확인했다 — 새 시트가 들어오면 해소된다.

## 재작업 대기 — 16프레임 규격 전환 (2026-08-26)

오너가 스프라이트를 4×4 격자 16프레임(셀 512 정사각)으로 전환했다. 규격과 프롬프트는
[docs/ART_PROMPTS.md](docs/ART_PROMPTS.md)에 있고, 받은 시트는
`python asset/tools/bake_sheets.py`로 게임용 스트립으로 굽는다.

### 적용 완료

| 대상 | 상태 |
|---|---|
| 도사 | ~~idle(숨쉬기 16프레임) · walk(달리기 16프레임)~~ ✅ **2026-08-27 오너 드롭 적용** — breath/walk 4×4 시트를 `bake_sheets.py`가 16프레임 스트립으로 굽고 `AnimatedSprite2D`가 문다. 논리 38px 유지 |
| 무사 | ~~idle(숨쉬기 16프레임) · walk(달리기 16프레임)~~ ✅ **2026-08-27 적용** — 위와 동일 |
| 잿귀 | idle 1장 · walk 16프레임 — 화면 33 논리px |

### 재생성 필요 — 피사체가 셀 밖으로 잘린다

구판 8×4 시트라 셀 폭 192px에 피사체가 붙거나 넘는다. 굽지 않고 두었고, 저장소에는
이전 스트립이 그대로 살아 있다. 작업 트리의 새 파일은 커밋하지 않았다.

| 대상 | 피사체 폭 (셀 192) | 증상 |
|---|---|---|
| 죽림 거한 · 걷기 | 177–192 | 26칸 좌 · 32칸 우 잘림 |
| 들개 · 걷기 | 181–192 | 23칸 좌우 잘림 |
| 장군 원혼 · 걷기 | 183–192 | 창이 셀 밖에서 끊긴다 |
| 장군 원혼 · 공격 | 170–192 | 28칸 좌 · 29칸 우 잘림 |
| 그슨대 · 걷기 | 174–192 | 27칸 좌우 잘림 |
| 화약 도깨비 · 폭발 | 148–192 | 23칸 좌 · 25칸 우 잘림 |

`asset/monsters/rusted_armor/idle.png`도 지워진 채 대체본이 배치되지 않았다 —
같은 폴더의 생성기 원본 파일명을 `idle.png`로 바꾸고 배경을 투명으로 빼면 된다.

### 엔진에 자리가 없는 시트

프레임은 멀쩡한데 넣을 곳이 없다. `SpriteSheet`는 `idle`/`walk` 두 슬롯만 만든다.

- 두두리 · 공격 (16프레임) — 보스 attack 애니메이션 슬롯 필요
- 장군 원혼 · 공격 — 같음
- 화약 도깨비 · 폭발 — suicide 연출용 슬롯 필요

### 공통으로 남은 문제

받은 16프레임 시트 넷 다 **위 여백이 0~1px**이라 머리·갓·상투가 셀 위 경계에 닿는다.
자를 때 잘리지는 않지만 여유가 없다. 다음 생성 때 프롬프트에 한 줄 더 넣는다:
`The character must occupy no more than 80% of the cell height.`

## Missing

```
[MISSING] 야광귀 sprite set (N10-1a)
Size:      32px logical frame, figure ~29px drawn — trash tier, between the
           goblin (30) and the player (38). Canvas = logical x 16, drawn on a
           grid ~3x finer than the logical one (smallest uniform run 5 canvas
           px, matching asset/monsters/forest_goblin).
Members:   res://asset/monsters/yagwanggwi/idle.png (+ walk.png, 4 frames min)
Used by:   data/monsters.json "yagwanggwi", ruined_village waves at 2:30 / 5:00
Reference: 세시풍속의 신발 도둑. 하늘에서 내려온 여윈 그림자에 남의 신발만
           크게 — 훔친 물건을 머리에 이고 달아나는 실루엣이어야 한다. 때려
           죽이는 적이 아니라 쫓아가는 적이므로 위협적일 필요가 없고, 오히려
           도망치는 자세가 읽혀야 한다.
Fallback:  PlaceholderArt rect (a missing texture never blocks a feature)
```

```
[PLACEHOLDER] 무쇠 · 생달걀 · 버드나무 가지 loot icons (N10-3b)
Size:      512x512 (32px logical x16), like every other loot icon
Members:   res://asset/ui/loot_icons/{cast_iron,raw_egg,willow_branch}.png
Used by:   data/loot.json, the 삼두구미 part gates
Why:       Drawn on the grid by asset/ui/build_material_icons.py because the
           image-generation credits ran out mid-feature. They read at a glance
           and they ship, but they carry five to seven colours against the
           neighbouring 귀철·주사 icons' shaded crystals — replace them when
           credits return, then delete the build script.
```

```
[MISSING] 삼두구미 sprite set (N10-3a)
Size:      64px logical frame, figure ~58px drawn — an elite, between the
           rusted armour (50) and the boss (86). Canvas = logical x 16, drawn
           on a grid ~3x finer than the logical one, like the night-2 set.
Members:   res://asset/monsters/samdugumi/idle.png (+ walk.png, 4 frames min)
Used by:   data/monsters.json "samdugumi", ruined_village wave at 5:00
Reference: 제주 전승의 무덤을 파먹는 괴물. 머리 셋, 꼬리 아홉, 그리고 제 다리를
           떼어내 부린다. 세 부위(머리·꼬리·다리)가 각각 부서지는 것이 이 싸움의
           규칙이므로 셋이 실루엣에서 따로 읽혀야 한다 — 부위별 파괴 상태 그림이
           있으면 더 좋지만, 없으면 본체 한 장으로 시작한다.
Fallback:  PlaceholderArt rect (a missing texture never blocks a feature)
```

```
[MISSING] 체 (hung sieve) prop (N10-1b)
Size:      18x22 px, drawn 1x like every other prop texture
Members:   res://asset/stages/bamboo_forest/props/hung_sieve.png
Used by:   data/props.json "hung_sieve" (wayside / camp themes), the 야광귀
           counterplay — a thief stops inside its 150px radius
Reference: 마루에 걸어두는 체. 둥근 나무 테에 성긴 망, 끈으로 매달린 모습.
           구멍이 보여야 한다 — 야광귀가 세는 것이 그 구멍이다.
Fallback:  round palette shape (placeholder "shrine")
```

```
[MISSING] xp orb sprite (AC-4)
Size:      orb ~10x10 px
Members:   res://asset/drop/xp_orb.png (idle, optional 2-frame shimmer)
Used by:   N3-5 XP drop (scripts/combat/xp_orb.gd)
Fallback:  cyan-green draw_circle orb
```

Satisfied by the AC-3 icon set + N3-13 wiring (asset/ui, scripts/ui/ui_icons.gd):
all 28 weapon icons, all 11 loot icons (mod-card display; the in-field drop
stays the intentional tier-tinted diamond per DESIGN.md §5.1), and the HUD
skull/coin/pause/info glyphs. The former [MISSING] entries for loot icons,
thunder_stone, mod weapon icons, weapon card icons and combat HUD icons are
cleared; what remains of those wants is below.

```
[MISSING] taoist archetype non-projectile FIELD art (N4-4a): seokjang,
          honbul, ghost_staff, flame_honbul (projectile travel + elemental hit
          sprites shipped N9-3f; icons shipped in AC-3)
Size:      staff swing arc sheet, soul-flame orb ~10x10 (2-frame flicker)
Used by:   N4-4a weapon mechanics (scripts/combat/auto_weapon.gd,
           projectile.gd)
Fallback:  palette-token WOOD/WEAPON_GHOST arc strokes and WEAPON_SOUL orbs
```

```
[DELIVERED N9-89] passive stat icons — all 18 of data/passives.json, one
           Joseon folk object each (tiger claw, folding fan, jipsin, gourd,
           ginseng, rattan shield, bokjumeoni, lodestone, bound books,
           talisman fan, arrow, yut sticks, tiger fang, cinnabar brush, bagua
           mirror, flint striker, chain links, seal stamp), generated as one
           batch so the set reads as one hand and installed by
           asset/build_from_generated.py. The old free-pack eleven (western
           boots, clover, gear-heart) are replaced.
```

```
[MISSING] title corner settings gear glyph
Size:      48x48 px touch glyph
Members:   res://asset/ui/title/settings_gear.png
Used by:   title corner utilities (scripts/ui/title.gd _build_utilities);
           DESIGN.md §4 and asset/title/preview.png show a gear icon
Fallback:  wood-styled text button "설정"/"Settings"
```

```
[DELIVERED N9-12] camp_backdrop — asset/camp/backdrop.png (1080x1920,
           composited in asset/camp/build_backdrop.py from the N1-2-REVISED
           production title layers under a NIGHT scrim gradient), wired in
           scripts/ui/camp_screen.gd over the kept NIGHT fallback fill.
           Bespoke per-building sign art stays a future nice-to-have.
```

```
[MISSING] meta_tree_backdrop (N7-1)
Size:      540 wide, ~750+ tall scrollable strip (2x export)
Members:   신목 (sacred tree) illustration behind the 명부수 node graph —
           trunk, branches, canopy glow like 설화 capture `_02`; optional
           root/soil footer under the deepest row
Used by:   scenes/meta_tree.tscn (scripts/ui/meta_tree_screen.gd Canvas)
Fallback:  code-drawn WOOD_BORDER trunk line + prerequisite edge lines
           (palette tokens only)
```

```
[MISSING] meta_node_icons (N7-1, roster expanded N7-2)
Size:      16px logical (32px 2x NEAREST), one per data/meta_tree.json node
Members:   trunk: iron_bones / wind_steps / sharp_talisman / soul_pull /
           quick_hands / coin_eye / head_start / insight / fourth_card /
           first_find / stone_skin / long_breath / revive; taoist branch:
           burn_mastery / ward_wide / chain_reach / orbit_extra /
           seal_ease; warrior: hwando_hone / iron_stance; archer:
           wind_read / rapid_nock; plus a small lock badge overlay
Used by:   meta tree node circles + detail card icon well
Fallback:  loot icons borrowed per node via the "icon" data field
           (tough_fiber, beast_fang, talisman_paper, wonhon_shard,
           whetstone, bamboo, cinnabar, thunder_stone); lock reads as the
           word 잠김 + dimmed icon
```

```
[NICE-TO-HAVE] bestiary_undiscovered_stamp (N5-4)
Size:      16px logical (32px 2x NEAREST)
Used by:   괴이록 undiscovered row icon well (scripts/ui/bestiary_screen.gd)
Fallback:  IN USE — the entry's real art self-modulated to INK reads as a
           silhouette; entries with no art show a "?" glyph. No new asset is
           required for the feature; a dedicated ink-stamp mark would only
           polish the ??? rows.
```

```
[DELIVERED N9-5d] reward_chest — asset/pickups/chest.png (22x18, authored
           in asset/weapon/build_fx.py: 반닫이 silhouette, brass fittings
           + lock plate), wired in scripts/combat/chest.gd over the kept
           gold pulse. A dedicated open-animation frame set remains a
           nice-to-have for a future art pass.
```

```
[DELIVERED N9-89] pickup_magnet — asset/pickups/magnet.png (14x14,
           lodestone with iron filings and a red thread, generated and cut in
           asset/build_from_generated.py), wired in scripts/combat/pickup.gd
           KIND_TEXTURES. The code-drawn blue horseshoe stays as the
           missing-file fallback.
```

```
[NICE-TO-HAVE] prop_break_frames (N5-5)
Size:      per breakable prop (bamboo_clump_small / rock_small /
           fallen_log), 2-3 shatter frames or a damaged variant
Used by:   Breakable props (scripts/combat/breakable.gd)
Fallback:  IN USE — hit flash + pooled death-puff ring on shatter.
```

## 투사체 · 이펙트 스프라이트 시트 — 오너 작업 대기 (2026-08-20)

> **배경 날린 원본은 `new_asset/needs_sprite/`에 모여 있다.** 10장 전부 투명
> PNG이고, 같은 폴더의 `README.md`가 파일마다 목표 경로 · 셀 크기 · 권장 프레임
> 수를 적어둔다. `python asset/build_sprite_requests.py`로 다시 만든다.


N9-78에서 무기 아이콘 9종, 투사체 10종, 신장/석장 원호는 생성 이미지를 잘라
실제 경로에 넣었다. 아래 항목은 **가로 스트립(애니메이션)** 이라 한 장짜리
그림으로 대체할 수 없다. 참고용 원본은 `new_asset/generated/`에 있고, 프레임만
만들어 주면 같은 경로에 그대로 들어간다.

시트 규약: **정사각 프레임의 가로 스트립**. 프레임 수는 `너비 ÷ 높이`로
읽으므로 파일 모양이 곧 선언이다 — 고정된 프레임 수를 따로 적을 필요가 없다.

```
[NEEDS FRAMES] swing_arc — asset/effect/swing_arc.png
Size:      20px 정사각 프레임, 현재 2프레임 (40x20)
Used by:   근접 휘두름 궤적 (N9-70)
Reference: new_asset/generated/fx_swing_arc.png (양끝이 뾰족한 베기 자국)
Note:      초승달이 아니라 베기 자국이다 — 양끝이 바늘처럼 가늘어야 한다
```

### 투사체가 날면서 움직이려면 (N9-80)

투사체 그림도 스트립을 받는다. 다만 캐릭터 시트와 계약이 다르다 — 투사체는
정사각이 아니라(20x7, 18x10) 파일 모양만으로는 40x20이 한 장인지 2프레임인지
구분할 수 없다. 그래서 **프레임 수를 `data/weapons.json`에 적는다**:

```json
"travel_sprite": "res://asset/weapon/travel/old_talisman.png",
"travel_frames": 4
```

파일은 셀을 가로로 이어 붙인 것이고, 셀 크기는 지금 파일 크기 그대로다.
4프레임이면 `18x10` → `72x10`. 키를 빼면 1프레임(지금 상태)이다.
`travel_frames`가 폭을 나누지 못하면 `validate_data`가 실패한다.

지금 전부 1프레임이라 정지 그림이다. 움직이면 좋을 후보, 값어치 순:

| 투사체 | 셀 크기 | 왜 |
|---|---|---|
| `hwabu` / `hwaryeongbu` | 18x18 / 16x18 | 불꽃이 흔들려야 불로 읽힌다 |
| `sal` / `gwisal` | 18x18 / 16x18 | 저주 연기가 일렁여야 한다 |
| `old_talisman` / `fire_talisman` | 18x10 | 종이가 팔랑이는 것이 이 무기의 정체다 |
| `beopgeom` / `bongmageom` | 20x7 | 검기가 번쩍이면 좋지만 셋 중 제일 급하지 않다 |

4프레임이면 충분하다. 12fps로 도는데 비행이 1초 미만이라 그보다 많으면
플레이어가 못 본다.

공용 타격 이펙트 `hit_lightning` / `hit_paper` / `blink_puff`는 2026-08-24
일관성 패스에서 제한 팔레트 픽셀 아트로 교체했다. 미참조 무료팩 이펙트
`hit_neutral` / `hit_fire` / `hit_curse`는 레지스트리와 함께 삭제했다.

### 폐촌 프롭 세트 — 재작업 대기 (2026-08-25)

```
[MISSING] ruined_village props — asset/stages/ruined_village/props/
Size:      밤1 프롭(asset/stages/bamboo_forest/props/) 규격에 대응
Members:   불탄 서까래 · 무너진 기와 · 무너진 흙담 · 그을린 그루터기 ·
           재 무더기 · 깨진 옹기 · 그을린 장승 · 잉걸불
Used by:   data/props.json props + field.themes (ruin/ashfield/ruined_wayside)
Fallback:  IN USE — 폐촌은 대나무숲 프롭을 그대로 쓴다. 바닥 타일과 변형
           3종은 폐촌 전용이 이미 들어가 있다.
Note:      생성본 3차까지 오너 반려 — 픽셀 품질이 다른 애셋과 안 맞는다.
           프롭·데이터·테마를 되돌렸다(2026-08-25). 다시 만들 때는 표시
           크기 그리드에 그린 뒤 정수배 확대하는 이 프로젝트 방식을 따를 것
           (오너 도사: 40x40 그리드 x16 = 640 캔버스).
```

## Anticipated (not yet needed — do not pre-produce)

These become `[MISSING]` entries only when the feature that needs them is actually
being built:

- Abandoned Temple stage ground and backdrop (ROADMAP M3-1)
- Second boss set (M3-3)
- Stage 2/3 monster sprite sets (gwimyeon_dokkaebi .. gumiho): their
  data/monsters.json entries carry no `sprite` key yet and render the
  placeholder rect until each stage is actually built
- Camp interiors for Workshop / Training Ground / Shrine (M2-3..M2-5)
- Icons for weapons added past the current 7 (M3-4..N)
