# 재검증 — 68a68d6 의 28건이 실제로 닫혔는가

- 워크트리 `qa-visual2`, 브랜치 `CastleBelll/qa-visual2` → `origin/main` merge (fast-forward) → **68a68d6**.
- `git add --renormalize .` 결과 변경 없음(CRLF 이미 정규화 상태). `godot --headless --path . --import` 통과.
- **게임 코드 수정 없음 · 푸시 없음.** 하네스 `tools/qa_verify.gd` / `.tscn` 은 이 리포트 직후 삭제.
- 캔버스 3종 `540x960 / 486x864 / 960x540` × 로케일 `ko/en`.
- 자동 검증 재실행: `tests/run_tests.gd` **PASS 603/603**, `tools/validate_data.gd` **PASS 18 json**.
- 콘솔: 여섯 번의 하네스 실행 전 구간 `ERROR` / `SCRIPT ERROR` / `push_error` **0건**.

## 집계

| | 건수 |
|---|---|
| PASS | **26 / 28** |
| FAIL | **2 / 28** — 시각 R4(선택됨 배지 대비), 플레이 R3(486x864 에서만) |
| 새로 잡힌 것 | 1건 (N1: 세로 540x960 설정 슬라이더 라벨 말줄임) |
| 부수 관찰 | 3건 (수정 대상 밖) |

---

## 시각 13건

### 판정표

| # | 항목 | 판정 | 실측 |
|---|---|---|---|
| R1 | 로케일 즉시 반영(본거지·전투 일시정지) | **PASS** | 본거지 잔류 한국어 16→**0**, `stale=none`; 일시정지 오버레이 20→**0** |
| R2 | 괴이록 탭 전환 scroll=0 | **PASS** | `scroll_before=444` → 탭 누른 뒤 1·2·99프레임 전부 `scroll=0` |
| R3 | 업적 미획득 행 대비 ≥4.5 | **PASS** | 이름 **6.61**, 설명 **6.61**, 보상 **4.56** |
| R12 | 크림 판 위 muted 잉크 ≥4.5 | **PASS** | `TEXT_MUTED_ON_PAPER #5e564c` = **5.30~5.52**, 본거지 `fails=0` |
| R4 | 선택됨 배지·잠김 이름 대비 | **FAIL(부분)** | 잠김 이름 **7.66** PASS / `● 선택됨` **4.21~4.39** < 4.5 |
| R5 | 업적 알약 색 문법 | **PASS** | 상태 알약 = `VERMILION`/`WOOD_PRESSED` + `CHIP_*` 토큰. `SUCCESS`·`CARD_BG` 제거 |
| R6 | 모달 3종 스크림 | **PASS** | `MODAL_SCRIM a=0.45`, 뒤 화면 실측 어두워짐 |
| R7 | 설정·결과지 등장 페이드 | **PASS** | 1프레임 alpha 설정 **0.13~0.14**, 결과 **0.13~0.14**, 레벨업 **0.00** |
| R8 | 가로 설정 슬라이더 라벨 말줄임 0 | **PASS** | 960x540 `trimmed=0`, 486x864 `trimmed=0` |
| R9 | 화면 제목 28px | **PASS** | `28px x7 (camp/CampTitle select/ScreenTitle meta/Title)`, 40px 소멸 |
| R10 | 알약 반경 층위 | **PASS** | `PILL_RADIUS=18` / `CHIP_RADIUS=10` 토큰화, 본거지 엽전=수련 탭 r18 |
| R11 | 카드 분홍 온도 제거 | **PASS** | `PAPER_CARD #fbf6ea` 색상각 **42°**, `PAPER_CARD_BORDER #c9b28e` **37°** |
| R13 | 본거지 엽전 알약 | **PASS** | `camp/GoldPill` = `meta/GoldPill` (r18, p14/06) |

### R1 — PASS
원 재현 경로 그대로: 설정 팝업 안에서 언어 버튼을 실제로 눌렀다.

