# 재훑기(시각) — 4a96ffe

`CastleBelll/qa-visual2` 를 `origin/main` (4a96ffe) 로 fast-forward 한 실화면.
캔버스 3종(540x960 / 486x864 / 960x540) × 로케일 2종(ko/en).
하네스: `tools/qa_resweep.gd` — 앞 라운드가 안 본 축만 판다.
캡처 `captures/qa-resweep/`, 로그 `captures/qa-resweep-{540,486,960}.log`.
**코드 수정·푸시 없음.**

앞 라운드(40건)에서 이미 센 항목은 다시 세지 않았다. 판 각도:
상태 전환 직후 1~2프레임 · 로케일 즉시 반영 · 일관성 축(타입 위계/반경/패딩/색 온도) ·
극단 프로필 · 렌더 픽셀 기준 WCAG 대비.

---

## 요약

| # | 화면 | 증상 | 심각도 |
|---|---|---|---|
| R1 | 본거지 · 전투 일시정지 | 언어를 바꿔도 화면이 안 따라온다 | **HIGH** |
| R2 | 괴이록 | 탭 전환이 앞 탭 스크롤 위치를 물고 온다 | MEDIUM |
| R3 | 업적 | 미달성 행 세 줄 전부 AA 미달 (2.0~2.3:1) | **HIGH** |
| R4 | 수행자 선택 | 선택 표시·잠긴 이름이 안 읽힌다 (1.5:1) | MEDIUM |
| R5 | 업적 | L2/F35가 걷어낸 두 색이 여기만 살아 있다 | MEDIUM |
| R6 | 전 모달 | 스크림이 없다 — 뒤 화면이 100% 밝기 | MEDIUM |
| R7 | 전 모달 | 등장 연출이 화면마다 다르다 | MEDIUM |
| R8 | 설정(가로) | "조이스틱 불투명도"가 잘린다 | MEDIUM |
| R9 | 전 화면 | 화면 제목 층위가 40 / 28 두 값 | MEDIUM |
| R10 | 전 화면 | 코너 반경·패딩에 토큰이 없다 (5종 / 4종) | LOW |
| R11 | 전 화면 | 종이 계열에 분홍 온도가 섞여 있다 | LOW |
| R12 | 본거지 · 결과 | 행 이름이 AA 문턱 바로 아래 (4.39 / 4.47) | LOW |
| R13 | 본거지 vs 수련 | 엽전 표시가 화면마다 다른 옷 | LOW |

---

## R1 — 본거지에서 언어를 바꿔도 화면이 안 따라온다 · **HIGH**

설정 팝업 안에서 한국어↔English 를 누르면 팝업 자신은 즉시 바뀌지만, **뒤의 본거지는
그대로 한국어다.** 3캔버스 전부 동일.

```
QA-X1camp  [540x960] locale=en korean_before=16 korean_after=16 changed=0 strings=21
           stale=DepartButton=출정 ; SelectButton=수행자 선택 ;
                 RunLengthButton=길이 ‹보통 밤› ; DifficultyButton=난이도 ‹순행›
QA-X1title [540x960] locale=en korean_before=3  korean_after=0  changed=3  strings=3
```

21개 문자열 중 **0개가 바뀐다.** 대조군인 타이틀은 3/3 전부 바뀐다.

원인: `title.gd:57` 만 `SettingsPopup.locale_changed` 를 잇는다.
`camp_screen.gd:75-76` 과 `combat_hud.gd:1513` 은 같은 팝업을 만들면서 신호를 안 잇는다.
`set_setting("locale")` → `apply_settings()` → `UiLocale.current_locale` 는 이미 en 이므로,
화면이 재빌드될 때까지 전역 로케일과 화면이 어긋난 채로 남는다.
본거지는 `_on_resized()` 가 **방향 전환이나 폭 계단에서만** 재빌드하므로(`camp_screen.gd:317-330`)
그냥 두면 계속 어긋난다.

캡처: `ko_x1_camp_after_flip_540x960.png` — 로케일은 en, 화면은 전부 한국어.

## R2 — 괴이록 탭 전환이 스크롤 위치를 물고 온다 · MEDIUM

몬스터 탭을 아래까지 내린 뒤 전리품/무기로 넘어가면, **새 탭이 중간부터 열린다.**

```
QA-X3init [540x960 ko] screen=bestiary tabs=3 scroll_before=444
QA-X3 [540x960 ko] screen=bestiary tab=전리품 0/14 frame=1  scroll=444
QA-X3 [540x960 ko] screen=bestiary tab=전리품 0/14 frame=99 scroll=444
QA-X3 [540x960 ko] screen=meta     tab=우치      frame=1  scroll=0
```

