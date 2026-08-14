# JOSEONLIKE — Design System (SSOT)

기준: 2026-08-14 오너 벤치마크 — 설화(Tailbound)의 디자인 문법을 따르되
복제하지 않는다 (`example/*.png` 참조 캡처). 모든 UI 작업은 이 문서와
`scripts/ui/palette.gd`의 토큰만 사용한다. raw Color/픽셀값 하드코딩 금지.

## 1. 타이포그래피

- 전역 폰트: **Neo둥근모** (`asset/font/neodgm.ttf`, SIL OFL 1.1,
  `asset/ui/theme.tres`로 전역 적용). 픽셀 폰트이므로 안티앨리어싱 OFF.
- 크기: TITLE 28 / BODY 20 / LABEL 16 (UiPalette 상수).
- 강조는 굵기가 아니라 **색**으로 한다 (픽셀 폰트에 볼드 없음).
- 본문은 흰 계열(TEXT_ON_DARK), 종이 위에서는 INK.

## 2. 팔레트 (palette.gd 토큰)

| 토큰 | 값 | 용도 |
|---|---|---|
| NIGHT | #16110d | 다크 화면 배경 (캐릭터 선택, 오버레이 딤) |
| PAPER | #ede0c4 | 종이 패널 (팝업/카드 바탕) |
| WOOD | #e2a057 | 버튼 바탕 (나무 패널) |
| WOOD_HOVER | #edb26c | 버튼 hover |
| WOOD_PRESSED | #c08544 | 버튼 pressed |
| WOOD_BORDER | #6e4322 | 버튼/패널 테두리 (3px) |
| WOOD_TEXT | #4a2e14 | 버튼 글자 (진갈) |
| INK | #1a1613 | 종이 위 텍스트, 외곽선 |
| GOLD | #c49a3d | 선택 강조 테두리, 제목 액센트 |
| VERMILION | #bf402a | 위험/등급 pill, 낙관 포인트 |
| SUCCESS | #3b6335 | 선택됨 닷, 성공 |

## 3. 컴포넌트 문법

### 버튼 (나무 패널)
- StyleBoxFlat: WOOD 바탕 + WOOD_BORDER 3px + corner 10, 글자 WOOD_TEXT.
- **텍스트만** — 버튼 안 아이콘 금지 (벤치마크 문법). 아이콘은 코너 유틸 전용.
- 프라이머리 = 크기 하나로만 구분 (전폭~85%, 높이 64+). 색 변형 금지.
- disabled 상태는 만들지 않는다 — 조건 미충족이면 **숨긴다**.

### 종이 패널 (팝업/카드)
- PAPER 바탕 + WOOD_BORDER 3px + corner 12. 제목은 상단 중앙, GOLD 또는
  WOOD_TEXT.
- 모서리 창살 장식은 에셋 도착 시 `asset/ui/chrome/lattice_corner.png`
  4방 배치 (ASSET_REQUIREMENTS 등록).

### 선택 카드 (캐릭터/난이도/레벨업)
- 바탕: 다크(NIGHT 계열) 또는 PAPER 안의 밝은 카드.
- 선택됨 = GOLD 3px 테두리 + SUCCESS 닷 + "선택됨".
- 캐릭터마다 액센트 컬러 1개 (이름·칭호에 사용).
- 레벨업 카드: 좌측 정사각 아이콘(다크 배경) + 이름(크게) + 데이터 설명
  + 우상단 등급 pill (VERMILION 계열).

### 전투 HUD (미니멀)
- 상단: ‖ 일시정지(좌) · 중앙 큰 타이머(픽셀, 흰+INK 외곽선) · 우측 카운터.
- 그 아래 전폭 얇은 XP바 (트랙 INK, 채움 WOOD).
- 카운터는 아이콘+숫자만, 패널/칩 배경 금지.
- HP는 캐릭터 하단 미니바 또는 최소 표시. 화면을 UI로 덮지 않는다.

## 4. 화면 규칙

- 타이틀: 야경 배경 + 로고(간판) + 세로 버튼 스택(85% 폭) + 코너 유틸
  아이콘(설정 등은 작게 코너로).
- 캐릭터 선택: NIGHT 배경 + 세로 카드 리스트 + 하단 나가기.
- 팝업(레벨업/개조/난이도): 종이 패널, 시간 정지, 하단 CTA 버튼 1개.
- 모든 화면 타이틀 baseline 20/68 (layout audit 강제).

## 5. 금지

- 빗금 disabled 칠, 버튼 안 아이콘, 빨강 대면적 버튼, 패널 위 패널 중첩,
  raw 색값, 등급 정보의 색-단독 전달(pill 텍스트 병행).