```
QA-X1camp  [540x960] locale=en korean_before=16 korean_after=0 changed=0 strings=21 stale=none
QA-X1camp  [960x540] locale=en korean_before=16 korean_after=0 strings=21 stale=none
QA-X1camp  [486x864] locale=en korean_before=16 korean_after=0 strings=21 stale=none
QA-V V-R1b [540x960] PASS locale=en overlay_korean before=20 after=0 want 0
QA-V V-R1b [960x540] PASS locale=en overlay_korean before=20 after=0 want 0
QA-V V-R1b [486x864] PASS locale=en overlay_korean before=20 after=0 want 0
```

앞 리포트의 `stale=DepartButton=출정 ; SelectButton=수행자 선택 ; …` 4건이 전부 사라졌다.
전투 일시정지 경로는 실제로 전투를 띄우고 → 일시정지 → 설정 → 언어 버튼을 눌렀다.
로케일 전환이 오버레이를 **재생성**하므로 노드 경로가 바뀐다 — 살아 있는
`_pause_overlay` 를 다시 읽어 셌다.
증거: `v_pause_locale_540x960.png`.

### R2 — PASS
몬스터 탭을 바닥까지 내린 상태(`scroll_before=444`)에서 다른 탭을 눌렀다.

```
QA-X3init [540x960 ko] screen=bestiary tabs=3 scroll_before=444
QA-X3 [540x960 ko] screen=bestiary tab=전리품 0/14 frame=1  scroll=0
QA-X3 [540x960 ko] screen=bestiary tab=전리품 0/14 frame=99 scroll=0
QA-X3 [540x960 ko] screen=bestiary tab=무기   0/36 frame=1  scroll=0
```
수련과 동일하게 탭마다 0으로 리셋된다. 3캔버스 동일.

### R3 / R12 — PASS (렌더 픽셀 재실측)
하네스의 `QA-X5contrast` 는 업적 보상 행에서 판 색을 **페이지 배경**(`#16110d`)으로
집었다 — 카드가 텍스처 명패로 바뀌면서 기존 최빈값 휴리스틱이 어긋난다. 그래서
캡처 PNG 를 직접 디코드해 라벨 밴드의 픽셀 최빈값으로 다시 쟀다
(`evi_ko_x5_achievements_540x960.png`, 첫 카드 미획득 행):

| 요소 | 잉크 | 판 | 이전 | 지금 | 필요 |
|---|---|---|---|---|---|
| 업적 이름 | `#1a1613` (INK) | `#ae9a7d` | 2.27 | **6.61** | 4.5 |
| 설명 | `#1a1613` (INK) | `#ae9a7d` | 2.20 | **6.61** | 4.5 |
| 보상 `150냥` | `#4a2e14` (WOOD_TEXT) | `#ae9a7d` | 1.98 | **4.56** | 4.5 |

미획득 행은 이제 알파 딤 없이 풀 잉크다 — "잠김"은 판이 말하고 글자는 읽히게 두는 쪽.
보상 행 4.56 은 통과하되 여유가 0.06 뿐이다.

R12 쪽:
```
QA-X5contrast [540x960 ko] screen=camp checked=16 fails=0   (이전: fails=2, 4.39 / 4.47)
TEXT_MUTED_ON_PAPER #5e564c on #f1dab5 = 5.30 ; on #f2dcb7 = 5.39 ; on PAPER #ede0c4 = 5.52
```
결과지도 같은 토큰을 쓰므로 같은 값으로 통과한다(`evi_ko_x2_result_settled_960x540.png`).

### R4 — **FAIL (부분)**
`● 선택됨` 은 형광 녹색을 벗고 주홍(`#bf402a`)이 됐다. 1.49 → **4.21~4.39** 로 크게
올랐지만 **AA 4.5 를 아직 넘지 못한다.**