수련(`meta_tree_screen.gd:265`)은 탭마다 `_scroll.scroll_vertical = 0` 을 넣는다.
괴이록(`bestiary_screen.gd:192 _on_tab_pressed`)은 `_refresh()` 만 부른다 — 한 개의
`ScrollContainer` 를 세 탭이 공유하므로 오프셋이 그대로 남는다. 두 탭 화면이 서로 다르게 행동한다.

캡처: `ko_x3_bestiary_tab1_540x960.png` — 전리품 탭인데 스크롤바가 바닥.

## R3 — 업적 미달성 행 세 줄 전부 AA 미달 · **HIGH**

화면에 실제로 그려진 픽셀 기준(라벨 상자 안에서 잉크 색을 뺀 나머지의 최빈값):

| 요소 | 잉크 | 판 | 대비 | 필요 |
|---|---|---|---|---|
| 업적 이름 | `#6b6258` | `#b09d80` | **2.27:1** | 4.5 |
| 설명 | `#6b6258` | `#af9a7d` | **2.20:1** | 4.5 |
| 보상 `150냥` | `#ffd94a` | `#ae9a7c` | **1.98:1** | 4.5 |

판 면은 페이지 전체에서 균일한 `#af9a7a` 다(y=150…820 샘플 전부 `(174,153,122)±2`) —
그라데이션 문제가 아니라 토큰 조합 자체가 어둡다. 크림 `PAPER #ede0c4` 위라면 통과할
`TEXT_MUTED_ON_PAPER` 를 탠 판 위에 얹었고, 금색 보상은 밝은 판 위 밝은 글씨라 최악이다.

캡처: `ko_x5_achievements_540x960.png` — `50냥` 이 거의 안 보인다.

## R4 — 수행자 선택: 선택 표시·잠긴 이름이 안 읽힌다 · MEDIUM

```
Word:선택됨   ink=58d858 bg=fde69e 1.49<4.5 @16px
Dot:●         ink=58d858 bg=fde9a1 1.52<4.5 @16px
TileName:우치 ink=4a7fd6 bg=fcdf97 3.05<4.5 @16px
TitleLabel:요괴를 봉인하는 술사 ink=4a7fd6 bg=fce49d 3.16<4.5 @16px
```

`● 선택됨` 은 크림 종이 위 형광 녹색 — **1.5:1**, 사실상 안 보인다.
지금 이 화면이 "선택됨"을 말하는 유일한 표시다.

잠긴 타일 이름은 `accent.darkened()` 결과(`character_select.gd:473`)라 근흑 카드 위
어두운 녹색 `#384e26` / 어두운 적색 `#5a261f` 로 앉는다 — 측정기가 판과 잉크를 분리하지
못할 만큼 두 값이 붙어 있다. 육안으로도 `무사 · 잠김` / `궁수 · 잠김` 이 거의 안 읽힌다.
F29 가 붙인 "· 잠김" 글자 자체가 안 읽히면 그 수정이 무효가 된다.

캡처: `ko_x5_select_540x960.png`

## R5 — L2/F35가 걷어낸 두 색이 업적 화면에만 살아 있다 · MEDIUM

- `achievements_screen.gd:231` 달성 알약 = `UiPalette.SUCCESS` `#58d858`.
  F35 는 이 색을 두고 *"SUCCESS green was the one neon in the whole palette"* 라며
  괴이록 NEW 배지에서 주홍으로 바꿨다(`bestiary_screen.gd:330-332`). 업적에는 9개가 그대로 있다.
- `:259` 테두리도 SUCCESS.
- 미달성 알약 = `UiPalette.CARD_BG` `#211c26` — L2 가 종이 위 카운터 알약에서
  목재톤으로 바꾼 바로 그 어두운 칩이다. 같은 화면 우상단 `0/9` 카운터는 이미 목재톤이라,
  한 화면 안에서 알약이 두 벌의 규칙을 쓴다.

캡처: `ko_x7_ach_all_achievements_540x960.png` (형광 녹색 9개) ↔
`ko_x7_ach_none_achievements_540x960.png` (검은 칩 9개)

## R6 — 모달에 스크림이 없다 · MEDIUM

설정 팝업이 열린 프레임과 안 열린 프레임의 **뒤 화면 픽셀이 바이트 단위로 같다.**

```
plain camp : [(0,10,26), (0,11,27), (23,25,28)]
popup open : [(0,10,26), (0,11,27), (23,25,28)]
```

`settings_popup.gd` · `level_up_popup.gd` · `result_screen.gd` 어디에도 스크림/ColorRect 가
없다(`combat_hud.gd:619 _belongings_scrim` 은 다른 용도). 세로에서는 종이 시트가
화면을 거의 덮어 티가 덜 나지만, 가로에서는 본거지 판들이 시트 옆에 100% 밝기로 남아
모달과 밝기를 다툰다.