```
QA-X5contrast [540x960 ko] screen=select ... Word:선택됨 ink=bf402a bg=fde69e 4.27<4.5 ; Dot:● ink=bf402a bg=fde9a1 4.36<4.5
QA-X5contrast [960x540 ko] ... Word:선택됨 4.33<4.5 ; Dot:● 4.39<4.5
QA-X5contrast [486x864 ko] ... Word:선택됨 4.33<4.5 ; Dot:● 4.02<4.5
캡처 픽셀 재실측: (191,64,42) on (253,228,156) = 4.21
```

잠긴 타일 이름은 통과다. 하네스가 `1.83` 로 읽은 것은 판을 뒤쪽 크림 시트로 집은
오검출이고, 실제 어두운 카드 위에서 재면:

```
locked name (176,164,148) on card (22,17,13) = 7.66  ← PASS
```

즉 R4 두 갈래 중 **잠김 이름은 닫혔고, 선택됨 배지는 아직 열려 있다.**
잉크를 한 단계만 더 어둡게(또는 배지를 어두운 알약 위 흰 글씨로) 하면 넘긴다.
증거: `evi_ko_x5_select_540x960.png`.

### R5 — PASS (잔여 1곳 메모)
`achievements_screen.gd:235-247` 의 상태 알약이 `SUCCESS`/`CARD_BG` 를 버리고
`VERMILION` / `WOOD_PRESSED` + `CHIP_RADIUS/CHIP_PAD_*` 로 갔다 — 괴이록 NEW 배지·
카운터 알약과 같은 문법이다.
잔여: `:269` `_card_box()` 의 **폴백** 테두리에 `UiPalette.SUCCESS` 가 남아 있다.
`UiIcons.card_panel()` 이 null 일 때만 도달하는 경로라 실화면에는 그려지지 않지만,
문법 통일의 마지막 한 줄로는 남아 있다.

### R6 — PASS
세 모달 모두 `Scrim` ColorRect(`MODAL_SCRIM a=0.45`)가 전체 사각형을 덮는다.

```
QA-V V-R6b [*] PASS scrim=yes alpha=0.45 covers_canvas=true   (레벨업)
QA-V V-R6c [*] PASS scrim=yes alpha=0.45 covers_canvas=true   (결과지)
```
설정 팝업은 앞 리포트가 쓴 방식 그대로 — 팝업 없는 프레임과 있는 프레임의 뒤 화면
픽셀을 직접 비교했다(`evi_ko_x4_camp_to_landscape_540x960.png` ↔
`evi_ko_x4_camp_popup_landscape_540x960.png`):

| 좌표 | 팝업 없음 | 팝업 열림 |
|---|---|---|
| (60,300) 크림 판 | `(241,217,179)` | `(143,127,105)` |
| (500,520) 목재 | `(89,48,15)` | `(59,34,14)` |
| (20,20) 밤하늘 | `(1,13,30)` | `(10,15,22)` |

앞 리포트의 "바이트 단위로 같다" 가 사라졌다.

### R7 — PASS
```
QA-X2 [540x960 ko] open         frame=1 min_modulate_a=0.14 → frame=99 1.00
QA-X2 [540x960 ko] result_open  frame=1 min_modulate_a=0.14 → frame=99 1.00
QA-X2 [540x960 ko] levelup_open frame=1 min_modulate_a=0.00 → frame=99 1.00
QA-X2 [540x960 en] result_open  frame=1 min_modulate_a=0.13
```
세 모달 전부 1프레임째 alpha < 1. 판 사각형은 1프레임과 안정 후가 동일해 재배치
깜빡임은 여전히 없다.

### R8 — PASS (가로), 그러나 세로 540 에서 같은 증상 잔존 → **N1**
가로에서 슬라이더 행이 라벨을 위로 쌓아 말줄임이 사라졌다.

```
QA-V V-R8 [960x540] PASS settings_labels=6 trimmed=0
QA-V V-R8 [486x864] PASS settings_labels=6 trimmed=0
```
가로 캡처(`evi_ko_x4_camp_popup_landscape_540x960.png`)에 `조이스틱 불투명도` 가
온전히 나온다. **판정 항목(가로)은 PASS.** 다만 아래 N1 — 540x960 에서는 아직 잘린다.

### R9 / R10 / R11 / R13 — PASS
```
QA-X5font   [*] 28px x7 (camp/CampTitle select/ScreenTitle meta/Title)      ← 40px 소멸
QA-X5radius [*] r10 x9 (achievements/Status …) ; r18 x11 (camp/GoldPill meta/Tab_archer …)
QA-X5pad    [*] p10/02 x9 (achievements/Status) ; p14/06 x7 (camp/GoldPill meta/GoldPill …)
palette.gd  PILL_RADIUS=18 PILL_PAD_X=14 PILL_PAD_Y=6 / CHIP_RADIUS=10 CHIP_PAD_X=10 CHIP_PAD_Y=2
PAPER #ede0c4 hue=41° · PAPER_CARD #fbf6ea hue=42° · PAPER_CARD_BORDER #c9b28e hue=37°
```
- R9: 수행자 선택 제목이 40 → 28 로 내려와 본거지·수련과 한 층위가 됐다. 3캔버스 동일.
- R10: 알약(18)과 칩(10)이 각각 토큰을 얻었고, 층위 안에서 갈리던 r10/r18 혼선이 사라졌다.
  (r03 버튼 / r08 초상 슬롯 / r12 수련 아이콘 우물은 알약 층위가 아니라 그대로다.)
- R11: 분홍 320~350° 가 전부 사라지고 종이 계열 셋이 37~42° 로 모였다.
- R13: 본거지 엽전이 수련과 같은 알약(r18, p14/06)을 입었다 —
  `evi_ko_x4_camp_popup_landscape_540x960.png` 우상단.

---

## 플레이 15건

### 판정표

| # | 항목 | 판정 | 실측 |
|---|---|---|---|
| R1 | 쿨다운 스윕 픽셀 변화 > 0 | **PASS** | 7s→4s **165px**, 4s→1s **166px** (이전 0) |
| R2 | 보스 바 목재 플레이트 + EXP 레일 정렬 | **PASS** | `bar_hp` 리빌, `dleft=0 dright=0` (이전 101px 어긋남) |
| R3 | 세로 레벨업 3장 스크롤바 0 · 마지막 줄 온전 | **FAIL(부분)** | 540x960·960x540 PASS / **486x864 스크롤바 + 29.2px 넘침, 마지막 줄 17.2px 잘림** |
| R4 | 소지품 수량 칸 안 인셋 | **PASS** | 수량 칸 9개, 최악 오버행 **-2.0px** |
| R5 | 그슨대 외곽선 분리 | **PASS** | 실루엣 경계 **734/734** 픽셀이 잉크(ratio 1.00) |
| R7 | 개조 카드 우물 = 베이스 무기 아이콘 | **PASS** | 우물에 `sword.png`, 글리프 폴백 없음 |
| R8 | 가로 결과지 하단 공백 < 60px | **PASS** | **47px** (이전 ~180px) |
| R9 | 카드 desc 어절 중간 줄바꿈 0 | **PASS** | desc 3장 × 3캔버스 전부 `mid_word_breaks=0` |
| R10 | 일시정지 탭 전환 종이 동일 | **PASS** | `dw=0 dh=0` 3캔버스 |
| R12 | 소지품 줄별 플레이트 과폭 0 | **PASS** | 가로 두 줄 105/164px, slop **8px** (이전 130px) |
| R13 | 타이머 잉크 칩 | **PASS** | `TimerPlate` StyleBoxFlat `#0d0a086b` (a=0.42) |
| R14 | 카운터 잉크 칩 | **PASS** | `Counters` 같은 칩 |
| R15 | 조이스틱 베이스 디스크 | **PASS** | 베이스·노브 둘 다 `kit_texture("disc_0")` (2 call site) |
| R17 | Lv 배지 인셋 | **PASS** | 배지 하단이 우물 하단보다 **2.0px 위** |
| R18 | 데미지 외곽선 3px | **PASS** | `OUTLINE_SIZE = 3` |