캡처: `en_x2_settings_settled_486x864.png`, `ko_x4_camp_popup_landscape_540x960.png`

## R7 — 등장 연출이 화면마다 다르다 · MEDIUM

레벨업만 두루마리가 펴진다. 나머지는 딱 붙는다.

```
QA-X2 [486x864 ko] levelup_open frame=1  min_modulate_a=0.00 panel=S:(438.0, 147.8)
QA-X2 [486x864 ko] levelup_open frame=2  min_modulate_a=0.00 panel=S:(438.0, 224.5)
QA-X2 [486x864 ko] levelup_open frame=99 min_modulate_a=1.00 panel=S:(438.0, 660.6)

QA-X2 [540x960 ko] open        frame=1  min_modulate_a=1.00 panel=S:(444.0, 566.0)
QA-X2 [540x960 ko] open        frame=99 min_modulate_a=1.00 panel=S:(444.0, 566.0)
QA-X2 [540x960 ko] result_open frame=1  min_modulate_a=1.00 panel=S:(444.0, 486.0)
```

설정·결과는 1프레임째에 이미 최종 크기·최종 불투명도다. 재배치 깜빡임은 **없다**(그건
정상), 다만 연출이 아예 없다. 게임에서 가장 자주 뜨는 세 모달 중 하나만 연출을 갖는다.

## R8 — 가로 배치에서 "조이스틱 불투명도"가 잘린다 · MEDIUM

가로 2열 그리드에서 슬라이더 행 이름이 `조이스틱 불…` 로 줄어든다.
`settings_popup.gd:442` 가 슬라이더 행에 `OVERRUN_TRIM_ELLIPSIS` 를 건다 —
세로 좁은 판을 위한 양보인데(코드 주석의 의도), 가로에서는 같은 행 오른쪽에 `언어` 라벨과
버튼이 들어갈 자리가 남아 있는데도 발동한다. 세로 배치(`:417`)는 `NO_TRIMMING` 이라
같은 라벨이 온전히 나온다.

캡처: `ko_x4_camp_popup_landscape_540x960.png`

## R9 — 화면 제목 층위가 두 값 · MEDIUM

```
QA-X5font [*] 7 distinct |
  16px x73 ; 20px x45 ; 26px x1 (title/MenuButton_start) ; 28px x7 (camp/CampTitle meta/Title)
  32px x1 (select/NameLabel) ; 40px x1 (select/ScreenTitle) ; 56px x2 (title/Logo)
```

`FONT_SIZE_TITLE=28` 을 본거지·수련·괴이록·업적이 쓴다. **수행자 선택만 40px** 다 —
같은 층위, 다른 크기. 토큰 밖 값이 26 / 32 / 40 세 개(로고 56은 별개로 봐도 된다).
3캔버스 전부 동일.

## R10 — 코너 반경·패딩에 토큰이 없다 · LOW

```
QA-X5radius [*] 5 distinct | r03 (톱니·뒤로) ; r08 (초상 슬롯) ; r10 (업적 알약)
                             r12 (수련 아이콘 우물) ; r18 (수련 탭)
QA-X5pad    [*] 4 distinct | p04/04 ; p10/02 ; p14/06 ; (텍스처 박스)
```

`palette.gd` 에는 `FONT_SIZE_*` 만 있고 반경/패딩 토큰이 없다. 알약 한 층위 안에서만
r10(업적) / r18(수련 탭)로 갈린다.

## R11 — 종이 계열에 분홍 온도가 섞여 있다 · LOW

`PAPER #ede0c4` (색상각 ~40°, 따뜻함) 옆에 `PAPER_CARD #f6ecf0` 와
`PAPER_CARD_BORDER #c9a0a6` (~320-350°, 분홍)이 있다. 둘 다 팔레트 토큰이라
"이탈색" 스캔에는 안 걸리지만, 화면에서는 크림 시트 위의 분홍-흰 카드로 읽힌다.
설정의 비선택 탭 `오디오`, 레벨업 카드 3장이 그렇다.

캡처: `ko_x4_camp_popup_landscape_540x960.png`, `ko_x2_levelup_settled_540x960.png`

## R12 — 행 이름이 AA 문턱 바로 아래 · LOW

```
QA-X5contrast [540x960 ko] screen=camp checked=16 fails=2 |
  보스 처치 ink=6b6258 bg=f1dab5 4.39<4.5 @20px ; 최고 처치 ink=6b6258 bg=f2dcb7 4.47<4.5 @20px
```

`TEXT_MUTED_ON_PAPER` + 크림 판 = **4.39~4.47:1**, AA 4.5 에 아슬하게 못 미친다.
결과 시트의 `Survived / Kills / Coins` 행 이름도 같은 조합이다. 잉크를 한두 단계만
어둡게 하면 전부 넘긴다.