### R1 — PASS (원인 수정 확인)
원 재현: 8초 쿨다운을 **매 프레임 1/60씩** 내리며(스테이지가 실제로 하는 그대로)
남은 7s / 4s / 1s 시점에 버튼 사각형의 픽셀을 떠서 비교했다.

```
QA-V P-R1 [540x960] PASS button=Active_chukji px_changed 7s->4s=165 4s->1s=166 want>0
QA-V P-R1 [960x540] PASS px_changed 7s->4s=165 4s->1s=166
QA-V P-R1 [486x864] PASS px_changed 7s->4s=165 4s->1s=166
```
앞 리포트의 "네 프레임이 사실상 동일(변화 94~114px, 전부 버튼 밖)"이 사라졌다.
근거는 코드에서도 확인된다 — `combat_hud.gd:1797` 이 마지막 **수신** 값이 아니라
마지막 **그린** 값 `_drawn_fraction` 과 비교한다.

> 계측 노트: 살아 있는 스테이지의 HUD 를 쓰면 스테이지가 매 프레임 자기 타이머로
> `set_active_cooldown` 을 덮어써 측정이 흔들린다(같은 코드가 실행마다 216 과 0 을
> 오갔다). 그래서 같은 `CombatHud` 를 독립 인스턴스로 띄워 같은 API 로만 구동했다.

### R2 — PASS
```
QA-V P-R2 [540x960] PASS boss=[8..532]   xp=[8..532]   dleft=0 dright=0
QA-V P-R2 [960x540] PASS boss=[120..840] xp=[120..840] dleft=0 dright=0
QA-V P-R2 [486x864] PASS boss=[8..478]   xp=[8..478]   dleft=0 dright=0
```
보스 바가 EXP 레일과 같은 `XpBarArt` 리빌(`bar_hp` 플레이트)로 바뀌었고, 두 바가
`_apply_bar_band()` 를 공유해 좌우 끝이 **정확히 일치**한다. 앞 리포트의 101px 어긋남 해소.

### R3 — **FAIL (486x864 에서만)**
원 재현 카드 구성 그대로: `광역 확장`(4줄 패시브) + `낡은 부적` + `불씨 정통` 3장.

```
QA-V P-R3  [540x960] PASS scrollbar=false overflow=0.0px   / P-R3b worst_overshoot=-12.0px
QA-V P-R3  [960x540] PASS scrollbar=false overflow=0.0px   / P-R3b worst_overshoot=-12.0px
QA-V P-R3  [486x864] FAIL scrollbar=true  overflow=29.2px  / P-R3b worst_overshoot=+17.2px
```
`v_levelup_area_486x864.png` 에서 세 번째 카드 `불씨 정통` 의 마지막 줄 `+2% (1/3)` 이
리스트 하단에서 세로로 절반 잘리고, 오른쪽에 스크롤바 트랙이 보인다 — 원 증상 그대로다.
**오너 규칙(스크롤 = FAIL) 위반이 좁은 세로 프로필에 남아 있다.**
원 발견이 걸린 540x960 과 가로에서는 닫혔다(`v_levelup_area_540x960.png` 는 3장이
스크롤 없이 수납되고 `광역 확장` 4줄이 온전하다).

### R4 / R12 — PASS
후반 상태(무기 3·패시브 4·재료 2, 수량 전부 2 이상)를 실제 HUD API 로 밀어 넣고 레이아웃을
안정시킨 뒤 쟀다.

```
QA-V P-R4  [*] PASS count_holders=9 worst_overhang=-2.0px want<0
QA-V P-R12 [960x540] PASS Line1Plate plate=164 content=156 slop=8 ; Line0Plate plate=105 content=97 slop=8
QA-V P-R12 [540x960] PASS Line0Plate plate=273 content=265 slop=8
```
수량 숫자 9개 전부 칸 테두리 **안쪽**에 있고(최악이 2px 여유), 가로에서는 두 줄이
각자 제 폭의 플레이트를 갖는다 — 앞 리포트의 "마지막 칸보다 130px 더 오른쪽까지" 해소.
증거: `v_belongings_960x540.png`, `v_belongings_540x960.png`.

### R5 — PASS
```
QA-V P-R5 [*] PASS edge_px=734 inked=734 ratio=1.00 want>0.90
```
`asset/monsters/geuseundae/build/idle_strip.png` 의 실루엣 경계 픽셀 **734개 전부**가
잉크 명도(<0.18)다. 잿귀에 썼던 것과 같은 측정. 앞 리포트의 "원본 아트 자체에 1px
외곽선이 없다" 가 해소됐다.

### R7 — PASS
```
QA-V P-R7 [*] PASS desc=환도 → ??? (레벨 유지) base=sword
              card_well=[tex:sword.png] glyph_fallback=false
```
결과가 가려진(`???`) 개조 카드인데도 우물에 **베이스 무기(환도) 아이콘**이 들어간다.
"개" 한 글자 폴백 없음. 결과 이름은 여전히 `???` — 그건 N4-9 의 의도된 규칙이라
이번 판정 대상이 아니다. 증거: `v_mod_card_540x960.png`.

### R8 — PASS
```
QA-V P-R8 [960x540] PASS paper_bottom-cta_bottom=47.0px want<60
                         panel=[P:(100,87) S:(760,366)] cta=[P:(147,342) S:(666,64)]
QA-V P-R8 [540x960] PASS 47.0px      QA-V P-R8 [486x864] PASS 47.0px
```
가로 결과지 하단 공백이 ~180px → **47px**. 세 캔버스에서 같은 값이라 종이 바닥이
CTA 를 따라간다. 증거: `evi_ko_x2_result_settled_960x540.png`.

### R9 — PASS
```
QA-V P-R9 [*] PASS desc_labels=3 mid_word_breaks=0
```
Label 과 **같은 break flag** 로 다시 조판해 줄 시작이 공백이 아닌 지점을 셌다 — 0건.
`광역 확장` 설명이 `폭발·결계·파동 반경,` / `혼불 크기, 휘두르는` / `리치, 투사체 크기까지`
로 어절 경계에서만 끊긴다. 앞 리포트의 `혼불 크 / 기`, `투사체 크기 / 까지` 재현 안 됨.
WORD JOINER(U+2060)가 어절 안에 들어가 있어 desc 문자열 자체에 조인터가 보인다(의도).

### R10 — PASS
```
QA-V P-R10 [540x960] PASS tabs=2 dw=0 dh=0 | Tab_build S:(412,629) · Tab_evolutions S:(412,629)
QA-V P-R10 [960x540] PASS tabs=2 dw=0 dh=0 | 둘 다 S:(846,433)
QA-V P-R10 [486x864] PASS tabs=2 dw=0 dh=0 | 둘 다 S:(366,629)
```
탭을 눌러도 종이 사각형이 **1px도 안 움직인다**. 앞 리포트의 x60→900 ↔ x220→760 해소.

### R13 / R14 / R15 / R17 / R18 — PASS
```
QA-V P-R13 [*] PASS TimerPlate node=yes bg=0d0a086b alpha=0.42
QA-V P-R14 [*] PASS Counters   node=yes bg=0d0a086b alpha=0.42
QA-V P-R15 [*] PASS kit disc_0=loaded draw_call_sites=2 want>=2
QA-V P-R17 [*] PASS lv_badges=2 badge_bottom-well_bottom=-2.0px want<0
QA-V P-R18 [*] PASS OUTLINE_SIZE=3 want>=3
```
- R13/R14: 타이머와 처치·엽전 카운터가 같은 반투명 잉크 칩(`#0d0a08` a=0.42)에 앉았다.
- R15: `virtual_joystick.gd` 의 베이스(:126)와 노브(:144)가 **둘 다** 같은 도자 디스크를 그린다.
- R17: `Lv.n` 배지 하단이 우물 프레임보다 2px 위 — 겹침 없음.
- R18: `damage_number.gd:19 const OUTLINE_SIZE := 3`.