캡처: `ko_x5_camp_540x960.png`, `en_x2_result_settled_486x864.png`

## R13 — 엽전 표시가 화면마다 다른 옷 · LOW

본거지는 코인 아이콘 + 금색 숫자를 판 없이 놓고, 수련은 금테 두른 어두운 알약에 담는다.
같은 값, 같은 위치(우상단), 다른 옷.

캡처: `ko_x1_camp_after_flip_540x960.png` ↔ `ko_x5_meta_540x960.png`

---

## 이상 없음

판 각도인데 깨끗했던 것들. 다음 라운드가 다시 파지 않도록 근거를 남긴다.

- **회전 직후 프레임.** 세로↔가로 양방향, 팝업을 연 채로 한 번 더 — 1프레임·2프레임·
  안정 후 전부 `clipped=0`, 캔버스 크기도 1프레임째에 이미 정확하다. 잔상·튐·재배치
  깜빡임 없음. `QA-X4`, 540x960 과 960x540 양쪽.
  ```
  QA-X4 [540x960] phase=to_landscape             frame=1 canvas=(960,540) visible=54 clipped=0
  QA-X4 [540x960] phase=popup_open_to_landscape  frame=1 canvas=(960,540) visible=80 clipped=0
  ```
- **극단 프로필.** 첫 부팅 / 엽전 0 / 엽전 99999 / 업적 0건 / 업적 전건 × 본거지·수련·업적
  × ko·en × 3캔버스 = 90 케이스. 잘린 글자 0, 가로 넘침 0, 빈 행 0. `QA-X7`.
- **레벨업 팝업 등장.** 일시정지된 트리 위(실제 경로)에서 두루마리가 제대로 펴진다 —
  alpha 0→1, 판 높이 148→225→661px. 매 프레임 `panel_in=true offscreen_nodes=0`.
- **설정 팝업 열기/닫기.** 1프레임과 안정 후의 판 사각형이 완전히 같다 — 레이아웃 전
  프레임이 새어 나오는 깜빡임 없음.
- **판 안쪽 여백.** 본거지 16px · 수행자 선택 16 · 수련 14 · 업적 10 — 전부 F33 의 8px
  바닥을 넘는다. (괴이록의 `Well/Glyph:?` 0px 두 건은 우물을 꽉 채우는 가운데 정렬
  플레이스홀더 글리프라 텍스트 인셋이 아니다.)
- **수련 탭 전환.** 네 탭 전부 `scroll=0` 으로 리셋, ko·en 동일.
- **타이틀 로케일 전환.** 3/3 반영, 한국어 잔류 0.
- **톱니 크기.** 타이틀·본거지 둘 다 `UTILITY_BUTTON_SIZE := 44` (4a96ffe 가 앞 라운드의
  48px 주석을 닫았다).
- **`#1a1a1a` 는 이탈색이 아니다.** 톱니·뒤로 버튼의 `normal` 스타일박스에 남은 Godot
  기본값인데, 셋 다 `flat = true` 라 그려지지 않는다. 스캔의 오검출.

---

## 하네스

`tools/qa_resweep.gd` — 게임 코드는 건드리지 않는다. 던지는 프로필로만 돌고
(`SaveService._write_locked = true`), 살아 있는 노드를 재고 스크린샷 픽셀을 읽는다.

| 검사 | 무엇을 |
|---|---|
| X1 | 설정 팝업에서 언어를 실제로 눌러 보고, 뒤 화면의 모든 문자열을 전후 대조 |
| X2 | 팝업 열기/닫기 직후 1·2프레임의 불투명도·판 사각형·화면 밖 노드 |
| X3 | 탭을 누른 직후 1·2프레임의 스크롤 오프셋·가로 넘침·0크기 노드 |
| X4 | 창 크기를 뒤집고 1·2프레임의 캔버스·잘린 노드 (팝업 연 채로도) |
| X5 | 전 화면 타입 크기·코너 반경·패딩·팔레트 밖 색 히스토그램 + 렌더 픽셀 대비 + 판 인셋 |
| X7 | 다섯 가지 극단 프로필 × 세 화면의 잘림·넘침·빈 라벨 |

대비 측정은 라벨 상자 **안에서** 잉크 색과 가까운 픽셀을 버린 뒤 나머지의 최빈값을
바탕으로 잡는다. 상자 바깥 링을 재면 판이 아니라 판을 둘러싼 배경을 읽고, 링 없이
최빈값만 재면 글자가 꽉 찬 라벨에서 잉크 자신을 읽는다 — 둘 다 실제로 오검출을 냈다.

자동 검증 재실행: 이번 라운드는 코드를 바꾸지 않았으므로 `tests/run_tests.gd` /
`validate_data.gd` 는 앞 라운드 결과(603/603 PASS, 18 json PASS)가 그대로 유효하다.