---

## 새로 잡힌 것

### N1 — 세로 540x960 설정에서 "조이스틱 불투명도"가 아직 잘린다 · MEDIUM
R8 의 수정은 **가로 2열 그리드**만 쌓게 만들었다. 세로 배치는 두 갈래인데,
좁은 폰(`_root.size.x < 520`)만 쌓고 **540px 세로는 라벨-왼쪽/컨트롤-오른쪽 그대로**다
(`settings_popup.gd:418`). 그 행의 라벨 상자가 118px 인데 글자는 170px 를 요구한다.

```
QA-V V-R8 [540x960] FAIL settings_labels=6 trimmed=1
                    조이스틱 불투명도 170>118 overrun=TRIM_ELLIPSIS clip=false
```
캡처 `evi_ko_x2_settings_settled_540x960.png` 에 `조이스틱 …` 로 나온다 — **게임의 기본
캔버스**다. 회귀는 아니고(수정 전에도 같은 경로였다) R8 이 닫지 못하고 남긴 쪽이다.
문턱을 520 → 560 으로 올리거나, 슬라이더 행은 방향과 무관하게 쌓으면 닫힌다.

## 부수 관찰 (이번 수정 대상 밖)

- **업적 우상단 `0/9` 카운터**: 금색 글씨가 목재 알약 위 — `2.29:1`. R5 가 "이미 목재톤"
  이라고 넘긴 알약인데 대비 자체는 미달이다. (`ink=ffd94a bg=c08544`)
- **괴이록**: `ProgressValue 3/64` `2.54:1`, 미기록 항목 설명 `아직 기록되지 않았다 — …`
  `2.60:1` (`ink=5e564c bg=16110d`) — 어두운 카드 위에 종이용 muted 잉크가 얹혀 있다.
- **`achievements_screen.gd:269`** `_card_box()` 폴백 테두리에 `UiPalette.SUCCESS` 잔존.
  키트 명패가 있는 실화면에서는 도달하지 않는 경로.

---

## 하네스와 증거

| 파일 | 무엇을 |
|---|---|
| `tools/qa_resweep.gd` (기존) | 시각축 X1~X7 재실행 — 로케일 전수 대조, 팝업 1·2프레임, 탭 스크롤, 타입/반경/패딩/대비 |
| `tools/qa_verify.gd` (신규, 리포트 후 삭제) | 플레이축 15건 + 일시정지 로케일 + 모달 스크림 + 설정 말줄임 |

로그: `visual-{540,486,960}.log`, `verify-{540,486,960}.log`.
캡처: `v_*.png`(하네스 산출), `evi_*.png`(시각 재실행 산출 중 인용분).

`qa_verify` 는 던지는 프로필로만 돌고(`SaveService._write_locked = true`), 실제
`CombatHud` / `LevelUpPopup` / `ResultScreen` / `stage.tscn` 을 그들 자신의 공개 API 로
구동한 뒤 살아 있는 노드 사각형과 뷰포트 픽셀을 읽는다. 게임 코드는 건드리지 않는다.

측정에서 두 번 속았고 둘 다 남긴다 — 다음 라운드가 같은 함정을 밟지 않도록:
1. **대비 측정의 판 색.** 카드가 텍스처 명패로 바뀌자 "라벨 상자 안 최빈값" 휴리스틱이
   페이지 배경(`#16110d`)이나 뒤쪽 크림 시트(`#f2dcb6`)를 판으로 집었다. 업적 보상
   `1.51`, 잠김 이름 `1.83` 이 그 오검출이다 — 캡처 픽셀 직접 측정으로 각각 `4.56`,
   `7.66` 임을 확인했다.
2. **살아 있는 스테이지 위에서의 쿨다운 계측.** 스테이지가 매 프레임 자기 값으로
   덮어써 같은 코드가 실행마다 `216` 과 `0` 을 오갔다. 독립 HUD 인스턴스로 고정했다.
